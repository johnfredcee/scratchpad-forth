#which memory model and processor to use by default
#PROCESSOR =     # for the 16-bit compilers
PROCESSOR = 386 # for the 32-bit compilers

# name the compiler
CC = wcl$(PROCESSOR)

MODEL = f       # flat

ASM = wasm
CFLAGS = -m$(MODEL) -od -d2 -db -s -hd -5r -zp1 -bc -bcl=dos32a  
LFLAGS = -m$(MODEL) -od -d2 -db -s -hd -5r -zp1 -bcl=dos32a  
AFLAGS =
LNKOPT = option quiet

.EXTENSIONS:
.EXTENSIONS: .exe .rex .lib .obj .o .wbj .asm .c .for  

OBJS = main.o

vesa.exe : $(OBJS) .PRECIOUS
	wcl386 $(LFLAGS) -fe=vesa.exe -bf=$^&.lnk $(OBJS) 
#	wlink $(LINKOPT) system dos32a name vesa.exe file{ $(OBJS) }

.c.o :
	$(CC) -c $^&.c $(CFLAGS)

.c.wbj :
	$(CC) $^& $(CFLAGS) -zw -fo=$^&.wbj

.asm.o :
	$(ASM) $(AFLAGS) $^&

