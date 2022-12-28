//
//  organizer.c
//  MediaOrganizer
//
//  Created by John Bridge on 7/29/22.
//

#include "organizer.h"

bool organizeDir(Organizer organizer, char* dir_path) {
    DIR* dir = opendir(dir_path);

    MediaFileListNode node = new_MediaFileListNode(NULL);
    MediaFileListNode first_node = node;
    
    mongoc_bulk_operation_t *bulk = NULL;
    bson_oid_t upload_oid;
    
    if(organizer->dbclient_holder != NULL && organizer->dbclient_holder->uploads_collection != NULL && organizer->dbclient_holder->files_collection != NULL) {
        //create upload entry
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
        
        //begin bulk entry of files
        bulk = mongoc_collection_create_bulk_operation_with_opts(organizer->dbclient_holder->files_collection, NULL);
    }
    
    struct dirent *dp;
    while((dp = readdir(dir)) != NULL) {
        if(strcmp(dp->d_name, ".") != 0 && strcmp(dp->d_name, "..") != 0) {
            //if dir, organize subdirectory
            DIR* o_dir = opendir(dp->d_name);
            if(o_dir != NULL) {
                size_t new_dir_path_size = strlen(dir_path)+strlen(dp->d_name)+2;
                char new_dir_path[new_dir_path_size];
                snprintf(new_dir_path, new_dir_path_size, "%s/%s", dir_path, dp->d_name);
                if(!organizeDir(organizer, new_dir_path)) {
                    printf("organize dir recursion failed");
                    free_MediaFileListNode(first_node);
                    //DO ERR Handling here
                    return false;
                }
                closedir(o_dir);
            }
            size_t mediafile_path_size = strlen(dir_path)+strlen(dp->d_name)+2;
            char mediafile_path[mediafile_path_size];
            snprintf(mediafile_path, mediafile_path_size, "%s/%s", dir_path, dp->d_name);
            //initialize MediaFile struct and set values properly
            MediaFile file = new_MediaFile(dp->d_name, mediafile_path);
            if(!MediaFile_setExtension(file)) {
                //TODO: error handling
                free_MediaFile(file);
                free_MediaFileListNode(first_node);
                return false;
            }
            if(!MediaFile_setMetadata(file)) {
                free_MediaFile(file);
                free_MediaFileListNode(first_node);
                //TODO: error handling
                return false;
            }
            if(!MediaFile_setDestinationPath(organizer, file)) {
                free_MediaFile(file);
                free_MediaFileListNode(first_node);
                //TODO: error handling
                return false;
            }
            MediaFileListNode new_node = new_MediaFileListNode(file);
            if(new_node == NULL) {
                printf("Fatal err: Could not allocate memory to create MediaFileListNode!");
                
                free_MediaFile(file);
                free_MediaFileListNode(first_node);
                return false;
            }
            node->next = new_node;
            node = new_node;

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
            }
        }
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
            free_MediaFileListNode(first_node);
            return false;
        }
        bson_destroy(&reply);
        mongoc_bulk_operation_destroy(bulk);
    }
    closedir(dir);
    //TODO: PROCESS THUMB+PREVIEW THREAD SPLIT HERE
    MediaFileListNode original_holder_node = first_node;
    first_node = first_node->next;
    while(first_node != NULL) {
        generatePreviewForMediaFile(organizer,first_node->file);
        generateThumbnailForMediaFile(organizer,first_node->file);
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
    free_MediaFileListNode(original_holder_node);
    return true;
}

bool organize(Organizer organizer) {
    return organizeDir(organizer, organizer->source_path);
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
        free(organizer);
        return NULL;
    }
    organizer->source_path = strdup(source);
    organizer->destination_path = strdup(destination);
    organizer->dbclient_holder = dbclient_holder;
    return organizer;
}
void free_Organizer(Organizer organizer) {
    free(organizer->source_path);
    closedir(organizer->source);
    free(organizer->destination_path);
    closedir(organizer->destination);
    //assuming dbclientholder freed elsewhere
    free(organizer);
}

//MediaFile functions
MediaFile new_MediaFile(char* name, char* filepath) {
    MediaFile file = (MediaFile) malloc(sizeof(struct MediaFile));
    if(file==NULL) {
        //TODO: DO ERROR HANDLING HERE
        printf("MEDIAFILE NULL");
        return NULL;
    }
    file->name = strdup(name);
    file->filepath = strdup(filepath);
    file->date = NULL;
    file->destination_path = NULL;
    file->extension = NULL;
    return file;
}

