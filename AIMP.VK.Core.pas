{************************************************}
{*                                              *}
{*                AIMP VK Plugin                *}
{*                                              *}
{*                Artem Izmaylov                *}
{*                (C) 2016-2024                 *}
{*                 www.aimp.ru                  *}
{*            Mail: support@aimp.ru             *}
{*                                              *}
{************************************************}

unit AIMP.VK.Core;

{$I AIMP.VK.inc}
{.$DEFINE VK_DUMP}

interface

uses
  Winapi.Windows,
  // System
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Math,
  System.SysUtils,
  // VK
  AIMP.VK.Classes,
  // ACL
  ACL.Hashes,
  ACL.Classes.StringList,
  ACL.FileFormats.XML,
  ACL.Threading,
  ACL.Utils.Stream,
  ACL.Web,
  ACL.Web.Http;

const
  sVKCallback = 'https://oauth.vk.com/blank.html';

type
  TVKLoadFromNodeProc = procedure (ANode: TACLXMLNode) of object;

  { EVKError }

  EVKError = class(Exception)
  strict private
    FErrorCode: Integer;
  public
    constructor Create(const AErrorText: string; const AErrorCode: Integer); overload;
    constructor Create(const AMessage: string); overload;
    //
    property ErrorCode: Integer read FErrorCode;
  end;

  { TVKParams }

  TVKParams = class(TACLStringList)
  public
    function Add(const AParam, AValue: string): TVKParams; overload;
    function Add(const AParam: string; AValue: Integer): TVKParams; overload;
    function Add(const AParam: string; AValue: TList<Integer>): TVKParams; overload;
    function ToString: string; override;
  end;

  { IVKServiceListener }

  IVKServiceListener = interface
  ['{3E65B54B-00A4-4F47-B2D6-2E8D8A2B9B17}']
    procedure NotifyLogIn;
    procedure NotifyLogOut;
  end;

  { TVKServicePermissions }

  TVKServicePermission = (vkpNotify, vkpFriends, vkpPhotos, vkpAudio, vkpVideo,
    vkpDocs, vkpNotes, vkpPages, vkpStatus, vkpOffers, vkpQuestions, vkpWall, vkpGroups,
    vkpMessages, vkpEmail, vkpNotifications, vkpStats, vkpAds, vkpMarket, vkpOffline);
  TVKServicePermissions = set of TVKServicePermission;

  TVKServicePermissionsHelper = record helper for TVKServicePermissions
  strict private const
    Map: array[TVKServicePermission] of Integer = (
      1, 2, 4, 8, 16, 131072, 2048, 128, 1024, 32, 64, 8192, 262144,
      4096, 4194304, 524288, 1048576, 32768, 134217728, 65536
    );
    MapStr: array[TVKServicePermission] of string = (
      'notify', 'friends', 'photos', 'audio', 'video', 'docs', 'notes', 'pages',
      'status', 'offers', 'questions', 'wall', 'groups', 'messages', 'email',
      'notifications', 'stats', 'ads', 'market', 'offline'
    );
  public
    constructor Create(Code: Integer);
    function ToInteger: Integer;
    function ToString: string;
  end;

  { TVKService }

  TVKService = class
  public const
    MaxPlaylistGetCount = 100;
    MaxAudioGetCount = 6000;
    MaxAudioPopularCount = 1000;
    MaxAudioRecommendationCount = 1000;
    MaxAudioSearchCount = 300;
    MaxFavePostCount = 100;
  strict private
    FAppID: Integer;
    FAppSecret: string;
    FListeners: TThreadList<IUnknown>;
    FPemissions: TVKServicePermissions;
    FToken: string;
    FUserID: Integer;
    FUserDisplayName: string;

    function BuildCommandLine(const AMethod: string; AParams: TVKParams): string;
    procedure CheckAuthorization;
    procedure CheckID(ID: Integer);
    function JsonToXml(const AStream: TBytesStream): TACLXMLDocument;
    function ResolveAlias(const AAlias, AVarName, AMethodName, ANodeName: string): Integer;
    procedure UpdateUserInfo;
  protected
    function Command(const AMethod: string; AParams: TVKParams): TACLXMLDocument; overload;
    procedure Command(const AMethod: string; AParams: TVKParams; AProc: TVKLoadFromNodeProc); overload;

    // Events
    procedure NotifyLogIn;
    procedure NotifyLogOut;

    property AppID: Integer read FAppID;
    property AppSecret: string read FAppSecret;
  public
    constructor Create(AAppID: Integer; const AAppSecret: string; APemissions: TVKServicePermissions);
    destructor Destroy; override;

    // Authorization
    function AuthorizationGetURL(const ACallbackURL: string = ''): string;
    function AuthorizationParseAnswer(const AAnswer: string): Boolean;
    function IsAuthorized: Boolean;
    procedure Logout;

    // Audios
    procedure AudioAdd(const OwnerID, AudioID, AlbumID: Integer); overload;
    procedure AudioAdd(const AAudios: TList<TPair<Integer, Integer>>; AlbumID: Integer); overload;
    function AudioCreatePlaylist(const Title: string): Integer;
    procedure AudioDelete(const OwnerID, AudioID: Integer; PlaylistID: Integer = 0);
    function AudioGet(OwnerID, Offset: Integer; Count: Integer = MaxAudioGetCount): TVKAudios;
    function AudioGetFromPlaylist(OwnerID, PlaylistID, Offset: Integer; Count: Integer = MaxAudioGetCount): TVKAudios;
    function AudioGetByID(const OwnerAndAudioIDPair: string): TVKAudio; overload;
    function AudioGetByID(const OwnerID, AudioID: Integer): TVKAudio; overload;
    function AudioGetFromWall(OwnerID, Offset: Integer): TVKAudios;
    function AudioGetFromWallPost(OwnerID, PostID: Integer): TVKAudios;
    function AudioGetLyrics(LyricsID: Integer): string;
    function AudioGetPopular(Offset: Integer; Count: Integer = 100; GenreID: Integer = 0): TVKAudios;
    function AudioGetRecommendations(Offset: Integer; Count: Integer = 100): TVKAudios;
    procedure AudioMoveToAlbum(AlbumID: Integer; AAudioID: TList<Integer>);
    function AudioSearch(const S: string; Offset: Integer = 0; Count: Integer = 30): TVKAudios;
    function AudioSetBroadcast(const OwnerAndAudioIDPair: string): Boolean; overload;
    function AudioSetBroadcast(const OwnerAndAudioIDPair: string; const TargetID: Integer): Boolean; overload;
    function AudioGetPlaylists(const OwnerID: Integer; Offset: Integer; Count: Integer = 100): TVKPlaylists;
    function AudioGetPlaylistByID(const OwnerID, PlaylistID: Integer): TVKPlaylist;

    // NewsFeed
    function NewsGetAudios: TVKAudios;

    // Favorites
    function FaveGetAudiosFromPosts: TVKAudios;
    procedure FaveGetUsers(AFriends: TVKFriends);

    // Groups
    procedure GroupsGet(AGroups: TVKGroups); overload;
    procedure GroupsGet(AUserID: Integer; AGroups: TVKGroups); overload;
    function GroupsGetIDByAlias(const AAlias: string): Integer;

    // Friends
    procedure FriendsGet(AFriends: TVKFriends);

    // Users
    function UsersGetIDByAlias(const AAlias: string): Integer;

    property Listeners: TThreadList<IUnknown> read FListeners;
    property Token: string read FToken write FToken;
    property UserDisplayName: string read FUserDisplayName write FUserDisplayName;
    property UserID: Integer read FUserID write FUserID;
  end;

