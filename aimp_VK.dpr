library aimp_VK;

{$I AIMP.VK.inc}

{$R *.res}
{$R aimp_VK_icon.res}

uses
  Windows,
  Forms,
  apiPlugin,
  AIMP.VK.Classes in 'AIMP.VK.Classes.pas',
  AIMP.VK.Core in 'AIMP.VK.Core.pas',
  AIMP.VK.Plugin in 'AIMP.VK.Plugin.pas',
  AIMP.VK.Plugin.DataStorage in 'AIMP.VK.Plugin.DataStorage.pas',
  AIMP.VK.Plugin.Downloader in 'AIMP.VK.Plugin.Downloader.pas',
  AIMP.VK.Plugin.FileSystem in 'AIMP.VK.Plugin.FileSystem.pas',
  AIMP.VK.Plugin.Menus in 'AIMP.VK.Plugin.Menus.pas',
  AIMP.VK.Plugin.StatusBroadcaster in 'AIMP.VK.Plugin.StatusBroadcaster.pas',
  AIMP.VK.Plugin.Dialogs.Auth in 'AIMP.VK.Plugin.Dialogs.Auth.pas',
  AIMP.VK.Plugin.Dialogs.Downloader in 'AIMP.VK.Plugin.Dialogs.Downloader.pas' {frmVKDownloader},
  AIMP.VK.Plugin.Dialogs.Lyrics in 'AIMP.VK.Plugin.Dialogs.Lyrics.pas' {frmVKLyrics},
  AIMP.VK.Plugin.Dialogs.Settings in 'AIMP.VK.Plugin.Dialogs.Settings.pas' {frmVKSettings},
  AIMP.VK.Plugin.SmartPlaylists in 'AIMP.VK.Plugin.SmartPlaylists.pas';

  function AIMPPluginGetHeader(out Header: IAIMPPlugin): HRESULT; stdcall;
  begin
    Header := TAIMPVKPlugin.Create;
    Result := S_OK;
  end;

exports
  AIMPPluginGetHeader;

begin
  Application.Icon.Handle := LoadIcon(HInstance, 'MAINICON');
end.
