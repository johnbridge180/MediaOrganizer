//
//  organizer.c
//  MediaOrganizer
//
//  Created by John Bridge on 7/29/22.
//

#include "organizer.h"

bool organize(Organizer organizer) {
    return organizeDir(organizer, organizer->source_path);
}

//dir_path must NOT end in "/"
bool organizeDir(Organizer organizer, char* dir_path) {
    DIR* dir = opendir(dir_path);
    struct dirent *dp;
    MediaFileListNode node = NULL;
    MediaFileListNode first_node = NULL;
    first_node=node=new_MediaFileListNode(NULL);
    
    mongoc_bulk_operation_t *bulk = NULL;
    bson_oid_t upload_oid;
    if(organizer->dbclient_holder != NULL && organizer->dbclient_holder->uploads_collection != NULL && organizer->dbclient_holder->files_collection != NULL) {
        //create upload
        bson_error_t error;
        bson_t reply;
        
        bson_t *upload_doc = bson_new();
        
        bson_oid_init (&upload_oid, NULL);
        BSON_APPEND_OID (upload_doc, "_id", &upload_oid);
        
        struct timeval tv;

        gettimeofday(&tv, NULL);
        
        unsigned long long millisecondsSinceEpoch =
            (unsigned long long)(tv.tv_sec) * 1000 +
            (unsigned long long)(tv.tv_usec) / 1000;
        BSON_APPEND_DATE_TIME(upload_doc, "time", millisecondsSinceEpoch);
        if(!mongoc_collection_insert_one(organizer->dbclient_holder->uploads_collection, upload_doc, NULL, &reply, &error)) {
            fprintf(stderr, "%s\n", error.message);
        }

        bson_destroy(upload_doc);
        
        bulk = mongoc_collection_create_bulk_operation_with_opts(organizer->dbclient_holder->files_collection, NULL);
        printf("hi");
    }
    
    while((dp = readdir(dir)) != NULL) {
        if(strcmp(dp->d_name, ".") != 0 && strcmp(dp->d_name, "..") != 0) {
            //check if dir
            if(opendir(dp->d_name) != NULL) {
                char new_dir_path[strlen(dir_path)+strlen(dp->d_name)+1];
                sprintf(new_dir_path, "%s/%s", dir_path, dp->d_name);
                if(!organizeDir(organizer, new_dir_path))
                    printf("organize dir recursion failed");
                    //DO ERR Handling here
                    return false;
            }
            //do organizing of files here
            char mediafile_path[strlen(dir_path)+strlen(dp->d_name)+1];
            sprintf(mediafile_path, "%s/%s", dir_path, dp->d_name);
            MediaFile file = new_MediaFile(dp->d_name, mediafile_path);
            if(MediaFile_setExtension(file)) {
                if(MediaFile_setMetadata(file)) {
                    if(!setDestinationPath(organizer, file)) {
                        //TODO: error handling
                        return false;
                    }
                    MediaFileListNode new_node = new_MediaFileListNode(file);
                    node->next = new_node;
                    node = new_node;
                    printf("1: %s",file->destination_path);
                    if(organizer->dbclient_holder != NULL && bulk != NULL) {
                        bson_oid_init (&file->mongo_objectID, NULL);
                        bson_t *file_doc = BCON_NEW("_id",BCON_OID(&file->mongo_objectID),
                                                    "path",BCON_UTF8(file->destination_path),
                                                    "time",BCON_DATE_TIME(file->date->unix_time*1000),
                                                    "name",BCON_UTF8(file->name),
                                                    "extension",BCON_UTF8(file->extension),
                                                    "upload_id",BCON_OID(&upload_oid),
                                                    "size",BCON_INT64(file->size),
                                                    "upload_complete",BCON_BOOL(false));
                        mongoc_bulk_operation_insert(bulk,file_doc);
                        bson_destroy(file_doc);
                        printf("2: %s",file->destination_path);
                    }
                } else {
                    //TODO: error handling
                    return false;
                }
            } else {
                //TODO: error handling
                return false;
            }
        }
        //printf("File created at: %s",ctime(&filestat.st_birthtime));
    }
    if(bulk != NULL) {
        bson_t reply;
        bson_error_t error;
        if(mongoc_bulk_operation_execute(bulk, &reply, &error)) {
            char *str = bson_as_canonical_extended_json(&reply, NULL);
               printf("%s\n", str);
               bson_free(str);
        } else {
            fprintf (stderr, "Error: %s\n", error.message);
            return false;
        }
        bson_destroy(&reply);
        mongoc_bulk_operation_destroy(bulk);
    }
    first_node = first_node->next;
    while(first_node != NULL) {
        printf("%s",first_node->file->filepath);
        printf("%s",first_node->file->destination_path);
        copyFile(first_node->file->filepath, first_node->file->destination_path);
        
        //do mongo update
        if(organizer->dbclient_holder != NULL) {
            bson_error_t error;
            bson_t reply;
            bson_t *query = BCON_NEW("_id",BCON_OID(&first_node->file->mongo_objectID));
            bson_t *update = BCON_NEW("$set",
                                      "{",
                                      "upload_complete",BCON_BOOL(true),
                                      "}");
            if(!mongoc_collection_update_one(organizer->dbclient_holder->files_collection, query, update, NULL, &reply, &error)) {
                fprintf (stderr, "%s\n", error.message);
            } else {
                char *str = bson_as_canonical_extended_json(&reply, NULL);
                printf("%s\n", str);
                bson_free(str);
            }
            bson_destroy(query);
            bson_destroy(update);
        }
        
        first_node = first_node->next;
    }
    return true;
}

