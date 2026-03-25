//
//  MPUpdateChecker.h
//  Markly
//

#import <Foundation/Foundation.h>

@interface MPUpdateChecker : NSObject

+ (instancetype)sharedChecker;

/// Check GitHub Releases for a newer version. If userInitiated is YES,
/// always show a result (even "up to date"). Otherwise only show if update found.
- (void)checkForUpdatesUserInitiated:(BOOL)userInitiated;

/// Called from the menu item
- (IBAction)checkForUpdates:(id)sender;

@end
