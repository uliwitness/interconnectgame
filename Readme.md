Setup
-----

Apart from what's needed to build the 'eleven' library's dependencies,
you will also need the MySQL connector. You can get it from Homebrew:

	brew install mysql-connector-c++

It will be linked in statically.

Then you need to set up the included Lua submodule: Duplicate the lua/src/luaconf.h.orig file as "luaconf.h" and run

	make macosx test
	
in that folder to build the Lua static library.

To run the server, you will need a working MySQL server with a database (The standard MAMP.app will work). Specify the login information in serversettings/settings.ini as dbserver, dbuser, dbpassword and dbname.

How to use this
---------------

Once you've built everything, build and run interconnectserver.xcodeproj. Now you have a server. Then build and run interconnectgame.xcodeproj and log in (default user is "admin", password is "eleven"). The console window is kinda like IRC and understands a "/help" command.
