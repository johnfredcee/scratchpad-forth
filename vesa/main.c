/*
 * Local Variables:
 * c-file-style: "stroustrup"
 * indent-tabs-mode: t
 * tab-width: 4
 * End:
 */
#include <stdio.h>

#pragma pack( 1 ) // pack to bytes boundary

struct vbeinfoblock  {
	unsigned char	VbeSignature[4];
	unsigned short	VbeVersion;
	char		*OemStringPtr;
	unsigned long	Capabilities;
	unsigned short	*VideoModePtr;
	unsigned short	TotalMemory;
	
	unsigned short	OemSoftwareRev;
	char		*OemVendorNamePtr;
	char		*OemProductNamePtr;
	char		*OemProductRevPtr;
	unsigned char	Reserved1[222];
	unsigned char	OemData[256];
} VIB;


struct modeinfoblock {
	unsigned short	ModeAttributes;
	unsigned char	WinAAttributes;
	unsigned char	WinBAttributes;
	unsigned short	WinGranularity;
	unsigned short	WinSize;
	unsigned short	WinASegment;
	unsigned short	WinBSegment;
	unsigned long	WinFuncPtr;
	unsigned short	BytesPerScanLine;

	unsigned short	XResolution;
	unsigned short	YResolution;
	unsigned char	XCharSize;
	unsigned char	YCharSize;
	unsigned char	NumberOfPlanes;
	unsigned char	BitsPerPixel;
	unsigned char	NumberOfBanks;
	unsigned char	MemoryModel;
	unsigned char	BankSize;
	unsigned char	NumberOfImagePages;
	unsigned char	Reserved;

	unsigned char	RedMaskSize;
	unsigned char	RedFieldPosition;
	unsigned char	GreenMaskSize;
	unsigned char	GreenFieldPosition;
	unsigned char	BlueMaskSize;
	unsigned char	BlueFieldPosition;
	unsigned char	RsvdMaskSize;
	unsigned char	RsvdFieldPosition;
	unsigned char	DirectColorModeInfo;

	unsigned long	PhysBasePtr;
	unsigned long	OffScreenMemOffset;
	unsigned short	OffScreenMemSize;
	unsigned char	Reserved2[206];
} MIB;

#pragma pack( ) // pack back to normal

unsigned long lfb_physaddr;
unsigned long lfb_physsize;
unsigned long lfb_linearbase;
unsigned long lfb_linesize;

#pragma aux cls = \
	"mov	ax,03h"	\
	"int	10h"	\
	modify [eax];

#pragma aux getkey =	\
	"xor	ax,ax"	\
	"int	16h"	\
	modify [eax];

// This is not the best way to check for presence of VGA, but it is just an
// example of how you can use the extended VGA BIOS functions without need
// to call DPMI.

#pragma aux detectvga =		\
	"sub	esp,40h"	\
	"mov	ah,1Bh"		\
	"xor	bx,bx"		\
	"mov	edi,esp"	\
	"int	10h"		\
	"cmp	al,1Bh"		\
	"mov	eax,1"		\
	"jnz	@@done"		\
	"mov	eax,0"		\
"@@done:"			\
	"add	esp,40h"	\
	modify [eax ebx edi]	\
	value [eax];

#pragma aux detectvesa =	\
	"mov	ax,4F00h"	\
	"mov	edi,offset VIB"	\
	"int	10h"		\
	"cmp	ax,004Fh"	\
	"mov	eax,1"		\
	"jnz	@@done"		\
	"mov	eax,0"		\
"@@done:"			\
	modify [eax ecx esi edi]\
	value [eax];

#pragma aux getmodeinfo =	\
  "mov	ax,4F01h"		\
  "mov	edi,offset MIB"		\
  "int	10h"			\
  "cmp	ax,004Fh"		\
  "mov	eax,1"			\
  "jnz	@@done"			\
  "mov	eax,0"			\
"@@done:"			\
  modify [eax ecx esi edi]	\
  value [eax]			\
  parm [ecx];

#pragma aux setcurrentmode = \
  "mov   ax,4F02h"		\
  "int   10h"			\
  "cmp	ax,004Fh"		\
  "mov	eax,1"			\
  "jz	@@done"			\
  "mov	eax,0"			\
"@@done:"			\
  modify [eax ebx ecx esi edi]	\
  parm  [bx]			\
  value [eax];

#pragma aux getcurrentmode = \
  "mov ax, 4F03h"	     \
  "int 10h"		     \
  "cmp ax,004Fh"	     \
  "mov eax,0"		     \
  "jnz @@done"		     \
  "mov ax,bx"		     \
"@@done:"		     \
  modify [eax ebx ecx esi edi]	\
  value [eax]	
	
#pragma aux mapmem = \
	"mov eax,0FF98h" \
	"mov ebx, lfb_physaddr" \
	"mov esi, lfb_physsize" \
	"int 21h" \
	"jnc @@done" \
	"xor ebx, ebx" \
