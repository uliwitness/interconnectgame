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
#include <string>
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
		
		std::string	to_string() { std::string str( std::to_string(x) ); str.append(1,','); str.append( std::to_string(y) ); return str; };
		void		assign( std::string inString )	{ size_t separatorPos = inString.find(','); x = strtol( inString.substr(0,separatorPos).c_str(), NULL, 10 ); y = strtol( inString.substr(separatorPos+1).c_str(), NULL, 10 ); };
		
		bool	operator ==( const point& otherPos )	{ return otherPos.x == x && otherPos.y == y; };
		
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
		wall() : colorName("blackColor") {};
		wall( point inStart, point inEnd ) : start(inStart), end(inEnd), colorName("blackColor") {};
		
		bool	intersection_with( wall wallB, point& outIntersectionPoint ) const;
		wall	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		wall	translated_by_x_y( double xdistance, double ydistance ) const;
		double	distance_to_point( point pos ) const;
		bool	intersected_with_wedge_of_lines( wall leftWall, wall rightWall, wall &outWall ) const;
		radians		angle() const;
		
		std::string	colorName;
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
		wall_vector							intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const;
		bool								closest_intersection_with_to_point( wall lookLine, point distancePoint, wall& outIntersectionWall, point &outIntersectionPoint ) const;

		void	set_color_name( std::string inColorName )	{ for( wall& currWall : *this ) currWall.colorName = inColorName; };
	};
	
	
	class object
	{
	public:
		object	translated_by_x_y( double xdistance, double ydistance ) const;
		object	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		std::vector<std::pair<wall,point>>	intersections_with( wall lookLine ) const;
		object								intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const;
		bool								closest_intersection_with_to_point( wall lookLine, point distancePoint, wall& outIntersectionWall, point &outIntersectionPoint ) const;
		void	set_color_name( std::string inColorName )	{ walls.set_color_name(inColorName); };

		wall_vector		walls;
	};
	
	
	struct object_intersection
	{
		std::vector<std::pair<wall,point>>	walls;
		object								object;
	};
	
	
	class object_vector : public std::vector<object>
	{
	public:
		object_vector() : vector() {};
		explicit object_vector( size_t nitems ) : vector(nitems) {};
		
		bool			load_file( std::string inFilePath );
		
		object_vector	translated_by_x_y( double xdistance, double ydistance ) const;
		object_vector	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		object_vector	intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const;
		std::vector<object_intersection>	intersections_with( wall lookLine ) const;
		bool								closest_intersection_with_to_point( wall lookLine, point distancePoint, object& outIntersectionRoom, wall& outIntersectionWall, point &outIntersectionPoint ) const;
		
		point	startLocation;
	};
}

#endif /* defined(__interconnectserver__interconnect_map__) */
