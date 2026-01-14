;;
;; We need to define a forth VM with registers that map onto the 386 register set
;;
;; W  - EDI - Pointer to code field of command currently being executed
;; IP - ESI - Instruction pointer
;; SP - EBP - Data stack pointer
;; RP - ESP - Return stack pointer
;; X  - ?
;; UP - ?
			[map symbols kernel.map]
		
			CPU 486 			; it's 1999
			ORG 0
		
			SECTION	KERNEL ALIGN=1 progbits
			BITS 32

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
docon_:		ADD EDI,4
			MOV EAX,[EDI]
			PUSHDSP EAX
			NEXTI

;; variable interpreter
dovar_:		ADD EDI,4
			PUSHDSP EDI
			NEXTI

;;; code for primitives
dup_:		MOV EAX,[EBP]
			LEA EBP,[EBP-4]
			MOV [EBP], EAX
			NEXTI

over_:		MOV EAX,[EBP+4]
			LEA EBP,[EBP-4]
			MOV [EBP], EAX
			NEXTI

drop_:		LEA EBP,[EBP+4]
			NEXTI

swap_:		MOV EAX,[EBP]
			MOV EBX,[EBP-4]
			MOV [EBP-4],EAX
			MOV [EBP],EBX
			NEXTI	

fetch_:		MOV EDX,[EBP]		; EDX <- address to fetch
			MOV EAX,[EDX]		; EAX <- value at address
			MOV [EBP],EAX
			NEXTI

store_:		MOV EDX,[EBP]		; EDX <- address to store ad  
			MOV EAX,[EBP+4]		; EAX <- value to store
			MOV [EDX],EAX
			LEA EBP,[EBP+8]		; Pop 2
			NEXTI

add_:		MOV EAX,[EBP]
			LEA EBP,[EBP+4]
			ADD [EBP],EAX
			NEXTI
	
sub_:		MOV EAX,[EBP]
			LEA EBP,[EBP+4]
			SUB [EBP],EAX
			NEXTI
	
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

;;; (reg offset interrupt number --- 0 | Offset of real mode call structure )
intr21_:	PUSH EDI
			MOV EAX,0300h		
			MOV EBX,[EBP+4]
			XOR ECX,ECX
			PUSH DS
			POP  ES
			MOV EDI,[EBP]
			INT 31h	
			JNC .ok
			XOR	EDI,EDI
.ok:		LEA EBP,[EBP+4]	
			MOV [EBP],EDI
			POP EDI
			NEXTI

;;; entry point, here we go
forth_:		MOV EBX,EAX			; EAX has kernel base addy - should be in EBX
			LEA ESI,[_cesp+EBX]
			MOV [ESI],ESP		; save the C stack pointer
			ADD ESI,4
			MOV [ESI],EBP		; save the C base pointer

			LEA EBP,[_stacktop+EBX]	; set the forth stacks
			LEA ESP,[_rstacktop+EBX]


			PUSHDSP 42
			MOV ESI, EDX		; prime IP
			MOV EDI, ESI
			ADD ESI, 4
			JMP [EDI]

exitforth_:					; should come back here
			LEA ESI,[_cebp+EBX]
			MOV EBP,[ESI]	; restore the C base pointer
			SUB ESI,4
			MOV ESP,[ESI]	; restore the C stack pointer
			RET

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
;;; save c stack pointer registers
_cesp:		DD	0
_cebp:		DD	0

			SECTION FORTHDICT  align=4 nobits
			BITS 32
		
		;;; reserve space for rest of dict and user words
_dicttop:	RESB	1024 * 116 	

	
			SECTION STACKS  align=4 nobits
			BITS 32

_stackbrk:	RESD	1
			RESB	1024*8		; 8k for the stack
_stacktop:

_rstackbrk:	RESD  	1
			RESB	1024*4		; 4k for the return stack
_rstacktop:	
