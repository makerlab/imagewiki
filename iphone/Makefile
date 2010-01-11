CC=arm-apple-darwin-gcc
LD=$(CC)
LDFLAGS=-ObjC -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit -framework PhotoLibrary -framework PhotoLibrary -framework CoreGraphics -framework Camera -framework GraphicsServices -framework OfficeImport -framework CoreTelephony
#LDFLAGS_FRAMEWORKSDIR=-F/Developer/SDKs/iphone/heavenly/System/Library/ 
#LDFLAGS_FRAMEWORKSDIR=-F/usr/local/share/iphonefs2/System/Library/

LDFLAGS=-mmacosx-version-min=10.1 -lobjc -framework CoreFoundation -framework Foundation -framework UIKit -framework LayerKit -framework CoreGraphics -framework PhotoLibrary -framework GraphicsServices -framework CoreTelephony -framework Camera -framework OfficeImport

all:	imagewiki	package

imagewiki:	ImageWiki.o ImageWikiApplication.o md5.o  toolchain_patch.o
	$(LD) $(LDFLAGS) -o $@ $^

%.o:	%.m %.h %.c
	$(CC) -I./ObjectiveFlickr.hmap -c $(CFLAGS) $(CPPFLAGS) $< -o $@ 

#%.o:    %.m
#		$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	rm -fr *.o imagewiki
	rm imagewiki.app/*

	
package: imagewiki
	cp imagewiki imagewiki.app/imagewiki
	cp Info.plist imagewiki.app/Info.plist
	cp icon.png imagewiki.app/icon.png
	cp play.gif imagewiki.app/play.gif
	cp stop.gif imagewiki.app/stop.gif
	cp snap.gif imagewiki.app/snap.gif
	cp Default.png imagewiki.app/Default.png

release:
	zip -r imagewiki.zip imagewiki.app
	md5 imagewiki.zip >md5value
	inject md5value checksum iphone.xml
	ls -b >filesize imagewiki.zip
	inject filesize filesize iphone.xml
 
