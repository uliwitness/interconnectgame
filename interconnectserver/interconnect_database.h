//
//  interconnect_database.h
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-11-29.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#ifndef __interconnectserver__inerconnect_database__
#define __interconnectserver__inerconnect_database__

#include "eleven_database_mysql.h"
#include <vector>
#include <functional>


namespace interconnect
{
	typedef uint32_t	mission_id;
	typedef uint32_t	mission_objective_id;
	
	typedef uint32_t	map_object_id;
	
	class user_state
	{
	public:
		user_state() : mPrimaryMission(0)	{};
		user_state( std::string inCurrentRoomName, mission_id inPrimaryMission ) : mCurrentRoom(inCurrentRoomName), mPrimaryMission(inPrimaryMission)	{};
		
		std::string		mCurrentRoom;
		mission_id		mPrimaryMission;
	};
	
	class mission_objective
	{
	public:
		mission_objective() : mID(0), mMaxCount(1), mCurrentCount(0), mPhysicalLocation(0)	{};
		mission_objective( mission_objective_id inID, std::string inName, uint32_t inMaxCount, uint32_t inCount, std::string inRoomName, map_object_id inLocation ) : mID(inID), mDisplayName(inName), mMaxCount(inMaxCount), mCurrentCount(inCount), mRoomName(inRoomName), mPhysicalLocation(inLocation)	{};
		
		mission_objective_id	mID;
		std::string				mDisplayName;
		uint32_t				mMaxCount;			// 1 means nothing countable about this objective.
		uint32_t				mCurrentCount;		// mCurrentCount == mMaxCount means objective complete.
		std::string				mRoomName;			// Room in which mPhysicalLocation resides.
		map_object_id			mPhysicalLocation;	// Location to mark on map while this objective is in progress.
	};
	
	class mission
	{
	public:
		mission() : mID(0)	{};
		mission( mission_id inID, std::string inName, std::string inRoomName, map_object_id inPhysicalLocation ) : mID(inID), mDisplayName(inName), mCurrentRoomName(inRoomName), mPhysicalLocation(inPhysicalLocation)	{};
		
		mission_id				mID;
		std::string				mDisplayName;
		std::string				mCurrentRoomName;
		map_object_id			mPhysicalLocation;
	};
	
	class database : public eleven::database_mysql
	{
	public:
		database( std::string inSettingsFolderPath ) : database_mysql( inSettingsFolderPath ) {};
	
		/*! Retrieve complete current client state for this user and
			inform the missions, objectives and user state callback of it. */
		void	request_current_state( eleven::user_id currentUser );
		
		void	set_user_state( mission_id inPrimaryMissionID, std::string inCurrentRoomName, eleven::user_id currentUser );
		void	add_mission_for_user( mission_id inMissionID, std::string inDisplayName, std::string inRoomName, map_object_id inPhysicalLocation, eleven::user_id currentUser );
		void	add_objective_to_mission_for_user( mission_objective_id inID, std::string inDisplayName, uint32_t mMaxCount, std::string inRoomName, map_object_id inPhysicalLocation, mission_id inMissionID, eleven::user_id currentUser );
		void	add_count_to_objective_of_mission_for_user( int32_t inCount, mission_objective_id inID, mission_id inMissionID, eleven::user_id currentUser );
		void	delete_objective_of_mission_for_user( mission_objective_id inID, mission_id inMissionID, eleven::user_id currentUser );
		void	delete_mission_for_user( mission_id inMissionID, eleven::user_id currentUser );
		
		void	set_missions_callback( std::function<void(const mission&,eleven::user_id)> inMissionsCallback )	{ mMissionsCallback = inMissionsCallback; };	// When you receive a mission, Caller should throw away any objectives she may have cached for it. The objectives callback will be called soon with its objectives.
		void	set_objectives_callback( std::function<void(const mission_objective&,mission_id,eleven::user_id)> inObjectivesCallback )	{ mObjectivesCallback = inObjectivesCallback; };	// Client should add this objective to the list of mission objectives for the specified user.
		void	set_user_state_callback( std::function<void(const user_state&,eleven::user_id)> inUserStateCallback )	{ mUserStateCallback = inUserStateCallback; };	// Client should use this state to find out what room to display and what mission to show at top of mission log.
		
	protected:
		std::function<void(const mission&,eleven::user_id)>	mMissionsCallback;
		std::function<void(const mission_objective&,mission_id,eleven::user_id)>	mObjectivesCallback;
		std::function<void(const user_state&,eleven::user_id)>	mUserStateCallback;
	};

}

#endif /* defined(__interconnectserver__inerconnect_database__) */
