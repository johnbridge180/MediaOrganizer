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
    holder->params = NULL;
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
    libraw_dcraw_clear_mem(thumb);
    //data_holder->preview = thumb;
    return 0;
}

void free_ImageData(ImageData data) {
    libraw_recycle_datastream(data->raw_data);
    libraw_recycle(data->raw_data);
    libraw_close(data->raw_data);
    if(data->params != NULL)
        free(data->params);
    free(data);
}

int RAW_setImageDataParams(ImageData data_holder) {
    ImageDataParams params = (ImageDataParams) malloc(sizeof(struct ImageDataParams));
    if(params==NULL)
        return -1;
    params->height = data_holder->raw_data->sizes.iheight;
    params->width = data_holder->raw_data->sizes.iwidth;
    params->flip = data_holder->raw_data->sizes.flip;
    
    //Record lens data
    params->lensname = data_holder->raw_data->lens.Lens;
    params->focal_length = data_holder->raw_data->lens.makernotes.CurFocal;
    //params->aperture = data_holder->params->aperture;
    //data_holder->raw_data->
    //params->aperture = data_holder->raw_data->lens.makernotes.CurAp;
    params->aperture = data_holder->raw_data->other.aperture;
    
    //record camera data
    params->make = data_holder->raw_data->idata.make;
    params->model = data_holder->raw_data->idata.model;
    params->shutter_speed = data_holder->raw_data->other.shutter;
    params->iso_speed = data_holder->raw_data->other.iso_speed;
    
    //set latitude/longitude arrays
    for(int i=0;i<3;i++) {
        params->latitude[i] = data_holder->raw_data->other.parsed_gps.latitude[i];
        params->longitude[i] = data_holder->raw_data->other.parsed_gps.longitude[i];
    }
    params->latitude_ref = data_holder->raw_data->other.parsed_gps.latref;
    params->longitude_ref = data_holder->raw_data->other.parsed_gps.longref;
    params->altitude = data_holder->raw_data->other.parsed_gps.altitude;
    params->altitude_ref = data_holder->raw_data->other.parsed_gps.altref;
    data_holder->params = params;
    return 0;
}