implementation

uses
  ACL.Parsers,
  ACL.Utils.Shell,
  ACL.Utils.Strings;

const
  XMLResponse = 'response';

  VKAPI_V = 'v=5.131';

{ EVKError }

constructor EVKError.Create(const AErrorText: string; const AErrorCode: Integer);
begin
  FErrorCode := AErrorCode;
  CreateFmt('VK Error: %s (%d)', [AErrorText, AErrorCode]);
end;

constructor EVKError.Create(const AMessage: string);
begin
  FErrorCode := -1;
  inherited Create(AMessage);
end;

{ TVKParams }

function TVKParams.Add(const AParam, AValue: string): TVKParams;
begin
  Result := Self;
  inherited Add(AParam + '=' + acStringFromAnsiString(acEncodeUTF8(AValue), CP_ACP));
end;

function TVKParams.Add(const AParam: string; AValue: Integer): TVKParams;
begin
  Result := Add(AParam, IntToStr(AValue));
end;

function TVKParams.Add(const AParam: string; AValue: TList<Integer>): TVKParams;
var
  I: Integer;
  S: TStringBuilder;
begin
  S := TStringBuilder.Create(AValue.Count * 6);
  try
    for I := 0 to AValue.Count - 1 do
    begin
      if I > 0 then
        S.Append(',');
      S.Append(AValue.List[I]);
    end;
    Result := Add(AParam, S.ToString);
  finally
    S.Free;
  end;
