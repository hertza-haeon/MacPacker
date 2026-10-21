// sevenzip_lzma_dec_arm64.S -- 7-Zip's ARM64 assembly LZMA decoder loop
// (LzmaDec_DecodeReal_3), which sevenzip_lzma_dec.c uses on Apple silicon.
// Empty on Intel. The vendored file is assembled as it is.

#if defined(__aarch64__)
#include "vendor/7zip/Asm/arm64/LzmaDecOpt.S"
#endif
