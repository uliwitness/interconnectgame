//
//  interconnect_map.cpp
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-12-13.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#include "interconnect_map.h"
#include <math.h>
#include <string>
#include <memory>
#include "tinyxml2.h"


using namespace interconnect;


double	point::distance_to( point inPos ) const
{
	return sqrt( pow((x - inPos.x), 2) +pow((y - inPos.y),2) );
}


bool	point::is_between( point posA, point posB ) const
{
	double	totalDistance = posA.distance_to(posB);
	double	leftDistance = distance_to(posA);
	double	rightDistance = distance_to(posB);
	
	return( fabs(totalDistance -(leftDistance +rightDistance)) < 0.001 );
}


point	point::rotated_around_point_with_angle( point rotationCenter, radians angle ) const
{
	point	rotatedPoint;
	rotatedPoint.x = (x -rotationCenter.x) * cosf(angle) - (y -rotationCenter.y) * sinf(angle) +rotationCenter.x;
	rotatedPoint.y = (y -rotationCenter.y) * cosf(angle) + (x -rotationCenter.x) * sinf(angle) +rotationCenter.y;
	return rotatedPoint;
}


point	point::translated_by_distance_angle( double distance, radians angle ) const
{
	point		newPos;
	newPos.x = x +(distance *sinf(angle));
	newPos.y = y +(distance *cosf(angle));
	return newPos;
}


point	point::translated_by_x_y( double xdistance, double ydistance ) const
{
	point	movedPoint;
	movedPoint.x = x +xdistance;
	movedPoint.y = y + ydistance;
	return movedPoint;
}


bool	wall::intersection_with( wall wallB, point& outIntersectionPoint ) const
{
	point	intersectionPoint;
	double	d = (start.x -end.x) * (wallB.start.y -wallB.end.y) - (start.y -end.y) * (wallB.start.x -wallB.end.x);
	if( d == 0 )
		return false;
	
	intersectionPoint.x = ((wallB.start.x -wallB.end.x) * (start.x * end.y -start.y * end.x) - (start.x -end.x) * (wallB.start.x * wallB.end.y - wallB.start.y * wallB.end.x)) / d;
	intersectionPoint.y = ((wallB.start.y - wallB.end.y) * (start.x * end.y - start.y * end.x) - (start.y -end.y) * (wallB.start.x * wallB.end.y -wallB.start.y * wallB.end.x)) / d;
	
	if( intersectionPoint.is_between( start, end ) && intersectionPoint.is_between( wallB.start, wallB.end ) )
	{
		outIntersectionPoint = intersectionPoint;
		return true;
	}
	else
		return false;
}


wall	wall::rotated_around_point_with_angle( point rotationCenter, radians angle ) const
{
	wall	rotatedWall = *this;
	rotatedWall.start = start.rotated_around_point_with_angle( rotationCenter, angle );
	rotatedWall.end = end.rotated_around_point_with_angle( rotationCenter, angle );
	return rotatedWall;
}


wall	wall::translated_by_x_y( double xdistance, double ydistance ) const
{
	wall	movedWall = *this;
	movedWall.start = start.translated_by_x_y( xdistance, ydistance );
	movedWall.end = end.translated_by_x_y( xdistance, ydistance );
	return movedWall;
}


radians	wall::angle() const
{
	double	xdiff = end.x -start.x;
	double	ydiff = end.y -start.y;
	double	outAngle = atan2( ydiff, xdiff );
	return outAngle;
}


double	wall::distance_to_point( point pos ) const
{
	double absDistance = fabs( pos.x * (end.y -start.y) -pos.y * (end.x -start.x) + end.x * start.y - end.y * start.x )
		/ sqrt( pow( (end.y - start.y), 2 ) + pow( (end.x - start.x), 2 ) );
	
	double	orthoAngle = angle() +(M_PI / 2.0);
	point	orthoPos = pos.translated_by_distance_angle( absDistance, orthoAngle );
	
	return absDistance *((orthoPos == pos)? 1 : -1 );
}


