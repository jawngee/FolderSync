//
//  ILFolderSync.m
//  FolderSync
//
//  Created by Jon Gilkison on 8/23/10.
//  Copyright 2010 Massify. All rights reserved.
//

#import "ILFolderSync.h"

@interface ILFolderSync(private)

-(NSArray *)sortedFiles:(NSString*)path;
-(void)collectFiles:(NSString*)forPath;

@end


@implementation ILFolderSync

@synthesize delegate;

NSInteger lastModifiedSort(id path1, id path2, void* context)
{
	NSComparisonResult res=[[path1 objectForKey:@"lastModDate"] compare: [path2 objectForKey:@"lastModDate"]];

	if (res==NSOrderedAscending)
		return NSOrderedDescending;
	else if (res==NSOrderedDescending)
		return NSOrderedAscending;
	
	return NSOrderedSame;
}

void ILLog(NSString *format, ...) 
{
    va_list args;
    va_start(args, format);
    NSString *formattedString = [[NSString alloc] initWithFormat: format
													   arguments: args];
    va_end(args);
	
	NSData *data=[formattedString dataUsingEncoding:NSUTF8StringEncoding];
    [[NSFileHandle fileHandleWithStandardOutput] writeData:data];
	[formattedString release];
}

-(id)initWithSource:(NSString*)theSourcePath andDest:(NSString *)theDestPath
{
	if ((self=[super init]))
	{
		sourceFiles=[[[NSMutableArray alloc] init] retain];
		sourcePath=[theSourcePath retain];
		destPath=[theDestPath retain];
		
		differentFiles=0;
		notFoundFiles=0;
		
		directoriesNotChanged=0;
	
		ILLog(@"Source: %@\n",sourcePath);
		ILLog(@"Destination: %@\n",destPath);
	}
	
	return self;
}

-(void)dealloc
{
	[sourceFiles release];
	[super dealloc];
}

-(NSArray *)sortedFiles:(NSString*)path
{
	ILLog(@"Reading %@ ",path);
    NSError* error = nil;
	
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path
                                                                         error:&error];
    
	ILLog(@" - %d files and directories\n",[files count]);
	if(error == nil)
    {
        NSMutableArray* filesAndProperties = [NSMutableArray arrayWithCapacity:[files count]];
        ILLog(@"Sorting ");
		for(NSString* file in files)
        {
			ILLog(@".");
            NSDictionary* properties = [[NSFileManager defaultManager]
                                        attributesOfItemAtPath:[path stringByAppendingPathComponent:file]
                                        error:&error];
            if(error == nil)
            {
                [filesAndProperties addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                               file, @"path",
											   [properties fileModificationDate], @"lastModDate",
											   [NSNumber numberWithUnsignedLongLong:[properties fileSize]], @"fileSize",
                                               nil]];                 
            }
			else NSLog(@"ERROR:%@",error);
        }
		
		ILLog(@"\n");
        NSArray *what=[filesAndProperties sortedArrayUsingFunction:&lastModifiedSort context:nil];
		return what;
    }
    else
    {
        NSLog(@"Encountered error while accessing contents of %@: %@", path, error);
    }
	
	return [NSArray array];
}

-(void)collectFiles:(NSString*)forPath
{
	NSString *thePath=[sourcePath stringByAppendingPathComponent:forPath];
	
	NSFileManager *fileManager=[NSFileManager defaultManager];
	
	NSArray *files=[self sortedFiles:thePath];
	for(NSDictionary *fileDict in files)
	{
		NSString *file=[fileDict objectForKey:@"path"];
		NSDate *sourceDate=[fileDict objectForKey:@"lastModDate"];
		long long unsigned int sfsize=[[fileDict objectForKey:@"fileSize"] unsignedLongLongValue];
		
		BOOL isDirectory=NO;
		
		[fileManager fileExistsAtPath:[thePath stringByAppendingPathComponent:file] isDirectory:&isDirectory];
		
		if (isDirectory==YES)
		{
			[self collectFiles:[forPath stringByAppendingPathComponent:file]];
		}
		else
		{
			file=[forPath stringByAppendingPathComponent:file];
			
			if ([fileManager fileExistsAtPath:[destPath stringByAppendingPathComponent:file]]==YES)
			{
				NSDictionary *destAttr=[fileManager attributesOfItemAtPath:[destPath stringByAppendingPathComponent:file] error:nil];
				
				long long unsigned int dfsize=[destAttr fileSize];
				
				// compare sizes
				NSDate *destDate=[destAttr fileModificationDate];
				
				if (([sourceDate isEqualToDate:destDate]==NO) || ([sourceDate isGreaterThan:destDate]))
				{
					differentFiles++;
					[sourceFiles addObject:file];
					directoriesNotChanged=0;
					bytesDifferent+=sfsize;
				}
				else if (sfsize!=dfsize)
				{
					differentFiles++;
					[sourceFiles addObject:file];
					directoriesNotChanged=0;
					bytesDifferent+=sfsize;
				}
			}
			else 
			{
				notFoundFiles++;
				[sourceFiles addObject:file];
				directoriesNotChanged=0;
				bytesDifferent+=sfsize;
			}
		}
	}
	
	ILLog(@"Not found: %d\n",notFoundFiles);
	ILLog(@"Different: %d\n",differentFiles);
	ILLog(@"File Size: %0.02fGB\n\n\n",(float)bytesDifferent/(1024.0*1024.0*1024.0));
	directoriesNotChanged++;
}

-(void)run:(BOOL)dryRun
{
	if (dryRun)
		ILLog(@"Dry Run\n");
	else
		ILLog(@"Live Run\n");
	
	startDate=[NSDate date];
	
	[self collectFiles:@""];
	
	NSTimeInterval runTime=[[NSDate date] timeIntervalSinceDate:startDate];
	
	ILLog(@"Scan Run Time: %f\n",runTime);
	ILLog(@"File Count: %d\n\n",[sourceFiles count]);
	
	NSFileManager *currentManager=[NSFileManager defaultManager];
	for(NSString *file in sourceFiles)
	{
		NSString *srcFile=[sourcePath stringByAppendingPathComponent:file];
		NSString *srcPath=[sourcePath stringByDeletingLastPathComponent];
		NSString *dstFile=[destPath stringByAppendingPathComponent:file];
		NSString *dstPath=[dstFile stringByDeletingLastPathComponent];
		
		if (!dryRun)
		{
			if ([currentManager fileExistsAtPath:dstPath]==NO)
			{
				[currentManager createDirectoryAtPath:dstPath withIntermediateDirectories:YES attributes:nil error:nil];
			}
			
			NSDictionary *srcFileAttrs=[currentManager attributesOfItemAtPath:srcFile error:nil];
			
			ILLog(@"Copying %@ to %@ ... ",srcFile, dstFile);
			
			[currentManager copyItemAtPath:srcFile toPath:dstFile error:nil];
			[currentManager setAttributes:srcFileAttrs ofItemAtPath:dstFile error:nil];
			NSDictionary *srcPathAttrs=[currentManager attributesOfItemAtPath:srcPath error:nil];
			[currentManager setAttributes:srcPathAttrs ofItemAtPath:dstPath error:nil];
			ILLog(@"Done.\n");
		}
		
	}

	runTime=[[NSDate date] timeIntervalSinceDate:startDate];
	
	ILLog(@"\nTotal Run Time: %f\n",runTime);
}


@end
