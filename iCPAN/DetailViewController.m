//
//  DetailViewController.m
//  iCPAN
//
//  Created by Olaf Alders on 11-05-17.
//  Copyright 2011 wundersolutions.com. All rights reserved.
//

#import "DetailViewController.h"

#import "GenericViewController.h"

#import "iCPANAppDelegate.h"

@interface DetailViewController ()
@property (nonatomic, retain) UIPopoverController *popoverController;
- (void)configureView;
@end

@implementation DetailViewController

@synthesize toolbar=_toolbar;

@synthesize detailItem=_detailItem;

@synthesize detailDescriptionLabel=_detailDescriptionLabel;

@synthesize popoverController=_myPopoverController;

@synthesize genericViewController=_genericViewController;

@synthesize webView;

#pragma mark - Managing the detail item

/*
 When setting the detail item, update the view and dismiss the popover controller if it's showing.
 */
- (void)setDetailItem:(NSManagedObject *)managedObject
{
	if (_detailItem != managedObject) {
		[_detailItem release];
		_detailItem = [managedObject retain];
		
        // Update the view.
        [self configureView];
	}
    
    if (self.popoverController != nil) {
        [self.popoverController dismissPopoverAnimated:YES];
    }		
}

- (void)configureView
{
    // Update the user interface for the detail item.

    NSLog(@"detail item %@", self.detailItem);
    self.detailDescriptionLabel.text = [[self.detailItem valueForKey:@"abstract"] description];
    
    // More webView loading
    // Basically, we'll initiate the page load here, but we'll write the page to disk later
    // This method will only ever be called when the user selects a module from the table
    // in the GenericView
	NSLog(@"looking for: %@", [self.detailItem valueForKey:@"name"]);
    //iCPANAppDelegate *del = [[UIApplication sharedApplication] delegate];
    
    //NSURL *url = [[del applicationDocumentsDirectory] URLByAppendingPathComponent:@"pod"];
    //url = [url URLByAppendingPathComponent:[self.detailItem valueForKey:@"name"]];
    NSURL *url = [[NSURL alloc] initWithString:[self.detailItem valueForKey:@"name"]];
	
	NSURLRequest *requestObj = [NSURLRequest requestWithURL:url];
	[webView loadRequest:requestObj];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"detail view will appear");

    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    NSLog(@"detail view did appear");
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Loading webView

- (void)viewDidLoad {
        
	// allow users to pinch/zoom.  also scales the page by default
	webView.scalesPageToFit = YES;
    
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	
	iCPANAppDelegate *del = [[UIApplication sharedApplication] delegate];
    
	NSURL *url = [request URL];
	NSString *path = [url relativePath];
    
	NSLog(@"relativePath: %@", [url relativePath]);
	NSLog(@"absoluteString: %@", [url absoluteString]);
	NSLog(@"baseURL: %@", [url baseURL]);	
	
	if ([[url absoluteString] rangeOfString:@"http://"].location == NSNotFound ) {
        
        // This is an offline page view. We need to handle all of the details.
        //
//		//path = [path stringByReplacingOccurrencesOfString:[[del cpanpod] absoluteString] withString:@""];
		path = [path stringByReplacingOccurrencesOfString:@"-" withString:@"::"];
		path = [path stringByReplacingOccurrencesOfString:@".html" withString:@""];
		
		NSLog(@"module to search for: %@", path);
        // remove next line once we try to follow links in webView
        path = [url absoluteString];
		
		NSManagedObjectContext *moc = [del managedObjectContext]; 
		NSFetchRequest *req = [[NSFetchRequest alloc] init];
		[req setEntity:[NSEntityDescription entityForName:@"Module" inManagedObjectContext:moc]];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", path];
		[req setPredicate:predicate];
		
		NSError *error = nil;
		NSArray *results = [moc executeFetchRequest:req error:&error];
        
		if (error) {
			// Replace this implementation with code to handle the error appropriately.
            
			NSLog(@"there has been an error");
			NSLog(@"fetchedResultsController error %@, %@", error, [error userInfo]);
			//exit(1);
		} 
        
        
		if ( results.count > 0 ) {
			
			Module *module = [results objectAtIndex:0];
			//NSLog(@"results for single module search %@", module.name );
			
			//NSLog(@"This is a local URL");
			
			self.title = module.name;
			//self.currentlyViewing = module.name;
			//NSInteger is_bookmarked = [del isBookmarked:path];
			/*if ( is_bookmarked == 1 ) {
				[self removeBookmarkButton];
			}
			else {
				[self addBookmarkButton];
			}
            */
			
			NSString *fileName = module.name;
			fileName = [fileName stringByReplacingOccurrencesOfString:@"::" withString:@"-"];
			fileName = [fileName stringByAppendingString:@".html"];
            NSString *podPath = [[[del cpanpod] URLByAppendingPathComponent:fileName] absoluteString];
            
			if ( ![[NSFileManager defaultManager] fileExistsAtPath:podPath] ) {
				NSLog(@"pod path: %@", del.cpanpod);
				NSLog(@"pod will be written to: %@", podPath);
				NSData* pod_data = [module.pod dataUsingEncoding:NSUTF8StringEncoding];
				[pod_data writeToFile:podPath atomically:YES];
			}
		}
		else {
			self.navigationItem.rightBarButtonItem = nil;
			self.title = @"404: Page Not Found";
		}
		
		[req release];
	}
	else {
		// we are now online
		self.navigationItem.rightBarButtonItem = nil;
		self.title = [url absoluteString];
	}
	
	//NSArray *dirContents = [[NSFileManager defaultManager] directoryContentsAtPath:del.cpanpod];
	//NSLog(@"contents %@", dirContents);
    
	return TRUE;
}

#pragma mark - Split view support

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController: (UIPopoverController *)pc
{
    barButtonItem.title = @"Events";
    NSMutableArray *items = [[self.toolbar items] mutableCopy];
    [items insertObject:barButtonItem atIndex:0];
    [self.toolbar setItems:items animated:YES];
    [items release];
    self.popoverController = pc;
}

// Called when the view is shown again in the split view, invalidating the button and popover controller.
- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    NSMutableArray *items = [[self.toolbar items] mutableCopy];
    [items removeObjectAtIndex:0];
    [self.toolbar setItems:items animated:YES];
    [items release];
    self.popoverController = nil;
}

/*
 // Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
 */

- (void)viewDidUnload
{
	[super viewDidUnload];

	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.popoverController = nil;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
    [_myPopoverController release];
    [_toolbar release];
    [_detailItem release];
    [_detailDescriptionLabel release];
    [super dealloc];
}

@end