bool copyFile(char* source, char* destination) {
        //Here we use kernel-space copying for performance reasons
    #if defined(__APPLE__) || defined(__FreeBSD__)
        //fcopyfile works on FreeBSD and OS X 10.5+
        //int result = fcopyfile(input, output, 0, COPYFILE_ALL);
        int result = copyfile(source, destination, 0, COPYFILE_ALL);
    #else
        printf("it thinks we're using linux");
        //sendfile will work with non-socket output (i.e. regular file) on Linux 2.6.33+
        int input, output;
        if ((input = open(source, O_RDONLY)) == -1) {
            return -1;
        }
        if ((output = creat(destination, 0777)) == -1) {
            close(input);
            return -1;
        }
        off_t bytesCopied = 0;
        struct stat fileinfo = {0};
        fstat(input, &fileinfo);
        int result = sendfile(output, input, &bytesCopied, fileinfo.st_size);
        close(input);
        close(output);
    #endif
        return !result;
}

bool setDestinationPath(Organizer organizer, MediaFile file) {
    if(!createSubDirIfNotExist(organizer->destination,file->date->year))
        return NULL;
    char year_dir_path[strlen(organizer->destination_path)+strlen(file->date->year)+1];
    sprintf(year_dir_path, "%s/%s", organizer->destination_path, file->date->year);
    if(!createSubDirIfNotExist(opendir(year_dir_path), file->date->month))
        return NULL;
    char month_dir_path[strlen(year_dir_path)+strlen(file->date->month)+1];
    sprintf(month_dir_path, "%s/%s", year_dir_path, file->date->month);
    if(!createSubDirIfNotExist(opendir(month_dir_path), file->date->day))
        return NULL;
    char day_dir_path[strlen(month_dir_path)+strlen(file->date->day)+1];
    sprintf(day_dir_path, "%s/%s", month_dir_path, file->date->day);
    
    createSubDirIfNotExist(opendir(day_dir_path), file->extension);
    char ext_dir_path[strlen(day_dir_path)+strlen(file->extension)+1];
    sprintf(ext_dir_path, "%s/%s", day_dir_path, file->extension);
    
    char destination_path[strlen(ext_dir_path)+strlen(file->name)+1];
    sprintf(destination_path, "%s/%s", ext_dir_path, file->name);
    file->destination_path = strdup(destination_path);
    return true;
}

bool createSubDirIfNotExist(DIR* dir, char* path) {
    if(mkdirat(dirfd(dir), path, S_IRWXU | S_IRWXG | S_IRWXO) && errno != EEXIST) {
        printf(strerror(errno));
        return false;
    }
    return true;
}

