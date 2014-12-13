//
//  interconnect_map.h
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-12-13.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#ifndef __interconnectserver__interconnect_map__
#define __interconnectserver__interconnect_map__

#include <vector>
#include <CoreGraphics/CoreGraphics.h>

namespace interconnect
{
	typedef double	radians;
	
	class point
	{
	public:
		point() : x(0), y(0) {};
		point( double inX, double inY ) : x(inX), y(inY) {};
		
		double	distance_to( point inPos ) const;
		bool	is_between( point posA, point posB ) const;
		point	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		point	translated_by_distance_angle( double distance, radians angle ) const;
		point	translated_by_x_y( double xdistance, double ydistance ) const;
	
		operator CGPoint() const
		{
			return CGPointMake( x, y );
		}
		
		double		x;
		double		y;
	};
	
	
	class wall
	{
	public:
		wall() {};
		wall( point inStart, point inEnd ) : start(inStart), end(inEnd) {};
		
		bool	intersection_with( wall wallB, point& outIntersectionPoint ) const;
		wall	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		wall	translated_by_x_y( double xdistance, double ydistance ) const;
		
		point		start;
		point		end;
	};
	
	
	class wall_vector : public std::vector<wall>
	{
	public:
		wall_vector() : vector() {};
		explicit wall_vector( size_t nitems ) : vector(nitems) {};
		wall_vector( std::initializer_list<point> inPoints );	// Takes a list of points and adds the walls between these points to this array.
		
		wall_vector	translated_by_x_y( double xdistance, double ydistance ) const;
		wall_vector	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		std::vector<std::pair<wall,point>>	intersections_with( wall lookLine ) const;
		bool								closest_intersection_with_to_point( wall lookLine, point distancePoint, wall& outIntersectionWall, point &outIntersectionPoint ) const;
	};
}

#endif /* defined(__interconnectserver__interconnect_map__) */
