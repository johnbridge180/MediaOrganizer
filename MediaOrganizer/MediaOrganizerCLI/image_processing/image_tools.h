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

struct ImageData {
    char* prev_extension;
    const char* name;
    const char* original_path;
    libraw_data_t *raw_data;
    libraw_processed_image_t *preview;
};
extern ImageData new_ImageData(const char* name, const char* path);
extern int RAW_initializeDataHolder(ImageData data_holder);

extern int RAW_createThumbFile(ImageData data_holder, const char* const_path);
extern void RAW_createPreviewFile(ImageData data_holder, const char* output_path);

extern void write_prev(libraw_processed_image_t *img, const char *basename);
extern void write_ppm(libraw_processed_image_t *img, const char *basename);

#endif /* image_tools_h */
