//
//  iCPANSplitViewAppDelegate.h
//  iCPANSplitView
//
//  Created by Olaf Alders on 11-05-17.
//  Copyright 2011 wundersolutions.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "iCPANAppDelegate.h"

@class RootViewController;

@class DetailViewController;

@interface iCPANSplitViewAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UISplitViewController *splitViewController;

@property (nonatomic, retain) IBOutlet RootViewController *rootViewController;

@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;

@end
