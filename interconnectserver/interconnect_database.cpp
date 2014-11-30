//
//  interconnect_database.cpp
//  interconnectserver
//
//  Created by Uli Kusterer on 2014-11-29.
//  Copyright (c) 2014 Uli Kusterer. All rights reserved.
//

#include "interconnect_database.h"
#include "eleven_log.h"
#include <cppconn/prepared_statement.h>


#define NO_MISSIONS_ID				0
#define NO_MISSIONS_ROOM_NAME		"hub"
#define NO_MISSIONS_MISSION_NAME	""


using namespace interconnect;


void	database::request_current_state( eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	sql::ResultSet			*res = NULL;
	user_state				currUserState;
	bool					foundUserState = false;
	
	try
	{
		stmt = mConnection->prepareStatement( "SELECT * FROM user_state WHERE userid=?" );
		stmt->setInt( 1, currentUser );
		res = stmt->executeQuery();
		while( res->next() )
		{
			currUserState.mPrimaryMission = res->getInt("primarymissionid");
			currUserState.mCurrentRoom = res->getString("currentroom");
			
			mUserStateCallback( currUserState, currentUser );
			foundUserState = true;
			break;
		}
		delete res;
		delete stmt;
		
		if( !foundUserState )	// User had no state yet.
		{
			mUserStateCallback( currUserState, currentUser );
		}
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Nobody's had any missions yet.
		{
			mMissionsCallback( mission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME ), currentUser );
		}
		else
		{
			eleven::log( "Error finding missions: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}

	mission		currMission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME );
	
	try
	{
		stmt = mConnection->prepareStatement( "SELECT * FROM missions WHERE userid=?" );
		stmt->setInt( 1, currentUser );
		res = stmt->executeQuery();
		while( res->next() )
		{
			currMission.mID = res->getInt("id");
			currMission.mDisplayName = res->getString("name");	// +++ LOCALIZE!
			currMission.mCurrentRoomName = res->getString("roomname");
			
			mMissionsCallback( currMission, currentUser );
		}
		delete res;
		delete stmt;
		
		if( currMission.mID == NO_MISSIONS_ID )	// Make sure "no missions" is communicated, too.
		{
			mMissionsCallback( currMission, currentUser );
		}
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Nobody's had any missions yet.
		{
			mMissionsCallback( mission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME ), currentUser );
		}
		else
		{
			eleven::log( "Error finding missions: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}
	
	try
	{
		mission_objective	currObjective;
		stmt = mConnection->prepareStatement( "SELECT * FROM mission_objectives WHERE userid=?" );
		stmt->setInt( 1, currentUser );
		res = stmt->executeQuery();
		while( res->next() )
		{
			currObjective.mID = res->getInt("id");
			currObjective.mPhysicalLocation = res->getInt("physicallocation");
			currObjective.mDisplayName = res->getString("name");	// +++ LOCALIZE!
			currObjective.mMaxCount = res->getInt("maxcount");
			currObjective.mCurrentCount = res->getInt("currentcount");
			mission_id	currMissionID = res->getInt("missionid");
			
			mObjectivesCallback( currObjective, currMissionID, currentUser );
		}
		delete res;
		delete stmt;
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Nobody's had any missions with objectives yet.
		{
			// Just ignore.
		}
		else
		{
			eleven::log( "Error finding missions: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}
}


void	database::add_mission_for_user( mission_id inMissionID, std::string inDisplayName, std::string inRoomName, eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	mission					currMission( inMissionID, inDisplayName, inRoomName );
	
	try
	{
		stmt = mConnection->prepareStatement( "INSERT INTO missions ( id, name, roomname, userid ) VALUES ( ?, ?, ?, ? )" );
		stmt->setInt( 1, inMissionID );
		stmt->setString( 2, inDisplayName );
		stmt->setString( 3, inRoomName );
		stmt->setInt( 4, currentUser );
		stmt->execute();
		delete stmt;
		
		mMissionsCallback( currMission, currentUser );
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Create it!
		{
			try
			{
				sql::Statement *stmt2 = mConnection->createStatement();
				stmt2->execute(	"CREATE TABLE missions\n"
								"(\n"
								"id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,\n"
								"name CHAR(255),\n"
								"roomname CHAR(255) NOT NULL,\n"
								"userid INT\n"
								");\n");
				delete stmt2;
				
				stmt = mConnection->prepareStatement( "INSERT INTO missions ( id, name, roomname, userid ) VALUES ( ?, ?, ?, ? )" );
				stmt->setInt( 1, inMissionID );
				stmt->setString( 2, inDisplayName );
				stmt->setString( 3, inRoomName );
				stmt->setInt( 4, currentUser );
				stmt->execute();
				delete stmt;
				
				mMissionsCallback( currMission, currentUser );
			}
			catch (sql::SQLException &e2)
			{
				eleven::log( "Error adding mission: %s (code=%d state=%s)\n", e2.what(), e2.getErrorCode(), e2.getSQLState().c_str() );
			}
		}
		else
		{
			eleven::log( "Error adding mission: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}
}


void	database::add_objective_to_mission_for_user( mission_objective_id inID, std::string inDisplayName, uint32_t inMaxCount, map_object_id inPhysicalLocation, mission_id inMissionID, eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	mission_objective		currObjective( inID, inDisplayName, inMaxCount, 0, inPhysicalLocation );
	
	try
	{
		stmt = mConnection->prepareStatement( "INSERT INTO mission_objectives ( id, name, maxcount, currentcount, missionid, physicallocation, userid ) VALUES ( ?, ?, ?, ?, ?, ?, ? )" );
		stmt->setInt( 1, inID );
		stmt->setString( 2, inDisplayName );
		stmt->setInt( 3, inMaxCount );
		stmt->setInt( 4, 0 );
		stmt->setInt( 5, inMissionID );
		stmt->setInt( 6, inPhysicalLocation );
		stmt->setInt( 7, currentUser );
		stmt->execute();
		delete stmt;
		
		mObjectivesCallback( currObjective, inMissionID, currentUser );
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Create it!
		{
			try
			{
				sql::Statement *stmt2 = mConnection->createStatement();
				stmt2->execute(	"CREATE TABLE mission_objectives\n"
								"(\n"
								"id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,\n"
								"name CHAR(255) NOT NULL,\n"
								"maxcount INT,\n"
								"currentcount INT,\n"
								"missionid INT,\n"
								"physicallocation INT,\n"
								"userid INT\n"
								");\n");
				delete stmt2;
				
				stmt = mConnection->prepareStatement( "INSERT INTO mission_objectives ( id, name, maxcount, currentcount, missionid, physicallocation, userid ) VALUES ( ?, ?, ?, ?, ?, ?, ? )" );
				stmt->setInt( 1, inID );
				stmt->setString( 2, inDisplayName );
				stmt->setInt( 3, inMaxCount );
				stmt->setInt( 4, 0 );
				stmt->setInt( 5, inMissionID );
				stmt->setInt( 6, inPhysicalLocation );
				stmt->setInt( 7, currentUser );
				stmt->execute();
				delete stmt;
				
				mObjectivesCallback( currObjective, inMissionID, currentUser );
			}
			catch (sql::SQLException &e2)
			{
				eleven::log( "Error adding mission objectives: %s (code=%d state=%s)\n", e2.what(), e2.getErrorCode(), e2.getSQLState().c_str() );
			}
		}
		else
		{
			eleven::log( "Error adding mission objectives: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}
}


void	database::add_count_to_objective_of_mission_for_user( int32_t inCount, mission_objective_id inID, mission_id inMissionID, eleven::user_id currentUser )
{
	/*
		!!! ASSUMPTION!
		
		This code only works if there is only ever one session per user. As soon as 2 sessions call this from different threads, we'll lose increments and we'd need a lock on the database.
	*/
	
	sql::PreparedStatement	*stmt = NULL;
	sql::ResultSet			*res = NULL;
	mission					currMission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME );
	
	try
	{
		int		currAmount = 0;
		
		stmt = mConnection->prepareStatement( "SELECT * FROM mission_objectives WHERE userid=? AND id=? AND missionid=?;" );
		stmt->setInt( 1, currentUser );
		stmt->setInt( 2, inID );
		stmt->setInt( 3, inMissionID );
		res = stmt->executeQuery();
		while( res->next() )
		{
			currAmount = res->getInt("currentcount");
			break;
		}
		delete res;
		delete stmt;
		
		stmt = mConnection->prepareStatement( "UPDATE mission_objectives SET currentcount=? WHERE userid=? AND id=? AND missionid=?;" );
		stmt->setInt( 1, currAmount +inCount );
		stmt->setInt( 2, currentUser );
		stmt->setInt( 3, inID );
		stmt->setInt( 4, inMissionID );
		stmt->execute();
		delete stmt;
	}
	catch (sql::SQLException &e)
	{
		eleven::log( "Error finding missions: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
	}
}


void	database::delete_objective_of_mission_for_user( mission_objective_id inID, mission_id inMissionID, eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	mission					currMission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME );
	
	try
	{
		stmt = mConnection->prepareStatement( "DELETE FROM mission_objectives WHERE userid=? AND id=? AND missionid=?" );
		stmt->setInt( 1, currentUser );
		stmt->setInt( 2, inID );
		stmt->setInt( 3, inMissionID );
		stmt->execute();
		delete stmt;
	}
	catch (sql::SQLException &e)
	{
		eleven::log( "Error deleting mission objective: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
	}
}


void	database::delete_mission_for_user( mission_id inMissionID, eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	mission					currMission( NO_MISSIONS_ID, NO_MISSIONS_MISSION_NAME, NO_MISSIONS_ROOM_NAME );
	
	try
	{
		stmt = mConnection->prepareStatement( "DELETE FROM missions WHERE userid=? AND id=?" );
		stmt->setInt( 1, currentUser );
		stmt->setInt( 2, inMissionID );
		stmt->execute();
		delete stmt;

		stmt = mConnection->prepareStatement( "DELETE FROM mission_objectives WHERE userid=? AND missionid=?" );
		stmt->setInt( 1, currentUser );
		stmt->setInt( 2, inMissionID );
		stmt->execute();
		delete stmt;
	}
	catch (sql::SQLException &e)
	{
		eleven::log( "Error deleting mission: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
	}
}


void	database::set_user_state( mission_id inPrimaryMissionID, std::string inCurrentRoomName, eleven::user_id currentUser )
{
	sql::PreparedStatement	*stmt = NULL;
	sql::ResultSet			*res = NULL;
	user_state				currUserState( inCurrentRoomName, inPrimaryMissionID );
	
	try
	{
		bool	exists = false;
		stmt = mConnection->prepareStatement( "SELECT userid FROM user_state WHERE userid=?;" );
		stmt->setInt( 1, currentUser );
		res = stmt->executeQuery();
		while( res->next() )
		{
			exists = true;
			break;
		}
		delete res;
		delete stmt;

		if( exists )
		{
			stmt = mConnection->prepareStatement( "UPDATE user_state SET primarymissionid=?, currentroom=? WHERE userid=?;" );
		}
		else	// First time this user logged in, but not first user ever!
		{
			stmt = mConnection->prepareStatement( "INSERT INTO user_state ( primarymissionid, currentroom, userid ) VALUES ( ?, ?, ? );" );
		}
		stmt->setInt( 1, inPrimaryMissionID );
		stmt->setString( 2, inCurrentRoomName );
		stmt->setInt( 3, currentUser );
		stmt->execute();
		delete stmt;
		
		mUserStateCallback( currUserState, currentUser );
	}
	catch (sql::SQLException &e)
	{
		if( e.getErrorCode() == 1146 )	// No such table? Create it! First user ever!
		{
			try
			{
				sql::Statement *stmt2 = mConnection->createStatement();
				stmt2->execute(	"CREATE TABLE user_state\n"
								"(\n"
								"userid INT NOT NULL PRIMARY KEY,\n"
								"currentroom CHAR(255) NOT NULL,\n"
								"primarymissionid INT\n"
								");\n");
				delete stmt2;
				
				stmt = mConnection->prepareStatement( "INSERT INTO user_state ( primarymissionid, currentroom, userid ) VALUES ( ?, ?, ? );" );
				stmt->setInt( 1, inPrimaryMissionID );
				stmt->setString( 2, inCurrentRoomName );
				stmt->setInt( 3, currentUser );
				stmt->execute();
				delete stmt;
				
				mUserStateCallback( currUserState, currentUser );
			}
			catch (sql::SQLException &e2)
			{
				eleven::log( "Error adding user state: %s (code=%d state=%s)\n", e2.what(), e2.getErrorCode(), e2.getSQLState().c_str() );
			}
		}
		else
		{
			eleven::log( "Error changing user state: %s (code=%d state=%s)\n", e.what(), e.getErrorCode(), e.getSQLState().c_str() );
		}
	}
}




