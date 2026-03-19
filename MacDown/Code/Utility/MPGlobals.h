//
//  MPGlobals.h
//  MacDown
//
//  Created by Tzu-ping Chung on 02/12.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "version.h"

// These should match the main bundle's values.
static NSString * const kMPApplicationName = @"ReadDown";

#ifdef DEBUG
static NSString * const kMPApplicationBundleIdentifier = @"com.readdown.app-debug";
#else
static NSString * const kMPApplicationBundleIdentifier = @"com.readdown.app";
#endif

static NSString * const kMPApplicationSuiteName = @"com.readdown.app";

static NSString * const MPCommandInstallationPath = @"/usr/local/bin/readdown";
static NSString * const kMPCommandName = @"readdown";

static NSString * const kMPHelpKey = @"help";
static NSString * const kMPVersionKey = @"version";

static NSString * const kMPFilesToOpenKey = @"filesToOpenOnNextLaunch";
static NSString * const kMPPipedContentFileToOpen = @"pipedContentFileToOpenOnNextLaunch";
