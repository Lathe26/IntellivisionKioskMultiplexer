; ROM from pre-1982 In-Store Kiosk

; Variables locations:
;   VAR8_IS_INITIALIZED     $015D
;   VAR8_CONT_TIMDEOUT_FLAG $015E
;   VAR8_CART_COUNTER       $015F
;   VAR8_CONT_DEBOUCE_TIMER $0160
;   VAR8_PRIOR_RAND         $0161
;   VAR8_LINE_COUNT         $0162
;   VAR8_LINE_COUNTDOWN     $0163
;   VAR8_TITLE_BUFFER       $0164
;
;   VAR16_CONT_TIMEOUT      $0315
;   VAR16_COLOR_MASK        $0316
;   VAR16_START_OF_LINE     $0317
;   VAR16_ISR_WAIT_TICKS    $0318

; ROM hacks:
;   $7088   Change BNC ($0209) to NOPP ($0208) so that Game does not appear in slot 0
;   $72F8   Because jzintv4droid does not support --rand-mem, change BEQ ($0224) to NOPP ($0208)

        ORG     $7000
        
ENTRY_POINT:
        PSHR    R5                              ; 7000   0275                   Push return address to stack
        SDBD                                    ; 7001   0001                   -.
        MVII    #$8000, R3                      ; 7002   02BB 0000 0080          |
        MVI@    R3,     R0                      ; 7005   0298                    |- Check if an instruction (< $0400) is at $8000 
        SDBD                                    ; 7006   0001                    |
        CMPI    #$0400, R0                      ; 7007   0378 0000 0004         -'        
        BC      MAIN_INIT                       ; 700A   0201 0003              If $8000 isn't code, go to this ROM's main code...
        J       $8000                           ; 700C   0004 0380 0000         ... else execute $8000.
        
