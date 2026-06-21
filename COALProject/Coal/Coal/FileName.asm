; ============================================================
; BRIDGE BOMBER (Project Submission Edition)
; MASM + Irvine32 | Grid: 20 rows x 60 cols (Strictly 1D Array)
; ============================================================

INCLUDE Irvine32.inc

; Global Matrix Constants
NROWS = 20
NCOLS = 60

; Fixed Map Row Index Boundaries
R_HUD = 0
R_TOP = 1
R_BRG = 3
R_BOT = 12

.data
    ; Dynamic Lane Variables (Shuffled by the Main Menu to alter level layouts)
    R_CAR1  DWORD 6
    R_CAR2  DWORD 10
    R_PED1  DWORD 8

    ; Asynchronous Cooldown Durations (in Milliseconds)
    T_PED   DWORD 280       ; Speed threshold for pedestrian row shifts
    T_BOX   DWORD 60        ; Speed threshold for the falling box descent
    T_SPWN  DWORD 2500      ; Time interval between new box spawns on the bridge

    ; 1D Memory Array: Holds exactly 1,200 bytes sequentially (20 Rows * 60 Columns)
    grid    BYTE NROWS * NCOLS DUP(' ')
    
    ; Game State Monitoring Flags
    pCol    DWORD 29        ; Track player column position on the bridge
    pHold   DWORD 0         ; Inventory state: 1 = carrying a box, 0 = empty-handed
    bActive DWORD 0         ; Physics state: 1 = box is currently flying mid-air, 0 = inactive
    bRow    DWORD 0         ; Falling box current row coordinate
    bCol    DWORD 0         ; Falling box locked column coordinate
    pts     SDWORD 0        ; Signed Double-Word (allows negative score values for hitting peds)
    dead    DWORD 0         ; Game Status Loop Flag: 0 = Playing, 1 = Lost/Quit, 2 = Won

    ; Clock Delta Accumulators (Stores previous CPU millisecond count snapshots)
    tmCar   DWORD 0
    tmPed   DWORD 0
    tmBox   DWORD 0
    tmSpwn  DWORD 0
    spSide  DWORD 0         ; Alternator flag to toggle spawning items on Left vs Right edges

    ; Text Assets and Screen Buffers
    menuTitle BYTE "=== WELCOME TO BRIDGE BOMBER ===", 0
    menuOpt1  BYTE "1. Start Game", 0
    menuOpt2  BYTE "2. Exit Program", 0
    menuPrompt BYTE "Enter choice (1-2): ", 0
    
    diffTitle BYTE "--- SELECT DIFFICULTY ---", 0
    diffOpt1  BYTE "1. Easy Mode   [ Cars, Cars, Peds ]", 0
    diffOpt2  BYTE "2. Medium Mode [ Cars, Peds, Cars ]", 0
    diffOpt3  BYTE "3. Hard Mode   [ Peds, Cars, Cars ]", 0
    diffPrompt BYTE "Enter choice (1-3): ", 0

    scrStr    BYTE "SCORE: ", 0
    msgStr    BYTE "  [A/D] Move  [SPACE] Drop  [Q] Quit", 0
    boxStr    BYTE " [BOX] ", 0

.code

; ============================================================
; GSet - Writes a character byte into the linear array
; Math: Memory Offset = (Row Index * NCOLS) + Column Index
; Inputs: EBX = Row Index, ESI = Column Index, CL = Char to write
; ============================================================
GSet PROC
    push eax              ; Save original EAX on the stack to preserve caller state
    mov  eax, ebx         ; Move Row index into EAX
    imul eax, NCOLS       ; EAX = Row * 60 (Calculates starting index of targeted row)
    add  eax, esi         ; EAX = (Row * 60) + Column (Calculates exact cell offset)
    mov  grid[eax], cl    ; Write character from CL directly into calculated array cell
    pop  eax              ; Restore original EAX back from the stack
    ret
GSet ENDP

