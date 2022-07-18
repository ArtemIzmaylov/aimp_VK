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

unit AIMP.VK.Classes;

{$I AIMP.VK.inc}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.Types,
  // ACL
  ACL.Hashes,
  ACL.Classes.Collections,
  ACL.FileFormats.XML,
  ACL.Utils.Stream;

type

  { IVKListIO }

  IVKListIO = interface
    procedure Clear;
    procedure Load(ANode: TACLXMLNode); overload;
    procedure Load(AStream: TStream); overload;
    procedure Save(ANode: TACLXMLNode); overload;
    procedure Save(AStream: TStream); overload;
  end;

  { TVKList }

  TVKList<T: class> = class abstract(TObjectList<T>,
    IUnknown,
    IVKListIO)
  strict private
    // IUnknown
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function QueryInterface(const IID: TGUID; out Obj): HRESULT; stdcall;
  public
    procedure Enum(AProc: TProc<T>);
    // IVKListIO
    procedure Load(ANode: TACLXMLNode); overload; virtual; abstract;
    procedure Load(AStream: TStream); overload;
    procedure Save(ANode: TACLXMLNode); overload; virtual; abstract;
    procedure Save(AStream: TStream); overload;
  end;

  { TVKAudio }

  TVKAudio = class
  protected
    FAlbumID: Integer;
    FArtist: string;
    FDate: Int64;
    FDuration: Integer;
    FGenreID: Integer;
    FID: Integer;
    FLyricsID: Integer;
    FOwnerID: Integer;
    FTitle: string;
    FURL: string;
    FAccessKey: string;

    function GetGenre: string;
  public
    constructor Create(ANode: TACLXMLNode); overload;
    procedure Assign(ASource: TVKAudio);
    function Clone: TVKAudio;
    procedure Load(ANode: TACLXMLNode);
    procedure Save(ANode: TACLXMLNode);
    function GetAPIPairs: string;
    function GetRealLink: string;
    //
    property AlbumID: Integer read FAlbumID write FAlbumID;
    property Artist: string read FArtist write FArtist;
    property Date: Int64 read FDate write FDate;
    property Duration: Integer read FDuration write FDuration;
    property Genre: string read GetGenre;
    property GenreID: Integer read FGenreID write FGenreID;
    property ID: Integer read FID write FID;
    property LyricsID: Integer read FLyricsID write FLyricsID;
    property OwnerID: Integer read FOwnerID write FOwnerID;
    property Title: string read FTitle write FTitle;
    property URL: string read FURL write FURL;
    property AccessKey: string read FAccessKey write FAccessKey;
  end;

  { TVKAudios }

  TVKAudios = class(TVKList<TVKAudio>)
  strict private
    FMaxCount: Integer;
  public
    procedure Load(ANode: TACLXMLNode); override;
    procedure Save(ANode: TACLXMLNode); override;
    //
    property MaxCount: Integer read FMaxCount write FMaxCount;
  end;

  { TVKPlaylist }

  TVKPlaylist = class
  protected
    FId: Integer;
    FOwnerId: Integer;
    FTitle: UnicodeString;
  public
    constructor Create(ANode: TACLXMLNode); overload;
    function GetOwnerAndAudioIDPair: string;
    procedure Load(ANode: TACLXMLNode);
    procedure Save(ANode: TACLXMLNode);
    //
    property Id: Integer read FId;
    property OwnerId: Integer read FOwnerId;
    property Title: UnicodeString read FTitle;
  end;

  { TVKPlaylists }

  TVKPlaylists = class(TVKList<TVKPlaylist>)
  strict private
    FMaxCount: Integer;
  public
    function Find(const OwnerID, PlaylistID: Integer; out APlaylist: TVKPlaylist): Boolean;
    procedure Load(ANode: TACLXMLNode); override;
    procedure Save(ANode: TACLXMLNode); override;
    //
    property MaxCount: Integer read FMaxCount write FMaxCount;
  end;

  { TVKFriend }

  TVKFriend = class
  strict private
    FFirstName: string;
    FLastName: string;
    FNickName: string;
    FUserID: Integer;
  public
    constructor Create(ANode: TACLXMLNode); overload;
    constructor Create(ID: Integer); overload;
    function DisplayName: string;
    procedure Load(ANode: TACLXMLNode);
    procedure Save(ANode: TACLXMLNode);
    //
    property FirstName: string read FFirstName;
    property LastName: string read FLastName;
    property NickName: string read FNickName;
    property UserID: Integer read FUserID;
  end;

  { TVKFriends }

  TVKFriends = class(TVKList<TVKFriend>)
  public
    function FindByDisplayName(const AName: string; out AFriend: TVKFriend): Boolean;
    procedure Load(ANode: TACLXMLNode); override;
    procedure Save(ANode: TACLXMLNode); override;
  end;

  { TVKGenres }

  TVKGenres = class(TACLMap<Integer, string>)
  public
    function Get(ID: Integer): string;
    function GetID(const S: string): Integer;
  end;

  { TVKGroup }

  TVKGroup = class
  strict private
    FName: string;
    FID: Integer;
  public
    constructor Create(ANode: TACLXMLNode); overload;
    procedure Load(ANode: TACLXMLNode);
    procedure Save(ANode: TACLXMLNode);
    //
    property ID: Integer read FID;
    property Name: string read FName;
  end;

  { TVKGroups }

  TVKGroups = class(TVKList<TVKGroup>)
  public
    function FindByName(const AName: string; out AGroup: TVKGroup): Boolean;
    procedure Load(ANode: TACLXMLNode); override;
    procedure Save(ANode: TACLXMLNode); override;
  end;

  { TVKWall }

  TVKWall = class
  strict private
    class procedure ExtractAudiosFromAttachments(AAttachments: TACLXMLNode; AAudios: TVKAudios);
    class procedure ExtractAudiosFromWallPosts(APosts: TACLXMLNode; AAudios: TVKAudios);
  public
    class procedure ExtractAudios(APosts: TACLXMLNode; AAudios: TVKAudios);
  end;

