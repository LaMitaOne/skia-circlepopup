{*******************************************************************************
  Skia-CirclePopup;
********************************************************************************
  A floating circular popup menu rendered via Skia4Delphi

*******************************************************************************}
{ Skia-CirclePopup; v0.1                                                   }
{ by Lara Miriam Tamy Reschke                                                                }
{                                                                              }
{------------------------------------------------------------------------------}
{
  Latest Changes:
   v 0.1:
   - First running lifesign
}

unit SkiaCirclePopup;

interface
uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  Vcl.Forms, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls, System.IOUtils,
  Vcl.Skia, Skia, Skia.API, vcl.Imaging.pngimage, vcl.Imaging.jpeg ;

type
  TCirclePopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TSkiaCirclePopup = class(TComponent)
  private
    FPopupForm: TForm;
    FPopupImage: TImage;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FInnerRadius: Integer;
    FOuterRadius: Integer;
    FCenter: TPointF;
    FGapAngle: Single;
    FSegmentColor: TColor;
    FHoverColor: TColor;
    FBorderColor: TColor;
    FTextColor: TColor;
    FHoverIndex: Integer;
    FOnSegmentClick: TCirclePopupClickEvent;
    FSegmentText: TStringList;

    procedure CreatePopupForm(StartX, StartY: Integer);
    function GetSegmentFromMouse(X, Y: Integer): Integer;
    procedure DoDraw;
    procedure PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PopupFormClick(Sender: TObject);
    procedure PopupFormClose(Sender: TObject; var Action: TCloseAction);
    procedure PopupFormDeactivate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
      SegmentColor, HoverColor, BorderColor, TextColor: TColor;
      SegmentCount: Integer; SegmentText: array of string;
      OnClick: TCirclePopupClickEvent);
  end;

implementation

{ TSkiaCirclePopup }

constructor TSkiaCirclePopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSegmentText := TStringList.Create;
end;

destructor TSkiaCirclePopup.Destroy;
begin
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FBuffer.Free;
  FSegmentText.Free;
  inherited Destroy;
end;

procedure TSkiaCirclePopup.CreatePopupForm(StartX, StartY: Integer);
begin
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;

  FPopupForm.Color := clFuchsia;
  FPopupForm.TransparentColor := True;
  FPopupForm.TransparentColorValue := clFuchsia;

  FPopupForm.ClientWidth := FOuterRadius * 2;
  FPopupForm.ClientHeight := FOuterRadius * 2;
  FPopupForm.Left := StartX - FOuterRadius;
  FPopupForm.Top := StartY - FOuterRadius;

  FPopupImage := TImage.Create(FPopupForm);
  FPopupImage.Parent := FPopupForm;
  FPopupImage.Align := alClient;
  FPopupImage.Stretch := False;
  FPopupImage.Center := False;
  FPopupImage.Transparent := True;

  FPopupImage.OnMouseMove := PopupFormMouseMove;
  FPopupImage.OnClick := PopupFormClick;

  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  FCenter := TPointF.Create(FOuterRadius, FOuterRadius);

  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    // DO NOT use afDefined! We want VCL to ignore the alpha and just look at RGB.
    FBuffer.AlphaFormat := afIgnored;
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);

  FPopupImage.Picture.Assign(nil);
  FPopupImage.Picture.Bitmap := FBuffer;
end;

procedure TSkiaCirclePopup.PopupFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  FPopupForm := nil;
end;

procedure TSkiaCirclePopup.PopupFormDeactivate(Sender: TObject);
begin
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

procedure TSkiaCirclePopup.ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
  SegmentColor, HoverColor, BorderColor, TextColor: TColor;
  SegmentCount: Integer; SegmentText: array of string;
  OnClick: TCirclePopupClickEvent);
var
  I: Integer;
begin
  FInnerRadius := InnerRadius;
  FOuterRadius := OuterRadius;
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 6;
  FSegmentText.Clear;
  for I := Low(SegmentText) to High(SegmentText) do
    FSegmentText.Add(SegmentText[I]);

  CreatePopupForm(StartX, StartY);
  DoDraw;
  FPopupForm.Show;
end;

procedure TSkiaCirclePopup.DoDraw;
var
  Surface: ISkSurface;
  Canvas: ISkCanvas;
  PathBuilder: ISkPathBuilder;
  Path: ISkPath;
  Paint: ISkPaint;
  SkFont: TSkFont;
  SkTypeface: ISkTypeface;
  SkStyle: TSkFontStyle;
  SkImgInfo: TSkImageInfo;
  SkImage: ISkImage;
  MemStream: TMemoryStream;
  OuterRect, InnerRect: TRectF;
  I: Integer;
  SegmentAngle, TotalCycle: Double;
  AngleStart, AngleEnd, MidAngle: Double;
  LineStartX, LineStartY, LineEndX, LineEndY: Double;
  TextPos: TPointF;
  TextSize: TSize;
