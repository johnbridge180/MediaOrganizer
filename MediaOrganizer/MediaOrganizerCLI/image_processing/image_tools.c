//
//  image_tools.c
//  MediaOrganizerCLI
//
//  Created by John Bridge on 8/6/22.
//

#include "image_tools.h"

ImageData new_ImageData(const char* name, const char* path) {
    ImageData holder = malloc(sizeof(struct ImageData));
    if(holder==NULL)
        return NULL;
    holder->original_path = path;
    holder->name = name;
    return holder;
}

int RAW_initializeDataHolder(ImageData data_holder) {
    if(data_holder==NULL)
        return -9;
    libraw_data_t *raw_data = libraw_init(0);
    if(libraw_open_file(raw_data, data_holder->original_path) != LIBRAW_SUCCESS)
        return -1;
    
    libraw_unpack_thumb(raw_data);
    libraw_dcraw_process(raw_data);
    int err;
    libraw_processed_image_t *thumb = libraw_dcraw_make_mem_thumb(raw_data, &err);
    
    data_holder->prev_extension = thumb->type == LIBRAW_THUMBNAIL_JPEG ? "jpg" : "ppm";
    data_holder->raw_data = raw_data;
    data_holder->preview = thumb;
    return 0;
}

//CREDIT: libjpeg example.c
int RAW_createThumbFile(ImageData data_holder, const char* output_path) {
    libraw_dcraw_process(data_holder->raw_data);
    int err;
    libraw_processed_image_t *prev = libraw_dcraw_make_mem_thumb(data_holder->raw_data, &err);
    if (prev->type != LIBRAW_IMAGE_JPEG) {
        return -3;
    }
    struct jpeg_decompress_struct info;
    struct jpeg_error_mgr j_err;
    
    unsigned long int imgWidth, imgHeight;
    int numComponents;
    
    unsigned long int dwBufferBytes;
    unsigned char* lpData;
    
    unsigned char* lpRowBuffer[1];
    
    FILE* fHandle;
    fHandle = fmemopen(prev->data, prev->data_size, "rb");
    
    if(fHandle == NULL) {
        return -1;
    }
    
    info.err = jpeg_std_error(&j_err);
    jpeg_create_decompress(&info);
    
    jpeg_stdio_src(&info, fHandle);
    jpeg_read_header(&info, TRUE);
    
    info.dct_method = JDCT_IFAST;
    info.dither_mode = JDITHER_ORDERED;
    info.scale_num = 1;
    info.scale_denom = 4;
    info.two_pass_quantize = TRUE;
    
    jpeg_start_decompress(&info);
    imgWidth = info.output_width;
    imgHeight = info.output_height;
    numComponents = info.num_components;
    
    dwBufferBytes = imgWidth * imgHeight * 3;
    lpData = (unsigned char*)malloc(sizeof(unsigned char)*dwBufferBytes);
    
    while(info.output_scanline < info.output_height) {
        lpRowBuffer[0] = (unsigned char *)(&lpData[3*info.output_width*info.output_scanline]);
                jpeg_read_scanlines(&info, lpRowBuffer, 1);
    }
    
    jpeg_finish_decompress(&info);
    jpeg_destroy_decompress(&info);
    fclose(fHandle);
    
    //CREDIT: libjpeg example.c for sizeable amount of the rest of this function
    
    struct jpeg_compress_struct cinfo;
    
    struct jpeg_error_mgr jerr;
    unsigned char *mem = NULL;
    unsigned long mem_size;
    /* More stuff */
    FILE * outfile;        /* target file */
    JSAMPROW row_pointer[1];    /* pointer to JSAMPLE row[s] */
    int row_stride;        /* physical row width in image buffer */
    
    /* Step 1: allocate and initialize JPEG compression object */
    
    /* We have to set up the error handler first, in case the initialization
     * step fails.  (Unlikely, but it could happen if you are out of memory.)
     * This routine fills in the contents of struct jerr, and returns jerr's
     * address which we place into the link field in cinfo.
     */
    cinfo.err = jpeg_std_error(&jerr);
    /* Now we can initialize the JPEG compression object. */
    jpeg_create_compress(&cinfo);
    
    /* Step 2: specify data destination (eg, a file) */
    /* Note: steps 2 and 3 can be done in either order. */
    
    /* Here we use the library-supplied code to send compressed data to a
     * stdio stream.  You can also write your own code to do something else.
     * VERY IMPORTANT: use "b" option to fopen() if you are on a machine that
     * requires it in order to write binary files.
     */
    //jpeg_stdio_dest(&cinfo, outfile);
    jpeg_mem_dest(&cinfo, &mem, &mem_size);
    /* Step 3: set parameters for compression */
    
    /* First we supply a description of the input image.
     * Four fields of the cinfo struct must be filled in:
     */
    cinfo.image_width = info.output_width;     /* image width and height, in pixels */
    cinfo.image_height = info.output_height;
    cinfo.input_components = 3;        /* # of color components per pixel */
    cinfo.in_color_space = JCS_RGB;     /* colorspace of input image */
    /* Now use the library's routine to set default compression parameters.
     * (You must set at least cinfo.in_color_space before calling this,
     * since the defaults depend on the source color space.)
     */
    jpeg_set_defaults(&cinfo);
    /* Now you can set any non-default parameters you wish to.
     * Here we just illustrate the use of quality (quantization table) scaling:
     */
    jpeg_set_quality(&cinfo, 70, TRUE);
    
    /* Step 4: Start compressor */
    
    /* TRUE ensures that we will write a complete interchange-JPEG file.
     * Pass TRUE unless you are very sure of what you're doing.
     */
    jpeg_start_compress(&cinfo, TRUE);
    
    /* Step 5: while (scan lines remain to be written) */
    /*           jpeg_write_scanlines(...); */
    
    /* Here we use the library's state variable cinfo.next_scanline as the
     * loop counter, so that we don't have to keep track ourselves.
     * To keep things simple, we pass one scanline per call; you can pass
     * more if you wish, though.
     */
    row_stride = info.output_width * 3;    /* JSAMPLEs per row in image_buffer */
    
    while (cinfo.next_scanline < cinfo.image_height) {
        /* jpeg_write_scanlines expects an array of pointers to scanlines.
         * Here the array is only one element long, but you could pass
         * more than one scanline at a time if that's more convenient.
         */
        row_pointer[0] = & lpData[cinfo.next_scanline * row_stride];
        (void) jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    
    /* Step 6: Finish compression */
    
    jpeg_finish_compress(&cinfo);
    /* After finish_compress, we can close the output file. */
    if ((outfile = fopen(output_path, "wb")) == NULL) {
        fprintf(stderr, "can't open %s\n", output_path);
        exit(1);
    }
    //TODO: copy orientation EXIF data tag to output file (current issue - portrait photos result in landscape thumbnail)
    fwrite(mem, mem_size, 1, outfile);
    fclose(outfile);
    
    /* Step 7: release JPEG compression object */
    jpeg_destroy_compress(&cinfo);
    
    return 0;
}

void RAW_createPreviewFile(ImageData data_holder, const char* output_path) {
    libraw_dcraw_process(data_holder->raw_data);
    int err;
    libraw_processed_image_t *thumb = libraw_dcraw_make_mem_thumb(data_holder->raw_data, &err);
    write_prev(thumb, output_path);
}

void write_prev(libraw_processed_image_t *img, const char *output_path){
    if (!img)
        return;

    if (img->type == LIBRAW_IMAGE_BITMAP) {
        write_ppm(img, output_path);
    } else if (img->type == LIBRAW_IMAGE_JPEG) {
        FILE *f = fopen(output_path, "wb");
        if (!f)
            return;
        fwrite(img->data, img->data_size, 1, f);
        fclose(f);
    }
}

void write_ppm(libraw_processed_image_t *img, const char *output_path) {
    if (!img)
        return;
    // type SHOULD be LIBRAW_IMAGE_BITMAP, but we'll check
    if (img->type != LIBRAW_IMAGE_BITMAP)
        return;
    if (img->colors != 3 && img->colors != 1)
    {
        printf("Only monochrome and 3-color images supported for PPM output\n");
        return;
    }
    
    FILE *f = fopen(output_path, "wb");
    if (!f)
        return;
    fprintf(f, "P%d\n%d %d\n%d\n", img->colors/2 + 5, img->width, img->height, (1 << img->bits) - 1);
    /*
     NOTE:
     data in img->data is not converted to network byte order.
     So, we should swap values on some architectures for dcraw compatibility
     (unfortunately, xv cannot display 16-bit PPMs with network byte order data
     */
#define SWAP(a, b)                                                             \
{                                                                            \
a ^= b;                                                                    \
a ^= (b ^= a);                                                             \
}
    if (img->bits == 16 && htons(0x55aa) != 0x55aa)
        for (unsigned i = 0; i < img->data_size-1; i += 2)
            SWAP(img->data[i], img->data[i + 1]);
#undef SWAP
    
    fwrite(img->data, img->data_size, 1, f);
    fclose(f);
}
