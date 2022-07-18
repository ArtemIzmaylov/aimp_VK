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

unit AIMP.VK.Plugin.FileSystem;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  System.Variants,
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.Generics.Defaults,
  // ACL
  ACL.Hashes,
  ACL.Sqlite3,
  ACL.Threading,
  ACL.Utils.Common,
  ACL.Utils.FileSystem,
  ACL.Utils.Stream,
  ACL.Utils.Strings,
  // API
  apiPlayer,
  apiObjects,
  apiFileManager,
  apiWrappers,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core;

const
  sFileURISchema = 'vk';
  sFileURISchemaLen = Length(sFileURISchema);

  sFileURIPrefix = sFileURISchema + '://';
  sFileURIAuthDialog = sFileURIPrefix + 'auth/';
  sFileURITemplate = sFileURIPrefix + 'Audios/%s.mp3';

const
  sFileSystemCacheFileName = 'Audios.db';

type
  TVKURIHandler = procedure (Service: TVKService) of object;

  { TAIMPVKExtensionFileInfo }

  TAIMPVKExtensionFileInfo = class(TInterfacedObject,
    IAIMPExtensionFileInfoProvider)
  public
    // IAIMPExtensionFileInfoProvider
    function GetFileInfo(FileURI: IAIMPString; Info: IAIMPFileInfo): HRESULT; stdcall;
  end;

  { TAIMPVKExtensionFileSystem }

  TAIMPVKExtensionFileSystem = class(TAIMPPropertyList,
    IAIMPExtensionFileSystem,
    IAIMPFileSystemCommandDropSource,
    IAIMPFileSystemCommandOpenFileFolder)
  protected
    // IAIMPFileSystemCommandDropSource
    function CreateStream(FileName: IAIMPString; out Stream: IAIMPStream): HRESULT; stdcall;

    // IAIMPFileSystemCommandOpenFileFolder
    function IAIMPFileSystemCommandOpenFileFolder.CanProcess = CanOpenFileFolder;
    function IAIMPFileSystemCommandOpenFileFolder.Process = OpenFileFolder;
    function CanOpenFileFolder(FileName: IAIMPString): HRESULT; stdcall;
    function OpenFileFolder(FileName: IAIMPString): HRESULT; stdcall;

    // IAIMPExtensionFileSystem
    function DoGetValueAsObject(PropertyID: Integer): IInterface; override;
    procedure DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT); override;
  end;

  { TAIMPVKExtensionPlayerHook }

  TAIMPVKExtensionPlayerHook = class(TInterfacedObject, IAIMPExtensionPlayerHook)
  public
    // IAIMPExtensionPlayerHook
    procedure OnCheckURL(URL: IAIMPString; var Handled: LongBool); stdcall;
  end;

  {TAIMPVKCustomAttributes = class(TInterfacedObject,IAIMPFileSystemCommandFileInfo)
  protected
    // IAIMPFileSystemCommandFileInfo
    function GetFileAttrs(FileName: IAIMPString; out Attrs: TAIMPFileAttributes): HRESULT; stdcall;
    function GetFileSize(FileName: IAIMPString; out Size: Int64): HRESULT; stdcall;
    function IsFileExists(FileName: IAIMPString): HRESULT; stdcall;
  end;}

  { TAIMPVKFileSystemCacheQueryBuilder }

  TAIMPVKFileSystemCacheQueryBuilder = class
  strict private const
    ObsolescenceTimeOfCache = SecsPerDay;
  public const
    sFieldArtist = 'Artist';
    sFieldDuration = 'Duration';
    sFieldFileURI = 'FileURI';
    sFieldGenreID = 'GenreID';
    sFieldID = 'ID';
    sFieldLink = 'Link';
    sFieldLinkBirthday = 'LinkBirthday';
    sFieldLyricsID = 'LyricsID';
    sFieldOwnerID = 'OwnerID';
    sFieldAccessKey = 'AccessKey';
    sFieldTitle = 'Title';
    sTableAudios = 'VKAudios';
  public
    class function CreateAudiosTable: string;
    class function CreateAudiosTableIndex: string;
    class function DropLinks: string;
    class function GetInfo(const AFileURI: string; ACheckActuality: Boolean): string;
    class function Replace(const AAudio: TVKAudio): string;
  end;

  { TAIMPVKFileSystem }

  TAIMPVKFileSystem = class
  strict private
    class var FCache: TACLSQLiteBase;
    class var FCacheLock: TACLCriticalSection;
    class var FService: TVKService;
    class var FServiceLock: TACLCriticalSection;
    class var FURIHandlers: TDictionary<string, TVKURIHandler>;

    class function GetInfoCore(const AFileURI: string; out AAudio: TVKAudio; ACheckActuality: Boolean = False): Boolean;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure Finalize;
    class procedure Initialize(AService: TVKService; ADataBase: TACLSQLiteBase);
    class procedure VersionMigration;

    // FileURI
    class function GetInfo(const AFileURI: string; AInfo: IAIMPFileInfo): Boolean; overload;
    class function GetInfo(const AFileURI: string; out AInfo: TVKAudio; ACheckActuality: Boolean = False): Boolean; overload;
    class function GetOwnerAndAudioIDPair(const AFileURI: string): string;
    class function IsOurFile(const AFileURI: IAIMPString): Boolean; overload;
    class function IsOurFile(const AFileURI: string): Boolean; overload;
    class function MakeFileURI(AItem: TVKAudio): string; inline;

    // URI Handlers
    class function ExecURIHandler(const URI: string): Boolean;
    class function GetURIHandler(const URI: string; out Proc: TVKURIHandler): Boolean;
    class procedure RegisterURIHandler(const URI: string; Proc: TVKURIHandler);

    // Cache
    class procedure FlushLinksCache;
    class procedure UpdateCache(AItem: TVKAudio); overload;
    class procedure UpdateCache(AItems: TVKAudios); overload;
    class procedure ClearTables;
  end;

