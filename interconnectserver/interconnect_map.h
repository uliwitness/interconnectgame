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
#include <functional>
#include <CoreGraphics/CoreGraphics.h>
#include <OpenGL/OpenGL.h>


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
		size_t		count_points_for_3d() const { return 4; };
		void		points_for_3d( std::vector<GLfloat> &outPoints ) const;
		
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
		size_t	count_points_for_3d() const;
		void	points_for_3d( std::vector<GLfloat> &outPoints ) const;

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
		size_t	count_points_for_3d() const;
		size_t	count_walls() const	{ return walls.size(); };
		void	points_for_3d( std::vector<GLfloat> &outPoints ) const;

		wall_vector		walls;
	};
	
	
	struct object_intersection
	{
		std::vector<std::pair<wall,point>>	walls;
		object								object;
	};
	
	
	typedef std::function<void(class object_vector*)>	change_callback;
	
	
	class object_vector : public std::vector<object>
	{
	public:
		object_vector() : vector(), currAngle(0) {};
		explicit object_vector( size_t nitems ) : vector(nitems), currAngle(0) {};
		
		bool			load_file( std::string inFilePath );
		
		object_vector	translated_by_x_y( double xdistance, double ydistance ) const;
		object_vector	rotated_around_point_with_angle( point rotationCenter, radians angle ) const;
		object_vector	intersected_with_wedge_of_lines( wall leftWall, wall rightWall ) const;
		std::vector<object_intersection>	intersections_with( wall lookLine ) const;
		bool								closest_intersection_with_to_point( wall lookLine, point distancePoint, object& outIntersectionRoom, wall& outIntersectionWall, point &outIntersectionPoint ) const;
		void	strafe( double distance );
		void	walk( double distance );
		void	turn( double numStepsIn360 );	// It will turn one of these steps. Specify a negative number to turn the other direction.
		void	project( point viewCenter, object_vector& outProjectedVector, bool mapModeDisplay ) const;
		void	cull_invisible( point viewCenter, double distance, object_vector& outProjectedVector );
		size_t	count_points_for_3d() const;
		size_t	count_walls() const;
		void	points_for_3d( std::vector<GLfloat> &outPoints ) const;
		void	add_change_listener( change_callback inCallback )	{ changeListeners.push_back( inCallback ); };
		
		std::vector<change_callback>	changeListeners;
		point							startLocation;	// The start location in the map. Assign this to currPos on initially entering a map.
		point							currPos;		// The position of the character in the world.
		radians							currAngle;		// The direction the character is facing in the world.
	};
}

#endif /* defined(__interconnectserver__interconnect_map__) */
