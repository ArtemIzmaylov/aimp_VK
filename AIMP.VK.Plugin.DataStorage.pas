{************************************************}
{*                                              *}
{*                AIMP VK Plugin                *}
{*                                              *}
{*                Artem Izmaylov                *}
{*                (C) 2016-2024                 *}
{*                 www.aimp.ru                  *}
{*            Mail: support@aimp.ru             *}
{*                                              *}
{************************************************}

unit AIMP.VK.Plugin.DataStorage;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.Variants,
  // API
  apiCore,
  apiFileManager,
  apiMessages,
  apiMusicLibrary,
  apiObjects,
  apiPlugin,
  apiWrappers,
  // ACL
  ACL.Classes.StringList,
  ACL.Hashes,
  ACL.SQLite3,
  ACL.Threading,
  ACL.Utils.FileSystem,
  ACL.Utils.Strings,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core;

const
  VKDSFieldID       = AIMPML_RESERVED_FIELD_ID;
  VKDSFieldFileName = AIMPML_RESERVED_FIELD_FILENAME;
  VKDSFieldAlbum    = 'Album';
  VKDSFieldArtist   = 'Artist';
  VKDSFieldCategory = 'Category';
  VKDSFieldDuration = 'Duration';
  VKDSFieldGenre    = 'Genre';
  VKDSFieldTitle    = 'Title';