function GetSearchQuery(const AInfo: IAIMPFileInfo): string;
implementation

uses
  AIMP.VK.Plugin.Downloader;

type
  { TAIMPVKFileSystemHelper }

  TAIMPVKFileSystemHelper = class(TInterfacedObject, IVKServiceListener)
  public
    // IVKServiceListener
    procedure NotifyLogIn;
    procedure NotifyLogOut;
  end;

function ExtractArtistAndTitleFromFileName(const AFileName: UnicodeString; var AArtist, ATitle: UnicodeString): Boolean;
var
  APos: Integer;
  ATemp: UnicodeString;
begin
  ATemp := acExtractFileNameWithoutExt(AFileName);
  Result := acFindString(' - ', ATemp, APos);
  if Result then
  begin
    AArtist := Copy(ATemp, 1, APos - 1);
    ATitle := Copy(ATemp, APos + 3, MaxWord);
  end;
end;

function GetSearchQuery(const AInfo: IAIMPFileInfo): string;
var
  AArtist: string;
  ATitle: string;
begin
  AArtist := PropListGetStr(AInfo, AIMP_FILEINFO_PROPID_ARTIST);
  ATitle := PropListGetStr(AInfo, AIMP_FILEINFO_PROPID_TITLE);
  if (ATitle = '') or (AArtist = '') then
    ExtractArtistAndTitleFromFileName(PropListGetStr(AInfo, AIMP_FILEINFO_PROPID_FILENAME), AArtist, ATitle);
  if (AArtist <> '') and (ATitle <> '') then
    Result := Format('%s - %s', [AArtist, ATitle])
  else
    Result := '';
end;

{ TAIMPVKExtensionFileInfo }

function TAIMPVKExtensionFileInfo.GetFileInfo(FileURI: IAIMPString; Info: IAIMPFileInfo): HRESULT;
begin
  Result := acBoolToHRESULT(TAIMPVKFileSystem.IsOurFile(FileURI) and TAIMPVKFileSystem.GetInfo(IAIMPStringToString(FileURI), Info));
end;

{ TAIMPVKExtensionFileSystem }

function TAIMPVKExtensionFileSystem.CreateStream(FileName: IAIMPString; out Stream: IAIMPStream): HRESULT;
var
  AVKStream: TAIMPVKDownloadDropSourceStream;
begin
  if TAIMPVKFileSystem.IsOurFile(FileName) then
  try
    AVKStream := TAIMPVKDownloadDropSourceStream.Create(IAIMPStringToString(FileName));
    FileName.SetData(PChar(AVKStream.Title + '.mp3'), -1);
    Stream := AVKStream;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end
  else
    Result := E_INVALIDARG;
end;

procedure TAIMPVKExtensionFileSystem.DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT);
begin
  if PropertyID = AIMP_FILESYSTEM_PROPID_READONLY then
  begin
    Value := 1;
    Result := S_OK;
  end
  else
    inherited DoGetValueAsInt32(PropertyID, Value, Result);
end;

function TAIMPVKExtensionFileSystem.CanOpenFileFolder(FileName: IAIMPString): HRESULT;
var
  AHandler: TVKURIHandler;