; ============================================================
; GGet - Reads a character byte from the linear array
; Math: Memory Offset = (Row Index * NCOLS) + Column Index
; Inputs: EBX = Row Index, ESI = Column Index
; Outputs: AL = Character read from the matrix cell
; ============================================================
GGet PROC
    mov  eax, ebx         ; Move Row index into EAX
    imul eax, NCOLS       ; EAX = Row * 60
    add  eax, esi         ; EAX = (Row * 60) + Column
    mov  al, grid[eax]    ; Fetch character from array memory slot into return register AL
    ret
GGet ENDP

; ============================================================
; FillRow - Populates an entire row with a fixed character
; Inputs: EBX = Row Index, CL = Character asset to draw
; ============================================================
FillRow PROC
    push esi              ; Save ESI to prevent register corruption
    mov  esi, 0           ; Begin processing at Column index 0
filLoop:
    call GSet             ; Paint character into current coordinate cell
    inc  esi              ; Step forward to next column index slot
    cmp  esi, NCOLS       ; Have we reached column 60?
    jl   filLoop          ; If column < 60, keep looping across row
    pop  esi              ; Restore original ESI register value
    ret
FillRow ENDP

; ============================================================
; Init - Re-zeroes variables and populates base map design
; ============================================================
Init PROC
    ; Clear entire 1,200-cell grid layout block in memory back to empty spaces
    mov  ecx, NROWS * NCOLS
    mov  edi, OFFSET grid
    mov  al, ' '
    rep  stosb            ; Standard string microcode: write space to EDI, increment, repeat ECX times

    ; Draw Level Border Infrastructure
    mov  cl, '#'
    mov  ebx, R_TOP
    call FillRow          ; Draw Top Safety Boundary Wall
    mov  ebx, R_BOT
    call FillRow          ; Draw Bottom Boundary Floor Wall

    ; Draw Player Bridge Walkway Track
    mov  ebx, R_BRG
    mov  cl, '='
    call FillRow

    ; Draw Background Track Layouts dynamically based on selected difficulty row numbers
    mov  cl, '-'
    mov  ebx, R_CAR1
    call FillRow          ; Draw Highway 1 background dashes
    mov  ebx, R_CAR2
    call FillRow          ; Draw Highway 2 background dashes

    mov  cl, '.'
    mov  ebx, R_PED1
    call FillRow          ; Draw Walkway background dots

    ; Populate Highway Lane 1 with active Car objects ('C')
    mov  cl, 'C'
    mov  ebx, R_CAR1
    mov  esi, 5
    call GSet
    mov  esi, 25
    call GSet
    mov  esi, 45
    call GSet

    ; Populate Highway Lane 2 with active Car objects ('C')
    mov  ebx, R_CAR2
    mov  esi, 15
    call GSet
    mov  esi, 35
    call GSet
    mov  esi, 55
    call GSet

    ; Populate Sidewalk Lane 1 with active Pedestrian objects ('o')
    mov  cl, 'o'
    mov  ebx, R_PED1
    mov  esi, 10
    call GSet
    mov  esi, 30
    call GSet
    mov  esi, 50
    call GSet

    ; Spawn pickup boxes on opposite structural edges of the bridge track
    mov  cl, 'B'
    mov  ebx, R_BRG
    mov  esi, 0
    call GSet
    mov  esi, NCOLS-1
    call GSet

    ; Initialize and spawn Player character ('P') at center column
    mov  pCol, 29
    mov  ebx, R_BRG
    mov  esi, pCol
    mov  cl, 'P'
    call GSet

    ; Reset Session Flags to absolute zero defaults
    mov  pHold, 0
    mov  bActive, 0
    mov  pts, 0
    mov  dead, 0
    mov  spSide, 0

    ; Sync delta timing clocks with system startup timestamp millisecond values
    call GetMseconds
    mov  tmCar, eax
    mov  tmPed, eax
    mov  tmBox, eax
    mov  tmSpwn, eax
    ret
Init ENDP

; ============================================================
; MainMenu - Captures text choices and configures lane variables
; ============================================================
MainMenu PROC
menuLoop:
    call Clrscr
    mov  edx, OFFSET menuTitle
    call WriteString
    call Crlf
    call Crlf
    mov  edx, OFFSET menuOpt1
    call WriteString
    call Crlf
    mov  edx, OFFSET menuOpt2
    call WriteString
    call Crlf
    call Crlf
    mov  edx, OFFSET menuPrompt
    call WriteString
    call ReadChar         ; Block input and capture menu selection key inside AL register
    cmp  al, '2'          
    je   exitSelected     ; Option 2: Terminate process instantly
    cmp  al, '1'          
    je   difficultyMenu   ; Option 1: Route context into difficulty assignment screen
    jmp  menuLoop
