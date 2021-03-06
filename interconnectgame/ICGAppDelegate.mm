//
//  ICGAppDelegate.m
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-11-24.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ICGAppDelegate.h"
#import "eleven_chatclient.h"
#import "eleven_asset_client.h"
#import <WebKit/WebKit.h>
#import "ICGKeychainWrapper.h"
#import "ICGMapView.h"
#import "ICGGameView.h"


using namespace eleven;
using namespace interconnect;


@interface ICGAppDelegate ()
{
	chatclient*							mChatClient;
	std::string							mCurrentRoomName;
	uint32_t							mPrimaryMissionID;
	std::map<uint32_t,mission_entry>	mMissions;
	object_vector						mCurrentMap;
	object_vector						mProjectedMap;
	object_vector						mCulledMap;
}

@property (strong) IBOutlet NSWindow *loginWindow;
@property (strong) IBOutlet NSTextField *userNameField;
@property (strong) IBOutlet NSTextField *passwordField;
@property (strong) IBOutlet NSProgressIndicator *progressSpinner;
@property (strong) IBOutlet NSButton *logInButton;
@property (strong) IBOutlet NSButton *quitButton;
@property (strong) IBOutlet ICGMapView *mapView;
@property (strong) IBOutlet ICGGameView *gameView;
@property (strong) IBOutlet WebView *webView;
@property (strong) IBOutlet NSWindow	*consoleWindow;
@property (strong) IBOutlet NSTextView	*consoleLog;
@property (strong) IBOutlet NSTextField	*consoleEntry;

@end

@implementation ICGAppDelegate

