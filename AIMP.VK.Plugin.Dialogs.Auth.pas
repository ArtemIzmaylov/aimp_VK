{************************************************}
{*                                              *}
{*                AIMP VK Plugin                *}
{*                                              *}
{*                Artem Izmaylov                *}
{*                (C) 2016-2023                 *}
{*                 www.aimp.ru                  *}
{*            Mail: support@aimp.ru             *}
{*                                              *}
{************************************************}

unit AIMP.VK.Plugin.Dialogs.Auth;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.UrlMon,
  // System
  System.Classes,
  System.ImageList,
  System.Math,
  System.SysUtils,
  System.Variants,
  // Vcl
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Imaging.pngimage,
  Vcl.ImgList,
  // ACL
  ACL.Threading,
  ACL.UI.Controls.BaseControls,
  ACL.UI.Controls.BaseEditors,
  ACL.UI.Controls.Buttons,
  ACL.UI.Controls.GroupBox,
  ACL.UI.Controls.Labels,
  ACL.UI.Controls.TextEdit,
  ACL.UI.Forms,
  ACL.UI.ImageList,
  ACL.Utils.FileSystem,
  ACL.Utils.Registry,
  ACL.Utils.Shell,
  ACL.Utils.Strings,
  // VK
  AIMP.VK.Core,
  AIMP.VK.Plugin.FileSystem;

type

  { TfrmVKAuth }

  TfrmVKAuth = class(TACLForm)
    btnGrantAccess: TACLButton;
    btnOpenURL: TACLButton;
    edAnswer: TACLEdit;
    GB1: TACLGroupBox;
    GB2: TACLGroupBox;
    GB3: TACLGroupBox;
    imHint1: TImage;
    L3: TACLLabel;
    L4: TACLLabel;
    procedure btnOpenURLClick(Sender: TObject);
    procedure btnGrantAccessClick(Sender: TObject);
    procedure edAnswerChange(Sender: TObject);
  strict private
    FService: TVKService;
  protected
    procedure ApplyLocalizations;
    property Service: TVKService read FService;
  public
    constructor Create(AService: TVKService; AOwnerWndHandle: THandle); reintroduce;
    class procedure Execute(AService: TVKService);
  end;

implementation

uses
  apiWrappers;

{$R *.dfm}

{ TfrmVKAuth }

class procedure TfrmVKAuth.Execute(AService: TVKService);
begin
  with TfrmVKAuth.Create(AService, MainWindowGetHandle) do
  try
    ApplyLocalizations;
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
  edAnswerChange(nil);
end;

procedure TfrmVKAuth.ApplyLocalizations;
begin
  Caption := LangLoadString('AIMPVKPlugin\L1');
  GB1.Caption := LangLoadString('AIMPVKPlugin.Auth\L1');
  GB2.Caption := LangLoadString('AIMPVKPlugin.Auth\L2');
  GB3.Caption := LangLoadString('AIMPVKPlugin.Auth\L5');
  L3.Caption := LangLoadString('AIMPVKPlugin.Auth\L3');
  L4.Caption := LangLoadString('AIMPVKPlugin.Auth\L4');
  btnGrantAccess.Caption := LangLoadString('AIMPVKPlugin.Auth\B2');
  btnOpenURL.Caption := LangLoadString('AIMPVKPlugin.Auth\B1');
end;

procedure TfrmVKAuth.btnGrantAccessClick(Sender: TObject);
var
  AAnswer: string;
begin
  AAnswer := edAnswer.Text;
  if acBeginsWith(AAnswer, sVKCallback) and Service.AuthorizationParseAnswer(AAnswer) then
    ModalResult := mrOk
  else
    raise EInvalidArgument.Create(LangLoadString('AIMPVKPlugin.Auth\E1'));
end;

procedure TfrmVKAuth.btnOpenURLClick(Sender: TObject);
begin
  edAnswer.Text := '';
  ShellExecuteURL(Service.AuthorizationGetURL);
end;

procedure TfrmVKAuth.edAnswerChange(Sender: TObject);
begin
  btnGrantAccess.Enabled := edAnswer.Text <> '';
end;

initialization
  TAIMPVKFileSystem.RegisterURIHandler(sFileURIAuthDialog, TfrmVKAuth.Execute);
end.

