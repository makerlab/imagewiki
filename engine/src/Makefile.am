AM_CFLAGS=`pkg-config --cflags opencv` `pkg-config --cflags gtk+-2.0` `pkg-config --cflags gsl` `xmlrpc-c-config abyss-server server-util --cflags`
AM_CXXFLAGS=`pkg-config --cflags opencv` `pkg-config --cflags gtk+-2.0` `pkg-config --cflags gsl` `xmlrpc-c-config c++ c++2 abyss-server server-util --cflags`
AM_LDFLAGS=`pkg-config --libs opencv` `pkg-config --libs gtk+-2.0` `pkg-config --libs gsl` `xmlrpc-c-config c++ c++2 abyss-server server-util --libs`

#lib_LIBRARIES=libsift.a
#libsift_a_SOURCES=imgfeatures.c kdtree.c minpq.c sift.c utils.c xform.c db.cpp

lib_LTLIBRARIES=libsift.la
libsift_la_SOURCES=imgfeatures.c kdtree.c minpq.c sift.c utils.c xform.c ImageDB.cpp


bin_PROGRAMS=db-add db-del db-list db-match db-convert db-server dspfeat siftfeat

db_add_SOURCES=db-add.cpp
db_add_LDADD=libsift.la

db_del_SOURCES=db-del.cpp
db_del_LDADD=libsift.la

db_list_SOURCES=db-list.cpp
db_list_LDADD=libsift.la

db_convert_SOURCES=db-convert.cpp
db_convert_LDADD=libsift.la

db_match_SOURCES=db-match.cpp
db_match_LDADD=libsift.la

db_server_SOURCES=db-server.cpp HTTPServer.cpp DBServer.cpp Thread.cpp MultipartParser.cpp Mutex.cpp
db_server_LDADD=libsift.la

dspfeat_SOURCES=dspfeat.c
dspfeat_LDADD=libsift.la

siftfeat_SOURCES=siftfeat.c
siftfeat_LDADD=libsift.la