bool	wall::intersected_with_wedge_of_lines( wall leftWall, wall rightWall, wall &outWall ) const
{
	assert( leftWall.start == rightWall.start );	// Algorithm assumes wall wedge's tip is "start" of each wall.
	
	outWall = *this;
	
	point		leftIntersection, rightIntersection;
	bool		intersectsLeft = false,
				intersectsRight = false;
	if(( intersectsLeft = intersection_with( leftWall, leftIntersection ) ))
	{
		if( wall(leftWall.start,start).angle() >= leftWall.angle() )
			outWall.start = leftIntersection;
		else
			outWall.end = leftIntersection;
	}
	if(( intersectsRight = intersection_with( rightWall, rightIntersection ) ))
	{
		if( wall(rightWall.start,end).angle() <= rightWall.angle() )
			outWall.end = rightIntersection;
		else
			outWall.start = rightIntersection;
	}
	
	// No intersection? Either fully inside or fully outside.
	if( !intersectsLeft && !intersectsRight )
	{
		double	lineStartAngle = wall(leftWall.start,start).angle();
		double	leftWallAngle = leftWall.angle();
		double	rightWallAngle = rightWall.angle();
		if( lineStartAngle >= leftWallAngle
			|| lineStartAngle <= rightWallAngle )
		{
			return false;
		}
	}

	return true;
}


wall_vector::wall_vector( std::initializer_list<point> inPoints )
{
	wall	currWall;
	for( const point& currPoint : inPoints )
	{
		currWall.start = currWall.end;
		currWall.end = currPoint;
		push_back( currWall );
	}
	(*this)[0].start = currWall.end;
}


wall_vector	wall_vector::rotated_around_point_with_angle( point rotationCenter, radians angle ) const
{
	wall_vector	rotatedWalls;
	
	for( const wall& currWall : *this )
	{
		rotatedWalls.push_back( currWall.rotated_around_point_with_angle( rotationCenter, angle ) );
	}
	
	return rotatedWalls;
}


wall_vector	wall_vector::translated_by_x_y( double xdistance, double ydistance ) const
{
	wall_vector	movedWalls;
	
	for( const wall& currWall : *this )
	{
		movedWalls.push_back( currWall.translated_by_x_y( xdistance, ydistance ) );
	}
	
	return movedWalls;
}


std::vector<std::pair<wall,point>>	wall_vector::intersections_with( wall lookLine ) const
{
	point								intersectionPoint;
	std::vector<std::pair<wall,point>>	outIntersections;
	
	for( const wall& currWall : *this )
	{
		if( lookLine.intersection_with( currWall, intersectionPoint ) )
		{
			outIntersections.push_back( std::make_pair(currWall, intersectionPoint) );
		}
	}
	
	return outIntersections;
}


wall_vector	wall_vector::intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const
{
	wall_vector	outIntersections;
	
	for( const wall& currWall : *this )
	{
		wall	intersectedWall;
		if( currWall.intersected_with_wedge_of_lines( leftWall, rightWall, intersectedWall ) )
		{
			outIntersections.push_back( intersectedWall );
		}
	}
	
	return outIntersections;
}


bool	wall_vector::closest_intersection_with_to_point( wall lookLine, point distancePoint, wall& outIntersectionWall, point& outIntersectionPoint ) const
{
	std::vector<std::pair<wall,point>>	intersections = intersections_with( lookLine );
	double								distance = DBL_MAX;
	
	for( const std::pair<wall,point>& currIntersection : intersections )
	{
		double	intersectionDistance = distancePoint.distance_to( currIntersection.second );
		if( distance > intersectionDistance )
		{
			outIntersectionWall = currIntersection.first;
			outIntersectionPoint = currIntersection.second;
			distance = intersectionDistance;
		}
	}
	
	return intersections.size() > 0;
}


object	object::translated_by_x_y( double xdistance, double ydistance ) const
{
	object	movedObject;
	
	movedObject.walls = walls.translated_by_x_y( xdistance, ydistance );
	
	return movedObject;
}


object	object::rotated_around_point_with_angle( point rotationCenter, radians angle ) const
{
	object	rotatedObject;
	
	rotatedObject.walls = walls.rotated_around_point_with_angle( rotationCenter, angle );
	
	return rotatedObject;
}


std::vector<std::pair<wall,point>>	object::intersections_with( wall lookLine ) const
{
	return walls.intersections_with( lookLine );
}


object	object::intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const
{
	object	rotatedObject;
	
	rotatedObject.walls = walls.intersected_with_wedge_of_lines( leftWall, rightWall );
	
