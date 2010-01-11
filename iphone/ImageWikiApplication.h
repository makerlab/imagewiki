/*
 
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; version 2
 of the License.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 
 */



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIPushButton.h>
#import <UIKit/UITableCell.h>
#import <UIKit/UIImageAndTextTableCell.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIAutocorrectImageView.h>
#import <UIKit/UITransitionView.h>
#import <UIKit/UIPreferencesTable.h>
#import <UIKit/UISegmentedControl.h>
#import <UIKit/UISwitchControl.h>
#import <UIKit/UISliderControl.h>
#import <UIKit/UIPreferencesTextTableCell.h>
#import <UIkit/UIProgressIndicator.h>
#import <UIkit/UITextLabel.h>
#import "CoreTelephony.h"

@class CameraController;
@class CameraView;

#define SHARED_SECRET "24ee98e4512d8d64"
#define API_KEY  "842d6482843a717b392add0864951ed6"

#define IMAGE_WIDTH 75
#define IMAGE_HEIGHT 75

// Utility Functions.
NSString* getmd5(char* str);
NSString* md5sig(NSDictionary* parameters) ;

typedef struct __CFMachPort *CFMachPortRef;

@interface ImageWikiApplication : UIApplication 
{	
	int       _currentView;
	NSString   *token;
	NSString* userid;
	NSString* password;
	NSString* tags;
	NSString* location;
	NSString* frob;

	int uploadQSize;	
	BOOL mLandscape;
	BOOL mStorePic;
	BOOL mIsPrivate;
	BOOL mGeoTag;
	BOOL isCachingNow;
	
	int mCurrentRotation;
	int mDeviceRotation;
	
	// Views
	CameraController* camController;
	CameraView* imageview;
	UIPreferencesTable *_pref;		
	UINavigationBar  *_navBar;
	UIPreferencesTextTableCell *userCell;
	UIPreferencesTextTableCell *passCell;
	UIPreferencesTextTableCell *tagCell;
	UITransitionView *_transitionView;
	UIProgressIndicator *progress;
	UIView *mainView;	
	UITextLabel* status;
	UIAlertSheet* alertSheet;
	UIAlertSheet* authorizeSheet;

	
	// Buttons
	UIPushButton* picButton;
	UIWindow *window;
	
	// Controls
	UISwitchControl* saveLocally;
	UISwitchControl* isPrivate;
	UISwitchControl* geotag;
		
	// UI Cells
	UIPreferencesTableCell* _saveCell;
	UIPreferencesTableCell* _privacyCell;
	UIPreferencesTableCell* _geoTagCell;
	
	// Location stuff.
	struct CTServerConnection *connection;
	CFMachPortRef ref;
	CFRunLoopSourceRef rlref;
	CFRunLoopRef currentRunLoop;
	void    *handle;
	
}

- (void) takePicture:(id)sender;
- (UIPreferencesTable *) createPrefPane;
- (UINavigationBar *) createNavBar;
- (int) numberOfGroupsInPreferencesTable:(UIPreferencesTable *)aTable;
- (int) preferencesTable:(UIPreferencesTable *)aTable numberOfRowsInGroup:(int)group;
- (UIPreferencesTableCell *) preferencesTable:(UIPreferencesTable *)aTable cellForGroup:(int)group;
- (UIPreferencesTableCell *) preferencesTable:(UIPreferencesTable *)aTable cellForRow:(int)row inGroup:(int)group;
- (float) preferencesTable:(UIPreferencesTable *)aTable heightForRow:(int)row inGroup:(int)group withProposedHeight:(float)proposed;
- (BOOL) preferencesTable:(UIPreferencesTable *)aTable isLabelGroup:(int)group;
- (void) setNavBar;
- (void) savePreferences;
- (void) loadPreferences;
//- (void) getFlickrData:(NSXMLElement*) e;
- (int) flickrUploadPic : (NSData*) jpeg;
- (void) compressImage:(CGImageRef)jpeg withFilename:(NSString*)filename;
//- (int) rotatePicture:(NSString*) pictureid degrees:(NSString*) deg;
- (NSString*) getNextFileNumberFromPhotoLibrary;
- (void) dealloc;
- (void) initlocation;
- (void) getCellInfo:(struct CellInfo) cellinfo;
- (void) cellConnect;
//- (NSString*) flickrApiCall:(NSString*) params;
//- (NSString*) signatureForCall:(NSDictionary*) parameters ;
- (int) uploadWithData:(NSData*) jpeg withTags:(NSString*)ptags withOrientation:(int)orientation withLocation:(NSString*)plocation isPrivate:(BOOL)privacy;
//- (void) sendCachedPics;
//- (int)getTokenWithFrob:(NSString*) frob;
//- (void) getFrob;
//- (int)authorizeFrob:(NSString*) pfrob;

#define CUR_BROWSER     0x00
#define CUR_PREFERENCES 0x01


@end
