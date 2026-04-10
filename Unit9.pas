unit Unit9;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, SkiaCirclePopup;

type
  TForm9 = class(TForm)
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private-Deklarationen }
    procedure HandleSegmentClick(Sender: TObject; SegmentIndex: Integer; const SegmentText: string);
  public
    { Public-Deklarationen }
  end;

var
  Form9: TForm9;

implementation

{$R *.dfm}

procedure TForm9.HandleSegmentClick(Sender: TObject; SegmentIndex: Integer; const SegmentText: string);
begin
  Showmessage('clicked - ' + inttostr(SegmentIndex));
end;

procedure TForm9.Button1Click(Sender: TObject);
var
  Popup: TSkiaCirclePopup;
  Items: array of string;
begin
  SetLength(Items, 6);
  Items[0] := '10%';
  Items[1] := '30%';
  Items[2] := '50%';
  Items[3] := '70%';
  Items[4] := '90%';
  Items[5] := '100%';

  Popup := TSkiaCirclePopup.Create(nil);
  Popup.ShowSkiaCirclePopup(Mouse.CursorPos.X,    // X
    Mouse.CursorPos.Y,    // Y
    20,                   // InnerRadius
    60,                   // OuterRadius
    clGray,              // SegmentColor
    clAqua,               // HoverColor
    TColor($00333300),    // BorderColor
    clBlack,               // TextColor
    6,                    // SegmentCount
    Items,                // SegmentText
    HandleSegmentClick);  // OnClick


end;

end.

