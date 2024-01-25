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

unit AIMP.VK.Plugin.Downloader;

{$I AIMP.VK.inc}
{$R AIMP.VK.Plugin.Downloader.res}

interface

uses
  Winapi.Windows,
  System.Classes,
  System.Math,
  System.SysUtils,
  // Vcl
  Vcl.Forms,
  Vcl.Controls,
  // API
  apiCore,
  apiObjects,
  apiWrappers,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core,
  AIMP.VK.Plugin.FileSystem,
  // ACL
  ACL.Classes,
  ACL.Classes.ByteBuffer,
  ACL.Classes.StringList,
  ACL.FastCode,
  ACL.Threading,
  ACL.Threading.Pool,
  ACL.UI.TrayIcon,
  ACL.Utils.Common,
  ACL.Utils.FileSystem,
  ACL.Utils.Shell,
  ACL.Utils.Stream,
  ACL.Utils.Strings,
  ACL.Web,
  ACL.Web.Http;

type

  { TAIMPVKDownloadDropSourceStream }

  TAIMPVKDownloadDropSourceStream = class(TInterfacedObject,
    IACLHttpClientHandler,
    IAIMPStream)
  strict private
    FData: TACLCircularByteBuffer;
    FDataEvent: TACLEvent;
    FFinished: Boolean;
    FPosition: Int64;
    FSize: Int64;
    FTaskHandle: THandle;
    FTitle: UnicodeString;
  protected
    // IACLWebHttpClientHandler
    function OnAccept(const AHeaders: string; const AContentType: string; const AContentSize: Int64): LongBool;
    procedure OnComplete(const AErrorInfo: TACLWebErrorInfo; ACanceled: LongBool);
    function OnData(Data: PByte; Count: Integer): Boolean;
    procedure OnProgress(const AReadBytes: Int64; const ATotalBytes: Int64);

    // IAIMPStream
    function GetPosition: Int64; stdcall;
    function GetSize: Int64; stdcall;
    function Read(Data: PByte; Count: Cardinal): Integer; stdcall;
    function Seek(const Offset: Int64; Mode: Integer): HRESULT; stdcall;
    function SetSize(const Value: Int64): HRESULT; stdcall;
    function Write(Buffer: PByte; Count: Cardinal; Written: PDWORD = nil): HRESULT; stdcall;
  public
    constructor Create(const AFileURI: string);
    destructor Destroy; override;
    //
    property Title: UnicodeString read FTitle;
  end;

  { TAIMPVKDownloadTask }

  TAIMPVKDownloadTaskProgressEvent = procedure (const AReadBytes, ATotalBytes: Int64) of object;

  TAIMPVKDownloadTask = class(TACLTask,
    IACLHttpClientHandler)
  strict private
    FError: string;
    FErrorLog: TACLStringList;
    FFileURI: string;
    FOutputPath: string;
    FService: TVKService;
    FStream: TStream;
    FTargetFileName: string;
    FTargetFileNameIsCreatedByMe: Boolean;

    FOnProgress: TAIMPVKDownloadTaskProgressEvent;

    // IACLWebHttpClientHandler
    function OnAccept(const AHeaders: string; const AContentType: string; const AContentSize: Int64): LongBool;
    procedure OnComplete(const AErrorInfo: TACLWebErrorInfo; ACanceled: LongBool);
    function OnData(Data: PByte; Count: Integer): Boolean;
    procedure OnProgress(const AReadBytes: Int64; const ATotalBytes: Int64);
  protected
    procedure Execute; override;
  public
    constructor Create(AService: TVKService; const AOutputPath, AFileURI: string;
      AErrorLog: TACLStringList; AProgressEvent: TAIMPVKDownloadTaskProgressEvent);
  end;

  { TAIMPVKDownloader }

  TAIMPVKDownloader = class(TComponent)
  strict private const
    sConfigOutputPath = 'AIMPVKPlugin\PathForDownloads';
  strict private
    FDownloaderForm: TForm;
    FOutputPath: string;
    FService: TVKService;
    FTrayIcon: TACLTrayIcon;

    procedure HandlerBallonHintClick(Sender: TObject);
    procedure HandlerHideForm(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ShowCompleteNotify;
    procedure ShowTrayIcon;
  public
    constructor Create(AService: TVKService); reintroduce;
    procedure Add(AFiles: TACLStringList);
    function CreateTask(const AFileURI: string; AErrorLog: TACLStringList = nil;
      AProgressEvent: TAIMPVKDownloadTaskProgressEvent = nil): TACLTask;
    function GetDefaultPath: string;
    // Config
    procedure ConfigLoad(AConfig: TAIMPServiceConfig);
    procedure ConfigSave(AConfig: TAIMPServiceConfig);
    //
    property OutputPath: string read FOutputPath write FOutputPath;
  end;

implementation

uses
  AIMP.VK.Plugin,
  AIMP.VK.Plugin.Dialogs.Downloader;

{ TAIMPVKDownloadDropSourceStream }

constructor TAIMPVKDownloadDropSourceStream.Create(const AFileURI: string);
var
  AInfo: TVKAudio;
begin
  inherited Create;
  FData := TACLCircularByteBuffer.Create(10 * SIZE_ONE_MEGABYTE);
  FDataEvent := TACLEvent.Create(True, False);

  if TAIMPVKFileSystem.GetInfo(AFileURI, AInfo, True) then
  try
    FTitle := Format('%s - %s', [AInfo.Artist, AInfo.Title]);
    FTaskHandle := TACLHttpClient.Request(hmGet, AInfo.URL, Self);
    FDataEvent.WaitFor;
  finally
    AInfo.Free;
  end;
end;

destructor TAIMPVKDownloadDropSourceStream.Destroy;
begin
  TACLHttpClient.Cancel(FTaskHandle, True);
  FTaskHandle := 0;
  FreeAndNil(FDataEvent);
  FreeAndNil(FData);
  inherited Destroy;
end;

function TAIMPVKDownloadDropSourceStream.OnAccept(const AHeaders, AContentType: string; const AContentSize: Int64): LongBool;
begin
  FSize := AContentSize;
  FDataEvent.Signal;
  Result := True;
end;

procedure TAIMPVKDownloadDropSourceStream.OnComplete(const AErrorInfo: TACLWebErrorInfo; ACanceled: LongBool);
begin
  FTaskHandle := 0;
  FFinished := True;
  FDataEvent.Signal;
end;

function TAIMPVKDownloadDropSourceStream.OnData(Data: PByte; Count: Integer): Boolean;
var
  ABuffer: PByte;
  ASize: Integer;
begin
  Result := True;
  while Count > 0 do
  begin
    FData.BeginWrite(ABuffer, ASize);
    try
      ASize := Min(ASize, Count);
      FastMove(Data^, ABuffer^, ASize);
      Dec(Count, ASize);
      Inc(Data, ASize);
    finally
      FData.EndWrite(ASize);
      FDataEvent.Signal;
    end;
    if Count > 0 then
      Sleep(100);
  end;
end;

procedure TAIMPVKDownloadDropSourceStream.OnProgress(const AReadBytes, ATotalBytes: Int64);
begin
  // do nothing
end;

function TAIMPVKDownloadDropSourceStream.GetPosition: Int64;
begin
  Result := FPosition;
end;

function TAIMPVKDownloadDropSourceStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TAIMPVKDownloadDropSourceStream.Read(Data: PByte; Count: Cardinal): Integer;
var
  ABuffer: PByte;
  ASize: Integer;
begin
  Result := 0;
  while Count > 0 do
  begin
    if not FFinished then
      FDataEvent.WaitFor;

    FData.BeginRead(ABuffer, ASize);
    try
      ASize := Min(ASize, Count);
      FastMove(ABuffer^, Data^, ASize);
      Inc(FPosition, ASize);
      Inc(Result, ASize);
      Dec(Count, ASize);
      Inc(Data, ASize);
    finally
      FData.EndRead(ASize);
    end;

    if ASize = 0 then
    begin
      if FFinished and (FData.DataAmount = 0) then
        Break;
      FDataEvent.Reset;
    end;
  end;
end;

function TAIMPVKDownloadDropSourceStream.Seek(const Offset: Int64; Mode: Integer): HRESULT;
var
  APosition: Int64;
begin
  case Mode of
    AIMP_STREAM_SEEKMODE_FROM_BEGINNING:
      APosition := Offset;
    AIMP_STREAM_SEEKMODE_FROM_CURRENT:
      APosition := FPosition + Offset;
    AIMP_STREAM_SEEKMODE_FROM_END:
      APosition := FSize + Offset;
  else
    Exit(E_INVALIDARG);
  end;

  if APosition <> FPosition then
  begin
  {$IFDEF DEBUG}
    raise EInvalidOperation.Create(ClassName + '.Seek');
  {$ENDIF}
    Result := E_NOTIMPL;
  end
  else
    Result := S_OK;
end;

function TAIMPVKDownloadDropSourceStream.SetSize(const Value: Int64): HRESULT;
begin
  Result := E_NOTIMPL;
end;

function TAIMPVKDownloadDropSourceStream.Write(Buffer: PByte; Count: Cardinal; Written: PDWORD): HRESULT;
begin
  Result := E_NOTIMPL;
end;

{ TAIMPVKDownloadTask }

constructor TAIMPVKDownloadTask.Create(AService: TVKService; const AOutputPath, AFileURI: string;
  AErrorLog: TACLStringList; AProgressEvent: TAIMPVKDownloadTaskProgressEvent);
begin
  inherited Create;
  FService := AService;
  FFileURI := AFileURI;
  FErrorLog := AErrorLog;
  FOnProgress := AProgressEvent;
  FOutputPath := IncludeTrailingPathDelimiter(AOutputPath);
end;

procedure TAIMPVKDownloadTask.Execute;
var
  AInfo: TVKAudio;
begin
  if TAIMPVKFileSystem.GetInfo(FFileURI, AInfo, True) then
  try
    if not IsCanceled then
    try
      FTargetFileNameIsCreatedByMe := False;
      FTargetFileName := Format('%d-%d-%s - %s.mp3', [AInfo.OwnerID, AInfo.ID, AInfo.Artist, AInfo.Title]);
      FTargetFileName := acValidateFileName(FTargetFileName);
      FTargetFileName := FOutputPath + FTargetFileName;
      try
        TACLHttpClient.Request(hmGet, AInfo.URL, Self, nil, nil, []);
      except
        on E: Exception do
          FError := E.ToString;
      end;
    finally
      FreeAndNil(FStream);
      if FTargetFileNameIsCreatedByMe and ((FError <> '') or IsCanceled) then
        acDeleteFile(FTargetFileName);
    end;
    if FError <> '' then
      FErrorLog.Add(FError);
  finally
    AInfo.Free;
  end;
end;

function TAIMPVKDownloadTask.OnAccept(const AHeaders, AContentType: string; const AContentSize: Int64): LongBool;
begin
  Result := True;
  if not ForceDirectories(FOutputPath) then
    RaiseLastOSError;
  if acFileExists(FTargetFileName) then
  begin
    if acFileSize(FTargetFileName) = AContentSize then
      Exit(False);
    FTargetFileName := acGetFreeFileName(FTargetFileName);
  end;
  FStream := TFileStream.Create(FTargetFileName, fmCreate);
  FTargetFileNameIsCreatedByMe := True;
end;

procedure TAIMPVKDownloadTask.OnComplete(const AErrorInfo: TACLWebErrorInfo; ACanceled: LongBool);
begin
  if (AErrorInfo.ErrorCode <> 0) and (AErrorInfo.ErrorCode <> acWebErrorNotAccepted) then
    FError := AErrorInfo.ToString;
end;

function TAIMPVKDownloadTask.OnData(Data: PByte; Count: Integer): Boolean;
begin
  Result := (FStream.Write(Data^, Count) = Count) and not IsCanceled;
end;

procedure TAIMPVKDownloadTask.OnProgress(const AReadBytes, ATotalBytes: Int64);
begin
  if Assigned(FOnProgress) then
    FOnProgress(AReadBytes, ATotalBytes);
end;

{ TAIMPVKDownloader }

constructor TAIMPVKDownloader.Create(AService: TVKService);
begin
  inherited Create(nil);
  FService := AService;
end;

procedure TAIMPVKDownloader.Add(AFiles: TACLStringList);
begin
  if AFiles.Count > 0 then
  begin
    CheckIsMainThread;
    if FDownloaderForm = nil then
    begin
      FDownloaderForm := TfrmVKDownloader.Create(Self);
      FDownloaderForm.OnHide := HandlerHideForm;
      FDownloaderForm.FreeNotification(Self);
      FDownloaderForm.Show;
    end;
    TfrmVKDownloader(FDownloaderForm).Add(AFiles);
  end;
end;

function TAIMPVKDownloader.CreateTask(const AFileURI: string;
  AErrorLog: TACLStringList = nil; AProgressEvent: TAIMPVKDownloadTaskProgressEvent = nil): TACLTask;
begin
  Result := TAIMPVKDownloadTask.Create(FService, OutputPath, AFileURI, AErrorLog, AProgressEvent);
end;

function TAIMPVKDownloader.GetDefaultPath: string;
begin
  Result := ShellGetMyMusic + 'VKMusic\';
end;

procedure TAIMPVKDownloader.ConfigLoad(AConfig: TAIMPServiceConfig);
begin
  OutputPath := AConfig.ReadString(sConfigOutputPath, GetDefaultPath);
end;

procedure TAIMPVKDownloader.ConfigSave(AConfig: TAIMPServiceConfig);
begin
  if (OutputPath = '') or acSameText(OutputPath, GetDefaultPath) then
    AConfig.Delete(sConfigOutputPath)
  else
    AConfig.WriteString(sConfigOutputPath, OutputPath);
end;

procedure TAIMPVKDownloader.Notification(AComponent: TComponent; Operation: TOperation);
var
  AShowTooltip: Boolean;
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FDownloaderForm) then
  begin
    AShowTooltip := FDownloaderForm.ModalResult = mrOk;
    FDownloaderForm := nil;
    if AShowTooltip then
      ShowCompleteNotify
    else
      FreeAndNil(FTrayIcon);
  end;
end;

procedure TAIMPVKDownloader.ShowCompleteNotify;
begin
  ShowTrayIcon;
  FTrayIcon.BalloonHint(VKName, LangLoadString('AIMPVKPlugin\L7'), bitInfo);
end;

procedure TAIMPVKDownloader.ShowTrayIcon;
begin
  if FTrayIcon = nil then
  begin
    FTrayIcon := TACLTrayIcon.Create(Self);
    FTrayIcon.Icon.Handle := LoadIcon(HInstance, 'TRAYICON');
    FTrayIcon.OnClick := HandlerBallonHintClick;
    FTrayIcon.OnBallonHintClick := HandlerBallonHintClick;
    FTrayIcon.Hint := VKName;
    FTrayIcon.IconVisible := True;
    FTrayIcon.Enabled := True;
  end;
end;

procedure TAIMPVKDownloader.HandlerBallonHintClick(Sender: TObject);
begin
  if FDownloaderForm <> nil then
    FDownloaderForm.Show
  else
    ShellExecute(OutputPath);

  FreeAndNil(FTrayIcon);
end;

procedure TAIMPVKDownloader.HandlerHideForm(Sender: TObject);
begin
  ShowTrayIcon;
end;

end.
