//
//  main.cpp
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-11-24.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#include "eleven_chatserver.h"
#include "eleven_users.h"
#include "eleven_channel.h"
#include "eleven_log.h"
#include "interconnect_database.h"


using namespace eleven;
using namespace interconnect;


int	main( int arc, const char** argv )
{
	interconnect::database	theDB("serversettings");
	
	theDB.set_user_state_callback( [](const user_state & inUserState, eleven::user_id inUserID )
	{
		session_ptr	session = user_session::session_for_user( inUserID );
		session->printf( "/currentroom %s\r\n", inUserState.mCurrentRoom.c_str() );
		session->printf( "/primarymission %d\r\n", inUserState.mPrimaryMission );
	});
	theDB.set_missions_callback( [](const mission & inTargetMission, eleven::user_id inUserID )
	{
		session_ptr	session = user_session::session_for_user( inUserID );
		session->printf( "/mission %d %s\r\n", inTargetMission.mID, inTargetMission.mCurrentRoomName.c_str() );
		session->printf( "/mission_display_name %d %s\r\n", inTargetMission.mID, inTargetMission.mDisplayName.c_str() );
	});
	theDB.set_objectives_callback( [](const mission_objective & inObjective, mission_id inMission, eleven::user_id inUserID )
	{
		session_ptr	session = user_session::session_for_user( inUserID );
		session->printf( "/mission_objective %d %d %d %d %d\r\n", inObjective.mID, inMission, inObjective.mCurrentCount, inObjective.mMaxCount, inObjective.mPhysicalLocation );
		session->printf( "/mission_objective_display_name %d %d %s\r\n", inObjective.mID, inMission, inObjective.mDisplayName.c_str() );
	});
	
	chatserver		server( "serversettings", 13762 );
	
	if( !server.valid() )
		return 110;
	
	user_session::set_user_database(&theDB);
	
	// /login <userName> <password>
	server.register_command_handler( "/login", user_session::login_handler );
	// /adduser <userName> <password> <confirmPassword> [moderator] [owner]
	server.register_command_handler( "/adduser", user_session::adduser_handler );
	// /deleteuser <userName> <confirmUserName>
	server.register_command_handler( "/deleteuser", user_session::deleteuser_handler );
	// /blockuser <userName> <confirmUserName>
	server.register_command_handler( "/blockuser", user_session::blockuser_handler );
	// /retireuser <userName> <confirmUserName>
	server.register_command_handler( "/retireuser", user_session::retireuser_handler );
	// /makemoderator <userName>
	server.register_command_handler( "/makemoderator", user_session::makemoderator_handler );
	// /makeowner <userName>
	server.register_command_handler( "/makeowner", user_session::makeowner_handler );
	// /bye
	server.register_command_handler( "/logout", []( session_ptr session, std::string currRequest, chatserver* server )
	{
		session->printf( "/logged-out Logging you out.\n" );
		
		session->disconnect();
	} );
	server.register_command_handler( "/last_room", [&theDB]( session_ptr session, std::string currRequest, chatserver* server )
	{
		user_session_ptr	loginInfo = session->find_sessiondata<user_session>(USER_SESSION_DATA_ID);
		if( !loginInfo )
		{
			session->sendln( "/!not_logged_in You must log in first." );
			return;
		}
		
		theDB.request_current_state( loginInfo->current_user() );
	} );
	server.register_command_handler( "/test", [&theDB]( session_ptr session, std::string currRequest, chatserver* server )
	{
		user_session_ptr	loginInfo = session->find_sessiondata<user_session>(USER_SESSION_DATA_ID);		
		theDB.add_mission_for_user( 1, "Welcome to Montreal!", "hub_back_alley", loginInfo->current_user() );
		theDB.set_user_state( 1, "hub", loginInfo->current_user() );
		theDB.add_objective_to_mission_for_user( 1, "Talk to other applicants", 3, 0, 1, loginInfo->current_user() );
		theDB.add_count_to_objective_of_mission_for_user( 2, 1, 1, loginInfo->current_user() );
	} );
	// /howdy
	server.register_command_handler( "/version", []( session_ptr session, std::string currRequest, chatserver* server )
	{
		session->printf( "/version 1.0 interconnectserver\n" );
	} );
	server.register_command_handler( "/shutdown", user_session::shutdown_handler );
	// /join <channelName>
	server.register_command_handler( "/join", channel::join_channel_handler );
	// /leave [<channelName>]
	server.register_command_handler( "/leave", channel::leave_channel_handler );
	// /kick [<channelName>] <userName>
	server.register_command_handler( "/kick", channel::kick_handler );
	// <anything that's not a recognized command>
	server.register_command_handler( "*", channel::chat_handler );
	
	log( "Listening on port %d\n", server.port_number() );
	
	server.wait_for_connection();
	
	return 0;
}