{************************************************}
{*                                              *}
{*                AIMP VK Plugin                *}
{*                                              *}
{*                Artem Izmaylov                *}
{*                (C) 2016-2020                 *}
{*                 www.aimp.ru                  *}
{*            Mail: support@aimp.ru             *}
{*                                              *}
{************************************************}

unit AIMP.VK.Plugin.Menus;

{$I AIMP.VK.inc}
{$R AIMP.VK.Plugin.Menus.res}

interface

uses
  Winapi.ActiveX,
  Winapi.Windows,
  System.Generics.Collections,
  System.SysUtils,
  System.Variants,
  // VK
  AIMP.VK.Core,
  AIMP.VK.Classes,
  AIMP.VK.Plugin,
  AIMP.VK.Plugin.DataStorage,
  AIMP.VK.Plugin.Downloader,
  AIMP.VK.Plugin.SmartPlaylists,
  // ACL
  ACL.Classes.StringList,
  ACL.Math,
  ACL.UI.Dialogs,
  ACL.Utils.Common,
  ACL.Utils.Strings,
  // API
  apiActions,
  apiFileManager,
  apiMenu,
  apiMusicLibrary,
  apiObjects,
  apiPlaylists,
  apiWrappers,
  apiWrappersGUI;

type
//----------------------------------------------------------------------------------------------------------------------
// Basic
//----------------------------------------------------------------------------------------------------------------------
  TAIMPVKCustomMenuItem = class;

  TAIMPVKItemStates = (isEnabled, isVisible);
  TAIMPVKItemState = set of TAIMPVKItemStates;

  TAIMPVKMenuItemDataSourceMode = (dsmFocusedOnly, dsmAllSelected);

  { IAIMPVKMenuItemDataSource }

  IAIMPVKMenuItemDataSource = interface(IAIMPActionEvent)
  ['{3F4AA204-E1BC-4EC9-AC70-3F74F5225604}']
    procedure Bind(AHandle: IAIMPMenuItem; AMenuItem: TAIMPVKCustomMenuItem);
    function GetFiles(AMode: TAIMPVKMenuItemDataSourceMode): TACLStringList;
  end;

  { TAIMPVKCustomMenuItem }

  TAIMPVKCustomMenuItem = class(TInterfacedObject, IAIMPActionEvent)
  strict private
    FDataSource: IAIMPVKMenuItemDataSource;
    FID: UnicodeString;
    FOwner: TAIMPVKPlugin;
  protected
    function GetState: TAIMPVKItemState; virtual; abstract;
    // IAIMPActionEvent
    procedure OnExecute(Sender: IUnknown); virtual; stdcall; abstract;
    // IAIMPVKMenuItem
    procedure UpdateState; overload;
    procedure UpdateState(AMenuItem: IAIMPMenuItem); overload; virtual;
  public
    constructor Create(AOwner: TAIMPVKPlugin; ADataSource: IAIMPVKMenuItemDataSource); virtual;
    class function GetGlyphName: string; virtual;
    class procedure Register(AOwner: TAIMPVKPlugin;
      ADataSource: IAIMPVKMenuItemDataSource; const AId: string; const AParentId: Variant);
    //
    property DataSource: IAIMPVKMenuItemDataSource read FDataSource;
    property ID: UnicodeString read FID;
    property Owner: TAIMPVKPlugin read FOwner;
  end;

  { TAIMPVKCustomFilesBasedMenuItem }

  TAIMPVKCustomFilesBasedMenuItem = class(TAIMPVKCustomMenuItem)
  protected
    function GetMode: TAIMPVKMenuItemDataSourceMode; virtual;
    procedure OnExecute(Sender: IUnknown); override;
    procedure OnExecuteCore(const Files: TACLStringList); virtual;
    function GetState: TAIMPVKItemState; override;
    function GetStateCore(const Files: TACLStringList): TAIMPVKItemState; virtual;
  end;

