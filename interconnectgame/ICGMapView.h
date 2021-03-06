//
//  MapRotationTestView.h
//  MapRotationTest
//
//  Created by Uli Kusterer on 2014-12-12.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "interconnect_map.h"
#include <unordered_set>


@interface ICGMapView : NSView
{
	interconnect::object_vector*	objects;
	interconnect::object_vector*	projectedObjects;
	interconnect::object_vector*	visibleObjects;
	BOOL							mapModeDisplay;	// YES if we want to show a map where North is up, NO if we want the world to rotate around the character, who's always facing up.
	std::unordered_set<unichar>		pressedKeys;
	BOOL							trackAngle;
}

@property (retain,nonatomic) NSTimer*	keyRepeatTimer;	// Timer that looks at pressedKeys and dispatches the key presses.

-(void)	setGameMap: (interconnect::object_vector*)mCurrentMap projectedMap: (interconnect::object_vector*)mProjectedMap culledMap: (interconnect::object_vector*)mCulledMap;

@end