"@@done:" \
	modify [eax ebx ecx esi edi] \
	value [ebx]

void ShowVI() {
	printf("Video BIOS Extension Information:\n");
	printf("=================================\n");

	printf("VBE Signature        :   %.4s\n",
		VIB.VbeSignature);

	printf("VBE Version          :   %d.%d\n",
		VIB.VbeVersion>>8,
		VIB.VbeVersion&0xFF);

	printf("OEM String           :   %s\n",
		VIB.OemStringPtr);

	printf("OEM Vendor Name      :   %s\n",
		VIB.OemVendorNamePtr);

	printf("OEM Product Name     :   %s\n",
		VIB.OemProductNamePtr);

	printf("OEM Product Revision :   %s\n",
		VIB.OemProductRevPtr);

	printf("Capabilities         :   0x%08X\n",
		   VIB.Capabilities);
	
	printf("Mode List Ptr        :   0x%08X\n",
		   VIB.VideoModePtr);

	printf("Total Memory         :   %4d KB\n",
		VIB.TotalMemory*64);
}

void ShowMI() {
  int n;
  int mode=0;
  unsigned short* ModePtr = VIB.VideoModePtr;
  
  printf("Video Mode Information:\n");
  printf("=======================\n");
	
  for(;;) {
    if((mode=(*ModePtr++))==0xFFFF) break;
    
    printf("Video Mode:  %04Xh  -  ",mode);
    
    if(getmodeinfo(mode)!=0) printf("invalid");
	  else {
	    if((MIB.ModeAttributes&0x0010)==0)
	      printf("text     ");
	    else	printf("graphics ");
	    
	    printf("%4d x ",MIB.XResolution);
	    printf("%4d x ",MIB.YResolution);
	    printf("%2d bits/pixel,  ",MIB.BitsPerPixel);
	    printf("%d planes ",MIB.NumberOfPlanes);
	    printf("%4d,%4d char size ", MIB.XCharSize, MIB.YCharSize);
	    printf("%2d %2d %2d number of planes, banks and pages ", MIB.NumberOfPlanes, MIB.NumberOfBanks, MIB.NumberOfImagePages);
	    printf("%02x Memory model", MIB.MemoryModel);
	    if((MIB.ModeAttributes&0x0080)!=0)
	      printf(",  linear");
	  }
	  printf("\n");
	}
}

unsigned short FindRightMode()
{
	unsigned short* ModePtr = VIB.VideoModePtr;
	int mode=0;
	unsigned short result = 0;
	for(;;)
	{
		if ((result != 0) || ((mode=(*ModePtr++))==0xFFFF))
			break;
	
		if(getmodeinfo(mode)==0)
		{
		  if ((MIB.XResolution == 640) && (MIB.YResolution == 480) &&
		      (MIB.BitsPerPixel = 8) && (MIB.NumberOfPlanes == 1) &&
		      ((MIB.ModeAttributes&0x0080) != 0))
		    {
		      result = mode;
		    }
		}
		
	}
	return result;
}

int setlinearmode(unsigned short mode, unsigned short clear)
{
	unsigned short bx = mode | 0x4000 | (clear == 0 ? 0xF000 : 0);
	return setcurrentmode(bx);
}

int main(int argc, char *argv[])
{
	unsigned short newmode = 0;
	unsigned short oldmode = 0;
	struct modeinfoblock *modeinfo = NULL;
	
	lfb_physsize = 640 * 480;
	lfb_linesize = 640;
	if(detectvga()) {
	  printf("VGA BIOS not detected!\n");
	  exit(-1);
	}
	if(detectvesa()) {
	  printf("VESA BIOS not detected!\n");
	  exit(-1);
	}
	ShowVI();
	ShowMI();
	printf("Buffer sizes\n");
	printf("VIB %d, MIB %d\n", sizeof(VIB), sizeof(MIB));
	newmode = FindRightMode();
	if (getmodeinfo(newmode) != 0) {
	  fprintf(stderr, "No mode info\n");
	  exit(-1);
	}
	modeinfo = &MIB;
	lfb_physaddr = modeinfo->PhysBasePtr;
	lfb_linearbase = mapmem();
	if (lfb_linearbase == 0) {
	  fprintf(stderr, "Failed to map memory\n");
	  exit(-1);
	}	
	oldmode = getcurrentmode();
	printf("Candidate mode %08x\n", newmode);
	printf("Current mode %08x\n", oldmode);
	if ((oldmode != 0) && (newmode != 0))
	{
	  printf("Hit key to switch mode\n");
	  getchar();
	  if (setlinearmode(newmode, 1) == 0) {
	    fprintf(stderr, "Mode change failed\n");
	    exit(-1);
	  }
	  printf("Hit key to change back\n");
	  getchar();
	  if (setlinearmode(oldmode, 1) == 0) {
	    fprintf(stderr, "Mode change failed\n");
	    exit(-1);
	  };
	}
	return 0;
}
