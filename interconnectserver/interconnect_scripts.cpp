//
//  interconnect_scripts.cpp
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-12-10.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#include "interconnect_scripts.h"
#include "eleven_users.h"

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}


namespace interconnect
{

using namespace eleven;


static std::string	sSettingsFolderPath;


// An example C function that we call from Lua:
static int foo (lua_State *L)
{
	int n = lua_gettop(L);    /* number of arguments */
	lua_Number sum = 0;
	int i;
	for (i = 1; i <= n; i++)
	{
		if (!lua_isnumber(L, i))
		{
			lua_pushstring(L, "incorrect argument");
			lua_error(L);
		}
		sum += lua_tonumber(L, i);
	}
	lua_pushnumber(L, sum/n);        /* first result */
	lua_pushnumber(L, sum);         /* second result */
	return 2;                   /* number of results */
}


// C++ closure (lambda, block, whatever) that we register with our server that runs a Lua script:
eleven::handler		runscript = []( session_ptr session, std::string currRequest, chatserver* server )
{
	user_session_ptr	loginInfo = session->find_sessiondata<user_session>(USER_SESSION_DATA_ID);		
	if( !loginInfo || (loginInfo->my_user_flags() & USER_FLAG_SERVER_OWNER) == 0 )
	{
		session->printf( "/!not_permitted\r\n" );
		return;
	}
	
	size_t	currOffset = 0;
	session::next_word(currRequest, currOffset);
	std::string	fileName( session::next_word(currRequest, currOffset) );
	if( fileName.size() == 0 || fileName.find("..") != std::string::npos )
	{
		session->printf( "/!no_such_file\r\n" );
		return;
	}
	std::string	filePath( sSettingsFolderPath );
	filePath.append( "/scripts/" );
	filePath.append( fileName );
	filePath.append( ".lua" );
	
	// ===== LUA CODE START: =====
	lua_State *L = luaL_newstate();	// Create a context.
	
	luaL_openlibs(L);	// Load Lua standard library.
	
	// CREATE A C-backed Lua object:
	lua_newtable( L );	// Create a new object & push it on the stack.
	lua_pushcfunction( L, foo );	// Create an (unnamed) function with C function "foo" as the implementation.
	lua_setfield( L, -2, "durchschnitt" );	// Pop the function off the back of the stack and into the object (-2 == penultimate object on stack) using the key "durchschnitt" (i.e. method name).
	lua_setglobal( L, "eleven_obj" );	// Pop the object off the stack into a global named "eleven_obj".
	
	// CREATE A C-BACKED LUA FUNCTION:
	lua_register( L, "myavg", foo );	// Create a global named "myavg" and stash an unnamed function with C function "foo" as its implementation in it.

	// Load the file:
	int s = luaL_loadfile( L, filePath.c_str() );

	if( s == 0 )
	{
		// Run it, with 0 params, accepting an arbitrary number of return values.
		//	Last 0 is error handler Lua function's stack index, or 0 to ignore.
		s = lua_pcall(L, 0, LUA_MULTRET, 0);
	}

	// Was an error? Get error message off the stack and send it back:
	if( s != 0 )
	{
		session->printf( "/!script_error %s\r\n", lua_tostring(L, -1) );
		lua_pop(L, 1); // remove error message
	}
	else
		session->printf( "/ran_script\r\n" );	// Send back indication of success.
	lua_close(L);	// Dispose of the script context.
	
	// ===== LUA CODE END. =====
};
	

void	init_scripts( std::string inSettingsFolderPath )
{
	sSettingsFolderPath = inSettingsFolderPath;
}


}
