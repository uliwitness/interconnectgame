//
//  ICGAppDelegate.h
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-11-24.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <string>
#include <map>


@interface ICGAppDelegate : NSObject <NSApplicationDelegate>

-(IBAction)	doLogIn: (id)sender;
-(IBAction)	doSendConsoleCommand: (id)sender;

@end


namespace interconnect
{
	class mission_objective_entry
	{
	public:
		uint32_t	mCurrentCount;
		uint32_t	mMaxCount;
		std::string	mRoomName;
		uint32_t	mPhysicalLocation;
		std::string	mDisplayName;
	};
	
	class mission_entry
	{
	public:
		mission_entry() : mPhysicalLocation(0)	{};
		
		std::string									mDisplayName;
		std::string									mRoomName;
		uint32_t									mPhysicalLocation;
		std::map<uint32_t,mission_objective_entry>	mObjectives;
	};
}

