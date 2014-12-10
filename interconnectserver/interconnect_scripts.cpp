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
	
	lua_State *L = luaL_newstate();
	
	luaL_openlibs(L);
	
	lua_register( L, "myavg", foo );

	int s = luaL_loadfile( L, filePath.c_str() );

	if( s == 0 )
	{
		// execute Lua program
		s = lua_pcall(L, 0, LUA_MULTRET, 0);
	}

	if( s != 0 )
	{
		session->printf( "/!script_error %s\r\n", lua_tostring(L, -1) );
		lua_pop(L, 1); // remove error message
	}
	else
		session->printf( "/ran_script\r\n" );
	lua_close(L);
};
	

void	init_scripts( std::string inSettingsFolderPath )
{
	sSettingsFolderPath = inSettingsFolderPath;
}


}
