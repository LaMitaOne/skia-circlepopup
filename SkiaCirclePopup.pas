{*******************************************************************************
  Skia-CirclePopup;
********************************************************************************
  A floating circular popup menu rendered via Skia4Delphi
*******************************************************************************}
{ Skia-CirclePopup; v0.3                                                      }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
   v 0.3:
   - Per-Segment color hot tracking! Each segment fades individually.
   - Added smooth Fade-In and Fade-Out animations (Show/Close)
   v 0.2:
   - Using PNG Stream again for 100% safe VCL Alpha transfer
   - Replaced primitive VCL TransparentColor with WinAPI UpdateLayeredWindow
   - Added true drop shadows using Skia ImageFilters
   - Fixed segment calculation on mouse click (no longer inverted)
}
unit SkiaCirclePopup;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, Vcl.Forms, Vcl.Graphics, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Skia, Skia, Skia.API;

type
  TCirclePopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TPopupState = (psIdle, psFadeIn, psFadeOut);

  TSkiaCirclePopup = class(TComponent)
  private
    FPopupForm: TForm;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FInnerRadius: Integer;
    FOuterRadius: Integer;
    FCenter: TPointF;
    FGapAngle: Single;
    FSegmentColor: TAlphaColor;
    FHoverColor: TAlphaColor;
    FBorderColor: TAlphaColor;
    FTextColor: TAlphaColor;
    FHoverIndex: Integer;
    FOnSegmentClick: TCirclePopupClickEvent;
    FSegmentText: TStringList;
    // Animation States
    FAnimTimer: TTimer;
    FState: TPopupState;
    FCurrentAlpha: Integer;
    FPendingClickIndex: Integer;
    FIsClosing: Boolean;
    // Per-Segment Color Tracking
    FSegmentColors: array of TAlphaColor;
    procedure CreatePopupForm(StartX, StartY: Integer);
    function GetSegmentFromMouse(X, Y: Integer): Integer;
    procedure DoDraw;
    procedure PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PopupFormClick(Sender: TObject);
    procedure PopupFormClose(Sender: TObject; var Action: TCloseAction);
    procedure PopupFormDeactivate(Sender: TObject);
    procedure UpdateLayeredWindowFromBitmap;
    procedure AnimTimerTick(Sender: TObject);
    function BlendColorStep(Current, Target: TAlphaColor): TAlphaColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor; SegmentCount: Integer; SegmentText: array of string; OnClick: TCirclePopupClickEvent);
  end;

implementation

{ TSkiaCirclePopup }

constructor TSkiaCirclePopup.Create(AOwner: TComponent);
begin
  inherited;
  FSegmentText := TStringList.Create;
  FAnimTimer := TTimer.Create(nil);
  FAnimTimer.Enabled := False;
  FAnimTimer.Interval := 15; // ~60 FPS
  FAnimTimer.OnTimer := AnimTimerTick;
end;

destructor TSkiaCirclePopup.Destroy;
begin
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FAnimTimer.Free;
  FBuffer.Free;
  FSegmentText.Free;
  inherited;
end;

procedure TSkiaCirclePopup.CreatePopupForm(StartX, StartY: Integer);
var
  FormSize: Integer;
  ExStyle: Integer;
begin
  // Form size includes a 60px padding on all sides for the drop shadow
  FormSize := (FOuterRadius + 60) * 2;
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;
  FPopupForm.Color := clBlack;
  FPopupForm.ClientWidth := FormSize;
  FPopupForm.ClientHeight := FormSize;
  // Center form exactly on the requested screen coordinates
  FPopupForm.Left := StartX - (FormSize div 2);
  FPopupForm.Top := StartY - (FormSize div 2);
  FPopupForm.OnMouseMove := PopupFormMouseMove;
  FPopupForm.OnClick := PopupFormClick;
  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;
  FCenter := TPointF.Create(FormSize / 2, FormSize / 2);
  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afDefined;
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);
  // Convert form into a Layered Window for per-pixel alpha blending
  ExStyle := GetWindowLong(FPopupForm.Handle, GWL_EXSTYLE);
  SetWindowLong(FPopupForm.Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);
end;

procedure TSkiaCirclePopup.UpdateLayeredWindowFromBitmap;
var
  ScreenDC, MemDC: HDC;
  OldBitmap: HBITMAP;
  BlendFunc: TBlendFunction;
  PtZero: TPoint;
  Size: TSize;
