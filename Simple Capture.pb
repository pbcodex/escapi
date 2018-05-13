;/* Extremely Simple Capture API */

Structure SimpleCapParams
  *mTargetBuf ; Must be at least mWidth * mHeight * SizeOf(int) of size! 
  mWidth.l
  mHeight.l
EndStructure

;/* Return the number of capture devices found */
PrototypeC countCaptureDevicesProc()

; /* initCapture tries To open the video capture device. 
;  * Returns 0 on failure, 1 on success. 
;  * Note: Capture parameter values must Not change While capture device
;  *       is in use (i.e. between initCapture And deinitCapture).
;  *       Do *Not* free the target buffer, Or change its pointer!
;  */
PrototypeC initCaptureProc(deviceno, *aParams.SimpleCapParams)

;/* deinitCapture closes the video capture device. */
PrototypeC deinitCaptureProc(deviceno)

;/* doCapture requests video frame To be captured. */
PrototypeC doCaptureProc(deviceno)

;/* isCaptureDone returns 1 when the requested frame has been captured.*/
PrototypeC isCaptureDoneProc(deviceno)


;/* Get the user-friendly name of a capture device. */
PrototypeC getCaptureDeviceNameProc(deviceno, *namebuffer, bufferlength)


;/* Returns the ESCAPI DLL version. 0x200 For 2.0 */
PrototypeC ESCAPIDLLVersionProc()

; marked as "internal" in the example
PrototypeC initCOMProc()

Global countCaptureDevices.countCaptureDevicesProc
Global initCapture.initCaptureProc
Global deinitCapture.deinitCaptureProc
Global doCapture.doCaptureProc
Global isCaptureDone.isCaptureDoneProc
Global getCaptureDeviceName.getCaptureDeviceNameProc
Global ESCAPIDLLVersion.ESCAPIDLLVersionProc


Procedure setupESCAPI()
  
  ; load library
  CompilerSelect #PB_Compiler_Processor
    CompilerCase #PB_Processor_x86
      Protected.i capdll = OpenLibrary(#PB_Any, "escapi_x32.dll")
    CompilerCase #PB_Processor_x64
      Protected.i capdll = OpenLibrary(#PB_Any, "escapi_x64.dll")
  CompilerEndSelect
  If capdll = 0
    ProcedureReturn 0
  EndIf
  
  ;/* Fetch function entry points */
  countCaptureDevices  = GetFunction(capdll, "countCaptureDevices")
  initCapture          = GetFunction(capdll, "initCapture")
  deinitCapture        = GetFunction(capdll, "deinitCapture")
  doCapture            = GetFunction(capdll, "doCapture")
  isCaptureDone        = GetFunction(capdll, "isCaptureDone")
  initCOM.initCOMProc  = GetFunction(capdll, "initCOM")
  getCaptureDeviceName = GetFunction(capdll, "getCaptureDeviceName")
  ESCAPIDLLVersion     = GetFunction(capdll, "ESCAPIDLLVersion")
  
  If countCaptureDevices = 0 Or initCapture = 0 Or deinitCapture = 0 Or doCapture = 0 Or isCaptureDone = 0 Or initCOM = 0 Or getCaptureDeviceName = 0 Or ESCAPIDLLVersion = 0
    ProcedureReturn 0
  EndIf
  
  ;/* Verify DLL version */
  If ESCAPIDLLVersion() < $200
    ProcedureReturn 0
  EndIf
  
  ;/* Initialize COM.. */
  initCOM();  
  
  ; returns number of devices found
  ProcedureReturn countCaptureDevices()
EndProcedure

;Test Area
device = 0

count = setupESCAPI()
Debug "init: " + Str(count)

If count = 0
  End
EndIf

name$ = Space(1000)
getCaptureDeviceName(device, @name$, 1000)
name$ = PeekS(@name$, -1, #PB_Ascii)
Debug "name: " + name$

scp.SimpleCapParams
scp\mWidth = 320
scp\mHeight = 240
scp\mTargetBuf = AllocateMemory (scp\mWidth * scp\mHeight * 4)

If initCapture(device, @scp)
  Debug "cap init successful"  
  
  image = CreateImage(#PB_Any, 320, 240)
  
  OpenWindow(0, 0, 0, 320, 240, name$, #PB_Window_ScreenCentered|#PB_Window_SystemMenu)
  ImageGadget(0, 0, 0, 320, 240, ImageID(image))
  
  Quit = 0
  Repeat
    
    doCapture(device)
    While isCaptureDone(device) = 0
      If WaitWindowEvent(1) = #PB_Event_CloseWindow
        Quit = 1
        Break
      EndIf        
    Wend
    
    If StartDrawing(ImageOutput(image))   
      For y = 0 To scp\mHeight - 1
        For x = 0 To scp\mWidth - 1
          pixel = PeekL(scp\mTargetBuf + (y*scp\mWidth + x) * 4)
          rgb   = RGB((pixel >> 16) & $FF, (pixel >> 8) & $FF, pixel & $FF)
          Plot(x, y, rgb)
        Next
      Next
      
      StopDrawing()
      SetGadgetState(0, ImageID(image))
    EndIf
    
    
  Until Quit
  
  deinitCapture(device)
Else
  Debug "init capture failed!"
EndIf

End
; IDE Options = PureBasic 5.62 (Windows - x64)
; Folding = -
; EnableXP