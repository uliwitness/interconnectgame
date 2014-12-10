//
//  interconnect_scripts.h
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-12-10.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#ifndef __interconnectserver__interconnect_scripts__
#define __interconnectserver__interconnect_scripts__

#include "eleven_chatserver.h"
#include <string>


namespace interconnect
{
	extern eleven::handler		runscript;
	
	extern void	init_scripts( std::string inSettingsFolderPath );
}

#endif /* defined(__interconnectserver__interconnect_scripts__) */