type
  TAIMPVKDataStorageCache = class;
  TAIMPVKCategory = (Unknown, Music, MusicFromPlaylist, MusicFromWall, MyFriends,
    MyGroups, Recommended, Popular, Search, SearchByUser, SearchByGroup, MyNewsFeed);

  { EAIMPVKDataStorageError }

  EAIMPVKDataStorageError = class(Exception);

  { IAIMPVKDataStorage }

  IAIMPVKDataStorage = interface
  ['{3A8F4498-3EE8-48FF-ADFD-BA24D335A0CB}']
    procedure EnumSystemPlaylists(AProc: TProc<TVKPlaylist>);
    procedure EnumMyPlaylists(AProc: TProc<TVKPlaylist>);
    procedure EnumMyFriends(AProc: TProc<TVKFriend>);
    procedure EnumMyGroups(AProc: TProc<TVKGroup>);
    procedure NotifyMyMusicChanged(AAlbumID: Integer = -1);
  end;

  { TAIMPVKDataStorage }

  TAIMPVKDataStorage = class(TAIMPPropertyList,
    IAIMPMessageHook,
    IAIMPMLDataProvider,
    IAIMPMLExtensionDataStorage,
    IAIMPVKDataStorage,
    IVKServiceListener)
  protected const
    CacheFmtAlbums = 'alb-%d';
    CacheFmtAudios = 'Id-%d';
    CacheFmtAudiosInAlbum = 'Id-%d-%d';

    MaxPlaylistCount = 500;
  strict private
    FCache: TAIMPVKDataStorageCache;
    FManager: IAIMPMLDataStorageManager;
    FService: TVKService;
    // IAIMPMessageHook
    procedure CoreMessage(Message: Cardinal; Param1: Integer; Param2: Pointer; var Result: HRESULT); stdcall;
  protected
    function AudioGetPlaylists(OwnerID: Integer; IgnoreCache: Boolean = False): TVKPlaylists;
    procedure DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT); override;
    function DoGetValueAsObject(PropertyID: Integer): IInterface; override;
  public
    constructor Create(AService: TVKService; ADataBase: TACLSQLiteBase);
    destructor Destroy; override;
    procedure EnumSystemPlaylists(AProc: TProc<TVKPlaylist>);
    procedure EnumMyPlaylists(AProc: TProc<TVKPlaylist>);
    procedure EnumMyFriends(AProc: TProc<TVKFriend>);
    procedure EnumMyGroups(AProc: TProc<TVKGroup>);
    // IAIMPMLDataProvider
    function GetData(Fields: IAIMPObjectList; Filter: IAIMPMLDataFilter; out Data: IUnknown): HRESULT; stdcall;
    // IAIMPMLExtensionDataStorage
    function ConfigLoad(Config: IAIMPConfig; Section: IAIMPString): HRESULT; stdcall;
    function ConfigSave(Config: IAIMPConfig; Section: IAIMPString): HRESULT; stdcall;
    function GetFields(Schema: Integer; out List: IAIMPObjectList): HRESULT; stdcall;
    function GetGroupingPresets(Schema: Integer; Presets: IAIMPMLGroupingPresets): HRESULT; stdcall;
    procedure FlushCache(AReserved: Integer); stdcall;
    procedure Finalize; stdcall;
    procedure Initialize(AManager: IAIMPMLDataStorageManager); stdcall;
    // IVKServiceListener
    procedure IVKServiceListener.NotifyLogIn = NotifyAuthChanged;
    procedure IVKServiceListener.NotifyLogOut = NotifyAuthChanged;
    procedure NotifyAuthChanged;
    // IAIMPVKDataStorage
    procedure NotifyMyMusicChanged(AAlbumID: Integer);

    property Cache: TAIMPVKDataStorageCache read FCache;
    property Service: TVKService read FService;
  end;

  { TAIMPVKDataStorageCache }

  TAIMPVKDataStorageCache = class
  public const
    LifeTime = 7; // Days
  strict private
    FDB: TACLSQLiteBase;
  public type
    TOperator = (opBeginsWith, opEquals);
  public
    constructor Create(DB: TACLSQLiteBase);
    procedure Flush; overload;
    procedure Flush(const AQuery: string; AOperator: TOperator); overload;
    procedure Flush(const AFormatString: string; const AArgs: array of const; AOperator: TOperator); overload;
    function Load(const AQuery: string; AList: IVKListIO): Boolean;
    procedure Save(const AQuery: string; AList: IVKListIO);
    //
    function Request<T: class>(const ASource: IVKListIO; const AQuery: string; AProc: TProc<T>; AForceRefresh: Boolean = False): T;
  end;

  { TAIMPVKDataStorageCacheQueryBuilder }

  TAIMPVKDataStorageCacheQueryBuilder = class
  strict private const
    sFieldData = 'd';
    sFieldQuery = 'q';
    sFieldTime = 't';
    sTableCache = 'VKCache';

    class function GetTimeStamp: Integer;
  public
    class function CreateTable: string;
    class function Delete(const AQuery: string; AOperator: TAIMPVKDataStorageCache.TOperator): string;
    class function DeleteAll: string;
    class function DeleteObsolette: string;
    class function Load(const AQuery: string): string;
    class function Save(const AQuery: string): string;
  end;

  { TAIMPVKDataProviderGroupingTree }

  TAIMPVKDataProviderGroupingTree = class(TInterfacedObject,
    IAIMPMLGroupingTreeDataProvider)
  strict private
    FStorage: TAIMPVKDataStorage;
  public
    constructor Create(AStorage: TAIMPVKDataStorage);
    // IAIMPMLGroupingTreeDataProvider
    function AppendFilter(Filter: IAIMPMLDataFilterGroup; Selection: IAIMPMLGroupingTreeSelection): HRESULT; stdcall;
    function GetCapabilities: Cardinal; stdcall;
    function GetData(Selection: IAIMPMLGroupingTreeSelection; out Data: IAIMPMLGroupingTreeDataProviderSelection): HRESULT; stdcall;
    function GetFieldForAlphabeticIndex(out FieldName: IAIMPString): HRESULT; stdcall;
  end;

  { TAIMPVKDataProviderGroupingTreeData }

  PAIMPVKDataProviderGroupingTreeNode = ^TAIMPVKDataProviderGroupingTreeNode;
  TAIMPVKDataProviderGroupingTreeNode = record
    DisplayValue: string;
    HasChildren: Boolean;
    ImageIndex: Integer;
    Value: string;
  end;

  TAIMPVKDataProviderGroupingTreeData = class(TList<TAIMPVKDataProviderGroupingTreeNode>)
  public
    function Add(const ACategory: TAIMPVKCategory;
      AHasChildren: Boolean): PAIMPVKDataProviderGroupingTreeNode; overload;
    function Add(const ACategory: TAIMPVKCategory;
      AHasChildren: Boolean; const AValue: OleVariant): PAIMPVKDataProviderGroupingTreeNode; overload;
    function Add(const ACategory: TAIMPVKCategory;
      AHasChildren: Boolean; const AValue: OleVariant; const ADisplayValue: UnicodeString;
      AImageIndex: Integer = AIMPML_FIELDIMAGE_NOTE): PAIMPVKDataProviderGroupingTreeNode; overload;
  end;

  { TAIMPVKDataProviderGroupingTreeSelection }

  TAIMPVKDataProviderGroupingTreeSelection = class(TInterfacedObject,
    IAIMPMLGroupingTreeDataProviderSelection)
  strict private
    FData: TAIMPVKDataProviderGroupingTreeData;
    FFieldName: IAIMPString;
    FIterator: Integer;
    FMode: TAIMPVKCategory;
    FStorage: TAIMPVKDataStorage;

    procedure PopulateFriends(AList: TAIMPVKDataProviderGroupingTreeData);
    procedure PopulateGroups(AList: TAIMPVKDataProviderGroupingTreeData);
    procedure PopulateIndex(AList: TAIMPVKDataProviderGroupingTreeData);
    procedure PopulateMusicCategories(AList: TAIMPVKDataProviderGroupingTreeData; ID: Integer);
    procedure PopulatePopularGenres(AList: TAIMPVKDataProviderGroupingTreeData);
    procedure PopulateSearchCategories(AList: TAIMPVKDataProviderGroupingTreeData);
    procedure PopulateRecommended(AList: TAIMPVKDataProviderGroupingTreeData);
  protected
    function PopulateData(const AData: string): TAIMPVKDataProviderGroupingTreeData;
  public
    constructor Create(AStorage: TAIMPVKDataStorage; const AValue: OleVariant);
    destructor Destroy; override;
    // IAIMPMLGroupingTreeDataProviderSelection
    function GetDisplayValue(out S: IAIMPString): HRESULT; stdcall;
    function GetFlags: Cardinal; stdcall;
    function GetImageIndex(out Index: Integer): HRESULT; stdcall;
    function GetValue(out FieldName: IAIMPString; out Value: OleVariant): HRESULT; stdcall;
    function NextRecord: LongBool; stdcall;
  end;

  { IAIMPVKDataProviderTable }

  IAIMPVKDataProviderTable = interface(IAIMPMLDataProviderSelection)
  ['{CA3DF842-FA5A-4804-87F9-4C48235A713B}']
    function GetValueAsString(AFieldIndex: Integer): string; overload;
    function HasData: Boolean;
  end;

  { TAIMPVKDataProviderTable }

  TAIMPVKDataProviderTable = class(TInterfacedObjectEx,
    IAIMPVKDataProviderTable,
    IAIMPMLDataProviderSelection)
  strict private type
    TCachedRequestProc = reference to function: TVKAudios;
  strict private
    FFieldIndexAlbum: Integer;
    FFieldIndexArtist: Integer;
    FFieldIndexCategory: Integer;
    FFieldIndexDuration: Integer;
    FFieldIndexFileName: Integer;
    FFieldIndexGenre: Integer;
    FFieldIndexID: Integer;
    FFieldIndexTitle: Integer;
    FIgnoreCache: Boolean;
    FMessageText: string;
    FOwnerPlaylists: TVKPlaylists;
    FStorage: TAIMPVKDataStorage;
    FTempBuffer: UnicodeString;

    function GetCache: TAIMPVKDataStorageCache;
    function GetService: TVKService;
  protected
    FCategory: string;
    FData: TVKAudios;
    FIndex: Integer;
    FOffset: Integer;

    function CachedRequest(const AQueryID: string; AProc: TCachedRequestProc): TVKAudios;
    function GetPlaylist(OwnerID, PlaylistID: Integer): string;
    function GetAudios(ACategory: TAIMPVKCategory; const AData: string): TVKAudios;
    function GetAudiosFromAlbum(const AOwnerAndAlbumIDPair: string): TVKAudios;
    function GetAudiosFromID(ID: Integer): TVKAudios; overload;
    function GetAudiosFromID(ID: Integer; APlaylistID: Integer): TVKAudios; overload;
    function GetAudiosFromNews: TVKAudios;
    function GetAudiosFromSearchQuery(ACategory: TAIMPVKCategory; const AData: string): TVKAudios;
    function GetAudiosFromWall(const AOwnerAndPostIDPair: string): TVKAudios; overload;
    function GetAudiosFromWall(ID: Integer): TVKAudios; overload;
    function GetPopularAudios(AGenreId: Integer): TVKAudios;
    function GetRecommended: TVKAudios;
    function QueryInterface(const IID: TGUID; out Obj): HRESULT; override; stdcall;
  public
    constructor Create(AStorage: TAIMPVKDataStorage; ACategory: TAIMPVKCategory;
      const AData: string; AFields: IAIMPObjectList; AOffset: Integer; AIgnoreCache: Boolean = False);
    destructor Destroy; override;
    // IAIMPMLDataProviderSelection
    function GetValueAsFloat(AFieldIndex: Integer): Double; stdcall;
    function GetValueAsInt32(AFieldIndex: Integer): Integer; stdcall;
    function GetValueAsInt64(AFieldIndex: Integer): Int64; stdcall;
    function GetValueAsString(AFieldIndex: Integer): string; overload;
    function GetValueAsString(FieldIndex: Integer; out Length: Integer): PWideChar; overload; stdcall;
    function HasData: Boolean;
    function HasNextPage: LongBool; stdcall;
    function NextRow: LongBool; stdcall;
    //
    property Cache: TAIMPVKDataStorageCache read GetCache;
    property MessageText: string read FMessageText write FMessageText;
    property Service: TVKService read GetService;
    property Storage: TAIMPVKDataStorage read FStorage;
  end;

  { TAIMPVKGroupingTreeValue }

  TAIMPVKGroupingTreeValue = class
  public
    class function Decode(const AValue: string; out AData: string): TAIMPVKCategory;
    class function Encode(const AValue: string; ACategory: TAIMPVKCategory): string;
  end;

