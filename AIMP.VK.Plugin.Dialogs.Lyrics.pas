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

unit AIMP.VK.Plugin.Dialogs.Lyrics;

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
  System.Actions,
  System.Variants,
  // VCL
  Vcl.ActnList,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ImgList,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core,
  AIMP.VK.Plugin,
  AIMP.VK.Plugin.FileSystem,
  // API
  apiFileManager,
  apiObjects,
  apiWrappers,
  // ACL
  ACL.Threading.Pool,
  ACL.Utils.Strings,
  ACL.UI.Forms,
  ACL.UI.Controls.BaseControls,
  ACL.UI.Controls.BaseEditors,
  ACL.UI.Controls.Memo,
  ACL.UI.Controls.Labels;

type

  { TAIMPVKLoadLyrics }

  TAIMPVKLoadLyricsCompleteEvent = procedure (const ATitle, ALyrics: string; ACanceled: Boolean) of object;

  TAIMPVKLoadLyrics = class(TACLTask)
  strict private
    FFileURI: string;
    FLyrics: string;
    FService: TVKService;
    FTitle: string;

    FOnComplete: TAIMPVKLoadLyricsCompleteEvent;

    function CreateInfo(const AFileURI: string): TVKAudio;
    function GetFileInfo(const AFileURI: string; out Info: IAIMPFileInfo): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AService: TVKService; const AFileURI: string; ACompleteEvent: TAIMPVKLoadLyricsCompleteEvent);
  end;

  { TfrmVKLyrics }

  TfrmVKLyrics = class(TACLForm)
    acSelectAll: TAction;
    ActionList: TActionList;
    lbLoading: TACLLabel;
    meLyrics: TACLMemo;

    procedure FormDestroy(Sender: TObject);
    procedure meLyricsKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure acSelectAllExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  protected
    FOwner: TAIMPVKPlugin;
    FTaskHandle: THandle;
    FTitle: string;

    procedure AsyncComplete(const ATitle, ALyrics: string; ACanceled: Boolean);
    function CanCloseByEscape: Boolean; override;
    procedure Initialize(AOwner: TAIMPVKPlugin);
    procedure Load(const AFileURI: string);
    procedure UpdateCaption;
    procedure WMUser(var Message: TMessage); message WM_USER;
  public
    constructor CreateDialog(AOwnerHandle: NativeUInt; ANew: Boolean = False); override;
    class procedure Execute(AOwner: TAIMPVKPlugin; const AFileURI: string);
  end;

implementation

{$R *.dfm}

function aimpExtractFileName(const S: string): string;
var
  AService: IAIMPServiceFileURI;
  AString: IAIMPString;
begin
  Result := ExtractFileName(S);
  if CoreGetService(IAIMPServiceFileURI, AService) then
  begin
    if Succeeded(AService.ExtractFileName(MakeString(S), AString)) then
      Result := IAIMPStringToString(AString);
  end;
end;

{ TAIMPVKLoadLyrics }

constructor TAIMPVKLoadLyrics.Create(AService: TVKService;
  const AFileURI: string; ACompleteEvent: TAIMPVKLoadLyricsCompleteEvent);
begin
  inherited Create;
  FService := AService;
  FFileURI := AFileURI;
  FOnComplete := ACompleteEvent;
end;

procedure TAIMPVKLoadLyrics.Execute;
var
  AInfo: TVKAudio;
begin
  try
    AInfo := CreateInfo(FFileURI);
    if AInfo <> nil then
    try
      FTitle := Format('%s - %s', [AInfo.Artist, AInfo.Title]);
      if not IsCanceled then
        FLyrics := FService.AudioGetLyrics(AInfo.LyricsID);
    finally
      AInfo.Free;
    end;
  except
    on E: Exception do
      FLyrics := E.ToString;
  end;
  FOnComplete(FTitle, FLyrics, IsCanceled);
end;

function TAIMPVKLoadLyrics.CreateInfo(const AFileURI: string): TVKAudio;
var
  AAudios: TVKAudios;
  AFileInfo: IAIMPFileInfo;
  I: Integer;
