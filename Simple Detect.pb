; ****************************************************************************
;Simple detect by GallyHC                                                    *
; ****************************************************************************
; ****************************************************************************
; ****************************************************************************

DisableASM
EnableExplicit

; ****************************************************************************
; ****************************************************************************
; ****************************************************************************

DeclareModule PureMoveDetect
  ;
  DisableASM
  EnableExplicit
  ;
  ;
  ;
  Structure ESCAPI_PARAMETERS
    differentiel.i
    minimumpoint.i
    minimumcounter.i
    xy_pixelsize.i
    xy_pixelzone.i
    colorshade.i
    grayscale.i
    gaussian.i
    viewresult.b
    viewdetect.b
  EndStructure
  ;
  ; VALEURS GLOBALE DE LA DETECTION AVEC ESCAPI.
  ;
  Global escapi_parameters.ESCAPI_PARAMETERS
  escapi_parameters\differentiel    = 80          ; Facteur de détection
  escapi_parameters\minimumpoint    = 10          ; Nombre mininum de points pour la détection
  escapi_parameters\minimumcounter  = 2           ; Nombre de cadre avant détection
  escapi_parameters\xy_pixelsize    = 2           ; taille des pixel de détection (1,2,4,8,16)
  escapi_parameters\colorshade      = 1           ; nombre de teinte de couleurs (1,2,4,8,16,32,64)
  escapi_parameters\grayscale       = #False      ; Met la détection en gris
  escapi_parameters\gaussian        = #True       ; Met la détection avec mode gaussian
  ;
  escapi_parameters\viewresult      = #True       ; Affichage du resultat de traitement.
  escapi_parameters\viewdetect      = #True       ; Affichage des points de détection.
  ;
  ; VALEURS GLOBALE DE LA DETECTION AVEC ESCAPI.
  ;
  Declare Escapi_OpenCapture  ()
  Declare Escapi_CloseCapture ()
  
EndDeclareModule

