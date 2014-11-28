//
//  ICGKeychainWrapper.h
//  interconnectgame
//
//  Created by Uli Kusterer on 2014-11-28.
//  Copyright (c) 2011 Chris Lowe. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonHMAC.h>


@interface ICGKeychainWrapper : NSObject
 
// Generic exposed method to search the keychain for a given value. Limit one result per search.
+ (NSData *)searchKeychainCopyMatchingIdentifier:(NSString *)identifier;
 
// Calls searchKeychainCopyMatchingIdentifier: and converts to a string value.
+ (NSString *)keychainStringFromMatchingIdentifier:(NSString *)identifier;
 
// Default initializer to store a value in the keychain.
// Associated properties are handled for you - setting Data Protection Access, Company Identifer (to uniquely identify string, etc).
+ (BOOL)createKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier;
 
// Updates a value in the keychain. If you try to set the value with createKeychainValue: and it already exists,
// this method is called instead to update the value in place.
+ (BOOL)updateKeychainValue:(NSString *)value forIdentifier:(NSString *)identifier;
 
// Delete a value in the keychain.
+ (void)deleteItemFromKeychainWithIdentifier:(NSString *)identifier;
 
@end
