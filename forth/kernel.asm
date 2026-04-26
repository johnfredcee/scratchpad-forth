;;
;; We need to define a forth VM with registers that map onto the 386 register set
;;
;; W  - EDI - Pointer to code field of command currently being executed
;; IP - ESI - Instruction pointer
;; SP - EBP - Data stack pointer
;; RP - ESP - Return stack pointer
;; X  - ?
;; UP - ?
;; BASE - EBX -- Base addy of FORTH kernel

			[map symbols kernel.map]
		
			CPU 486 			; it's 1999
			ORG 0


;; offsets for dpmi structure
DPMI_EDI EQU 00h
DPMI_ESI EQU 04h
DPMI_EBP EQU 08h	
DPMI_XXX EQU 0Ch
DPMI_EBX EQU 10h
DPMI_EDX EQU 14h
DPMI_ECX EQU 18h
DPMI_EAX EQU 1Ch
DPMP_FL  EQU 20h
DPMI_ES  EQU 22h
DPMI_DS  EQU 24h
DPMI_FS  EQU 26h
DPMI_GS  EQU 28h
DPMI_IP  EQU 2Ah
DPMI_CS  EQU 2Ch
DPMI_SP  EQU 2Eh
DPMI_SS  EQU 30h

F_IMMEDIATE EQU 18h
F_HIDDEN    EQU 20H

			SECTION	KERNEL ALIGN=4 progbits
			BITS 32

			db "KSTART"

	;;; push to the data stack 
%macro      PUSHDSP 1
			LEA EBP,[EBP-4]
			MOV [EBP],%1
%endmacro

;;; pop from the data stack 
%macro      POPDSP 1
			MOV %1,[EBP]		
			LEA EBP,[EBP+4]
%endmacro

;;; inner interpteter - get next word, jump indirect
;;; (address pointed to by cw)
%macro		NEXTI 0
			MOV EDI,[ESI] 		; [IP] -> W
			ADD ESI,4			; IP + CELL
			JMP [EDI]			; W -> X JP (X)
%endmacro

;;; execute an xt on the data stack
%macro		EXECUTEI 0
			POPDSP 	 EDI		; POP PSP TO W 
			JMP		 [EDI]		; [W] JMP
%endmacro

docol_:		PUSH ESI 			; IP -> return stack
			MOV  ESI,EDI		; W + CELL -> IP
			ADD  ESI,4
			NEXTI				; Go!

doexit_:	POP ESI				; return stack -> IP
			NEXTI

;; constant interpreter
docon_:		ADD EDI,4			; get data field
			MOV EAX,[EDI]		; push constant to data stack
			PUSHDSP EAX			
			NEXTI			

;; variable interpreter
dovar_:		ADD EDI,4
			PUSHDSP EDI
			NEXTI

doexec_: 	MOV EDI,[EBP]    ; Get CFA
            LEA EBP,[EBP+4]  ; Pop data stack
            JMP [EDI]        ; Execute!

dobreak_: 	INT 3
			NEXTI

;; --- stack manipulation ---------------------------

;;; code for primitives
dup_:		MOV EAX,[EBP] 	; get tos
			LEA EBP,[EBP-4] ; push
			MOV [EBP], EAX	; write new tos
			NEXTI

;;; (x1 x2 --- x1 x2 x1 )
over_:		MOV EAX,[EBP+4]	; get 2os
			LEA EBP,[EBP-4]	; push
			MOV [EBP], EAX	; write new toss
			NEXTI

;; ( x -- )
drop_:		LEA EBP,[EBP+4] ; pop
			NEXTI

;; ( x1 x2 -- x2 x1 )
swap_:		MOV EAX,[EBP]		; get tos	
			MOV EDX,[EBP+4]		; get 2os
			MOV [EBP+4],EAX		; write new 2os
			MOV [EBP],EDX		; write now tos
			NEXTI	

;; --- memory access ---------------------------

fetch_:		MOV EAX,[EBP]		; EDX <- address to fetch
			MOV EAX,[EAX]		; EAX <- value at address
			MOV [EBP],EAX
			NEXTI