end;

function TVKParams.ToString: string;
begin
  Result := GetDelimitedText('&', False);
end;

{ TVKServicePermissionsHelper }

constructor TVKServicePermissionsHelper.Create(Code: Integer);
var
  I: TVKServicePermission;
begin
  Self := [];
  for I := Low(I) to High(I) do
  begin
    if Code and Map[I] <> 0 then
      Include(Self, I);
  end;
end;

function TVKServicePermissionsHelper.ToInteger: Integer;
var
  I: TVKServicePermission;
begin
  Result := 0;
  for I := Low(I) to High(I) do
  begin
    if I in Self then
      Inc(Result, Map[I]);
  end;
end;

function TVKServicePermissionsHelper.ToString: string;
var
  B: TACLStringBuilder;
  I: TVKServicePermission;
begin
  B := TACLStringBuilder.Get;
  try
    for I := Low(I) to High(I) do
    begin
      if I in Self then
      begin
        if B.Length > 0 then
          B.Append(',');
        B.Append(MapStr[I]);
      end;
    end;
    Result := B.ToString;
  finally
    B.Release;
  end;
end;

{ TVKService }

constructor TVKService.Create(AAppID: Integer; const AAppSecret: string; APemissions: TVKServicePermissions);
begin
  inherited Create;
  FAppID := AAppID;
  FAppSecret := AAppSecret;
  FPemissions := APemissions;
  FListeners := TThreadList<IUnknown>.Create;
end;

destructor TVKService.Destroy;
begin
  FreeAndNil(FListeners);
  inherited Destroy;
end;

function TVKService.AuthorizationGetURL(const ACallbackURL: string = ''): string;
begin
  Result :=
    'https://oauth.vk.com/authorize?' +
    'response_type=token&' +
    'client_id=' + IntToStr(AppID) + '&' +
    'scope=' + FPemissions.ToString;
end;

function TVKService.AuthorizationParseAnswer(const AAnswer: string): Boolean;

  function ExtractParam(const URL, AParam: string): string;
  var
    APos, APosEnd: Integer;
  begin
    APos := acPos(AParam + '=', URL);
    if APos > 0 then
    begin
      APos := APos + Length(AParam) + 1;
      APosEnd := acPos('&', URL, False, APos + 1);
      if APosEnd = 0 then
        APosEnd := Length(URL) + 1;
      Result := acURLDecode(Copy(URL, APos, APosEnd - APos));
    end
    else
      Result := '';
  end;

begin
  FToken := ExtractParam(AAnswer, 'access_token');
  FUserID := StrToIntDef(ExtractParam(AAnswer, 'user_id'), 0);

  Result := (FToken <> '') and (FUserID > 0);
  if Result then
  begin
    UpdateUserInfo;
    RunInMainThread(NotifyLogIn);
  end;
end;

function TVKService.IsAuthorized: Boolean;
begin
  Result := FToken <> '';
end;

procedure TVKService.Logout;
begin
  FToken := '';
  RunInMainThread(NotifyLogOut);
end;

procedure TVKService.AudioAdd(const OwnerID, AudioID, AlbumID: Integer);
var
  AParams: TVKParams;
