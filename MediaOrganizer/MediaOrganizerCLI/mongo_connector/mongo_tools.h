//
//  mongo_tools.h
//  MediaOrganizerTool
//
//  Created by John Bridge on 8/3/22.
//

#ifndef mongo_tools_h
#define mongo_tools_h

//#include <mongoc.h>
#include <stdio.h>
#include <mongoc/mongoc.h>

typedef struct MongoDBClientHolder *MongoDBClientHolder;
struct MongoDBClientHolder {
    mongoc_database_t *database;
    mongoc_client_t *client;
    const char* db_name;
    mongoc_collection_t *files_collection;
    mongoc_collection_t *uploads_collection;
};

extern MongoDBClientHolder new_MongoDBClientHolder(const char* uri_string, const char* db_name);

extern int createDefaultMongoDBCollections(MongoDBClientHolder dbclient_holder);
extern int createMongoDBCollections(MongoDBClientHolder dbclient_holder, const char* files_collection_name, const char* upload_group_name, const char* events_name);

#endif /* mongo_tools_h */