//----------------------------------------------------------------------------------------------------------------------
// DataSources
//----------------------------------------------------------------------------------------------------------------------

  TAIMPVKCustomMenuItemDataSource = class(TInterfacedObject,
    IAIMPActionEvent,
    IAIMPVKMenuItemDataSource)
  strict private
    FFilesFocused: TACLStringList;
    FFilesSelected: TACLStringList;
    FMenuItems: TList<TAIMPVKCustomMenuItem>;
    FRegistered: Boolean;

    // IAIMPVKMenuItemDataSource
    procedure Bind(AHandle: IAIMPMenuItem; AMenuItem: TAIMPVKCustomMenuItem);
    function GetFiles(AMode: TAIMPVKMenuItemDataSourceMode): TACLStringList;
    // IAIMPActionEvent
    procedure OnExecute(Data: IInterface); stdcall;
  protected
    procedure QueryFiles(AFilesFocused, AFilesSelected: TACLStringList); virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  { TAIMPVKMLMenuItemDataSource }

  TAIMPVKMLMenuItemDataSource = class(TAIMPVKCustomMenuItemDataSource)
  protected
    procedure QueryFiles(AFilesFocused: TACLStringList; AFilesSelected: TACLStringList); override;
  end;

  { TAIMPVKPLMenuItemDataSource }

  TAIMPVKPLMenuItemDataSource = class(TAIMPVKCustomMenuItemDataSource)
  protected
    procedure QueryFiles(AFilesFocused: TACLStringList; AFilesSelected: TACLStringList); override;
  end;

  { TAIMPVKMLSmartPlaylistDataSource }

  TAIMPVKMLSmartPlaylistDataSource = class(TAIMPVKCustomMenuItemDataSource)
  protected
    procedure QueryFiles(AFilesFocused: TACLStringList; AFilesSelected: TACLStringList); override;
  end;

//----------------------------------------------------------------------------------------------------------------------
// MenuItems
//----------------------------------------------------------------------------------------------------------------------

  { TAIMPVKMenuItemAddToAlbum }

  TAIMPVKMenuItemAddToAlbum = class(TAIMPVKCustomFilesBasedMenuItem)
  protected
    procedure UpdateState(AMenuItem: IAIMPMenuItem); override;
  end;

  { TAIMPVKMenuItemAddToMyMusic }

  TAIMPVKMenuItemAddToMyMusic = class(TAIMPVKCustomFilesBasedMenuItem)
  strict private
    FAlbumID: Integer;
    procedure NameValidationProc(Sender: TObject; const AValueIndex: Integer; const AValue: UnicodeString; var AIsValid: Boolean);
  protected
    procedure OnExecuteCore(const AFiles: TACLStringList); override;
  public
    constructor Create(AOwner: TAIMPVKPlugin; ADataSource: IAIMPVKMenuItemDataSource; AAlbumID: Integer); reintroduce;
  end;

  { TAIMPVKMenuItemCreateSmartPlaylist }

  TAIMPVKMenuItemCreateSmartPlaylist = class(TAIMPVKCustomMenuItem)
  strict private
    function GetInfo(out ACategory: TAIMPVKCategory; out AData, AGroupPath: string): Boolean;
  protected
    function GetState: TAIMPVKItemState; override;
    procedure OnExecute(Sender: IInterface); override; stdcall;
  end;

  { TAIMPVKMenuItemDelete }

  TAIMPVKMenuItemDelete = class(TAIMPVKCustomFilesBasedMenuItem)
  protected
    function GetStateCore(const AFiles: TACLStringList): TAIMPVKItemState; override;
    procedure OnExecuteCore(const AFiles: TACLStringList); override;
  end;

  { TAIMPVKMenuItemDownload }

  TAIMPVKMenuItemDownload = class(TAIMPVKCustomFilesBasedMenuItem)
  protected
    procedure OnExecuteCore(const AFiles: TACLStringList); override;
  end;

  { TAIMPVKMenuItemFindLyrics }

  TAIMPVKMenuItemFindLyrics = class(TAIMPVKCustomFilesBasedMenuItem)
  protected
    function GetMode: TAIMPVKMenuItemDataSourceMode; override;
    function GetStateCore(const AFiles: TACLStringList): TAIMPVKItemState; override;
    procedure OnExecuteCore(const AFiles: TACLStringList); override;
  end;

