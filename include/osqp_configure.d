module osqp_configure;


/* DEBUG */
//#mesondefine DEBUG

/* Operating system */
//#mesondefine IS_LINUX
//#mesondefine IS_MAC
//#mesondefine IS_WINDOWS

/* EMBEDDED */
/*
#ifdef USE_EMBEDDED
#define EMBEDDED (False)
#else
#undef EMBEDDED
#endif*/
/* PRINTING */
//#mesondefine PRINTING

/* PROFILING */
//#mesondefine PROFILING

/* CTRLC */
//#mesondefine CTRLC

/* DFLOAT */
//#mesondefine DFLOAT

/* DLONG */
//#mesondefine DLONG

/* ENABLE_MKL_PARDISO */
//#mesondefine ENABLE_MKL_PARDISO


/* MEMORY MANAGEMENT */
//#mesondefine OSQP_CUSTOM_MEMORY

version(OSQP_CUSTOM_MEMORY)
{
    // todo : test it
    //#include "custom_header.h"
    import custom_header.h;
}
else {
/* If no custom memory allocator defined, use
 * standard linux functions. Custom memory allocator definitions
 * appear in the osqp_configure.h generated file. */
    import core.stdc.stdlib;
    alias c_malloc = malloc;
    alias c_calloc = calloc;
    alias c_realloc = realloc;
    alias c_free = free;
}
