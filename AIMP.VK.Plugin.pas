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

unit AIMP.VK.Plugin;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.SysUtils,
  // ACL
  ACL.Classes,
  ACL.Classes.Collections,
  ACL.Sqlite3,
  ACL.Utils.Common,
  ACL.Utils.Strings,
  ACL.Web,
  // VK
  AIMP.VK.Core,
  AIMP.VK.Plugin.DataStorage,
  AIMP.VK.Plugin.Downloader,
  AIMP.VK.Plugin.SmartPlaylists,
  AIMP.VK.Plugin.StatusBroadcaster,
  // API
  apiCore,
  apiFileManager,
  apiMenu,
  apiMusicLibrary,
  apiObjects,
  apiOptions,
  apiPlayer,
  apiPlaylists,
  apiPlugin,
  apiWrappers,
  apiWrappersUI,
  // Wrappers
  AIMPCustomPlugin;

const
  FileNameForUserDB = 'AIMPVKPlugin.db';
  VKName = 'AIMP VK Plugin';

  VKAppID = 5776857;
  VKAppSecret = '';
  VKAppUserAgent = 'com.vk.windows_app/20302';

  VKPluginIDBase = 'AIMP.VK';

type

  { TAIMPVKPlugin }

  TAIMPVKPlugin = class(TAIMPCustomPlugin)
  strict private
    FDataBase: TACLSQLiteBase;
    FDataStorage: IAIMPVKDataStorage;
    FDownloader: TAIMPVKDownloader;
    FForms: TACLObjectList;
    FService: TVKService;
    FStatusContoller: TAIMPVKStatusBroadcastController;

    procedure ConfigLoad;
    procedure ConfigSave;
    function GetWorkPath: string;
  protected
    function InfoGet(Index: Integer): PWideChar; override; stdcall;
    function InfoGetCategories: Cardinal; override; stdcall;
    function Initialize(Core: IAIMPCore): HRESULT; override; stdcall;
    procedure Finalize; override; stdcall;
    procedure RegisterMenus;
  public
    property DataStorage: IAIMPVKDataStorage read FDataStorage;
    property Downloader: TAIMPVKDownloader read FDownloader;
    property Forms: TACLObjectList read FForms;
    property Service: TVKService read FService;
    property StatusContoller: TAIMPVKStatusBroadcastController read FStatusContoller;
    property WorkPath: string read GetWorkPath;
  end;

implementation

uses
  AIMP.VK.Plugin.Menus,
  AIMP.VK.Plugin.FileSystem,
  AIMP.VK.Plugin.Dialogs.Settings;

const
{$I AIMP.VK.Version.inc}

function FormatPluginVersion: UnicodeString;
begin
  Result := Format('v%d.%s.%d %s', [__VersionID div 1000,
    acFormatTrackNo((__VersionID mod 1000) div 10), __VersionBuild, __VersionPrefix]);
end;

{ TAIMPVKPlugin }

function TAIMPVKPlugin.InfoGet(Index: Integer): PWideChar;
begin
  case Index of
    AIMP_PLUGIN_INFO_NAME:
      Result := PWideChar('VK Plugin ' + FormatPluginVersion);
    AIMP_PLUGIN_INFO_SHORT_DESCRIPTION:
      Result := 'Provides an ability to play music from VK.com';
    AIMP_PLUGIN_INFO_AUTHOR:
      Result := 'Keller';
  else
    Result := '';
  end;
end;

function TAIMPVKPlugin.InfoGetCategories: Cardinal;
begin
  Result := AIMP_PLUGIN_CATEGORY_ADDONS;
end;

function TAIMPVKPlugin.Initialize(Core: IAIMPCore): HRESULT;
var
  AIntf: IAIMPServiceMusicLibrary;
begin
  Result := inherited Initialize(Core);
  if Failed(Result) or not ForceDirectories(WorkPath) or not CoreGetService(IAIMPServiceMusicLibrary, AIntf) then
    Exit(E_NOTIMPL);

  TACLWebSettings.UserAgent := VKAppUserAgent;

  FForms := TACLObjectList.Create(True);
  FDataBase := TACLSQLiteBase.Create(WorkPath + FileNameForUserDB);
  FService := TVKService.Create(VKAppID, VKAppSecret, [vkpFriends, vkpGroups, vkpNotify, vkpAudio, vkpStatus, vkpOffline, vkpWall]);
  TAIMPVKFileSystem.Initialize(Service, FDataBase);
  FDownloader := TAIMPVKDownloader.Create(Service);
  FDataStorage := TAIMPVKDataStorage.Create(Service, FDataBase);
  FStatusContoller := TAIMPVKStatusBroadcastController.Create(Service);
  ConfigLoad;

  Core.RegisterExtension(IAIMPServiceFileInfo, TAIMPVKExtensionFileInfo.Create);
  Core.RegisterExtension(IAIMPServiceFileSystems, TAIMPVKExtensionFileSystem.Create);
  Core.RegisterExtension(IAIMPServiceMusicLibrary, FDataStorage);
  Core.RegisterExtension(IAIMPServicePlaylistManager2, TAIMPVKSmartPlaylistsFactory.Create(DataStorage));
  Core.RegisterExtension(IAIMPServiceOptionsDialog, TAIMPVKOptionsFrame.Create(Self));
  Core.RegisterExtension(IAIMPServicePlayer, TAIMPVKExtensionPlayerHook.Create);
  RegisterMenus;