procedure AddSimpleMenuItem(AParent: IAIMPMenuItem; const ATitle: string; AEvent: IUnknown); overload;
procedure AddSimpleMenuItem(AParent: Integer; const ATitle: string; AEvent: IUnknown); overload;
implementation

uses
  AIMP.VK.Plugin.Dialogs.Lyrics,
  AIMP.VK.Plugin.FileSystem;

procedure AddSimpleMenuItem(AParent: IAIMPMenuItem; const ATitle: string; AEvent: IUnknown); overload;
var
  ASubItem: IAIMPMenuItem;
begin
  CoreCreateObject(IAIMPMenuItem, ASubItem);
  PropListSetStr(ASubItem, AIMP_MENUITEM_PROPID_NAME, ATitle);
  PropListSetObj(ASubItem, AIMP_MENUITEM_PROPID_PARENT, AParent);
  PropListSetObj(ASubItem, AIMP_MENUITEM_PROPID_EVENT, AEvent);
  CoreIntf.RegisterExtension(IAIMPServiceMenuManager, ASubItem);
end;

procedure AddSimpleMenuItem(AParent: Integer; const ATitle: string; AEvent: IUnknown); overload;
var
  AMenuItem: IAIMPMenuItem;
  AService: IAIMPServiceMenuManager;
begin
  if CoreGetService(IAIMPServiceMenuManager, AService) then
  begin
    if Succeeded(AService.GetBuiltIn(AParent, AMenuItem)) then
      AddSimpleMenuItem(AMenuItem, ATitle, AEvent);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------
// Custom
//----------------------------------------------------------------------------------------------------------------------

{ TAIMPVKCustomMenuItem }

constructor TAIMPVKCustomMenuItem.Create(AOwner: TAIMPVKPlugin; ADataSource: IAIMPVKMenuItemDataSource);
begin
  inherited Create;
  FOwner := AOwner;
  FDataSource := ADataSource;
end;

class procedure TAIMPVKCustomMenuItem.Register(AOwner: TAIMPVKPlugin;
  ADataSource: IAIMPVKMenuItemDataSource; const AId: string; const AParentId: Variant);
var
  AGlyph: IAIMPImage2;
  AHandle: IAIMPMenuItem;
  AMenuItem: TAIMPVKCustomMenuItem;
  AParentHandle: IAIMPMenuItem;
  AService: IAIMPServiceMenuManager;
begin
  CoreCreateObject(IAIMPMenuItem, AHandle);
  if CoreGetService(IAIMPServiceMenuManager, AService) then
  begin
    if VarIsStr(AParentID) then
      CheckResult(AService.GetByID(MakeString(AParentID), AParentHandle))
    else
      CheckResult(AService.GetBuiltIn(AParentID, AParentHandle));
  end;

  if GetGlyphName <> '' then
  try
    CoreCreateObject(IAIMPImage2, AGlyph);
    CheckResult(AGlyph.LoadFromResource(HInstance, PWideChar(GetGlyphName), 'PNG'));
    PropListSetObj(AHandle, AIMP_MENUITEM_PROPID_GLYPH, AGlyph);
  except
    // do nothing
  end;

  AMenuItem := Create(AOwner, ADataSource);
  AMenuItem.FID := AId;
  PropListSetStr(AHandle, AIMP_MENUITEM_PROPID_ID, AId);
  PropListSetObj(AHandle, AIMP_MENUITEM_PROPID_EVENT, AMenuItem);
  PropListSetObj(AHandle, AIMP_MENUITEM_PROPID_PARENT, AParentHandle);
  if ADataSource <> nil then
    ADataSource.Bind(AHandle, AMenuItem);

  CoreIntf.RegisterExtension(IAIMPServiceMenuManager, AHandle);
end;

class function TAIMPVKCustomMenuItem.GetGlyphName: string;
begin
  Result := 'MENUGLYPH';
end;