begin
  if not Assigned(FPopupForm) or not Assigned(FBuffer) then
    Exit;
  ScreenDC := GetDC(0);
  try
    MemDC := CreateCompatibleDC(ScreenDC);
    try
      OldBitmap := SelectObject(MemDC, FBuffer.Handle);
      PtZero := Point(0, 0);
      Size.cx := FBuffer.Width;
      Size.cy := FBuffer.Height;
      BlendFunc.BlendOp := AC_SRC_OVER;
      BlendFunc.BlendFlags := 0;
      // Use FCurrentAlpha to support show/hide fading
      BlendFunc.SourceConstantAlpha := FCurrentAlpha;
      BlendFunc.AlphaFormat := AC_SRC_ALPHA;
      UpdateLayeredWindow(FPopupForm.Handle, ScreenDC, nil, @Size, MemDC, @PtZero, 0, @BlendFunc, ULW_ALPHA);
      SelectObject(MemDC, OldBitmap);
    finally
      DeleteDC(MemDC);
    end;
  finally
    ReleaseDC(0, ScreenDC);
  end;
end;

procedure TSkiaCirclePopup.PopupFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  FPopupForm := nil;
end;

procedure TSkiaCirclePopup.PopupFormDeactivate(Sender: TObject);
begin
  // Ignore deactivation if the form is already fading out
  if FIsClosing then
    Exit;
  if Assigned(FPopupForm) then
  begin
    FIsClosing := True;
    FState := psFadeOut;
    FPendingClickIndex := -1;
    FAnimTimer.Enabled := True;
  end;
end;

function TSkiaCirclePopup.BlendColorStep(Current, Target: TAlphaColor): TAlphaColor;
var
  R1, G1, B1, R2, G2, B2: Integer;
begin
  if Current = Target then
    Exit(Current);
  R1 := TAlphaColorRec(Current).R;
  G1 := TAlphaColorRec(Current).G;
  B1 := TAlphaColorRec(Current).B;
  R2 := TAlphaColorRec(Target).R;
  G2 := TAlphaColorRec(Target).G;
  B2 := TAlphaColorRec(Target).B;
  // Step color components towards the target for a smooth transition
  if R1 < R2 then
    Inc(R1, Min(15, R2 - R1))
  else if R1 > R2 then
    Dec(R1, Min(15, R1 - R2));
  if G1 < G2 then
    Inc(G1, Min(15, G2 - G1))
  else if G1 > G2 then
    Dec(G1, Min(15, G1 - G2));
  if B1 < B2 then
    Inc(B1, Min(15, B2 - B1))
  else if B1 > B2 then
    Dec(B1, Min(15, B1 - B2));
  TAlphaColorRec(Result).R := R1;
  TAlphaColorRec(Result).G := G1;
  TAlphaColorRec(Result).B := B1;
  TAlphaColorRec(Result).A := 255;
end;

procedure TSkiaCirclePopup.AnimTimerTick(Sender: TObject);
var
  I: Integer;
  TargetColor: TAlphaColor;
  NeedsRedraw: Boolean;
  LClickIndex: Integer;
  LCallback: TCirclePopupClickEvent;
  LText: string;
begin
  if not Assigned(FPopupForm) then
  begin
    FAnimTimer.Enabled := False;
    Exit;
  end;
  NeedsRedraw := False;

  // 1. Handle Show/Close Alpha-Fading
  case FState of
    psFadeIn:
      begin
        FCurrentAlpha := FCurrentAlpha + 25;
        if FCurrentAlpha >= 255 then
        begin
          FCurrentAlpha := 255;
          FState := psIdle;
        end;
        NeedsRedraw := True;
      end;
    psFadeOut:
      begin
        FCurrentAlpha := FCurrentAlpha - 25;
        if FCurrentAlpha <= 0 then
        begin
          FCurrentAlpha := 0;
          FAnimTimer.Enabled := False;
          FPopupForm.Hide;
        // Trigger click event safely after form is hidden
          LClickIndex := FPendingClickIndex;
          LCallback := FOnSegmentClick;
          LText := '';
          if (LClickIndex >= 0) and (LClickIndex < FSegmentText.Count) then
            LText := FSegmentText[LClickIndex];
          FPopupForm.Close;
          if (LClickIndex >= 0) and Assigned(LCallback) then
            LCallback(Self, LClickIndex, LText);
          Exit;
        end;
        NeedsRedraw := True;
      end;
    psIdle:
      begin
      // 2. Handle Per-Segment Color Blending
        for I := 0 to FSegmentCount - 1 do
        begin
          if I = FHoverIndex then
            TargetColor := FHoverColor
          else
            TargetColor := FSegmentColor;
          if FSegmentColors[I] <> TargetColor then
          begin
            FSegmentColors[I] := BlendColorStep(FSegmentColors[I], TargetColor);
            NeedsRedraw := True;
          end;
        end;
      end;
  end;

  // 3. Redraw and update screen if necessary
  if NeedsRedraw then
  begin
    DoDraw;
    UpdateLayeredWindowFromBitmap;
  end
  else
  begin
    // Pause timer to save CPU when fully visible and colors have settled
    if (FState = psIdle) and (FCurrentAlpha = 255) then
      FAnimTimer.Enabled := False;
  end;
