/*

*/

#include "ImageDB.hpp"

#include <iostream>
#include <errno.h>

#include <sys/stat.h>
#include <unistd.h>


void usage(const char* progname)
{
    std::cerr << progname << " converts a database between text and binary formats.\n\n";
    std::cerr << "Usage: " << progname << " t <binary db file> <text db file>\n";
    std::cerr << "Usage: " << progname << " b <text db file> <binary db file>\n";
}

typedef std::list<std::string> StringList;

int main( int argc, char** argv )
{
    bool to_binary = true;
    const char *progname = argv[0];

    if (argc != 4) {
        usage(progname);
        return 1;
    }

    if (strcmp(argv[1], "t") == 0) {
        to_binary = false;
    } else if (strcmp(argv[1], "b") == 0) {
        to_binary = true;
    } else {
        std::cerr << "'" << argv[1] << "' is not an allowed conversion; must be 't' for text or 'b' for binary.\n";
        usage(progname);
        return 1;
    }

    ImageDB db;
    if (!db.load(argv[2], !to_binary)) {
        std::cerr << "Error loading ImageDB '" << argv[2] << "' ("
                  << strerror(errno) << ")\n";
        return 2;
    }

    std::cout << "Database " << argv[2] << " has " << db.num_images() << " entries.\n";

    if (!db.save(argv[3], to_binary)) {
        std::cerr << "Error saving ImageDB '" << argv[2] << "' ("
                  << strerror(errno) << ")\n";
        return 2;
    }

    return 0;
}
