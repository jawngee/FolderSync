#import <Foundation/Foundation.h>
#import "ILFolderSync.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
	NSString *src=[args stringForKey:@"src"];
	NSString *dest=[args stringForKey:@"dest"];
	BOOL dryRun=[args boolForKey:@"dry"];
	
	ILFolderSync *sync=[[ILFolderSync alloc] initWithSource:src andDest:dest];
	[sync run:dryRun];
	
    
	[pool drain];
    return 0;
}
