Setup
-----

Apart from what's needed to build the 'eleven' library's dependencies,
you will also need the MySQL connector and Lua. You can get the former from Homebrew:

	brew install mysql-connector-c++

It will be linked in statically.

Then duplicate the lua/src/luaconf.h.orig file as "luaconf.h" and run make macosx test to build the Lua static library.