//
//  ICGGameView.h
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-12-16.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "interconnect_map.h"
#include <unordered_set>


@interface ICGGameView : NSView
{
	interconnect::object_vector*	objects;
	interconnect::object_vector*	projectedObjects;
	interconnect::object_vector*	visibleObjects;
	std::unordered_set<unichar>		pressedKeys;
}

@property (retain,nonatomic) NSTimer*	keyRepeatTimer;	// Timer that looks at pressedKeys and dispatches the key presses.

-(void)	setGameMap: (interconnect::object_vector*)mCurrentMap projectedMap: (interconnect::object_vector*)mProjectedMap culledMap: (interconnect::object_vector*)mCulledMap;

@end
