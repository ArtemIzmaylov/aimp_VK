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

unit AIMP.VK.Plugin.StatusBroadcaster;

{$I AIMP.VK.inc}

interface

uses
  Windows,
  // API
  apiFileManager,
  apiMessages,
  apiObjects,
  apiPlayer,
  // ACL
  ACL.Classes,
  ACL.Threading.Pool,
  // VK
  AIMP.VK.Classes,
  AIMP.VK.Core,
  AIMP.VK.Plugin.FileSystem;

type

  { TAIMPVKStatusBroadcastController }

  TAIMPVKStatusBroadcastController = class(TACLUnknownObject, IAIMPMessageHook)
  strict private
    FAllowBroadcast: Boolean;
    FAllowSearch: Boolean;
    FService: TVKService;

    procedure SetAllowBroadcast(AValue: Boolean);
  protected
    FTaskHandle: THandle;

    // IAIMPMessageHook
    procedure CoreMessage(Message: Cardinal; Param1: Integer; Param2: Pointer; var Result: HRESULT); stdcall;
    //
    procedure Broadcast(AInfo: IAIMPFileInfo);
    procedure TrackStarted;
    procedure TrackStopped;
  public
    constructor Create(AService: TVKService);
    destructor Destroy; override;
    //
    property AllowBroadcast: Boolean read FAllowBroadcast write SetAllowBroadcast;
    property AllowSearch: Boolean read FAllowSearch write FAllowSearch;
    property Service: TVKService read FService;
  end;

  { TAIMPVKStatusBroadcaster }

  TAIMPVKStatusBroadcaster = class(TACLTask)
  strict private
    FInfo: IAIMPFileInfo;
    FOwner: TAIMPVKStatusBroadcastController;

    function GetService: TVKService;
    function GetVKTrack(const AFileInfo: IAIMPFileInfo; out ATrack: TVKAudio): Boolean;
  protected
    procedure Execute; override;
    //
    property Service: TVKService read GetService;
  public
    constructor Create(AInfo: IAIMPFileInfo; AOwner: TAIMPVKStatusBroadcastController);
  end;

implementation

uses
  apiWrappers;

{ TAIMPVKStatusBroadcastController }

constructor TAIMPVKStatusBroadcastController.Create(AService: TVKService);
var
  ADispatcher: IAIMPServiceMessageDispatcher;
begin
  inherited Create;
  FService := AService;
  if CoreGetService(IAIMPServiceMessageDispatcher, ADispatcher) then
    ADispatcher.Hook(Self)
end;

destructor TAIMPVKStatusBroadcastController.Destroy;
var
  ADispatcher: IAIMPServiceMessageDispatcher;
begin
  if CoreGetService(IAIMPServiceMessageDispatcher, ADispatcher) then
    ADispatcher.Unhook(Self);
  TaskDispatcher.Cancel(FTaskHandle, True);
  inherited Destroy;
end;

procedure TAIMPVKStatusBroadcastController.CoreMessage(Message: Cardinal; Param1: Integer; Param2: Pointer; var Result: HRESULT);
begin
  if Message = AIMP_MSG_EVENT_STREAM_START_SUBTRACK then
    TrackStarted;
  if Message = AIMP_MSG_EVENT_PLAYER_STATE then
  begin
    if Param1 = 2 then
      TrackStarted
    else
      TrackStopped;
  end;
end;

procedure TAIMPVKStatusBroadcastController.Broadcast(AInfo: IAIMPFileInfo);
begin
  TaskDispatcher.Cancel(FTaskHandle, True);
  FTaskHandle := TaskDispatcher.Run(TAIMPVKStatusBroadcaster.Create(AInfo, Self));
end;

procedure TAIMPVKStatusBroadcastController.TrackStarted;
var
  AFileInfo: IAIMPFileInfo;
  AService: IAIMPServicePlayer;
begin
  if AllowBroadcast then
  begin
    if CoreGetService(IID_IAIMPServicePlayer, AService) and Succeeded(AService.GetInfo(AFileInfo)) then
      Broadcast(AFileInfo);
  end;
end;

procedure TAIMPVKStatusBroadcastController.TrackStopped;
begin
  if AllowBroadcast then
    Broadcast(nil);
end;

procedure TAIMPVKStatusBroadcastController.SetAllowBroadcast(AValue: Boolean);
begin
  if FAllowBroadcast <> AValue then
  begin
    FAllowBroadcast := AValue;
    if not AllowBroadcast then
      Broadcast(nil);
  end;
end;

{ TAIMPVKStatusBroadcaster }

constructor TAIMPVKStatusBroadcaster.Create(AInfo: IAIMPFileInfo; AOwner: TAIMPVKStatusBroadcastController);
begin
  inherited Create;
  FInfo := AInfo;
  FOwner := AOwner;
end;

procedure TAIMPVKStatusBroadcaster.Execute;
var
  ATrack: TVKAudio;
begin
  try
    if (FInfo <> nil) and GetVKTrack(FInfo, ATrack) then
    try
      if not Canceled then
        Service.AudioSetBroadcast(ATrack.GetAPIPairs);
    finally
      ATrack.Free;
    end
    else
      if not Canceled then
        Service.AudioSetBroadcast('');
  finally
    FOwner.FTaskHandle := 0;
  end;
end;

function TAIMPVKStatusBroadcaster.GetService: TVKService;
begin
  Result := FOwner.Service;
end;

function TAIMPVKStatusBroadcaster.GetVKTrack(const AFileInfo: IAIMPFileInfo; out ATrack: TVKAudio): Boolean;
var
  ATracks: TVKAudios;
begin
  Result := TAIMPVKFileSystem.GetInfo(PropListGetStr(AFileInfo, AIMP_FILEINFO_PROPID_FILENAME), ATrack);
  if not Result then
  try
    if FOwner.AllowSearch and not Canceled then
    begin
      ATracks := Service.AudioSearch(GetSearchQuery(AFileInfo));
      try
        Result := ATracks.Count > 0;
        if Result then
          ATrack := ATracks.Extract(ATracks.First)
      finally
        ATracks.Free;
      end;
    end;
  except
    ATrack := nil;
  end;
end;

end.
