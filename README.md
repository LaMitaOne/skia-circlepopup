# skia-circlepopup  
A floating, circular popup menu for Delphi VCL, rendered entirely via Skia4Delphi.
   
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/skia-circlepopup)
    
<img width="360" height="202" alt="circle" src="https://github.com/user-attachments/assets/dc4dbfb8-49e5-491a-8b17-f74be945c374" />

Sample video: https://www.youtube.com/watch?v=Pr-IEDD7OKU 
    
Bypasses standard VCL limitations by using the Windows UpdateLayeredWindow API combined with Skia to deliver a smooth, anti-aliased radial menu with true per-pixel alpha transparency and soft drop shadows. No clFuchsia masking, no jagged edges, no flickering.    
     
Latest Changes: https://youtu.be/Pr-IEDD7OKU  
     
   v 0.4:
   
    No more png convert neeeded      
         
   v 0.3:
   
    Per-Segment color hot tracking! Each segment fades individually.   
    Added smooth Fade-In and Fade-Out animations (Show/Close)   
         
   v 0.2:
   
    True Anti-Aliasing & Alpha: Flawless per-pixel transparency via WS_EX_LAYERED.   
    Drop Shadows: Genuine, soft drop shadows rendered via Skia ImageFilter.   
    Zero Flicker: Rendered off-screen and pushed directly to the Windows Compositor.   
    Hover States: Segments change color on mouse hover.   

    
Requirements     
     
    Delphi (10.3 Rio or newer recommended)
    Skia4Delphi must be installed.
     

zipped exe and sample project included   
    
Now it's slowly looking bit better than d7 vcl version 🙃    
     
     
🎨 Skia4Delphi Components:    
   Alive Progress/Loading circle https://github.com/LaMitaOne/SkiaAliveProgress   
   Audio Visualizer https://github.com/LaMitaOne/SkiaAVisualizer        
   CustomThreadedBase (this i use mostly) https://github.com/LaMitaOne/SkiaCustomThreadedBase    
   Skia Alive Grid https://github.com/LaMitaOne/Skia-AliveGrid    
   Skia-Flowmotion animated image grid https://github.com/LaMitaOne/skia-flowmotion   
   Skia-Slideshow https://github.com/LaMitaOne/Skia-Slideshow   
   Skia-Circlepopup https://github.com/LaMitaOne/skia-circlepopup  
   Skia-CubesPopup https://github.com/LaMitaOne/SkiaCubesPopup   
   Skia-Button https://github.com/LaMitaOne/SkiaButton    
   Skia Desktop Pet https://github.com/LaMitaOne/SkiaDesktopPetBase    
         
🧪 Skia4Delphi experimental Components:    
   CustomMultithreadedBase  https://github.com/LaMitaOne/SkiaCustomMultiThreadedBase    
   Page Control https://github.com/LaMitaOne/SkiaPageControl   
   Surface Widget/modules rendering engine https://github.com/LaMitaOne/MRX-Skia-Surface   
   LCARS fluid engine https://github.com/LaMitaOne/Skia-LCARS-Fluid-Engine   
   Fluid Magma effect https://github.com/LaMitaOne/Fluid-Magma-Effect    
      