store_:		MOV EDX,[EBP]		; EDX <- address to store ad  
			MOV EAX,[EBP+4]		; EAX <- value to store
			MOV [EDX],EAX
			LEA EBP,[EBP+8]		; Pop 2
			NEXTI

fetchbyte_:	MOV EDX,[EBP]		; EDX <- address to fetch
			XOR EAX,EAX
			MOV AL,[EDX]		; EAX <- value at address
			MOV [EBP],EAX
			NEXTI

storebyte_:	MOV EDX,[EBP]		; EDX <- address to store ad  
			MOV EAX,[EBP+4]		; EAX <- value to store
			MOV [EDX],AL
			LEA EBP,[EBP+8]		; Pop 2
			NEXTI

;; --- artithmetic words ---------------------------

;; ( n1 -- n1 + 1 ) 1+
addone_:	INC [EBP]
			NEXTI

;; ( n1 -- n1 - 1 ) 1-
subone_:	DEC [EBP]
			NEXTI

;; ( n1 -- n1 + 4)
addfour_:	MOV EAX,[EBP]
			ADD EAX,4
			MOV [EBP],EAX
			NEXTI

;; ( n1 -- n1 - 4)
subfour_:	MOV EAX,[EBP]
			SUB EAX,4
			MOV [EBP],EAX
			NEXTI

;; ( n1 n2 -- n1 + n2 )
add_:		MOV EAX,[EBP]
			LEA EBP,[EBP+4]
			ADD [EBP],EAX
			NEXTI
;; ( n1 n2 -- n1 - n2 )	
sub_:		MOV EAX,[EBP]
			LEA EBP,[EBP+4]
			SUB [EBP],EAX
			NEXTI

;; ( n1 n2 -- n1*n2 )	
mul_:		MOV EAX,[EBP]
			MOV EDX,[EBP+4]
			IMUL EAX,EDX
			LEA EBP,[EBP+4]
			MOV [EBP], EAX
			NEXTI

divmod_:	XOR EDX,EDX
			MOV ECX,[EBP]
			MOV EAX,[EBP+4]
			IDIV ECX
			MOV [EBP+4],EDX
			MOV [EBP],EAX
			NEXTI

zeroeq_:    MOV EAX,[EBP]
			TEST EAX,EAX
			SETZ AL
			MOVZX EAX,AL
			MOV [EBP],EAX
			NEXTI 

eq_:        MOV EAX,[EBP]
			CMP EAX,[EBP+4]
			SETE AL
			MOVZX EAX,AL
			LEA EBP,[EBP+4]
			MOV [EBP], EAX
			NEXTI

ge_:  		MOV EAX,[EBP]
			CMP EAX,[EBP+4]
			SETG AL
			MOVZX EAX,AL
			LEA EBP,[EBP+4]
			MOV [EBP], EAX
			NEXTI

lt_:		MOV EAX,[EBP]
			CMP EAX,[EBP+4]
			SETL AL
			MOVZX EAX,AL
			LEA EBP,[EBP+4]
			MOV [EBP], EAX
			NEXTI

and_:		MOV EAX,[EBP]
			AND [EBP+4],EAX
			LEA EBP,[EBP+4]
			NEXTI

or_:		MOV EAX,[EBP]
			OR  [EBP+4],EAX
			LEA EBP,[EBP+4]
			NEXTI

xor_:		MOV EAX,[EBP]
			XOR [EBP+4],EAX
			LEA EBP,[EBP+4]
			NEXTI
		
invert_:	NOT [EBP]	
			NEXTI

;; --- return stack manipulation ---------------------------

; move value from param stack to return stack
tors_:		MOV EAX,[EBP]
			PUSH EAX
			LEA EBP,[EBP-4]
			NEXTI

; move value from return stack to param stack
fromrs_:	POP	EAX
			LEA	EBP,[EBP-4]
			MOV [EBP],EAX
			NEXTI

; get the actual address RSP points to
rspfetch_:	LEA	EBP,[EBP-4]
			MOV [EBP],ESP
			NEXTI
		
; set the address RSP points to
rspstore_:	MOV EAX,[EBP]
			LEA	EBP,[EBP+4]
			MOV ESP,EAX
			NEXTI
		
; move RSP to "pop" value and throw it away
rdrop_:		POP	EAX
			NEXTI