begin
  Result := acBoolToHRESULT(TAIMPVKFileSystem.GetURIHandler(IAIMPStringToString(FileName), AHandler));
end;

function TAIMPVKExtensionFileSystem.OpenFileFolder(FileName: IAIMPString): HRESULT;
begin
  Result := acBoolToHRESULT(TAIMPVKFileSystem.ExecURIHandler(IAIMPStringToString(FileName)));
end;

function TAIMPVKExtensionFileSystem.DoGetValueAsObject(PropertyID: Integer): IInterface;
begin
  if PropertyID = AIMP_FILESYSTEM_PROPID_SCHEME then
    Result := MakeString(sFileURISchema)
  else
    Result := inherited DoGetValueAsObject(PropertyID);
end;

{ TAIMPVKExtensionPlayerHook }

procedure TAIMPVKExtensionPlayerHook.OnCheckURL(URL: IAIMPString; var Handled: LongBool);
var
  AInfo: TVKAudio;
begin
  if TAIMPVKFileSystem.IsOurFile(URL) and TAIMPVKFileSystem.GetInfo(IAIMPStringToString(URL), AInfo, True) then
  try
    URL.SetData(PWideChar(AInfo.URL), Length(AInfo.URL));
    Handled := True;
  finally
    AInfo.Free;
  end;
end;

{ TAIMPVKFileSystemCacheQueryBuilder }

class function TAIMPVKFileSystemCacheQueryBuilder.CreateAudiosTable: string;

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
    S.Append(sTableAudios);
    S.Append('(');

    AddField(S, sFieldID, 'INT');
    AddField(S, sFieldOwnerID, 'INT');
    AddField(S, sFieldAccessKey, 'STRING (18)');
    AddField(S, sFieldArtist, 'TEXT COLLATE UNICODE');
    AddField(S, sFieldTitle, 'TEXT COLLATE UNICODE');
    AddField(S, sFieldFileURI, 'TEXT PRIMARY KEY COLLATE UNICODE');
    AddField(S, sFieldLink, 'TEXT COLLATE UNICODE');
    AddField(S, sFieldLinkBirthday, 'Double');
    AddField(S, sFieldDuration, 'Double');
    AddField(S, sFieldGenreID, 'INT');
    AddField(S, sFieldLyricsID, 'INT', True);

    S.Append(');');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKFileSystemCacheQueryBuilder.CreateAudiosTableIndex: string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('CREATE INDEX IF NOT EXISTS ');
    S.Append(sTableAudios);
    S.Append('_');
    S.Append(sFieldFileURI);
    S.Append('_index');
    S.Append(' ON ');
    S.Append(sTableAudios);
    S.Append('(');
    S.Append(sFieldFileURI);
    S.Append(');');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKFileSystemCacheQueryBuilder.DropLinks: string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('UPDATE ');
    S.Append(sTableAudios);
    S.Append(' SET ');
    S.Append(sFieldLinkBirthday);
    S.Append(' = ');
    S.Append(0);
    S.Append(';');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKFileSystemCacheQueryBuilder.GetInfo(const AFileURI: string; ACheckActuality: Boolean): string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('SELECT * FROM ');
    S.Append(sTableAudios);
    S.Append(' WHERE (');
    S.Append(sFieldFileURI);
    S.Append(' = ');
    S.Append(PrepareData(AFileURI));
    S.Append(')');
    if ACheckActuality then
    begin
      S.Append(' AND (');
      S.Append(sFieldLinkBirthday);
      S.Append(' >= ');
      S.Append(PrepareData(Now - ObsolescenceTimeOfCache / SecsPerDay));
      S.Append(')');
    end;
    S.Append(' LIMIT 1;');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

class function TAIMPVKFileSystemCacheQueryBuilder.Replace(const AAudio: TVKAudio): string;
var
  S: TStringBuilder;
begin
  S := TStringBuilder.Create;
  try
    S.Append('REPLACE INTO ');
    S.Append(sTableAudios);
    S.Append(' VALUES(');
    S.Append(PrepareData(AAudio.ID));
    S.Append(', ');
    S.Append(PrepareData(AAudio.OwnerID));
    S.Append(', ');
    S.Append(PrepareData(AAudio.AccessKey));
    S.Append(', ');
    S.Append(PrepareData(AAudio.Artist));
    S.Append(', ');
    S.Append(PrepareData(AAudio.Title));
    S.Append(', ');
    S.Append(PrepareData(TAIMPVKFileSystem.MakeFileURI(AAudio)));
    S.Append(', ');
    S.Append(PrepareData(AAudio.URL));
    S.Append(', ');
    S.Append(PrepareData(Now));
    S.Append(', ');
    S.Append(PrepareData(AAudio.Duration));
    S.Append(', ');
    S.Append(PrepareData(AAudio.GenreID));
    S.Append(', ');
    S.Append(PrepareData(AAudio.LyricsID));
    S.Append(');');
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