function VKGenres: TVKGenres;
function ParseOwnerAndAudioIDPair(const S: string; out AOwnerID, ID: Integer; out AccessKey: string): Boolean;
implementation

uses
  ACL.Utils.Shell, ACL.Utils.Strings, ACL.Parsers;

var
  FVKGenres: TVKGenres;

function VKGenres: TVKGenres;
begin
  if FVKGenres = nil then
  begin
    FVKGenres := TVKGenres.Create;
    FVKGenres.Add(1, 'Rock');
    FVKGenres.Add(2, 'Pop');
    FVKGenres.Add(3, 'Rap & Hip-Hop');
    FVKGenres.Add(4, 'Easy Listening');
    FVKGenres.Add(5, 'Dance & House');
    FVKGenres.Add(6, 'Instrumental');
    FVKGenres.Add(7, 'Metal');
    FVKGenres.Add(21, 'Alternative');
    FVKGenres.Add(8, 'Dubstep');
    FVKGenres.Add(1001, 'Jazz & Blues');
    FVKGenres.Add(10, 'Drum & Bass');
    FVKGenres.Add(11, 'Trance');
    FVKGenres.Add(12, 'Chanson');
    FVKGenres.Add(13, 'Ethnic');
    FVKGenres.Add(14, 'Acoustic & Vocal');
    FVKGenres.Add(15, 'Reggae');
    FVKGenres.Add(16, 'Classical');
    FVKGenres.Add(17, 'Indie Pop');
    FVKGenres.Add(19, 'Speech');
    FVKGenres.Add(22, 'Electropop & Disco');
    FVKGenres.Add(18, 'Other');
  end;
  Result := FVKGenres;
end;

function Split(Str: string; Delimiter: Char): TStrings;
begin
  Result := TStringList.Create;
  Result.Delimiter := Delimiter;
  Result.StrictDelimiter := True;
  Result.DelimitedText := Str;
end;

function ParseOwnerAndAudioIDPair(const S: string; out AOwnerID, ID: Integer; out AccessKey: String): Boolean;
var
  AParts: TStringDynArray;
begin
  AParts := SplitString(S, '_');
  Result := Length(AParts) >= 2;
  if Result then
  begin
    AOwnerID := StrToIntDef(AParts[0], 0);
    ID := StrToIntDef(AParts[1], 0);
    if Length(AParts) >= 3 then
      AccessKey := AParts[2];
    Result := (AOwnerID <> 0) and (ID <> 0);
  end;