; push parameter stack value onto stack
dspfetch_:	MOV EAX,EBP
			LEA EBP,[EBP-4]
			MOV [EBP],EAX
			NEXTI

; store the value on top of parameter stack into psp
dspstore_:	MOV EAX,[EBP]
			MOV EBP,EAX
			NEXTI


;; --- dictionary building and words ---------------------------

;; write EAX to [_here] and advance _here
comma_aux:	MOV EDI,[_here+EBX]
			MOV [EDI],EAX
			ADD EDI,4
			MOV [_here+EBX],EDI
			RET

;; finalise a dictionary definition by writing exit
semicolon_aux:
			MOV EDI,[_here+EBX]
			MOV EAX,[_exitcw+EBX]	; stored in here by c-harness
			MOV [EDI],EAX
			ADD EDI,4
			MOV [_here+EBX],EDI
			RET

;; make dictionary entry
;; [esi] -- counted string
;; edi - cfa of word
;; eax -- flags
;; out
;; eax - cfa
mkdict_aux:	PUSH EDI
			MOV EDI,[_here+EBX]
			PUSH EDI				; save here
			PUSH ESI               ; ( ESI EDI EDI )
			MOV ESI,[_link+EBX]
			MOV [EDI],ESI		; link
			ADD EDI,4
			MOV [EDI],AL			; flags
			XOR AL,AL			  
			INC EDI
			MOV [EDI], AL		; pad0
			INC EDI
			MOV [EDI],AL		; pad1
			INC EDI
			POP ESI				; (EDI  EDI)
			XOR ECX,ECX
			MOV CL,[ESI]
			MOV [EDI],CL
			INC EDI				; (EDI EDI EDI)
			PUSH EDI
			CMP CL,16
			JBE .namecopy		; namestring
			MOV CL,16
.namecopy:
			INC ESI
			CLD
			REP MOVSB
			POP	EDI				; (EDI EDI)
			ADD EDI,16
			POP ESI				; old here (EDI)
			POP EAX				; codeword ()
			MOV [EDI],EAX
			MOV EAX,EDI			; eax = [cfa]
			ADD EDI,4
			MOV [_here+EBX],EDI	; set here
			MOV [_latest+EBX],ESI
			RET

;; colon 
;; EAX - flags
;; ESI - nanme as counted string
colon_aux:	LEA EDI,[docol_+EBX]
			CALL mkdict_aux
			RET

;; ( n -- ) allocate n bytes of space at here
allot_:		MOV EDX,[EBP]
			MOV EAX,[_here+EBX]
			ADD EAX,EDX
			MOV [_here+EBX],EAX
			LEA EBP,[EBP+4]
			NEXTI

herevar_:	LEA EAX,[_here+EBX]
			PUSHDSP EAX
			NEXTI
	
;; ( -- n ) push literal on stack
lit_:		LEA EBP,[EBP-4]
			MOV EAX,[ESI]
			MOV [EBP], EAX
			ADD ESI,4
			NEXTI

;; immediate - set last word as immediate
immediate_: MOV EDX, [_latest+EBX]
			LEA EDX, [EDX+4]
			MOV AL, [EDX]
			OR  AL, F_IMMEDIATE
			MOV [EDX],AL
			NEXTI

;; dictionary building macros

;; makecol LABEL,FLAGS
%macro MAKECOL 2		
	%strlen namelen %str(%1) ; NASM calculates this for us!
	SECTION FORTHDATA  align=4 progbits
	BITS 32
	global name_%1
name_%1:
	db namelen
	db %str(%1)
addr_%1_cfa:
	dd	0
	SECTION	KERNEL ALIGN=4 progbits
	BITS 32
	LEA ESI,[name_%1+EBX]
	MOV EAX,%2
	CALL colon_aux
	MOV  [addr_%1_cfa+EBX],EAX
%endmacro	

;; makeword LABEL,INTERPRETER,FLAGS
%macro MAKEWORD 3		
	%strlen namelen %str(%1) ; NASM calculates this for us!
	SECTION FORTHDATA  align=4 progbits
	BITS 32
	global name_%1
name_%1:
	db namelen
	db %str(%1)
