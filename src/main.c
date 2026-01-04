
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gendefs.h"
#include "kernel.h"

#define F_IMMEDIATE 0x80
#define F_HIDDEN    0x20

#pragma pack(push, 1)
typedef struct dict_entry
{
  uint32   link; // 4
  unsigned char flags;
  unsigned char pad0;
  unsigned char pad1;
  unsigned char nlen; // 8
  char  name[16]; // 24
  void (*codeword)(); // 28
} dict_entry_t;
#pragma pack(pop)


void (*forth)(void* base, void* colonstart);

/* newest word in dictionary */
uint32* latest_ptr;
/* end of dictionary */
uint32* here_ptr;
/* previous entry in dictionary */ 
uint32* link_ptr;
/* base address of kernel */ 
uint32* forth_base_ptr;
/* address of codeword of exit */
uint32* exitcw;

#define MK_PTR(x) ((void(*)()) ((*forth_base_ptr) + ((uint32)(x))))

void* mkdict(char *name, void (*codeword)(), int flags)
{
	dict_entry_t* new_entry;
	void* result;
	
	new_entry = (dict_entry_t*) *here_ptr;
	new_entry->link = *link_ptr;
	*link_ptr = *here_ptr;
	new_entry->flags = flags;
	new_entry->pad0  = 0xEE;
	new_entry->pad1  = 0xEE;
	new_entry->nlen  = strlen(name);
	strncpy(new_entry->name, name, 15);
	result = &(new_entry->codeword);
	new_entry->codeword = codeword;
	*here_ptr = *here_ptr + sizeof(dict_entry_t);
	*latest_ptr = (uint32) new_entry;
	return result;
}

/* begin a colon definition */
void* colon(char *name)
{
	*latest_ptr = *here_ptr;
	return mkdict(name, MK_PTR(K_DOCOL), F_HIDDEN);
}

void semicolon()
{	
	uint32* dictmem =(uint32*) *here_ptr;
	*dictmem = (uint32) exitcw;
	*here_ptr = *here_ptr + 4;
}

void comma(uint32 codeword)
{
	uint32* dictmem = (uint32*) *here_ptr;
	*dictmem = (uint32) codeword;
	*here_ptr = *here_ptr + 4;
}

int main(int argc, char** argv)
{
  FILE* kernel_file;
  long kernel_size;
  uint8 *kernel;
  void *dupcw, *overcw, *dropcw, *swapcw;
  void *testmecw;
  void *callforthcw;
  void *exitforthcw;
  
  printf("Hello world\n");
  kernel_file = fopen("KERNEL.BIN", "rb");
  if (kernel_file != NULL) {
	fseek(kernel_file, 0, SEEK_END);
	kernel_size = ftell(kernel_file);
	printf("Kernel size %08x\n", kernel_size);
	fseek(kernel_file, 0, SEEK_SET);
	kernel = (uint8*) malloc(kernel_size);
	printf("Reading kernel\n");
	fread(kernel, kernel_size, 1, kernel_file);
	printf("Done\n");
	fclose(kernel_file);

	/* poke in the loaded base address of the forth kernel */
	forth_base_ptr = (uint32*) (kernel + K_FORTHBASE);
	*forth_base_ptr = (uint32) kernel;
	here_ptr = (uint32*) (kernel + K_HERE);
	link_ptr = (uint32*) (kernel + K_LINK);
	latest_ptr = (uint32*) (kernel + K_LATEST);
	/* set top of dictionary */
	*here_ptr =  (uint32) kernel + K_DICTTOP;
	*link_ptr = (uint32) NULL; // (uint32) kernel + K_DICTTOP;
	*latest_ptr = (uint32) kernel + K_DICTTOP;

	/* start building the dictionary */
	exitcw = mkdict("EXIT", MK_PTR(K_DOEXIT), 0);
	dupcw = mkdict("DUP", MK_PTR(K_DUP), 0);
	overcw = mkdict("OVER", MK_PTR(K_OVER), 0);
	dropcw = mkdict("DROP", MK_PTR(K_DROP), 0);
	swapcw = mkdict("SWAP", MK_PTR(K_SWAP), 0);
	mkdict("@", MK_PTR(K_FETCH), 0);
	mkdict("!", MK_PTR(K_STORE), 0);
	mkdict("+", MK_PTR(K_ADD), 0);
	mkdict("-", MK_PTR(K_SUB), 0);
	mkdict("*", MK_PTR(K_MUL), 0);
	mkdict("/MOD", MK_PTR(K_DIVMOD), 0);
	
	exitforthcw = mkdict("EXITFORTH", MK_PTR(K_EXITFORTH), 0);
	
	testmecw = colon("TESTME");
	comma((uint32) dupcw);
	comma((uint32) dropcw);
	semicolon();

	callforthcw = colon("CALLFORTH");
	comma((uint32) testmecw);
	comma((uint32) exitforthcw);
	
    /* compute kernel entry address */
	forth = (void (*)(void*, void*))(kernel + K_FORTH);

	printf("Callforth cw @ %08x\n", (uint32) callforthcw);
	printf("Testme cw @ %08x\n", (uint32) testmecw);
	printf("Dupcw @ %08x\n", (uint32) dupcw);
	printf("Docol @ %08x\n", (uint32) kernel + K_DOCOL);
	printf("Dup @ %08x\n", (uint32) kernel + K_DUP);
	printf("Exit cw @ %08x\n", (uint32) exitcw);
	printf("Exit @ %08x\n", (uint32) kernel+K_DOEXIT);
	printf("Entering kernel @ %08x\n", (uint32) forth);
	forth(kernel, callforthcw);
	printf("Left kernel\n");
  } else {
	printf("Failed to find kernel file\n");
  }
  return 0;
}

