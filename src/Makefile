
#which memory model and processor to use by default
#PROCESSOR =     # for the 16-bit compilers
PROCESSOR = 386 # for the 32-bit compilers

# name the compiler
CC = wcl$(PROCESSOR)
ASM = nasm

MODEL = f       # flat

# options to use
CFLAGS = -m$(MODEL) -od -d2 -db -s -hd -5r -zp1 -bc -bcl=dos32a  
LFLAGS = -m$(MODEL) -od -d2 -db -s -hd -5r -zp1 -bcl=dos32a  
AFLAGS = -f obj

.EXTENSIONS:
.EXTENSIONS: .exe .rex .bin .lib .obj .o .wbj .asm .c .for

OBJS = main.obj 
CFLAGS += -I"../.."

forth.exe : $(OBJS) kernel.bin kernel.h .PRECIOUS
	wcl386 $(LFLAGS) -fe=forth.exe -bf=$^&.lnk $(OBJS) 

kernel.bin: kernel.asm .PRECIOUS
	nasm -f bin kernel.asm -l kernel.lst -o kernel.bin 
	perl3 munger.pl > kernel.h

clean : .SYMBOLIC 
	rm *.o *.bin *.map kernel.h

all : .SYMBOLIC
	kernel.bin forth.exe
	
.c.obj :
	$(CC) -c $^&.c $(CFLAGS)

.c.wbj :
	$(CC) -c $^& $(CFLAGS) -zw -fo=$^&.wbj 

.asm.obj :
	$(ASM) $(AFLAGS)  $^&.asm -l $^&.lst 


