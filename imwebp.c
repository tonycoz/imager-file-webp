#include "imwebp.h"
#include "webp/mux.h"

i_img *
i_readwebp(io_glue *ig, int allow_incomplete, int page) {
  return NULL;
}

i_img **
i_readwebp_multi(io_glue *ig, int *count) {
  *count = 0;
  return NULL;
}

undef_int
i_writewebp(i_img *im, io_glue *ig) {
  return 0;
}
undef_int
i_writewebp_multi(io_glue *ig, i_img **imgs, int count) {
  return 0;
}

char const * i_webp_libversion(void) {
  static char buf[80];
  if (!*buf) {
    unsigned int mux_ver = WebPGetMuxVersion();
    sprintf(buf, "mux %d.%d.%d (%x)", mux_ver >> 16, (mux_ver >> 8) & 0xFF, mux_ver & 0xFF, mux_ver);
  }
  return buf;
}
