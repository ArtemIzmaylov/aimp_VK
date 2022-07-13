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

unit AIMP.VK.Plugin.SmartPlaylists;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  System.Classes,
  // API
  apiObjects,
  apiPlaylists,
  apiThreading,
  apiMusicLibrary,
  apiWrappers,
  // ACL
  ACL.Utils.Stream,
  // VK
  AIMP.VK.Plugin.DataStorage;

type

  { TAIMPVKSmartPlaylist }

  TAIMPVKSmartPlaylist = class(TAIMPPropertyList,
    IAIMPPlaylistPreimageDataProvider,
    IAIMPPlaylistPreimage)
  strict private
    FCategory: TAIMPVKCategory;
    FData: UnicodeString;
    FDataStorage: IAIMPVKDataStorage;

    procedure PopulateFiles(AOwner: IAIMPTaskOwner; AList: IAIMPObjectList);
  protected
    procedure DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT); override;
    function DoGetValueAsObject(PropertyID: Integer): IInterface; override;
  public
    constructor Create(ADataStorage: IAIMPVKDataStorage; ACategory: TAIMPVKCategory; const AData: UnicodeString);
    // IAIMPPlaylistPreimage
    procedure Finalize; stdcall;
    procedure Initialize(Listener: IAIMPPlaylistPreimageListener); stdcall;
    function ConfigLoad(Stream: IAIMPStream): HRESULT; stdcall;
    function ConfigSave(Stream: IAIMPStream): HRESULT; stdcall;
    function ExecuteDialog(OwnerWndHanle: HWND): HRESULT; stdcall;
    // IAIMPPlaylistPreimageDataProvider
    function GetFiles(Owner: IAIMPTaskOwner; out Flags: Cardinal; out List: IAIMPObjectList): HRESULT; stdcall;
  end;

  { TAIMPVKSmartPlaylistsFactory }

  TAIMPVKSmartPlaylistsFactory = class(TInterfacedObject, IAIMPExtensionPlaylistPreimageFactory)
  strict private
    FDataStorage: IAIMPVKDataStorage;
  protected
    // IAIMPExtensionPlaylistPreimageFactory
    function CreatePreimage(out Intf: IAIMPPlaylistPreimage): HRESULT; stdcall;
    function GetFlags: Cardinal; stdcall;
    function GetID(out ID: IAIMPString): HRESULT; stdcall;
    function GetName(out Name: IAIMPString): HRESULT; stdcall;
  public
    constructor Create(ADataStorage: IAIMPVKDataStorage);
    class function CanCreate(ACategory: TAIMPVKCategory; const AData: UnicodeString): Boolean;
    class function New(ACategory: TAIMPVKCategory; const AData: UnicodeString): IAIMPPlaylistPreimage;
  end;

implementation

uses
  AIMP.VK.Plugin;

const
  VKPreimageFactoryID = VKPluginIDBase + '.PreimageFactory';

{ TAIMPVKSmartPlaylist }

constructor TAIMPVKSmartPlaylist.Create(
  ADataStorage: IAIMPVKDataStorage; ACategory: TAIMPVKCategory; const AData: UnicodeString);
begin
  inherited Create;
  FDataStorage := ADataStorage;
  FCategory := ACategory;
  FData := AData;
end;

procedure TAIMPVKSmartPlaylist.Finalize;
begin
  // do nothing
end;

procedure TAIMPVKSmartPlaylist.Initialize(Listener: IAIMPPlaylistPreimageListener);
begin
  // do nothing
end;

function TAIMPVKSmartPlaylist.ConfigLoad(Stream: IAIMPStream): HRESULT;
var
  AStream: TAIMPStreamWrapper;
begin
  try
    AStream := TAIMPStreamWrapper.Create(Stream);
    try
      FCategory := TAIMPVKCategory(AStream.ReadByte);
      FData := AStream.ReadStringWithLength;
    finally
      AStream.Free;
    end;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TAIMPVKSmartPlaylist.ConfigSave(Stream: IAIMPStream): HRESULT;
var
  AStream: TAIMPStreamWrapper;
begin
  try
    AStream := TAIMPStreamWrapper.Create(Stream);
    try
      AStream.WriteByte(Ord(FCategory));
      AStream.WriteStringWithLength(FData);
    finally
      AStream.Free;
    end;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

function TAIMPVKSmartPlaylist.ExecuteDialog(OwnerWndHanle: HWND): HRESULT;
begin
  Result := E_NOTIMPL;
end;

