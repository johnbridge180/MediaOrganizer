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
#include <dirent.h>
#include <errno.h>

typedef struct Organizer *Organizer;

struct Organizer {
    char* source_path;
    DIR* source;
    char* destination_path;
    DIR* destination;
};

extern bool validateFolder(char* folder);
extern Organizer new_Organizer(char* source, char* destination);
extern DIR* openValidDir(char* path);

#endif /* organizer_h */
