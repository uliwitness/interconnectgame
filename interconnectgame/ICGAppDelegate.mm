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

@property (weak) IBOutlet NSWindow *loginWindow;
@property (weak) IBOutlet NSTextField *userNameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSProgressIndicator *progressSpinner;
@property (weak) IBOutlet NSButton *logInButton;
@property (weak) IBOutlet NSButton *quitButton;
@property (weak) IBOutlet NSWindow *gameWindow;
@property (weak) IBOutlet WebView *webView;

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
	assetClient->set_file_finished_callback( [](std::string inFilename, bool inSuccess)
	{
		printf("File %s %s.\n", inFilename.c_str(), (inSuccess?"finished successfully":"failed to download"));
	} );
	
	ini_file	theIniFile;
	if( !theIniFile.open( [[NSBundle mainBundle] pathForResource: @"settings/settings.ini" ofType:@""].fileSystemRepresentation ) )
	{
		NSRunAlertPanel( @"Application Damaged", @"The settings file could not be found. Please re-download this application.", @"Quit", @"", @"" );
		[NSApplication.sharedApplication terminate: self];
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
	NSLog(@"==== Missions: ====");
	for( auto currMission : mMissions )
	{
		NSLog( @"%@ (in %s/%d)", [NSString stringWithUTF8String: currMission.second.mDisplayName.c_str()], currMission.second.mRoomName.c_str(), currMission.second.mPhysicalLocation );
		for( auto currObjective : currMission.second.mObjectives )
		{
			NSLog( @"\t%@ (%d/%d) in %s/%d", [NSString stringWithUTF8String: currObjective.second.mDisplayName.c_str()], currObjective.second.mCurrentCount, currObjective.second.mMaxCount, currObjective.second.mRoomName.c_str(), currObjective.second.mPhysicalLocation );
		}
	}
	NSLog(@" ");
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
		if( ![ICGKeychainWrapper updateKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"] )
			[ICGKeychainWrapper createKeychainValue: self.passwordField.stringValue forIdentifier: @"interconnectGamePassword"];
		
		[self.progressSpinner setDoubleValue: 10.0];
//		mChatClient->current_session()->printf( "/test\r\n" );
		mChatClient->current_session()->printf( "/last_room\r\n" );
//		mChatClient->current_session()->printf( "/asset_info %s\r\n", "Photo on 2014-05-25 at 23.17.jpg" );
	}
	else
	{
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
		[self.progressSpinner setDoubleValue: 0.0];
		[self.userNameField setEnabled: YES];
		[self.passwordField setEnabled: YES];
	}
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
		
		[self updateObjectivesDisplay];
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
		
		[self updateObjectivesDisplay];
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
		
		[self updateObjectivesDisplay];
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
		
		[self updateObjectivesDisplay];
	} );
	mChatClient->register_message_handler( "*", []( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		NSLog( @"%s", inLine.c_str() );
	} );
	
	if( mChatClient->connect() )
	{
		[self.progressSpinner setDoubleValue: 4.0];
		mChatClient->listen_for_messages();
		
		mChatClient->current_session()->printf( "/login %s %s\r\n", self.userNameField.stringValue.lowercaseString.UTF8String, self.passwordField.stringValue.UTF8String );
	}
	else
	{
		[self.progressSpinner setDoubleValue: 0.0];
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
		[self.userNameField setEnabled: YES];
		[self.passwordField setEnabled: YES];
	}
}

@end