end;

{ TVKList<T> }

procedure TVKList<T>.Enum(AProc: TProc<T>);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    AProc(List[I]);
end;

procedure TVKList<T>.Load(AStream: TStream);
var
  ANode: TACLXMLNode;
  AXML: TACLXMLDocument;
begin
  AXML := TACLXMLDocument.CreateEx(AStream);
  try
    Clear;
    ANode := AXML[0];
    if ANode.NodeName = AnsiString(ClassName) then
      Load(ANOde);
  finally
    AXML.Free;
  end;
end;

procedure TVKList<T>.Save(AStream: TStream);
var
  AXML: TACLXMLDocument;
begin
  AXML := TACLXMLDocument.Create;
  try
    Save(AXML.Add(AnsiString(ClassName)));
    AXML.SaveToStream(AStream, TACLXMLDocumentFormatSettings.Binary);
  finally
    AXML.Free;
  end;
end;

function TVKList<T>._AddRef: Integer;
begin
  Result := -1;
end;

function TVKList<T>._Release: Integer;
begin
  Result := -1;
end;

function TVKList<T>.QueryInterface(const IID: TGUID; out Obj): HRESULT;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;


{ TVKAudio }

constructor TVKAudio.Create(ANode: TACLXMLNode);
begin
  inherited Create;
  Load(ANode);
end;

procedure TVKAudio.Assign(ASource: TVKAudio);
begin
  FArtist := ASource.Artist;
  FDuration := ASource.Duration;
  FGenreID := ASource.GenreID;
  FID := ASource.ID;
  FAlbumID := ASource.AlbumID;
  FLyricsID := ASource.LyricsID;
  FOwnerID := ASource.OwnerID;
  FTitle := ASource.Title;
  FDate := ASource.Date;
  FAccessKey := ASource.AccessKey;
end;

function TVKAudio.Clone: TVKAudio;
begin
  Result := TVKAudio.Create;
  Result.Assign(Self);
end;

procedure TVKAudio.Load(ANode: TACLXMLNode);
var
  ASubNode: TACLXMLNode;
begin
  FID := ANode.NodeValueByNameAsInteger('id');
  FArtist := ANode.NodeValueByName('artist');

  if ANode.FindNode('album', ASubNode) then
  begin
    FAlbumID := ASubNode.NodeValueByNameAsInteger('id');
  end;

  FDuration := ANode.NodeValueByNameAsInteger('duration');
  FGenreID := ANode.NodeValueByNameAsInteger('genre_id');
  FLyricsID := ANode.NodeValueByNameAsInteger('lyrics_id');
  FOwnerID := ANode.NodeValueByNameAsInteger('owner_id');
  FTitle := ANode.NodeValueByName('title');
  FDate := StrToInt64Def(ANode.NodeValueByName('date'), 0);
  FURL := ANode.NodeValueByName('url');
  FAccessKey := ANode.NodeValueByName('access_key');
end;

procedure TVKAudio.Save(ANode: TACLXMLNode);
begin
  ANode.Add('id').NodeValueAsInteger := FID;
  ANode.Add('artist').NodeValue := FArtist;
  ANode.Add('duration').NodeValueAsInteger := FDuration;
  ANode.Add('genre_id').NodeValueAsInteger := FGenreID;
  ANode.Add('album').Add('id').NodeValueAsInteger := FAlbumID;
  ANode.Add('lyrics_id').NodeValueAsInteger := FLyricsID;
  ANode.Add('owner_id').NodeValueAsInteger := FOwnerID;
  ANode.Add('title').NodeValue := FTitle;
  ANode.Add('date').NodeValue := IntToStr(FDate);
  ANode.Add('url').NodeValue := FURL;
  ANode.Add('access_key').NodeValue := FAccessKey;
end;

function TVKAudio.GetGenre: string;
begin
  Result := VKGenres.Get(GenreID);
end;

function TVKAudio.GetAPIPairs: string;
begin
  Result := Format('%d_%d_%s', [OwnerID, ID, AccessKey]);
end;

