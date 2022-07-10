object frmVKDownloader: TfrmVKDownloader
  Left = 8
  Top = 8
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  ClientHeight = 221
  ClientWidth = 594
  Color = clBtnFace
  Constraints.MinHeight = 250
  Constraints.MinWidth = 600
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Position = poDesigned
  OnClose = FormClose
  TextHeight = 13
  object pbCurrentProgress: TACLProgressBar
    AlignWithMargins = True
    Left = 12
    Top = 33
    Width = 570
    Height = 18
    Margins.Left = 12
    Margins.Right = 12
    Align = alTop
    ExplicitLeft = 224
    ExplicitTop = 288
    ExplicitWidth = 100
  end
  object pbTotalProgress: TACLProgressBar
    AlignWithMargins = True
    Left = 12
    Top = 57
    Width = 570
    Height = 18
    Margins.Left = 12
    Margins.Right = 12
    Align = alTop
    ExplicitLeft = 20
    ExplicitTop = 20
    ExplicitWidth = 412
  end
  object lbProcessingFile: TACLLabel
    AlignWithMargins = True
    Left = 12
    Top = 12
    Width = 570
    Height = 15
    Margins.Left = 12
    Margins.Right = 12
    Margins.Top = 12
    Align = alTop
    Caption = 'lbProcessingFile'
    ExplicitLeft = -2
    ExplicitTop = -1
    ExplicitWidth = 588
  end
  object tlQueue: TACLTreeList
    AlignWithMargins = True
    Left = 12
    Top = 81
    Width = 570
    Height = 97
    Margins.Left = 12
    Margins.Right = 12
    Align = alClient
    TabOrder = 0
    Columns = <
      item
      end
      item
      end>
    OptionsBehavior.Deleting = True
    OptionsSelection.MultiSelect = True
    OptionsView.Columns.AutoWidth = True
    OptionsView.Columns.Visible = False
    OptionsView.Nodes.GridLines = []
  end
  object btnCancel: TACLButton
    AlignWithMargins = True
    Left = 480
    Top = 184
    Width = 102
    Height = 25
    Margins.Bottom = 12
    Margins.Left = 480
    Margins.Right = 12
    Align = alBottom
    TabOrder = 1
    OnClick = btnCancelClick
    Caption = 'btnCancel'
  end
  object tmProgress: TACLTimer
    Enabled = False
    Interval = 200
    OnTimer = tmProgressTimer
    Left = 560
    Top = 8
  end
end
