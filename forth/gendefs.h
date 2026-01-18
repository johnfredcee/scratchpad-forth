#ifndef GENDEFS_H
#define GENDEFS_H


// they didn't include this def in their math include
#ifndef M_PI
#define M_PI 3.141592654
#endif

// so stuff can find proper file ops
#include <io.h>

typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;

typedef signed char sint8;
typedef signed short sint16;
typedef signed int sint32;

#endif