addr_%1_cfa:
	dd	0
	SECTION	KERNEL ALIGN=4 progbits
	BITS 32
	LEA ESI,[name_%1+EBX]
	LEA EDI,[%2+EBX]
	MOV EAX,%3
	CALL mkdict_aux
	MOV  [addr_%1_cfa+EBX],EAX
%endmacro	

;; version of makeword where word name and labael are different eg. ! and fetch
;; makenword "NAME", LABEL, INTERPRETER, FLAGS
%macro MAKENWORD 4		
	%strlen namelen %1 ; NASM calculates this for us!
	SECTION FORTHDATA  align=4 progbits
	BITS 32
	global name_%2
name_%2:
	db namelen
	db %1
addr_%2_cfa:
	dd	0
	SECTION	KERNEL ALIGN=4 progbits
	BITS 32
	LEA ESI,[name_%2+EBX]
	LEA EDI,[%3+EBX]
	MOV EAX,%4
	CALL mkdict_aux
	MOV  [addr_%2_cfa+EBX],EAX
%endmacro	

%macro COMMA 1
	LEA EAX,[%1]
	CALL comma_aux
%endmacro

%macro COMPILECOMMA 1
	LEA EAX,[%1+EBX]
	CALL comma_aux
%endmacro

%macro SEMICOLON 0
	CALL semicolon_aux
%endmacro

;; --- system words


;;; Perform DPMI real mode interrupts -  offset is to register information
;;; (offset intnum  --- 0 | offset )
intr_:		PUSH EBX
			PUSH EDI
			MOV EAX,0300h		; dpmi - simulate real mode interrupt	
			MOV EBX,[EBP]		; bl = interrupt number, rest of ebx = 0
			XOR ECX,ECX			; number of words of stack to use
			PUSH DS
			POP  ES
			MOV EDI,[EBP+4]
			INT 31h	
			JNC .ok
			XOR	EDI,EDI
.ok:		LEA EBP,[EBP+4]	
			MOV [EBP],EDI
			POP EDI
			POP EBX
			NEXTI

hex_:		MOV EAX,16
			MOV [_base+EBX], EAX
			NEXTI

octal_:		MOV EAX,8
			MOV [_base+EBX], EAX
			NEXTI

decimal_:	MOV EAX,10
			MOV [_base+EBX], EAX
			NEXTI

;;; ( char -- ) EMIT
;;; prints char to TTY
emit_:		PUSH EDI
			LEA	 EDI,[EBX+_dpmiregs]	; get dpmi regs base
			XOR  EAX,EAX
			MOV  AH,02h					; int function 02
			MOV  [EDI+DPMI_EAX],EAX  
			XOR  EDX,EDX
			MOV  EDX,[EBP]				; character to print
			MOV  [EDI+DPMI_EDX],EDX
			MOV  EAX,0300h				; dpmi simulate real mode interrupt
			XOR  ECX,ECX
			PUSH DS						; ensure es = ds (it probably does..)
			POP  ES						
			PUSH EBX
			MOV  BX,0021h				; int 21
			INT  31h					; call it
			POP  EBX
			POP  EDI
			LEA  EBP,[EBP+4]			; consume char
			NEXTI

;; Gets single keypress char from stdin
;; ( -- char ) KEY
key_:		PUSH EDI
			LEA	 EDI,[EBX+_dpmiregs]	; get dpmi regs base
			XOR  EAX,EAX
			MOV  AH,08h					; int  function 08
			MOV  [EDI+DPMI_EAX], EAX
			MOV  EAX,0300h				; dpmi simulate real mode interrupt
			XOR  ECX,ECX
			PUSH DS						; ensure es = ds (it probably does..)
			POP  ES						
			PUSH EBX
			MOV  BX,0021h				; int 21
			INT  31h					; call it
			JC   .bad
			MOV  EAX,[EDI+DPMI_EAX]
			JMP  .fin
.bad:		XOR EAX,EAX
.fin:		POP EBX
			POP EDI
			LEA EBP,[EBP-4]
			MOV [EBP],EAX
			NEXTI

