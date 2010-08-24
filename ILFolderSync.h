//
//  ILFolderSync.h
//  FolderSync
//
//  Created by Jon Gilkison on 8/23/10.
//  Copyright 2010 Massify. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ILFolderSyncProtocol

@optional

-(void)foundFileWithDifferentDate:(NSString*)filename;
-(void)foundFileWithDifferentSize:(NSString*)filename;
-(void)foundMissingFile:(NSString*)filename;
-(void)startingCollection;
-(void)endingCollection;
-(void)startingTransfer;
-(void)endingTransfer;
-(void)copyingFile:(NSString*)filename number:(NSInteger)number of:(NSInteger)total;

@end


@interface ILFolderSync : NSObject 
{
	id<ILFolderSyncProtocol> delegate;
	NSDate *startDate;
	
	NSString *sourcePath;
	NSString *destPath;
	
	NSInteger notFoundFiles;
	NSInteger differentFiles;
	long long unsigned int bytesDifferent;
	
	NSInteger directoriesNotChanged;
	
	NSMutableArray *sourceFiles;
}

@property (retain, nonatomic) id<ILFolderSyncProtocol> delegate;


-(id)initWithSource:(NSString*)theSourcePath andDest:(NSString *)theDestPath;
-(void)run:(BOOL)dryRun;

@end
