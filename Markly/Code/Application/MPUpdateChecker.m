//
//  MPUpdateChecker.m
//  Markly
//

#import "MPUpdateChecker.h"

static NSString * const kMPGitHubReleasesAPI = @"https://api.github.com/repos/Wirtzer/Markly/releases/latest";
static NSString * const kMPLastUpdateCheckKey = @"MPLastUpdateCheckDate";

@implementation MPUpdateChecker

+ (instancetype)sharedChecker
{
    static MPUpdateChecker *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MPUpdateChecker alloc] init]; });
    return instance;
}

- (IBAction)checkForUpdates:(id)sender
{
    [self checkForUpdatesUserInitiated:YES];
}

- (void)checkForUpdatesUserInitiated:(BOOL)userInitiated
{
    NSURL *url = [NSURL URLWithString:kMPGitHubReleasesAPI];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/vnd.github.v3+json" forHTTPHeaderField:@"Accept"];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data)
            {
                if (userInitiated)
                    [self showErrorAlert:@"Could not reach GitHub. Check your internet connection."];
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!json || ![json isKindOfClass:[NSDictionary class]])
            {
                if (userInitiated)
                    [self showErrorAlert:@"Unexpected response from GitHub."];
                return;
            }

            NSString *latestTag = json[@"tag_name"];  // e.g. "v0.2"
            NSString *htmlURL = json[@"html_url"];
            NSString *body = json[@"body"] ?: @"";

            if (!latestTag)
            {
                if (userInitiated)
                    [self showErrorAlert:@"No releases found on GitHub."];
                return;
            }

            NSString *currentVersion = [self currentVersion];
            NSString *latestVersion = [self stripLeadingV:latestTag];

            if ([self version:latestVersion isNewerThan:currentVersion])
                [self showUpdateAvailableFrom:currentVersion to:latestVersion url:htmlURL notes:body];
            else if (userInitiated)
                [self showUpToDateAlert:currentVersion];

            // Record check time
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kMPLastUpdateCheckKey];
        });
    }];
    [task resume];
}


#pragma mark - Version comparison

- (NSString *)currentVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)stripLeadingV:(NSString *)tag
{
    if ([tag hasPrefix:@"v"] || [tag hasPrefix:@"V"])
        return [tag substringFromIndex:1];
    return tag;
}

- (BOOL)version:(NSString *)a isNewerThan:(NSString *)b
{
    // Compare using numeric version ordering (e.g. "0.2" > "0.1", "1.0.1" > "1.0")
    return [a compare:b options:NSNumericSearch] == NSOrderedDescending;
}


#pragma mark - Alerts

- (NSString *)stripMarkdown:(NSString *)text
{
    // Strip common markdown formatting for plain-text display
    NSMutableString *s = [text mutableCopy];
    // Remove heading markers
    NSRegularExpression *headings = [NSRegularExpression regularExpressionWithPattern:@"^#{1,6}\\s*" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [headings replaceMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@""];
    // Remove bold/italic markers
    NSRegularExpression *bold = [NSRegularExpression regularExpressionWithPattern:@"\\*{1,2}([^*]+)\\*{1,2}" options:0 error:nil];
    [bold replaceMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:@"$1"];
    return [s copy];
}

- (void)showUpdateAvailableFrom:(NSString *)current to:(NSString *)latest url:(NSString *)urlString notes:(NSString *)notes
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Markly %@ is available", latest];

    NSString *info = [NSString stringWithFormat:@"You're currently running version %@.", current];
    if (notes.length > 0)
        info = [info stringByAppendingFormat:@"\n\n%@", [self stripMarkdown:notes]];
    alert.informativeText = info;

    [alert addButtonWithTitle:@"Download"];
    [alert addButtonWithTitle:@"Later"];
    alert.alertStyle = NSAlertStyleInformational;

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn && urlString)
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (void)showUpToDateAlert:(NSString *)version
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"You're up to date!";
    alert.informativeText = [NSString stringWithFormat:@"Markly %@ is the latest version.", version];
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

- (void)showErrorAlert:(NSString *)message
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Update Check Failed";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"OK"];
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
}

@end