begin
  CheckID(OwnerID);
  if AudioID > 0 then
  begin
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('audio_id', AudioID);
      if AlbumID > 0 then
        AParams.Add('album_id', AlbumID);
      Command('audio.add', AParams).Free;
    finally
      AParams.Free;
    end;
  end;
end;

procedure TVKService.AudioAdd(const AAudios: TList<TPair<Integer, Integer>>; AlbumID: Integer);
var
  AIndex: Integer;
  AIsRetryMode: Boolean;
begin
  if AlbumID < 0 then
    raise EArgumentException.Create('TVKService.AudioAdd');

  {$MESSAGE 'TODO - Use the https://vk.com/dev/execute method'}

  AIndex := 0;
  AIsRetryMode := False;
  while AIndex < AAudios.Count do
  begin
    if AIsRetryMode then
      Sleep(1000);
    try
      AudioAdd(AAudios.List[AIndex].Key, AAudios.List[AIndex].Value, AlbumID);
      AIsRetryMode := False;
      Inc(AIndex);
    except
      on E: Exception do
      begin
        AIsRetryMode := not AIsRetryMode and (E is EVKError) and (EVKError(E).ErrorCode = 6);
        if not AIsRetryMode then
          raise;
      end;
    end;
  end;
end;

function TVKService.AudioCreatePlaylist(const Title: string): Integer;
var
  ADoc: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('owner_id', UserID);
    AParams.Add('title', Title);
    ADoc := Command('audio.createPlaylist', AParams);
    try
      if ADoc.FindNode(['response', 'id'], ANode) then
        Result := ANode.NodeValueAsInteger
      else
        raise EVKError.Create('VK Error: ID of playlist was not found');
    finally
      ADoc.Free;
    end;
  finally
    AParams.Free;
  end;
end;

procedure TVKService.AudioDelete(const OwnerID, AudioID: Integer; PlaylistID: Integer);
var
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('owner_id', OwnerID);
    AParams.Add('audio_id', AudioID);
    if PlaylistID <> 0 then
      AParams.Add('playlist_id', PlaylistID);
    Command('audio.delete', AParams).Free;
  finally
    AParams.Free;
  end;
end;

function TVKService.AudioGet(OwnerID, Offset, Count: Integer): TVKAudios;
var
  AParams: TVKParams;
begin
  CheckID(OwnerID);

  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxAudioGetCount));
      Command('audio.get', AParams, Result.Load);

      // #AI: FIXME - workaround for strange beahvior of VK API:
      // MaxCount = 211, but when we requested 6000 - VK returns 205 instead of 211.
      if (Offset = 0) and (Count >= MaxAudioGetCount) then
        Result.MaxCount := Result.Count
      else
        Result.MaxCount := Min(Result.MaxCount, MaxAudioGetCount);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetFromPlaylist(OwnerID, PlaylistID, Offset, Count: Integer): TVKAudios;
var
  AParams: TVKParams;
begin
  CheckID(OwnerID);

  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('playlist_id', PlaylistID);
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxAudioGetCount));
      Command('audio.get', AParams, Result.Load);

      // #AI: FIXME - workaround for strange beahvior of VK API:
      // MaxCount = 211, but when we requested 6000 - VK returns 205 instead of 211.
      if (Offset = 0) and (Count >= MaxAudioGetCount) then
        Result.MaxCount := Result.Count
      else
        Result.MaxCount := Min(Result.MaxCount, MaxAudioGetCount);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetByID(const OwnerAndAudioIDPair: string): TVKAudio;
var
  AAudios: TVKAudios;
  AParams: TVKParams;
begin
  AAudios := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('audios', OwnerAndAudioIDPair);
      Command('audio.getById', AParams, AAudios.Load);
      Result := AAudios.Extract(AAudios.First);
    finally
      AParams.Free;
    end;
  finally
    AAudios.Free;
  end;
end;

function TVKService.AudioGetByID(const OwnerID, AudioID: Integer): TVKAudio;
begin
  Result := AudioGetByID(Format('%d_%d', [OwnerID, AudioID]));
end;