procedure TAIMPVKCustomMenuItem.UpdateState;
var
  AMenuItem: IAIMPMenuItem;
  AService: IAIMPServiceMenuManager;
begin
  if CoreGetService(IAIMPServiceMenuManager, AService) then
  begin
    if Succeeded(AService.GetByID(MakeString(ID), AMenuItem)) then
      UpdateState(AMenuItem);
  end;
end;

procedure TAIMPVKCustomMenuItem.UpdateState(AMenuItem: IAIMPMenuItem);
var
  AState: TAIMPVKItemState;
begin
  AState := GetState;
  PropListSetInt32(AMenuItem, AIMP_MENUITEM_PROPID_ENABLED, Ord(isEnabled in AState));
  PropListSetInt32(AMenuItem, AIMP_MENUITEM_PROPID_VISIBLE, Ord(isVisible in AState));
end;

{ TAIMPVKCustomFilesBasedMenuItem }

function TAIMPVKCustomFilesBasedMenuItem.GetMode: TAIMPVKMenuItemDataSourceMode;
begin
  Result := dsmAllSelected;
end;

procedure TAIMPVKCustomFilesBasedMenuItem.OnExecute(Sender: IUnknown);
var
  AFiles: TACLStringList;
begin
  if DataSource <> nil then
  begin
    AFiles := DataSource.GetFiles(GetMode);
    if AFiles.Count > 0 then
      OnExecuteCore(AFiles);
  end;
end;

procedure TAIMPVKCustomFilesBasedMenuItem.OnExecuteCore(const Files: TACLStringList);
begin
  // do nothing
end;

function TAIMPVKCustomFilesBasedMenuItem.GetState: TAIMPVKItemState;
var
  AFiles: TACLStringList;
begin
  Result := [];
  if DataSource <> nil then
  begin
    AFiles := DataSource.GetFiles(GetMode);
    if AFiles.Count > 0 then
      Result := GetStateCore(AFiles);
  end;
end;

function TAIMPVKCustomFilesBasedMenuItem.GetStateCore(const Files: TACLStringList): TAIMPVKItemState;
begin
  if TAIMPVKFileSystem.IsOurFile(Files.First) then
    Result := [isEnabled, isVisible]
  else
    Result := [];
end;

//----------------------------------------------------------------------------------------------------------------------
// DataSources
//----------------------------------------------------------------------------------------------------------------------

{ TAIMPVKCustomMenuItemDataSource }

constructor TAIMPVKCustomMenuItemDataSource.Create;
begin
  FFilesFocused := TACLStringList.Create;
  FFilesSelected := TACLStringList.Create;
  FMenuItems := TList<TAIMPVKCustomMenuItem>.Create;
end;

destructor TAIMPVKCustomMenuItemDataSource.Destroy;
begin
  FreeAndNil(FFilesFocused);
  FreeAndNil(FFilesSelected);
  FreeAndNil(FMenuItems);
  inherited Destroy;
end;

procedure TAIMPVKCustomMenuItemDataSource.Bind(AHandle: IAIMPMenuItem; AMenuItem: TAIMPVKCustomMenuItem);
begin
  FMenuItems.Add(AMenuItem);
  if not FRegistered then
  begin
    FRegistered := True;
    PropListSetObj(AHandle, AIMP_MENUITEM_PROPID_EVENT_ONSHOW, Self);
  end;
end;

function TAIMPVKCustomMenuItemDataSource.GetFiles(AMode: TAIMPVKMenuItemDataSourceMode): TACLStringList;
begin
  if AMode = dsmAllSelected then
    Result := FFilesSelected
  else
    Result := FFilesFocused;
end;

procedure TAIMPVKCustomMenuItemDataSource.OnExecute(Data: IInterface);
var
  AItem: TAIMPVKCustomMenuItem;
begin
  FFilesFocused.Clear;
  FFilesSelected.Clear;
  QueryFiles(FFilesFocused, FFilesSelected);
  for AItem in FMenuItems do
    AItem.UpdateState;
end;

{ TAIMPVKMLMenuItemDataSource }

