{*******************************************************************************
  Skia-CirclePopup;
********************************************************************************
  A floating circular popup menu rendered via Skia4Delphi

*******************************************************************************}
{ Skia-CirclePopup; v0.2                                                       }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
  Latest Changes:
   v 0.2:
   - Using PNG Stream again for 100% safe VCL Alpha transfer
   - Replaced primitive VCL TransparentColor with WinAPI UpdateLayeredWindow
   - Added true drop shadows using Skia ImageFilters
   - Fixed segment calculation on mouse click (no longer inverted)
}

unit SkiaCirclePopup;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils,
  Vcl.Forms, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg,
  Vcl.Skia, Skia, Skia.API;

type
  TCirclePopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

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

    procedure CreatePopupForm(StartX, StartY: Integer);
    function GetSegmentFromMouse(X, Y: Integer): Integer;
    procedure DoDraw;
    procedure PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PopupFormClick(Sender: TObject);
    procedure PopupFormClose(Sender: TObject; var Action: TCloseAction);
    procedure PopupFormDeactivate(Sender: TObject);
    procedure UpdateLayeredWindowFromBitmap;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
      SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor;
      SegmentCount: Integer; SegmentText: array of string;
      OnClick: TCirclePopupClickEvent);
  end;

implementation

{ TSkiaCirclePopup }

constructor TSkiaCirclePopup.Create(AOwner: TComponent);
begin
  inherited;
  // Initialize the string list to hold the text for each segment
  FSegmentText := TStringList.Create;
end;

destructor TSkiaCirclePopup.Destroy;
begin
  // Clean up the popup form and buffer to prevent memory leaks
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FBuffer.Free;
  FSegmentText.Free;
  inherited;
end;

procedure TSkiaCirclePopup.CreatePopupForm(StartX, StartY: Integer);
var
  FormSize: Integer;
  ExStyle: Integer;
begin
  // Calculate form size: We add 60 pixels of padding around the outer radius.
  // This empty space is strictly reserved for the drop shadow to bleed into.
  FormSize := (FOuterRadius + 60) * 2;

  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;
  FPopupForm.Color := clBlack; // Background color doesn't matter due to layered window

  FPopupForm.ClientWidth := FormSize;
  FPopupForm.ClientHeight := FormSize;

  // Center the form exactly on the requested screen coordinates
  FPopupForm.Left := StartX - (FormSize div 2);
  FPopupForm.Top := StartY - (FormSize div 2);

  // Assign interaction events
  FPopupForm.OnMouseMove := PopupFormMouseMove;
  FPopupForm.OnClick := PopupFormClick;
  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  // The drawing center shifts because the form is larger than the circle itself
  FCenter := TPointF.Create(FormSize / 2, FormSize / 2);

  // Create and configure the 32-bit VCL Bitmap buffer.
  // afDefined tells VCL that the bitmap contains a valid alpha channel.
  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afDefined;
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);

  // Crucial step: Convert the form into a Layered Window.
  // This allows per-pixel alpha blending via UpdateLayeredWindow.
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
  if not Assigned(FPopupForm) or not Assigned(FBuffer) then Exit;

  // Get device contexts for drawing
  ScreenDC := GetDC(0);
  try
    MemDC := CreateCompatibleDC(ScreenDC);
    try
      // Select our rendered bitmap into the memory DC
      OldBitmap := SelectObject(MemDC, FBuffer.Handle);

      PtZero := Point(0, 0);
      Size.cx := FBuffer.Width;
      Size.cy := FBuffer.Height;

      // Setup alpha blending parameters
      BlendFunc.BlendOp := AC_SRC_OVER;
      BlendFunc.BlendFlags := 0;
      BlendFunc.SourceConstantAlpha := 255; // Use per-pixel alpha, not global
      BlendFunc.AlphaFormat := AC_SRC_ALPHA; // Pre-multiplied alpha format

      // Push the bitmap to the Windows compositor. This creates the actual
      // floating, transparent window with perfect anti-aliased edges.
      UpdateLayeredWindow(
        FPopupForm.Handle,
        ScreenDC,
        nil,
        @Size,
        MemDC,
        @PtZero,
        0,
        @BlendFunc,
        ULW_ALPHA
      );

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
  // Free the form automatically when closed
  Action := caFree;
  FPopupForm := nil;
