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

unit AIMP.VK.Plugin.Dialogs.Downloader;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.Math,
  System.SysUtils,
  System.UITypes,
  System.Variants,
  // VCL
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core,
  AIMP.VK.Plugin.Downloader,
  AIMP.VK.Plugin.FileSystem,
  // API
  apiFileManager,
  apiWrappers,
  apiObjects,
  // ACL
  ACL.Classes,
  ACL.Classes.StringList,
  ACL.Classes.Timer,
  ACL.Threading.Pool,
  ACL.UI.AeroPeek,
  ACL.UI.Forms,
  ACL.UI.DropSource,
  ACL.UI.DropTarget,
  ACL.UI.Controls.TreeList.Options,
  ACL.UI.Controls.TreeList.SubClass,
  ACL.UI.Controls.TreeList.Types,
  ACL.UI.Controls.Buttons,
  ACL.UI.Controls.BaseControls,
  ACL.UI.Controls.CompoundControl,
  ACL.UI.Controls.TreeList,
  ACL.UI.Controls.Labels,
  ACL.UI.Controls.ProgressBar;

type

  { TfrmVKDownloader }

  TfrmVKDownloader = class(TACLForm)
    lbProcessingFile: TACLLabel;
    pbCurrentProgress: TACLProgressBar;
    pbTotalProgress: TACLProgressBar;
    tlQueue: TACLTreeList;
    tmProgress: TACLTimer;
    btnCancel: TACLButton;

    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure tmProgressTimer(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  strict private
    FCancelConfirmation: Boolean;
    FErrorLog: TACLStringList;
    FFilesProcessed: Integer;
    FTaskbarProgress: TACLAeroPeek;
    FTaskHandle: THandle;

    function GetTitle(const AFileName: string): string;
    procedure HandlerTaskComplete;
    procedure HandlerTaskProgress(const APosition, ACount: Int64);
  protected
    procedure ApplyLocalizations;
    procedure CheckStartTask;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure UpdateCaption;
    procedure UpdateProgress;
    //
    property ErrorLog: TACLStringList read FErrorLog;
    property TaskbarProgress: TACLAeroPeek read FTaskbarProgress;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Add(AFiles: TACLStringList);
  end;

implementation

uses
  ACL.Threading;

{$R *.dfm}

{ TfrmVKDownloader }

constructor TfrmVKDownloader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FErrorLog := TACLStringList.Create;
  FTaskbarProgress := TACLAeroPeek.Create(Handle);
  FTaskbarProgress.ShowProgress := True;
  ApplyLocalizations;
end;

destructor TfrmVKDownloader.Destroy;
begin
  TaskDispatcher.Cancel(FTaskHandle, True);
  TACLMainThread.Unsubscribe(HandlerTaskComplete);
  FreeAndNil(FTaskbarProgress);
  FreeAndNil(FErrorLog);
  inherited Destroy;
end;

procedure TfrmVKDownloader.Add(AFiles: TACLStringList);
var
  ANode: TACLTreeListNode;
  I: Integer;
begin
  tlQueue.BeginUpdate;
  try
    for I := 0 to AFiles.Count - 1 do
    begin
      ANode := tlQueue.RootNode.AddChild;
      ANode.AddValue(GetTitle(AFiles[I]));
      ANode.AddValue(AFiles[I]);
    end;
  finally
    tlQueue.EndUpdate;
  end;
  CheckStartTask;
end;

procedure TfrmVKDownloader.ApplyLocalizations;
begin
  btnCancel.Caption := LangLoadString('CommonDialogs\B2');
  UpdateCaption;
end;

procedure TfrmVKDownloader.CheckStartTask;
var
  ANode: TACLTreeListNode;
begin
  if (FTaskHandle = 0) and (tlQueue.RootNode.ChildrenCount > 0) then
  begin
    ANode := tlQueue.RootNode.Children[0];
    lbProcessingFile.Caption := ANode.Caption;
    FTaskHandle := TaskDispatcher.Run(
      TAIMPVKDownloader(Owner).CreateTask(ANode[1], ErrorLog, HandlerTaskProgress),
      HandlerTaskComplete, tmcmSyncPostponed);
    ANode.Free;
    tmProgress.Enabled := True;
  end;
end;

procedure TfrmVKDownloader.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
end;

procedure TfrmVKDownloader.UpdateCaption;
var
  ACaption: string;
begin
  ACaption := LangLoadString('AIMPVKPlugin\L6');
  if pbTotalProgress.Max > 0 then
    ACaption := '[' + FormatFloat('0.00', 100 * pbTotalProgress.Progress / pbTotalProgress.Max) + '%] ' + ACaption;
  Caption := ACaption;
end;

procedure TfrmVKDownloader.UpdateProgress;
begin
  pbTotalProgress.Max := FFilesProcessed + tlQueue.RootNode.ChildrenCount + Ord(FTaskHandle <> 0);
  pbTotalProgress.Progress := FFilesProcessed + pbCurrentProgress.Progress / Max(1, pbCurrentProgress.Max);
  TaskbarProgress.UpdateProgress(Trunc(100 * pbTotalProgress.Progress), Trunc(100 * pbTotalProgress.Max));
  UpdateCaption;
end;

function TfrmVKDownloader.GetTitle(const AFileName: string): string;
var
  AInfo: TVKAudio;
begin
  if TAIMPVKFileSystem.GetInfo(AFileName, AInfo, False) then
  try
    Result := AInfo.Artist + ' - ' + AInfo.Title;
  finally
    AInfo.Free;
  end
  else
    Result := AFileName;
end;

procedure TfrmVKDownloader.HandlerTaskComplete;
begin
  FTaskHandle := 0;
  tmProgress.Enabled := False;
  pbCurrentProgress.Progress := 0;
  Inc(FFilesProcessed);
  UpdateProgress;

  if ModalResult = mrCancel then
  begin
    Close;
    Exit;
  end;

  CheckStartTask;
  if FTaskHandle = 0 then
  begin
    if ErrorLog.Count > 0 then
    begin
      TaskbarProgress.ProgressState := appsStopped;
      MessageDlg(ErrorLog.Text, mtWarning, [mbOK], 0);
    end;
    ModalResult := mrOk;
    Close;
  end;
end;

procedure TfrmVKDownloader.HandlerTaskProgress(const APosition, ACount: Int64);
begin
  pbCurrentProgress.Max := ACount;
  pbCurrentProgress.Progress := APosition;
end;

procedure TfrmVKDownloader.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FCancelConfirmation then
    Action := caNone
  else
    if FTaskHandle <> 0 then
      Action := caHide
    else
      Action := caFree;
end;

procedure TfrmVKDownloader.btnCancelClick(Sender: TObject);

  function AskForConfirmation: Boolean;
  begin
    FCancelConfirmation := True;
    try
      Result := MessageDlg(LangLoadString('AIMPVKPlugin\L5'), mtWarning, [mbOK, mbCancel], 0, mbCancel) = mrOk;
    finally
      FCancelConfirmation := False;
    end;
  end;

begin
  if ((FTaskHandle <> 0) or tlQueue.RootNode.HasChildren) and AskForConfirmation then
  begin
    if ModalResult = mrNone then
    begin
      ModalResult := mrCancel;
      TaskDispatcher.Cancel(FTaskHandle, True);
      Exit;
    end;
  end;
  if ModalResult <> mrNone then
    Close;
end;

procedure TfrmVKDownloader.tmProgressTimer(Sender: TObject);
begin
  UpdateProgress;
end;

end.