;;; Parse numeric literasl using _base as radix			
;;; esi - start address of counted string
;;; eax -- value
number_aux:	XOR  EAX,EAX
			XOR  ECX,ECX
			MOV  CL,[ESI]
			INC  ESI
			TEST ECX,ECX
			JZ 	 .return 	; ZERO - LENGTH STRING = 0
			MOV  EDX,[_base+EBX]
			XOR  EBX,EBX
			MOV  BL,[ESI]
			INC  ESI
			PUSH EAX
			CMP  BL,'-'
			JNZ  .convert_char
			POP  EAX
			PUSH EBX
			DEC  ECX
			JNZ  .next_char 
			POP	 EBX	; error - string is '-'
			MOV  ECX,1
			RET
.next_char: IMUL EAX,EDX ; EAX = EAX * BASE
			MOV  BL,[ESI]
			INC  ESI
.convert_char:
			SUB  BL,'0'
			JB   .negate
			CMP  BL,10
			JB   .compare_base
			SUB  BL,17
			JB   .negate
			ADD  BL,10
.compare_base:
			CMP	 BL,DL
			JGE  .negate
			ADD  EAX,EBX
			DEC  ECX
			JNZ  .next_char
.negate:	POP  EBX
			TEST EBX,EBX
			JZ   .return
			NEG  EAX
.return:    RET						

;;; ( c-addr --  val ) NUMBER - parse the cunted string at addr and push val on the stack
;;; uses the current radix in BASE, bails with partial value if string is malformed
number_:    PUSH ESI
			PUSH EBX
			MOV  ESI,[EBP]
			CALL number_aux
			MOV  [EBP],EAX
			POP  EBX
			POP  ESI
			NEXTI

;; --- get input source
source_: 	LEA EDX,[EBX+_tiblen]
			XOR EAX,EAX
			MOV AL,[EDX]
			MOV [EBP-8],EAX
			INC EDX
			MOV [EBP-4],EDX
			LEA EBP,[EBP-8]
			NEXTI

;; get offset into input source
ingt_:		LEA EAX,[EBX+_tibchr]
			MOV [EBP-4],EAX
			LEA EBP,[EBP-4]
			NEXTI
		
;;; ( delimter -- addr ) WORD
;;; parse word from input stream and place at addr
word_:		PUSH ESI
			PUSH EDI
			MOV ESI,[EBX+_tibchr]   ; ESI = tib
			LEA EAX,[EBX+_tib]
			ADD ESI,EAX 
			LEA EDI,[EBX+_parsebuf] ; EDI = prsebuf
			MOV EAX,[EBP]			; AL = delimiter
			XOR ECX,ECX				; ECX = count
.leading:	MOV DL,[ESI]			; skip leading delimiters
			CMP AL,DL
			JNZ .parsing			
			INC ESI
			JMP .leading
.parsing:	MOV DL,[ESI]			; start the parse
			CMP AL,DL				; when we hit the ending delimter, we are done
			JZ  .done		 		
			MOV [EDI],DL			; copy char to parsebuf
	 		INC ECX					; count chars
			INC ESI					; bump to next char
			INC EDI
			JMP .parsing
.done:		
			INC ESI					; bmp esi past the delimiter
			LEA EDI,[EBX+_parseblen]
			MOV [EDI],CL			; put length in parsebuflen
			MOV [EBP],EDI			; put parsbuf on top of stack
			MOV EAX,ESI
			LEA EDX,[EBX+_tib]
			SUB EAX,EDX
			MOV [EBX+_tibchr], EAX
			POP EDI
			POP ESI
			NEXTI

;;; -- dictionary building
;;; ( n --- ) 	
comma_:		MOV EAX,[EBP]	
			MOV EDX,[_here+EBX]
			MOV [EDX],EAX
			ADD EDX,4
			MOV [_here+EBX],EDX
			LEA EBP,[EBP+4]
			NEXTI

;; ( c-ccc -- address n )
find_:		PUSH ESI
			PUSH EDI
			MOV  ESI,[_latest+EBX] ; point to latest word
			XOR  ECX,ECX		
			MOV  EDI,[EBP]		; get string we are seeking
			MOV  CL,[EDI]		; get length