-(void)	dealloc
{
	if( mChatClient )
	{
		delete mChatClient;
		mChatClient = NULL;
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString		*assetsFolderPath = NSSearchPathForDirectoriesInDomains( NSCachesDirectory, NSUserDomainMask, YES)[0];
	assetsFolderPath = [assetsFolderPath stringByAppendingPathComponent: @"/com.thevoidsoftware.interconnectgame/assets/"];
	[[NSFileManager defaultManager] createDirectoryAtPath: assetsFolderPath withIntermediateDirectories: YES attributes: @{} error: NULL];

	asset_client*	assetClient = new asset_client( assetsFolderPath.UTF8String );
	assetClient->set_file_finished_callback( [self](std::string inFilename, bool inSuccess)
	{
		[self logFormat: @"File %s %s.\n" color: NSColor.lightGrayColor bold: NO, inFilename.c_str(), (inSuccess?"finished successfully":"failed to download")];
		
		size_t	suffixPos = inFilename.rfind( ".xml" );
		if( inSuccess && suffixPos != std::string::npos && inFilename.substr(0,suffixPos).compare(mCurrentRoomName) == 0 )
		{
			mCurrentMap.load_file( eleven::asset_client::shared_asset_client()->path_for_asset(inFilename) );
			mCurrentMap.currPos = mCurrentMap.startLocation;
			
			[self performSelectorOnMainThread: @selector(loadMap) withObject: nil waitUntilDone: NO];
		}
	} );
	
	ini_file	theIniFile;
	if( !theIniFile.open( [[NSBundle mainBundle] pathForResource: @"settings/settings.ini" ofType:@""].fileSystemRepresentation ) )
	{
		[self logString: @"The settings file could not be found. Please re-download this application." color: NSColor.redColor bold: NO];
		return;
	}
	self.webView.drawsBackground = NO;
	NSString	*	urlString = [NSString stringWithUTF8String: theIniFile.setting("welcomeurl").c_str()];
	[self.webView.mainFrame loadRequest: [NSURLRequest requestWithURL: [NSURL URLWithString: urlString]]];
	NSString	*	userName = [[NSUserDefaults standardUserDefaults] stringForKey: @"ICGUserName"];
	[self.userNameField setStringValue: userName ?: @""];
	
	NSString*	password = @"";
	password = [ICGKeychainWrapper keychainStringFromMatchingIdentifier: @"interconnectGamePassword"];
	if( !password )
		password = @"";
	[self.passwordField setStringValue: password];
	
	[self.loginWindow makeKeyAndOrderFront: self];
}


-(void)	loadMap
{
	mCurrentMap.add_change_listener( [=]( object_vector* sender )
	{
		[self.gameView setNeedsDisplay: YES];
		[self.mapView setNeedsDisplay: YES];
	} );
	
	[self.gameView setGameMap: &mCurrentMap projectedMap: &mProjectedMap culledMap: &mCulledMap];
	[self.mapView setGameMap: &mCurrentMap projectedMap: &mProjectedMap culledMap: &mCulledMap];

	[self.gameView setNeedsDisplay: YES];
	[self.mapView setNeedsDisplay: YES];
	
	[self.gameView.window makeKeyAndOrderFront: nil];	// +++ wait with this until full game has loaded & hide login window then.
	[self.mapView.window makeKeyAndOrderFront: nil];	// +++ wait with this until full game has loaded & hide login window then.
	[self.loginWindow orderOut: self];	// +++ wait with this until full game has loaded & hide login window then.
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if( mChatClient )
	{
		session_ptr	session = mChatClient->current_session();
		if( session )
			session->printf("/logout\r\n");
	}
}


-(void)	updateObjectivesDisplay
{
	[self logString: @"Missions:\n" color: NSColor.cyanColor bold: YES];
	NSMutableString	*	missionsString = [[NSMutableString alloc] init];
	for( auto currMission : mMissions )
	{
		[missionsString appendFormat: @"%@ (in %s/%d)\n", [NSString stringWithUTF8String: currMission.second.mDisplayName.c_str()], currMission.second.mRoomName.c_str(), currMission.second.mPhysicalLocation];
		for( auto currObjective : currMission.second.mObjectives )
		{
			if( currObjective.second.mMaxCount > 0 )
			{
				[missionsString appendFormat: @"\t%@ (%d/%d) in %s/%d\n", [NSString stringWithUTF8String: currObjective.second.mDisplayName.c_str()], currObjective.second.mCurrentCount, currObjective.second.mMaxCount, currObjective.second.mRoomName.c_str(), currObjective.second.mPhysicalLocation];
			}
			else
			{
				[missionsString appendFormat: @"\t%@ in %s/%d\n", [NSString stringWithUTF8String: currObjective.second.mDisplayName.c_str()], currObjective.second.mRoomName.c_str(), currObjective.second.mPhysicalLocation];
			}
		}
	}
	[self logString: missionsString color: NSColor.cyanColor bold: NO];
}


-(void)	loginDidWork: (NSNumber*)didWork
{
	if( didWork.boolValue )
	{
		[self.progressSpinner setDoubleValue: 8.0];
		[[NSUserDefaults standardUserDefaults] setObject: self.userNameField.stringValue forKey: @"ICGUserName"];
	
		[self logString: @"Logged in.\n" color: NSColor.whiteColor bold: NO];
		if( ![ICGKeychainWrapper updateKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"] )
			[ICGKeychainWrapper createKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"];
		
		[self.progressSpinner setDoubleValue: 10.0];
		mChatClient->current_session()->printf( "/last_room\r\n" );
	}
	else
	{
		[self logString: @"Error logging in.\n" color: NSColor.redColor bold: NO];
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
		[self.progressSpinner setDoubleValue: 0.0];
		[self.userNameField setEnabled: YES];
		[self.passwordField setEnabled: YES];
	}
	
	[self.consoleWindow makeKeyAndOrderFront: nil];
}


-(void)	logString: (NSString*)inString color: (NSColor*)theColor bold: (BOOL)makeBold
{
	NSFont						*originalFont = [NSFont fontWithName: @"Helvetica" size: 12];
	NSFont						*theFont = originalFont;
	if( makeBold )
	{
		theFont = [[NSFontManager sharedFontManager] convertWeight: YES ofFont: theFont];
		if( !theFont )
			theFont = originalFont;
	}
	NSMutableAttributedString	*attrStr = [[NSMutableAttributedString alloc] initWithString: inString attributes:@{ NSFontAttributeName: theFont, NSForegroundColorAttributeName: theColor }];
	[self.consoleLog.textStorage performSelectorOnMainThread: @selector(appendAttributedString:) withObject: attrStr waitUntilDone: NO];
}


-(void)	logFormat: (NSString*)inString color: (NSColor*)theColor bold: (BOOL)makeBold, ...
{
	va_list		vargs;
	va_start(vargs, makeBold);
	NSFont						*originalFont = [NSFont fontWithName: @"Helvetica" size: 12];
	NSFont						*theFont = originalFont;
	if( makeBold )
	{
		theFont = [[NSFontManager sharedFontManager] convertWeight: YES ofFont: theFont];
		if( !theFont )
			theFont = originalFont;
	}
	NSMutableAttributedString	*attrStr = [[NSMutableAttributedString alloc] initWithString: [[NSString alloc] initWithFormat: inString arguments: vargs] attributes:@{ NSFontAttributeName: theFont, NSForegroundColorAttributeName: theColor }];
	va_end(vargs);
	[self performSelectorOnMainThread: @selector(doLoggingMainThread:) withObject: attrStr waitUntilDone: NO];
}


-(void)	doLoggingMainThread: (NSAttributedString*)attrStr
{
	[self.consoleLog.textStorage beginEditing];
	[self.consoleLog.textStorage appendAttributedString: attrStr];
	[self.consoleLog.textStorage endEditing];
}


-(IBAction)	doLogIn: (id)sender
{
	if( [self.passwordField.stringValue rangeOfString: @" "].location != NSNotFound
		|| [self.passwordField.stringValue rangeOfString: @"\t"].location != NSNotFound
		|| [self.passwordField.stringValue rangeOfString: @"\r"].location != NSNotFound
		|| [self.passwordField.stringValue rangeOfString: @"\n"].location != NSNotFound
		|| [self.userNameField.stringValue rangeOfString: @" "].location != NSNotFound
		|| [self.userNameField.stringValue rangeOfString: @"\t"].location != NSNotFound
		|| [self.userNameField.stringValue rangeOfString: @"\r"].location != NSNotFound
		|| [self.userNameField.stringValue rangeOfString: @"\n"].location != NSNotFound
		|| self.passwordField.stringValue.length == 0 || self.userNameField.stringValue.length == 0 )
	{
		NSBeep();
		return;
	}
	
	self.logInButton.enabled = NO;
	[self.progressSpinner startAnimation: self];
	[self.progressSpinner setDoubleValue: 2.0];
	[self.userNameField setEnabled: NO];
	[self.passwordField setEnabled: NO];

	mChatClient = new chatclient( "127.0.0.1", 13762, [[NSBundle mainBundle] pathForResource: @"settings" ofType:@""].fileSystemRepresentation );
	mChatClient->register_message_handler( "/logged_in", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @YES waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/!could_not_log_in", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @NO waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/asset_info", asset_client::asset_info );
	mChatClient->register_message_handler( "/asset_chunk", asset_client::asset_chunk );
	mChatClient->register_message_handler( "/currentroom", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		mCurrentRoomName = session::next_word(inLine, currOffset);
		inSession->printf( "/asset_info %s.xml\r\n", mCurrentRoomName.c_str() );
	} );
	mChatClient->register_message_handler( "/primarymission", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		mPrimaryMissionID = atoi( session::next_word(inLine, currOffset).c_str() );
	} );
	mChatClient->register_message_handler( "/mission", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		uint32_t missionID = atoi( session::next_word(inLine, currOffset).c_str() );
		if( missionID == 0 )
			mMissions.clear();
		else
		{
			mission_entry&	missionEntry = mMissions[missionID];
			std::string		missionRoomName = session::next_word(inLine, currOffset);
			missionEntry.mRoomName = missionRoomName;
			missionEntry.mPhysicalLocation = atoi( session::next_word(inLine, currOffset).c_str() );
		}
		
		[self performSelectorOnMainThread: @selector(updateObjectivesDisplay) withObject: nil waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/mission_display_name", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		uint32_t 		missionID = atoi( session::next_word(inLine, currOffset).c_str() );
		if( missionID == 0 )
			mMissions.clear();
		else
		{
			std::string		missionName = session::remainder_of_string( inLine, currOffset );
			mission_entry&	missionEntry = mMissions[missionID];
			missionEntry.mDisplayName = missionName;
		}
		
		[self performSelectorOnMainThread: @selector(updateObjectivesDisplay) withObject: nil waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/mission_objective", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		uint32_t missionObjectiveID = atoi( session::next_word(inLine, currOffset).c_str() );
		uint32_t missionID = atoi( session::next_word(inLine, currOffset).c_str() );
		uint32_t currCount = atoi( session::next_word(inLine, currOffset).c_str() );
		uint32_t maxCount = atoi( session::next_word(inLine, currOffset).c_str() );
		std::string roomName = session::next_word(inLine, currOffset);
		uint32_t physicalLocationID = atoi( session::next_word(inLine, currOffset).c_str() );
		mission_entry&	missionEntry = mMissions[missionID];
		mission_objective_entry&	objectiveEntry = missionEntry.mObjectives[missionObjectiveID];
		objectiveEntry.mCurrentCount = currCount;
		objectiveEntry.mMaxCount = maxCount;
		objectiveEntry.mRoomName = roomName;
		objectiveEntry.mPhysicalLocation = physicalLocationID;
		
		[self performSelectorOnMainThread: @selector(updateObjectivesDisplay) withObject: nil waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/mission_objective_display_name", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		size_t	currOffset = 0;
		session::next_word(inLine, currOffset);
		uint32_t missionObjectiveID = atoi( session::next_word(inLine, currOffset).c_str() );
		uint32_t missionID = atoi( session::next_word(inLine, currOffset).c_str() );
		std::string		missionName = session::remainder_of_string( inLine, currOffset );
		mission_entry&	missionEntry = mMissions[missionID];
		mission_objective_entry&	objectiveEntry = missionEntry.mObjectives[missionObjectiveID];
		objectiveEntry.mDisplayName = missionName;
		
		[self performSelectorOnMainThread: @selector(updateObjectivesDisplay) withObject: nil waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/log", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self logString: [[NSString stringWithUTF8String: inLine.c_str() +5] stringByAppendingString: @"\n"] color: NSColor.grayColor bold: NO];
	} );
	mChatClient->register_message_handler( "*", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self logString: [[NSString stringWithUTF8String: inLine.c_str()] stringByAppendingString: @"\n"] color: NSColor.whiteColor bold: NO];
	} );
	
	if( mChatClient->connect() )
	{
		[self.progressSpinner setDoubleValue: 4.0];
		mChatClient->listen_for_messages();
		
		mChatClient->current_session()->printf( "/login %s %s\r\n", self.userNameField.stringValue.lowercaseString.UTF8String, self.passwordField.stringValue.UTF8String );
	}
	else
	{
		[self logString: @"Couldn't connect to server.\n" color: NSColor.redColor bold: NO];

		[self.progressSpinner setDoubleValue: 0.0];
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
		[self.userNameField setEnabled: YES];
		[self.passwordField setEnabled: YES];
	}
}

-(IBAction)	doSendConsoleCommand: (id)sender
{
	NSString	*	commandStr = [sender stringValue];
	session_ptr		theSession = mChatClient->current_session();
	if( theSession )
	{
		theSession->sendln( commandStr.UTF8String );
		[self logString: [commandStr stringByAppendingString: @"\n"] color: NSColor.lightGrayColor bold: NO];
	}
	else
		[self logString: @"Connection lost\n" color: NSColor.redColor bold: NO];
}

@end