exitSelected:
    exit                        

difficultyMenu:
    call Crlf
    call Crlf
    mov  edx, OFFSET diffTitle
    call WriteString
    call Crlf
    call Crlf
    mov  edx, OFFSET diffOpt1
    call WriteString
    call Crlf
    mov  edx, OFFSET diffOpt2
    call WriteString
    call Crlf
    mov  edx, OFFSET diffOpt3
    call WriteString
    call Crlf
    call Crlf
    mov  edx, OFFSET diffPrompt
    call WriteString
    call ReadChar         ; Block input and capture difficulty key selection in AL

    cmp  al, '1'
    je   setEasy
    cmp  al, '2'
    je   setMedium
    cmp  al, '3'
    je   setHard
    jmp  difficultyMenu   ; Input verification: if invalid key pressed, reload sub-menu

setEasy:
    ; Easy Mode Sequence Map: Car Row -> Car Row -> Pedestrian Row
    mov  R_CAR1, 5
    mov  R_CAR2, 7
    mov  R_PED1, 9
    ret
setMedium:
    ; Medium Mode Sequence Map: Car Row -> Pedestrian Row -> Car Row
    mov  R_CAR1, 5
    mov  R_PED1, 7
    mov  R_CAR2, 9
    ret
setHard:
    ; Hard Mode Sequence Map: Pedestrian Row -> Car Row -> Car Row
    mov  R_PED1, 5
    mov  R_CAR1, 7
    mov  R_CAR2, 9
    ret
MainMenu ENDP

; ============================================================
; HUD - Refreshes score counters and inventory strings at coordinate (0,0)
; ============================================================
HUD PROC
    mov  dh, R_HUD
    mov  dl, 0
    call Gotoxy
    mov  edx, OFFSET scrStr
    call WriteString
    mov  eax, pts
    call WriteInt

    ; Conditional UI Element rendering based on inventory boolean flag
    cmp  pHold, 1
    jne  skipBoxIndicator
    mov  edx, OFFSET boxStr
    call WriteString ; Show [BOX] text tag if player is holding weapon
    jmp  printControls
skipBoxIndicator:
    mov  al, ' '
    mov  ecx, 7
clearGap:
    call WriteChar
    loop clearGap             ; Pad old [BOX] string region with spaces to wipe it cleanly
printControls:
    mov  edx, OFFSET msgStr
    call WriteString
    ret
HUD ENDP

; ============================================================
; PrintGrid - Flushes 1D sequential block to console screen
; Splitting logic: Slices flat line into rows by executing Crlf every 60 bytes
; ============================================================
PrintGrid PROC
    mov  dh, R_TOP
    mov  dl, 0
    call Gotoxy
    mov  ebx, R_TOP       ; Start reading array contents from Row 1
pgRowLoop:
    mov  esi, 0           ; Initialize internal Column counter to 0
pgColLoop:
    call GGet
    call WriteChar   ; Fetch layout character from array index into AL, then print it out
    inc  esi              
    cmp  esi, NCOLS       ; Have we completed printing a horizontal sequence line of 60 characters?
    jl   pgColLoop        ; If column count < 60, continue printing line characters
    call Crlf             ; END OF ROW TRICK: Force cursor down to next console line block
    inc  ebx              
    cmp  ebx, R_BOT + 1   ; Have we finished printing all level rows down to bottom boundary?
    jl   pgRowLoop        ; If row index <= bottom wall row, jump to process next block line sequence
    ret
PrintGrid ENDP

