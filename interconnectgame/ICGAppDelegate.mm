//
//  ICGAppDelegate.m
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-11-24.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ICGAppDelegate.h"
#import "eleven_chatclient.h"


@interface ICGAppDelegate ()
{
	eleven::chatclient*		mChatClient;
}

@property (weak) IBOutlet NSWindow *loginWindow;
@property (weak) IBOutlet NSTextField *userNameField;
@property (weak) IBOutlet NSTextField *passwordField;
@property (weak) IBOutlet NSProgressIndicator *progressSpinner;
@property (weak) IBOutlet NSButton *logInButton;
@property (weak) IBOutlet NSButton *quitButton;
@property (weak) IBOutlet NSWindow *gameWindow;

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
	NSString	*	userName = [[NSUserDefaults standardUserDefaults] stringForKey: @"ICGUserName"];
	[self.userNameField setStringValue: userName ?: @""];
	[self.loginWindow makeKeyAndOrderFront: self];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if( mChatClient )
		mChatClient->current_session()->printf("/logout\r\n");
}


-(void)	loginDidWork: (NSNumber*)didWork
{
	if( didWork.boolValue )
	{
		[[NSUserDefaults standardUserDefaults] setObject: self.userNameField.stringValue forKey: @"ICGUserName"];
		[self.loginWindow orderOut: self];
	}
	[self.progressSpinner stopAnimation: self];
	self.logInButton.enabled = YES;
	
	if( didWork.boolValue )
	{
		[self.gameWindow makeKeyAndOrderFront: self];
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

	mChatClient = new eleven::chatclient( "127.0.0.1", 13762, [[NSBundle mainBundle] pathForResource: @"settings" ofType:@""].fileSystemRepresentation );
	mChatClient->register_message_handler( "/logged_in", [=]( eleven::session_ptr inSession, std::string inLine, eleven::chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @YES waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/!could_not_log_in", [=]( eleven::session_ptr inSession, std::string inLine, eleven::chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @NO waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "*", []( eleven::session_ptr inSession, std::string inLine, eleven::chatclient* inSender)
	{
		NSLog( @"%s", inLine.c_str() );
	} );
	
	if( mChatClient->connect() )
	{
		mChatClient->listen_for_messages();
		
		mChatClient->current_session()->printf( "/login %s %s\r\n", self.userNameField.stringValue.lowercaseString.UTF8String, self.passwordField.stringValue.UTF8String );
	}
	else
	{
		[self.progressSpinner stopAnimation: self];
		self.logInButton.enabled = YES;
	}
}

@end
