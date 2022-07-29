//
//  organizer.c
//  MediaOrganizer
//
//  Created by John Bridge on 7/29/22.
//

#include "organizer.h"


bool validateFolder(char* folder) {
    DIR* dir = opendir(folder);
    if(dir != NULL) {
        closedir(dir);
        free(dir);
        return false;
    } else if(ENOENT == errno) {
        struct stat st = {0};
        if (stat(folder, &st) == -1) {
            return mkdir(folder, S_IRWXU | S_IRWXG | S_IRWXO);
        }
        return false;
    } else {
        return false;
    }
}

Organizer new_Organizer(char* source, char* destination) {
    Organizer organizer = (Organizer) malloc(sizeof(struct Organizer));
    if(organizer==NULL) {
        return NULL;
    }
    if(validateFolder(source) && validateFolder(destination)) {
        organizer->source = opendir(source);
        organizer->destination = opendir(destination);
    } else {
        return NULL;
    }
    organizer->source_path = source;
    organizer->destination_path = destination;
    return organizer;
}

DIR* openValidDir(char* path) {
    if(validateFolder(path)) {
        return opendir(path);
    } else {
        return NULL;
    }
}