//CREDIT: libjpeg example.c
int RAW_createThumbFile(ImageData data_holder, const char* output_path) {
    RAW_setImageDataParams(data_holder);
    libraw_dcraw_process(data_holder->raw_data);
    int err;
    libraw_processed_image_t *prev = libraw_dcraw_make_mem_thumb(data_holder->raw_data, &err);
    if (prev->type != LIBRAW_IMAGE_JPEG) {
        return -3;
    }
    struct jpeg_decompress_struct info;
    struct jpeg_error_mgr j_err;
    
    unsigned long int imgWidth, imgHeight;
    
    unsigned long int dwBufferBytes;
    unsigned char* lpData;
    
    unsigned char* lpRowBuffer[1];
    
    FILE* fHandle;
    fHandle = fmemopen(prev->data, prev->data_size, "rb");
    
    uint16_t readTag;
    fread(&readTag,2,1,fHandle);
    //TODO: make exif reader/writer endian-independent
    //LITTLE ENDIAN ONLY RN vvvv
    readTag = (readTag << 8) | (readTag >> 8);
    unsigned char* exifData = NULL;
    uint16_t exifData_size=0;
    if(readTag==0xFFD8) {
        while(readTag != 0xFFE1 && readTag != 0xFFD9) {
            fread(&readTag,2,1,fHandle);
            readTag = (readTag << 8) | (readTag >> 8);
        }
        if(readTag==0xFFE1) {
            fread(&readTag,2,1,fHandle);
            readTag = (readTag << 8) | (readTag >> 8);
            exifData_size=readTag;
            fseek(fHandle,-2L,SEEK_CUR);
            exifData=malloc(exifData_size);
            fread(exifData, readTag, 1, fHandle);
        } else if(readTag==0xFFD9) {
            printf("EOF w/ no APP1 Block");
        }
    } else {
        printf("not valid JPEG, file starts with 2byte tag: %x",readTag);
    }
    
    fseek(fHandle, 0, SEEK_SET);
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
    info.scale_denom = 8;
    info.two_pass_quantize = TRUE;
    
    jpeg_start_decompress(&info);
    imgWidth = info.output_width;
    imgHeight = info.output_height;
    
    dwBufferBytes = imgWidth * imgHeight * 3;
    lpData = (unsigned char*)malloc(sizeof(unsigned char)*dwBufferBytes);
    
    while(info.output_scanline < info.output_height) {
        lpRowBuffer[0] = (unsigned char *)(&lpData[3*info.output_width*info.output_scanline]);
                jpeg_read_scanlines(&info, lpRowBuffer, 1);
    }
    
    jpeg_finish_decompress(&info);
    jpeg_destroy_decompress(&info);
    fclose(fHandle);
    libraw_dcraw_clear_mem(prev);
    
    //CREDIT: libjpeg example.c for sizeable amount of the rest of this function
    
    struct jpeg_compress_struct cinfo;
    
    struct jpeg_error_mgr jerr;
    unsigned char *mem = NULL;
    unsigned long mem_size;
    
    FILE * outfile;        /* target file */
    JSAMPROW row_pointer[1];    /* pointer to JSAMPLE row[s] */
    int row_stride;        /* physical row width in image buffer */
    cinfo.err = jpeg_std_error(&jerr);
    
    jpeg_create_compress(&cinfo);
    
    jpeg_mem_dest(&cinfo, &mem, &mem_size);

    cinfo.image_width = info.output_width;
    cinfo.image_height = info.output_height;
    cinfo.input_components = 3;        /* # of color components per pixel */
    cinfo.in_color_space = JCS_RGB;

    jpeg_set_defaults(&cinfo);

    jpeg_set_quality(&cinfo, 90, TRUE);
    
    /* TRUE ensures that we will write a complete interchange-JPEG file.
     * Pass TRUE unless you are very sure of what you're doing.
     */
    jpeg_start_compress(&cinfo, TRUE);
    
    row_stride = info.output_width * 3;    /* JSAMPLEs per row in image_buffer */
    
    while (cinfo.next_scanline < cinfo.image_height) {
        row_pointer[0] = & lpData[cinfo.next_scanline * row_stride];
        (void) jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    
    free(lpData);
    /* After finish_compress, we can close the output file. */
    if ((outfile = fopen(output_path, "wb")) == NULL) {
        fprintf(stderr, "can't open %s\n", output_path);
        exit(1);
    }
    if(exifData_size>0) {
        FILE* buffer_stream = fmemopen(mem, mem_size, "rb");
        //copy EXIF data tag to output file if exists in original thumbnail
        uint16_t readTag_2;
        fread(&readTag_2,2,1,buffer_stream);
        readTag_2 = (readTag_2 << 8) | (readTag_2 >> 8);
        while(readTag_2 != 0xFFE0 && readTag_2 != 0xFFD9) {
            readTag_2 = (readTag_2 << 8) | (readTag_2 >> 8);
            fwrite(&readTag_2, 2, 1, outfile);
            
            fread(&readTag_2,2,1,buffer_stream);
            readTag_2 = (readTag_2 << 8) | (readTag_2 >> 8);
        }
        if(readTag_2==0xFFE0) {
            fread(&readTag_2,2,1,buffer_stream);
            readTag_2 = (readTag_2 << 8) | (readTag_2 >> 8);
            fseek(buffer_stream, (readTag_2-2), SEEK_CUR);
            
            fputc(0xFF, outfile);fputc(0xE1, outfile);
            fwrite(exifData,exifData_size,1,outfile);
        } else if(readTag_2==0xFFD9) {
            fwrite(&readTag_2,2,1,outfile);
        } else {
            
        }
        char gotten_char = fgetc(buffer_stream);
        while(feof(buffer_stream)==0) {
            fputc(gotten_char,outfile);
            gotten_char = fgetc(buffer_stream);
        }
        fclose(buffer_stream);
        free(exifData);
    } else {
        fwrite(mem, mem_size, 1, outfile);
    }
    fclose(outfile);
    free(mem);
    
    /* Step 7: release JPEG compression object */
    jpeg_destroy_compress(&cinfo);
    
    return 0;
}

void RAW_createPreviewFile(ImageData data_holder, const char* output_path) {
    libraw_dcraw_process(data_holder->raw_data);
    int err;
    libraw_processed_image_t *thumb = libraw_dcraw_make_mem_thumb(data_holder->raw_data, &err);
    write_prev(thumb, output_path);
    libraw_dcraw_clear_mem(thumb);
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
