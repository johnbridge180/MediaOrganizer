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

#include "mongo_tools.h"
#include "image_tools.h"

typedef struct Organizer *Organizer;
typedef struct MediaFile *MediaFile;
typedef struct MediaFileDate *MediaFileDate;
typedef struct Upload *Upload;
typedef struct MediaFileListNode *MediaFileListNode;

//path variables must not end in "/"

//Organizer struct and functions
struct Organizer {
    char *source_path;
    DIR* source;
    char *destination_path;
    DIR* destination;
    MongoDBClientHolder dbclient_holder;
};
extern Organizer new_Organizer(char* source, char* destination, MongoDBClientHolder dbclient_holder);

extern bool organize(Organizer organizer);
extern bool organizeDir(Organizer organizer, char* dir_path);

//MediaFile related structs and functions
struct MediaFile {
    char *name;
    char *filepath;
    char *extension;
    MediaFileDate date;
    char *destination_path;
    off_t size;
    bson_oid_t mongo_objectID;
};
extern MediaFile new_MediaFile(char* name, char* sourceDirectory);

extern bool MediaFile_setExtension(struct MediaFile *file);
extern bool MediaFile_setMetadata(MediaFile file);
extern bool MediaFile_setDestinationPath(Organizer organizer, MediaFile file);

struct MediaFileDate {
    char *month;
    char *day;
    char *year;
    __darwin_time_t unix_time;
};
extern MediaFileDate new_MediaFileDate(char* month, char* day, char* year, __darwin_time_t unix_time);

struct MediaFileListNode {
    MediaFile file;
    MediaFileListNode next;
};
extern MediaFileListNode new_MediaFileListNode(MediaFile value);

//Directory helper functions
extern bool validateFolder(char* folder);
extern bool createSubDirIfNotExist(DIR* dir, char* path);

//copyfile function accounting for macOS and Linux
extern bool copyFile(char* source, char* destination);

//string helper functions
extern void str_tolower(char* str);

extern int generatePreviewForMediaFile(Organizer organizer, MediaFile file);
extern int generateThumbnailForMediaFile(Organizer organizer, MediaFile file);

#endif /* organizer_h */