begin
  Result := nil;
  if TAIMPVKFileSystem.IsOurFile(AFileURI) then
  begin
    if not (TAIMPVKFileSystem.GetInfo(AFileURI, Result) or IsCanceled) then
      Result := FService.AudioGetByID(TAIMPVKFileSystem.GetOwnerAndAudioIDPair(AFileURI));
  end
  else
    if GetFileInfo(AFileURI, AFileInfo) and not IsCanceled then
    begin
      AAudios := FService.AudioSearch(GetSearchQuery(AFileInfo));
      try
        for I := 0 to AAudios.Count - 1 do
        begin
          if AAudios.List[I].LyricsID > 0 then
            Exit(AAudios.Extract(AAudios.List[I]));
        end;
      finally
        AAudios.Free;
      end;
    end;
end;

function TAIMPVKLoadLyrics.GetFileInfo(const AFileURI: string; out Info: IAIMPFileInfo): Boolean;
var
  AService: IAIMPServiceFileInfo;
begin
  Result := False;
  if CoreGetService(IAIMPServiceFileInfo, AService) then
  begin
    CoreCreateObject(IAIMPFileInfo, Info);
    Result := Succeeded(AService.GetFileInfoFromFileURI(MakeString(AFileURI), AIMP_SERVICE_FILEINFO_FLAG_DONTUSEAUDIODECODERS, Info));
  end;
end;

{ TfrmVKLyrics }

constructor TfrmVKLyrics.CreateDialog(AOwnerHandle: NativeUInt; ANew: Boolean);
begin
  inherited CreateDialog(AOwnerHandle, ANew);
  if TACLStayOnTopHelper.IsStayOnTop(AOwnerHandle) then
    FormStyle := fsStayOnTop;
end;

class procedure TfrmVKLyrics.Execute(AOwner: TAIMPVKPlugin; const AFileURI: string);
begin
  with TfrmVKLyrics.CreateDialog(MainWindowGetHandle) do
  begin
    Initialize(AOwner);
    Load(AFileURI);
    Show;
  end;
end;

procedure TfrmVKLyrics.AsyncComplete(const ATitle, ALyrics: string; ACanceled: Boolean);
begin
  FTaskHandle := 0;
  if not ACanceled then
    SendMessage(Handle, WM_USER, WPARAM(@ATitle), LPARAM(@ALyrics));
end;

function TfrmVKLyrics.CanCloseByEscape: Boolean;
begin
  Result := True;
end;

procedure TfrmVKLyrics.Initialize(AOwner: TAIMPVKPlugin);
begin
  FOwner := AOwner;
  FOwner.Forms.Add(Self);
end;

procedure TfrmVKLyrics.Load(const AFileURI: string);
begin
  FTitle := aimpExtractFileName(AFileURI);
  lbLoading.Caption := LangLoadString('AIMPVKPlugin\L4');
  FTaskHandle := TaskDispatcher.Run(TAIMPVKLoadLyrics.Create(FOwner.Service, AFileURI, AsyncComplete));
  UpdateCaption;
end;

procedure TfrmVKLyrics.UpdateCaption;
begin
  Caption := Format(LangLoadString('AIMPVKPlugin\L3'), [FTitle]);
end;

procedure TfrmVKLyrics.WMUser(var Message: TMessage);
begin
  FTitle := IfThenW(PString(Message.WParam)^, FTitle);
  meLyrics.Text := PString(Message.LParam)^;
  meLyrics.Visible := True;
  meLyrics.SetFocus;
  UpdateCaption;
end;

procedure TfrmVKLyrics.acSelectAllExecute(Sender: TObject);
begin
  meLyrics.InnerMemo.SelectAll;
end;

procedure TfrmVKLyrics.meLyricsKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TfrmVKLyrics.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TfrmVKLyrics.FormDestroy(Sender: TObject);
begin
  FOwner.Forms.Extract(Self);
  TaskDispatcher.Cancel(FTaskHandle, True);
end;

end.