void free_MediaFile(MediaFile file) {
    if(file != NULL) {
        if(file->date != NULL)
            free_MediaFileDate(file->date);
        free(file->name);
        free(file->filepath);
        if(file->destination_path != NULL)
            free(file->destination_path);
        if(file->extension != NULL)
            free(file->extension);
        free(file);
    }
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

bool MediaFile_setMetadata(MediaFile file) {
    struct stat filestat;
    if(stat(file->filepath, &filestat)) {
        printf("stat error at %s",file->filepath);
        //TODO: DO ERROR HANDLING HERE
        printf("%s",strerror(errno));
        return false;
    }
    struct tm *time = localtime(&filestat.st_birthtimespec.tv_sec);
    size_t day_size = (int)log10(time->tm_mday)+2;
    char day[day_size];
    char year[5];
    const char* month = "Unknown";
    snprintf(day, day_size, "%d", time->tm_mday);
    snprintf(year, 5, "%d", time->tm_year+1900);
    switch(time->tm_mon) {
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
        default:
            month="Unknown";
    }
    char* day_copy = strdup(day);
    char* year_copy = strdup(year);
    file->date = new_MediaFileDate(month, day_copy, year_copy, filestat.st_birthtimespec.tv_sec);
    if(file->date == NULL) {
        free(day_copy);
        free(year_copy);
        return false;
    }
    file->size = filestat.st_size;
    return true;
}

bool MediaFile_setDestinationPath(Organizer organizer, MediaFile file) {
    if(!createSubDirIfNotExist(organizer->destination_path,file->date->year))
        return NULL;
    //+2 1 for '/' char and 1 for '\0' char
    size_t year_dir_path_size = strlen(organizer->destination_path)+strlen(file->date->year)+2;
    char year_dir_path[year_dir_path_size];
    snprintf(year_dir_path, year_dir_path_size, "%s/%s", organizer->destination_path, file->date->year);
    if(!createSubDirIfNotExist(year_dir_path, file->date->month))
        return NULL;
    size_t month_dir_path_size = strlen(year_dir_path)+strlen(file->date->month)+2;
    char month_dir_path[month_dir_path_size];
    snprintf(month_dir_path, month_dir_path_size, "%s/%s", year_dir_path, file->date->month);
    if(!createSubDirIfNotExist(month_dir_path, file->date->day))
        return NULL;
    size_t day_dir_path_size = strlen(month_dir_path)+strlen(file->date->day)+2;
    char day_dir_path[day_dir_path_size];
    snprintf(day_dir_path,day_dir_path_size, "%s/%s", month_dir_path, file->date->day);
    
    createSubDirIfNotExist(day_dir_path, file->extension);
    size_t ext_dir_path_size = strlen(day_dir_path)+strlen(file->extension)+2;
    char ext_dir_path[ext_dir_path_size];
    snprintf(ext_dir_path,ext_dir_path_size, "%s/%s", day_dir_path, file->extension);
    
    size_t destination_path_size = strlen(ext_dir_path)+strlen(file->name)+2;
    char destination_path[destination_path_size];
    snprintf(destination_path,destination_path_size, "%s/%s", ext_dir_path, file->name);
    file->destination_path = strdup(destination_path);
    return true;
}

MediaFileDate new_MediaFileDate(const char* month, char* day, char* year, __darwin_time_t unix_time) {
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
void free_MediaFileDate(MediaFileDate date) {
    free(date->day);
    free(date->year);
    free(date);
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
void free_MediaFileListNode(MediaFileListNode node) {
    free_MediaFile(node->file);
    if(node->next != NULL)
        free_MediaFileListNode(node->next);
    free(node);
}

//Directory helper functions
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
        printf("%s",strerror(errno));
        return false;
    } else {
        //TODO: DO ERROR HANDLING HERE
        printf("%s",strerror(errno));
        return false;
    }
}

bool createSubDirIfNotExist(const char* parent_folder_path, const char* path) {
    DIR* dir = opendir(parent_folder_path);
    if(dir==NULL) {
        printf("Could not open directory \"%s\"",parent_folder_path);
        return false;
    }
    if(mkdirat(dirfd(dir), path, S_IRWXU | S_IRWXG | S_IRWXO) && (errno != EEXIST)) {
        printf("%s",strerror(errno));
        closedir(dir);
        return false;
    }
    closedir(dir);
    return true;
}

//copyfile function with different fns fir macos and linux
bool copyFile(char* source, char* destination) {
        //Here we use kernel-space copying for performance reasons
    #if defined(__APPLE__) || defined(__FreeBSD__)
        //fcopyfile works on FreeBSD and OS X 10.5+
        //int result = fcopyfile(input, output, 0, COPYFILE_ALL);
        int result = copyfile(source, destination, 0, COPYFILE_ALL);
    #else
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


//string helper functions
void str_tolower(char* str) {
    for(int i=0;i<strlen(str);i++) {
        str[i] = tolower(str[i]);
    }
}

int generatePreviewForMediaFile(Organizer organizer, MediaFile file) {
    ImageData previews_data = new_ImageData(file->name,file->filepath);
    RAW_initializeDataHolder(previews_data);
    if(previews_data==NULL)
        return -1;

    int length = (int) strlen(file->destination_path);
    int slash_location = -1;
    for(int i=length-1; i>=0; i--) {
        if (file->destination_path[i]=='/') {
            slash_location = i;
            break;
        }
    }
    if(slash_location == -1) {
        return -1;
    }
    char *containing_folder = malloc(sizeof(char)*(slash_location+2));
    memcpy(containing_folder, &file->destination_path[0], slash_location+1);
    containing_folder[slash_location+1] = '\0';
    if(!createSubDirIfNotExist(containing_folder, "preview")) {
        free(containing_folder);
        return -2;
    }
        
    //-1 for '.' +1 for '\0'
    char* name_noextension = malloc(sizeof(char)*(strlen(file->name)-strlen(file->extension)));
    memcpy(name_noextension,&file->name[0],strlen(file->name)-1-strlen(file->extension));
    //-1 for . +1 for '\0'
    name_noextension[strlen(file->name)-1-strlen(file->extension)] = '\0';
    
    //8=strlen("preview/")
    //5=strlen(".prev")
    //1=strlen(".") then strlen(previews_data->prev_extension)
    //1 +1 for ending
    size_t prev_output_path_size = strlen(containing_folder)+strlen(name_noextension)+strlen(previews_data->prev_extension)+15;
    char prev_output_path[prev_output_path_size];

    snprintf(prev_output_path, prev_output_path_size, "%spreview/%s.prev.%s",containing_folder,name_noextension, previews_data->prev_extension);
    RAW_createPreviewFile(previews_data, prev_output_path);
    
    //Insert path into MongoDB
    if(organizer->dbclient_holder != NULL) {
        bson_error_t error;
        bson_t reply;
        bson_t *query = BCON_NEW("_id",BCON_OID(&file->mongo_objectID));
        bson_t *update = BCON_NEW("$set",
                                  "{",
                                  "prev_path",BCON_UTF8(prev_output_path),
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
    
    free(containing_folder);
    free(name_noextension);
    free_ImageData(previews_data);
    return 0;
}

int generateThumbnailForMediaFile(Organizer organizer, MediaFile file) {
    ImageData previews_data = new_ImageData(file->name,file->filepath);
    RAW_initializeDataHolder(previews_data);
    if(previews_data==NULL)
        return -1;

    int length = (int) strlen(file->destination_path);
    int slash_location = -1;
    for(int i=length-1; i>=0; i--) {
        if (file->destination_path[i]=='/') {
            slash_location = i;
            break;
        }
    }
    if(slash_location == -1) {
        return -1;
    }
    
    char *containing_folder = malloc(sizeof(char)*(slash_location+2));
    memcpy(containing_folder, &file->destination_path[0], slash_location+1);
    containing_folder[slash_location+1] = '\0';
    if(!createSubDirIfNotExist(containing_folder, "preview")) {
        free(containing_folder);
        return -2;
    }
    // -1 for '.' +1 for '\0'
    char* name_noextension = malloc(sizeof(char)*(strlen(file->name)-strlen(file->extension)));
    memcpy(name_noextension,&file->name[0],strlen(file->name)-1-strlen(file->extension));
    name_noextension[strlen(file->name)-1-strlen(file->extension)] = '\0';
    
    //8=strlen("preview/")
    //6=strlen(".thumb")
    //1=. then strlen(previews_data->prev_extension)
    //1 +1 for '\0'
    size_t prev_output_path_size = strlen(containing_folder)+strlen(name_noextension)+strlen(previews_data->prev_extension)+16;
    char prev_output_path[prev_output_path_size];
    if(strcmp(previews_data->prev_extension, "ppm")==0) {
        free_ImageData(previews_data);
        printf("No PPM thumb functionality yet\n");
        free(name_noextension);
        free(containing_folder);
        //NO PPM THUMB FUNC YET;
        return -1;
    }
    snprintf(prev_output_path, prev_output_path_size, "%spreview/%s.thumb.%s",containing_folder,name_noextension, previews_data->prev_extension);
    RAW_createThumbFile(previews_data, prev_output_path);

    //Insert path into MongoDB
    if(organizer->dbclient_holder != NULL) {
        bson_error_t error;
        bson_t reply;
        bson_t *query = BCON_NEW("_id",BCON_OID(&file->mongo_objectID));
        bson_t *update = BCON_NEW("$set",
                                  "{",
                                  "thumb_path",BCON_UTF8(prev_output_path),
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
    uploadExifData(organizer, file, previews_data);
    free(containing_folder);
    free(name_noextension);
    free_ImageData(previews_data);
    return 0;
}

int uploadExifData(Organizer organizer, MediaFile file, ImageData image) {
    if(image->params == NULL)
        return -1;
    bson_error_t error;
    bson_t reply;
    
    char latref_string[2] = {image->params->latitude_ref,'\0'};
    char longref_string[2] = {image->params->longitude_ref,'\0'};
    char altref_string[2] = {image->params->altitude_ref, '\0'};
    
    bson_t *lat_doc = BCON_NEW("degrees",BCON_DOUBLE(image->params->latitude[0]),"minutes",BCON_DOUBLE(image->params->latitude[1]),"seconds",BCON_DOUBLE(image->params->latitude[2]));
    
    bson_t *long_doc = BCON_NEW("degrees",BCON_DOUBLE(image->params->longitude[0]),"minutes",BCON_DOUBLE(image->params->longitude[1]),"seconds",BCON_DOUBLE(image->params->longitude[2]));
    
    bson_t *gps_doc = BCON_NEW(
                               "latitude",BCON_DOCUMENT(lat_doc),
                               "latitude_ref",BCON_UTF8(latref_string),
                               "longitude",BCON_DOCUMENT(long_doc),
                               "longitude_ref",BCON_UTF8(longref_string),
                               "altitude",BCON_DOUBLE(image->params->altitude),
                               "altitude_ref",BCON_UTF8(altref_string));
    bson_t *doc = BCON_NEW("make",BCON_UTF8(image->params->make),
                           "model",BCON_UTF8(image->params->model),
                           "shutter_speed",BCON_DOUBLE(image->params->shutter_speed),
                           "lens",BCON_UTF8(image->params->lensname),
                           "focal_length",BCON_DOUBLE(image->params->focal_length),
                           "aperture",BCON_DOUBLE(image->params->aperture),
                           "flip",BCON_INT32(image->params->flip),
                           "gps_data",BCON_DOCUMENT(gps_doc));
    
    bson_t *query = BCON_NEW("_id",BCON_OID(&file->mongo_objectID));
    bson_t *update = BCON_NEW("$set",
                              "{",
                              "exif_data",BCON_DOCUMENT(doc),
                              "}");
    if(!mongoc_collection_update_one(organizer->dbclient_holder->files_collection, query, update, NULL, &reply, &error)) {
        fprintf (stderr, "%s\n", error.message);
        bson_destroy(lat_doc);
        bson_destroy(long_doc);
        bson_destroy(gps_doc);
        bson_destroy(doc);
        bson_destroy(query);
        bson_destroy(update);
        return -2;
    }
    
    char *str = bson_as_canonical_extended_json(&reply, NULL);
    printf("%s\n", str);
    bson_free(str);
    
    bson_destroy(lat_doc);
    bson_destroy(long_doc);
    bson_destroy(gps_doc);
    bson_destroy(doc);
    bson_destroy(query);
    bson_destroy(update);
    
    return 0;
}