function TVKService.AudioGetFromWall(OwnerID, Offset: Integer): TVKAudios;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  CheckID(OwnerID);
  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('offset', Offset);
      AParams.Add('count', 100);

      ADocument := Command('wall.get', AParams);
      try
        if ADocument.FindNode(['response', 'items'], ANode) then
          TVKWall.ExtractAudios(ANode, Result);
      finally
        ADocument.Free;
      end;
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetFromWallPost(OwnerID, PostID: Integer): TVKAudios;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  CheckID(OwnerID);
  CheckID(PostID);

  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('posts', IntToStr(OwnerID) + '_' + IntToStr(PostID));
      ADocument := Command('wall.getById', AParams);
      try
        if ADocument.FindNode(['response'], ANode) then
          TVKWall.ExtractAudios(ANode, Result);
      finally
        ADocument.Free;
      end;
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetLyrics(LyricsID: Integer): string;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  Result := '';
  if LyricsID > 0 then
  begin
    AParams := TVKParams.Create;
    try
      AParams.Add('lyrics_id', LyricsID);
      ADocument := Command('audio.getLyrics', AParams);
      try
        if ADocument.FindNode(['response', 'text'], ANode) then
          Result := ANode.NodeValue;
      finally
        ADocument.Free;
      end;
    finally
      AParams.Free;
    end;
  end;
end;

function TVKService.AudioGetPopular(Offset, Count, GenreID: Integer): TVKAudios;
var
  AParams: TVKParams;
begin
  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      if GenreID > 0 then
        AParams.Add('genre_id', GenreID);
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxAudioPopularCount));
      Command('audio.getPopular', AParams, Result.Load);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetRecommendations(Offset, Count: Integer): TVKAudios;
var
  AParams: TVKParams;
begin
  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('user_id', FUserID);
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxAudioRecommendationCount));
      Command('audio.getRecommendations', AParams, Result.Load);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TVKService.AudioMoveToAlbum(AlbumID: Integer; AAudioID: TList<Integer>);
var
  AParams: TVKParams;
begin
  if AlbumID < 0 then
    raise EArgumentException.Create('TVKService.AudioMoveToAlbum');
  if AAudioID.Count > 0 then
  begin
    AParams := TVKParams.Create;
    try
      AParams.Add('album_id', AlbumID);
      AParams.Add('audio_ids', AAudioID);
      Command('audio.moveToAlbum', AParams).Free;
    finally
      AParams.Free;
    end;
  end;
end;

function TVKService.AudioSearch(const S: string; Offset: Integer = 0; Count: Integer = 30): TVKAudios;
var
  AParams: TVKParams;
begin
  if S = '' then
    raise EArgumentException.Create('Search string is empty');

  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('q', acURLEscape(S));
//      AParams.Add('auto_complete', 1);
      AParams.Add('sort', 2); // by popularity
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxAudioSearchCount));
      Command('audio.search', AParams, Result.Load);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioSetBroadcast(const OwnerAndAudioIDPair: string): Boolean;
begin
  Result := AudioSetBroadcast(OwnerAndAudioIDPair, UserID);
end;

function TVKService.AudioSetBroadcast(const OwnerAndAudioIDPair: string; const TargetID: Integer): Boolean;
var
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    if OwnerAndAudioIDPair <> '' then
      AParams.Add('audio', OwnerAndAudioIDPair);
    AParams.Add('target_ids', TargetID);
    Command('audio.setBroadcast', AParams).Free;
    Result := True;
  finally
    AParams.Free;
  end;
end;

function TVKService.AudioGetPlaylists(const OwnerID: Integer; Offset: Integer; Count: Integer = 100): TVKPlaylists;
var
  AParams: TVKParams;
begin
  CheckID(OwnerID);
  Result := TVKPlaylists.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('offset', Offset);
      AParams.Add('count', Min(Count, MaxPlaylistGetCount));
      Command('audio.getPlaylists', AParams, Result.Load);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.AudioGetPlaylistByID(const OwnerID: Integer; const PlaylistID: Integer): TVKPlaylist;
var
  AParams: TVKParams;