function TAIMPVKSmartPlaylist.GetFiles(Owner: IAIMPTaskOwner; out Flags: Cardinal; out List: IAIMPObjectList): HRESULT;
begin
  try
    CoreCreateObject(IAIMPObjectList, List);
    Flags := AIMP_PLAYLIST_ADD_FLAGS_NOCHECKFORMAT or AIMP_PLAYLIST_ADD_FLAGS_NOEXPAND or AIMP_PLAYLIST_ADD_FLAGS_NOTHREADING;
    if TAIMPVKSmartPlaylistsFactory.CanCreate(FCategory, FData) then
      PopulateFiles(Owner, List);
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

procedure TAIMPVKSmartPlaylist.DoGetValueAsInt32(PropertyID: Integer; out Value: Integer; var Result: HRESULT);
begin
  case PropertyID of
    AIMP_PLAYLISTPREIMAGE_PROPID_AUTOSYNC:
      begin
        Result := S_OK;
        Value := 1;
      end;
    AIMP_PLAYLISTPREIMAGE_PROPID_HASDIALOG:
      begin
        Result := S_OK;
        Value := 0;
      end;
  else
    inherited DoGetValueAsInt32(PropertyID, Value, Result);
  end;
end;

function TAIMPVKSmartPlaylist.DoGetValueAsObject(PropertyID: Integer): IInterface;
begin
  if PropertyID = AIMP_PLAYLISTPREIMAGE_PROPID_FACTORYID then
    Result := MakeString(VKPreimageFactoryID)
  else
    Result := inherited DoGetValueAsObject(PropertyID);
end;

procedure TAIMPVKSmartPlaylist.PopulateFiles(AOwner: IAIMPTaskOwner; AList: IAIMPObjectList);
var
  AFields: IAIMPObjectList;
  AOffset: Integer;
  ASelection: IAIMPVKDataProviderTable;
begin
  CoreCreateObject(IAIMPObjectList, AFields);
  AFields.Add(MakeString(VKDSFieldFileName));

  AOffset := 0;
  repeat
    ASelection := TAIMPVKDataProviderTable.Create(FDataStorage as TAIMPVKDataStorage, FCategory, FData, AFields, AOffset, True);
    if ASelection.HasData then
    repeat
      AList.Add(MakeString(ASelection.GetValueAsString(0)));
    until (AOwner <> nil) and AOwner.IsCanceled or not ASelection.NextRow;

    AOffset := AList.GetCount;
  until (AOwner <> nil) and AOwner.IsCanceled or False {or not ASelection.HasNextPage}; {$MESSAGE 'TODO - HasNextPage'}
end;

{ TAIMPVKSmartPlaylistsFactory }

constructor TAIMPVKSmartPlaylistsFactory.Create(ADataStorage: IAIMPVKDataStorage);
begin
  FDataStorage := ADataStorage;
end;

class function TAIMPVKSmartPlaylistsFactory.CanCreate(ACategory: TAIMPVKCategory; const AData: UnicodeString): Boolean;
begin
  Result := (ACategory in [TAIMPVKCategory.Music, TAIMPVKCategory.MusicFromPlaylist, TAIMPVKCategory.MusicFromWall]) and (AData <> '');
end;

class function TAIMPVKSmartPlaylistsFactory.New(ACategory: TAIMPVKCategory; const AData: UnicodeString): IAIMPPlaylistPreimage;
var
  AFactory: IAIMPExtensionPlaylistPreimageFactory;
  AService: IAIMPServicePlaylistManager2;
begin
  Result := nil;
  if CoreGetService(IAIMPServicePlaylistManager2, AService) then
  begin
    if Succeeded(AService.GetPreimageFactoryByID(MakeString(VKPreimageFactoryID), AFactory)) then
    begin
      if AFactory is TAIMPVKSmartPlaylistsFactory then
        Result := TAIMPVKSmartPlaylist.Create(TAIMPVKSmartPlaylistsFactory(AFactory).FDataStorage, ACategory, AData);
    end;
  end;
end;

function TAIMPVKSmartPlaylistsFactory.CreatePreimage(out Intf: IAIMPPlaylistPreimage): HRESULT;
begin
  if FDataStorage <> nil then
  begin
    Intf := TAIMPVKSmartPlaylist.Create(FDataStorage, Unknown, '');
    Result := S_OK;
  end
  else
    Result := E_FAIL;
end;

function TAIMPVKSmartPlaylistsFactory.GetFlags: Cardinal;
begin
  Result := AIMP_PREIMAGEFACTORY_FLAG_CONTEXTDEPENDENT;
end;

function TAIMPVKSmartPlaylistsFactory.GetID(out ID: IAIMPString): HRESULT;
begin
  ID := MakeString(VKPreimageFactoryID);
  Result := S_OK;
end;

function TAIMPVKSmartPlaylistsFactory.GetName(out Name: IAIMPString): HRESULT;
begin
  Result := LangLoadString('AIMPVKPlugin\Caption', Name);
end;

end.