function GetCategory(AFilter: IAIMPMLDataFilter; out AData: UnicodeString): TAIMPVKCategory;
function GetCategoryName(ACategory: TAIMPVKCategory): UnicodeString;
implementation

uses
  System.Character,
  System.StrUtils,
  System.Math,
  // VK
  AIMP.VK.Plugin,
  AIMP.VK.Plugin.FileSystem;

type
  TEnumDataFieldFiltersProc = reference to function (AFilter: IAIMPMLDataFieldFilter): Boolean;

function CreateField(const AName: string; AType: Integer; AFlags: Integer = 0): IAIMPMLDataField;
begin
  CoreCreateObject(IAIMPMLDataField, Result);
  CheckResult(Result.SetValueAsInt32(AIMPML_FIELD_PROPID_TYPE, AType));
  CheckResult(Result.SetValueAsObject(AIMPML_FIELD_PROPID_NAME, MakeString(AName)));
  CheckResult(Result.SetValueAsInt32(AIMPML_FIELD_PROPID_FLAGS, AIMPML_FIELDFLAG_FILTERING or AFlags));
end;

function EnumDataFieldFilters(const AFilter: IAIMPMLDataFilterGroup; const AProc: TEnumDataFieldFiltersProc): Boolean;
var
  AFieldFilter: IAIMPMLDataFieldFilter;
  AGroup: IAIMPMLDataFilterGroup;
  I: Integer;
begin
  Result := False;
  for I := 0 to AFilter.GetChildCount - 1 do
  begin
    if Succeeded(AFilter.GetChild(I, IAIMPMLDataFilterGroup, AGroup)) then
      Result := EnumDataFieldFilters(AGroup, AProc)
    else
      if Succeeded(AFilter.GetChild(I, IAIMPMLDataFieldFilter, AFieldFilter)) then
        Result := AProc(AFieldFilter);

    if Result then
      Break;
  end;
end;

function GetFieldIndex(AFields: IAIMPObjectList; const AFieldName: string): Integer;
var
  AResult: Integer;
  I: Integer;
  S: IAIMPString;
begin
  Result := -1;
  for I := 0 to AFields.GetCount - 1 do
    if Succeeded(AFields.GetObject(I, IAIMPString, S)) then
    begin
      if Succeeded(S.Compare2(PChar(AFieldName), Length(AFieldName), AResult, False)) and (AResult = 0) then
        Exit(I);
    end;
end;

function GetCategory(AFilter: IAIMPMLDataFilter; out AData: UnicodeString): TAIMPVKCategory;

  function ExtractData(out AData: UnicodeString): Boolean;
  var
    AString: IAIMPString;
  begin
    Result := EnumDataFieldFilters(AFilter,
      function (AFilter: IAIMPMLDataFieldFilter): Boolean
      var
        AField: IAIMPMLDataField;
      begin
        Result :=
          Succeeded(AFilter.GetValueAsObject(AIMPML_FIELDFILTER_FIELD, IAIMPMLDataField, AField)) and
          (PropListGetStr(AField, AIMPML_FIELD_PROPID_NAME) = VKDSFieldCategory) and
          (PropListGetStr(AFilter, AIMPML_FIELDFILTER_VALUE1, AString));
      end);

    if Result then
      AData := IAIMPStringToString(AString);
  end;

var
  AValue: string;
begin
  Result := TAIMPVKCategory.Unknown;
  if ExtractData(AValue) then
  begin
    Result := TAIMPVKGroupingTreeValue.Decode(AValue, AData);
    if Result in [Search, SearchByUser, SearchByGroup] then
    begin
      AData := PropListGetStr(AFilter, AIMPML_FILTER_SEARCHSTRING);
      AFilter.SetValueAsObject(AIMPML_FILTER_SEARCHSTRING, nil);
    end;
  end;
end;

function GetCategoryName(ACategory: TAIMPVKCategory): UnicodeString;
const
  Map: array[TAIMPVKCategory] of UnicodeString = ('',
    'Music', 'MusicFromPlaylist', 'Wall', 'MyFriends', 'MyGroups',
    'MyRecommendations', 'Popular', 'Search', 'SearchByUserID',
    'SearchByGroupID', 'MyNewsFeed'
  );
