# MediaOrganizer
 Organizes files typically used by photographers/videographers.
 
 Program is intended to be used with the organizer script executed on a NAS server, and the macOS application run on a client device. The NAS server must have mongod installed and a webserver capable of serving PHP pages
## Current Features
 #### Video Demonstration
 [![YouTube video demonstrating the current state of the software. Includes demos of photo grid scrolling, viewing photo details, and downloading files](https://img.youtube.com/vi/M8PEt7qT1SI/0.jpg)](https://www.youtube.com/watch?v=M8PEt7qT1SI)
 
 [This video](https://www.youtube.com/watch?v=M8PEt7qT1SI) demonstrates the current features of the Swift client program.
 ###### Organizer script
  * Copies files from source directory to a target directory where files are organized by date and file extension
  * Rips jpeg previews from LibRAW readable files and places them into a preview directory (/path/to/target/YEAR/MONTH/DAY/FILE_EXT/preview/FILENAME.prev.jpg)
  * Compresses jpeg previews into a smaller thumbnail for quick previews over network
  * Inserts a record into a mongodb collection containing file metadata and some exif data
 ###### MediaOrganizer macOS application
  * Displays all photos, retrieving a preview for each photo listed in the mongodb collection via a GET request to a PHP script
  * Caches thumbnails and a downsampled tiny thumbnail that is used when scrolling through images or when image sizes are small
  * Provides EXIF data for each image when clicked on
  * Allows downloading of photos, previews

## Todo 03/10
 ###### Organizer script
  - [ ] Ensure compatibility with multiple types of raw images (currently tested on CR3 files)
  - [ ] Add support for video files
    - [ ] Rip thumbnails, exif data for collection entry
    - [ ] Automatic Transcoding
  - [ ] Multithreaded thumbnail compressor + video transcoder
  - [ ] Easy install as a service on a linux machine
    * Automatically runs when storage containing media files is attached
    
 ###### MediaOrganizer app
  - [ ] File search (by extension, date, camera, etc.)
  - [ ] File multi-select and download
  - [ ] Uploads tab
  - [ ] Events tab - Can add files, or entire uploads to a new event
    * Events could contain info like location, client, notes
    * Later on, should be able to attach Photoshop/AfterEffects files to events and be able to download project files and all associated media with one button
  - [ ] iPhone and iPad compatibility
  - [ ] All-in-one mode: Files are organized and stored on user's main drive and external storage devices if selected, without need for a NAS
  
  ###### Dependencies / acknowledged libraries
  * LibRAW
  * jpeglib
  * MongoDB (mongoc, mongo-swift driver, mongo-php-driver)
  
## Build Instructions
 Client Program (MediaOrganizer) can be built with XCode after installing MongoSwift framework
 
 Organizer (MediaOrganizerCLI) can also be built with XCode after installing LibRAW, jpeglib, and mongo-c-driver.
  * Paths to library `include` and `lib` folders were hardcoded in the project.pbxproj header search paths. Make sure you update these paths for both the debug and release schemes. If you have installed the dependencies via Homebrew, they will either be located in `/opt/homebrew/Cellar` (ARM/M1), or in `/usr/local/` (Intel)
## Running Notes
  #### Running MediaOrganizerCLI
  * In XCode, MediaOrganizerCLI can be run by adding 4 arguments to its scheme:
    1. Source Directory: path to directory containing raw image files to be sorted
    2. Destination Directory: path to directory in which to store organized filesystem
    3. MongoDB uri
    4. MongoDB database name
  * If built and then run outside of XCode, run: `./MediaOrganizerCLI <source directory> <destination directory> <mongodb server url (ex. mongodb://localhost:27017)> <mongodb database name>`
  #### Setting up PHP API endpoint
  * Install PHP and a web server
  * Install MongoDB PHP Driver: `sudo pecl install mongodb`
  * Place request.php in public folder
  #### Setting up MediaOrganizer client
  * Click the gear icon or click MediaOrganizer->Preferences in the menu bar and set the mongodb and api request uri