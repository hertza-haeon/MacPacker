// sevenzip_lzma_dec.c -- 7-Zip's LZMA decoder (vendor/7zip/C/LzmaDec.c),
// with its main loop in ARM64 assembly on Apple silicon.
//
// 7-Zip's own builds define Z7_LZMA_DEC_OPT for LzmaDec.c and link
// Asm/arm64/LzmaDecOpt.S (vendor/7zip/CPP/7zip/7zip_gcc.mak). SwiftPM can't
// set a define for one architecture, so it is set here and the vendored file
// is compiled through this one, unchanged; the loop itself comes from
// sevenzip_lzma_dec_arm64.S. The Intel slice keeps the C loop: 7-Zip's x86
// assembly is written for MASM, which clang doesn't assemble.

#if defined(__aarch64__)
#define Z7_LZMA_DEC_OPT
#endif

#include "vendor/7zip/C/LzmaDec.c"