begin
  Result := LangLoadString('AIMPVKPlugin\' + Map[ACategory]);
end;

{ TAIMPVKDataStorage }

constructor TAIMPVKDataStorage.Create(AService: TVKService; ADataBase: TACLSQLiteBase);
begin
  inherited Create;
  FService := AService;
  FCache := TAIMPVKDataStorageCache.Create(ADataBase);
end;

destructor TAIMPVKDataStorage.Destroy;
begin
  FreeAndNil(FCache);
  inherited Destroy;
end;

procedure TAIMPVKDataStorage.EnumSystemPlaylists(AProc: TProc<TVKPlaylist>);
//const
//  SystemPlaylists: array[0..7] of Integer = (-21, -22, -23, -25, -26, -27, -30, -31);
begin
//  with Cache.Request<TVKPlaylists>(TVKPlaylists.Create, 'systemplaylists',
//    procedure (APlaylists: TVKPlaylists)
//    begin
//      for var ID in SystemPlaylists do
//        APlaylists.Add(Service.AudioGetPlaylistByID(Service.UserID, ID));
//    end) do
//  try
//    Enum(AProc);
//  finally
//    Free;
//  end;
end;

procedure TAIMPVKDataStorage.EnumMyPlaylists(AProc: TProc<TVKPlaylist>);
begin
  with AudioGetPlaylists(Service.UserID) do
  try
    Enum(AProc);
  finally
    Free;
  end;
end;

procedure TAIMPVKDataStorage.EnumMyFriends(AProc: TProc<TVKFriend>);
begin
  with Cache.Request<TVKFriends>(TVKFriends.Create, 'myfriends', Service.FriendsGet) do
  try
    Enum(AProc);
  finally
    Free;
  end;
end;

procedure TAIMPVKDataStorage.EnumMyGroups(AProc: TProc<TVKGroup>);
begin
  with Cache.Request<TVKGroups>(TVKGroups.Create, 'mygroups', Service.GroupsGet) do
  try
    Enum(AProc);
  finally
    Free;
  end;
end;

function TAIMPVKDataStorage.GetData(Fields: IAIMPObjectList; Filter: IAIMPMLDataFilter; out Data: IUnknown): HRESULT;
var
  AData: UnicodeString;
begin
  try
    Result := S_OK;
    Data := TAIMPVKDataProviderTable.Create(Self, GetCategory(Filter, AData),
      AData, Fields, PropListGetInt32(Filter, AIMPML_FILTER_OFFSET));
  except
    Result := E_FAIL;
  end;
end;

function TAIMPVKDataStorage.ConfigLoad(Config: IAIMPConfig; Section: IAIMPString): HRESULT;
begin
  Result := S_OK;
end;

function TAIMPVKDataStorage.ConfigSave(Config: IAIMPConfig; Section: IAIMPString): HRESULT;
begin
  Result := S_OK;
end;

function TAIMPVKDataStorage.GetFields(Schema: Integer; out List: IAIMPObjectList): HRESULT;
var
  AField: IAIMPMLDataField;
begin
  CoreCreateObject(IAIMPObjectList, List);
  case Schema of
    AIMPML_FIELDS_SCHEMA_ALL:
      begin
        List.Add(CreateField(VKDSFieldID, AIMPML_FIELDTYPE_INT32, AIMPML_FIELDFLAG_INTERNAL));
        List.Add(CreateField(VKDSFieldFileName, 0));
        List.Add(CreateField(VKDSFieldArtist, AIMPML_FIELDTYPE_STRING));
        List.Add(CreateField(VKDSFieldAlbum, AIMPML_FIELDTYPE_STRING));
        List.Add(CreateField(VKDSFieldTitle, AIMPML_FIELDTYPE_STRING));
        List.Add(CreateField(VKDSFieldGenre, AIMPML_FIELDTYPE_STRING));
        List.Add(CreateField(VKDSFieldDuration, AIMPML_FIELDTYPE_DURATION));

        AField := CreateField(VKDSFieldCategory, AIMPML_FIELDTYPE_STRING, AIMPML_FIELDFLAG_INTERNAL);
        AField.SetValueAsInt32(AIMPML_FIELD_PROPID_IMAGE, 3);
        List.Add(AField);
      end;

    AIMPML_FIELDS_SCHEMA_TABLE_VIEW_ALBUMTHUMBNAILS,
    AIMPML_FIELDS_SCHEMA_TABLE_VIEW_DEFAULT,
    AIMPML_FIELDS_SCHEMA_TABLE_VIEW_GROUPDETAILS:
      begin
        List.Add(MakeString(VKDSFieldTitle));
        List.Add(MakeString(VKDSFieldArtist));
        List.Add(MakeString(VKDSFieldGenre));
        List.Add(MakeString(VKDSFieldDuration));
      end;
  end;

  Result := S_OK;
end;

function TAIMPVKDataStorage.GetGroupingPresets(Schema: Integer; Presets: IAIMPMLGroupingPresets): HRESULT;
var
  APreset: IAIMPMLGroupingPreset;
begin
  Result := S_OK;
  if Schema = AIMPML_GROUPINGPRESETS_SCHEMA_BUILTIN then
    Presets.Add(MakeString('AIMP.VK.ML.GroupingPreset.Default'), nil, 0, TAIMPVKDataProviderGroupingTree.Create(Self), APreset);
end;

procedure TAIMPVKDataStorage.FlushCache(AReserved: Integer);
begin
  FCache.Flush;
end;

procedure TAIMPVKDataStorage.Finalize;
var
  AService: IAIMPServiceMessageDispatcher;
begin
  if CoreGetService(IID_IAIMPServiceMessageDispatcher, AService) then
    AService.Unhook(Self);
  FService.Listeners.Remove(Self);
  FManager := nil;
end;

procedure TAIMPVKDataStorage.Initialize(AManager: IAIMPMLDataStorageManager);
var
  AService: IAIMPServiceMessageDispatcher;
begin
  FManager := AManager;
  FService.Listeners.Add(Self);
  if CoreGetService(IID_IAIMPServiceMessageDispatcher, AService) then
    AService.Hook(Self);
end;

procedure TAIMPVKDataStorage.NotifyAuthChanged;
begin
  FlushCache(0);
  FManager.Changed;
end;

procedure TAIMPVKDataStorage.NotifyMyMusicChanged(AAlbumID: Integer);
begin
  FCache.Flush(CacheFmtAlbums, [FService.UserID], opBeginsWith);
  if AAlbumID >= 0 then
    FCache.Flush(CacheFmtAudiosInAlbum, [FService.UserID, AAlbumID], opEquals)
  else
    FCache.Flush(CacheFmtAudios, [FService.UserID], opBeginsWith);

  FManager.Changed;
end;

function TAIMPVKDataStorage.AudioGetPlaylists(OwnerID: Integer; IgnoreCache: Boolean = False): TVKPlaylists;
begin
  Result := Cache.Request<TVKPlaylists>(TVKPlaylists.Create, Format(CacheFmtAlbums, [OwnerID]),
    procedure (Playlists: TVKPlaylists)
    var
      AMaxCount: Integer;
      ATempResult: TVKPlaylists;
    begin
      AMaxCount := MaxPlaylistCount;
      repeat
        ATempResult := Service.AudioGetPlaylists(OwnerID, Playlists.Count, TVKService.MaxPlaylistGetCount);
        try
          if ATempResult.Count > 0 then
          begin
            ATempResult.OwnsObjects := False;
            AMaxCount := Min(AMaxCount, ATempResult.MaxCount);
            Playlists.AddRange(ATempResult);
          end
          else
            Break;
        finally
          FreeAndNil(ATempResult);
        end;
      until Playlists.Count >= AMaxCount;
    end,
    IgnoreCache);
end;

procedure TAIMPVKDataStorage.DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT);
begin
  if PropertyID = AIMPML_DATASTORAGE_PROPID_CAPABILITIES then
  begin
    Value := 0; // Supress all features
    Result := S_OK;
  end
  else
    inherited DoGetValueAsInt32(PropertyID, Value, Result);
end;

function TAIMPVKDataStorage.DoGetValueAsObject(PropertyID: Integer): IInterface;
begin
  case PropertyID of
    AIMPML_DATASTORAGE_PROPID_ID:
      Result := MakeString(VKPluginIDBase + '.DataStorage');
    AIMPML_DATASTORAGE_PROPID_CAPTION:
      Result := LangLoadStringEx('AIMPVKPlugin\Caption');
  else
    Result := inherited DoGetValueAsObject(PropertyID);
  end
end;

procedure TAIMPVKDataStorage.CoreMessage(Message: Cardinal; Param1: Integer; Param2: Pointer; var Result: HRESULT);
begin
  case Message of
    AIMP_MSG_EVENT_LANGUAGE:
      if FManager <> nil then
        FManager.Changed;
  end;
end;

{ TAIMPVKDataStorageCache }

constructor TAIMPVKDataStorageCache.Create(DB: TACLSQLiteBase);
begin
  inherited Create;
  FDB := DB;
  FDB.Exec(TAIMPVKDataStorageCacheQueryBuilder.CreateTable);