{ TAIMPVKFileSystem }

class constructor TAIMPVKFileSystem.Create;
begin
  FCacheLock := TACLCriticalSection.Create;
  FServiceLock := TACLCriticalSection.Create;
  FURIHandlers := TDictionary<string, TVKURIHandler>.Create;
end;

class destructor TAIMPVKFileSystem.Destroy;
begin
  FreeAndNil(FURIHandlers);
  FreeAndNil(FServiceLock);
  FreeAndNil(FCacheLock);
end;

class procedure TAIMPVKFileSystem.Finalize;
begin
  FCacheLock.Enter;
  try
    FCache := nil;
  finally
    FCacheLock.Leave;
  end;

  FServiceLock.Enter;
  try
    if FService <> nil then
    begin
      FService.Listeners.Remove(FCache);
      FService := nil;
    end;
  finally
    FServiceLock.Leave;
  end;
end;

class procedure TAIMPVKFileSystem.VersionMigration;
begin
  //FROM 0 TO 1
  //FCacheLock.Enter;
  try
    if FCache.Version = 0 then
    begin
      FCache.Exec('DROP TABLE IF EXISTS VKAudios;');
      FCache.Version := 1;
      FCache.Compress;
    end;
  finally
    //FCacheLock.Leave;
  end;
end;

class procedure TAIMPVKFileSystem.Initialize(AService: TVKService; ADataBase: TACLSQLiteBase);
begin
  FCache := ADataBase;

  // VERSION MIGRATION
  VersionMigration;

  FCacheLock.Enter;
  try
    FCache := ADataBase;

    FCache.Exec(TAIMPVKFileSystemCacheQueryBuilder.CreateAudiosTable);
    FCache.Exec(TAIMPVKFileSystemCacheQueryBuilder.CreateAudiosTableIndex);
  finally
    FCacheLock.Leave;
  end;

  FServiceLock.Enter;
  try
    FService := AService;
    FService.Listeners.Add(TAIMPVKFileSystemHelper.Create);
  finally
    FServiceLock.Leave;
  end;
end;

class function TAIMPVKFileSystem.IsOurFile(const AFileURI: string): Boolean;
begin
  Result := acBeginsWith(AFileURI, sFileURIPrefix);
end;

class function TAIMPVKFileSystem.GetInfo(const AFileURI: string; AInfo: IAIMPFileInfo): Boolean;
var
  AAudio: TVKAudio;
begin
  Result := GetInfo(AFileURI, AAudio);
  if Result then
  try
    PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_ARTIST, AAudio.Artist);
    PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_TITLE, AAudio.Title);
    PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_GENRE, AAudio.Genre);
    PropListSetFloat(AInfo, AIMP_FILEINFO_PROPID_DURATION, AAudio.Duration);
    PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_URL, AAudio.GetRealLink);
    {PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_ALBUM, 'VK Album Name');
    PropListSetStr(AInfo, AIMP_FILEINFO_PROPID_LYRICS , 'VK Lyrics Text');}
  finally
    AAudio.Free;
  end;
end;

class function TAIMPVKFileSystem.GetInfo(const AFileURI: string; out AInfo: TVKAudio; ACheckActuality: Boolean = False): Boolean;
begin
  Result := False;
  if acGetScheme(AFileURI) = sFileURISchema then
  begin
    Result := GetInfoCore(AFileURI, AInfo, ACheckActuality);
    if (not Result or (AInfo.URL = '')) and ACheckActuality then
    begin
      FServiceLock.Enter;
      try
        if FService <> nil then
        try
          UpdateCache(FService.AudioGetByID(GetOwnerAndAudioIDPair(AFileURI)));
        except
          // do nothing
        end;
      finally
        FServiceLock.Leave;
      end;
      Result := GetInfoCore(AFileURI, AInfo);
    end;
  end;
end;

class function TAIMPVKFileSystem.GetOwnerAndAudioIDPair(const AFileURI: string): string;
begin
  Result := acChangeFileExt(acExtractFileName(AFileURI), '');
end;

class function TAIMPVKFileSystem.IsOurFile(const AFileURI: IAIMPString): Boolean;
begin
  Result := (AFileURI.GetLength > sFileURISchemaLen) and
    (acCompareStrings(AFileURI.GetData, sFileURISchema, sFileURISchemaLen, sFileURISchemaLen) = 0);
