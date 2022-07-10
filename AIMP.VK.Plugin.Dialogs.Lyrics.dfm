object frmVKLyrics: TfrmVKLyrics
  Left = 0
  Top = 0
  ClientHeight = 531
  ClientWidth = 426
  Color = clBtnFace
  Constraints.MinHeight = 480
  Constraints.MinWidth = 380
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poMainFormCenter
  OnClose = FormClose
  OnDestroy = FormDestroy
  OnKeyUp = meLyricsKeyUp
  TextHeight = 13
  object lbLoading: TACLLabel
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 420
    Height = 525
    Align = alClient
    Alignment = taCenter
    Caption = 'lbLoading'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGray
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    ExplicitLeft = 192
    ExplicitTop = 264
    ExplicitWidth = 75
    ExplicitHeight = 15
  end
  object meLyrics: TACLMemo
    AlignWithMargins = True
    Left = 8
    Top = 8
    Width = 410
    Height = 515
    Margins.All = 8
    Align = alClient
    DoubleBuffered = True
    TabOrder = 0
    Visible = False
    OnKeyUp = meLyricsKeyUp
    ReadOnly = True
    ScrollBars = ssVertical
    DesignSize = (
      410
      515)
  end
  object ActionList: TActionList
    Left = 16
    Top = 16
    object acSelectAll: TAction
      Caption = 'acSelectAll'
      ShortCut = 16449
      OnExecute = acSelectAllExecute
    end
  end
end
