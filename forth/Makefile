
#which memory model and processor to use by default
#PROCESSOR =     # for the 16-bit compilers
PROCESSOR = 386 # for the 32-bit compilers

# name the compiler
CC = wcl$(PROCESSOR)
ASM = nasm

MODEL = f     	   # flat

# options to use
CFLAGS = -m$(MODEL) -od -d2  -s -hd -5r -zp1 -bc 
LFLAGS = -m$(MODEL) -od -d2  -s -hd -5r -zp1   
AFLAGS = -f obj

.EXTENSIONS:
.EXTENSIONS: .exe .rex .bin .lib .obj .o .wbj .asm .c .for

OBJS = main.o 
CFLAGS += -I"../.."

forth.exe : $(OBJS) kernel.bin kernel.h .PRECIOUS
	$(CC) $(LFLAGS) -bcl=dos4g -fe=forth.exe -fd=$^&.lnk $(OBJS) 

kernel.bin: kernel.asm .PRECIOUS
	nasm -f bin kernel.asm -l kernel.lst -o kernel.bin 
	perl munger.pl > kernel.h

clean : .SYMBOLIC 
	rm *.o *.bin *.map kernel.h forth.exe

all : .SYMBOLIC
	kernel.bin forth.exe

.c.o :
	$(CC) -c $^&.c $(CFLAGS)

.c.wbj :
	$(CC) -c $^& $(CFLAGS) -zw -fo=$^&.wbj 

.asm.obj :
	$(ASM) $(AFLAGS)  $^&.asm -l $^&.lst 