.nextword:
			PUSH ESI			; save start of word sought
			PUSH EDI			
			PUSH ECX
			ADD	 ESI,7			; bump to namelen in dictionary
			MOV  AL,[ESI]		; get name length
			CMP  AL,CL			; compare with source string len
			JNE  .nomatch
			INC  ESI
			CMP  AL,16			; trunc to 16
			JBE  .inrange
			MOV	 AL,16
.inrange:
			INC  EDI
			REPE CMPSB			; compare strings
			JNE  .nomatch
			JMP	 .found
	;;  do comparison
.nomatch:
			POP  ECX
			POP	 EDI
			POP	 ESI
			MOV	 ESI,[ESI]		; back to next word
			TEST ESI,ESI
			JZ	 .notfound
			JMP  .nextword
			
.found:
			POP  ECX
			POP  EDI
			POP  ESI
			ADD  ESI, 24
			MOV  [EBP],ESI
			LEA  EBP,[EBP-4]
			SUB  ESI, 20
			MOV  EAX,[ESI]
			AND  AL,F_IMMEDIATE
			SETNZ AL
			NEG	AL
			MOVSX EAX,AL
			MOV	[EBP], EAX
			JMP	.done
.notfound:
			LEA  EBP,[EBP-4]
			XOR  EAX,EAX
			MOV  [EBP],EAX
.done:
			POP  EDI
			POP  ESI
			NEXTI

;;; MKDICT - Build a dictionary entry		
;;;  ( codeword name flags -- cfa ) 
mkdict_:	PUSH EDI
			PUSH ESI
			MOV EDI,[_here+EBX]
			PUSH EDI				; save here
			MOV ESI,[_link+EBX]
			MOV [EDI],ESI		; link
			ADD EDI,4
			MOV EAX,[EBP]
			MOV [EDI],AL			; flags
			XOR AL,AL			  
			INC EDI
			MOV [EDI], AL		; pad0
			INC EDI
			MOV [EDI],AL		; pad1
			INC EDI
			MOV ESI,[EBP+4]		; name length
			XOR ECX,ECX
			MOV CL,[ESI]
			MOV [EDI],CL
			INC EDI
			PUSH EDI
			CMP CL,16
			JBE .namecopy
			MOV CL,16
.namecopy:
			INC ESI
			CLD
			REP MOVSB
			POP	EDI
			ADD EDI,16
			MOV EAX,[EBP+8]		; codeword	
			MOV [EDI],EAX
			MOV [EBP+8],EDI
			ADD EDI,4
			MOV [_here+EBX],EDI	; set here
			POP EDI				; edi = old here
			MOV [_latest+EBX],EDI
			LEA EBP,[EBP+8]
			POP ESI
			POP EDI
			NEXTI
		   			


;;; SEMICOLON ( -- )
;;; Compile EXIT, unhide latest word, return to interpret mode
semico_:    
			PUSH ESI
			PUSH EDI
			
			; Compile EXIT
			MOV EDI, [EBX+_here]        ; EDI = HERE
			MOV EAX, [EBX+_exitcw]     ; EAX = address of EXIT code
			MOV [EDI], EAX              ; Compile EXIT
			ADD EDI, 4                  
			MOV [EBX+_here], EDI        ; Update HERE
			
			; Unhide the latest word
			MOV ESI, [EBX+_latest]      ; ESI = latest entry
			MOV AL, [ESI+4]             ; Load flags byte (offset 4)
			AND AL, ~20h                ; Clear HIDDEN bit
			MOV [ESI+4], AL             ; Store back
			
			; Return to interpret mode
			MOV DWORD [EBX+_state], 0   ; STATE = 0
			
			POP EDI
			POP ESI
			NEXTI

;;; --- branching

;;; ( N --- ) BRANCHz -- only branch if TOS is zero
branchz_: 	MOV  EAX,[EBP]
			LEA  EBP,[EBP+4]
			TEST EAX,EAX
			JZ   branch_
			ADD  ESI,4
			NEXTI

;;; ( --- ) BRANCH -- unconditional branch
branch_:  	ADD	ESI,[ESI]
			NEXTI

;;; --- debugging support routines 

hxtov_aux:  MOV  EAX,[EBP]
			MOV  EDX,[EBP+4]
			LEA  EBP,[EBP+8]
			MOV  ECX,8
			LEA  EDX,[EDX+16]
			PUSH EBX 