; ============================================================
; ScrollRow - Conveyor Horizontal Array Shifting Engine
; CRITICAL SAFETY: Uses pushad/popad to isolate register states
; Direction flag logic inside EDX: 0 = Shift Left, 1 = Shift Right
; ============================================================
ScrollRow PROC
    pushad                ; CRITICAL: Snapshot all 8 caller registers to stack to prevent corruption
    cmp  edx, 1
    je   srRight          ; Evaluate shift direction instruction routing flag

    ; --- SHIFT LEFT LOGIC ---
    mov  esi, 0
    call GGet                   
    movzx edx, al         ; Capture edge character at col 0, wrap protect it securely inside EDX register
    mov  edi, 0           ; Shifting write destination pointer starts at Column 0
srLLoop:
    mov  eax, NCOLS
    dec  eax
    cmp  edi, eax         
    jge  srLDone          ; Stop loop once destination column target pointer reaches index position 59
    mov  esi, edi
    inc  esi
    call GGet     ; Read column asset character from right index (edi + 1)
    mov  esi, edi
    mov  cl, al
    call GSet   ; Write captured asset backward into current column index (edi)
    inc  edi
    jmp  srLLoop
srLDone:
    mov  esi, NCOLS
    dec  esi
    mov  cl, dl
    call GSet ; Wrap saved col 0 character into terminal col 59 slot
    jmp  srDone

    ; --- SHIFT RIGHT LOGIC ---
srRight:
    mov  esi, NCOLS
    dec  esi
    call GGet    
    movzx edx, al         ; Capture edge character at col 59, wrap protect it securely inside EDX register
    mov  edi, NCOLS
    dec  edi                ; Shifting write destination pointer starts at Column 59
srRLoop:
    cmp  edi, 0           
    jle  srRDone          ; Stop loop once destination column target pointer drops down to index position 0
    mov  esi, edi
    dec  esi
    call GGet     ; Read column asset character from left index (edi - 1)
    mov  esi, edi
    mov  cl, al
    call GSet   ; Write captured asset forward into current column index (edi)
    dec  edi
    jmp  srRLoop
srRDone:
    mov  esi, 0
    mov  cl, dl
    call GSet     ; Wrap saved col 59 character into start col 0 slot
srDone:
    popad                 ; Restore original registers exactly as they were before shifting
    ret
ScrollRow ENDP

; ============================================================
; Traffic Animation Handlers (Asynchronous Non-Blocking Timing Gates)
; ============================================================
UpdateCars PROC
    call GetMseconds      ; Fetch current CPU system runtime clock tick tally into EAX
    mov  ecx, eax
    sub  ecx, tmCar       ; Calculate elapsed milliseconds since last traffic animation execution
    cmp  ecx, 180         ; Has our fixed baseline traffic animation speed threshold expired?
    jl   ucEnd            ; If elapsed time < 180ms, bypass execution to maintain fixed timing pacing
    mov  tmCar, eax       ; Refresh time snapshot with updated clock value to reset gate timer
    
    ; Execute updates on lanes dynamically by reading configuration variables
    mov  ebx, R_CAR1
    mov  edx, 0
    call ScrollRow ; Shift Car Lane 1 leftwards (Direction Flag = 0)
    
    mov  ebx, R_CAR2
    mov  edx, 1
    call ScrollRow ; Shift Car Lane 2 rightwards (Direction Flag = 1)
ucEnd:
    ret
UpdateCars ENDP

UpdatePeds PROC
    call GetMseconds
    mov  ecx, eax
    sub  ecx, tmPed
    cmp  ecx, T_PED       ; Compare elapsed time against civilian pacing threshold (280ms)
    jl   upEnd            ; If elapsed timeline hasn't expired, bypass execution frame
    mov  tmPed, eax       ; Reset gate clock snapshot tracking marker
    
    mov  ebx, R_PED1
    mov  edx, 1
    call ScrollRow ; Shift Civilians rightwards (Direction Flag = 1)
upEnd:
    ret
UpdatePeds ENDP

SpawnBox PROC
    call GetMseconds
    mov  ecx, eax
    sub  ecx, tmSpwn
    cmp  ecx, T_SPWN      ; Check if 2,500ms spawning window interval cooldown has expired
    jl   spEnd
    mov  tmSpwn, eax      ; Reset gate clock snapshot tracking marker
    
    cmp  spSide, 0        
    je   spLeft           ; Alternator logic tracking branch routing
    
    ; Attempt spawning replenishment box on right edge of bridge path row layout
    mov  ebx, R_BRG
    mov  esi, NCOLS-1
    call GGet
    cmp  al, '='          ; Safety validation: check if cell is clear of characters or player
    jne  spFlip           ; If cell is blocked, skip insertion to prevent deleting active elements
    mov  cl, 'B'
    call GSet
    jmp  spFlip