end;

procedure TAIMPVKPlugin.Finalize;
begin
  ConfigSave;
  FForms.Clear;
  FDataStorage := nil;
  FreeAndNil(FStatusContoller);
  FreeAndNil(FDownloader);
  TAIMPVKFileSystem.Finalize;
  inherited Finalize;
  FreeAndNil(FDataBase);
  FreeAndNil(FService);
  FreeAndNil(FForms);
end;

procedure TAIMPVKPlugin.RegisterMenus;

  procedure RegisterMenusIn(const AMenuIDBase: string; AParentID: Integer; ADataSource: IAIMPVKMenuItemDataSource);
  begin
    TAIMPVKMenuItemDownload.Register(Self, ADataSource, AMenuIDBase + '.Download', AParentId);
    TAIMPVKMenuItemFindLyrics.Register(Self, ADataSource, AMenuIDBase + '.FindLyrics', AParentId);
    TAIMPVKMenuItemAddToPlaylist.Register(Self, ADataSource, AMenuIDBase + '.AddToPlaylist', AParentId);
    TAIMPVKMenuItemAddToMyMusic.Register(Self, ADataSource, AMenuIDBase + '.AddToMyMusic', AParentId);
    AddSimpleMenuItem(AParentId, '-', nil);
  end;

var
  AMLDS: IAIMPVKMenuItemDataSource;
  APLDS: IAIMPVKMenuItemDataSource;
begin
  APLDS := TAIMPVKPLMenuItemDataSource.Create;
  AMLDS := TAIMPVKMLMenuItemDataSource.Create;
  RegisterMenusIn(VKPluginIDBase + '.Menus.PL', AIMP_MENUID_PLAYER_PLAYLIST_CONTEXT_FUNCTIONS, APLDS);
  RegisterMenusIn(VKPluginIDBase + '.Menus.ML', AIMP_MENUID_ML_TABLE_CONTEXT_FUNCTIONS, AMLDS);

  TAIMPVKMenuItemDelete.Register(Self, AMLDS, VKPluginIDBase + '.Menus.ML.Delete', AIMP_MENUID_ML_TABLE_CONTEXT_DELETION);

  TAIMPVKMenuItemCreateSmartPlaylist.Register(Self, TAIMPVKMLSmartPlaylistDataSource.Create,
    VKPluginIDBase + '.Menus.CreateSmartPL', AIMP_MENUID_ML_TREE_CONTEXT_FUNCTIONS);
end;

procedure TAIMPVKPlugin.ConfigLoad;
var
  AConfig: TAIMPServiceConfig;
begin
  if Service <> nil then
  begin
    AConfig := ServiceGetConfig;
    try
      Service.UserID := AConfig.ReadInteger('AIMPVKPlugin\UserID');
      Service.UserDisplayName := AConfig.ReadString('AIMPVKPlugin\UserDisplayName');
      Service.Token := AConfig.ReadString('AIMPVKPlugin\AccessToken');
      StatusContoller.AllowBroadcast := AConfig.ReadInteger('AIMPVKPlugin\StatusAllowBroadcast') <> 0;
      StatusContoller.AllowSearch := AConfig.ReadInteger('AIMPVKPlugin\StatusAllowSearch') <> 0;
      Downloader.ConfigLoad(AConfig);
    finally
      AConfig.Free;
    end;
  end;
end;

procedure TAIMPVKPlugin.ConfigSave;
var
  AConfig: TAIMPServiceConfig;
begin
  if Service <> nil then
  begin
    AConfig := ServiceGetConfig;
    try
      AConfig.WriteString('AIMPVKPlugin\UserDisplayName', Service.UserDisplayName);
      AConfig.WriteString('AIMPVKPlugin\AccessToken', Service.Token);
      AConfig.WriteInteger('AIMPVKPlugin\UserID', Service.UserID);
      AConfig.WriteInteger('AIMPVKPlugin\StatusAllowBroadcast', Ord(StatusContoller.AllowBroadcast));
      AConfig.WriteInteger('AIMPVKPlugin\StatusAllowSearch', Ord(StatusContoller.AllowSearch));
      Downloader.ConfigSave(AConfig);
    finally
      AConfig.Free;
    end;
  end;
end;

function TAIMPVKPlugin.GetWorkPath: string;
begin
  Result := CoreGetProfilePath
end;

end.