procedure TAIMPVKMLMenuItemDataSource.QueryFiles(AFilesFocused, AFilesSelected: TACLStringList);
var
  AFileURI: IAIMPString;
  AList: IAIMPMLFileList;
  AService: IAIMPServiceMusicLibraryUI;
  I: Integer;
begin
  if CoreGetService(IAIMPServiceMusicLibraryUI, AService) and Succeeded(AService.GetFiles(AIMPML_GETFILES_FLAGS_SELECTED, AList)) then
  begin
    AFilesSelected.Capacity := AList.GetCount;
    for I := 0 to AList.GetCount - 1 do
    begin
      if Succeeded(AList.GetFileName(I, AFileURI)) then
        AFilesSelected.Add(IAIMPStringToString(AFileURI));
    end;
    if AFilesSelected.Count > 0 then
      AFilesFocused.Add(AFilesSelected.First);
  end;
end;

{ TAIMPVKPLMenuItemDataSource }

procedure TAIMPVKPLMenuItemDataSource.QueryFiles(AFilesFocused, AFilesSelected: TACLStringList);
var
  AFileURI: IAIMPString;
  AGroup: IAIMPPlaylistGroup;
  AItem: IAIMPPlaylistItem;
  AList: IAIMPObjectList;
  APlaylist: IAIMPPlaylist;
  AProperties: IAIMPPropertyList;
  AService: IAIMPServicePlaylistManager;
  I: Integer;
begin
  if CoreGetService(IAIMPServicePlaylistManager, AService) and Succeeded(AService.GetActivePlaylist(APlaylist)) then
  begin
    if Succeeded(APlaylist.GetFiles(AIMP_PLAYLIST_GETFILES_FLAGS_SELECTED_ONLY, AList)) then
    begin
      AFilesSelected.Capacity := AList.GetCount;
      for I := 0 to AList.GetCount - 1 do
      begin
        if Succeeded(AList.GetObject(I, IAIMPString, AFileURI)) then
          AFilesSelected.Add(IAIMPStringToString(AFileURI));
      end;
    end;
    if Supports(APlaylist, IAIMPPropertyList, AProperties) then
    begin
      if
        Succeeded(AProperties.GetValueAsObject(AIMP_PLAYLIST_PROPID_FOCUSED_OBJECT, IAIMPPlaylistItem, AItem)) or
        Succeeded(AProperties.GetValueAsObject(AIMP_PLAYLIST_PROPID_FOCUSED_OBJECT, IAIMPPlaylistGroup, AGroup)) and
        Succeeded(AGroup.GetItem(0, IAIMPPlaylistItem, AItem))
      then
        if PropListGetInt32(AItem, AIMP_PLAYLISTITEM_PROPID_SELECTED) <> 0 then
          if Succeeded(AItem.GetValueAsObject(AIMP_PLAYLISTITEM_PROPID_FILENAME, IAIMPString, AFileURI)) then
            AFilesFocused.Add(IAIMPStringToString(AFileURI));
    end;
  end;
end;

{ TAIMPVKMLSmartPlaylistDataSource }

procedure TAIMPVKMLSmartPlaylistDataSource.QueryFiles(AFilesFocused, AFilesSelected: TACLStringList);
begin
  // do nothing
end;

//----------------------------------------------------------------------------------------------------------------------
// MenuItems
//----------------------------------------------------------------------------------------------------------------------

{ TAIMPVKMenuItemAddToAlbum }

procedure TAIMPVKMenuItemAddToAlbum.UpdateState(AMenuItem: IAIMPMenuItem);
begin
  inherited UpdateState(AMenuItem);
  AMenuItem.DeleteChildren;

  AddSimpleMenuItem(AMenuItem, LangLoadString('AIMPVKPlugin\NewAlbum'), TAIMPVKMenuItemAddToMyMusic.Create(Owner, DataSource, -1));
  AddSimpleMenuItem(AMenuItem, '-', nil);
  Owner.DataStorage.EnumMyPlaylists(
    procedure (APlaylist: TVKPlaylist)
    begin
      AddSimpleMenuItem(AMenuItem, APlaylist.Title, TAIMPVKMenuItemAddToMyMusic.Create(Owner, DataSource, APlaylist.Id));
    end);
