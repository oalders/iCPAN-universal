//
//  DetailViewController.h
//  iCPAN
//
//  Created by Olaf Alders on 11-05-17.
//  Copyright 2011 wundersolutions.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Module.h"

@class GenericViewController;

@interface DetailViewController : UIViewController <UIPopoverControllerDelegate, UISplitViewControllerDelegate,UIWebViewDelegate> {
    UIWebView *webView;
    UIBarButtonItem *backButton;
    UIBarButtonItem *forwardButton;
    UIBarButtonItem *refreshButton;
    UIBarButtonItem *stopButton;
}


@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;

@property (nonatomic, retain) Module *detailItem;

@property (nonatomic, retain) IBOutlet UILabel *detailDescriptionLabel;

@property (nonatomic, assign) IBOutlet GenericViewController *genericViewController;

@property (nonatomic, retain) IBOutlet UIWebView *webView;

@property (nonatomic, retain) NSString *moduleFile;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *backButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *forwardButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *refreshButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *stopButton;


@end