bool MediaFile_setExtension(MediaFile file) {
    int length = (int) strlen(file->name);
    int dot_location = -1;
    for(int i=length-1; i>=0; i--) {
        if (file->name[i]=='.') {
            dot_location = i;
            break;
        }
    }
    if(dot_location == -1) {
        return false;
    }
    file->extension = malloc(length-dot_location);
    memcpy(file->extension, &file->name[dot_location+1], length-dot_location);
    file->extension[length-dot_location-1] = '\0';
    str_tolower(file->extension);
    return true;
}
void str_tolower(char* str) {
    for(int i=0;i<strlen(str);i++) {
        str[i] = tolower(str[i]);
    }
}
bool MediaFile_setMetadata(MediaFile file) {
    struct stat filestat;
    if(stat(file->filepath, &filestat)) {
        printf("stat error at %s",file->filepath);
        //TODO: DO ERROR HANDLING HERE
        printf(strerror(errno));
        return false;
    }
    struct tm *time = localtime(&filestat.st_birthtimespec.tv_sec);
    char* day = malloc(sizeof(char)*(int)log10(time->tm_mday));
    char* year = malloc(sizeof(char)*(int)log10(time->tm_year+1900));
    char* month = "Unknown";
    sprintf(day, "%d", time->tm_mday);
    sprintf(year, "%d", time->tm_year+1900);
    switch(time->tm_mon) {
        default:
            month="Unknown";
        case 0:
            month="January";
            break;
        case 1:
            month="February";
            break;
        case 2:
            month="March";
            break;
        case 3:
            month="April";
            break;
        case 4:
            month="May";
            break;
        case 5:
            month="June";
            break;
        case 6:
            month="July";
            break;
        case 7:
            month="August";
            break;
        case 8:
            month="September";
            break;
        case 9:
            month="October";
            break;
        case 10:
            month="November";
            break;
        case 11:
            month="December";
            break;
    }
    file->date = new_MediaFileDate(month, day, year, filestat.st_birthtimespec.tv_sec);
    file->size = filestat.st_size;
    return true;
}

MediaFileListNode new_MediaFileListNode(MediaFile value) {
    MediaFileListNode node = (MediaFileListNode) malloc(sizeof(struct MediaFileListNode));
    if(node==NULL) {
        printf("node NULL");
        return NULL;
    }
    node->file = value;
    node->next = NULL;
    return node;
}

bool validateFolder(char* folder) {
    DIR* dir = opendir(folder);
    if(dir != NULL) {
        closedir(dir);
        //free(dir);
        return true;
    } else if(ENOENT == errno) {
        struct stat st = {0};
        if (stat(folder, &st) == -1) {
            return mkdir(folder, S_IRWXU | S_IRWXG | S_IRWXO);
        }
        //TODO: DO ERROR HANDLING HERE
        printf(strerror(errno));
        return false;
    } else {
        //TODO: DO ERROR HANDLING HERE
        printf(strerror(errno));
        return false;
    }
}

MediaFile new_MediaFile(char* name, char* filepath) {
    MediaFile file = (MediaFile) malloc(sizeof(struct MediaFile));
    if(file==NULL) {
        //TODO: DO ERROR HANDLING HERE
        printf("MEDIAFILE NULL");
        return NULL;
    }
    file->name = strdup(name);
    file->filepath = strdup(filepath);
    return file;
}
MediaFileDate new_MediaFileDate(char* month, char* day, char* year, __darwin_time_t unix_time) {
    MediaFileDate date = (MediaFileDate) malloc(sizeof(struct MediaFileDate));
    if(date==NULL) {
        printf("DATE NULL");
        return NULL;
    }
    date->month = month;
    date->day = day;
    date->year = year;
    date->unix_time = unix_time;
    return date;
}
Organizer new_Organizer(char* source, char* destination, MongoDBClientHolder dbclient_holder) {
    Organizer organizer = (Organizer) malloc(sizeof(struct Organizer));
    if(organizer==NULL) {
        printf("organizer null");
        //TODO: DO ERROR HANDLING HERE
        return NULL;
    }
    if(validateFolder(source) && validateFolder(destination)) {
        organizer->source = opendir(source);
        organizer->destination = opendir(destination);
    } else {
        printf("folder validation failed");
        return NULL;
    }
    organizer->source_path = strdup(source);
    organizer->destination_path = strdup(destination);
    organizer->dbclient_holder = dbclient_holder;
    return organizer;
}

DIR* openValidDir(char* path) {
    if(validateFolder(path)) {
        return opendir(path);
    } else {
        //TODO: DO ERROR HANDLING HERE
        return NULL;
    }
}