begin
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);

  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;

    // 1. Fuchsia background!
    Canvas.Clear(TAlphaColors.Fuchsia);

    // 2. Draw the simple gray circle
    OuterRect := TRectF.Create(FCenter.X - FOuterRadius, FCenter.Y - FOuterRadius,
                               FCenter.X + FOuterRadius, FCenter.Y + FOuterRadius);

    Paint := TSkPaint.Create;
    Paint.AntiAlias := False;
    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Gray;

    Canvas.DrawOval(OuterRect, Paint);

    // ==========================================
    // 3. DRAW THE SPLIT LINES (GAPS)
    // ==========================================
    SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
    TotalCycle := SegmentAngle + FGapAngle;

    PathBuilder := TSkPathBuilder.Create;
    Paint.Style := TSkPaintStyle.Stroke;
    Paint.StrokeWidth := FGapAngle;
    Paint.Color := TAlphaColors.Fuchsia;

    for I := 0 to FSegmentCount - 1 do
    begin
      AngleStart := I * TotalCycle;

      LineStartX := FCenter.X + FInnerRadius * Cos(DegToRad(AngleStart));
      LineStartY := FCenter.Y + FInnerRadius * Sin(DegToRad(AngleStart));
      LineEndX   := FCenter.X + FOuterRadius * Cos(DegToRad(AngleStart));
      LineEndY   := FCenter.Y + FOuterRadius * Sin(DegToRad(AngleStart));

      PathBuilder.Reset;
      PathBuilder.MoveTo(LineStartX, LineStartY);
      PathBuilder.LineTo(LineEndX, LineEndY);
      Path := PathBuilder.Snapshot;

      Canvas.DrawPath(Path, Paint);
    end;

    // ==========================================
    // 4. PUNCH THE MIDDLE HOLE
    // ==========================================
    InnerRect := TRectF.Create(FCenter.X - FInnerRadius, FCenter.Y - FInnerRadius,
                               FCenter.X + FInnerRadius, FCenter.Y + FInnerRadius);

    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Fuchsia;

    Canvas.DrawOval(InnerRect, Paint);

    // ==========================================
    // 5. DRAW THE TEXT (Perfectly Centered)
    // ==========================================
    SkStyle := TSkFontStyle.Normal;
    SkTypeface := TSkTypeface.MakeFromName('Tahoma', SkStyle);
    SkFont := TSkFont.Create(SkTypeface, 11);

    Paint.Style := TSkPaintStyle.Fill;
    Paint.Color := TAlphaColors.Aqua;


    // Prepare VCL Canvas to measure text
    if Assigned(FPopupForm) then
    begin
      FPopupForm.Canvas.Font.Name := 'Tahoma';
      FPopupForm.Canvas.Font.Size := 11;
    end;

    for I := 0 to FSegmentCount - 1 do
    begin
      if (I < FSegmentText.Count) and (FSegmentText[I] <> '') then
      begin
        AngleStart := FGapAngle / 2 + I * TotalCycle;
        AngleEnd := AngleStart + SegmentAngle;
        MidAngle := (AngleStart + AngleEnd) / 2;

        var R := FInnerRadius + (FOuterRadius - FInnerRadius) / 2;
        TextPos.X := FCenter.X + R * Cos(DegToRad(MidAngle));
        TextPos.Y := FCenter.Y + R * Sin(DegToRad(MidAngle));

        // --- THE FIX: Use Windows API to measure text width ---
        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2); // Shift left by half the width
        end;

        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y + (7 * 0.3), SkFont, Paint);
      end;
    end;

    // ==========================================
    // 6. SAVE TO MEMORY AND LOAD
    // ==========================================
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
            if Assigned(FPopupImage) then
              FPopupImage.Picture.LoadFromStream(MemStream);
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
  NewIndex := GetSegmentFromMouse(X, Y);
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
    DoDraw;
    if Assigned(FPopupImage) then
      FPopupImage.Invalidate;
  end;
end;

procedure TSkiaCirclePopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  Pt := FPopupImage.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);
  if (Index >= 0) and Assigned(FOnSegmentClick) then
  begin
    Index := FSegmentCount - 1 - Index;
    FOnSegmentClick(Self, Index, FSegmentText[Index]);
  end;
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

function TSkiaCirclePopup.GetSegmentFromMouse(X, Y: Integer): Integer;
var
  Angle: Double;
  SegmentAngle, TotalCycle: Double;
  Dx, Dy: Single;
  Dist: Single;
begin
  Result := -1;
  Dx := X - FCenter.X;
  Dy := Y - FCenter.Y;
  Dist := Sqrt(Dx*Dx + Dy*Dy);
  if (Dist < FInnerRadius) or (Dist > FOuterRadius) then Exit;

  Angle := RadToDeg(ArcTan2(Dy, Dx));
  if Angle < 0 then Angle := Angle + 360;
  Angle := 360 - Angle;
  Angle := Angle + 90;
  if Angle >= 360 then Angle := Angle - 360;

  SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
  TotalCycle := SegmentAngle + FGapAngle;
  Angle := Angle - FGapAngle/2;
  if Angle < 0 then Angle := Angle + 360;

  Result := Floor(Angle / TotalCycle);
  if Result >= FSegmentCount then Result := FSegmentCount - 1;
end;

end.
