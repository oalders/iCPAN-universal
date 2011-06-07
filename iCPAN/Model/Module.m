//
//  Module.m
//  iCPAN
//
//  Created by Olaf Alders on 11-06-07.
//  Copyright (c) 2011 wundersolutions.com. All rights reserved.
//

#import "Module.h"


@implementation Module
@dynamic pod;
@dynamic name;
@dynamic abstract;
@dynamic distribution;
@dynamic path;

- (NSString *)path {
	
    NSString *path = [self.name stringByReplacingOccurrencesOfString:@"::" withString:@"-"];
    path = [path stringByAppendingString:@".html"];
    
    return path;
    
}


@end
