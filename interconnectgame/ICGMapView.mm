//
//  MapRotationTestView.m
//  MapRotationTest
//
//  Created by Uli Kusterer on 2014-12-12.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ICGMapView.h"
#include "eleven_asset_client.h"


using namespace interconnect;


#define STEP_SIZE			10.0	// Each up/down arrow keypress moves you by 10 points. Same for sidestep with shift key.
#define NUM_ROTATION_STEPS	36.0	// 36 steps in 360 degrees means each left/right arrow press turns you by 10 degrees.
#define LOOK_DISTANCE		1000	// How far away may points we can see be at most, in points.
#define INTERACT_DISTANCE	100		// How far away a point we are aiming at may be at most, in points.


// We need key codes under which to save the modifiers in our "keys pressed"
//	table. We must pick characters that are unlikely to be on any real keyboard.
//	So we pick the Unicode glyphs that correspond to the symbols on these keys.
enum
{
	ICGShiftFunctionKey			= 0x21E7,	// -> NSShiftKeyMask
	ICGAlphaShiftFunctionKey	= 0x21EA,	// -> NSAlphaShiftKeyMask
	ICGAlternateFunctionKey		= 0x2325,	// -> NSAlternateKeyMask
	ICGControlFunctionKey		= 0x2303,	// -> NSControlKeyMask
	ICGCommandFunctionKey		= 0x2318	// -> NSCommandKeyMask
};


@implementation ICGMapView

-(id)	initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder: coder];
	if( self )
	{
		currAngle = 0;
		mapModeDisplay = NO;
		self.keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 target: self selector: @selector(dispatchPressedKeys:) userInfo: nil repeats: YES];
	}
	return self;
}


-(BOOL)	loadMap: (NSString*)inFilename
{
	if( !objects.load_file( eleven::asset_client::shared_asset_client()->path_for_asset(inFilename.UTF8String) ) )
	{
		return NO;
	}
	
	currPos = objects.startLocation;
	[self setNeedsDisplay: YES];
	
	return YES;
}


- (void)drawRect:(NSRect)dirtyRect
{
	point			viewCenter = { self.bounds.size.width / 2, self.bounds.size.height / 2 };
	object_vector	projectedObjects;
	
	if( !mapModeDisplay )
		projectedObjects = objects.rotated_around_point_with_angle( currPos, currAngle );
	else
		projectedObjects = objects;
	
	projectedObjects = projectedObjects.translated_by_x_y( -currPos.x +viewCenter.x, -currPos.y +viewCenter.y );
	
	point	indicatorPos = viewCenter;
	point	lookEndPos = indicatorPos.translated_by_distance_angle( INTERACT_DISTANCE, M_PI );
	wall	lookLine = { indicatorPos, lookEndPos };
	point	intersectionPoint = { -10000, -10000 };
	if( !mapModeDisplay )
	{
		wall	currWall;
		object	currObject;
		if( projectedObjects.closest_intersection_with_to_point( lookLine, indicatorPos, currObject, currWall, intersectionPoint ) )
		{
			[NSColor.cyanColor set];
			[NSBezierPath setDefaultLineWidth: 4];
			[NSBezierPath strokeLineFromPoint: currWall.start toPoint: currWall.end];
			[NSBezierPath setDefaultLineWidth: 1];
		}
	}
	
	// Draw!
	for( const object& currObject : projectedObjects )
	{
		[(NSColor*)[NSColor performSelector: NSSelectorFromString([NSString stringWithUTF8String: currObject.walls[0].colorName.c_str()])] set];
	
		NSBezierPath	*	thePath = [NSBezierPath bezierPath];
		[thePath moveToPoint: currObject.walls[0].start];
		for( const wall& currWall : currObject.walls )
		{
			[thePath lineToPoint: currWall.end];
		}
		[thePath fill];
	}
	
	if( !mapModeDisplay )
	{
		[NSColor.blueColor set];
		
		[NSBezierPath strokeLineFromPoint: indicatorPos toPoint: indicatorPos.translated_by_distance_angle( INTERACT_DISTANCE, M_PI )];
		
		[NSColor.magentaColor set];
		[[NSBezierPath bezierPathWithOvalInRect: NSMakeRect( intersectionPoint.x -4, intersectionPoint.y-4, 8, 8)] fill];
	}
	
	[NSColor.redColor set];
	point triA;
	point triB;
	point triC;
	if( mapModeDisplay )
	{
		triA = point(indicatorPos.x -10, indicatorPos.y +10).rotated_around_point_with_angle( indicatorPos, (2 * M_PI) -currAngle );
		triB = point(indicatorPos.x +10, indicatorPos.y +10).rotated_around_point_with_angle( indicatorPos, (2 * M_PI) -currAngle );
		triC = point(indicatorPos.x, indicatorPos.y -10).rotated_around_point_with_angle( indicatorPos, (2 * M_PI) -currAngle );
	}
	else
	{
		triA = point(indicatorPos.x -10, indicatorPos.y +10);
		triB = point(indicatorPos.x +10, indicatorPos.y +10);
		triC = point(indicatorPos.x, indicatorPos.y -10);
	}
	NSBezierPath	*	playerPath = [NSBezierPath bezierPath];
	[playerPath moveToPoint: triA];
	[playerPath lineToPoint: triB];
	[playerPath lineToPoint: triC];
	[playerPath lineToPoint: triA];
	[playerPath fill];
	
	[NSColor.whiteColor set];
	wall leftWall, rightWall;
	leftWall.start = rightWall.start = indicatorPos;
	leftWall.end = indicatorPos.translated_by_distance_angle( LOOK_DISTANCE, M_PI -(M_PI / 4.0) );
	rightWall.end = indicatorPos.translated_by_distance_angle( LOOK_DISTANCE, M_PI +(M_PI / 4.0) );
	
	[NSBezierPath strokeLineFromPoint: leftWall.start toPoint: leftWall.end];
	[NSBezierPath strokeLineFromPoint: rightWall.start toPoint: rightWall.end];

	
	[NSColor.blackColor set];
	object_vector	visibleObjects = projectedObjects.intersected_with_wedge_of_lines( leftWall, rightWall );
	for( const object& currObject : visibleObjects )
	{
		for( const wall& currWall : currObject.walls )
		{
			[NSBezierPath strokeLineFromPoint: currWall.start toPoint: currWall.end];
		}
	}
}