end;

procedure TAIMPVKDataStorageCache.Flush;
begin
  FDB.Exec(TAIMPVKDataStorageCacheQueryBuilder.DeleteAll);
  FDB.Compress;
end;

procedure TAIMPVKDataStorageCache.Flush(const AQuery: string; AOperator: TOperator);
begin
  FDB.Exec(TAIMPVKDataStorageCacheQueryBuilder.Delete(AQuery, AOperator));
  FDB.Compress;
end;

procedure TAIMPVKDataStorageCache.Flush(const AFormatString: string; const AArgs: array of const; AOperator: TOperator);
begin
  Flush(Format(AFormatString, AArgs), AOperator);
  FDB.Compress;
end;

function TAIMPVKDataStorageCache.Load(const AQuery: string; AList: IVKListIO): Boolean;
var
  AData: TMemoryStream;
  ATable: TACLSQLiteTable;
begin
  Result := FDB.Exec(TAIMPVKDataStorageCacheQueryBuilder.Load(AQuery), ATable);
  if Result then
  try
    AData := TMemoryStream.Create;
    try
      ATable.ReadBlob(0, AData);
      AData.Position := 0;
      AList.Load(AData);
    finally
      AData.Free;
    end;
  finally
    ATable.Free;
  end;
end;

procedure TAIMPVKDataStorageCache.Save(const AQuery: string; AList: IVKListIO);
var
  AData: TMemoryStream;
begin
  AData := TMemoryStream.Create;
  try
    AList.Save(AData);
    AData.Position := 0;
    FDB.Transaction(
      procedure
      begin
        FDB.Exec(TAIMPVKDataStorageCacheQueryBuilder.DeleteObsolette);
        FDB.ExecInsertBlob(TAIMPVKDataStorageCacheQueryBuilder.Save(AQuery), AData);
      end);
  finally
    AData.Free;
  end;
end;

function TAIMPVKDataStorageCache.Request<T>(const ASource: IVKListIO;
  const AQuery: string; AProc: TProc<T>; AForceRefresh: Boolean = False): T;
begin
  Result := T(ASource);
  if AForceRefresh or not Load(AQuery, ASource) then
  try
    AProc(Result);
    Save(AQuery, ASource);
  except
    ASource.Clear;
  end;
end;

{ TAIMPVKDataStorageCacheQueryBuilder }

class function TAIMPVKDataStorageCacheQueryBuilder.CreateTable: string;

  procedure AddField(S: TStringBuilder; const AName, AType: string; ALast: Boolean = False);
  begin
    S.Append(AName);
    S.Append(' ');
    S.Append(AType);
    if not ALast then
      S.Append(', ');
  end;

var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('CREATE TABLE IF NOT EXISTS ');
    S.Append(sTableCache);
    S.Append('(');
    AddField(S, sFieldQuery, 'TEXT PRIMARY KEY COLLATE UNICODE');
    AddField(S, sFieldTime, 'INT');
    AddField(S, sFieldData, 'BLOB', True);
    S.Append(');');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.Delete(
  const AQuery: string; AOperator: TAIMPVKDataStorageCache.TOperator): string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('DELETE FROM ');
    S.Append(sTableCache);
    S.Append(' WHERE ');
    S.Append(sFieldQuery);
    if AOperator = opEquals then
    begin
      S.Append(' = ');
      S.Append(PrepareData(AQuery));
    end
    else
    begin
      S.Append(' LIKE "');
      S.Append(AQuery);
      S.Append('%"');
    end;
    S.Append(';');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.DeleteAll: string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('DELETE FROM ');
    S.Append(sTableCache);
    S.Append(';');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.DeleteObsolette: string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('DELETE FROM ');
    S.Append(sTableCache);
    S.Append(' WHERE ');
    S.Append(sFieldTime);
    S.Append(' < ');
    S.Append(PrepareData(GetTimeStamp - TAIMPVKDataStorageCache.LifeTime));
    S.Append(';');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.Load(const AQuery: string): string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('SELECT ');
    S.Append(sFieldData);
    S.Append(' FROM ');
    S.Append(sTableCache);
    S.Append(' WHERE ');
    S.Append(sFieldQuery);
    S.Append(' = ');
    S.Append(PrepareData(AQuery));
//    S.Append(PrepareData(GetTimeStamp - TAIMPVKDataStorageCache.LifeTime));
    S.Append(' LIMIT 1;');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.Save(const AQuery: string): string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('REPLACE INTO ');
    S.Append(sTableCache);
    S.Append(' VALUES(');
    S.Append(PrepareData(AQuery));
    S.Append(', ');
    S.Append(PrepareData(GetTimeStamp));
    S.Append(', ?);');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKDataStorageCacheQueryBuilder.GetTimeStamp: Integer;
begin
  Result := Trunc(Now);
end;

{ TAIMPVKDataProviderGroupingTree }

constructor TAIMPVKDataProviderGroupingTree.Create(AStorage: TAIMPVKDataStorage);
begin
  FStorage := AStorage;
end;

function TAIMPVKDataProviderGroupingTree.AppendFilter(
  Filter: IAIMPMLDataFilterGroup; Selection: IAIMPMLGroupingTreeSelection): HRESULT;
var
  AFieldName: IAIMPString;
  AFilter: IAIMPMLDataFieldFilter;
  AValue: OleVariant;
  I: Integer;
begin
  Filter.BeginUpdate;
  try
    Filter.SetValueAsInt32(AIMPML_FILTERGROUP_OPERATION, AIMPML_FILTERGROUP_OPERATION_AND);
    for I := 0 to Selection.GetCount - 1 do
    begin
      if Succeeded(Selection.GetValue(I, AFieldName, AValue)) then
        Filter.Add(AFieldName, AValue, Null, AIMPML_FIELDFILTER_OPERATION_EQUALS, AFilter);
    end;
  finally
    Filter.EndUpdate;
  end;
  Result := S_OK;
end;

function TAIMPVKDataProviderGroupingTree.GetCapabilities: Cardinal;
begin
  Result := AIMPML_GROUPINGTREEDATAPROVIDER_CAP_HIDEALLDATA;
end;

function TAIMPVKDataProviderGroupingTree.GetData(
  Selection: IAIMPMLGroupingTreeSelection; out Data: IAIMPMLGroupingTreeDataProviderSelection): HRESULT;
var
  AFieldName: IAIMPString;
  AValue: OleVariant;
begin
  if Succeeded(Selection.GetValue(0, AFieldName, AValue)) then
  begin
    if not WideSameText(IAIMPStringToString(AFieldName), VKDSFieldCategory) then
      Exit(E_UNEXPECTED);
  end
  else
    AValue := '';

  try
    Data := TAIMPVKDataProviderGroupingTreeSelection.Create(FStorage, AValue);
    Result := S_OK;
  except
    Result := E_FAIL;
  end;