spLeft:
    ; Attempt spawning replenishment box on left edge of bridge path row layout
    mov  ebx, R_BRG
    mov  esi, 0
    call GGet
    cmp  al, '='          
    jne  spFlip
    mov  cl, 'B'
    call GSet
spFlip:
    mov  eax, spSide
    xor  eax, 1
    mov  spSide, eax      ; Flip toggle bit value so next spawn cycle checks opposite edge
spEnd:
    ret
SpawnBox ENDP

; ============================================================
; UpdateBox - Compact Real-Time Collision Processing Core
; ============================================================
UpdateBox PROC
    cmp  bActive, 1       
    jne  ubEnd            ; Flight safety check: bypass completely if no box asset is active mid-air
    call GetMseconds
    mov  ecx, eax
    sub  ecx, tmBox
    cmp  ecx, T_BOX       ; Check if vertical air descent lookahead pace time (60ms) has expired
    jl   ubEnd            ; If time has not expired, lock box position in current position cell
    mov  tmBox, eax       ; Reset gate timer snapshot tracking marker

    ; Wipe visual artifact trail by writing original background symbol back to the departure cell coordinates
    mov  ebx, bRow
    mov  esi, bCol
    cmp  ebx, R_CAR1
    je   skipErase
    cmp  ebx, R_CAR2
    je   skipErase
    cmp  ebx, R_PED1
    je   skipErase
    call RestoreBg        ; Safe clean write function triggers only if box is moving outside active lanes
skipErase:

    inc  bRow             ; DESCEND PHASE: Drop down tracking variable to target next row position index down
    mov  eax, bRow
    cmp  eax, R_BOT       ; Boundary threshold check: did box plunge past bottom of world coordinates?
    jge  ubMissed         ; If box index matches floor row boundary, route to complete miss destruction routine

    ; Read array character data at our calculated next-step landing zone coordinates
    mov  ebx, bRow
    mov  esi, bCol
    call GGet                   

    ; --- IMPACT CHECK ENGINE ---
    cmp  al, 'C'
    je   ubHitCar       ; Target contains live car -> Process scoring destruction
    cmp  al, 'o'
    je   ubHitPed       ; Target contains civilian -> Process penalty points
    cmp  al, 'X'
    je   ubHitWrecked   ; Target contains previous wreckage -> Block and destroy package

    ; --- LANE FILTER OVERLAYS ---
    ; Ghost Injection Prevention: if lookahead landing cell sits inside moving traffic lane, 
    ; bypass visual array print block. This lets lookahead physics drop down without altering tracks.
    cmp  ebx, R_CAR1
    je   ubEnd
    cmp  ebx, R_CAR2
    je   ubEnd
    cmp  ebx, R_PED1
    je   ubEnd

    ; If target cell is clear background, draw visual box asset character 'B' into layout cell array space
    mov  cl, 'B'
    call GSet
    jmp  ubEnd

ubHitCar:
    add  pts, 5           ; Success reward scoring increment
    mov  cl, 'X'
    call GSet   ; Permanently transform active target character 'C' into burning wreck 'X'
    mov  bActive, 0       ; Reset projectile physics flag state back to zero to kill further air descent
    call CheckWinCondition ; Scan remaining traffic layout to analyze if victory state condition met
    jmp  ubEnd
ubHitWrecked:
    mov  bActive, 0       ; Box shatters on old wreck -> package destroyed silently, no score changes applied
    jmp  ubEnd
ubHitPed:
    sub  pts, 10          ; Penalty violation deduction
    mov  bActive, 0       ; Weapon package item disintegrates on impact
    jmp  ubEnd
ubMissed:
    mov  bActive, 0       ; Box landed safely on floor -> package deactivates cleanly
ubEnd:
    ret
