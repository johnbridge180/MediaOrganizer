//
//  image_tools.h
//  MediaOrganizerCLI
//
//  Created by John Bridge on 8/6/22.
//

#ifndef image_tools_h
#define image_tools_h

#include <stdio.h>
#include <libraw.h>
#include <jpeglib.h>
#include <jerror.h>

typedef struct ImageData *ImageData;
typedef struct ImageDataParams *ImageDataParams;

struct ImageData {
    char* prev_extension;
    const char* name;
    const char* original_path;
    libraw_data_t *raw_data;
    libraw_processed_image_t *preview;
    ImageDataParams params;
};
extern ImageData new_ImageData(const char* name, const char* path);
extern int RAW_initializeDataHolder(ImageData data_holder);
extern void free_ImageData(ImageData data);

extern void free_processed_image(libraw_processed_image_t* image);

struct ImageDataParams {
    //image data
    int flip;           //orientation of image
    uint16_t width;
    uint16_t height;
    
    //lens data
    char *lensname;
    float focal_length;
    float aperture;
    
    //camera data
    char *make;
    char *model;
    float shutter_speed;
    
    //gps data
    float latitude[3];
    char latitude_ref;
    float longitude[3];
    char longitude_ref;
    float altitude;
    char altitude_ref;
};
extern int RAW_setImageDataParams(ImageData data_holder);

extern int RAW_createThumbFile(ImageData data_holder, const char* const_path);
extern void RAW_createPreviewFile(ImageData data_holder, const char* output_path);

extern void write_prev(libraw_processed_image_t *img, const char *basename);
extern void write_ppm(libraw_processed_image_t *img, const char *basename);

#endif /* image_tools_h */