end;

class function TAIMPVKFileSystem.MakeFileURI(AItem: TVKAudio): string;
begin
  Result := Format(sFileURITemplate, [AItem.GetAPIPairs]);
end;

class function TAIMPVKFileSystem.ExecURIHandler(const URI: string): Boolean;
var
  AHandler: TVKURIHandler;
begin
  Result := GetURIHandler(URI, AHandler);
  if Result then
    AHandler(FService);
end;

class function TAIMPVKFileSystem.GetURIHandler(const URI: string; out Proc: TVKURIHandler): Boolean;
begin
  Result := FURIHandlers.TryGetValue(URI, Proc);
end;

class procedure TAIMPVKFileSystem.RegisterURIHandler(const URI: string; Proc: TVKURIHandler);
begin
  FURIHandlers.Add(URI, Proc);
end;

class procedure TAIMPVKFileSystem.FlushLinksCache;
begin
  FCacheLock.Enter;
  try
    // Links are depended from access token
    if FCache <> nil then
      FCache.Exec(TAIMPVKFileSystemCacheQueryBuilder.DropLinks);
  finally
    FCacheLock.Leave;
  end;
end;

class procedure TAIMPVKFileSystem.UpdateCache(AItem: TVKAudio);
begin
  FCacheLock.Enter;
  try
    if FCache <> nil then
      FCache.Exec(TAIMPVKFileSystemCacheQueryBuilder.Replace(AItem));
  finally
    FCacheLock.Leave;
  end;
end;

class procedure TAIMPVKFileSystem.UpdateCache(AItems: TVKAudios);
begin
  if AItems <> nil then
  begin
    FCacheLock.Enter;
    try
      if FCache <> nil then
        FCache.Transaction(
          procedure
          begin
            for var I := 0 to AItems.Count - 1 do
              UpdateCache(AItems[I]);
          end)
    finally
      FCacheLock.Leave;
    end;
  end;
end;

class procedure TAIMPVKFileSystem.ClearTables;
begin
  FCacheLock.Enter;
  try
    if FCache <> nil then
    begin
      FCache.Exec('DELETE FROM ' + PrepareData(TAIMPVKFileSystemCacheQueryBuilder.sTableAudios) + ';');
      FCache.Compress;
    end
  finally
    FCacheLock.Leave;
  end;
end;


class function TAIMPVKFileSystem.GetInfoCore(const AFileURI: string; out AAudio: TVKAudio; ACheckActuality: Boolean): Boolean;
var
  ATable: TACLSQLiteTable;
begin
  FCacheLock.Enter;
  try
    Result := (FCache <> nil) and FCache.Exec(TAIMPVKFileSystemCacheQueryBuilder.GetInfo(AFileURI, ACheckActuality), ATable);
    if Result then
    try
      AAudio := TVKAudio.Create;
      AAudio.Artist := ATable.ReadStr(TAIMPVKFileSystemCacheQueryBuilder.sFieldArtist);
      AAudio.Duration := ATable.ReadInt(TAIMPVKFileSystemCacheQueryBuilder.sFieldDuration);
      AAudio.GenreID := ATable.ReadInt(TAIMPVKFileSystemCacheQueryBuilder.sFieldGenreID);
      AAudio.ID := ATable.ReadInt(TAIMPVKFileSystemCacheQueryBuilder.sFieldID);
      AAudio.LyricsID := ATable.ReadInt(TAIMPVKFileSystemCacheQueryBuilder.sFieldLyricsID);
      AAudio.OwnerID := ATable.ReadInt(TAIMPVKFileSystemCacheQueryBuilder.sFieldOwnerID);
      AAudio.Title := ATable.ReadStr(TAIMPVKFileSystemCacheQueryBuilder.sFieldTitle);
      AAudio.URL := ATable.ReadStr(TAIMPVKFileSystemCacheQueryBuilder.sFieldLink);
      AAudio.AccessKey := ATable.ReadStr(TAIMPVKFileSystemCacheQueryBuilder.sFieldAccessKey);
    finally
      ATable.Free;
    end;
  finally
    FCacheLock.Leave;
  end;
end;

{ TAIMPVKFileSystemHelper }

procedure TAIMPVKFileSystemHelper.NotifyLogIn;
begin
  TAIMPVKFileSystem.FlushLinksCache;
end;

procedure TAIMPVKFileSystemHelper.NotifyLogOut;
begin
  // do nothing
end;

end.
