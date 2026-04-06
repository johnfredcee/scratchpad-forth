
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <i86.h>

#include "gendefs.h"
#include "kernel.h"

void clearscreen()
{
    union REGS regs;

    regs.w.cx = 0;
    regs.w.dx = 0x1850;
    regs.h.bh = 7;
    regs.w.ax = 0x0600;
    int386( 0x10, &regs, &regs );
    regs.h.ah = 2;
    regs.h.bh = 0;
    regs.w.dx = 0;
    int386( 0x10, &regs, &regs );
}

#define F_IMMEDIATE 0x80
#define F_HIDDEN 0x20

#pragma pack(push, 1)
typedef struct dict_entry {
  uint32 link; // 4
  unsigned char flags;
  unsigned char pad0;
  unsigned char pad1;
  unsigned char nlen; // 8
  char name[16];      // 24
  void (*codeword)(); // 28
} dict_entry_t;
#pragma pack(pop)

void (*forth)(void *base);

/* newest word in dictionary */
uint32 *latest_ptr;
/* end of dictionary */
uint32 *here_ptr;
/* previous entry in dictionary */
uint32 *link_ptr;
/* base address of kernel */
uint32 *forth_base_ptr;
/* address of codeword of exit */
uint32 *exitcw;

#define MK_PTR(x) ((void (*)())((*forth_base_ptr) + ((uint32)(x))))

void *mkdict(char *name, void (*codeword)(), int flags) {
  dict_entry_t *new_entry;
  void *result;

  new_entry = (dict_entry_t *)*here_ptr;
  new_entry->link = *link_ptr;
  *link_ptr = *here_ptr;
  new_entry->flags = flags;
  new_entry->pad0 = 0xEE;
  new_entry->pad1 = 0xEE;
  new_entry->nlen = strlen(name);
  strncpy(new_entry->name, name, 15);
  result = &(new_entry->codeword);
  new_entry->codeword = codeword;
  *here_ptr = *here_ptr + sizeof(dict_entry_t);
  *latest_ptr = (uint32)new_entry;
  return result;
}

/* begin a colon definition */
void *colon(char *name) {
//  *latest_ptr = *here_ptr;
  return mkdict(name, MK_PTR(K_DOCOL), F_HIDDEN);
}

void semicolon() {
  uint32 *dictmem = (uint32 *)*here_ptr;
  *dictmem = (uint32)exitcw;
  *here_ptr = *here_ptr + 4;
}

void comma(uint32 codeword) {
  uint32 *dictmem = (uint32 *)*here_ptr;
  *dictmem = (uint32)codeword;
  *here_ptr = *here_ptr + 4;
}

int main(int argc, char **argv) {
  FILE *kernel_file;
  long kernel_size;
  uint8 *kernel;
  uint8 *kernel_data;
  void *herecw, *allotcw, *litcw, *exitcwptr;
  void *addcw, *subcw, *zeroeqcw, *addonecw, *subonecw, *addfourcw, *subfourcw; 
  void *fetchcw, *storecw, *executecw;
  void *emitcw, *keycw, *numbercw;
  void *clv80cw,*hxtovcw,*seestkcw;
  void *intrcw;
  void *sourcecw, *ingtcw, *wordcw, *mkdictcw, *createcw, *coloncw;
  void *commacw, *findwrdcw, *semicoloncw;
  void *branchcw, *branchzcw;
  void *testmecw;
  void *callforthcw;
  void *exitforthcw;
  char *tib,*tiblen;
  void *tibptr;

  
  clearscreen();
  printf("\nBooting forth\n");
  kernel_file = fopen("KERNEL.BIN", "rb");
  if (kernel_file != NULL) {
    fseek(kernel_file, 0, SEEK_END);
    kernel_size = ftell(kernel_file);
    fseek(kernel_file, 0, SEEK_SET);
    kernel_data = (uint8 *)malloc(kernel_size + 32);
    kernel = (uint8*) ((((uint32) kernel_data) & ~15) + 16);
    printf("Reading kernel\n");
    fread(kernel, kernel_size, 1, kernel_file);
    printf("Done\n");
    fclose(kernel_file);
    printf("Kernel loaded @ %08p\n", kernel);
    printf("Kernel size %08lx\n", kernel_size);

    /* poke in the loaded base address of the forth kernel */
    forth_base_ptr = (uint32 *)(kernel + K_FORTHBASE);
    *forth_base_ptr = (uint32)kernel;
    here_ptr = (uint32 *)(kernel + K_HERE);
    link_ptr = (uint32 *)(kernel + K_LINK);
    latest_ptr = (uint32 *)(kernel + K_LATEST);
    /* set top of dictionary */
    *here_ptr = (uint32)kernel + K_DICTTOP;
    *link_ptr = (uint32)NULL; // (uint32) kernel + K_DICTTOP;
    *latest_ptr = (uint32)kernel + K_DICTTOP;

    /* start building the dictionary */
    herecw = mkdict("HERE", MK_PTR(K_HEREVAR), 0);
    exitcw = mkdict("EXIT", MK_PTR(K_DOEXIT), 0);
    exitcwptr = (uint32*) MK_PTR(K_EXITCW);
    *(uint32*)exitcwptr = (uint32) exitcw;

    executecw = mkdict("EXECUTE", MK_PTR(K_DOEXEC), 0);
    clv80cw = mkdict("CLV80", MK_PTR(K_CLV80), 0);
    findwrdcw = mkdict("FINDWRD", MK_PTR(K_FINDWRD), 0);
    mkdictcw = mkdict("MKDICT", MK_PTR(K_MKDICT), 0);
    
    tib = (char*) MK_PTR(K_TIB);
    strcpy(tib,"-980");
    tiblen =(char*)  MK_PTR(K_TIBLEN);
    *tiblen = strlen(tib);

    /**
    createcw = colon("CREATE");
    comma((uint32)litcw);
    comma((uint32)MK_PTR(K_DOVAR));
    comma((uint32)litcw);
    comma((uint32)32);
    comma((uint32)wordcw);
    comma((uint32)litcw);
    comma((uint32)0);
    comma((uint32)mkdictcw);
    comma((uint32)addfourcw);
    semicolon();
    
    coloncw = colon(":");
    comma((uint32)createcw);          // create word
    comma((uint32)subfourcw);
    comma((uint32)MK_PTR(K_DOCOL));   // store docol in cfa
    comma((uint32)swapcw);
    comma((uint32)storecw);
    semicolon();
    */

    /* compute kernel entry address */
    forth = MK_PTR(K_FORTH);
    printf("Forth entry point offset %08x\n", K_FORTH);
    printf("Callforth cw @ %08x\n", (uint32)callforthcw);
    printf("Stack top @ %08p\n", MK_PTR(K_STACKTOP) );
    printf("R stack top %08p\n", MK_PTR(K_RSTACKTOP) );
    printf("TIB @%08p\n", MK_PTR(K_TIB) );
    printf("TIBCHR @%08p\n", MK_PTR(K_TIBCHR) );
    printf("Here @%08p\n", (void*)(*here_ptr) );
    printf("Docol @%08p\n", MK_PTR(K_DOCOL));
    printf("DO EXIT @%08p\n", MK_PTR(K_DOEXIT));   
    printf("Exit cfa @%08p\n", exitcw);
    printf("Entering kernel @ %08x\n", (uint32)forth);
    forth(kernel);
    printf("Left kernel\n");
    free(kernel_data);
  } else {
    printf("Failed to find kernel file\n");
  }
  return 0;
}