UpdateBox ENDP

; ============================================================
; CheckWinCondition - Target Array Scanner Loop
; ============================================================
CheckWinCondition PROC
    push ebx
    push esi
    push ecx
    mov  ecx, 0           ; Clear tracking register to explicitly count active targets manually
    
    ; Scan Highway Lane 1 columns for remaining active 'C' elements
    mov  ebx, R_CAR1
    mov  esi, 0
l1: 
    call GGet
    cmp  al, 'C'
    jne  n1
    inc  ecx                
n1: 
    inc  esi
    cmp  esi, NCOLS
    jl   l1

    ; Scan Highway Lane 2 columns for remaining active 'C' elements
    mov  ebx, R_CAR2
    mov  esi, 0
l2: 
    call GGet
    cmp  al, 'C'
    jne  n2
    inc  ecx                
n2: 
    inc  esi
    cmp  esi, NCOLS
    jl   l2

    cmp  ecx, 0           ; Check if active car tally count has successfully dropped to absolute zero
    jne  winDone          ; If active car elements still found, end check and continue session play loop
    mov  dead, 2          ; TARGET COUNT IS ZERO: Assign Victory victory level value code flag to variable
winDone:
    pop  ecx
    pop  esi
    pop  ebx
    ret
CheckWinCondition ENDP

; ============================================================
; RestoreBg - Visual Reconstruction Decoder Engine
; ============================================================
RestoreBg PROC
    mov  eax, ebx         ; Map dynamic row coordinate lookup comparisons
    cmp  eax, R_BRG
    je   rbBridge
    cmp  eax, R_CAR1
    je   rbRoad
    cmp  eax, R_CAR2
    je   rbRoad
    cmp  eax, R_PED1
    je   rbPed
    mov  cl, ' '
    call GSet
    ret ; Default tracking space fallback value
rbBridge: 
    mov  cl, '='
    call GSet
    ret ; Restore metal bridge pathway segment tile
rbRoad:   
    mov  cl, '-'
    call GSet
    ret ; Restore dynamic asphalt roadway segment tile
rbPed:    
    mov  cl, '.'
    call GSet
    ret ; Restore dynamic civilian concrete brick segment tile
RestoreBg ENDP

; ============================================================
; InputPROC - Real-Time User Controls Processor
; ============================================================
InputPROC PROC
    call ReadKey          ; Non-blocking keyboard state scan: checks if a key is being held down right now
    jz   inEnd            ; If terminal keyboard buffer contains zero key events, exit function immediately
    
    ; Convert uppercase letter characters into lowercase by appending bit modification values (+32)
    cmp  al, 'A'
    jl   inLow
    cmp  al, 'Z'
    jg   inLow
    add  al, 32
inLow:
    cmp  al, 'a'
    je   inLeft
    cmp  al, 'd'
    je   inRight
    cmp  al, ' '
    je   inDrop
    cmp  al, 'q'
    je   inQuit
    jmp  inEnd
inLeft:
    cmp  pCol, 0
    jle  inEnd ; Border screen safety: check if player is pinned against left matrix margin edge
    mov  ebx, R_BRG
    mov  esi, pCol
    call RestoreBg ; Re-draw '=' structural track over old player location
    dec  pCol             ; Decrement index tracking coordinates leftwards
    mov  esi, pCol
    call GGet
    cmp  al, 'B'
    jne  m1
    mov  pHold, 1            ; INVENTORY CHECK: if player stepped onto box, equip weapon!
m1:  
    mov  cl, 'P'
    call GSet
    jmp  inEnd
inRight:
    mov  eax, NCOLS-1
    cmp  pCol, eax
    jge  inEnd    ; Border screen safety: check if player pinned against right wall edge
    mov  ebx, R_BRG
    mov  esi, pCol
    call RestoreBg
    inc  pCol             ; Increment index tracking coordinates rightwards
    mov  esi, pCol
    call GGet
    cmp  al, 'B'
    jne  m2
    mov  pHold, 1            ; INVENTORY CHECK: load box weapon element into weapon slot if run over
m2:  
    mov  cl, 'P'
    call GSet
    jmp  inEnd
