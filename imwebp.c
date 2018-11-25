#include "imwebp.h"
#include "webp/mux.h"
#include "webp/encode.h"
#include "imext.h"
#include <errno.h>

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
  return i_writewebp_multi(ig, &im, 1);
}

static unsigned char *
frame_raw(i_img *im) {
  unsigned char *data, *p;
  i_img_dim y;
  data = mymalloc(im->xsize * im->ysize * 3);
  p = data;
  for (y = 0; y < im->ysize; ++y) {
    i_gsamp(im, 0, im->xsize, y, p, NULL, im->channels);
    p += im->channels * im->xsize;
  }

  return data;
}

unsigned char *
frame_webp(i_img *im, size_t *sz) {
  unsigned char *raw = frame_raw(im);
  uint8_t *webp;
  size_t webp_size = WebPEncodeRGB(raw, im->xsize, im->ysize, im->xsize * 3, 80, &webp);
  *sz = webp_size;
  myfree(raw);
  return webp;
}

undef_int
i_writewebp_multi(io_glue *ig, i_img **imgs, int count) {
  WebPMux *mux;
  int i;
  WebPData outd;
  WebPMuxError err;

  for (i = 0; i < count; ++i) {
    if (imgs[i]->channels != 3) {
      i_push_error(0, "channels must be 3 for now");
      return 0;
    }
    if (imgs[i]->xsize > 16383) {
      i_push_error(0, "maximum webp image width is 16383");
      return 0;
    }
    if (imgs[i]->ysize > 16383) {
      i_push_error(0, "maximum webp image height is 16383");
      return 0;
    }
  }

  mux = WebPMuxNew();

  if (!mux) {
    i_push_error(0, "Cannot create mux object.  ABI mismatch?");
  }

  if (count == 1) {
    WebPData d;
    d.bytes = frame_webp(imgs[0], &d.size);
    if ((err = WebPMuxSetImage(mux, &d, 1)) != WEBP_MUX_OK) {
      i_push_errorf(err, "failed to set image (%d)", (int)err);
      WebPDataClear(&d);
      goto fail;
    }
    WebPDataClear(&d);
  }
  else {
    WebPMuxFrameInfo f;
    f.x_offset = f.y_offset = 0;
    f.duration = 1000/30;
    f.id = WEBP_CHUNK_ANMF;
    f.dispose_method = WEBP_MUX_DISPOSE_BACKGROUND;
    f.blend_method = WEBP_MUX_NO_BLEND;
    for (i = 0; i < count; ++i) {
      WebPData d;
      f.bitstream.bytes = frame_webp(imgs[i], &f.bitstream.size);
      WebPMuxPushFrame(mux, &f, 1);
      WebPDataClear(&f.bitstream);
    }
  }

  if ((err = WebPMuxAssemble(mux, &outd)) != WEBP_MUX_OK) {
    i_push_errorf((int)err, "failed to assemble %d", (int)err);
    goto fail;
  }

  if (i_io_write(ig, outd.bytes, outd.size) != outd.size) {
    i_push_error(errno, "failed to write");
    goto fail;
  }
  WebPDataClear(&outd);

  if (i_io_close(ig))
    goto fail;

  WebPMuxDelete(mux);
  return 1;

 fail:
  WebPMuxDelete(mux);
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
