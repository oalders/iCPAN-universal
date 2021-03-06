//
//  Author.m
//  iCPAN
//
//  Created by Olaf Alders on 11-06-07.
//  Copyright (c) 2011 wundersolutions.com. All rights reserved.
//

#import "Author.h"


@implementation Author
@dynamic email;
@dynamic name;
@dynamic pauseid;
@dynamic distributions;

- (void)addDistributionsObject:(NSManagedObject *)value {    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"distributions" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"distributions"] addObject:value];
    [self didChangeValueForKey:@"distributions" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

- (void)removeDistributionsObject:(NSManagedObject *)value {
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"distributions" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"distributions"] removeObject:value];
    [self didChangeValueForKey:@"distributions" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [changedObjects release];
}

- (void)addDistributions:(NSSet *)value {    
    [self willChangeValueForKey:@"distributions" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"distributions"] unionSet:value];
    [self didChangeValueForKey:@"distributions" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

- (void)removeDistributions:(NSSet *)value {
    [self willChangeValueForKey:@"distributions" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"distributions"] minusSet:value];
    [self didChangeValueForKey:@"distributions" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
}


@end
