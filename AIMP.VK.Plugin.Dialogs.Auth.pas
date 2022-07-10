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

unit AIMP.VK.Plugin.Dialogs.Auth;

{$I AIMP.VK.inc}

interface

uses
  // System
  Winapi.Windows,
  Winapi.Messages,
  Winapi.UrlMon,
  System.Classes,
  System.ImageList,
  System.Math,
  System.SysUtils,
  System.Variants,
  SHDocVw,
  // Vcl
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ImgList,
  Vcl.OleCtrls,
  Vcl.StdCtrls,
  // ACL
  ACL.Threading,
  ACL.UI.Forms,
  ACL.UI.Controls.BaseControls,
  ACL.UI.Controls.BaseEditors,
  ACL.UI.Controls.TextEdit,
  ACL.UI.ImageList,
  ACL.Utils.FileSystem,
  ACL.Utils.Registry,
  ACL.Utils.Shell,
  ACL.Utils.Strings,
  ACL.Web,
  // VK
  AIMP.VK.Core,
  AIMP.VK.Plugin.FileSystem;

type

  { TfrmVKAuth }

  TfrmVKAuth = class(TACLForm)
    WebBrowser: TWebBrowser;
    edURL: TACLEdit;
    ilGlyphs: TACLImageList;
    procedure WebBrowserNavigateComplete2(ASender: TObject; const pDisp: IDispatch; const URL: OleVariant);
    procedure edURLKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edURLNavigateClick(Sender: TObject);
    procedure edURLOpenInBrowserClick(Sender: TObject);
    procedure WebBrowserNavigateError(ASender: TObject; const pDisp: IDispatch; const URL, Frame,
      StatusCode: OleVariant; var Cancel: WordBool);
  strict private
    FService: TVKService;
  protected
    procedure DoShow; override;
    //
    property Service: TVKService read FService;
  public
    constructor Create(AService: TVKService; AOwnerWndHandle: THandle); reintroduce;
    class procedure Execute(AService: TVKService);
  end;

implementation

uses
  apiWrappers;

{$R *.dfm}

type
  TIEMode = (iemUnknown, iemIE7, iemIE8, iemIE9, iemIE10);

function GetIEVersion: Integer;
var
  AKey: HKEY;
  AValue: string;
begin
  Result := 0;
  if acRegOpenRead(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Internet Explorer', AKey) then
  try
    AValue := acRegReadStr(AKey, 'svcVersion');
    if AValue = '' then
      AValue := acRegReadStr(AKey, 'Version');
    Result := StrToIntDef(Copy(AValue, 1, Pos('.', AValue) - 1), 0);
  finally
    acRegClose(AKey);
  end;
end;

procedure SetEmbeddedWebBrowserMode(AMode: TIEMode);
const
  Map: array[TIEMode] of Integer = (0, 7000, 8888, 9999, 10001);
  REG_KEY = 'Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION';
var
  AKey: HKEY;
begin
  AKey := acRegOpenCreate(HKEY_CURRENT_USER, REG_KEY);
  if AKey <> 0 then
  try
    acRegWriteInt(AKey, acExtractFileName(acSelfExeName), Map[AMode]);
  finally
    acRegClose(AKey);
  end;
end;

{ TfrmVKAuth }

class procedure TfrmVKAuth.Execute(AService: TVKService);
begin
  case Sign(GetIEVersion - 9) of
    0: SetEmbeddedWebBrowserMode(iemIE9);
    1: SetEmbeddedWebBrowserMode(iemIE10);
  else
    SetEmbeddedWebBrowserMode(iemIE8); // < IE8 is not supported by VK
  end;

  with TfrmVKAuth.Create(AService, MainWindowGetHandle) do
  try
    Caption := LangLoadString('AIMPVKPlugin\L1');
    ShowModal;
  finally
    Free;
  end;
end;

constructor TfrmVKAuth.Create(AService: TVKService; AOwnerWndHandle: THandle);
begin
  inherited CreateDialog(AOwnerWndHandle);
  FService := AService;
  if TACLStayOnTopHelper.IsStayOnTop(AOwnerWndHandle) then
    FormStyle := fsStayOnTop;
end;

procedure TfrmVKAuth.DoShow;
begin
  inherited DoShow;
//  'http://www.whoishostingthis.com/tools/user-agent/'
  WebBrowser.Navigate(Service.AuthorizationGetURL);
end;

procedure TfrmVKAuth.edURLNavigateClick(Sender: TObject);
begin
  WebBrowser.Navigate(edURL.Text);
end;

procedure TfrmVKAuth.edURLOpenInBrowserClick(Sender: TObject);
begin
  ShellExecuteURL(Service.AuthorizationGetURL);
end;

procedure TfrmVKAuth.edURLKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    edURLNavigateClick(Sender);
    Key := 0;
  end;
end;

procedure TfrmVKAuth.WebBrowserNavigateComplete2(ASender: TObject; const pDisp: IDispatch; const URL: OleVariant);
begin
  edURL.Text := URL;
  if acBeginsWith(URL, sVKCallback) then
  begin
    if Service.AuthorizationParseAnswer(URL) then
      ModalResult := mrOk;
  end;
end;

procedure TfrmVKAuth.WebBrowserNavigateError(ASender: TObject; const pDisp: IDispatch;
  const URL, Frame, StatusCode: OleVariant; var Cancel: WordBool);
begin
  // do nothing
end;

initialization
  TAIMPVKFileSystem.RegisterURIHandler(sFileURIAuthDialog, TfrmVKAuth.Execute);
end.

