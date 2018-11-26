#include "imwebp.h"
#include "webp/mux.h"
#include "webp/encode.h"
#include "webp/decode.h"
#include "imext.h"
#include <errno.h>

#define START_SLURP_SIZE 8192
#define next_slurp_size(old) ((size_t)((old) * 3 / 2) + 10)

static unsigned char *
slurpio(io_glue *ig, size_t *size) {
  size_t alloc_size = START_SLURP_SIZE;
  unsigned char *data = mymalloc(alloc_size);
  ssize_t rdsize = i_io_read(ig, data, alloc_size);

  *size = 0;
  while (rdsize > 0) {
    *size += rdsize;
    if (alloc_size < START_SLURP_SIZE + *size) {
      size_t new_alloc = next_slurp_size(alloc_size);
      data = myrealloc(data, new_alloc);
      alloc_size = new_alloc;
    }
    rdsize = i_io_read(ig, data+*size, (alloc_size - *size));
  }

  if (rdsize < 0) {
    i_push_error(errno, "failed to read");
    myfree(data);
    return NULL;
  }

  /* maybe free up some space */
  data = myrealloc(data, *size);

  return data;
}

static i_img *
get_image(WebPMux *mux, int n, int *error) {
  WebPMuxFrameInfo f;
  WebPMuxError err;
  WebPBitstreamFeatures feat;
  VP8StatusCode code;
  i_img *img;

  *error = 0;
  if ((err = WebPMuxGetFrame(mux, n, &f)) != WEBP_MUX_OK) {
    if (err != WEBP_MUX_NOT_FOUND) {
      i_push_errorf(err, "failed to read %d", (int)err);
      *error = 1;
    }
    return NULL;
  }

  if ((code = WebPGetFeatures(f.bitstream.bytes, f.bitstream.size, &feat))
      != VP8_STATUS_OK) {
    WebPDataClear(&f.bitstream);
    i_push_errorf((int)code, "failed to get features (%d)", (int)code);
    return NULL;
  }

  if (feat.has_alpha) {
    int width, height;
    int y;
    uint8_t *bmp = WebPDecodeRGBA(f.bitstream.bytes, f.bitstream.size,
				 &width, &height);
    uint8_t *p = bmp;
    if (!bmp) {
      WebPDataClear(&f.bitstream);
      i_push_error(0, "failed to decode");
      *error = 1;
      return NULL;
    }
    img = i_img_8_new(width, height, 4);
    for (y = 0; y < height; ++y) {
      i_psamp(img, 0, width, y, p, NULL, 4);
      p += width * 4;
    }
    WebPFree(bmp);
  }
  else {
    int width, height;
    int y;
    uint8_t *bmp = WebPDecodeRGB(f.bitstream.bytes, f.bitstream.size,
				 &width, &height);
    uint8_t *p = bmp;
    if (!bmp) {
      WebPDataClear(&f.bitstream);
      i_push_error(0, "failed to decode");
      *error = 1;
      return NULL;
    }
    img = i_img_8_new(width, height, 3);
    for (y = 0; y < height; ++y) {
      i_psamp(img, 0, width, y, p, NULL, 3);
      p += width * 3;
    }
    WebPFree(bmp);
  }
  WebPDataClear(&f.bitstream);

  i_tags_set(&img->tags, "i_format", "webp", 4);
  
  return img;
}

i_img *
i_readwebp(io_glue *ig, int page) {
  WebPMux *mux;
  i_img *img;
  unsigned char *mdata;
  WebPData data;
  int n;
  int imgs_alloc = 0;
  int error;

  i_clear_error();
  if (page < 0) {
    i_push_error(0, "page must be non-negative");
    return NULL;
  }

  data.bytes = mdata = slurpio(ig, &data.size);
  
  mux = WebPMuxCreate(&data, 0);

  if (!mux) {
    myfree(mdata);
    i_push_error(0, "Cannot create mux object.  ABI mismatch?");
    return NULL;
  }

  img = get_image(mux, page+1, &error);
  if (img == NULL && !error) {
    i_push_error(0, "No such image");
  }

  WebPMuxDelete(mux);
  myfree(mdata);
  
  return img;
}

i_img **
i_readwebp_multi(io_glue *ig, int *count) {
  WebPMux *mux;
  i_img *img;
  unsigned char *mdata;
  WebPData data;
  int n;
  i_img **result = NULL;
  int imgs_alloc = 0;
  int error;

  data.bytes = mdata = slurpio(ig, &data.size);
  
  mux = WebPMuxCreate(&data, 0);

  if (!mux) {
    myfree(mdata);
    i_push_error(0, "Cannot create mux object.  ABI mismatch?");
    return NULL;
  }

  n = 1;
  img = get_image(mux, n++, &error);
  *count = 0;
  while (img) {
    if (*count == imgs_alloc) {
      imgs_alloc += 10;
      result = myrealloc(result, imgs_alloc * sizeof(i_img *));
    }
    result[(*count)++] = img;
    img = get_image(mux, n++, &error);
  }

  WebPMuxDelete(mux);
  myfree(mdata);
  
  return result;
#if 0
 fail:
  myfree(data);
  WebPMuxDelete(mux);
  return NULL;
#endif
}

undef_int
i_writewebp(i_img *im, io_glue *ig) {
  return i_writewebp_multi(ig, &im, 1);
}

static const int gray_chans[4] = { 0, 0, 0, 1 };

static unsigned char *
frame_raw(i_img *im, int *out_chans) {
  unsigned char *data, *p;
  i_img_dim y;
  const int *chans = im->channels < 3 ? gray_chans : NULL;
  *out_chans = (im->channels & 1) ? 3 : 4;
  data = mymalloc(im->xsize * im->ysize * *out_chans);
  p = data;
  for (y = 0; y < im->ysize; ++y) {
    i_gsamp(im, 0, im->xsize, y, p, chans, *out_chans);
    p += *out_chans * im->xsize;
  }

  return data;
}

static unsigned char *
frame_webp(i_img *im, size_t *sz) {
  int chans;
  unsigned char *raw = frame_raw(im, &chans);
  uint8_t *webp;
  size_t webp_size;
  if (chans == 4) {
    webp_size = WebPEncodeRGBA(raw, im->xsize, im->ysize, im->xsize * chans, 80, &webp);
  }
  else {
    webp_size = WebPEncodeRGB(raw, im->xsize, im->ysize, im->xsize * chans, 80, &webp);
  }
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
    return 0;
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

char const *
i_webp_libversion(void) {
  static char buf[80];
  if (!*buf) {
    unsigned int mux_ver = WebPGetMuxVersion();
    sprintf(buf, "mux %d.%d.%d (%x)", mux_ver >> 16, (mux_ver >> 8) & 0xFF, mux_ver & 0xFF, mux_ver);
  }
  return buf;
}
