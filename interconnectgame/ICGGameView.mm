//
//  ICGGameView.m
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-12-16.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#import "ICGGameView.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>


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


@implementation ICGGameView

-(id)	initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder: coder];
	if( self )
	{
		self.keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 target: self selector: @selector(dispatchPressedKeys:) userInfo: nil repeats: YES];
	}
	return self;
}


-(void)	setGameMap: (interconnect::object_vector*)inCurrentMap projectedMap: (interconnect::object_vector*)inProjectedMap culledMap: (interconnect::object_vector*)inCulledMap
{
	objects = inCurrentMap;
	projectedObjects = inProjectedMap;
	visibleObjects = inCulledMap;
	
	[self setNeedsDisplay: YES];
}


-(BOOL)	acceptsFirstResponder
{
	return YES;
}


-(BOOL)	becomeFirstResponder
{
	return YES;
}


-(void)	lineToProjectedPointX: (GLfloat)x Y: (GLfloat)y Z: (GLfloat)z toPath: (NSBezierPath*)bpath
{
	CGFloat		zFactorFudge = 3;
	NSSize		mySize = self.bounds.size;
	mySize.width /= 2;
	mySize.height /= 2;
	NSPoint		finalPoint = NSMakePoint( ((x -mySize.width) * zFactorFudge / z) +mySize.width,
											((y -mySize.height) * zFactorFudge / z) +mySize.height );
	
	[bpath lineToPoint: finalPoint];
}


-(void)	moveToProjectedPointX: (GLfloat)x Y: (GLfloat)y Z: (GLfloat)z toPath: (NSBezierPath*)bpath
{
	CGFloat		zFactorFudge = 3;
	NSSize		mySize = self.bounds.size;
	mySize.width /= 2;
	mySize.height /= 2;
	NSPoint		finalPoint = NSMakePoint( ((x -mySize.width) * zFactorFudge / z) +mySize.width,
											((y -mySize.height) * zFactorFudge / z) +mySize.height );
	
	[bpath moveToPoint: finalPoint];
}


- (void)drawRect:(NSRect)r
{
	if( !visibleObjects )
		return;

	size_t					numPoints = visibleObjects->count_points_for_3d();
	std::vector<GLfloat>	points;
	points.reserve( numPoints * 3 );
	size_t					numWalls = visibleObjects->count_walls();
	
	visibleObjects->points_for_3d( points );
	
	if( points.size() == 0 )
		return;

	for( size_t x = 0; x < (numWalls * 3); x += 12 )
	{
		NSBezierPath	*	theWall = [NSBezierPath bezierPath];
		[self moveToProjectedPointX: points[x +0] Y: points[x +1] Z: points[x +2] toPath: theWall];
		[self lineToProjectedPointX: points[x +3] Y: points[x +4] Z: points[x +5] toPath: theWall];
		[self lineToProjectedPointX: points[x +6] Y: points[x +7] Z: points[x +8] toPath: theWall];
		[self lineToProjectedPointX: points[x +9] Y: points[x +10] Z: points[x +11] toPath: theWall];
		[self lineToProjectedPointX: points[x +0] Y: points[x +1] Z: points[x +2] toPath: theWall];
		
		[(NSColor*)[NSColor performSelector: NSSelectorFromString(@"redColor")] set];
		[theWall fill];
	}
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
	if( !objects )
		return;
	objects->strafe( -STEP_SIZE * (running? 2 : 1) );
	[self setNeedsDisplay: YES];
}


-(void)	strafeRight: (id)sender fast: (BOOL)running
{
	if( !objects )
		return;
	objects->strafe( STEP_SIZE * (running? 2 : 1) );
	[self setNeedsDisplay: YES];
}


-(void)	moveLeft: (id)sender
{
	if( !objects )
		return;
	objects->turn( NUM_ROTATION_STEPS );
	[self setNeedsDisplay: YES];
}


-(void)	moveRight: (id)sender
{
	if( !objects )
		return;
	objects->turn( -NUM_ROTATION_STEPS );
	[self setNeedsDisplay: YES];
}


-(void)	moveUp: (id)sender fast: (BOOL)running
{
	if( !objects )
		return;
	objects->walk( -STEP_SIZE * (running? 2 : 1) );
	[self setNeedsDisplay: YES];
}


-(void)	moveDown: (id)sender fast: (BOOL)running
{
	if( !objects )
		return;
	objects->walk( STEP_SIZE * (running? 2 : 1) );
	[self setNeedsDisplay: YES];
}

@end