end;

{ TAIMPVKMenuItemAddToMyMusic }

constructor TAIMPVKMenuItemAddToMyMusic.Create(
  AOwner: TAIMPVKPlugin; ADataSource: IAIMPVKMenuItemDataSource; AAlbumID: Integer);
begin
  inherited Create(AOwner, ADataSource);
  FAlbumID := AAlbumID;
end;

procedure TAIMPVKMenuItemAddToMyMusic.OnExecuteCore(const AFiles: TACLStringList);
var
  AAlbumID: Integer;
  AAudioID: Integer;
  AOwnerID: Integer;
  ATitle: string;
  ATracksToAdd: TList<TPair<Integer, Integer>>;
  ATracksToMove: TList<Integer>;
  AUserID: Integer;
  I: Integer;
begin
  AAlbumID := FAlbumID;
  if AAlbumID < 0 then
  begin
    if TACLInputQueryDialog.Execute(LangLoadString('AIMPVKPlugin\NewAlbum'), LangLoadString('MSG\2'), ATitle, nil, NameValidationProc) then
      AAlbumID := Owner.Service.AudioCreatePlaylist(ATitle);
  end;
  if AAlbumID >= 0 then
  begin
    ATracksToAdd := TList<TPair<Integer, Integer>>.Create;
    ATracksToMove := TList<Integer>.Create;
    try
      AUserID := Owner.Service.UserID;
      for I := 0 to AFiles.Count - 1 do
      begin
        if ParseOwnerAndAudioIDPair(TAIMPVKFileSystem.GetOwnerAndAudioIDPair(AFiles[I]), AOwnerID, AAudioID) then
        begin
          if AOwnerID = AUserID then
            ATracksToMove.Add(AAudioID)
          else
            ATracksToAdd.Add(TPair<Integer, Integer>.Create(AOwnerID, AAudioID));
        end;
      end;
      Owner.Service.AudioMoveToAlbum(AAlbumID, ATracksToMove);
      Owner.Service.AudioAdd(ATracksToAdd, AAlbumID);
    finally
      ATracksToMove.Free;
      ATracksToAdd.Free;
    end;
    Owner.DataStorage.NotifyMyMusicChanged;
  end;
end;

procedure TAIMPVKMenuItemAddToMyMusic.NameValidationProc(
  Sender: TObject; const AValueIndex: Integer; const AValue: UnicodeString; var AIsValid: Boolean);
begin
  AIsValid := AValue <> '';
end;

{ TAIMPVKMenuItemCreateSmartPlaylist }

function TAIMPVKMenuItemCreateSmartPlaylist.GetState: TAIMPVKItemState;
var
  ACategory: TAIMPVKCategory;
  AData: string;
  AGroupPath: string;
begin
  if GetInfo(ACategory, AData, AGroupPath) then
  begin
    if TAIMPVKSmartPlaylistsFactory.CanCreate(ACategory, AData) then
      Result := [isEnabled, isVisible]
    else
      Result := [isVisible];
  end
  else
    Result := [];
end;

procedure TAIMPVKMenuItemCreateSmartPlaylist.OnExecute(Sender: IInterface);

  function CreatePlaylistName(const AGroupPath: string): string;
  const
    Separator = ' - ';
  begin
    Result := LangLoadString('AIMPVKPlugin\Caption') + Separator +
      acStringReplace(ExcludeTrailingPathDelimiter(AGroupPath), PathDelim, Separator);
  end;

var
  ACategory: TAIMPVKCategory;
  AData: string;
  AGroupPath: string;
  APlaylist: IAIMPPlaylist;
  APlaylistProperties: IAIMPPropertyList;
  AService: IAIMPServicePlaylistManager2;