Module PureMoveDetect
  ;
  DisableASM
  EnableExplicit
  ;
  ;
  ;
  #ESCAPI_WIDTH       = 640
  #ESCAPI_HEIGHT      = 400
  #ESCAPI_WIDTH_M1    = #ESCAPI_WIDTH  - 1
  #ESCAPI_HEIGHT_M1   = #ESCAPI_HEIGHT - 1
  ;
  ; 
  ;
  Structure ESCAPI_RGB
    r.l
    g.l
    b.l
  EndStructure
  Structure ESCAPI_CAPPARAMS
    *mTargetBuf
    mWidth.l
    mHeight.l
  EndStructure
  ;
  ;
  ;
  PrototypeC countCaptureDevicesProc()
  PrototypeC initCaptureProc(deviceno, *aParams.ESCAPI_CAPPARAMS)
  PrototypeC deinitCaptureProc(deviceno)
  PrototypeC doCaptureProc(deviceno)
  PrototypeC isCaptureDoneProc(deviceno)
  PrototypeC getCaptureDeviceNameProc(deviceno, *namebuffer, bufferlength)
  PrototypeC ESCAPIDLLVersionProc()
  PrototypeC initCOMProc()
  ;
  Global countCaptureDevices.countCaptureDevicesProc
  Global initCapture.initCaptureProc
  Global deinitCapture.deinitCaptureProc
  Global doCapture.doCaptureProc
  Global isCaptureDone.isCaptureDoneProc
  Global getCaptureDeviceName.getCaptureDeviceNameProc
  Global ESCAPIDLLVersion.ESCAPIDLLVersionProc
  ;
  Global.i escapi_device
  Global Font_ID1.i = LoadFont(#PB_Any, "Century Gothic", 10, #PB_Font_Bold | #PB_Font_HighQuality)
  ;
  ;
  ;
  Procedure Escapi_Setup()
    ;
    ;
    ;
    Protected initCOM.initCOMProc
    ;
    CompilerSelect #PB_Compiler_Processor
      CompilerCase #PB_Processor_x86
        Protected.i escapidll = OpenLibrary(#PB_Any, "escapi_x32.dll")
      CompilerCase #PB_Processor_x64
        Protected.i escapidll = OpenLibrary(#PB_Any, "escapi_x64.dll")
    CompilerEndSelect
    ;
    If escapidll = 0
      ProcedureReturn 0
    EndIf
    ;
    countCaptureDevices     = GetFunction(escapidll, "countCaptureDevices")
    initCapture             = GetFunction(escapidll, "initCapture")
    deinitCapture           = GetFunction(escapidll, "deinitCapture")
    doCapture               = GetFunction(escapidll, "doCapture")
    isCaptureDone           = GetFunction(escapidll, "isCaptureDone")
    initCOM                 = GetFunction(escapidll, "initCOM")
    getCaptureDeviceName    = GetFunction(escapidll, "getCaptureDeviceName")
    ESCAPIDLLVersion        = GetFunction(escapidll, "ESCAPIDLLVersion")
    ;
    If countCaptureDevices = 0 Or initCapture = 0 Or deinitCapture = 0 Or doCapture = 0 Or isCaptureDone = 0 Or initCOM = 0 Or getCaptureDeviceName = 0 Or ESCAPIDLLVersion = 0
      ProcedureReturn 0
    EndIf
    If ESCAPIDLLVersion() < $200
      ProcedureReturn 0
    EndIf
    ;
    initCOM()
    ProcedureReturn countCaptureDevices()
    
  EndProcedure
  ;
  ;
  ;
  Procedure Escapi_OpenCapture()
    ;
    ;
    ;
    Define.i escapi_buffersize  = #ESCAPI_WIDTH  * #ESCAPI_HEIGHT  * 4
    Define.i escapi_pixcount    = (#ESCAPI_WIDTH * #ESCAPI_HEIGHT) - 2
    Define.i escapi_offset      = 0
    Define.i escapi_pitch       = 0
    Define.i escapi_number      = 0
    Define.i escapi_quit        = #False
    Define.i escapi_detect      = #False
    Define.i escapi_count       = Escapi_Setup()
    Define.s escapi_name        = Space(255)
    Define.i i, x, y, xx, yy, hm1, colr, colg, colb, diff, cx, cy
    Define  *escapi_readbuffer
    Define  *escapi_writebuffer
    ;
    Dim escapi_tabsaving.ESCAPI_RGB   (#ESCAPI_WIDTH / escapi_parameters\xy_pixelsize, #ESCAPI_HEIGHT / escapi_parameters\xy_pixelsize)
    Dim escapi_tabcapture.ESCAPI_RGB  (#ESCAPI_WIDTH / escapi_parameters\xy_pixelsize, #ESCAPI_HEIGHT / escapi_parameters\xy_pixelsize)
    Dim escapi_tabpointzone           (#ESCAPI_WIDTH / escapi_parameters\xy_pixelsize, #ESCAPI_HEIGHT / escapi_parameters\xy_pixelsize)
    Dim escapi_tabboundbox.point      (1)
    ;
    If escapi_count > 0
      getCaptureDeviceName(escapi_device, @escapi_name, 255)
      ;
      For i=0 To escapi_device
        getCaptureDeviceName(i, @escapi_name, 255)
        Debug PeekS(@escapi_name, -1, #PB_Ascii)
      Next i
      ;
      Define escapi_dll.ESCAPI_CAPPARAMS
      With escapi_dll
        \mWidth             = #ESCAPI_WIDTH
        \mHeight            = #ESCAPI_HEIGHT
        \mTargetBuf         = AllocateMemory(escapi_buffersize)
        *escapi_readbuffer  = \mTargetBuf
      EndWith
      ;
      If initCapture(escapi_device, @escapi_dll)
        ;
        OpenWindow(#PB_Any, 50, 50, #ESCAPI_WIDTH, #ESCAPI_HEIGHT, PeekS(@escapi_name, -1, #PB_Ascii), #PB_Window_SystemMenu)
        Define.i escapi_canva = CanvasGadget(#PB_Any, 0, 0, #ESCAPI_WIDTH, #ESCAPI_HEIGHT)
        ;
        If doCapture(escapi_device) <> 0
          Repeat
            ;
            doCapture(escapi_device)
            While isCaptureDone(escapi_device) = #False
              If WaitWindowEvent(1) = #PB_Event_CloseWindow
                escapi_quit = #True
                Break
              EndIf
              ;
              Delay(2)
            Wend
            ;
            StartDrawing(CanvasOutput(escapi_canva))
              *escapi_writebuffer = DrawingBuffer()
              escapi_pitch        = DrawingBufferPitch()
            StopDrawing()
            ;
            ; AFFICHAGE ET STOCKAGE DES POINTS DE LA CAPTURE.
            ;
            escapi_offset = 0
            FreeArray(escapi_tabcapture())
            Dim escapi_tabcapture.ESCAPI_RGB  (#ESCAPI_WIDTH / escapi_parameters\xy_pixelsize, #ESCAPI_HEIGHT / escapi_parameters\xy_pixelsize)
            For y = 0 To #ESCAPI_HEIGHT_M1 Step 1
              hm1 = *escapi_writebuffer + ((#ESCAPI_HEIGHT_M1 - y) * escapi_pitch)
              For x = 0 To #ESCAPI_WIDTH_M1 Step 1
                ;
                If escapi_parameters\viewresult = #False
                  PokeL(hm1 + x * 3, PeekL(*escapi_readbuffer + escapi_offset))
                EndIf
                ;
                diff = PeekL(*escapi_readbuffer + escapi_offset)
                With escapi_tabcapture(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)
                  If \r > 0 Or \g > 0 Or \b > 0
                    \r = (\r + (diff >> 16) & $ff) / 2
                    \g = (\g + (diff >> 8 ) & $ff) / 2
                    \b = (\b + (diff >> 0 ) & $ff) / 2
                  Else
                    \r = (diff >> 16) & $ff
                    \g = (diff >> 8 ) & $ff
                    \b = (diff >> 0 ) & $ff
                  EndIf
                EndWith
                escapi_offset + 4
              Next x
            Next y
            ;
            ; ROUTINE DE TRAITEMENT DE LA DETECTION.
            ;
            escapi_count = 0
            escapi_tabboundbox(0)\x = #ESCAPI_WIDTH
            escapi_tabboundbox(0)\y = #ESCAPI_HEIGHT
            escapi_tabboundbox(1)\x = 0
            escapi_tabboundbox(1)\y = 0
            StartDrawing(CanvasOutput(escapi_canva))
              DrawingMode(#PB_2DDrawing_Default)
              DrawingFont(FontID(Font_ID1))
              ;
              If escapi_parameters\viewresult = #True
                Box(0, 0, #ESCAPI_WIDTH, #ESCAPI_HEIGHT, $ff)
              EndIf
              For y = 0 To #ESCAPI_HEIGHT_M1 Step 1
                For x = 0 To #ESCAPI_WIDTH_M1 Step 1
                  escapi_detect = #False
                  ;
                  colr = escapi_tabcapture(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\r
                  colg = escapi_tabcapture(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\g
                  colb = escapi_tabcapture(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\b
                  ;
                  If escapi_parameters\gaussian = #True
                    If x > 1 And x < #ESCAPI_WIDTH_M1 - escapi_parameters\xy_pixelsize And y > 1 And y < #ESCAPI_HEIGHT_M1 - escapi_parameters\xy_pixelsize
                      colr = 0
                      colg = 0
                      colb = 0
                      For yy = -1 To 1 Step 1
                        For xx = -1 To 1 Step 1
                            colr + escapi_tabcapture((x + xx) / escapi_parameters\xy_pixelsize, (y + yy) / escapi_parameters\xy_pixelsize)\r
                            colg + escapi_tabcapture((x + xx) / escapi_parameters\xy_pixelsize, (y + yy) / escapi_parameters\xy_pixelsize)\g
                            colb + escapi_tabcapture((x + xx) / escapi_parameters\xy_pixelsize, (y + yy) / escapi_parameters\xy_pixelsize)\b
                        Next xx
                      Next yy 
                      colr / 9
                      colg / 9
                      colb / 9
                    EndIf
                  EndIf
                  ;
                  If escapi_parameters\grayscale = #True
                    If escapi_parameters\colorshade = 1
                      diff = (colr + colg + colb) / 3
                    Else
                      diff = (((colr + colg + colb) / 3) / escapi_parameters\colorshade) * escapi_parameters\colorshade
                    EndIf
                    colr = diff
                    colg = diff
                    colb = diff
                  Else
                    If escapi_parameters\colorshade > 1
                      colr = (colr / escapi_parameters\colorshade) * escapi_parameters\colorshade
                      colg = (colg / escapi_parameters\colorshade) * escapi_parameters\colorshade
                      colb = (colb / escapi_parameters\colorshade) * escapi_parameters\colorshade
                    EndIf
                  EndIf
                  ;
                  diff = 0
                  diff + Abs (escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\r - colr)
                  diff + Abs (escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\g - colg)
                  diff + Abs (escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\b - colb)
                  If x > 1 And x < #ESCAPI_WIDTH_M1 - escapi_parameters\xy_pixelsize And y > 1 And y < #ESCAPI_HEIGHT_M1 - escapi_parameters\xy_pixelsize
                    If diff > escapi_parameters\differentiel
                      escapi_count + 1
                      escapi_detect = #False
                      ;
                      If escapi_tabboundbox(0)\x > x
                        escapi_tabboundbox(0)\x = x
                      EndIf
                      If escapi_tabboundbox(0)\y > y
                        escapi_tabboundbox(0)\y = y
                      EndIf
                      If escapi_tabboundbox(1)\x < x
                        escapi_tabboundbox(1)\x = x
                      EndIf
                      If escapi_tabboundbox(1)\y < y
                        escapi_tabboundbox(1)\y = y
                      EndIf
                      ;
                      If escapi_parameters\viewresult = #True
                        If escapi_parameters\viewdetect = #True
                          Box(x, y, escapi_parameters\xy_pixelsize, escapi_parameters\xy_pixelsize, $ff00)
                        Else
                          Box(x, y, escapi_parameters\xy_pixelsize, escapi_parameters\xy_pixelsize, RGB(colr, colg, colb))
                        EndIf
                      EndIf
                    Else
                      If escapi_parameters\viewresult = #True
                        Box(x, y, escapi_parameters\xy_pixelsize, escapi_parameters\xy_pixelsize, RGB(colr, colg, colb))
                      EndIf
                    EndIf
                  EndIf
                  ;
                  escapi_tabpointzone(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize) = escapi_detect
                  ;
                  escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\r = ((escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\r + colr)*100) / 200
                  escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\g = ((escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\g + colg)*100) / 200
                  escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\b = ((escapi_tabsaving(x / escapi_parameters\xy_pixelsize, y / escapi_parameters\xy_pixelsize)\b + colb)*100) / 200
                  ;
                  x + (escapi_parameters\xy_pixelsize - 1)
                Next x
                y + (escapi_parameters\xy_pixelsize - 1)
              Next y
              ;
              ; ROUTINE D'AFFICHAGE DE LA ZONE DE DETECTION.
              ;
              If escapi_count > escapi_parameters\minimumpoint
                escapi_number + 1 
                If escapi_number > escapi_parameters\minimumcounter
                  escapi_tabboundbox(0)\x = (escapi_tabboundbox(0)\x / escapi_parameters\xy_pixelsize) * escapi_parameters\xy_pixelsize
                  escapi_tabboundbox(0)\y = (escapi_tabboundbox(0)\y / escapi_parameters\xy_pixelsize) * escapi_parameters\xy_pixelsize
                  escapi_tabboundbox(1)\x = (escapi_tabboundbox(1)\x / escapi_parameters\xy_pixelsize) * escapi_parameters\xy_pixelsize
                  escapi_tabboundbox(1)\y = (escapi_tabboundbox(1)\y / escapi_parameters\xy_pixelsize) * escapi_parameters\xy_pixelsize
                  ;
                  DrawingMode(#PB_2DDrawing_AlphaBlend)
                  Box(escapi_tabboundbox(0)\x, escapi_tabboundbox(0)\y, escapi_tabboundbox(1)\x - escapi_tabboundbox(0)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(1)\y - escapi_tabboundbox(0)\y + escapi_parameters\xy_pixelsize, $80000000) 
                  DrawingMode(#PB_2DDrawing_Default)
                  DrawText(escapi_parameters\xy_pixelsize + 4, escapi_parameters\xy_pixelsize + 4, " Movement detected ", $ffff)
                  LineXY(escapi_tabboundbox(0)\x, escapi_tabboundbox(0)\y, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(0)\y, $00ffff)
                  LineXY(escapi_tabboundbox(0)\x, escapi_tabboundbox(0)\y, escapi_tabboundbox(0)\x, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, $00ffff)
                  LineXY(escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(0)\y, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, $00ffff)
                  LineXY(escapi_tabboundbox(0)\x, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, $00ffff)
                  LineXY(escapi_tabboundbox(0)\x, escapi_tabboundbox(0)\y + 1, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(0)\y + 1, $00ffff)
                  LineXY(escapi_tabboundbox(0)\x + 1, escapi_tabboundbox(0)\y, escapi_tabboundbox(0)\x + 1, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, $00ffff)
                  LineXY(escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize - 1, escapi_tabboundbox(0)\y, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize - 1, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize, $00ffff)
                  LineXY(escapi_tabboundbox(0)\x, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize - 1, escapi_tabboundbox(1)\x + escapi_parameters\xy_pixelsize, escapi_tabboundbox(1)\y + escapi_parameters\xy_pixelsize - 1, $00ffff)
                EndIf
              Else
                escapi_number = 0
              EndIf
              ;
              ;DrawingMode(#PB_2DDrawing_Default)
              ;DrawText(escapi_parameters\xy_pixelsize + 4, #ESCAPI_HEIGHT - (TextHeight("A") + escapi_parameters\xy_pixelsize + 4), " " + FormatDate("%dd/%mm/%yyyy - %hh:%ii:%ss" + " ", Date()), $ffff)
            StopDrawing()
            ;
          Until escapi_quit
        Else
          MessageRequester("Error", "Capture failed.")
        EndIf
        ;
        FreeMemory(escapi_dll\mTargetBuf)
        ;
      Else
        MessageRequester("Error", "Init capture failed.")
      EndIf
      ;
      deinitCapture(escapi_device)
    Else
      MessageRequester("Error", "Unable to initialize ESCAPI.")
    EndIf
  
  EndProcedure
  ;
  Procedure Escapi_CloseCapture()
    ;
    ;
    ;
    deinitCapture(escapi_device)
    
  EndProcedure

EndModule

; ****************************************************************************
; ****************************************************************************
; ****************************************************************************

PureMoveDetect::Escapi_OpenCapture()
PureMoveDetect::Escapi_CloseCapture()
; IDE Options = PureBasic 5.62 (Windows - x64)
; CursorPosition = 1
; Folding = -
; EnableXP