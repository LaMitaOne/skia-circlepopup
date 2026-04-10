program Project11;

uses
  Vcl.Forms,
  Unit9 in 'Unit9.pas' {Form9},
  SkiaCirclePopup in 'SkiaCirclePopup.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm9, Form9);
  Application.Run;
end.