function TVKAudio.GetRealLink: string;
begin
  Result := 'https://vk.com/audio' + GetAPIPairs;
end;

{ TVKAudios }

procedure TVKAudios.Load(ANode: TACLXMLNode);
var
  ASubNode: TACLXMLNode;
  I: Integer;
begin
  if ANode <> nil then
  begin
    FMaxCount := ANode.NodeValueByNameAsInteger('count');
    if ANode.FindNode('items', ASubNode) then
      ANode := ASubNode;
    for I := 0 to ANode.Count - 1 do
    begin
      ASubNode := ANode[I];
//      if ASubNode.NodeName = 'audio' then
        Add(TVKAudio.Create(ASubNode));
    end;
  end;
end;

procedure TVKAudios.Save(ANode: TACLXMLNode);
var
  I: Integer;
begin
  ANode.Add('count').NodeValueAsInteger := FMaxCount;
  ANode := ANode.Add('items');
  for I := 0 to Count - 1 do
    List[I].Save(ANode.Add('audio'));
end;

{ TVKPlaylist }

constructor TVKPlaylist.Create(ANode: TACLXMLNode);
begin
  Load(ANode);
end;

function TVKPlaylist.GetOwnerAndAudioIDPair: string;
begin
  Result := Format('%d_%d', [OwnerID, ID]);
end;

procedure TVKPlaylist.Load(ANode: TACLXMLNode);
begin
  FId := ANode.NodeValueByNameAsInteger('id');
  FOwnerId := ANode.NodeValueByNameAsInteger('owner_id');
  FTitle := ANode.NodeValueByName('title');
end;

procedure TVKPlaylist.Save(ANode: TACLXMLNode);
begin
  ANode.Add('id').NodeValueAsInteger := ID;
  ANode.Add('owner_id').NodeValueAsInteger := OwnerId;
  ANode.Add('title').NodeValue := Title;
end;

{ TVKPlaylists }

function TVKPlaylists.Find(const OwnerID, PlaylistID: Integer; out APlaylist: TVKPlaylist): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Count - 1 do
    if (List[I].Id = PlaylistID) and (List[I].OwnerId = OwnerID) then
    begin
      APlaylist := List[I];
      Exit(True);
    end;
end;

procedure TVKPlaylists.Load(ANode: TACLXMLNode);
begin
  if ANode <> nil then
  begin
    FMaxCount := ANode.NodeValueByNameAsInteger('count');
    ANode.Enum(['items'],
      procedure (ANode: TACLXMLNode)
      var
        AItem: TVKPlaylist;
      begin
        AItem := TVKPlaylist.Create;
        AItem.FId := ANode.NodeValueByNameAsInteger('id');
        AItem.FOwnerId := ANode.NodeValueByNameAsInteger('owner_id');
        AItem.FTitle := ANode.NodeValueByName('title');
        Add(AItem);
      end);
  end;
end;

procedure TVKPlaylists.Save(ANode: TACLXMLNode);
var
  I: Integer;
begin
  ANode.Add('count').NodeValueAsInteger := FMaxCount;
  ANode := ANode.Add('items');
  for I := 0 to Count - 1 do
    List[I].Save(ANode.Add('item'));
end;

{ TVKFriend }

constructor TVKFriend.Create(ANode: TACLXMLNode);
begin
  Load(ANode);
end;

constructor TVKFriend.Create(ID: Integer);
begin
  FFirstName := 'id' + IntToStr(ID);
  FUserID := ID;
end;

function TVKFriend.DisplayName: string;
begin
  Result := Format('%s %s', [FirstName, LastName]);
end;

procedure TVKFriend.Load(ANode: TACLXMLNode);
begin
  FFirstName := ANode.NodeValueByName('first_name');
  FLastName := ANode.NodeValueByName('last_name');
  FNickName := ANode.NodeValueByName('nickname');
  FUserID := ANode.NodeValueByNameAsInteger('id');
end;

procedure TVKFriend.Save(ANode: TACLXMLNode);
begin
  ANode.Add('first_name').NodeValue := FFirstName;
  ANode.Add('last_name').NodeValue := FLastName;
  ANode.Add('nickname').NodeValue := FNickName;
  ANode.Add('id').NodeValueAsInteger := FUserID;
