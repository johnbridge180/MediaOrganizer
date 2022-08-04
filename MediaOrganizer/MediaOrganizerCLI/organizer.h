//
//  organizer.h
//  MediaOrganizer
//
//  Created by John Bridge on 7/29/22.
//

#ifndef organizer_h
#define organizer_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <math.h>
#include <dirent.h>
#include <sys/errno.h>
#include <ctype.h>

#if defined(__APPLE__) || defined(__FreeBSD__)
#include <copyfile.h>
#else
#include <sys/sendfile.h>
#endif


typedef struct Organizer *Organizer;
typedef struct MediaFile *MediaFile;
typedef struct MediaFileDate *MediaFileDate;

struct Organizer {
    //SOURCE_PATH MUST NOT END IN "/"
    char *source_path;
    DIR* source;
    //DESTINATION_PATH MUST NOT END IN "/"
    char *destination_path;
    DIR* destination;
};
struct MediaFile {
    char *name;
    char *filepath;
    char *extension;
    MediaFileDate date;
    char *destination_path;
};
struct MediaFileDate {
    char *month;
    char *day;
    char *year;
};

extern char* getFileExtension(char* filepath);
extern bool validateFolder(char* folder);
extern DIR* openValidDir(char* path);
extern bool organize(Organizer organizer);
extern bool organizeDir(Organizer organizer, char* dir_path);
extern bool createSubDirIfNotExist(DIR* dir, char* path);
extern bool setDestinationPath(Organizer organizer, MediaFile file);
extern bool copyFile(char* source, char* destination);

extern void str_tolower(char* str);

extern bool organizeFile(Organizer organizer, MediaFile file);

extern MediaFile new_MediaFile(char* name, char* sourceDirectory);
extern bool MediaFile_setExtension(struct MediaFile *file);
extern MediaFileDate new_MediaFileDate(char* month, char* day, char* year);
extern bool MediaFile_setDate(MediaFile file);

extern Organizer new_Organizer(char* source, char* destination);

#endif /* organizer_h */