end;

function TAIMPVKDataProviderGroupingTree.GetFieldForAlphabeticIndex(out FieldName: IAIMPString): HRESULT;
begin
  Result := E_NOTIMPL;
end;

{ TAIMPVKDataProviderGroupingTreeData }

function TAIMPVKDataProviderGroupingTreeData.Add(
  const ACategory: TAIMPVKCategory; AHasChildren: Boolean): PAIMPVKDataProviderGroupingTreeNode;
begin
  Result := Add(ACategory, AHasChildren, '');
end;

function TAIMPVKDataProviderGroupingTreeData.Add(
  const ACategory: TAIMPVKCategory; AHasChildren: Boolean; const AValue: OleVariant): PAIMPVKDataProviderGroupingTreeNode;
begin
  Result := Add(ACategory, AHasChildren, AValue, GetCategoryName(ACategory));
end;

function TAIMPVKDataProviderGroupingTreeData.Add(const ACategory: TAIMPVKCategory;
  AHasChildren: Boolean; const AValue: OleVariant; const ADisplayValue: UnicodeString;
  AImageIndex: Integer = AIMPML_FIELDIMAGE_NOTE): PAIMPVKDataProviderGroupingTreeNode;
var
  ANode: TAIMPVKDataProviderGroupingTreeNode;
begin
  ANode.ImageIndex := AImageIndex;
  ANode.HasChildren := AHasChildren;
  ANode.DisplayValue := ADisplayValue;
  ANode.Value := TAIMPVKGroupingTreeValue.Encode(AValue, ACategory);
  Result := @List[inherited Add(ANode)];
end;

{ TAIMPVKDataProviderGroupingTreeSelection }

constructor TAIMPVKDataProviderGroupingTreeSelection.Create(AStorage: TAIMPVKDataStorage; const AValue: OleVariant);
var
  AData: string;
begin
  FStorage := AStorage;
  FFieldName := MakeString(VKDSFieldCategory);
  FMode := TAIMPVKGroupingTreeValue.Decode(AValue, AData);
  FData := PopulateData(AData);
end;

destructor TAIMPVKDataProviderGroupingTreeSelection.Destroy;
begin
  FreeAndNil(FData);
  inherited Destroy;
end;

function TAIMPVKDataProviderGroupingTreeSelection.GetDisplayValue(out S: IAIMPString): HRESULT;
begin
  try
    S := MakeString(FData[FIterator].DisplayValue);
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TAIMPVKDataProviderGroupingTreeSelection.GetFlags: Cardinal;
begin
  Result := AIMPML_GROUPINGTREENODE_FLAG_STANDALONE;
  if FData[FIterator].HasChildren then
    Result := Result or AIMPML_GROUPINGTREENODE_FLAG_HASCHILDREN;
end;

function TAIMPVKDataProviderGroupingTreeSelection.GetImageIndex(out Index: Integer): HRESULT; stdcall;
begin
  try
    Index := FData[FIterator].ImageIndex;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TAIMPVKDataProviderGroupingTreeSelection.GetValue(out FieldName: IAIMPString; out Value: OleVariant): HRESULT;
begin
  try
    FieldName := FFieldName;
    Value := FData[FIterator].Value;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TAIMPVKDataProviderGroupingTreeSelection.NextRecord: LongBool;
begin
  Inc(FIterator);
  Result := FIterator < FData.Count;
end;

function TAIMPVKDataProviderGroupingTreeSelection.PopulateData(const AData: string): TAIMPVKDataProviderGroupingTreeData;
begin
  Result := TAIMPVKDataProviderGroupingTreeData.Create;
  try
    case FMode of
      TAIMPVKCategory.Unknown:
        PopulateIndex(Result);
      TAIMPVKCategory.Search:
        PopulateSearchCategories(Result);
      TAIMPVKCategory.Music:
        PopulateMusicCategories(Result, StrToIntDef(AData, 0));
      TAIMPVKCategory.MyFriends:
        PopulateFriends(Result);
      TAIMPVKCategory.MyGroups:
        PopulateGroups(Result);
      TAIMPVKCategory.Recommended:
        PopulateRecommended(Result);
      TAIMPVKCategory.Popular:
        if AData = '' then
          PopulatePopularGenres(Result);
    end;
  except
    // do nothing
  end;
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateFriends(AList: TAIMPVKDataProviderGroupingTreeData);
begin
  FStorage.EnumMyFriends(
    procedure (AFriend: TVKFriend)
    begin
      AList.Add(TAIMPVKCategory.Music, True, AFriend.UserID, AFriend.DisplayName, AIMPML_FIELDIMAGE_ARTIST);
    end);
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateGroups(AList: TAIMPVKDataProviderGroupingTreeData);
begin
  FStorage.EnumMyGroups(
    procedure (AGroup: TVKGroup)
    begin
      AList.Add(TAIMPVKCategory.Music, True, -AGroup.ID, AGroup.Name);
    end);
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateIndex(AList: TAIMPVKDataProviderGroupingTreeData);
begin
  AList.Add(TAIMPVKCategory.Music, True, FStorage.Service.UserID, LangLoadString('AIMPVKPlugin\MyMusic'));
// TODO: need to implement the Owner field
//  AList.Add(TAIMPVKCategory.MyNewsFeed, False);
  AList.Add(TAIMPVKCategory.MyFriends, True);
  AList.Add(TAIMPVKCategory.MyGroups, True);
  AList.Add(TAIMPVKCategory.Recommended, True);
  AList.Add(TAIMPVKCategory.Search, True);
  AList.Add(TAIMPVKCategory.Popular, True);
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateMusicCategories(
  AList: TAIMPVKDataProviderGroupingTreeData; ID: Integer);
var
  APlaylist: TVKPlaylist;
  APlaylists: TVKPlaylists;
  I: Integer;
begin
  AList.Add(TAIMPVKCategory.MusicFromWall, False, ID).ImageIndex := AIMPML_FIELDIMAGE_DISK;

  APlaylists := FStorage.AudioGetPlaylists(ID);
  try
    for I := 0 to APlaylists.Count - 1 do
    begin
      APlaylist := APlaylists.List[I];
      AList.Add(TAIMPVKCategory.MusicFromPlaylist, False,
        APlaylist.GetOwnerAndAudioIDPair, APlaylist.Title, AIMPML_FIELDIMAGE_DISK);
    end;
  finally
    APlaylists.Free;
  end;
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulatePopularGenres(
  AList: TAIMPVKDataProviderGroupingTreeData);
begin
  VKGenres.Enum(
    procedure (const Key: Integer; const Value: string)
    begin
      AList.Add(TAIMPVKCategory.Popular, False, Key, Value);
    end);
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateSearchCategories(
  AList: TAIMPVKDataProviderGroupingTreeData);
begin
  AList.Add(TAIMPVKCategory.SearchByGroup, False);
  AList.Add(TAIMPVKCategory.SearchByUser, False);