.next:		MOV  BL,AL
			AND  BL,0Fh
			CMP  BL,9
			JBE  .digit 
			ADD  BL,'A'-10
			JMP  .letter
.digit:	    ADD  BL, '0'
.letter:	MOV  BH,1Eh ; yellow on blue
			MOV  [EDX],BX
			LEA  EDX,[EDX - 2]
	  		SHR  EAX,4
			DEC  ECX
			JNZ  .next
			POP EBX
			RET

;; write hex value to video memory
;;( videmem value -- )
hxtov_:		LEA EAX, [hxtov_aux+EBX]
			CALL EAX
			NEXTI

;; clear top line of video display
;; ( -- )
clv80_:		MOV ECX,80
			MOV EDX,0B8000h
			MOV AX,1E20h
.cll:		MOV [EDX],AX
			LEA EDX,[EDX + 2]
			DEC ECX
			JNE	.cll
			NEXTI

;; write contents of stack to top line of video memory
;; ( -- )
seestk_:	MOV EDX,0B8000h
			MOV ECX,EBP			
.again:		MOV EAX,[ECX] ; value
			PUSH ECX
			MOV [EBP-4], EDX ; video location
			MOV [EBP-8], EAX ; value
			LEA EBP,[EBP-8]
			PUSH EDX
			LEA EAX,[hxtov_aux+EBX]
			CALL EAX
			POP EDX
			POP ECX
			LEA EDX,[EDX+12h]
			LEA ECX,[ECX+4]
			LEA EAX,[EBX+_stacktop]
			CMP ECX,EAX
			JNE .again
			NEXTI

			db 0F4h, 0F4h, 0F4h, 0F4h

;; -- forth entry and exit

;;; entry point, here we go
forth_:		MOV EBX,EAX			; EAX has kernel base addy - should be in EBX
			LEA ESI,[_cesp+EBX]
			MOV [ESI],ESP		; save the C stack pointer
			MOV [ESI+4],EBP		; save the C base pointer

			LEA EBP,[_stacktop+EBX]	; set the forth stacks
			LEA ESP,[_rstacktop+EBX]

			;; build the dictionary
			MAKEWORD EXITFORTH, exitforth_, 0

			;; stack manipulation - todo - rot
			MAKEWORD DUP,  dup_, 0
			MAKEWORD OVER, over_, 0
			MAKEWORD DROP, drop_, 0
			MAKEWORD SWAP, swap_, 0

			;; return stack manipulation - todo - R> , R<, RDROP
			MAKENWORD ">R", TORS, tors_, 0
			MAKENWORD "R>", FROMRS, fromrs_, 0
			MAKENWORD "R@", RSPFETCH, rspfetch_, 0
			MAKENWORD "R!", RSPSTORE, rspstore_, 0
			MAKEWORD RDROP, rdrop_, 0
			MAKENWORD "SP@", DSPFETCH, dspfetch_,0
			MAKENWORD "SP!", DSPSTORE, dspstore_,0
		
			;; memory manipulation - todo c@, c!, cmove
			MAKENWORD "@", FETCH, fetch_, 0
			MAKENWORD "!", STORE, store_, 0
			MAKENWORD "C@", CFETCH, fetchbyte_, 0
			MAKENWORD "C!", CSTORE, storebyte_, 0

			;; arithmetic
			MAKENWORD "+", ADD, add_, 0
			MAKENWORD "-", SUB, sub_, 0
			MAKENWORD "*", MUL, mul_, 0
			MAKENWORD "/MOD", DIVMOD, divmod_, 0
			MAKENWORD "1+", ADDONE, addone_, 0
			MAKENWORD "1-", SUBONE, subone_, 0
			MAKENWORD "4+", ADDFOUR, addfour_, 0
			MAKENWORD "4-", SUBFOUR, subfour_, 0

			;; bitwise logic - todo and, or, xor, invert
			MAKEWORD  OR,or_,0
			MAKEWORD  AND,and_,0
			MAKEWORD  XOR,xor_,0
			MAKEWORD  INVERT,invert_,0
		
			;; comparison
			MAKENWORD "0=", ZEROEQ, zeroeq_, 0
			MAKENWORD "=", EQUALS, eq_, 0
			MAKENWORD ">", GREATER, ge_, 0
			MAKENWORD "<", LESSER, lt_, 0



			;; io
			MAKEWORD EMIT, emit_, 0
			MAKEWORD KEY, key_, 0
			MAKENWORD ">IN", INGT, ingt_, 0
			MAKEWORD INTR, intr_, 0
			MAKEWORD SOURCE, source_, 0

			;; dictionary manipulation
			MAKEWORD ALLOT, allot_, 0
			MAKEWORD LIT, lit_, 0
			MAKENWORD ",", COMMA, comma_, 0
			MAKENWORD ";", SEMICOLON, semico_, 0
			MAKEWORD FIND, find_, 0
	
			;; parsing
			MAKEWORD NUMBER, number_, 0
			MAKENWORD "WORD", WORD, word_, 0

			;; branches
			MAKENWORD "BRANCH", BRANCH, branch_, 0
			MAKENWORD "?BRANCH", BRANCHNZ, branchz_, 0
			MAKEWORD EXECUTE, doexec_, 0

			;; debuggering
			MAKEWORD HXTOV, hxtov_, 0
			MAKEWORD SEESTK, seestk_, 0
			MAKEWORD CLV80, clv80_, 0

			MAKECOL TESTBR, 0
			MOV EAX,[addr_LIT_cfa+EBX]
			CALL comma_aux
			MOV EAX,42
			CALL comma_aux
			MOV EAX,[addr_BRANCH_cfa+EBX]
			CALL comma_aux
			MOV EAX,12
			CALL comma_aux
			MOV EAX,[addr_LIT_cfa+EBX]
			CALL comma_aux
			MOV EAX,99
			CALL comma_aux
			SEMICOLON

			;; make our word for testing
			MAKECOL  CALLFORTH, 0
			MOV EAX,[addr_KEY_cfa+EBX]
			CALL comma_aux
			MOV EAX,[addr_TESTBR_cfa+EBX]
			CALL comma_aux
			MOV EAX,[addr_SEESTK_cfa+EBX]
			CALL comma_aux
			SEMICOLON

			MOV EAX,[_latest+EBX]
			ADD EAX,24
			MOV [_coldstart+EBX],EAX
			MOV EAX,[addr_EXITFORTH_cfa+EBX]
			MOV [_coldstart+4+EBX],EAX

			LEA ESI, [_coldstart+EBX]		; prime IP
			MOV EDI, [ESI]
			ADD ESI, 4

			JMP [EDI]

