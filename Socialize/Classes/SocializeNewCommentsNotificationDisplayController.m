//
//  SocializeNewCommentsNotificationHandler.m
//  SocializeSDK
//
//  Created by Nathaniel Griswold on 1/9/12.
//  Copyright (c) 2012 Socialize, Inc. All rights reserved.
//

#import "SocializeNewCommentsNotificationDisplayController.h"
#import "SocializeActivityDetailsViewController.h"
#import "SocializeCommentsTableViewController.h"

@implementation SocializeNewCommentsNotificationDisplayController
@synthesize navigationController = navigationController_;
@synthesize commentsTableViewController = commentsTableViewController_;
@synthesize activityDetailsViewController = activityDetailsViewController_;

- (void)dealloc {
    [activityDetailsViewController_ setDelegate:nil];
    self.activityDetailsViewController = nil;
    [commentsTableViewController_ setDelegate:nil];
    self.commentsTableViewController = nil;
    self.navigationController = nil;
    
    [super dealloc];
}

- (SocializeActivityDetailsViewController*)activityDetailsViewController {
    if (activityDetailsViewController_ == nil) {
        activityDetailsViewController_ = [[SocializeActivityDetailsViewController alloc] init];
        activityDetailsViewController_.delegate = self;
        
    }
    return activityDetailsViewController_;
}

- (SocializeCommentsTableViewController*)commentsTableViewController {
    if (commentsTableViewController_ == nil) {
        commentsTableViewController_ = [[SocializeCommentsTableViewController alloc] initWithNibName:nil bundle:nil entryUrlString:nil];
        commentsTableViewController_.delegate = self;
    }
    return commentsTableViewController_;
}

- (UIViewController*)mainViewController {
    return self.navigationController;
}

- (UINavigationController*)navigationController {
    if (navigationController_ == nil) {
        navigationController_ = [[UINavigationController alloc] initWithRootViewController:self.commentsTableViewController];
        [navigationController_ pushViewController:self.activityDetailsViewController animated:NO];
        navigationController_.delegate = self;
    }
    return navigationController_;
}

- (void)activityDetailsViewController:(SocializeActivityDetailsViewController *)activityDetailsViewController didLoadActivity:(id<SocializeActivity>)activity {
    // Copy the entity info from the activity details, since it already fetched it.
    self.commentsTableViewController.entity = activity.entity;
}

- (void)commentsTableViewControllerDidFinish:(SocializeCommentsTableViewController *)commentsTableViewController {
    [self.delegate notificationDisplayControllerDidFinish:self];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (viewController == self.activityDetailsViewController) {
        viewController.title = @"New Comment";
        viewController.navigationItem.rightBarButtonItem = nil;
        
        NSAssert([self.activityType isEqualToString:@"comment"], @"Socialize Notification is of type new_comments, but activity is not a comment");
        NSAssert(self.activityID != nil, @"Socialize Notification is Missing Comment ID");
        
        [self.activityDetailsViewController fetchActivityForType:self.activityType activityID:self.activityID];
    } else if (viewController == self.commentsTableViewController) {
        [self.delegate notificationDisplayControllerDidFinish:self];
    }
}

@end