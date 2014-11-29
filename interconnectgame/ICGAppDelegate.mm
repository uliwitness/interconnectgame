//
//  ICGAppDelegate.m
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-11-24.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ICGAppDelegate.h"
#import "eleven_chatclient.h"
#import <WebKit/WebKit.h>
#import "ICGKeychainWrapper.h"


using namespace eleven;


@interface ICGAppDelegate ()
{
	chatclient*		mChatClient;
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
		mChatClient->current_session()->printf( "/last_room\r\n" );
//		mChatClient->current_session()->printf( "/test\r\n" );
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
	mChatClient->register_message_handler( "/logged_in", [=]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @YES waitUntilDone: NO];
	} );
	mChatClient->register_message_handler( "/!could_not_log_in", [=]( session_ptr inSession, std::string inLine, chatclient* inSender)
	{
		[self performSelectorOnMainThread: @selector(loginDidWork:) withObject: @NO waitUntilDone: NO];
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
