# skia-circlepopup  

SkiaCirclePopup   

<img width="403" height="301" alt="Unbenannt" src="https://github.com/user-attachments/assets/99a17eb5-36db-465b-a86d-4cddeb384964" />
   
Very early proof-of-concept (Alpha 0.1). A floating circular popup menu rendered via Skia4Delphi instead of standard VCL canvas.    
    
First lifesign and looks promising, but absolutely NOT finished. We got it drawing and functioning, which is great, but let's be real: the graphics are still far from crisp. We are currently fighting horrible edge halos and anti-aliasing dirt because of a messy VCL/Alpha workaround we had to use to even get it to show up transparently.     
    
So yes, Skia renders it and it looks slightly less horrible than a pure VCL attempt, but it's still not where it needs to be. Could definitely make something good out of this     with more work, but don't expect a polished component yet.    
    
See the included sample project to test it.    