begin
  CheckID(OwnerID);

  Result := TVKPlaylist.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('owner_id', OwnerID);
      AParams.Add('playlist_id', PlaylistID);
      Command('audio.getPlaylistById', AParams, Result.Load);
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.NewsGetAudios: TVKAudios;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
  ASubNode: TACLXMLNode;
  I: Integer;
begin
  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('filters', 'audio');
      AParams.Add('return_banned', 0);
      AParams.Add('count', 100); // Max

      ADocument := Command('newsfeed.get', AParams);
      try
        if ADocument.FindNode(['response', 'items'], ANode) then
          for I := 0 to ANode.Count - 1 do
          begin
            if ANode[I].FindNode('audio', ASubNode) then
              Result.Load(ASubNode);
          end;
      finally
        ADocument.Free;
      end;
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TVKService.FaveGetAudiosFromPosts: TVKAudios;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  Result := TVKAudios.Create;
  try
    AParams := TVKParams.Create;
    try
      AParams.Add('offset', 0);
      AParams.Add('count', MaxFavePostCount);

      ADocument := Command('fave.getPosts', AParams);
      try
        if ADocument.FindNode(['response', 'items'], ANode) then
          TVKWall.ExtractAudios(ANode, Result);
      finally
        ADocument.Free;
      end;
    finally
      AParams.Free;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TVKService.FaveGetUsers(AFriends: TVKFriends);
var
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('offset', 0);
    AParams.Add('count', MaxAudioGetCount);
    Command('fave.getUsers', AParams, AFriends.Load);
  finally
    AParams.Free;
  end;
end;

procedure TVKService.GroupsGet(AGroups: TVKGroups);
begin
  GroupsGet(UserID, AGroups);
end;

procedure TVKService.GroupsGet(AUserID: Integer; AGroups: TVKGroups);
var
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('user_id', AUserID);
    AParams.Add('extended', 1);
    AParams.Add('count', 1000); // Max
    Command('groups.get', AParams, AGroups.Load);
  finally
    AParams.Free;
  end;
end;

function TVKService.GroupsGetIDByAlias(const AAlias: string): Integer;
begin
  Result := ResolveAlias(AAlias, 'group_id', 'groups.getById', 'group');
end;

procedure TVKService.FriendsGet(AFriends: TVKFriends);
var
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('order', 'name');
    AParams.Add('fields', 'nickname');
    Command('friends.get', AParams, AFriends.Load);
  finally
    AParams.Free;
  end;
end;

function TVKService.UsersGetIDByAlias(const AAlias: string): Integer;
begin
  Result := ResolveAlias(AAlias, 'user_ids', 'users.get', 'user');
end;

function TVKService.Command(const AMethod: string; AParams: TVKParams): TACLXMLDocument;
var
  AErrorCode: Integer;
  AErrorInfo: TACLWebErrorInfo;
  AErrorNode: TACLXMLNode;
  AStream: TBytesStream;
begin
  CheckAuthorization;

  AStream := TBytesStream.Create;
  try
    if not TACLHttpClient.GetNoThread(BuildCommandLine(AMethod, AParams), AStream, AErrorInfo) then
      raise Exception.Create('Connection Error: ' + AErrorInfo.ToString);
    AStream.Position := 0;
  {$IFDEF VK_DUMP}
    AStream.SaveToFile('B:\vkDump.json');
  {$ENDIF}
    Result := JsonToXml(AStream);
  {$IFDEF VK_DUMP}
    Result.SaveToFile('B:\vkDump.xml');
  {$ENDIF}
    if Result.FindNode('error', AErrorNode) then
    try
      AErrorCode := StrToIntDef(AErrorNode.NodeValueByName('error_code'), -1);
      if AErrorCode = 5 then
        FToken := '';
      raise EVKError.Create(AErrorNode.NodeValueByName('error_msg'), AErrorCode);
    finally
      FreeAndNil(Result);
    end;
  finally
    FreeAndNil(AStream);
  end;
end;

procedure TVKService.Command(const AMethod: string; AParams: TVKParams; AProc: TVKLoadFromNodeProc);
var
  ADoc: TACLXMLDocument;
  ANode: TACLXMLNode;