end;

{ TVKFriends }

function TVKFriends.FindByDisplayName(const AName: string; out AFriend: TVKFriend): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    AFriend := List[I];
    if WideSameText(AName, AFriend.DisplayName) then
      Exit(True);
  end;
  Result := False;
end;

procedure TVKFriends.Load(ANode: TACLXMLNode);
var
  ASubNode: TACLXMLNode;
  I: Integer;
begin
  if (ANode <> nil) and ANode.FindNode('items', ANode) then
    for I := 0 to ANode.Count - 1 do
    begin
      ASubNode := ANode[I];
//      if ASubNode.NodeName = 'user' then
        Add(TVKFriend.Create(ASubNode));
    end;
end;

procedure TVKFriends.Save(ANode: TACLXMLNode);
var
  I: Integer;
begin
  ANode := ANode.Add('items');
  for I := 0 to Count - 1 do
    List[I].Save(ANode.Add('user'));
end;

{ TVKGenres }

function TVKGenres.Get(ID: Integer): string;
begin
  if not TryGetValue(ID, Result) then
    Result := '';
end;

function TVKGenres.GetID(const S: string): Integer;
begin
  if not TryGetKey(S, Result) then
    Result := 0;
end;

{ TVKGroup }

constructor TVKGroup.Create(ANode: TACLXMLNode);
begin
  Load(ANode);
end;

procedure TVKGroup.Load(ANode: TACLXMLNode);
begin
  FID := ANode.NodeValueByNameAsInteger('id');
  FName := ANode.NodeValueByName('name');
end;

procedure TVKGroup.Save(ANode: TACLXMLNode);
begin
  ANode.Add('id').NodeValueAsInteger := FID;
  ANode.Add('name').NodeValue := FName;
end;

{ TVKGroups }

function TVKGroups.FindByName(const AName: string; out AGroup: TVKGroup): Boolean;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    AGroup := List[I];
    if WideSameText(AName, AGroup.Name) then
      Exit(True);
  end;
  Result := False;
end;

procedure TVKGroups.Load(ANode: TACLXMLNode);
var
  ASubNode: TACLXMLNode;
  I: Integer;
begin
  if (ANode <> nil) and ANode.FindNode('items', ANode) then
    for I := 0 to ANode.Count - 1 do
    begin
      ASubNode := ANode[I];
//      if ASubNode.NodeName = 'group' then
        Add(TVKGroup.Create(ASubNode));
    end;
end;

procedure TVKGroups.Save(ANode: TACLXMLNode);
var
  I: Integer;
begin
  ANode := ANode.Add('items');
  for I := 0 to Count - 1 do
    List[I].Save(ANode.Add('group'));
end;

{ TVKWall }

class procedure TVKWall.ExtractAudios(APosts: TACLXMLNode; AAudios: TVKAudios);
begin
  ExtractAudiosFromWallPosts(APosts, AAudios);
end;

class procedure TVKWall.ExtractAudiosFromAttachments(AAttachments: TACLXMLNode; AAudios: TVKAudios);
var
  ANode: TACLXMLNode;
  I: Integer;
begin
  for I := 0 to AAttachments.Count - 1 do
  begin
    ANode := AAttachments[I];
    if (ANode.NodeValueByName('type') = 'audio') and ANode.FindNode('audio', ANode) then
      AAudios.Add(TVKAudio.Create(ANode));
  end;
end;

class procedure TVKWall.ExtractAudiosFromWallPosts(APosts: TACLXMLNode; AAudios: TVKAudios);
var
  ANode: TACLXMLNode;
  ASubNode: TACLXMLNode;
  I: Integer;
begin
  for I := 0 to APosts.Count - 1 do
  begin
    ANode := APosts[I];
//    if ANode.NodeName = 'post' then
    if ANode.NodeName = 'item' then
    begin
      if ANode.FindNode('attachments', ASubNode) then
        ExtractAudiosFromAttachments(ASubNode, AAudios);
      if ANode.FindNode('copy_history', ASubNode) then
        ExtractAudiosFromWallPosts(ASubNode, AAudios);
    end;
  end;
end;

initialization

finalization
  FreeAndNil(FVKGenres);
end.