inDrop:
    cmp  pHold, 1
    jne  inEnd                  ; Launch Block validation 1: reject drop if inventory holds no box package
    cmp  bActive, 1
    je   inEnd                  ; Launch Block validation 2: reject drop if another package is flying mid-air
    mov  pHold, 0
    mov  bActive, 1             ; Set weapon inventory variable flag state to zero, activate physics drop loop
    mov  eax, pCol
    mov  bCol, eax
    mov  bRow, R_BRG + 1 ; Lock launch columns, drop package starting row below bridge path index
    mov  ebx, bRow
    mov  esi, bCol
    mov  cl, 'B'
    call GSet ; Injected first physical air track box character byte to screen matrix
    call GetMseconds
    mov  tmBox, eax
    jmp  inEnd    ; Reset air time clock register reference tracking marker
inQuit:
    mov  dead, 1          ; Assign standard exit status code to flag to drop execution loops out
inEnd:
    ret
InputPROC ENDP

; ============================================================
; GameLoop - Main Engine Ticking Runtime Cycle Controller
; ============================================================
GameLoop PROC
    call Clrscr
gLoop:
    call HUD              ; Clear top data text and draw live HUD interface strings
    call PrintGrid        ; Flush 1D sequential matrix array layout directly to viewscreen terminal coordinates
    cmp  dead, 0          
    jne  gOver            ; Evaluate status tracking flag: loop breaks if dead code value does not equal 0
    
    ; Route execution threads down to standalone update modules sequentially on every processing frame
    call InputPROC
    call UpdateCars
    call UpdatePeds
    call UpdateBox
    call SpawnBox
    
    mov  eax, 16
    call Delay ; Regulate system pacing block to hold cycle processing to a steady ~60FPS rate
    jmp  gLoop
gOver:
    mov  dh, R_BOT + 2
    mov  dl, 0
    call Gotoxy ; Drop cursor past active level geometry lines for ending prints
    cmp  dead, 2          
    je   printWinMessage  ; Route string execution to victory logic block if win code value matches 2

    ; --- PRINT GAME OVER SCREEN ---
    mov  al, ' '
    call WriteChar
    mov  al, 'G'
    call WriteChar
    mov  al, 'A'
    call WriteChar
    mov  al, 'M'
    call WriteChar
    mov  al, 'E'
    call WriteChar
    mov  al, ' '
    call WriteChar
    mov  al, 'O'
    call WriteChar
    mov  al, 'V'
    call WriteChar
    mov  al, 'E'
    call WriteChar
    mov  al, 'R'
    call WriteChar
    mov  al, '!'
    call WriteChar
    jmp  finishEndScreen
printWinMessage:
    ; --- PRINT VICTORY MESSAGE ---
    mov  al, ' '
    call WriteChar
    mov  al, 'V'
    call WriteChar
    mov  al, 'I'
    call WriteChar
    mov  al, 'C'
    call WriteChar
    mov  al, 'T'
    call WriteChar
    mov  al, 'O'
    call WriteChar
    mov  al, 'R'
    call WriteChar
    mov  al, 'Y'
    call WriteChar
    mov  al, '!'
    call WriteChar
    
    ; --- SCORE ADDITION LINK ---
    ; Appends score tracker safely directly onto end of line block using existing UI string memory data assets
    mov  edx, OFFSET scrStr  ; Load HUD string data descriptor location pointer ("SCORE: ") into target argument EDX
    call WriteString         ; Execute Irvine terminal write to append text directly next to victory characters
    mov  eax, pts            ; Move signed double-word tracking tally contents down into print buffer register EAX
    call WriteInt            ; Flush live integer value out right next to string block descriptor seamlessly
finishEndScreen:
    call Crlf
    ret
GameLoop ENDP

; ============================================================
; main - Entry Point Controller
; ============================================================
main PROC
    call MainMenu         ; 1. Load Welcome screens and choose track configuration assignments
    call Init             ; 2. Wipe memory structures and build map grid characters using difficulty rows
    call GameLoop         ; 3. Launch processing cycles until Win, Loss, or manual Close key issued
    exit                  ; 4. Gracefully return allocation boundaries back to OS kernel system
main ENDP

END main