end;

procedure TSkiaCirclePopup.ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor; SegmentCount: Integer; SegmentText: array of string; OnClick: TCirclePopupClickEvent);
var
  I: Integer;
begin
  if Assigned(FPopupForm) then
  begin
    FAnimTimer.Enabled := False;
    FPopupForm.Hide;
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FInnerRadius := InnerRadius;
  FOuterRadius := OuterRadius;
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 8;
  // Initialize individual colors for each segment
  SetLength(FSegmentColors, FSegmentCount);
  for I := 0 to FSegmentCount - 1 do
    FSegmentColors[I] := FSegmentColor;
  FSegmentText.Clear;
  for I := Low(SegmentText) to High(SegmentText) do
    FSegmentText.Add(SegmentText[I]);
  CreatePopupForm(StartX, StartY);
  FCurrentAlpha := 0;
  FIsClosing := False;
  DoDraw;
  UpdateLayeredWindowFromBitmap;
  FPopupForm.Show;
  // Start animation loop
  FState := psFadeIn;
  FAnimTimer.Enabled := True;
end;

procedure TSkiaCirclePopup.DoDraw;
var
  Surface: ISkSurface;
  Canvas: ISkCanvas;
  Paint: ISkPaint;
  SkFont: TSkFont;
  SkTypeface: ISkTypeface;
  SkStyle: TSkFontStyle;
  SkImgInfo: TSkImageInfo;
  SkImage: ISkImage;
  OuterRect, InnerRect: TRectF;
  I: Integer;
  SegmentAngle, TotalCycle: Double;
  AngleStart, MidAngle: Double;
  TextPos: TPointF;
  TextSize: TSize;
  MemStream: TMemoryStream;
  PngImage: TPngImage;
  PathBuilder: ISkPathBuilder;
  SegPath: ISkPath;