end;

procedure TSkiaCirclePopup.PopupFormDeactivate(Sender: TObject);
begin
  // Close the popup if the user clicks away or alt-tabs
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

procedure TSkiaCirclePopup.ShowSkiaCirclePopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
  SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor;
  SegmentCount: Integer; SegmentText: array of string;
  OnClick: TCirclePopupClickEvent);
var
  I: Integer;
begin
  // Store all visual parameters locally
  FInnerRadius := InnerRadius;
  FOuterRadius := OuterRadius;
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 8; // Angle in degrees between segments

  FSegmentText.Clear;
  for I := Low(SegmentText) to High(SegmentText) do
    FSegmentText.Add(SegmentText[I]);

  // Boot up the popup
  CreatePopupForm(StartX, StartY);
  DoDraw;
  FPopupForm.Show;
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
  // Initialize Skia raster surface matching the VCL buffer dimensions
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);

  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;

    // 1. Clear the canvas completely. TAlphaColorRec.Null makes it 100% transparent.
    // This is vital for the drop shadow and alpha blending to work correctly.
    Canvas.Clear(TAlphaColorRec.Null);

    // Define the outer and inner bounding boxes for the circle segments
    OuterRect := TRectF.Create(FCenter.X - FOuterRadius, FCenter.Y - FOuterRadius,
                               FCenter.X + FOuterRadius, FCenter.Y + FOuterRadius);

    InnerRect := TRectF.Create(FCenter.X - FInnerRadius, FCenter.Y - FInnerRadius,
                               FCenter.X + FInnerRadius, FCenter.Y + FInnerRadius);

    // Calculate angles: Total 360 degrees minus the gaps between segments
    SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
    TotalCycle := SegmentAngle + FGapAngle;

    Paint := TSkPaint.Create;
    Paint.AntiAlias := True; // Smooth curves!
    Paint.Style := TSkPaintStyle.Fill;

    PathBuilder := TSkPathBuilder.Create;

    // 2. DRAW SEGMENTS
    for I := 0 to FSegmentCount - 1 do
    begin
      AngleStart := FGapAngle / 2 + I * TotalCycle;

      // Build a perfect donut-slice path using arcs and lines
      PathBuilder.Reset;
      PathBuilder.MoveTo(FCenter.X + FOuterRadius * Cos(DegToRad(AngleStart)),
                         FCenter.Y + FOuterRadius * Sin(DegToRad(AngleStart)));
      PathBuilder.ArcTo(OuterRect, AngleStart, SegmentAngle, False);
      PathBuilder.LineTo(FCenter.X + FInnerRadius * Cos(DegToRad(AngleStart + SegmentAngle)),
                         FCenter.Y + FInnerRadius * Sin(DegToRad(AngleStart + SegmentAngle)));
      PathBuilder.ArcTo(InnerRect, AngleStart + SegmentAngle, -SegmentAngle, False);
      PathBuilder.Close;
      SegPath := PathBuilder.Detach;

      // A) DROP SHADOW: Render the shadow first so it sits beneath the segment.
      // DX=0, DY=12 pushes the shadow downwards.
      // We temporarily disable AntiAlias for the shadow filter to prevent white fringing.
      Paint.AntiAlias := False;
      Paint.Color := TAlphaColors.Black;
      Paint.ImageFilter := TSkImageFilter.MakeDropShadow(0, 12, 12, 12, TAlphaColors.Black);
      Canvas.DrawPath(SegPath, Paint);

      // Clear filter and re-enable AntiAlias for the actual segment
      Paint.ImageFilter := nil;
      Paint.AntiAlias := True;

      // B) FILL SEGMENT: Choose color based on hover state
      if I = FHoverIndex then
        Paint.Color := FHoverColor
      else
        Paint.Color := FSegmentColor;

      Canvas.DrawPath(SegPath, Paint);

      // C) INNER 3D BORDER: Draw a semi-transparent stroke inside the segment
      // to give it a slight bevelled/3D depth effect.
      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 3;
      Paint.Color := $40000000; // 25% Opaque Black
      Canvas.DrawPath(SegPath, Paint);
      Paint.Style := TSkPaintStyle.Fill;
    end;

    // 3. DRAW TEXT
    // We use Skia's font management but leverage VCL's GetTextExtentPoint32
    // to accurately measure the text width for centering.
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

        // Find the exact center point of the segment ring
        var R := FInnerRadius + (FOuterRadius - FInnerRadius) / 2;
        TextPos.X := FCenter.X + R * Cos(DegToRad(MidAngle));
        TextPos.Y := FCenter.Y + R * Sin(DegToRad(MidAngle));

        // Measure text and adjust position to center it perfectly
        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2);
          // The +14 offsets the baseline so the text is visually centered vertically
          TextPos.Y := TextPos.Y - (TextSize.cy / 2) + 14;
        end;

        // Text is drawn completely straight (no rotation) for maximum readability
        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y, SkFont, Paint);
      end;
    end;

    // 4. TRANSFER TO VCL (The PNG Stream trick)
    // Render the finished Skia canvas to a PNG stream.
    // This guarantees that the alpha channel is perfectly preserved and
    // prevents the VCL from flipping the Y-axis or messing up the pre-multiplied alpha.
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

              // Draw the PNG onto our 32-bit VCL bitmap.
              // We fill it with black first (though transparent PNG handles alpha well).
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

      // 5. PUSH TO SCREEN
      // Tell Windows to update the layered form with our newly rendered bitmap
      UpdateLayeredWindowFromBitmap;
    end;
  end;