MAIN_INIT:
        JSR     R5,     WAIT_FOR_ISR_END        ; 700F   0004 0170 015C         Wait for the end of the ISR
        MVII    #$0000, R4                      ; 7012   02BC 0000              -.
        MVII    #$0008, R0                      ; 7014   02B8 0008               |- Zero out to MOB X-position STIC register
        JSR     R5,     X_FILL_ZERO             ; 7016   0004 0114 0338         -'
        MVII    #$0028, R4                      ; 7019   02BC 0028              -.
        MVII    #$0005, R0                      ; 701B   02B8 0005               |- Set STIC's color stack and border color to Black
        JSR     R5,     X_FILL_ZERO             ; 701D   0004 0114 0338         -'
        MVII    #$0030, R4                      ; 7020   02BC 0030              -.
        MVII    #$0003, R0                      ; 7022   02B8 0003               |- Set STIC background delays to 0, keep screen full-sized
        JSR     R5,     X_FILL_ZERO             ; 7024   0004 0114 0338         -'
        SDBD                                    ; 7027   0001                   -.
        MVII    UDB_PLUS_X14, R0                ; 7028   02B8 0073 0073          |_ Set Universal Data Base + $14 (i.e. cartridge header) to $7373
        MVII    #$02F0, R3                      ; 702B   02BB 02F0               |
        MVO@    R0,     R3                      ; 702D   0258                   -'        
        SDBD                                    ; 702E   0001                   -.
        MVII    GRAM_INIT_DEST, R5              ; 702F   02BD 007B 0073          |- Initialize the GRAM
        JSRD    R4,     X_NEW_GRAM_INIT         ; 7032   0004 001E 0335         -'
        SDBD                                    ; 7035   0001                   -.
        MVII    #$5014, R0                      ; 7036   02B8 0014 0050          |_ Set GRAM allocation table to back to $5014
        MVII    #$02F0, R3                      ; 7039   02BB 02F0               |  
        MVO@    R0,     R3                      ; 703B   0258                   -'        
        MVII    #$0102, R4                      ; 703C   02BC 0102              -.
        SDBD                                    ; 703E   0001                    |_ Zero out $0102-$015C (EXEC's 8-bit RAM)
        MVII    #$005B, R0                      ; 703F   02B8 005B 0000          |
        JSR     R5,     X_FILL_ZERO             ; 7042   0004 0114 0338         -'
        MVII    #$0001, R0                      ; 7045   02B8 0001              -.
        MVII    #$0147, R3                      ; 7047   02BB 0147               |- Set EXEC 8-bit var at $0147 to $0001
        MVO@    R0,     R3                      ; 7049   0258                   -'
        SDBD                                    ; 704A   0001                   -.
        MVII    VAR16_CONT_TIMEOUT, R4          ; 704B   02BC 0015 0003          |_ Set VAR16_CONT_TIMEOUT to 600 (10 seconds on NTSC)
        MVII    #$0258, R0                      ; 704E   02B8 0258               |
        MVO@    R0,     R4                      ; 7050   0260                   -'
        CLRR    R0                              ; 7051   01C0                   -.
        MVII    #$VAR8_IS_INITIALIZED, R4       ; 7052   02BC 015D               |_ Clear kiosk's VAR8s $015D-$015F
        MVO@    R0,     R4                      ; 7054   0260                    |
        MVO@    R0,     R4                      ; 7055   0260                   -'
        JSR     R5,     COLOR_STACK_W_BLACK     ; 7056   0004 0170 013E         Set to Color Stack mode and black out the screen
        JSR     R5,     PRINT_NEXT_CARTS_TITLE  ; 7059   0004 0170 0133         Print the next cartridge's title
        JSR     R5,     INSTALL_MAIN_ISR        ; 705C   0004 0170 00A6         Install the main ISR for the kiosk hardware
        JSR     R5,     INIT_HANDTAB            ; 705F   0004 0170 010A         Initialize the HANDTAB

MAIN_LOOP:
        EIS                                     ; 7062   0002                   Enable interrupts
        MVII    #$VAR8_IS_INITIALIZED, R4       ; 7063   02BC 015D              -.
        MVI@    R4,     R0                      ; 7065   02A0                    |_ If VAR8_IS_INITIALIZED != 0
        TSTR    R0                              ; 7066   0080                    |  goto RESTORE_EXEC_ISR
        BNEQ    RESTORE_EXEC_ISR                ; 7067   020C 002B              -'  This is only true after the user presses Enter to select a game.
        MVI@    R4,     R0                      ; 7069   02A0                   -.  
        TSTR    R0                              ; 706A   0080                    |- If VAR8_CONT_TIMEDOUT_FLAG is != 0
        BNEQ    HANDLE_CONTROLLER_TIMEOUT       ; 706B   020C 000E              -'  goto HANDLE_CONTROLLER_TIMEOUT
        SDBD                                    ; 706D   0001                   -.
        MVII    VAR16_CONT_TIMEOUT, R3          ; 706E   02BB 0015 0003          |
        MVI@    R3,     R0                      ; 7071   0298                    |  Every 4th VAR16_CONT_TIMEOUT value, call EXEC to 
        ANDI    #$0003, R0                      ; 7072   03B8 0003               |- process the hand controllers (EXEC code at $14F1)
        BNEQ    MAIN_LOOP                       ; 7074   022C 0013               |  This is a 15Hz rate on NTSC.
        JSR     R5,     .EXEC.4F1               ; 7076   0004 0114 00F1          |  Note: assumes EXEC routine is non-blocking unless 1+9 is pressed
        B       MAIN_LOOP                       ; 7079   0220 0018              -'

HANDLE_CONTROLLER_TIMEOUT:
        CLRR    R4                              ; 707B   01E4                   -._ Activate cartridge slot 0
        JSR     R5,     WRITE_TO_7410_AREA      ; 707C   0004 0170 0332         -'
        SDBD                                    ; 707F   0001                   -.
        MVII    #$5000, R3                      ; 7080   02BB 0000 0050          |
        MVI@    R3,     R0                      ; 7083   0298                    |_ See if a cartridge is in slot 0 (check $5000 for an instruction).
        SDBD                                    ; 7084   0001                    |  If so, restore the default EXEC ISR and return out of all kiosk code.
        CMPI    #$0400, R0                      ; 7085   0378 0000 0004          |
        BNC     RESTORE_EXEC_ISR                ; 7088   0209 000A              -'
        SDBD                                    ; 708A   0001                   -.
        MVII    #$1FFC, R5                      ; 708B   02BD 00FC 001F          |  No cartridge found in slot 0.
        MVI@    R5,     R0                      ; 708E   02A8                    |_ Check $1FFC in the EXEC to detect Sears vs Mattel...
        TSTR    R0                              ; 708F   0080                    |
        BNEQ    BRANCH_ATTRACT_SEARS            ; 7090   020C 000E               |  If non-zero, assume that Sears EXEC found
        B       BRANCH_ATTRACT_MATTEL           ; 7092   0200 000F              -'  If zero, it's Mattel.
                                                ;                                   Bug:  Intellivsion II will be confused with Sears.

RESTORE_EXEC_ISR:
        DIS                                     ; 7094   0003                   -.
        SDBD                                    ; 7095   0001                    |
        MVII    #$1126, R0                      ; 7096   02B8 0026 0011          |
        MVII    #$0100, R4                      ; 7099   02BC 0100               |  Disable interrupts.
        MVO@    R0,     R4                      ; 709B   0260                    |- Install origin EXEC ISR routine
        SWAP    R0,     1                       ; 709C   0040                    |  En-enable interrupts
        MVO@    R0,     R4                      ; 709D   0260                    |
        EIS                                     ; 709E   0002                   -'
        PULR    R7                              ; 709F   02B7                   Return from ENTRY_POINT routine
        
BRANCH_ATTRACT_SEARS:
        J       DISPLAY_ATTRACT_SEARS           ; 70A0   0004 0374 002E         Goto real Sears attract mode

BRANCH_ATTRACT_MATTEL:
        J       DISPLAY_ATTRACT_MATTEL          ; 70A3   0004 0374 00AC         Goto real Mattel attract mode

INSTALL_MAIN_ISR:
        DIS                                     ; 70A6   0003                   -.
        MVII    #$0100, R4                      ; 70A7   02BC 0100               |
        SDBD                                    ; 70A9   0001                    |
        MVII    #$MAIN_ISR, R0                  ; 70AA   02B8 00B2 0070          |  Disable interrupts.
        MVO@    R0,     R4                      ; 70AD   0260                    |- Install new ISR routine of MAIN_ISR
        SWAP    R0,     1                       ; 70AE   0040                    |  En-enable interrupts
        MVO@    R0,     R4                      ; 70AF   0260                    |
        EIS                                     ; 70B0   0002                   -'
        MOVR    R5,     R7                      ; 70B1   00AF                   Return from routine

MAIN_ISR:
        PSHR    R5                              ; 70B2   0275                   Push return address to stack
        MVII    #$0003, R0                      ; 70B3   02B8 0003              -._ Generate random number between 0 and 7
        JSR     R5,     X_RAND1                 ; 70B5   0004 0114 027D         -'  Bug or feature that returned rand value is ignore?  Is it just seeding/advancing it?
        SDBD                                    ; 70B8   0001                   -.
        MVII    #$VAR16_ISR_WAIT_TICKS, R3      ; 70B9   02BB 0018 0003          |
        MVI@    R3,     R0                      ; 70BC   0298                    |- Decrement VAR16_ISR_WAIT_TICKS
        DECR    R0                              ; 70BD   0010                    |
        MVO@    R0,     R3                      ; 70BE   0258                   -'
        SDBD                                    ; 70BF   0001                   -.
        MVII    VAR16_CONT_TIMEOUT, R3          ; 70C0   02BB 0015 0003          |  Read VAR16_CONT_TIMEOUT, decrement value in R0.
        MVI@    R3,     R0                      ; 70C3   0298                    |_ If value 0, then goto @@cont_timedout
        DECR    R0                              ; 70C4   0010                    |  ... otherwise store decremented value back in VAR16_CONT_TIMEOUT
        BEQ     @@cont_timedout                 ; 70C5   0204 0010               |  
        MVO@    R0,     R3                      ; 70C7   0258                   -'        
        MVII    #VAR8_CONT_DEBOUCE_TIMER, R3    ; 70C8   02BB 0160              -.
        MVI@    R3,     R0                      ; 70CA   0298                    |  
        TSTR    R0                              ; 70CB   0080                    |_ Decrement VAR8_CONT_DEBOUCE_TIMER down to 0 (don't decrement further).
        BEQ     @@enable_display_play_note      ; 70CC   0204 0002               |  
        DECR    R0                              ; 70CE   0010                    |  
        MVO@    R0,     R3                      ; 70CF   0258                   -'        
@@enable_display_play_note:                     ;                               -.
        MVII    #$0020, R3                      ; 70D0   02BB 0020               |- Enable STIC display
        MVO@    R0,     R3                      ; 70D2   0258                   -'
        JSR     R5,     X_PLAY_NOTE             ; 70D3   0004 0118 02BD         Play a note... assuming that what this does.  What note is played?
        PULR    R7                              ; 70D6   02B7                   Return from ISR
@@cont_timedout:                                ;                               -.
        MVII    #$0001, R0                      ; 70D7   02B8 0001               |_ Set VAR8_CONT_TIMEDOUT_FLAG to 1
        MVII    #VAR8_CONT_TIMEDOUT_FLAG, R3    ; 70D9   02BB 015E               |
        MVO@    R0,     R3                      ; 70DB   0258                   -'
        B       @@enable_display_play_note      ; 70DC   0220 000D              Enable the display and play a note

HANDTAB:                                        ;                               Inputs:
                                                ;                                   R0 = Side buttons: -1 for released
                                                ;                                        Disc:  R0 = 0 is East, 2 is NE, 4 is North, etc.  -1 for released 
                                                ;                                        Keypad: R0 = keypad number ($A = Clear, $B = Enter)
                                                ;                                   R1 = 0 left controller, 1 for right controller
        BIDECLE $HANDLE_DISC                    ; 70DE   70EC                   Disc : R3 changes, but unclear what it is.
        BIDECLE $HANDLE_KEYPAD                  ; 70E0   70E8                   Keypad
        BIDECLE $0000                           ; 70E2   0000                   Handler for upper side button pressed/released?
        BIDECLE $0000                           ; 70E4   0000                   Handler for right side button pressed/released?
        BIDECLE $0000                           ; 70E6   0000                   Handler for left side button pressed/released?

HANDLE_KEYPAD:
        CLRR    R1                              ; 70E8   01C9                   -._ Set R1 to match what R2 was set to when .EXEC.910 was called so that the keypad
        J       .EXEC.94C                       ; 70E9   0004 0318 014C         -'  button is processed by .EXEC.94C.  If Enter was pressed, then HANDLE_ENTER is called

HANDLE_DISC:
        SDBD                                    ; 70EC   0001                   -.
        MVII    VAR16_CONT_TIMEOUT, R3          ; 70ED   02BB 0015 0003          |_ Set VAR16_CONT_TIMEOUT to 600 (10 seconds on NTSC)
        MVII    #$0258, R1                      ; 70F0   02B9 0258               |
        MVO@    R1,     R3                      ; 70F2   0259                   -'
        TSTR    R0                              ; 70F3   0080                   -._ If HANDTAB input R0 is 0, start debouncing
        BMI     @@start_debouncing              ; 70F4   020B 000D              -'  
        MVII    #VAR8_CONT_DEBOUCE_TIMER, R3    ; 70F6   02BB 0160              -.
        MVI@    R3,     R0                      ; 70F8   0298                    |_ If VAR8_CONT_DEBOUCE_TIMER has NOT zero, just exit routine now.
        TSTR    R0                              ; 70F9   0080                    |
        BNEQ    @@exit                          ; 70FA   020C 000C              -'        
        PSHR    R5                              ; 70FC   0275                   -.  Make the fast click noise
        JSR     R5,     .EXEC.60A               ; 70FD   0004 0114 020A          |- Assuming that is all EXEC $160A does.
        PULR    R5                              ; 7100   02B5                   -'  
        B       PRINT_NEXT_CARTS_TITLE          ; 7101   0200 0030              Display the next cart's title on the screen, then exit this handler.
@@start_debouncing:                             ;                               -.
        MVII    VAR8_CONT_DEBOUCE_TIMER, R3     ; 7103   02BB 0160               |_ Set VAR8_CONT_DEBOUCE_TIMER to 5
        MVII    #$0005, R0                      ; 7105   02B8 0005               |
        MVO@    R0,     R3                      ; 7107   0258                   -'
@@exit:                                         ;                               Start the exit early from routine process, starting from here.
        EIS                                     ; 7108   0002                   Enable interrupts
        MOVR    R5,     R7                      ; 7109   00AF                   Return from routine

INIT_HANDTAB:
        PSHR    R5                              ; 710A   0275                   Push the return address to the stack
        MVII    #$0005, R0                      ; 710B   02B8 0005              -.  Set up various registers before call into
        SDBD                                    ; 710D   0001                    |  EXEC function $1910
        MVII    #$5000, R1                      ; 710E   02B9 0000 0050          |  R0 = $0005
        CLRR    R2                              ; 7111   01D2                    |_ R1 = $5000  Bug?  Only low is stored in 8-bit memory
        CLRR    R3                              ; 7112   01DB                    |  R2 = $0000
        SDBD                                    ; 7113   0001                    |  R3 = $0000
        MVII    #$HANDTAB, R4                   ; 7114   02BC 00DE 0070          |  R4 = $70DE (pointer to HANDTAB)
        JSR     R5,     .EXEC.910               ; 7117   0004 0118 0110         -'  THIS FUNCTION RETURNS TO PREVIOUS CALLER !!!

; Execution only reaches here AFTER the controller is used and ENTER is pressed.  The return call stack is
;   .EXEC.03D   This from where the EXEC calls into $7000 after reset
;   $7079       In MAIN_LOOP after it calls .EXEC.4F1
;   .EXEC.52A   The EXEC code that handles the HANDTAB processing
;   $711A       Here...
HANDLE_ENTER:
        SDBD                                    ; 711A   0001                   -.  If output is magic value, then goto
        CMPI    #$3EF9, R0                      ; 711B   0378 00F9 003E          |- DISPLAY_EASTER_EGG1
        BEQ     DISPLAY_EASTER_EGG1             ; 711E   0204 0053              -'  Type in 16121 or 81657 and then Enter
        SDBD                                    ; 7120   0001                   -.  If output is magic value, then goto
        CMPI    #$5243, R0                      ; 7121   0378 0043 0052          |- DISPLAY_EASTER_EGG2
        BEQ     DISPLAY_EASTER_EGG2             ; 7124   0204 0066              -'  Type in 21059
        JSR     R5,     PLAY_TUNE               ; 7126   0004 0170 0398         Play some music 
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 7129   0004 0170 034D         -._ Wait 61 ticks (1 second on NTSC)
        DECLE   $0041                           ; 712C   0041                   -'
        MVII    #$0001, R0                      ; 712D   02B8 0001              -.
        MVII    #$VAR8_IS_INITIALIZED, R3       ; 712F   02BB 015D               |- Set VAR8_IS_INITIALIZED to 1
        MVO@    R0,     R3                      ; 7131   0258                   -'
        PULR    R7                              ; 7132   02B7                   Return from routine

PRINT_NEXT_CARTS_TITLE:
        PSHR    R5                              ; 7133   0275                   -.
        JSR     R5,     FIND_NEXT_CART          ; 7134   0004 0170 01A0          |_ Find the next cartridge, read and print its title
        JSR     R5,     READ_CART_TITLE         ; 7137   0004 0170 01DE          |
        JSR     R5,     PRINT_TITLE             ; 713A   0004 0170 021C         -'
        PULR    R7                              ; 713D   02B7                   Return from routine

COLOR_STACK_W_BLACK:
        PSHR    R5                              ; 713E   0275                   Push return address to stack
        MVII    #$00F0, R0                      ; 713F   02B8 00F0              -.
        MVII    #$0200, R4                      ; 7141   02BC 0200               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7143   0004 0114 0338         -'        
        JSR     R5,     WAIT_FOR_ISR_END        ; 7146   0004 0170 015C         Wait here until the ISR is hit
        MVII    #$0021, R3                      ; 7149   02BB 0021              -._ Set STIC to Color Stack mode
        MVI@    R3,     R0                      ; 714B   0298                   -'
        MVII    #$0000, R0                      ; 714C   02B8 0000              -.
        MVII    #$0028, R3                      ; 714E   02BB 0028               |
        MVO@    R0,     R3                      ; 7150   0258                    |- Set 1st color stack entry and border to Black
        MVII    #$002C, R3                      ; 7151   02BB 002C               |
        MVO@    R0,     R3                      ; 7153   0258                   -'
        PULR    R7                              ; 7154   02B7                   Return from routine

AFTER_PRINT_EASTER_EGG:
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 7155   0004 0170 034D         -._ Wait 300 ticks (5 seconds on NTSC)
        DECLE   $012C                           ; 7158   012C                   -'
        J       X_RESET                         ; 7159   0004 0310 0000         Reset the system

WAIT_FOR_ISR_END:
        PSHR    R5                              ; 715C   0275                   Push return address to stack
        MOVR    R7,     R0                      ; 715D   00B8                   -._ Put SYNC_WITH_STIC_ISR into R0
        ADDI    #$000D, R0                      ; 715E   02F8 000D              -'  
        MVII    #$0100, R4                      ; 7160   02BC 0100              -.
        MOVR    R4,     R5                      ; 7162   00A5                    |
        DIS                                     ; 7163   0003                    |
        SDBD                                    ; 7164   0001                    |  Replace the normal ISR with SYNC_WITH_STIC_ISR.
        MVI@    R4,     R1                      ; 7165   02A1                    |- Temporarily store normal ISR in R1
        MVO@    R0,     R5                      ; 7166   0268                    |
        SWAP    R0,     1                       ; 7167   0040                    |
        MVO@    R0,     R5                      ; 7168   0268                    |
        EIS                                     ; 7169   0002                   -'
@@wait_for_isr:                                 ;                               -._ Wait here until the ISR is hit
        DECR    R7                              ; 716A   0017                   -'

SYNC_WITH_STIC_ISR:
        SUBI    #$0008, R6                      ; 716B   033E 0008              Adjust the stack pointer, discarding some data
        MVII    #$0100, R4                      ; 716D   02BC 0100              -.  Restore the normal ISR that was in R1
        MVO@    R1,     R4                      ; 716F   0261                    |_ and exit.  Assuming this returns to just
        SWAP    R1,     1                       ; 7170   0041                    |  after "JSR WAIT_FOR_ISR_END".
        MVO@    R1,     R4                      ; 7171   0261                   -'  
        PULR    R7                              ; 7172   02B7                   Return from routine

DISPLAY_EASTER_EGG1:
        MVII    #$0200, R4                      ; 7173   02BC 0200              -.
        MVII    #$00F0, R0                      ; 7175   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7177   0004 0114 0338         -'
        MVII    #$0001, R0                      ; 717A   02B8 0001              -.
        MVII    #$VAR8_LINE_COUNT, R4           ; 717C   02BC 0162               |_ Set VAR8_LINE_COUNT & VAR8_LINE_COUNTDOWN to 1
        MVO@    R0,     R4                      ; 717E   0260                    |  (EASTER_EGG_TEXT1 has 2 lines)
        MVO@    R0,     R4                      ; 717F   0260                   -'
        SDBD                                    ; 7180   0001                   -._ Set R4 to be the fake "game title"
        MVII    #$EASTER_EGG_TEXT1, R4          ; 7181   02BC 00C0 0071         -'
PRINT_EASTER_EGG:                               ;                               Either fall through from above (egg1) or jump to (egg2)
        SDBD                                    ; 7184   0001                   -.
        MVII    #$AFTER_PRINT_EASTER_EGG, R5    ; 7185   02BD 0055 0071          |_ Print one of the Easter Egg screens, set
        PSHR    R5                              ; 7188   0275                    |  return address to AFTER_PRINT_EASTER_EGG
        J       PRINT_TITLE.@@print_next_line   ; 7189   0004 0370 0232         -'

DISPLAY_EASTER_EGG2:
        MVII    #$0200, R4                      ; 718C   02BC 0200              -.
        MVII    #$00F0, R0                      ; 718E   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7190   0004 0114 0338         -'
        MVII    #$0002, R0                      ; 7193   02B8 0002              -.
        MVII    #$VAR8_LINE_COUNT, R4           ; 7195   02BC 0162               |_ Set VAR8_LINE_COUNT & VAR8_LINE_COUNTDOWN to 1
        MVO@    R0,     R4                      ; 7197   0260                    |  (EASTER_EGG_TEXT1 has 2 lines)
        MVO@    R0,     R4                      ; 7198   0260                   -'
        SDBD                                    ; 7199   0001                   -._ Set R4 to be the fake "game title"
        MVII    #$EASTER_EGG_TEXT2, R4          ; 719A   02BC 00CE 0071         -'
        J       PRINT_EASTER_EGG                ; 719D   0004 0370 0184         Go print the easter egg

FIND_NEXT_CART:                                 ;                               Note: R0 is always 0 on entry
        PSHR    R5                              ; 71A0   0275                   Push return address to stack
@@next_count:                                   ;                               -.  Start checking for cartridges
        JSR     R5,     WRITE_TO_7400           ; 71A1   0004 0170 032C          |- (Don't exit until one is found!)
        JSR     R5,     INCR_VAR8_CART_COUNTER  ; 71A4   0004 0170 0347         -'
        CMPI    #$00EB, R4                      ; 71A7   037C 00EB              -.  Did VAR8_CART_COUNTER exceed EB?
        BLT     @@read_cart                     ; 71A9   0205 0005               |_ ... yup, reset it to zero and start over.
        JSR     R5,     CLEAR_VAR8_CART_COUNTER ; 71AB   0004 0170 0338          |  VAR8_CART_COUNTER can only be 1 thru 234 (never 0)
        B       @@next_count                    ; 71AE   0220 000E              -'  Bug:  No cart causes an infinite loop.
@@read_cart:                                    ;                               -._ ... nope, write to an address
        JSR     R5,     WRITE_TO_7410_AREA      ; 71B0   0004 0170 0332         -'  in the $7410 to $74FA range.
        SDBD                                    ; 71B3   0001                   -.
        MVII    #$5000, R3                      ; 71B4   02BB 0000 0050          |
        EIS                                     ; 71B7   0002                    |_ See if there is a cartridge present 
        MVI@    R3,     R0                      ; 71B8   0298                    |  (i.e. code/BIDECLE at $5000) 
        SDBD                                    ; 71B9   0001                    |  (enable interrupts as well)
        CMPI    #$0400, R0                      ; 71BA   0378 0000 0004         -'
        BC      @@next_count                    ; 71BD   0221 001D              Nope, nothing found, try again.
        PULR    R7                              ; 71BF   02B7                   Something found, return from routine

EASTER_EGG_TEXT1:
        STRING  "JOHN"                          ; 71C0                          -.
        DECLE   $0000                           ; 71C4   0000                    |_ Easter Egg text #1  :-)
        STRING  "WAS HERE"                      ; 71C5                           |
        DECLE   $0000                           ; 71CD   0000                   -'
        
EASTER_EGG_TEXT2:
        STRING  "JOHN"                          ; 71CE                          -.
        DECLE   $0000                           ; 71D2   0000                    |
        STRING  "LOVES"                         ; 71D3                           |_ Easter Egg text #2  :-)
        DECLE   $0000                           ; 71D8   0000                    |
        STRING  "LUCY"                          ; 71D9                           |
        DECLE   $0000                           ; 71DD   0000                   -'

READ_CART_TITLE:
        PSHR    R5                              ; 71DE   0275                   Push return address to stack
        JSR     R5,     X_READ_ROM_HDR          ; 71DF   0004 0110 00AB         -._ Get cart's Date/Tile address and put into R5
        DECLE   $000A                           ; 71E2   000A                   -'  
        MOVR    R5,     R4                      ; 71E3   00AC                   -._ Skip over the Date
        INCR    R4                              ; 71E4   000C                   -'
        MVI@    R4,     R0                      ; 71E5   02A0                   -.
        DECR    R4                              ; 71E6   0014                    |  Check if the Title is a blank string.
        TSTR    R0                              ; 71E7   0080                    |  If not, use the actual title,
        BNEQ    @@not_blank                     ; 71E8   020C 0004               |- otherwise default to "MATH FUN" title.
        SDBD                                    ; 71EA   0001                    |  Title address is returned in R4.
        MVII    MATH_FUN_TITLE, R4              ; 71EB   02BC 00EF 0071          |  
@@not_blank:                                    ;                               -'
        PULR    R7                              ; 71EE   02B7                   Return from routine

MATH_FUN_TITLE:
        STRING  "MATH FUN"                      ; 71EF                          -.
        DECLE   $0000                           ; 71F7   0000                    |
        STRING  "Electric Company"              ; 71F8                           |- Default game title of "Math Fun"
        STRING  " MATH FUN CARTRIDGE"           ; 7208                           |
        DECLE   $0000                           ; 721B   0000                   -'
        
PRINT_TITLE:                                    ;                               Input: R4 is cartridge's title
        PSHR    R5                              ; 721C   0275                   -._ Save off registers to the stack
        PSHR    R4                              ; 721D   0274                   -'
        JSR     R5,     UPDATE_RAND_COLOR_MASK  ; 721E   0004 0170 02EF         Update the random color mask  
        MVII    #$0200, R4                      ; 7221   02BC 0200              -.
        MVII    #$00F0, R0                      ; 7223   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7225   0004 0114 0338         -'
        PULR    R4                              ; 7228   02B4                   -._ Restore R4 (cartridge title) from the stack
        JSR     R5,     PARSE_TITLE_INTO_LINES  ; 7229   0004 0170 0282         -'  so that it can be parsed into the title buffer
        MVII    #$VAR8_LINE_COUNT, R4           ; 722C   02BC 0162              -.
        MVI@    R4,     R0                      ; 722E   02A0                    |- Initialize VAR8_LINE_COUNTDOWN with VAR8_LINE_COUNT
        MVO@    R0,     R4                      ; 722F   0260                   -'
        MVII    #$VAR8_TITLE_BUFFER, R4         ; 7230   02BC 0164              Set R4 to the start of the title buffer
@@print_next_line:
        JSR     R5,     PRINT_TITLE_LINE         ; 7232   0004 0170 023D        Print 1 line of the title
        MVII    #$VAR8_LINE_COUNTDOWN, R3       ; 7235   02BB 0163              -.
        MVI@    R3,     R0                      ; 7237   0298                    |  
        DECR    R0                              ; 7238   0010                    |- Decrement VAR8_LINE_COUNTDOWN.
        MVO@    R0,     R3                      ; 7239   0258                    |  If still positive, print the next line
        BPL     @@print_next_line               ; 723A   0223 0009              -'
        PULR    R7                              ; 723C   02B7                   Return from PRINT_TITLE routine

PRINT_TITLE_LINE:                               ;                               Input: R4 is start of the line inside of #VAR8_TITLE_BUFFER
        PSHR    R5                              ; 723D   0275                   Push return address to stack
        MVII    #$VAR8_LINE_COUNTDOWN, R3       ; 723E   02BB 0163              -.
        MVI@    R3,     R0                      ; 7240   0298                    |  Read VAR8_LINE_COUNTDOWN, multiply by 60 ($3C)
        MVII    #$003C, R1                      ; 7241   02B9 003C               |- and store into R0 (60 = 3 Backtab rows)
        JSR     R5,     X_MPY                   ; 7243   0004 011C 01DC          |
        MOVR    R2,     R0                      ; 7246   0090                   -'        
        MVII    #$VAR8_LINE_COUNT, R3           ; 7247   02BB 0162              -.
        MVI@    R3,     R2                      ; 7249   029A                    |  Use VAR8_LINE_COUNT to index into TITLE_LAST_LINE_CENTERS
        SDBD                                    ; 724A   0001                    |- to find out where in the Backtab that the last line of the
        ADDI    #$TITLE_LAST_LINE_CENTERS, R2   ; 724B   02FA 00EB 0072          |  title is centered.
        MVI@    R2,     R2                      ; 724E   0292                   -'  Bug:  Does not handle more than 4 title lines.
        SUBR    R0,     R2                      ; 724F   0102                   Subtract off the offset to get the CURRENT title line's center position
        MOVR    R4,     R1                      ; 7250   00A1                   Copy start of line in #VAR8_TITLE_BUFFER to R1
@@backtab_line_start_pos:                       ;                               -.
        DECR    R2                              ; 7251   0012                    |
        MVI@    R4,     R0                      ; 7252   02A0                    |- Decrement R2 Backtab position for each character in the current line
        TSTR    R0                              ; 7253   0080                    |
        BNEQ    @@backtab_line_start_pos        ; 7254   022C 0004              -'
        MOVR    R2,     R4                      ; 7256   0094                   -.  Initial registers as follows:
        MOVR    R4,     R3                      ; 7257   00A3                    |- R2 = R4 = Backtab starting position
        ADDI    #$0014, R3                      ; 7258   02FB 0014              -'  R3 = Backtab starting position + 20 (next row, same column)
@@next_char:                                    ;                               Start processing the next char, starting from here.
        MVI@    R1,     R0                      ; 725A   0288                   -.
        INCR    R1                              ; 725B   0009                    |_ Read character, see if it is '\0', set R1 to point to next character
        TSTR    R0                              ; 725C   0080                    |  then goto @@end_of_line
        BEQ     @@end_of_line                   ; 725D   0204 0021              -'
        ANDI    #$001F, R0                      ; 725F   03B8 001F              -.  Mask off the character to 5 bit range, treat all $1B-$1F as spaces.
        CMPI    #$001A, R0                      ; 7261   0378 001A               |  Net effect is that lower-case chars are capitalized, and all 
        BLE     @@is_alpha                      ; 7263   0206 0001               |- remaining symbols and numbers are treated as spaces.
        CLRR    R0                              ; 7265   01C0                    |
@@is_alpha:                                     ;                               -'  Note: PARSE_TITLE_INTO_LINES already converted < 'A' chars to spaces.
        SLL     R0,     2                       ; 7266   004C                   -.
        SDBD                                    ; 7267   0001                    |-  Multiply R0 by 4 to index into the CHAR_TO_GRAM_INDEX_TABLE
        ADDI    #$CHAR_TO_GRAM_INDEX_TABLE, R0  ; 7268   02F8 00C2 0073         -'
        MOVR    R0,     R2                      ; 726B   0082                   -.
        JSR     R5,     APPLY_COLOR_MASK        ; 726C   0004 0170 0319          |- Get GRAM index, apply color (R2 incremented for next call), 
        MVO@    R0,     R4                      ; 726F   0260                   -'  write to upper-left location for char in the Backtab.
        JSR     R5,     APPLY_COLOR_MASK        ; 7270   0004 0170 0319         -._ Get GRAM index, apply color (R2 incremented for next call), 
        MVO@    R0,     R4                      ; 7273   0260                   -'  write to upper-right location for char in the Backtab.
        JSR     R5,     APPLY_COLOR_MASK        ; 7274   0004 0170 0319         -.  Get GRAM index, apply color (R2 & R3 incremented for next call),
        MVO@    R0,     R3                      ; 7277   0258                    |- write to lower-left location for char in the Backtab.
        INCR    R3                              ; 7278   000B                   -'
        JSR     R5,     APPLY_COLOR_MASK        ; 7279   0004 0170 0319         -.  Get GRAM index, apply color (R2 & R3 incremented for next call),
        MVO@    R0,     R3                      ; 727C   0258                    |- write to lower-right location for char in the Backtab.
        INCR    R3                              ; 727D   000B                   -'
        B       @@next_char                     ; 727E   0220 0025              Go read the next character
@@end_of_line:                                  ;                               EOL handling starts from here
        MOVR    R1,     R4                      ; 7280   008C                   Restore R4 to the start of the next line in VAR8_TITLE_BUFFER
        PULR    R7                              ; 7281   02B7                   Return from routine

PARSE_TITLE_INTO_LINES:                         ;                               Input: R4 points to the Cartridge title
        PSHR    R5                              ; 7282   0275                   Push return address to stack
        CLRR    R0                              ; 7283   01C0                   -.
        MVII    #$VAR8_LINE_COUNT, R3           ; 7284   02BB 0162               |  Initialize the following variables:
        MVO@    R0,     R3                      ; 7286   0258                    |  VAR8_LINE_COUNT = 0
        MVII    #$VAR8_TITLE_BUFFER, R5         ; 7287   02BD 0164               |- R5 = start of the title buffer (point to addresss VAR8_TITLE_BUFFER)
        SDBD                                    ; 7289   0001                    |  VAR16_START_OF_LINE = start of title buffer
        MVII    #$VAR16_START_OF_LINE, R3       ; 728A   02BB 0017 0003          |
        MVO@    R5,     R3                      ; 728D   025D                   -'
@@next_char:                                    ;                               Start processing the next char, starting from here.
        MVI@    R4,     R0                      ; 728E   02A0                   Read next character from the cartridge's title
        TSTR    R0                              ; 728F   0080                   -._ If the character '\0', goto @@end_of_word
        BEQ     @@end_of_word                   ; 7290   0204 002D              -'
        CMPI    #$0026, R0                      ; 7292   0378 0026              -._ If the character '&', goto @@handle_amp
        BEQ     @@handle_amp                    ; 7294   0204 000D              -'
        CMPI    #$0040, R0                      ; 7296   0378 0040              -._ If the character >= 'A', goto @@mostly_alphas
        BGT     @@mostly_alphas                 ; 7298   020E 0002              -'
        MVII    #$0020, R0                      ; 729A   02B8 0020              Set all remaining < 'A' characters as a space
@@mostly_alphas:                                ;                               Fall-true or jump here from above
        CMPI    #$0020, R0                      ; 729C   0378 0020              -._ If the character a space, goto @@end_of_word
        BEQ     @@end_of_word                   ; 729E   0204 001F              -'
        MVO@    R0,     R5                      ; 72A0   0268                   Add character to buffer (if >= 'A')
        B       @@next_char                     ; 72A1   0220 0014              Go get the next character
@@handle_amp:
        DECR    R5                              ; 72A3   0015                   Back up 1 char
        CLRR    R0                              ; 72A4   01C0                   -.
        MVO@    R0,     R5                      ; 72A5   0268                    |
        MVII    #$0041, R0                      ; 72A6   02B8 0041               |
        MVO@    R0,     R5                      ; 72A8   0268                    |
        MVII    #$004E, R0                      ; 72A9   02B8 004E               |- Write '\0AND\0' to title buffer
        MVO@    R0,     R5                      ; 72AB   0268                    |
        MVII    #$0044, R0                      ; 72AC   02B8 0044               |
        MVO@    R0,     R5                      ; 72AE   0268                    |
        CLRR    R0                              ; 72AF   01C0                    |
        MVO@    R0,     R5                      ; 72B0   0268                   -' 
        INCR    R4                              ; 72B1   000C                   Increment the title read pointer to the char after '&'
        MVII    #$VAR8_LINE_COUNT, R3           ; 72B2   02BB 0162              -.
        MVI@    R3,     R0                      ; 72B4   0298                    |
        INCR    R0                              ; 72B5   0008                    |- Increment VAR8_LINE_COUNT by 2
        INCR    R0                              ; 72B6   0008                    |
        MVO@    R0,     R3                      ; 72B7   0258                   -' 
        SDBD                                    ; 72B8   0001                   -.
        MVII    #$VAR16_START_OF_LINE, R3       ; 72B9   02BB 0017 0003          |- Set VAR16_START_OF_LINE to where the next char will go
        MVO@    R5,     R3                      ; 72BC   025D                   -'
        B       @@next_char                     ; 72BD   0220 0030              Go get the next character
@@end_of_word:                                  ;                               Handle the end of a word starting from here
        PSHR    R0                              ; 72BF   0270                   Save current char on the stack (R0)
        MOVR    R5,     R0                      ; 72C0   00A8                   -.
        SDBD                                    ; 72C1   0001                    |
        MVII    #$VAR16_START_OF_LINE, R3       ; 72C2   02BB 0017 0003          |_ See if current line is too long (>= 11 chars)
        SUB@    R3,     R0                      ; 72C5   0318                    |  [borrowing R0 for this calculation].
        CMPI    #$000B, R0                      ; 72C6   0378 000B               |  If so, goto @@long_line
        BGE     @@long_line                     ; 72C8   020D 0009              -'
@@check_last_line:                              ;                               Check for the end of the last line starting from here
        PULR    R0                              ; 72CA   02B0                   Pull current char from the stack (R0)
        MVO@    R0,     R5                      ; 72CB   0268                   -.  Add character (a '\0' or space) to title buffer,
        TSTR    R0                              ; 72CC   0080                    |_ see if it is a '\0'.
        BEQ     @@end_of_title                  ; 72CD   0204 0002               |  If so, goto @@end_of_title,
        B       @@next_char                     ; 72CF   0220 0042              -'  otherwise go get the next character.
@@end_of_title:                                 ;                               Handle the end of the entire title string, starting from here
        MVO@    R0,     R5                      ; 72D1   0268                   Add character (always a '\0') to buffer.
        PULR    R7                              ; 72D2   02B7                   Return out of PARSE_TITLE_INTO_LINES
@@long_line:                                    ;                               Handle that the line got too long for the screen, starting from here
        MVII    #$VAR8_LINE_COUNT, R3           ; 72D3   02BB 0162              -.
        MVI@    R3,     R0                      ; 72D5   0298                    |_ Increment VAR8_LINE_COUNT
        INCR    R0                              ; 72D6   0008                    |
        MVO@    R0,     R3                      ; 72D7   0258                   -'
        MOVR    R5,     R3                      ; 72D8   00AB                   -. Set up R3 as backwards traversing read pointer of the title buffer
@@find_prior_space:                             ;                                |
        DECR    R3                              ; 72D9   0013                    |_ Walk the title buffer backwards looking for a space.
        MVI@    R3,     R0                      ; 72DA   0298                    |  Bug:  If a word of in line is too long, it wraps around the screen,
        CMPI    #$0020, R0                      ; 72DB   0378 0020               |  with letters overwriting top/bottom half of other letters
        BNEQ    @@find_prior_space              ; 72DD   022C 0005              -'
        CLRR    R0                              ; 72DF   01C0                   -._ Replace prior space with a '\0'
        MVO@    R0,     R3                      ; 72E0   0258                   -' 
        INCR    R3                              ; 72E1   000B                   -. Set to 1st char of the current word
        PSHR    R4                              ; 72E2   0274                    |
        SDBD                                    ; 72E3   0001                    |_ Set VAR16_START_OF_LINE to the start of the word we just
        MVII    #$VAR16_START_OF_LINE, R4       ; 72E4   02BC 0017 0003          |  traversed backwards over.
        MVO@    R3,     R4                      ; 72E7   0263                    | 
        PULR    R4                              ; 72E8   02B4                   -'
        B       @@check_last_line               ; 72E9   0220 0020              Go check if character at END of current word was end of word or end of title.

TITLE_LAST_LINE_CENTERS:                        ;                               Table of where the last title lines are positioned in the Backtab
        DECLE   $026F                           ; 72EB   026F                   1 line title -> Row 5, Col 11
        DECLE   $0283                           ; 72EC   0283                   2 line title -> Row 6, Col 11
        DECLE   $02AB                           ; 72EC   02AB                   3 line title -> Row 8, Col 11
        DECLE   $02BF                           ; 72EE   02BF                   4 line title -> Row 9, Col 11

UPDATE_RAND_COLOR_MASK:
        PSHR    R5                              ; 72EF   0275                   Push return address to the stack (of course)
@@next_rand:                                    ;                               -.
        MVII    #$0003, R0                      ; 72F0   02B8 0003               |
        JSR     R5,     X_RAND1                 ; 72F2   0004 0114 027D          |  Keep generating a random number between 0 and 7
        MVII    #VAR8_PRIOR_RAND, R3            ; 72F5   02BB 0161               |- until it is different from VAR8_PRIOR_RAND.
        CMP@    R3,     R0                      ; 72F7   0358                    |  Store new value in VAR8_PRIOR_RAND.
        BEQ     @@next_rand                     ; 72F8   0224 0009               |  Bug:  Infinite loop if very 1st call to X_RAND1 returns 0.
        MVO@    R0,     R3                      ; 72FA   0258                   -'        jzintv exposed this bug majorly, thus jzintv --rand-mem is required.
        SLL     R0,     1                       ; 72FB   0048                   -.
        SDBD                                    ; 72FC   0001                    |
        ADDI    #@@color_table, R0              ; 72FD   02F8 0009 0073          |
        MOVR    R0,     R4                      ; 7300   0084                    |  Use random number to index into @@color_table
        SDBD                                    ; 7301   0001                    |- to get the appropriate BIDECLE.  Store it
        MVI@    R4,     R0                      ; 7302   02A0                    |  as a DECLE in VAR16_COLOR_MASK
        SDBD                                    ; 7303   0001                    |
        MVII    #VAR16_COLOR_MASK, R3           ; 7304   02BB 0016 0003          |
        MVO@    R0,     R3                      ; 7307   0258                   -'
        PULR    R7                              ; 7308   02B7                   Return from routine
@@color_table:                                   ;                              -.  BIDECLE table of Backtab colors (with GRAM bit set)
        DECLE   $0006,  $0008,  $0006,  $0018   ; 7309   0006 0008 0006 0018     |      Yellow,     YellowGreen
        DECLE   $0004,  $0018,  $0001,  $0018   ; 730D   0004 0018 0001 0018     |-     Pink,       Cyan
        DECLE   $0005,  $0018,  $0002,  $0018   ; 7311   0005 0018 0002 0018     |      LightBlue,  Orange
        DECLE   $0005,  $0008,  $0001,  $0008   ; 7315   0005 0008 0001 0008    -'      Green,      Blue
        
APPLY_COLOR_MASK:                               ;                               Input: R2 is a pointer to a GRAM index (index is stored in ROM), R2 is incremented here!
        PSHR    R5                              ; 7319   0275                   Push return address to stack
        MVI@    R2,     R0                      ; 731A   0290                   -.  
        INCR    R2                              ; 731B   000A                    |_ Read memory at R2 into R0, increment the R2 pointer,
        CMPI    #$0100, R0                      ; 731C   0378 0100               |  and compare value previously read to $100.  
        BEQ     @@bail_with_zero                ; 731E   0204 000A              -'  If equal, return 0 in R0 below
        SLL     R0,     2                       ; 7320   004C                   -.
        SLL     R0,     1                       ; 7321   0048                    |  Compare to $100 was false.
        PSHR    R3                              ; 7322   0273                    |  Multiply value by 8, XOR it by
        SDBD                                    ; 7323   0001                    |- VAR16_COLOR_MASK, and
        MVII    #VAR16_COLOR_MASK, R3           ; 7324   02BB 0016 0003          |  return the result in R0.
        XOR@    R3,     R0                      ; 7327   03D8                    |  
        PULR    R3                              ; 7328   02B3                   -'
        PULR    R7                              ; 7329   02B7                   Return from routine
@@bail_with_zero:                               ;                               -._ Put 0 in R0 
        CLRR    R0                              ; 732A   01C0                   -'
        PULR    R7                              ; 732B   02B7                   Return from routine

WRITE_TO_7400:
        SDBD                                    ; 732C   0001                   -.
        MVII    #$7400, R3                      ; 732D   02BB 0000 0074          |- Write R0 (which is always 0) to $7400 (register)
        MVO@    R0,     R3                      ; 7330   0258                   -'
        MOVR    R5,     R7                      ; 7331   00AF                   Return from routine

WRITE_TO_7410_AREA:                             ;                               Input: R4 is 0 to $EA (0 only happens in HANDLE_CONTROLLER_TIMEOUT)
        SDBD                                    ; 7332   0001                   -.  Write R0 to address $7410 + R4
        ADDI    #$7410, R4                      ; 7333   02FC 0010 0074          |- (R0 might be a dummy value and the 'address'
        MVO@    R0,     R4                      ; 7336   0260                   -'  is the value, similar to Atari 2600 cart "RAM")
        MOVR    R5,     R7                      ; 7337   00AF                   Return from routine  

CLEAR_VAR8_CART_COUNTER:
        CLRR    R0                              ; 7338   01C0                   -.  
        MVII    #VAR8_CART_COUNTER, R3          ; 7339   02BB 015F               |- Clear VAR8_CART_COUNTER
        MVO@    R0,     R3                      ; 733B   0258                   -'
        MOVR    R5,     R7                      ; 733C   00AF                   Return from routine

; DEAD CODE?  Looks like an unused routine to select cartridge slot at random... but it doesn't check for whether anything is in the slot.
        PSHR    R5                              ; 733D   0275                   Push return address to stack
        MVII    #$000A, R0                      ; 733E   02B8 000A              -.
        JSR     R5,     X_RAND2                 ; 7340   0004 0114 029E          |_ Randomly pick a number from 0 to 10 (or is it 0 to 9)
        MVII    #$VAR8_CART_COUNTER, R3         ; 7343   02BB 015F               |  and set VAR8_CART_COUNTER to that slot.
        MVO@    R0,     R3                      ; 7345   0258                   -'
        PULR    R7                              ; 7346   02B7                   Return from routine

INCR_VAR8_CART_COUNTER:
        MVII    #VAR8_CART_COUNTER, R3          ; 7347   02BB 015F              -.
        MVI@    R3,     R4                      ; 7349   029C                    |_ Increment VAR8_CART_COUNTER
        INCR    R4                              ; 734A   000C                    |  Note: incremented value left in R4
        MVO@    R4,     R3                      ; 734B   025C                   -'  
        MOVR    R5,     R7                      ; 734C   00AF                   Return from routine

WAIT_FOR_ISR_TICKS:                             ;                               Input: ticks to countdown is DECLE that follows JSR instruction.
        PSHR    R3                              ; 734D   0273                   Push R3 to the stack
        MVI@    R5,     R0                      ; 734E   02A8                   -.
        SDBD                                    ; 734F   0001                    |_ Store value after JSR in VAR16_ISR_WAIT_TICKS
        MVII    #$VAR16_ISR_WAIT_TICKS, R3      ; 7350   02BB 0018 0003          |
        MVO@    R0,     R3                      ; 7353   0258                   -'
@@wait_for_0318_zero:
        EIS                                     ; 7354   0002                   -.
        NOP                                     ; 7355   0034                    |
        NOP                                     ; 7356   0034                    |
        NOP                                     ; 7357   0034                    |_ Wait for MAIN_ISR to count down the requested ticks
        NOP                                     ; 7358   0034                    |
        MVI@    R3,     R0                      ; 7359   0298                    |
        TSTR    R0                              ; 735A   0080                    |
        BPL     @@wait_for_0318_zero            ; 735B   0223 0008              -'
        PULR    R3                              ; 735D   02B3                   Pop R3 from the stack
        MOVR    R5,     R7                      ; 735E   00AF                   Return from routine

; Start of UDB (Universal Data Base)
        BIDECLE $0000                           ; 735F                          Ptr: MOB graphic images
        BIDECLE $0000                           ; 7361                          Ptr: EXEC timer table
        BIDECLE $0000                           ; 7363                          Ptr: Start of game
        BIDECLE $GRAM_CARDS                     ; 7365                          Ptr: Backgnd gfx list ($762E)
        BIDECLE $0000                           ; 7367                          Ptr: GRAM init sequence
        BIDECLE $0000                           ; 7369                          Ptr: Date/Title
        DECLE   $0000                           ; 736B                          Key-click / flags
        DECLE   $0000                           ; 736C                          Border extension
        DECLE   $0000                           ; 736D                          Color Stack / FGBG
        DECLE   $0000,  $0000                   ; 736E                          Color Stack init (0, 1)
        DECLE   $0000,  $0000                   ; 7370                          Color Stack init (2, 3)
        DECLE   $0000                           ; 7373                          Border color init
UDB_PLUS_X14:                                                               
        DECLE   $0000,  $0000,  $0000,  $0000   ; 7373   0000 0000 0000 0000    -._ Reserved GRAM space for MOBs (i.e. none),
        DECLE   $0000,  $0000,  $0000,  $0000   ; 7377   0000 0000 0000 0000    -'  same format as cartridge header at $5014

GRAM_INIT_DEST:
        DECLE   $0040                           ; 737B   0040                   Number of GRAM cards to init (64)
        DECLE   $0001,  $0380                   ; 737C   0001 0380              #00-07:  CART #00-07 ----
        DECLE   $0011,  $0380                   ; 737E   0011 0380              #08-0F:  CART #08-0F ----
        DECLE   $0021,  $0380                   ; 7380   0021 0380              #10-17:  CART #10-17 ----
        DECLE   $0031,  $0280                   ; 7382   0031 0280              #18-1D:  CART #18-1D ----
        DECLE   $0011,  $0022                   ; 7384   0011 0022              #1E   :  Algo #1        
        DECLE   $0071,  $0006                   ; 7386   0071 0006              #1F   :  4x4 tile
        DECLE   $0229,  $0380                   ; 7388   0229 0380              #20-27:  CART #14-1B X---
        DECLE   $0239,  $0080                   ; 738A   0239 0080              #28-29:  CART #1C-1D X---
        DECLE   $0113,  $0380                   ; 738C   0113 0380              #30-31:  CART #09-10 -Y--
        DECLE   $0123,  $0280                   ; 738E   0123 0280              #32-37:  CART #11-16 -Y--
        DECLE   $0308                           ; 7390   0308                   #38   :  CART #04    XY--
        DECLE   $0334                           ; 7391   0334                   #39   :  CART #1A    XY--
        DECLE   $032C                           ; 7392   032C                   #3A   :  CART #16    XY--
        DECLE   $030A                           ; 7393   030A                   #3B   :  CART #05    XY--
        DECLE   $032A                           ; 7394   032A                   #3C   :  CART #15    XY--
        DECLE   $002A                           ; 7395   002A                   #3D   :  CART #15    ----
        DECLE   $0310                           ; 7396   0310                   #3E   :  CART #08    XY--
        DECLE   $030E                           ; 7397   030E                   #3F   :  CART #07    XY--
        
PLAY_TUNE:
        PSHR    R5                              ; 7398   0275                   Push return address to stack
        JSR     R5,     X_PLAY_MUS3             ; 7399   0004 0118 0395         -.
        DECLE   $0184                           ; 739C  Note (short)             |
        DECLE   $01B4                           ; 739D  Note (short)             |
        DECLE   $0204                           ; 739E  Note (short)             |
        DECLE   $0240                           ; 739F  Note (short)             |
        DECLE   $0008                           ; 73A0  Note (short)             |
        DECLE   $0280                           ; 73A1  Note (short)             |- Play some music
        DECLE   $0008                           ; 73A2  Note (short)             |
        DECLE   $02B0                           ; 73A3  Note (short)             |
        DECLE   $01C0                           ; 73A4  Note (short)             |
        DECLE   $01F8                           ; 73A5  Note (short)             |
        DECLE   $0302                           ; 73A6  Note (short)             |
        DECLE   $0000                           ; 73A7  End of music            -'
        PULR    R7                              ; 73A8   02B7                   Return from routine

; DEAD CODE?  Note there is no PULR R7 at the end... because it isn't needed.
        PSHR    R5                              ; 73A9   0275                   Push return address to stack
        JSR     R5,     X_PLAY_SFX1             ; 73AA   0004 0118 03BB         -.
        DECLE   $0389                           ; 73AD  SFX data                 |
        DECLE   $0280,  $0200                   ; 73AE  SFX data                 |
        DECLE   $0288,  $0180                   ; 73B0  SFX data                 |
        DECLE   $0284,  $0080                   ; 73B2  SFX data                 |
        DECLE   $0001,  $0300                   ; 73B4  SFX data                 |
        DECLE   $0001,  $0382                   ; 73B6  SFX data                 |- Play a sound effect.
        DECLE   $0001,  $0081                   ; 73B8  SFX data                 |  It executes a "PULR R7" as a return.
        DECLE   $008E                           ; 73BA  SFX data                 |
        DECLE   $00EB                           ; 73BB  SFX data                 |
        DECLE   $0001,  $0003                   ; 73BC  SFX data                 |
        DECLE   $03EE                           ; 73BE  SFX data                 |
        DECLE   $008F,  $001F                   ; 73BF  SFX data                 |
        DECLE   $02CF                           ; 73C1  SFX end                 -'

CHAR_TO_GRAM_INDEX_TABLE:                       ; This table is used to get the 4 GRAM indices for each upper-case alphabetic or space character.
                                                ; It is marked as UL = upper-left, UR = upper-right, LL = lower-left, and LR = lower-right
                                                ;         UL   UR   LL   LR
        DECLE   $0100,  $0100,  $0100,  $0100   ; 73C2   0100 0100 0100 0100    Space
        DECLE   $0019,  $0025,  $001B,  $0027   ; 73C6   0019 0025 001B 0027    A
        DECLE   $0010,  $0011,  $0031,  $0032   ; 73CA   0010 0011 0031 0032    B
        DECLE   $0016,  $0009,  $0037,  $002A   ; 73CE   0016 0009 0037 002A    C
        DECLE   $000A,  $0022,  $002B,  $003A   ; 73D2   000A 0022 002B 003A    D
        DECLE   $0010,  $000B,  $0031,  $002C   ; 73D6   0010 000B 0031 002C    E
        DECLE   $0010,  $000B,  $0015,  $001F   ; 73DA   0010 000B 0015 001F    F
        DECLE   $0016,  $0009,  $0037,  $0000   ; 73DE   0016 0009 0037 0000    G
        DECLE   $0036,  $003C,  $003D,  $0021   ; 73E2   0036 003C 003D 0021    H
        DECLE   $000C,  $000D,  $002D,  $002E   ; 73E6   000C 000D 002D 002E    I
        DECLE   $0100,  $0017,  $0037,  $003A   ; 73EA   0100 0017 0037 003A    J
        DECLE   $000E,  $000F,  $002F,  $0030   ; 73EE   000E 000F 002F 0030    K
        DECLE   $0023,  $0100,  $002B,  $0001   ; 73F2   0023 0100 002B 0001    L
        DECLE   $0020,  $0014,  $001A,  $0026   ; 73F6   0020 0014 001A 0026    M
        DECLE   $0020,  $0039,  $001A,  $0035   ; 73FA   0020 0039 001A 0035    N
        DECLE   $0016,  $0022,  $0037,  $003A   ; 73FE   0016 0022 0037 003A    O
        DECLE   $0010,  $0011,  $0015,  $001F   ; 7402   0010 0011 0015 001F    P
        DECLE   $0016,  $0022,  $0037,  $0002   ; 7406   0016 0022 0037 0002    Q
        DECLE   $0010,  $0011,  $0015,  $0003   ; 740A   0010 0011 0015 0003    R
        DECLE   $0004,  $003B,  $0005,  $0038   ; 740E   0004 003B 0005 0038    S
        DECLE   $000C,  $000D,  $0006,  $001E   ; 7412   000C 000D 0006 001E    T
        DECLE   $0023,  $0017,  $0037,  $003A   ; 7416   0023 0017 0037 003A    U
        DECLE   $001C,  $0028,  $001D,  $0029   ; 741A   001C 0028 001D 0029    V
        DECLE   $0023,  $0017,  $0018,  $0024   ; 741E   0023 0017 0018 0024    W
        DECLE   $0012,  $0013,  $0033,  $0034   ; 7422   0012 0013 0033 0034    X
        DECLE   $0012,  $0013,  $0006,  $001E   ; 7426   0012 0013 0006 001E    Y
        DECLE   $0007,  $0008,  $003E,  $003F   ; 742A   0007 0008 003E 003F    Z
        
DISPLAY_ATTRACT_SEARS:
        MVII    #$00F0, R0                      ; 742E   02B8 00F0              -.
        MVII    #$0200, R4                      ; 7430   02BC 0200               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7432   0004 0114 0338         -'
        MVII    #$0005, R3                      ; 7435   02BB 0005              Set color to Green
        MVII    #$0250, R4                      ; 7437   02BC 0250              -.
        JSR     R5,     X_PRINT_R5              ; 7439   0004 0118 007B          |_ Display the string starting at
        STRING  "    This is the     "          ; 743C                           |  Row 4, Column 0
        DECLE   $0000                           ; 7450   0000                   -'
        ADDI    #$0028, R4                      ; 7451   02FC 0028              -.
        JSR     R5,     X_PRINT_R5              ; 7453   0004 0118 007B          |_ Display the string starting at
        STRING  " SUPER VIDEO ARCADE "          ; 7456                           |  Row 7, Column 0
        DECLE   $0000                           ; 746A   0000                   -'
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 746B   0004 0170 034D         -._ Wait 300 ticks (5 seconds on NTSC)
        DECLE   $012C                           ; 746E   012C                   -'
        MVII    #$0200, R4                      ; 746F   02BC 0200              -.
        MVII    #$00F0, R0                      ; 7471   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7473   0004 0114 0338         -'
        MVII    #$0250, R4                      ; 7476   02BC 0250              -.
        JSR     R5,     X_PRINT_R5              ; 7478   0004 0118 007B          |_ Display the string starting at
        STRING  "  Our Most Advanced "          ; 747B                           |  Row 4, Column 0
        DECLE   $0000                           ; 748F   0000                   -'
        ADDI    #$0028, R4                      ; 7490   02FC 0028              -.
        JSR     R5,     X_PRINT_R5              ; 7492   0004 0118 007B          |_ Display the string starting at
        STRING  "  Video Game System "          ; 7495                           |  Row 7, Column 0
        DECLE   $0000                           ; 74A9   0000                   -'
        B       DISPLAY_ATTRACT_END             ; 74AA   0200 00DE              Go to the ending of the attract mode

DISPLAY_ATTRACT_MATTEL:
        MVII    #$00F0, R0                      ; 74AC   02B8 00F0              -.
        MVII    #$0200, R4                      ; 74AE   02BC 0200               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 74B0   0004 0114 0338         -'
        MVO     R0,     .BTAB.00                ; 74B3   0240 0200              Bug?  Write $00F0 (black '>') to 1st Backtab location?
        MVII    #$0005, R3                      ; 74B5   02BB 0005              Set color to Green
        MVII    #$023C, R4                      ; 74B7   02BC 023C              -.
        JSR     R5,     X_PRINT_R5              ; 74B9   0004 0118 007B          |  
        STRING  "       Welcome      "          ; 74BC                           |_ Display the string starting at
        STRING  "                    "          ; 74D0                           |  Row 3, Column 0
        STRING  "         to         "          ; 74E4                           |
        DECLE   $0000                           ; 74F8   0000                   -'
        ADDI    #$0028, R4                      ; 74F9   02FC 0028              -.
        JSR     R5,     X_PRINT_R5              ; 74FB   0004 0118 007B          |_ Display the string starting at
        STRING  "    INTELLIVISION   "          ; 74FE                           |  Row 8, Column 0
        DECLE   $0000                           ; 7512   0000                   -'
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 7513   0004 0170 034D         -._ Wait 300 ticks (5 seconds on NTSC)
        DECLE   $012C                           ; 7516   012C                   -'
        MVII    #$0200, R4                      ; 7517   02BC 0200              -.
        MVII    #$00F0, R0                      ; 7519   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 751B   0004 0114 0338         -'
        MVII    #$023C, R4                      ; 751E   02BC 023C              -.
        JSR     R5,     X_PRINT_R5              ; 7520   0004 0118 007B          |  
        STRING  "     The World's    "          ; 7523                           |
        STRING  "                    "          ; 7537                           |_ Display the string starting at
        STRING  "    Most Exciting   "          ; 754B                           |  Row 3, Column 0
        STRING  "                    "          ; 755F                           |
        STRING  "  Video Game System "          ; 7573                           |
        DECLE   $0000                           ; 7587   0000                   -'
        B       DISPLAY_ATTRACT_END             ; 7588   0200 0000              Go to the ending of the attract mode

DISPLAY_ATTRACT_END:
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 758A   0004 0170 034D         -._ Wait 300 ticks (5 seconds on NTSC)
        DECLE   $012C                           ; 758D   012C                   -'
        MVII    #$0200, R4                      ; 758E   02BC 0200              -.
        MVII    #$00F0, R0                      ; 7590   02B8 00F0               |- Set Backtab to solid black.
        JSR     R5,     X_FILL_ZERO             ; 7592   0004 0114 0338         -'
        MVII    #$0228, R4                      ; 7595   02BC 0228              -.
        JSR     R5,     X_PRINT_R5              ; 7597   0004 0118 007B          |  
        STRING  "     Experience     "          ; 759A                           |
        STRING  "                    "          ; 75AE                           |
        STRING  "    the thrill of   "          ; 75C2                           |_ Display the string starting at
        STRING  "                    "          ; 75D6                           |  Row 2, Column 0
        STRING  "      REAL-LIFE     "          ; 75EA                           |
        STRING  "                    "          ; 75FE                           |
        STRING  "    Video Action    "          ; 7612                           |
        DECLE   $0000                           ; 7626   0000                   -'
        JSR     R5,     WAIT_FOR_ISR_TICKS      ; 7627   0004 0170 034D         -._ Wait 300 ticks (5 seconds on NTSC)
        DECLE   $012C                           ; 762A   012C                   -'
        J       X_RESET                         ; 762B   0004 0310 0000         Reset the whole system

GRAM_CARDS:                                     ;                               These are the cartridge's version of these card
                                                ;                               which are flip different ways before copying into GRAM.
                                                ;
                                                ;                               Cart card $00
        DECLE   $007C                           ; 762E   007C                   ' XXXXX  '
        DECLE   $007C                           ; 762F   007C                   ' XXXXX  '
        DECLE   $001C                           ; 7630   001C                   '   XXX  '
        DECLE   $001C                           ; 7631   001C                   '   XXX  '
        DECLE   $003C                           ; 7632   003C                   '  XXXX  '
        DECLE   $00F8                           ; 7633   00F8                   'XXXXX   '
        DECLE   $00E0                           ; 7634   00E0                   'XXX     '
        DECLE   $0000                           ; 7635   0000                   '        '
        
                                                ;                               Cart card $01
        DECLE   $0000                           ; 7636   0000                   '        '
        DECLE   $0000                           ; 7637   0000                   '        '
        DECLE   $0000                           ; 7638   0000                   '        '
        DECLE   $0000                           ; 7639   0000                   '        '
        DECLE   $0000                           ; 763A   0000                   '        '
        DECLE   $00FC                           ; 763B   00FC                   'XXXXXX  '
        DECLE   $00FC                           ; 763C   00FC                   'XXXXXX  '
        DECLE   $0000                           ; 763D   0000                   '        '
        
                                                ;                               Cart card $02
        DECLE   $001C                           ; 763E   001C                   '   XXX  '
        DECLE   $001C                           ; 763F   001C                   '   XXX  '
        DECLE   $00DC                           ; 7640   00DC                   'XX XXX  '
        DECLE   $00F8                           ; 7641   00F8                   'XXXXX   '
        DECLE   $0078                           ; 7642   0078                   ' XXXX   '
        DECLE   $00FC                           ; 7643   00FC                   'XXXXXX  '
        DECLE   $00CC                           ; 7644   00CC                   'XX  XX  '
        DECLE   $0000                           ; 7645   0000                   '        '
        
                                                ;                               Cart card $03
        DECLE   $00F0                           ; 7646   00F0                   'XXXX    '
        DECLE   $00E0                           ; 7647   00E0                   'XXX     '
        DECLE   $0070                           ; 7648   0070                   ' XXX    '
        DECLE   $0038                           ; 7649   0038                   '  XXX   '
        DECLE   $0038                           ; 764A   0038                   '  XXX   '
        DECLE   $001C                           ; 764B   001C                   '   XXX  '
        DECLE   $001C                           ; 764C   001C                   '   XXX  '
        DECLE   $0000                           ; 764D   0000                   '        '
        
                                                ;                               Cart card $04
        DECLE   $0000                           ; 764E   0000                   '        '
        DECLE   $0007                           ; 764F   0007                   '     XXX'
        DECLE   $001F                           ; 7650   001F                   '   XXXXX'
        DECLE   $003C                           ; 7651   003C                   '  XXXX  '
        DECLE   $0038                           ; 7652   0038                   '  XXX   '
        DECLE   $0038                           ; 7653   0038                   '  XXX   '
        DECLE   $003C                           ; 7654   003C                   '  XXXX  '
        DECLE   $001F                           ; 7655   001F                   '   XXXXX'
        
                                                ;                               Cart card $05
        DECLE   $0007                           ; 7656   0007                   '     XXX'
        DECLE   $0000                           ; 7657   0000                   '        '
        DECLE   $0000                           ; 7658   0000                   '        '
        DECLE   $0038                           ; 7659   0038                   '  XXX   '
        DECLE   $003C                           ; 765A   003C                   '  XXXX  '
        DECLE   $001F                           ; 765B   001F                   '   XXXXX'
        DECLE   $0007                           ; 765C   0007                   '     XXX'
        DECLE   $0000                           ; 765D   0000                   '        '
        
                                                ;                               Cart card $06
        DECLE   $0003                           ; 765E   0003                   '      XX'
        DECLE   $0003                           ; 765F   0003                   '      XX'
        DECLE   $0003                           ; 7660   0003                   '      XX'
        DECLE   $0003                           ; 7661   0003                   '      XX'
        DECLE   $0003                           ; 7662   0003                   '      XX'
        DECLE   $0003                           ; 7663   0003                   '      XX'
        DECLE   $0003                           ; 7664   0003                   '      XX'
        DECLE   $0000                           ; 7665   0000                   '        '
        
                                                ;                               Cart card $07
        DECLE   $0000                           ; 7666   0000                   '        '
        DECLE   $003F                           ; 7667   003F                   '  XXXXXX'
        DECLE   $003F                           ; 7668   003F                   '  XXXXXX'
        DECLE   $0038                           ; 7669   0038                   '  XXX   '
        DECLE   $0000                           ; 766A   0000                   '        '
        DECLE   $0000                           ; 766B   0000                   '        '
        DECLE   $0001                           ; 766C   0001                   '       X'
        DECLE   $0003                           ; 766D   0003                   '      XX'
        
                                                ;                               Cart card $08
        DECLE   $0000                           ; 766E   0000                   '        '
        DECLE   $00FC                           ; 766F   00FC                   'XXXXXX  '
        DECLE   $00FC                           ; 7670   00FC                   'XXXXXX  '
        DECLE   $003C                           ; 7671   003C                   '  XXXX  '
        DECLE   $007C                           ; 7672   007C                   ' XXXXX  '
        DECLE   $00F8                           ; 7673   00F8                   'XXXXX   '
        DECLE   $00F0                           ; 7674   00F0                   'XXXX    '
        DECLE   $00E0                           ; 7675   00E0                   'XXX     '
        
                                                ;                               Cart card $09
        DECLE   $0000                           ; 7676   0000                   '        '
        DECLE   $00E0                           ; 7677   00E0                   'XXX     '
        DECLE   $00F8                           ; 7678   00F8                   'XXXXX   '
        DECLE   $003C                           ; 7679   003C                   '  XXXX  '
        DECLE   $001C                           ; 767A   001C                   '   XXX  '
        DECLE   $0000                           ; 767B   0000                   '        '
        DECLE   $0000                           ; 767C   0000                   '        '
        DECLE   $0000                           ; 767D   0000                   '        '
        
                                                ;                               Cart card $0A
        DECLE   $0000                           ; 767E   0000                   '        '
        DECLE   $003F                           ; 767F   003F                   '  XXXXXX'
        DECLE   $003F                           ; 7680   003F                   '  XXXXXX'
        DECLE   $0038                           ; 7681   0038                   '  XXX   '
        DECLE   $0038                           ; 7682   0038                   '  XXX   '
        DECLE   $0038                           ; 7683   0038                   '  XXX   '
        DECLE   $0038                           ; 7684   0038                   '  XXX   '
        DECLE   $0038                           ; 7685   0038                   '  XXX   '
        
                                                ;                               Cart card $0B
        DECLE   $0000                           ; 7686   0000                   '        '
        DECLE   $00FC                           ; 7687   00FC                   'XXXXXX  '
        DECLE   $00FC                           ; 7688   00FC                   'XXXXXX  '
        DECLE   $0000                           ; 7689   0000                   '        '
        DECLE   $0000                           ; 768A   0000                   '        '
        DECLE   $0000                           ; 768B   0000                   '        '
        DECLE   $0000                           ; 768C   0000                   '        '
        DECLE   $00E0                           ; 768D   00E0                   'XXX     '
        
                                                ;                               Cart card $0C
        DECLE   $0000                           ; 768E   0000                   '        '
        DECLE   $003F                           ; 768F   003F                   '  XXXXXX'
        DECLE   $003F                           ; 7690   003F                   '  XXXXXX'
        DECLE   $0003                           ; 7691   0003                   '      XX'
        DECLE   $0003                           ; 7692   0003                   '      XX'
        DECLE   $0003                           ; 7693   0003                   '      XX'
        DECLE   $0003                           ; 7694   0003                   '      XX'
        DECLE   $0003                           ; 7695   0003                   '      XX'
        
                                                ;                               Cart card $0D
        DECLE   $0000                           ; 7696   0000                   '        '
        DECLE   $00F8                           ; 7697   00F8                   'XXXXX   '
        DECLE   $00F8                           ; 7698   00F8                   'XXXXX   '
        DECLE   $0080                           ; 7699   0080                   'X       '
        DECLE   $0080                           ; 769A   0080                   'X       '
        DECLE   $0080                           ; 769B   0080                   'X       '
        DECLE   $0080                           ; 769C   0080                   'X       '
        DECLE   $0080                           ; 769D   0080                   'X       '
        
                                                ;                               Cart card $0E
        DECLE   $0000                           ; 769E   0000                   '        '
        DECLE   $0038                           ; 769F   0038                   '  XXX   '
        DECLE   $0038                           ; 76A0   0038                   '  XXX   '
        DECLE   $0038                           ; 76A1   0038                   '  XXX   '
        DECLE   $0038                           ; 76A2   0038                   '  XXX   '
        DECLE   $0039                           ; 76A3   0039                   '  XXX  X'
        DECLE   $003B                           ; 76A4   003B                   '  XXX XX'
        DECLE   $003F                           ; 76A5   003F                   '  XXXXXX'
        
                                                ;                               Cart card $0F
        DECLE   $0000                           ; 76A6   0000                   '        '
        DECLE   $001C                           ; 76A7   001C                   '   XXX  '
        DECLE   $003C                           ; 76A8   003C                   '  XXXX  '
        DECLE   $0078                           ; 76A9   0078                   ' XXXX   '
        DECLE   $00F0                           ; 76AA   00F0                   'XXXX    '
        DECLE   $00E0                           ; 76AB   00E0                   'XXX     '
        DECLE   $00C0                           ; 76AC   00C0                   'XX      '
        DECLE   $0080                           ; 76AD   0080                   'X       '
        
                                                ;                               Cart card $10
        DECLE   $0000                           ; 76AE   0000                   '        '
        DECLE   $003F                           ; 76AF   003F                   '  XXXXXX'
        DECLE   $003F                           ; 76B0   003F                   '  XXXXXX'
        DECLE   $0038                           ; 76B1   0038                   '  XXX   '
        DECLE   $0038                           ; 76B2   0038                   '  XXX   '
        DECLE   $0038                           ; 76B3   0038                   '  XXX   '
        DECLE   $0038                           ; 76B4   0038                   '  XXX   '
        DECLE   $003F                           ; 76B5   003F                   '  XXXXXX'
        
                                                ;                               Cart card $11
        DECLE   $0000                           ; 76B6   0000                   '        '
        DECLE   $00F0                           ; 76B7   00F0                   'XXXX    '
        DECLE   $00F8                           ; 76B8   00F8                   'XXXXX   '
        DECLE   $003C                           ; 76B9   003C                   '  XXXX  '
        DECLE   $001C                           ; 76BA   001C                   '   XXX  '
        DECLE   $001C                           ; 76BB   001C                   '   XXX  '
        DECLE   $003C                           ; 76BC   003C                   '  XXXX  '
        DECLE   $00F8                           ; 76BD   00F8                   'XXXXX   '
        
                                                ;                               Cart card $12
        DECLE   $0000                           ; 76BE   0000                   '        '
        DECLE   $0038                           ; 76BF   0038                   '  XXX   '
        DECLE   $0038                           ; 76C0   0038                   '  XXX   '
        DECLE   $0038                           ; 76C1   0038                   '  XXX   '
        DECLE   $003C                           ; 76C2   003C                   '  XXXX  '
        DECLE   $001E                           ; 76C3   001E                   '   XXXX '
        DECLE   $000F                           ; 76C4   000F                   '    XXXX'
        DECLE   $0007                           ; 76C5   0007                   '     XXX'
        
                                                ;                               Cart card $13
        DECLE   $0000                           ; 76C6   0000                   '        '
        DECLE   $0038                           ; 76C7   0038                   '  XXX   '
        DECLE   $0038                           ; 76C8   0038                   '  XXX   '
        DECLE   $0038                           ; 76C9   0038                   '  XXX   '
        DECLE   $0078                           ; 76CA   0078                   ' XXXX   '
        DECLE   $00F0                           ; 76CB   00F0                   'XXXX    '
        DECLE   $00E0                           ; 76CC   00E0                   'XXX     '
        DECLE   $00C0                           ; 76CD   00C0                   'XX      '
        
                                                ;                               Cart card $14
        DECLE   $0000                           ; 76CE   0000                   '        '
        DECLE   $001C                           ; 76CF   001C                   '   XXX  '
        DECLE   $003C                           ; 76D0   003C                   '  XXXX  '
        DECLE   $007C                           ; 76D1   007C                   ' XXXXX  '
        DECLE   $007C                           ; 76D2   007C                   ' XXXXX  '
        DECLE   $00FC                           ; 76D3   00FC                   'XXXXXX  '
        DECLE   $00FC                           ; 76D4   00FC                   'XXXXXX  '
        DECLE   $00DC                           ; 76D5   00DC                   'XX XXX  '
        
                                                ;                               Cart card $15
        DECLE   $003F                           ; 76D6   003F                   '  XXXXXX'
        DECLE   $0038                           ; 76D7   0038                   '  XXX   '
        DECLE   $0038                           ; 76D8   0038                   '  XXX   '
        DECLE   $0038                           ; 76D9   0038                   '  XXX   '
        DECLE   $0038                           ; 76DA   0038                   '  XXX   '
        DECLE   $0038                           ; 76DB   0038                   '  XXX   '
        DECLE   $0038                           ; 76DC   0038                   '  XXX   '
        DECLE   $0000                           ; 76DD   0000                   '        '
        
                                                ;                               Cart card $16
        DECLE   $0000                           ; 76DE   0000                   '        '
        DECLE   $0003                           ; 76DF   0003                   '      XX'
        DECLE   $000F                           ; 76E0   000F                   '    XXXX'
        DECLE   $001E                           ; 76E1   001E                   '   XXXX '
        DECLE   $001C                           ; 76E2   001C                   '   XXX  '
        DECLE   $0038                           ; 76E3   0038                   '  XXX   '
        DECLE   $0038                           ; 76E4   0038                   '  XXX   '
        DECLE   $0038                           ; 76E5   0038                   '  XXX   '
        
                                                ;                               Cart card $17
        DECLE   $0000                           ; 76E6   0000                   '        '
        DECLE   $001C                           ; 76E7   001C                   '   XXX  '
        DECLE   $001C                           ; 76E8   001C                   '   XXX  '
        DECLE   $001C                           ; 76E9   001C                   '   XXX  '
        DECLE   $001C                           ; 76EA   001C                   '   XXX  '
        DECLE   $001C                           ; 76EB   001C                   '   XXX  '
        DECLE   $001C                           ; 76EC   001C                   '   XXX  '
        DECLE   $001C                           ; 76ED   001C                   '   XXX  '
        
                                                ;                               Cart card $18
        DECLE   $0039                           ; 76EE   0039                   '  XXX  X'
        DECLE   $0039                           ; 76EF   0039                   '  XXX  X'
        DECLE   $003B                           ; 76F0   003B                   '  XXX XX'
        DECLE   $003F                           ; 76F1   003F                   '  XXXXXX'
        DECLE   $001F                           ; 76F2   001F                   '   XXXXX'
        DECLE   $001E                           ; 76F3   001E                   '   XXXX '
        DECLE   $000C                           ; 76F4   000C                   '    XX  '
        DECLE   $0000                           ; 76F5   0000                   '        '
        
                                                ;                               Cart card $19
        DECLE   $0000                           ; 76F6   0000                   '        '
        DECLE   $0007                           ; 76F7   0007                   '     XXX'
        DECLE   $000F                           ; 76F8   000F                   '    XXXX'
        DECLE   $000E                           ; 76F9   000E                   '    XXX '
        DECLE   $001C                           ; 76FA   001C                   '   XXX  '
        DECLE   $001C                           ; 76FB   001C                   '   XXX  '
        DECLE   $0038                           ; 76FC   0038                   '  XXX   '
        DECLE   $0038                           ; 76FD   0038                   '  XXX   '
        
                                                ;                               Cart card $1A
        DECLE   $0039                           ; 76FE   0039                   '  XXX  X'
        DECLE   $0039                           ; 76FF   0039                   '  XXX  X'
        DECLE   $0038                           ; 7700   0038                   '  XXX   '
        DECLE   $0038                           ; 7701   0038                   '  XXX   '
        DECLE   $0038                           ; 7702   0038                   '  XXX   '
        DECLE   $0038                           ; 7703   0038                   '  XXX   '
        DECLE   $0038                           ; 7704   0038                   '  XXX   '
        DECLE   $0000                           ; 7705   0000                   '        '
        
                                                ;                               Cart card $1B
        DECLE   $0038                           ; 7706   0038                   '  XXX   '
        DECLE   $003F                           ; 7707   003F                   '  XXXXXX'
        DECLE   $003F                           ; 7708   003F                   '  XXXXXX'
        DECLE   $0038                           ; 7709   0038                   '  XXX   '
        DECLE   $0038                           ; 770A   0038                   '  XXX   '
        DECLE   $0038                           ; 770B   0038                   '  XXX   '
        DECLE   $0038                           ; 770C   0038                   '  XXX   '
        DECLE   $0000                           ; 770D   0000                   '        '
        
                                                ;                               Cart card $1C
        DECLE   $0000                           ; 770E   0000                   '        '
        DECLE   $0038                           ; 770F   0038                   '  XXX   '
        DECLE   $0038                           ; 7710   0038                   '  XXX   '
        DECLE   $0038                           ; 7711   0038                   '  XXX   '
        DECLE   $0038                           ; 7712   0038                   '  XXX   '
        DECLE   $001C                           ; 7713   001C                   '   XXX  '
        DECLE   $001C                           ; 7714   001C                   '   XXX  '
        DECLE   $000E                           ; 7715   000E                   '    XXX '
        
                                                ;                               Cart card $1D
        DECLE   $000E                           ; 770E   000E                   '    XXX '
        DECLE   $0007                           ; 770F   0007                   '     XXX'
        DECLE   $0007                           ; 7710   0007                   '     XXX'
        DECLE   $0003                           ; 7711   0003                   '      XX'
        DECLE   $0003                           ; 7712   0003                   '      XX'
        DECLE   $0001                           ; 7713   0001                   '       X'
        DECLE   $0001                           ; 7714   0001                   '       X'
        DECLE   $0000                           ; 7715   0000                   '        '
; end of GRAM_CARDS     
   
        DECLE   $FFFF                           ; 771E   FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 771F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7723   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7727   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 772B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 772F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7733   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7737   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 773B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 773F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7743   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7747   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 774B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 774F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7753   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7757   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 775B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 775F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7763   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7767   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 776B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 776F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7773   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7777   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 777B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 777F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7783   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7787   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 778B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 778F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7793   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 7797   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 779B   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 779F   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77A3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77A7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77AB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77AF   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77B3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77B7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77BB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77BF   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77C3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77C7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77CB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77CF   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77D3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77D7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77DB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77DF   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77E3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77E7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77EB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77EF   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77F3   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77F7   FFFF FFFF FFFF FFFF
        DECLE   $FFFF,  $FFFF,  $FFFF,  $FFFF   ; 77FB   FFFF FFFF FFFF FFFF
        DECLE   $FFFF                           ; 77FF   FFFF
;; ======================================================================== ;;
;;  Branch cross-reference
;; ------------------------------------------------------------------------ ;;
;;  Target      Target of
;;  $700F       $700A  
;;  $7062       $7074   $7079  
;;  $707B       $706B  
;;  $7094       $7067   $7088  
;;  $70A0       $7090  
;;  $70A3       $7092  
;;  $70A6       $705C  
;;  $70D0       $70CC   $70DC  
;;  $70D7       $70C5  
;;  $7103       $70F4  
;;  $7108       $70FA  
;;  $710A       $705F  
;;  $7133       $7059   $7101  
;;  $713E       $7056  
;;  $715C       $700F   $7146  
;;  $716A       $716A  
;;  $7173       $711E  
;;  $7184       $719D  
;;  $718C       $7124  
;;  $71A0       $7134  
;;  $71A1       $71AE   $71BD  
;;  $71B0       $71A9  
;;  $71DE       $7137  
;;  $71EE       $71E8  
;;  $721C       $713A  
;;  $7232       $7189   $723A  
;;  $723D       $7232  
;;  $7251       $7254  
;;  $725A       $727E  
;;  $7266       $7263  
;;  $7280       $725D  
;;  $7282       $7229  
;;  $728E       $72A1   $72BD   $72CF  
;;  $729C       $7298  
;;  $72A3       $7294  
;;  $72BF       $7290   $729E  
;;  $72CA       $72E9  
;;  $72D1       $72CD  
;;  $72D3       $72C8  
;;  $72D9       $72DD  
;;  $72EF       $721E  
;;  $72F0       $72F8  
;;  $7319       $726C   $7270   $7274   $7279  
;;  $732A       $731E  
;;  $732C       $71A1  
;;  $7332       $707C   $71B0  
;;  $7338       $71AB  
;;  $7347       $71A4  
;;  $734D       $7129   $7155   $746B   $7513   $758A   $7627  
;;  $7354       $735B  
;;  $7398       $7126  
;;  $73EB       $73EB  
;;  $73F1       $73EF  
;;  $73F2       $73F0  
;;  $7417       $7417  
;;  $741F       $741F  
;;  $742E       $70A0  
;;  $74AC       $70A3  
;;  $758A       $74AA   $7588  
;;  $76E2       $76E0  
;;  $76FA       $76F8  
;; ======================================================================== ;;