exitforth_:					; should come back here
			LEA ESI,[_cesp+EBX]
			MOV ESP,[ESI]	; restore the C base pointer
			MOV EBP,[ESI+4]	; restore the C stack pointer
			RET

			DB "KEND"
			
	SECTION FORTHDATA  align=4 progbits
	BITS 32

;;; base where forthvm is loaded
_forthbase:	DD 0
;;; location of last defined word 
_link:		DD _dicttop
;;; current top of dictionary
_here:	    DD _dicttop
;;; pointer to latest defined word
_latest:	DD _dicttop
;;; compilation state
_state: 	DD 0
;;; current radix base for number parsing
_base:      DD 10
;;; exit codewword
_exitcw:	DD 0
			
;;; save c stack pointer registers
_cesp:		DD	0
_cebp:		DD	0

;;; buffer for dpmi real mode interrupt calls
_dpmiregs: 	TIMES 34h DD 0 

;; vector for jumping to cold statt
_coldstart: DD 0
			DD 0

;; something to read input from
_parseblen: DB 0
_parsebuf:  TIMES 255 DB 0
_tiblen:    DB 0 
_tib:		TIMES 255 DB 0
_tibchr:    DD 0

	SECTION FORTHDICT  align=4 progbits
	BITS 32
		
		;;; reserve space for rest of dict and user words
_dicttop:	RESB	1024 * 116 	

	
	SECTION STACKS  align=4 progbits
	BITS 32

_stackbrk:	DD		0FEFEFEFEh
			RESB	1024*8		; 8k for the stack
_stacktop:

_rstackbrk:	DD  	0FEFEFEFEh
			RESB	1024*4		; 4k for the return stack
_rstacktop:	