end;

procedure TAIMPVKDataProviderGroupingTreeSelection.PopulateRecommended(
  AList: TAIMPVKDataProviderGroupingTreeData);
begin
  FStorage.EnumSystemPlaylists(
    procedure (APlaylist: TVKPlaylist)
    begin
      AList.Add(TAIMPVKCategory.MusicFromPlaylist,
        False, APlaylist.GetOwnerAndAudioIDPair, APlaylist.Title);
    end);
end;

{ TAIMPVKDataProviderTable }

constructor TAIMPVKDataProviderTable.Create(AStorage: TAIMPVKDataStorage;
  ACategory: TAIMPVKCategory; const AData: string; AFields: IAIMPObjectList;
  AOffset: Integer; AIgnoreCache: Boolean = False);

  function ExcludeTrailingSlashes(const S: string): string;
  begin
    Result := S;
    if (S <> '') and CharInSet(S[Length(S)], ['\', '/'])  then
      SetLength(Result, Length(S) - 1);
  end;

begin
  FStorage := AStorage;
  FOffset := AOffset;
  FIgnoreCache := AIgnoreCache;
  FCategory := TAIMPVKGroupingTreeValue.Encode(AData, ACategory);
  FFieldIndexArtist := GetFieldIndex(AFields, VKDSFieldArtist);
  FFieldIndexAlbum := GetFieldIndex(AFields, VKDSFieldAlbum);
  FFieldIndexDuration := GetFieldIndex(AFields, VKDSFieldDuration);
  FFieldIndexFileName := GetFieldIndex(AFields, VKDSFieldFileName);
  FFieldIndexID := GetFieldIndex(AFields, VKDSFieldID);
  FFieldIndexTitle := GetFieldIndex(AFields, VKDSFieldTitle);
  FFieldIndexGenre := GetFieldIndex(AFields, VKDSFieldGenre);
  FFieldIndexCategory := GetFieldIndex(AFields, VKDSFieldCategory);

  FData := GetAudios(ACategory, ExcludeTrailingSlashes(AData));
  if FData = nil then
  begin
    if Service.IsAuthorized then
    begin
      if MessageText = '' then
        MessageText := LangLoadString('AIMPVKPlugin\NoData');
    end
    else
    begin
      MessageText := Format('%s[url=%s]%s[/url]', [
        MessageText + IfThen(MessageText <> '', acCRLF),
        sFileURIAuthDialog, LangLoadString('AIMPVKPlugin\L2')])
    end;
  end;
end;

destructor TAIMPVKDataProviderTable.Destroy;
begin
  FreeAndNil(FOwnerPlaylists);
  FreeAndNil(FData);
  inherited Destroy;
end;

function TAIMPVKDataProviderTable.GetValueAsFloat(AFieldIndex: Integer): Double;
begin
  Result := FData[FIndex].Duration;
end;

function TAIMPVKDataProviderTable.GetValueAsInt32(AFieldIndex: Integer): Integer;
begin
  Result := FData[FIndex].ID;
end;

function TAIMPVKDataProviderTable.GetValueAsInt64(AFieldIndex: Integer): Int64;
begin
  Result := 0;
end;

function TAIMPVKDataProviderTable.GetValueAsString(FieldIndex: Integer; out Length: Integer): PWideChar;
begin
  FTempBuffer := GetValueAsString(FieldIndex);
  Length := System.Length(FTempBuffer);
  Result := PWideChar(FTempBuffer);
end;

function TAIMPVKDataProviderTable.GetValueAsString(AFieldIndex: Integer): string;
begin
  if AFieldIndex = FFieldIndexArtist then
    Result := FData[FIndex].Artist
  else if AFieldIndex = FFieldIndexFileName then
    Result := TAIMPVKFileSystem.MakeFileURI(FData[FIndex])
  else if AFieldIndex = FFieldIndexTitle then
    Result := FData[FIndex].Title
  else if AFieldIndex = FFieldIndexGenre then
    Result := FData[FIndex].Genre
  else if AFieldIndex = FFieldIndexCategory then
    Result := FCategory
  else if AFieldIndex = FFieldIndexAlbum then
    Result := GetPlaylist(FData[FIndex].OwnerID, FData[FIndex].AlbumID)
  else
    Result := '';
end;

function TAIMPVKDataProviderTable.HasData: Boolean;
begin
  Result := (FData <> nil) and (FData.Count > 0);
end;

function TAIMPVKDataProviderTable.HasNextPage: LongBool;
begin
  Result := HasData and (FOffset + FData.Count < FData.MaxCount);
end;

function TAIMPVKDataProviderTable.NextRow: LongBool;
begin
  Inc(FIndex);
  Result := (FData <> nil) and (FIndex < FData.Count);
end;

function TAIMPVKDataProviderTable.CachedRequest(
  const AQueryID: string; AProc: TCachedRequestProc): TVKAudios;
var
  ACached: TVKAudios;
  I: Integer;
begin
  ACached := TVKAudios.Create;
  if Cache.Load(AQueryID, ACached) and (FOffset < ACached.Count) then
  begin
    if not FIgnoreCache then
    begin
      ACached.DeleteRange(0, FOffset);
      Exit(ACached);
    end;
    ACached.DeleteRange(FOffset, ACached.Count - FOffset);
  end;

  try
    Result := AProc;
    if Result <> nil then
      TAIMPVKFileSystem.UpdateCache(Result);
    if ACached.Count = 0 then
      Cache.Save(AQueryID, Result)
    else
    begin
      ACached.Capacity := Max(ACached.Capacity, ACached.Count + Result.Count);
      ACached.MaxCount := Result.MaxCount;
      for I := 0 to Result.Count - 1 do
        ACached.Add(Result[I].Clone);
      Cache.Save(AQueryID, ACached);
    end;
  finally
    ACached.Free;
  end;
end;

function TAIMPVKDataProviderTable.GetPlaylist(OwnerID, PlaylistID: Integer): string;
var
  APlaylist: TVKPlaylist;
begin
  Result := '';
  if PlaylistID <> 0 then
  begin
    if FOwnerPlaylists = nil then
      FOwnerPlaylists := FStorage.AudioGetPlaylists(OwnerID, FIgnoreCache);
    if FOwnerPlaylists.Find(OwnerID, PlaylistID, APlaylist) then
      Result := APlaylist.Title;
  end;
end;

function TAIMPVKDataProviderTable.GetAudios(
  ACategory: TAIMPVKCategory; const AData: string): TVKAudios;
begin
  Result := nil;
  try
    case ACategory of
      TAIMPVKCategory.MyFriends:
        raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\SelectTheFriend'));
      TAIMPVKCategory.MyGroups:
        raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\SelectTheGroup'));
      TAIMPVKCategory.MyNewsFeed:
        Result := GetAudiosFromNews;
      TAIMPVKCategory.Music:
        Result := GetAudiosFromID(StrToIntDef(AData, 0));
      TAIMPVKCategory.MusicFromPlaylist:
        Result := GetAudiosFromAlbum(AData);
      TAIMPVKCategory.Popular:
        Result := GetPopularAudios(StrToIntDef(AData, 0));
      TAIMPVKCategory.Recommended:
        Result := GetRecommended;
      TAIMPVKCategory.Search,
      TAIMPVKCategory.SearchByUser,
      TAIMPVKCategory.SearchByGroup:
        Result := GetAudiosFromSearchQuery(ACategory, AData);
      TAIMPVKCategory.MusicFromWall:
        Result := GetAudiosFromWall(AData);
    end;
  except
    on E: Exception do
    begin
      MessageText := E.Message;
      Result := nil;
    end;
  end;
end;

function TAIMPVKDataProviderTable.GetAudiosFromAlbum(const AOwnerAndAlbumIDPair: string): TVKAudios;
var
  AOwnerID, AAlbumID: Integer;
  AAccessKey: string;
begin
  if not ParseOwnerAndAudioIDPair(AOwnerAndAlbumIDPair,
    AOwnerID, AAlbumID, AAccessKey) or (AOwnerID = 0) or (AAlbumID = 0)
  then
    raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\NoData'));

  Result := GetAudiosFromID(AOwnerID, AAlbumID);
end;

function TAIMPVKDataProviderTable.GetAudiosFromID(ID: Integer): TVKAudios;
begin
  if ID = 0 then
    raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\NoData'));

  Result := CachedRequest(Format(TAIMPVKDataStorage.CacheFmtAudios, [ID]),
    function: TVKAudios
    begin
      Result := Service.AudioGet(ID, FOffset);
    end);
end;

function TAIMPVKDataProviderTable.GetAudiosFromID(ID: Integer; APlaylistID: Integer): TVKAudios;
begin
  if ID = 0 then
    raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\NoData'));

  Result := CachedRequest(Format(TAIMPVKDataStorage.CacheFmtAudiosInAlbum, [ID, APlaylistID]),
    function: TVKAudios
    begin
      Result := Service.AudioGetFromPlaylist(ID, APlaylistID, FOffset);
    end);
end;

function TAIMPVKDataProviderTable.GetAudiosFromNews: TVKAudios;
begin
  Result := CachedRequest('mynews',
    function: TVKAudios
    begin
      Result := Service.NewsGetAudios;
    end);
end;

function TAIMPVKDataProviderTable.GetAudiosFromSearchQuery(
  ACategory: TAIMPVKCategory; const AData: string): TVKAudios;
var
  ID: Integer;
begin
  if Trim(AData) = '' then
    raise EAIMPVKDataStorageError.Create(LangLoadString('AIMPVKPlugin\SearchStringRequired'));

  if (Length(AData) > 4) and acBeginsWith(AData, 'wall') and CharInSet(AData[5], ['-', '0'..'9']) then
    Exit(GetAudiosFromWall(Copy(AData, 5, MaxInt)));

  if ACategory = TAIMPVKCategory.Search then
  begin
    Exit(
      CachedRequest(Format('Q-%s', [TACLHashMD5.Calculate(AData)]),
        function: TVKAudios
        begin
          Result := Service.AudioSearch(AData, FOffset, TVKService.MaxAudioSearchCount);
        end));
  end;

  ID := StrToIntDef(AData, 0);
  if ID = 0 then
  begin
    if ACategory = TAIMPVKCategory.SearchByGroup then
      ID := Service.GroupsGetIDByAlias(AData)
    else
      ID := Service.UsersGetIDByAlias(AData);
  end;
  if ACategory = TAIMPVKCategory.SearchByGroup then
    ID := -ID;
  Result := GetAudiosFromID(ID);
end;

function TAIMPVKDataProviderTable.GetAudiosFromWall(const AOwnerAndPostIDPair: string): TVKAudios;
var
  AOwnerID, APostID: Integer;
  AAccessKey: string;
begin
  if ParseOwnerAndAudioIDPair(AOwnerAndPostIDPair, AOwnerID, APostID, AAccessKey) then
  begin
    Result := CachedRequest('WallPost-' + AOwnerAndPostIDPair,
      function: TVKAudios
      begin
        Result := Service.AudioGetFromWallPost(AOwnerID, APostID);
      end)
  end
  else
    Result := GetAudiosFromWall(StrToIntDef(AOwnerAndPostIDPair, 0));
end;

function TAIMPVKDataProviderTable.GetAudiosFromWall(ID: Integer): TVKAudios;
begin
  Result := CachedRequest('Wall-' + IntToStr(ID),
    function: TVKAudios
    begin
      Result := Service.AudioGetFromWall(ID, FOffset);
    end);
end;

function TAIMPVKDataProviderTable.GetPopularAudios(AGenreId: Integer): TVKAudios;
begin
  Result := CachedRequest('Popular-' + IntToStr(AGenreId),
    function: TVKAudios
    begin
      Result := Service.AudioGetPopular(FOffset, TVKService.MaxAudioPopularCount, AGenreId);
    end);
end;

function TAIMPVKDataProviderTable.GetRecommended: TVKAudios;
begin
  Result := CachedRequest('Recommended',
    function: TVKAudios
    begin
      Result := Service.AudioGetRecommendations(FOffset, TVKService.MaxAudioRecommendationCount);
    end);
end;

function TAIMPVKDataProviderTable.QueryInterface(const IID: TGUID; out Obj): HRESULT;
begin
  if (IID = IID_IAIMPMLDataProviderSelection) and not HasData then
    Exit(E_NOINTERFACE);
  if (IID = IID_IAIMPString) then
  begin
    IAIMPString(Obj) := MakeString(MessageText);
    Result := S_OK;
  end
  else
    Result := inherited QueryInterface(IID, Obj);
end;

function TAIMPVKDataProviderTable.GetCache: TAIMPVKDataStorageCache;
begin
  Result := Storage.Cache;
end;

function TAIMPVKDataProviderTable.GetService: TVKService;
begin
  Result := Storage.Service;
end;

{ TAIMPVKGroupingTreeValue }

class function TAIMPVKGroupingTreeValue.Decode(const AValue: string; out AData: string): TAIMPVKCategory;
begin
  if Length(AValue) >= 2 then
  begin
    Result := TAIMPVKCategory(TACLHexcode.Decode(AValue[1], AValue[2]));
    AData := Copy(AValue, 3, MaxInt);
  end
  else
    Result := TAIMPVKCategory.Unknown;
end;

class function TAIMPVKGroupingTreeValue.Encode(const AValue: string; ACategory: TAIMPVKCategory): string;
begin
  Result := TACLHexcode.Encode(Ord(ACategory));
  if not (ACategory in [Search, SearchByUser, SearchByGroup]) then
    Result := Result + AValue;
end;

end.