-(BOOL)	isFlipped
{
	return YES;
}


-(BOOL)	acceptsFirstResponder
{
	return YES;
}


-(BOOL)	becomeFirstResponder
{
	return YES;
}


-(void)	keyDown:(NSEvent *)theEvent
{
	NSString	*	pressedKeyString = theEvent.charactersIgnoringModifiers;
	unichar			pressedKey = (pressedKeyString.length > 0) ? [pressedKeyString characterAtIndex: 0] : 0;
	if( pressedKey )
		pressedKeys.insert( pressedKey );
}


-(void)	keyUp:(NSEvent *)theEvent
{
	NSString	*	pressedKeyString = theEvent.charactersIgnoringModifiers;
	unichar			pressedKey = (pressedKeyString.length > 0) ? [pressedKeyString characterAtIndex: 0] : 0;
	if( pressedKey )
	{
		auto foundKey = pressedKeys.find( pressedKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}
}


-(void)	flagsChanged: (NSEvent *)theEvent
{
	if( theEvent.modifierFlags & NSShiftKeyMask )
	{
		pressedKeys.insert( ICGShiftFunctionKey );
	}
	else
	{
		auto foundKey = pressedKeys.find( ICGShiftFunctionKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}

	if( theEvent.modifierFlags & NSAlphaShiftKeyMask )
	{
		pressedKeys.insert( ICGAlphaShiftFunctionKey );
	}
	else
	{
		auto foundKey = pressedKeys.find( ICGAlphaShiftFunctionKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}

	if( theEvent.modifierFlags & NSControlKeyMask )
	{
		pressedKeys.insert( ICGControlFunctionKey );
	}
	else
	{
		auto foundKey = pressedKeys.find( ICGControlFunctionKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}

	if( theEvent.modifierFlags & NSCommandKeyMask )
	{
		pressedKeys.insert( ICGCommandFunctionKey );
	}
	else
	{
		auto foundKey = pressedKeys.find( ICGCommandFunctionKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}

	if( theEvent.modifierFlags & NSAlternateKeyMask )
	{
		pressedKeys.insert( ICGAlternateFunctionKey );
	}
	else
	{
		auto foundKey = pressedKeys.find( ICGAlternateFunctionKey );
		if( foundKey != pressedKeys.end() )
			pressedKeys.erase(foundKey);
	}
}


-(void) dispatchPressedKeys: (NSTimer*)sender
{
	BOOL	shiftKeyDown = pressedKeys.find(ICGShiftFunctionKey) != pressedKeys.end();
	for( unichar pressedKey : pressedKeys )
	{
		switch( pressedKey )
		{
			case 'w':
				[self moveUp: self fast: shiftKeyDown];
				break;
				
			case 'a':
				[self moveLeft: self];
				break;
				
			case 's':
				[self moveDown: self fast: shiftKeyDown];
				break;
				
			case 'd':
				[self moveRight: self];
				break;

			case 'q':
				[self strafeLeft: self fast: shiftKeyDown];
				break;
				
			case 'e':
				[self strafeRight: self fast: shiftKeyDown];
				break;
			
			case NSLeftArrowFunctionKey:
				[self moveLeft: self];
				break;
				
			case NSRightArrowFunctionKey:
				[self moveRight: self];
				break;
			
			case NSUpArrowFunctionKey:
				[self moveUp: self fast: shiftKeyDown];
				break;
				
			case NSDownArrowFunctionKey:
				[self moveDown: self fast: shiftKeyDown];
				break;
		}
	}
}


-(void)	strafeLeft: (id)sender fast: (BOOL)running
{
	currPos = currPos.translated_by_distance_angle( -STEP_SIZE *(running? 2 : 1), currAngle +(M_PI / 2.0) );
	[self setNeedsDisplay: YES];
}


-(void)	strafeRight: (id)sender fast: (BOOL)running
{
	currPos = currPos.translated_by_distance_angle( STEP_SIZE *(running? 2 : 1), currAngle +(M_PI / 2.0) );
	[self setNeedsDisplay: YES];
}


-(void)	moveLeft: (id)sender
{
	currAngle += (M_PI * 2) / NUM_ROTATION_STEPS;
	[self setNeedsDisplay: YES];
}


-(void)	moveRight: (id)sender
{
	currAngle -= (M_PI * 2) / NUM_ROTATION_STEPS;
	[self setNeedsDisplay: YES];
}


-(void)	moveUp: (id)sender fast: (BOOL)running
{
	currPos = currPos.translated_by_distance_angle( -STEP_SIZE *(running? 2 : 1), currAngle);
	[self setNeedsDisplay: YES];
}


-(void)	moveDown: (id)sender fast: (BOOL)running
{
	currPos = currPos.translated_by_distance_angle( STEP_SIZE *(running? 2 : 1), currAngle);
	[self setNeedsDisplay: YES];
}


@end
