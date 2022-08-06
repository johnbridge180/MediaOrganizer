//
//  mongo_tools.c
//  MediaOrganizerTool
//
//  Created by John Bridge on 8/3/22.
//

#include "mongo_tools.h"

MongoDBClientHolder new_MongoDBClientHolder(const char* uri_string, const char* db_name) {
    mongoc_uri_t *uri;
    mongoc_client_t *client;
    mongoc_server_api_t *api;
    bson_error_t error;
    mongoc_database_t *database;

    mongoc_init();

    uri = mongoc_uri_new_with_error (uri_string, &error);
    client = mongoc_client_new_from_uri(uri);

    api = mongoc_server_api_new (MONGOC_SERVER_API_V1);
    mongoc_client_set_server_api (client, api, &error);
    
    mongoc_client_set_appname(client, "MediaOrganizer");

    database = mongoc_client_get_database(client, db_name);

    MongoDBClientHolder client_holder = malloc(sizeof(struct MongoDBClientHolder));
    if(client_holder==NULL) {
    	return NULL;
    }
    client_holder->client = client;
    client_holder->database = database;
    client_holder->db_name = db_name;
    return client_holder;
}

int createDefaultMongoDBCollections(MongoDBClientHolder dbclient_holder) {
    return createMongoDBCollections(dbclient_holder, "files", "upload_groups", "events");
}
int createMongoDBCollections(MongoDBClientHolder dbclient_holder, const char* files_collection_name, const char* uploads_collection_name, const char* events_collection_name) {
    //Create events collection
    if(events_collection_name != NULL) {
        struct _bson_error_t error1;
        
        //set options
        bson_t *opts = bson_new();
        
        mongoc_collection_t *events_collection = mongoc_database_create_collection(dbclient_holder->database, files_collection_name, opts, &error1);
        
        //create indexes
        bson_t time_index_keys;
        bson_t name_index_keys;
        
        bson_init(&time_index_keys);
        BSON_APPEND_INT32(&time_index_keys, "time", -1);
        
        bson_init(&name_index_keys);
        BSON_APPEND_UTF8(&name_index_keys, "name", "text");
        
        bson_t *create_indexes = BCON_NEW("createIndexes",
                                          BCON_UTF8(events_collection_name),
                                          "indexes",
                                          "[",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&time_index_keys),
                                          "name",
                                          BCON_UTF8("event_time"),
                                          "}",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&name_index_keys),
                                          "name",
                                          BCON_UTF8("event_name"),
                                          "}",
                                          "]");
        bson_t reply;
        bson_error_t error;
        bool r;
        r = mongoc_database_write_command_with_opts (
              dbclient_holder->database, create_indexes, NULL /* opts */, &reply, &error);
        
        printf ("%s\n", bson_as_json(&reply, NULL));
        if(!r) {
            fprintf (stderr, "Error in createIndexes for events collection: %s\n", error.message);
        }
        
        //free memory
        bson_destroy(&reply);
        bson_destroy(create_indexes);
        bson_free(opts);
        mongoc_collection_destroy(events_collection);
        //bson_free(error1);
    }
    
    //Create uploads collection
    if(uploads_collection_name != NULL) {
        struct _bson_error_t error1;
        
        //set options
        bson_t *opts = bson_new();
        
        mongoc_collection_t *uploads_collection = mongoc_database_create_collection(dbclient_holder->database, uploads_collection_name, opts, &error1);
        fprintf (stderr, "Error in createIndexes for uploads collection: %s\n", error1.message);
        
        //create indexes
        bson_t time_index_keys;
        bson_t completed_index_keys;
        
        bson_init(&time_index_keys);
        bson_init(&completed_index_keys);
        BSON_APPEND_INT32(&time_index_keys, "time", -1);
        BSON_APPEND_INT32(&completed_index_keys, "completed",1);
        
        bson_t *create_indexes = BCON_NEW("createIndexes",
                                          BCON_UTF8(uploads_collection_name),
                                          "indexes",
                                          "[",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&time_index_keys),
                                          "name",
                                          BCON_UTF8("upload_time"),
                                          "}",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&completed_index_keys),
                                          "name",
                                          BCON_UTF8("upload_completed_bool"),
                                          "}",
                                          "]");
        bson_t reply;
        bson_error_t error;
        bool r;
        r = mongoc_database_write_command_with_opts (
              dbclient_holder->database, create_indexes, NULL /* opts */, &reply, &error);
        
        printf ("%s\n", bson_as_json(&reply, NULL));
        if(!r) {
            fprintf (stderr, "Error in createIndexes for uploads collection: %s\n", error.message);
        }
        
        //free memory
        bson_destroy(&reply);
        bson_destroy(create_indexes);
        bson_free(opts);
        mongoc_collection_destroy(uploads_collection);
        dbclient_holder->uploads_collection = mongoc_client_get_collection(dbclient_holder->client, dbclient_holder->db_name, uploads_collection_name);
        //bson_free(error1);
    }
    
    //Create files collection
    if(files_collection_name != NULL) {
        struct _bson_error_t error1;
        
        //set options
        bson_t *opts = bson_new();
        
        //create collection
        mongoc_collection_t *files_collection = mongoc_database_create_collection(dbclient_holder->database, files_collection_name, opts, &error1);
        
        //create indexes
        bson_t timeextension_index_keys;
        bson_t eventid_index_keys;
        bson_t uploadid_index_keys;
        
        
        bson_init(&timeextension_index_keys);
        bson_init(&eventid_index_keys);
        bson_init(&uploadid_index_keys);
        
        BSON_APPEND_INT32(&timeextension_index_keys, "time", -1);
        BSON_APPEND_UTF8(&timeextension_index_keys, "extension", "text");
        
        BSON_APPEND_INT32(&eventid_index_keys, "event_id", 1);
        
        BSON_APPEND_INT32(&uploadid_index_keys, "upload_id", 1);
        
        bson_t *create_indexes = BCON_NEW("createIndexes",
                                          BCON_UTF8(files_collection_name),
                                          "indexes",
                                          "[",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&timeextension_index_keys),
                                          "name",
                                          BCON_UTF8("files_timeextension"),
                                          "}",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&eventid_index_keys),
                                          "name",
                                          BCON_UTF8("files_eventid"),
                                          "}",
                                          "{",
                                          "key",
                                          BCON_DOCUMENT(&uploadid_index_keys),
                                          "name",
                                          BCON_UTF8("files_uploadid"),
                                          "}",
                                          "]");
        bson_t reply;
        bson_error_t error;
        bool r;
        r = mongoc_database_write_command_with_opts (
              dbclient_holder->database, create_indexes, NULL /* opts */, &reply, &error);
        
        printf ("%s\n", bson_as_json(&reply, NULL));
        if(!r) {
            fprintf (stderr, "Error in createIndexes for files collection: %s\n", error.message);
        }
        
        //free memory
        bson_destroy(&reply);
        bson_destroy(create_indexes);
        bson_free(opts);
        mongoc_collection_destroy(files_collection);
        dbclient_holder->files_collection = mongoc_client_get_collection(dbclient_holder->client, dbclient_holder->db_name, files_collection_name);
    }
    return 0;
}
