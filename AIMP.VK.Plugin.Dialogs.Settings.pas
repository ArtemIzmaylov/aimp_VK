{************************************************}
{*                                              *}
{*                AIMP VK Plugin                *}
{*                                              *}
{*                Artem Izmaylov                *}
{*                (C) 2016-2021                 *}
{*                 www.aimp.ru                  *}
{*            Mail: support@aimp.ru             *}
{*                                              *}
{************************************************}

unit AIMP.VK.Plugin.Dialogs.Settings;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.ImageList,
  System.Math,
  System.SysUtils,
  System.UITypes,
  System.Variants,
  // VCL
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ImgList,
  // VK
  AIMP.VK.Core,
  AIMP.VK.Plugin,
  AIMP.VK.Plugin.FileSystem,
  AIMP.VK.Plugin.DataStorage,
  // API
  apiWrappersUI,
  apiOptions,
  // ACL
  ACL.UI.Controls.BaseControls,
  ACL.UI.Controls.BaseEditors,
  ACL.UI.Controls.Buttons,
  ACL.UI.Controls.Category,
  ACL.UI.Controls.GroupBox,
  ACL.UI.Controls.Labels,
  ACL.UI.Controls.Panel,
  ACL.UI.Controls.TextEdit,
  ACL.UI.Dialogs,
  ACL.UI.Dialogs.FolderBrowser,
  ACL.UI.Forms,
  ACL.UI.ImageList,
  ACL.Utils.RTTI,
  ACL.Utils.Shell,
  ACL.Utils.Strings;

type

  { TAIMPVKOptionsFrame }

  TAIMPVKOptionsFrame = class(TAIMPCustomOptionsFrame)
  strict private
    FOwner: TAIMPVKPlugin;
  protected
    function CreateForm(ParentWnd: HWND; ParentControl: TWinControl): TForm; override;
    function GetName: string; override;
    procedure Notification(ID: Integer); override; stdcall;
  public
    constructor Create(AOwner: TAIMPVKPlugin);
  end;

  { TfrmVKSettings }

  TfrmVKSettings = class(TACLForm)
    B1: TACLButton;
    B2: TACLButton;
    Button_ClearCache: TACLButton;
    CB1: TACLCheckBox;
    edDownloadPath: TACLEdit;
    GB1: TACLGroupBox;
    GB2: TACLGroupBox;
    GB3: TACLGroupBox;
    ilImages: TACLImageList;
    L1: TACLLabel;
    L2: TACLLabel;
    Label_ClearCache: TACLLabel;
    pnlBackground: TACLPanel;
    lbVersion: TACLLabel;

    procedure B1Click(Sender: TObject);
    procedure B2Click(Sender: TObject);
    procedure edDownloadPathButtons0Click(Sender: TObject);
    procedure edDownloadPathButtons1Click(Sender: TObject);
    procedure ModifiedHandler(Sender: TObject);
    procedure Button_ClearCacheClick(Sender: TObject);
  strict private
    FOwner: TAIMPVKPlugin;
  protected
    procedure UpdateAuthInfo;
    procedure UpdateCacheSize;
    //
    property Owner: TAIMPVKPlugin read FOwner;
  public
    constructor Create(AOwner: TAIMPVKPlugin; AParentWnd: HWND); reintroduce;
    procedure ConfigLoad;
    procedure ConfigReset;
    procedure ConfigSave;
    procedure Localize;
  end;

implementation

uses
  apiWrappers;

{$R *.dfm}

const
  sLangSection = 'AIMPVKPlugin.Settings\';

{ TAIMPVKOptionsFrame }

constructor TAIMPVKOptionsFrame.Create(AOwner: TAIMPVKPlugin);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TAIMPVKOptionsFrame.CreateForm(ParentWnd: HWND; ParentControl: TWinControl): TForm;
begin
  Result := TfrmVKSettings.Create(FOwner, ParentWnd);
end;

function TAIMPVKOptionsFrame.GetName: string;
begin
  Result := LangLoadString('AIMPVKPlugin\Caption');
end;

procedure TAIMPVKOptionsFrame.Notification(ID: Integer);
begin
  case ID of
    AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_LOAD:
      TfrmVKSettings(Form).ConfigLoad;
    AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_SAVE:
      TfrmVKSettings(Form).ConfigSave;
    AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_LOCALIZATION:
      TfrmVKSettings(Form).Localize;
    AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_RESET:
      TfrmVKSettings(Form).ConfigReset;
  end;
