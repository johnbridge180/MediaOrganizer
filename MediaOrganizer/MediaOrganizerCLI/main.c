//
//  main.c
//  MediaOrganizerCLI
//
//  Created by John Bridge on 8/3/22.
//

#include <stdio.h>
#include "organizer.h"

int main(int argc, char * argv[]) {
    if(argc != 5) {
        printf("Program requires four arguments.\nRun ./MediaOrganizerCLI <source directory> <destination directory> <mongodb server url (ex. mongodb://localhost:27017)> <mongodb database name>\n");
        return 1;
    }
    MongoDBClientHolder mongo_holder = new_MongoDBClientHolder(argv[3], argv[4]);
    createDefaultMongoDBCollections(mongo_holder);
    Organizer organizer = new_Organizer(argv[1], argv[2], mongo_holder);
    organize(organizer);
    free_Organizer(organizer);
    freeDBClientHolder(mongo_holder);
    return 0;
}