begin
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);
  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;
    Canvas.Clear(TAlphaColorRec.Null);
    OuterRect := TRectF.Create(FCenter.X - FOuterRadius, FCenter.Y - FOuterRadius, FCenter.X + FOuterRadius, FCenter.Y + FOuterRadius);
    InnerRect := TRectF.Create(FCenter.X - FInnerRadius, FCenter.Y - FInnerRadius, FCenter.X + FInnerRadius, FCenter.Y + FInnerRadius);
    SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
    TotalCycle := SegmentAngle + FGapAngle;
    Paint := TSkPaint.Create;
    Paint.AntiAlias := True;
    Paint.Style := TSkPaintStyle.Fill;
    PathBuilder := TSkPathBuilder.Create;
    for I := 0 to FSegmentCount - 1 do
    begin
      AngleStart := FGapAngle / 2 + I * TotalCycle;
      PathBuilder.Reset;
      PathBuilder.MoveTo(FCenter.X + FOuterRadius * Cos(DegToRad(AngleStart)), FCenter.Y + FOuterRadius * Sin(DegToRad(AngleStart)));
      PathBuilder.ArcTo(OuterRect, AngleStart, SegmentAngle, False);
      PathBuilder.LineTo(FCenter.X + FInnerRadius * Cos(DegToRad(AngleStart + SegmentAngle)), FCenter.Y + FInnerRadius * Sin(DegToRad(AngleStart + SegmentAngle)));
      PathBuilder.ArcTo(InnerRect, AngleStart + SegmentAngle, -SegmentAngle, False);
      PathBuilder.Close;
      SegPath := PathBuilder.Detach;
      // Draw Drop Shadow
      Paint.AntiAlias := False;
      Paint.Color := TAlphaColors.Black;
      Paint.ImageFilter := TSkImageFilter.MakeDropShadow(0, 12, 12, 12, TAlphaColors.Black);
      Canvas.DrawPath(SegPath, Paint);
      Paint.ImageFilter := nil;
      Paint.AntiAlias := True;
      // Fill segment using its individual tracked color
      Paint.Color := FSegmentColors[I];
      Canvas.DrawPath(SegPath, Paint);
      // Draw Inner 3D Border
      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 3;
      Paint.Color := $40000000;
      Canvas.DrawPath(SegPath, Paint);
      Paint.Style := TSkPaintStyle.Fill;
    end;
    // Draw Text
    SkStyle := TSkFontStyle.Bold;
    SkTypeface := TSkTypeface.MakeFromName('Tahoma', SkStyle);
    SkFont := TSkFont.Create(SkTypeface, 12);
    Paint.Style := TSkPaintStyle.Fill;
    Paint.AntiAlias := True;
    Paint.Color := FTextColor;
    if Assigned(FPopupForm) then
    begin
      FPopupForm.Canvas.Font.Name := 'Tahoma';
      FPopupForm.Canvas.Font.Size := 12;
      FPopupForm.Canvas.Font.Style := [fsBold];
    end;
    for I := 0 to FSegmentCount - 1 do
    begin
      if (I < FSegmentText.Count) and (FSegmentText[I] <> '') then
      begin
        AngleStart := FGapAngle / 2 + I * TotalCycle;
        MidAngle := AngleStart + (SegmentAngle / 2);
        var R := FInnerRadius + (FOuterRadius - FInnerRadius) / 2;
        TextPos.X := FCenter.X + R * Cos(DegToRad(MidAngle));
        TextPos.Y := FCenter.Y + R * Sin(DegToRad(MidAngle));
        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2);
          TextPos.Y := TextPos.Y - (TextSize.cy / 2) + 14;
        end;
        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y, SkFont, Paint);
      end;
    end;
    // Transfer Skia Surface to VCL Bitmap via PNG Stream
    SkImage := Surface.MakeImageSnapshot;
    if Assigned(SkImage) then
    begin
      MemStream := TMemoryStream.Create;
      try
        if SkImage.EncodeToStream(MemStream, TSkEncodedImageFormat.PNG) then
        begin
          if MemStream.Size > 0 then
          begin
            MemStream.Position := 0;
            PngImage := TPngImage.Create;
            try
              PngImage.LoadFromStream(MemStream);
              FBuffer.Canvas.Lock;
              try
                FBuffer.Canvas.Brush.Color := clBlack;
                FBuffer.Canvas.FillRect(FBuffer.Canvas.ClipRect);
                FBuffer.Canvas.Draw(0, 0, PngImage);
              finally
                FBuffer.Canvas.Unlock;
              end;
            finally
              PngImage.Free;
            end;
          end;
        end;
      finally
        MemStream.Free;
      end;
    end;
  end;
end;

procedure TSkiaCirclePopup.PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewIndex: Integer;
begin
  if FIsClosing then
    Exit;
  NewIndex := GetSegmentFromMouse(X, Y);
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
  end;
  // Wake up the timer immediately for zero-latency fading
  if not FAnimTimer.Enabled then
    FAnimTimer.Enabled := True;
end;

procedure TSkiaCirclePopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  if FIsClosing then
    Exit;
  Pt := FPopupForm.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);
  FIsClosing := True;
  FState := psFadeOut;
  if Index >= 0 then
    FPendingClickIndex := Index
  else
    FPendingClickIndex := -1;
  FAnimTimer.Enabled := True;
end;

function TSkiaCirclePopup.GetSegmentFromMouse(X, Y: Integer): Integer;
var
  Angle: Double;
  SegmentAngle, TotalCycle: Double;
  Dx, Dy, Dist: Single;
begin
  Result := -1;
  Dx := X - FCenter.X;
  Dy := Y - FCenter.Y;
  Dist := Sqrt(Dx * Dx + Dy * Dy);
  // Check if mouse is inside the segment ring
  if (Dist < FInnerRadius) or (Dist > FOuterRadius) then
    Exit;
  Angle := RadToDeg(ArcTan2(Dy, Dx));
  if Angle < 0 then
    Angle := Angle + 360;
  SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
  TotalCycle := SegmentAngle + FGapAngle;
  Angle := Angle - FGapAngle / 2;
  if Angle < 0 then
    Angle := Angle + 360;
  Result := Floor(Angle / TotalCycle);
  if Result >= FSegmentCount then
    Result := FSegmentCount - 1;
end;

end.