end;

{ TfrmVKSettings }

constructor TfrmVKSettings.Create(AOwner: TAIMPVKPlugin; AParentWnd: HWND);
begin
  FOwner := AOwner;
  CreateParented(AParentWnd);
end;

procedure TfrmVKSettings.ConfigLoad;
begin
  edDownloadPath.Text := Owner.Downloader.OutputPath;
  GB2.CheckBox.Checked := Owner.StatusContoller.AllowBroadcast;
  CB1.Checked := Owner.StatusContoller.AllowSearch;
  UpdateAuthInfo;
end;

procedure TfrmVKSettings.ConfigReset;
begin
  edDownloadPath.Text := Owner.Downloader.GetDefaultPath;
  GB2.CheckBox.Checked := False;
  CB1.Checked := False;
end;

procedure TfrmVKSettings.ConfigSave;
begin
  Owner.Downloader.OutputPath := edDownloadPath.Text;
  Owner.StatusContoller.AllowBroadcast := GB2.CheckBox.Checked;
  Owner.StatusContoller.AllowSearch := CB1.Checked;
end;

procedure TfrmVKSettings.Localize;
begin
  LangLocalizeForm(Self, sLangSection);

  TACLDialogsStrs.FolderBrowserCaption := LangLoadString('CommonDialogs\L1');
  TACLDialogsStrs.FolderBrowserRecursive := LangLoadString('CommonDialogs\L2');
  TACLDialogsStrs.FolderBrowserNewFolder := LangLoadString('CommonDialogs\B3');;
  TACLDialogsStrs.MsgDlgButtons[mbCancel] := LangLoadString('CommonDialogs\B2');
  TACLDialogsStrs.MsgDlgButtons[mbOK] := LangLoadString('CommonDialogs\B1');
  lbVersion.Caption := FormatPluginVersion;

  UpdateAuthInfo;
  UpdateCacheSize;
end;

procedure TfrmVKSettings.UpdateAuthInfo;
var
  AUserName: string;
begin
  B2.Visible := Owner.Service.IsAuthorized;
  B1.Visible := not B2.Visible;

  if Owner.Service.UserDisplayName <> '' then
    AUserName := Owner.Service.UserDisplayName
  else
    AUserName := 'id' + IntToStr(Owner.Service.UserID);

  L1.Visible := Owner.Service.IsAuthorized;
  L1.Caption := Format(LangLoadString(sLangSection + 'L1'), [AUserName]);
  L1.URL := 'https://vk.com/id' + IntToStr(Owner.Service.UserID);
end;

procedure TfrmVKSettings.UpdateCacheSize;
begin
  Label_ClearCache.Caption := LangLoadString('AIMPVKPlugin.Settings\' + Label_ClearCache.Name) +
    ' (' + acFormatSize(TAIMPVKFileSystem.GetCacheSize) + ')';
end;

procedure TfrmVKSettings.B1Click(Sender: TObject);
begin
  TAIMPVKFileSystem.ExecURIHandler(sFileURIAuthDialog);
  UpdateAuthInfo;
end;

procedure TfrmVKSettings.B2Click(Sender: TObject);
begin
  Owner.Service.Logout;
  UpdateAuthInfo;
end;

procedure TfrmVKSettings.Button_ClearCacheClick(Sender: TObject);
begin
  TAIMPVKFileSystem.FlushCache;
  Button_ClearCache.Enabled := false;
  UpdateCacheSize;
end;

procedure TfrmVKSettings.edDownloadPathButtons0Click(Sender: TObject);
var
  APath: UnicodeString;
begin
  APath := edDownloadPath.Text;
  if TACLShellFolderBrowser.Execute(APath, Handle) then
  begin
    edDownloadPath.Text := APath;
    ModifiedHandler(Sender);
  end;
end;

procedure TfrmVKSettings.edDownloadPathButtons1Click(Sender: TObject);
begin
  ShellExecute(edDownloadPath.Text);
end;

procedure TfrmVKSettings.ModifiedHandler(Sender: TObject);
var
  AService: IAIMPServiceOptionsDialog;
begin
  if CoreGetService(IAIMPServiceOptionsDialog, AService) then
    AService.FrameModified(nil);
end;

end.
