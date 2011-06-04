//
//  GenericViewController.m
//  iCPAN
//
//  Created by Olaf Alders on 11-05-18.
//  Copyright 2011 wundersolutions.com. All rights reserved.
//

#import "GenericViewController.h"
#import "iCPANAppDelegate_iPad.h"


@implementation GenericViewController

@synthesize managedObjectContext, searchResults;

- (void) insertDummyData
{
    
    iCPANAppDelegate *del = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *context = del.managedObjectContext;
    
    //NSManagedObject *author = [NSEntityDescription
    //                           insertNewObjectForEntityForName:@"Author" 
    //                           inManagedObjectContext:context];
    //[author setValue:@"OALDERS" forKey:@"pauseid"];
    //[author setValue:@"Olaf Alders" forKey:@"name"];
    //[author setValue:@"olaf@wundersolutions.com" forKey:@"email"];
    
    NSError *error;
    //if (![context save:&error]) {
    //    NSLog(@"Whoops, couldn't save: %@ %@", [error localizedDescription], error);
    //}
    //NSLog(@"dummy data inserted");
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Module" inManagedObjectContext:context];
    [request setEntity:entity];
    [request setFetchLimit:50];
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    [request setSortDescriptors:[NSArray arrayWithObject:sort]];
    
    // Execute the fetch — create a mutable copy of the result.
    error = nil;
    NSMutableArray *mutableFetchResults = [[context executeFetchRequest:request error:&error] mutableCopy];
    NSLog(@"got %i results", [mutableFetchResults count]);
    if (mutableFetchResults == nil) {
        // Handle the error.
        NSLog(@"Whoops, couldn't read: %@", [error localizedDescription]);
    }
    self.searchResults = mutableFetchResults;
    
    [request release];
    
    NSLog(@"tables should have been created");
    
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self insertDummyData];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.searchResults count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"CellIdentifier";
    
    // Dequeue or create a cell of the appropriate type.
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    // Configure the cell.
    //NSLog(@"cell %@", [[self.searchResults objectAtIndex:indexPath.row] name]);
    cell.textLabel.text = [[self.searchResults objectAtIndex:indexPath.row] name];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    return cell;
}


@end
