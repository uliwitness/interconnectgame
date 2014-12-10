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


using namespace eleven;
using namespace interconnect;


@interface ICGAppDelegate ()
{
	chatclient*							mChatClient;
	std::string							mCurrentRoomName;
	uint32_t							mPrimaryMissionID;
	std::map<uint32_t,mission_entry>	mMissions;
}

@property (strong) IBOutlet NSWindow *loginWindow;
@property (strong) IBOutlet NSTextField *userNameField;
@property (strong) IBOutlet NSTextField *passwordField;
@property (strong) IBOutlet NSProgressIndicator *progressSpinner;
@property (strong) IBOutlet NSButton *logInButton;
@property (strong) IBOutlet NSButton *quitButton;
@property (strong) IBOutlet NSWindow *gameWindow;
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

	asset_client*	assetClient = new asset_client( assetsFolderPath.UTF8String );
	assetClient->set_file_finished_callback( [self](std::string inFilename, bool inSuccess)
	{
		[self logFormat: @"File %s %s.\n" color: NSColor.lightGrayColor, inFilename.c_str(), (inSuccess?"finished successfully":"failed to download")];
	} );
	
	ini_file	theIniFile;
	if( !theIniFile.open( [[NSBundle mainBundle] pathForResource: @"settings/settings.ini" ofType:@""].fileSystemRepresentation ) )
	{
		[self logString: @"The settings file could not be found. Please re-download this application." color: NSColor.redColor];
		return;
	}
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
	NSMutableString	*	missionsString = [[NSMutableString alloc] initWithString: @"==== Missions: ====\n"];
	for( auto currMission : mMissions )
	{
		[missionsString appendFormat: @"%@ (in %s/%d)\n", [NSString stringWithUTF8String: currMission.second.mDisplayName.c_str()], currMission.second.mRoomName.c_str(), currMission.second.mPhysicalLocation];
		for( auto currObjective : currMission.second.mObjectives )
		{
			[missionsString appendFormat: @"\t%@ (%d/%d) in %s/%d\n", [NSString stringWithUTF8String: currObjective.second.mDisplayName.c_str()], currObjective.second.mCurrentCount, currObjective.second.mMaxCount, currObjective.second.mRoomName.c_str(), currObjective.second.mPhysicalLocation];
		}
	}
	[self logString: missionsString color: NSColor.blueColor];
}


-(void)	loginDidWork: (NSNumber*)didWork
{
	if( didWork.boolValue )
	{
		[self.progressSpinner setDoubleValue: 8.0];
		[[NSUserDefaults standardUserDefaults] setObject: self.userNameField.stringValue forKey: @"ICGUserName"];
		//[self.loginWindow orderOut: self];
	}
	
	if( didWork.boolValue )
	{
		[self logString: @"Logged in.\n" color: NSColor.whiteColor];
		if( ![ICGKeychainWrapper updateKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"] )
			[ICGKeychainWrapper createKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"];
		
		[self.progressSpinner setDoubleValue: 10.0];
//		mChatClient->current_session()->printf( "/test\r\n" );
		mChatClient->current_session()->printf( "/last_room\r\n" );
//		mChatClient->current_session()->printf( "/asset_info %s\r\n", "Photo on 2014-05-25 at 23.17.jpg" );
	}
	else
	{
		[self logString: @"Error logging in.\n" color: NSColor.redColor];
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
		[self.progressSpinner setDoubleValue: 0.0];
		[self.userNameField setEnabled: YES];
		[self.passwordField setEnabled: YES];
	}
	
	[self.consoleWindow makeKeyAndOrderFront: nil];
}


-(void)	logString: (NSString*)inString color: (NSColor*)theColor
{
	NSMutableAttributedString	*attrStr = [[NSMutableAttributedString alloc] initWithString: inString attributes:@{ NSFontAttributeName: [NSFont fontWithName: @"Menlo" size: 10], NSForegroundColorAttributeName: theColor }];
	[self.consoleLog.textStorage performSelectorOnMainThread: @selector(appendAttributedString:) withObject: attrStr waitUntilDone: NO];
}


-(void)	logFormat: (NSString*)inString color: (NSColor*)theColor, ...
{
	va_list		vargs;
	va_start(vargs, theColor);
	NSMutableAttributedString	*attrStr = [[NSMutableAttributedString alloc] initWithString: [[NSString alloc] initWithFormat: inString arguments: vargs] attributes:@{ NSFontAttributeName: [NSFont fontWithName: @"Menlo" size: 10], NSForegroundColorAttributeName: theColor }];
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
	mChatClient->register_message_handler( "*", [self]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self logString: [[NSString stringWithUTF8String: inLine.c_str()] stringByAppendingString: @"\n"] color: NSColor.whiteColor];
	} );
	
	if( mChatClient->connect() )
	{
		[self.progressSpinner setDoubleValue: 4.0];
		mChatClient->listen_for_messages();
		
		mChatClient->current_session()->printf( "/login %s %s\r\n", self.userNameField.stringValue.lowercaseString.UTF8String, self.passwordField.stringValue.UTF8String );
	}
	else
	{
		[self logString: @"Couldn't connect to server.\n" color: NSColor.redColor];

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
	
	mChatClient->current_session()->sendln( commandStr.UTF8String );
	[self logString: [commandStr stringByAppendingString: @"\n"] color: NSColor.lightGrayColor];
}

@end