begin
  if CoreGetService(IAIMPServicePlaylistManager2, AService) and GetInfo(ACategory, AData, AGroupPath) then
  begin
    if Succeeded(AService.CreatePlaylist(MakeString(CreatePlaylistName(AGroupPath)), True, APlaylist)) then
    begin
      APlaylistProperties := APlaylist as IAIMPPropertyList;
      APlaylistProperties.SetValueAsObject(AIMP_PLAYLIST_PROPID_PREIMAGE, TAIMPVKSmartPlaylistsFactory.New(ACategory, AData));
      APlaylist.ReloadFromPreimage;
    end;
  end;
end;

function TAIMPVKMenuItemCreateSmartPlaylist.GetInfo(out ACategory: TAIMPVKCategory; out AData, AGroupPath: string): Boolean;

  function GetActiveFilter(out AFilter: IAIMPMLDataFilter): Boolean;
  var
    AServiceUI: IAIMPServiceMusicLibraryUI;
    APath: IAIMPString;
  begin
    Result := CoreGetService(IAIMPServiceMusicLibraryUI, AServiceUI) and Succeeded(AServiceUI.GetGroupingFilter(AFilter));
    if Result then
    begin
      if Succeeded(AServiceUI.GetGroupingFilterPath(APath)) then
        AGroupPath := IAIMPStringToString(APath);
    end;
  end;

  function IsOurStorageActive: Boolean;
  var
    AIntf: IUnknown;
    AService: IAIMPServiceMusicLibrary;
  begin
    Result := CoreGetService(IAIMPServiceMusicLibrary, AService) and
      Succeeded(AService.GetActiveStorage(IAIMPVKDataStorage, AIntf));
  end;

var
  AFilter: IAIMPMLDataFilter;
begin
  Result := IsOurStorageActive and GetActiveFilter(AFilter);
  if Result then
    ACategory := GetCategory(AFilter, AData);
end;

{ TAIMPVKMenuItemDelete }

function TAIMPVKMenuItemDelete.GetStateCore(const AFiles: TACLStringList): TAIMPVKItemState;
var
  AOwnerID, ID: Integer;
begin
  Result := [];
  if ParseOwnerAndAudioIDPair(TAIMPVKFileSystem.GetOwnerAndAudioIDPair(AFiles.First), AOwnerID, ID) then
  begin
    if AOwnerID = Owner.Service.UserID then
      Result := [isEnabled, isVisible]
    else
      Result := [isVisible];
  end;
end;

procedure TAIMPVKMenuItemDelete.OnExecuteCore(const AFiles: TACLStringList);
var
  AAudioID: Integer;
  AOwnerID: Integer;
  AUserID: Integer;
  I: Integer;
begin
  if acMessageBox(MainWindowGetHandle, LangLoadString('AIMPVKPlugin\Q1'), VKName, MB_ICONQUESTION or MB_YESNOCANCEL) = ID_YES then
  begin
    AUserID := Owner.Service.UserID;
    for I := 0 to AFiles.Count - 1 do
    begin
      if ParseOwnerAndAudioIDPair(TAIMPVKFileSystem.GetOwnerAndAudioIDPair(AFiles[I]), AOwnerID, AAudioID) then
      begin
        if AOwnerID = AUserID then
          Owner.Service.AudioDelete(AOwnerID, AAudioID);
      end;
    end;
    Owner.DataStorage.NotifyMyMusicChanged;
  end;
end;

{ TAIMPVKMenuItemDownload }

procedure TAIMPVKMenuItemDownload.OnExecuteCore(const AFiles: TACLStringList);
begin
  Owner.Downloader.Add(AFiles);
end;

{ TAIMPVKMenuItemFindLyrics }

function TAIMPVKMenuItemFindLyrics.GetMode: TAIMPVKMenuItemDataSourceMode;
begin
  Result := dsmFocusedOnly;
end;

function TAIMPVKMenuItemFindLyrics.GetStateCore(const AFiles: TACLStringList): TAIMPVKItemState;
begin
  Result := [isEnabled, isVisible];
end;

procedure TAIMPVKMenuItemFindLyrics.OnExecuteCore(const AFiles: TACLStringList);
begin
  TfrmVKLyrics.Execute(Owner, AFiles.First);
end;

end.
