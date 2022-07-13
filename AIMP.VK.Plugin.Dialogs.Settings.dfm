object frmVKSettings: TfrmVKSettings
  Left = 0
  Top = 0
  AlphaBlendValue = 0
  BorderStyle = bsNone
  ClientHeight = 500
  ClientWidth = 434
  Color = clBtnFace
  DefaultMonitor = dmDesktop
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  Icon.Data = {
    0000010001001010000001002000680400001600000028000000100000002000
    0000010020000000000040040000000000000000000000000000000000000000
    00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000
    00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF0073AAFF00699CFF00699CFF0069
    9CFF007CB8FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF000000FF000000FF0000
    00FF000000FF00476BFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF003958FF00AEFFFF00AE
    FFFF00476BFF000000FF0096DDFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF002A42FF00699CFF0069
    9CFF001726FF000000FF009EE9FF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF000000FF000000FF0000
    00FF001726FF0085C5FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF003958FF00AEFFFF0069
    9CFF000000FF007CB8FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF002A42FF00699CFF0039
    58FF000000FF0073AAFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF001726FF000000FF000000FF0000
    00FF00476BFF00A6F4FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AE
    FFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF00AEFFFF000000FF0000
    00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000
    00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000
    0000000000000000000000000000000000000000000000000000000000000000
    000000000000000000000000000000000000000000000000000000000000}
  TextHeight = 13
  object ACLPanel1: TACLPanel
    Left = 0
    Top = 0
    Width = 434
    Height = 500
    Align = alClient
    ParentShowHint = False
    ShowHint = False
    TabOrder = 0
    Borders = []
    object GB1: TACLGroupBox
      AlignWithMargins = True
      Left = 0
      Top = 54
      Width = 434
      Height = 54
      Margins.Bottom = 0
      Margins.Left = 0
      Margins.Right = 0
      Align = alTop
      TabOrder = 0
      Caption = '1'
      object L1: TACLLabel
        AlignWithMargins = True
        Left = 10
        Top = 17
        Width = 162
        Height = 27
        Align = alClient
        Caption = 'L1'
      end
      object B1: TACLButton
        AlignWithMargins = True
        Left = 304
        Top = 17
        Width = 120
        Height = 27
        Align = alRight
        TabOrder = 1
        OnClick = B1Click
        Caption = 'B1'
      end
      object B2: TACLButton
        AlignWithMargins = True
        Left = 178
        Top = 17
        Width = 120
        Height = 27
        Align = alRight
        TabOrder = 0
        OnClick = B2Click
        Caption = 'B2'
      end
    end
    object GB2: TACLGroupBox
      AlignWithMargins = True
      Left = 0
      Top = 111
      Width = 434
      Height = 115
      Margins.Bottom = 0
      Margins.Left = 0
      Margins.Right = 0
      Align = alTop
      TabOrder = 1
      Caption = '1'
      CheckBox.Action = cbaToggleChildrenEnableState
      CheckBox.Visible = True
      OnCheckBoxStateChanged = ModifiedHandler
      object L2: TACLLabel
        AlignWithMargins = True
        Left = 29
        Top = 38
        Width = 395
        Height = 67
        Margins.Left = 22
        Align = alClient
        AlignmentVert = taAlignTop
        Style.WordWrap = True
        Caption = 'L1'
      end
      object CB1: TACLCheckBox
        AlignWithMargins = True
        Left = 10
        Top = 17
        Width = 414
        Height = 15
        Align = alTop
        TabOrder = 0
        OnClick = ModifiedHandler
        Caption = 'CB1'
      end
    end
    object GB3: TACLGroupBox
      AlignWithMargins = True
      Left = 0
      Top = 3
      Width = 434
      Height = 48
      Margins.Bottom = 0
      Margins.Left = 0
      Margins.Right = 0
      Align = alTop
      TabOrder = 2
      AutoSize = True
      Caption = '1'
      OnCheckBoxStateChanged = ModifiedHandler
      object edDownloadPath: TACLEdit
        AlignWithMargins = True
        Left = 10
        Top = 17
        Width = 414
        Height = 21
        Align = alTop
        TabOrder = 0
        OnChange = ModifiedHandler
        Buttons = <
          item
            Caption = '...'
            OnClick = edDownloadPathButtons0Click
          end
          item
            ImageIndex = 0
            OnClick = edDownloadPathButtons1Click
          end>
        ButtonsImages = ilImages
        Text = ''
      end
    end
    object GB_ClearCache: TACLGroupBox
      Left = 0
      Top = 450
      Width = 434
      Height = 50
      Align = alBottom
      TabOrder = 3
      Caption = 'ClearCache'
      object Label_ClearCache: TACLLabel
        Left = 7
        Top = 14
        Width = 300
        Height = 29
        Align = alClient
        AlignmentVert = taAlignTop
        Style.WordWrap = True
        Caption = 'ClearCache'
      end
      object Button_ClearCache: TACLButton
        Left = 307
        Top = 14
        Width = 120
        Height = 29
        Align = alRight
        TabOrder = 0
        OnClick = Button_ClearCacheClick
        Caption = 'Clear Cache'
      end
    end
  end
  object ilImages: TACLImageList
    Left = 8
    Bitmap = {
      4C49435A2611000086000000789CF3F461646464606560611000C2FF40A028F0
      1F0A9C7CCD182000446B00B103100B003123830244428061148C8251300A4601
      E9E0FF403B6080C17F86911106FF89C023118C64BF83C048F6FB281805A36014
      8C8261069C7CEDA02C108D3A6AC008166FC0A1F3FFFFFF400C6313A0EF43E9F3
      10FA033B2A1F2E4FAC7978EB6200B81F40B7}
  end
end