	return rotatedObject;
}


bool	object::closest_intersection_with_to_point( wall lookLine, point distancePoint, wall& outIntersectionWall, point &outIntersectionPoint ) const
{
	return walls.closest_intersection_with_to_point( lookLine, distancePoint, outIntersectionWall, outIntersectionPoint );
}


bool	object_vector::load_file( std::string inFilePath )
{
	std::unique_ptr<tinyxml2::XMLDocument>	document( new tinyxml2::XMLDocument() );
	
	if( tinyxml2::XML_SUCCESS != document->LoadFile( inFilePath.c_str() ) )
		return false;
	
	tinyxml2::XMLElement	*	rootElem = document->RootElement();
	tinyxml2::XMLElement	*	startLocElem = rootElem->FirstChildElement("startlocation");
	startLocation.assign( startLocElem->GetText() );
	
	tinyxml2::XMLElement	*	tileElem = rootElem->FirstChildElement("tile");
	tinyxml2::XMLElement	*	objectElem = tileElem->FirstChildElement("object");
	while( objectElem )
	{
		object	newObject;
		
		std::string	colorName( "grayColor" );
		tinyxml2::XMLElement	*	colorElem = objectElem->FirstChildElement("color");
		if( colorElem )
			colorName = colorElem->GetText();
		
		tinyxml2::XMLElement	*	wallElem = objectElem->FirstChildElement("wall");
		while( wallElem )
		{
			wall	newWall;
			
			tinyxml2::XMLElement	*	startElem = wallElem->FirstChildElement("start");
			tinyxml2::XMLElement	*	endElem = wallElem->FirstChildElement("end");
			
			newWall.start.assign( startElem->GetText() );
			newWall.end.assign( endElem->GetText() );
			newWall.colorName = colorName;
			newObject.walls.push_back( newWall );
			
			wallElem = wallElem->NextSiblingElement( "wall" );
		}
		
		push_back( newObject );
		
		objectElem = objectElem->NextSiblingElement( "object" );
	}
	
	return true;
}


object_vector	object_vector::translated_by_x_y( double xdistance, double ydistance ) const
{
	object_vector	movedObjects;
	
	for( const object& currObject : *this )
	{
		movedObjects.push_back( currObject.translated_by_x_y( xdistance, ydistance ) );
	}
	
	return movedObjects;
}


object_vector	object_vector::rotated_around_point_with_angle( point rotationCenter, radians angle ) const
{
	object_vector	rotatedObjects;
	
	for( const object& currObject : *this )
	{
		rotatedObjects.push_back( currObject.rotated_around_point_with_angle( rotationCenter, angle ) );
	}
	
	return rotatedObjects;
}


object_vector	object_vector::intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const
{
	object_vector	movedObjects;
	
	for( const object& currObject : *this )
	{
		movedObjects.push_back( currObject.intersected_with_wedge_of_lines( leftWall, rightWall ) );
	}
	
	return movedObjects;
}


std::vector<object_intersection>	object_vector::intersections_with( wall lookLine ) const
{
	std::vector<object_intersection>	allIntersections;
	
	for( const object& currObject : *this )
	{
		object_intersection	objectIntersection;
		objectIntersection.object = currObject;
		objectIntersection.walls = currObject.intersections_with( lookLine );
		if( objectIntersection.walls.size() > 0 )
			allIntersections.push_back( objectIntersection );
	}
	
	return allIntersections;
}


bool	object_vector::closest_intersection_with_to_point( wall lookLine, point distancePoint, object& outIntersectionRoom, wall& outIntersectionWall, point &outIntersectionPoint ) const
{
	std::vector<object_intersection>	allIntersections = intersections_with(lookLine);
	double								distance = DBL_MAX;
	
	for( const object_intersection& currIntersection : allIntersections )
	{
		for( const std::pair<wall,point> currWallIntersection : currIntersection.walls )
		{
			double	intersectionDistance = distancePoint.distance_to( currWallIntersection.second );
			if( distance > intersectionDistance )
			{
				outIntersectionWall = currWallIntersection.first;
				outIntersectionPoint = currWallIntersection.second;
				outIntersectionRoom = currIntersection.object;
				distance = intersectionDistance;
			}
		}
	}
	
	return allIntersections.size() > 0;
}



