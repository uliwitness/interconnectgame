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


using namespace eleven;


int	main( int arc, const char** argv )
{
	chatserver		server( "serversettings", 13762 );
	
	if( !server.valid() )
		return 110;
	
	if( !user_session::load_users( "serversettings" ) )
	{
		fprintf(stderr, "Can't find account database file accounts.txt.\n");
		return 100;
	}
		
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
	server.register_command_handler( "/last_room", []( session_ptr session, std::string currRequest, chatserver* server )
	{
		session->printf( "/last_room_was startroom\n" );
		
		session->disconnect();
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