//
//  MPSidebarController.h
//  Markly
//

#import <Cocoa/Cocoa.h>

// Posted when the user clicks a file in the Files list. userInfo[@"url"] is
// the file's NSURL. Directories never post this.
extern NSString * const MPSidebarDidSelectFileNotification;

@interface MPSidebarController : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate>

@property (nonatomic, readonly) NSSplitView *outerSplitView;
@property (nonatomic, readonly) NSView *sidebarView;
@property (nonatomic, readonly) BOOL sidebarVisible;

- (instancetype)initWithContentView:(NSView *)contentView;
- (void)installInWindow:(NSWindow *)window aroundView:(NSView *)contentSplitView;
- (void)toggleSidebar;
- (void)showSidebar;
- (void)hideSidebar;

// File browser
@property (nonatomic, readonly) NSURL *rootURL;
- (void)setRootURL:(NSURL *)url;
// Highlight a file in the Files list, expanding folders as needed.
- (void)selectFileURL:(NSURL *)url;
// Copy visibility, width, selected tab and folder from another sidebar, so a
// window that replaces another looks the same. The folder is only copied if
// it contains `fileURL`.
- (void)adoptStateFromSidebar:(MPSidebarController *)other forFileURL:(NSURL *)fileURL;

// Document outline
- (void)updateHeadingsFromMarkdown:(NSString *)markdown;

@end


// Represents a file/folder in the file tree
@interface MPFileNode : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSArray<MPFileNode *> *children;
@property (nonatomic, readonly) BOOL isDirectory;
@end


// Represents a heading in the document outline
@interface MPHeadingNode : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic) NSInteger level; // 1-6
@property (nonatomic) NSRange range;
@property (nonatomic, strong) NSMutableArray<MPHeadingNode *> *children;
@end