end;

procedure TSkiaCirclePopup.PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewIndex: Integer;
begin
  // Check which segment the mouse is hovering over
  NewIndex := GetSegmentFromMouse(X, Y);

  // Only redraw if the hover index changed to save performance
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
    DoDraw;
  end;
end;

procedure TSkiaCirclePopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  // Get mouse position relative to the form
  Pt := FPopupForm.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);

  // Hide first to prevent visual glitches on close
  if Assigned(FPopupForm) then
    FPopupForm.Hide;

  // Trigger the callback if a valid segment was clicked
  if (Index >= 0) and Assigned(FOnSegmentClick) then
  begin
    FOnSegmentClick(Self, Index, FSegmentText[Index]);
  end;

  // Finally destroy the form
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

  // Calculate distance from center
  Dx := X - FCenter.X;
  Dy := Y - FCenter.Y;
  Dist := Sqrt(Dx*Dx + Dy*Dy);

  // If the click is inside the inner hole or outside the outer edge, ignore it
  if (Dist < FInnerRadius) or (Dist > FOuterRadius) then Exit;

  // Calculate angle. ArcTan2 returns radians. 0 is right, goes clockwise (Y is down in screen coords)
  Angle := RadToDeg(ArcTan2(Dy, Dx));
  if Angle < 0 then Angle := Angle + 360;

  // Calculate segment size like in DoDraw
  SegmentAngle := (360 - FGapAngle * FSegmentCount) / FSegmentCount;
  TotalCycle := SegmentAngle + FGapAngle;

  // Adjust angle to account for the initial gap offset
  Angle := Angle - FGapAngle/2;
  if Angle < 0 then Angle := Angle + 360;

  // Determine which segment index belongs to this angle
  Result := Floor(Angle / TotalCycle);
  if Result >= FSegmentCount then Result := FSegmentCount - 1;
end;

end.
