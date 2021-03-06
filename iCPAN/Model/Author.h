//
//  Author.h
//  iCPAN
//
//  Created by Olaf Alders on 11-06-07.
//  Copyright (c) 2011 wundersolutions.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Author : NSManagedObject {
@private
}
@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * pauseid;
@property (nonatomic, retain) NSSet* distributions;

@end