begin
  ADoc := Command(AMethod, AParams);
  try
    if ADoc.FindNode(XMLResponse, ANode) then
      AProc(ANode);
  finally
    ADoc.Free;
  end;
end;

procedure TVKService.NotifyLogIn;
var
  AIntf: IVKServiceListener;
  I: Integer;
begin
  with FListeners.LockList do
  try
    for I := 0 to Count - 1 do
    begin
      if Supports(List[I], IVKServiceListener, AIntf) then
        AIntf.NotifyLogIn;
    end;
  finally
    FListeners.UnlockList;
  end;
end;

procedure TVKService.NotifyLogOut;
var
  AIntf: IVKServiceListener;
  I: Integer;
begin
  with FListeners.LockList do
  try
    for I := 0 to Count - 1 do
    begin
      if Supports(List[I], IVKServiceListener, AIntf) then
        AIntf.NotifyLogOut;
    end;
  finally
    FListeners.UnlockList;
  end;
end;

function TVKService.BuildCommandLine(const AMethod: string; AParams: TVKParams): string;
var
  ACmdLine: TStringBuilder;
begin
  ACmdLine := TStringBuilder.Create(256);
  try
    ACmdLine.Append('https://api.vk.com/method/');
    ACmdLine.Append(AMethod);
    ACmdLine.Append('?access_token=');
    ACmdLine.Append(Token);

    if AParams.Count > 0 then
    begin
      ACmdLine.Append('&');
      ACmdLine.Append(AParams.ToString);
    end;

    ACmdLine.Append('&');
    ACmdLine.Append(VKAPI_V);

    Result := ACmdLine.ToString;
  finally
    ACmdLine.Free;
  end;
end;

procedure TVKService.CheckAuthorization;
begin
  if not IsAuthorized then
    raise EVKError.Create('VK Error: access token is invalid');
end;

procedure TVKService.CheckID(ID: Integer);
begin
  if ID = 0 then
    raise EArgumentException.Create('Invalid ID');
end;

function TVKService.JsonToXml(const AStream: TBytesStream): TACLXMLDocument;

  procedure Process(ANode: TACLXMLNode; AValue: TJSONValue);
  var
    APair: TJSONPair;
    I: Integer;
  begin
    if AValue is TJSONObject then
    begin
      for APair in TJSONObject(AValue) do
        Process(ANode.Add(APair.JsonString.Value), APair.JsonValue);
    end
    else

    if AValue is TJSONArray then
    begin
      for I := 0 to TJSONArray(AValue).Count - 1 do
        Process(ANode.Add('item'), TJSONArray(AValue).Items[I]);
    end
    else
      ANode.NodeValue := AValue.Value;
  end;

var
  JSON: TJSONObject;
begin
  Result := TACLXMLDocument.Create;

  JSON := TJSONObject.Create;
  try
    JSON.Parse(AStream.Bytes, 0, AStream.Size);
    Process(Result, JSON);
  finally
    JSON.Free;
  end;
end;

function TVKService.ResolveAlias(const AAlias, AVarName, AMethodName, ANodeName: string): Integer;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  Result := 0;
  AParams := TVKParams.Create;
  try
    AParams.Add(AVarName, AAlias);
    ADocument := Command(AMethodName, AParams);
    try
      if ADocument.FindNode([XMLResponse, ANodeName, 'id'], ANode) then
        Result := StrToIntDef(ANode.NodeValue, 0);
    finally
      ADocument.Free;
    end;
  finally
    AParams.Free;
  end;
end;

procedure TVKService.UpdateUserInfo;
var
  ADocument: TACLXMLDocument;
  ANode: TACLXMLNode;
  AParams: TVKParams;
begin
  AParams := TVKParams.Create;
  try
    AParams.Add('user_ids', UserID);
    AParams.Add('fields', '');
    AParams.Add('name_case', 'Nom');

    ADocument := Command('users.get', AParams);
    try
      if ADocument.FindNode([XMLResponse, 'user'], ANode) then
        FUserDisplayName := ANode.NodeValueByName('first_name') + ' ' + ANode.NodeValueByName('last_name');
    finally
      ADocument.Free;
    end;
  finally
    AParams.Free;
  end;
end;

end.
