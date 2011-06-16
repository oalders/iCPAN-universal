//
//  GenericViewController.h
//  iCPAN
//
//  Created by Olaf Alders on 11-05-18.
//  Copyright 2011 wundersolutions.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DetailViewController;

@interface GenericViewController : UIViewController <UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate> {
    NSManagedObjectContext *managedObjectContext;
}

@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSMutableArray *searchResults;

- (void) searchModules;

@end
