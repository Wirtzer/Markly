//
//  MPSidebarControllerTests.m
//  Markly
//
//  Regression tests for the sidebar (Files / Outline), run against real
//  document windows. See MPClickRow for how clicks are simulated.
//

#import <XCTest/XCTest.h>
#import "MPSidebarController.h"
#import "MPDocument.h"


// Private parts of the classes under test.
@interface MPSidebarController (Testing)
@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSOutlineView *fileOutlineView;
@property (nonatomic, strong) NSOutlineView *headingOutlineView;
@end

@interface MPDocument (Testing)
@property (strong) MPSidebarController *sidebarController;
@end


#pragma mark - Helpers

static BOOL MPSpinUntil(NSTimeInterval timeout, BOOL (^condition)(void))
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition() && deadline.timeIntervalSinceNow > 0)
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
    return condition();
}

static void MPSpin(NSTimeInterval seconds)
{
    MPSpinUntil(seconds, ^BOOL{ return NO; });
}

// Synthesized NSEvents cannot drive AppKit controls in the test host: the
// app runs in the background, and even a plain NSButton ignores injected
// mouse events there (no Accessibility / UI Automation access). So a "click"
// here does the two things a real click does, minus AppKit's own event
// tracking:
//   1. hit-tests the point against the whole window, so the test fails if
//      anything covers the target, and
//   2. performs what NSTableView does on mouse-up: select the row, then send
//      the view's action (or doubleAction on the second click) to its target.

static BOOL MPPointIsReachable(NSView *view, NSPoint pointInView)
{
    NSPoint p = [view convertPoint:pointInView toView:nil];
    NSView *hit = [view.window.contentView.superview hitTest:p];
    if (hit && (hit == view || [hit isDescendantOf:view]))
        return YES;
    NSLog(@"point %@ in window hits %@, not %@", NSStringFromPoint(p), hit, view);
    return NO;
}

static BOOL MPClickRow(NSOutlineView *outline, NSInteger row, NSInteger clickCount)
{
    if (row < 0)
        return NO;
    [outline scrollRowToVisible:row];
    NSRect r = [outline rectOfRow:row];
    if (!MPPointIsReachable(outline, NSMakePoint(NSMidX(r), NSMidY(r))))
        return NO;
    for (NSInteger i = 1; i <= clickCount; i++)
    {
        [outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
             byExtendingSelection:NO];
        SEL action = (i >= 2 && outline.doubleAction) ? outline.doubleAction
                                                      : outline.action;
        if (action)
            [NSApp sendAction:action to:outline.target from:outline];
    }
    return YES;
}

static NSInteger MPRowNamed(NSOutlineView *outline, NSString *name)
{
    for (NSInteger row = 0; row < outline.numberOfRows; row++)
    {
        id item = [outline itemAtRow:row];
        NSString *label = [item respondsToSelector:@selector(name)]
            ? [item name] : [item title];
        if ([label isEqualToString:name])
            return row;
    }
    return -1;
}

// Click a tab ("Files" / "Outline"): find a point AppKit itself reports as
// belonging to that tab, check nothing covers it, and select it.
static BOOL MPClickTab(NSTabView *tabView, NSString *label)
{
    NSRect b = tabView.bounds;
    for (CGFloat y = 0; y < 40 && y < NSHeight(b); y += 2)
    {
        for (CGFloat x = NSMinX(b); x < NSMaxX(b); x += 2)
        {
            NSPoint pt = NSMakePoint(x, tabView.isFlipped ? NSMinY(b) + y
                                                          : NSMaxY(b) - y);
            NSTabViewItem *item = [tabView tabViewItemAtPoint:pt];
            if (![item.label isEqualToString:label])
                continue;
            if (!MPPointIsReachable(tabView, pt))
                return NO;
            [tabView selectTabViewItem:item];
            return YES;
        }
    }
    return NO;
}

static NSString *MPCanonicalPath(NSURL *url)
{
    return url.URLByResolvingSymlinksInPath.path;
}


#pragma mark - Tests

@interface MPSidebarControllerTests : XCTestCase
@property (nonatomic, strong) NSURL *folder;
@property (nonatomic, strong) NSMutableArray<NSDocument *> *openedDocuments;
@end


@implementation MPSidebarControllerTests

- (void)setUp
{
    [super setUp];
    [NSApp activateIgnoringOtherApps:YES];

    NSString *name = [NSString stringWithFormat:@"MarklySidebarTests-%@",
                      [NSUUID UUID].UUIDString];
    self.folder = [[NSURL fileURLWithPath:NSTemporaryDirectory()]
                   URLByAppendingPathComponent:name isDirectory:YES];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtURL:[self.folder URLByAppendingPathComponent:@"sub"]
 withIntermediateDirectories:YES attributes:nil error:NULL];

    NSDictionary *files = @{
        @"alpha.md": @"# Alpha doc\n\n## Section A\n\nalpha body\n\n## Section B\n\nmore\n",
        @"beta.md": @"# Beta doc\n\nbeta body\n",
        @"gamma.md": @"# Gamma doc\n\ngamma body\n",
        @"sub/nested.md": @"# Nested doc\n",
    };
    for (NSString *rel in files)
    {
        [files[rel] writeToURL:[self.folder URLByAppendingPathComponent:rel]
                    atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    self.openedDocuments = [NSMutableArray array];
}

- (void)tearDown
{
    // Close anything the tests opened, including documents opened by a
    // sidebar click (they live in the folder we created).
    NSString *root = MPCanonicalPath(self.folder);
    for (NSDocument *doc in [NSDocumentController sharedDocumentController].documents.copy)
    {
        if ([MPCanonicalPath(doc.fileURL) hasPrefix:root])
        {
            [doc updateChangeCount:NSChangeCleared];
            [doc close];
        }
    }
    MPSpin(0.2);
    [[NSFileManager defaultManager] removeItemAtURL:self.folder error:NULL];
    [super tearDown];
}

- (MPDocument *)openDocumentNamed:(NSString *)name
{
    NSURL *url = [self.folder URLByAppendingPathComponent:name];
    __block NSDocument *opened = nil;
    __block BOOL done = NO;
    [[NSDocumentController sharedDocumentController]
        openDocumentWithContentsOfURL:url display:YES
                    completionHandler:^(NSDocument *doc, BOOL wasOpen, NSError *err) {
        opened = doc;
        done = YES;
    }];
    XCTAssertTrue(MPSpinUntil(10, ^BOOL{ return done; }), @"document never opened");
    XCTAssertTrue([opened isKindOfClass:[MPDocument class]]);
    MPDocument *doc = (MPDocument *)opened;

    // Editor/preview setup is queued on the main queue after the nib loads.
    MPSpin(0.5);

    NSWindow *window = doc.windowControllers.firstObject.window;
    [window setFrame:NSMakeRect(100, 100, 1000, 700) display:YES];
    [window makeKeyAndOrderFront:nil];
    [doc.sidebarController showSidebar];
    [window layoutIfNeeded];
    [window displayIfNeeded];
    MPSpin(0.2);
    return doc;
}

- (NSArray<NSDocument *> *)documentsNamed:(NSString *)name
{
    NSString *path = MPCanonicalPath([self.folder URLByAppendingPathComponent:name]);
    NSMutableArray *found = [NSMutableArray array];
    for (NSDocument *doc in [NSDocumentController sharedDocumentController].documents)
    {
        if ([MPCanonicalPath(doc.fileURL) isEqualToString:path])
            [found addObject:doc];
    }
    return found;
}

#pragma mark Harness sanity

- (void)testSidebarShowsFolderContents
{
    MPDocument *doc = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = doc.sidebarController.fileOutlineView;
    XCTAssertTrue(doc.sidebarController.sidebarVisible);
    XCTAssertGreaterThanOrEqual(MPRowNamed(files, @"alpha.md"), 0);
    XCTAssertGreaterThanOrEqual(MPRowNamed(files, @"beta.md"), 0);
    XCTAssertGreaterThanOrEqual(MPRowNamed(files, @"sub"), 0);
    XCTAssertGreaterThanOrEqual(MPRowNamed(files, @"nested.md"), 0,
                                @"top-level folders start expanded");
}

#pragma mark Files list: clicking switches documents (the reported bug)

- (void)testSingleClickOnFileSwitchesToThatFileInPlace
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSWindow *alphaWindow = alpha.windowControllers.firstObject.window;
    NSRect alphaFrame = alphaWindow.frame;
    CGFloat sidebarWidth = alpha.sidebarController.sidebarView.frame.size.width;
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"beta.md"), 1));

    XCTAssertTrue(MPSpinUntil(5, ^BOOL{
        return [self documentsNamed:@"beta.md"].count == 1;
    }), @"a single click on beta.md should open it");

    MPDocument *beta = (MPDocument *)[self documentsNamed:@"beta.md"].firstObject;
    NSWindow *betaWindow = beta.windowControllers.firstObject.window;
    XCTAssertTrue(betaWindow.isVisible);
    XCTAssertTrue(NSEqualRects(betaWindow.frame, alphaFrame),
                  @"the new file should take the old window's place, got %@ vs %@",
                  NSStringFromRect(betaWindow.frame), NSStringFromRect(alphaFrame));

    // Sidebar carries over: still visible, same width, same folder, and the
    // file we switched to is highlighted.
    MPSidebarController *sidebar = beta.sidebarController;
    XCTAssertTrue(sidebar.sidebarVisible);
    XCTAssertEqualWithAccuracy(sidebar.sidebarView.frame.size.width, sidebarWidth, 1.0);
    XCTAssertEqualObjects([sidebar.tabView.selectedTabViewItem identifier], @"files");
    NSOutlineView *betaFiles = sidebar.fileOutlineView;
    XCTAssertEqual(betaFiles.selectedRow, MPRowNamed(betaFiles, @"beta.md"));

    // The unedited document we switched away from is closed.
    XCTAssertTrue(MPSpinUntil(5, ^BOOL{
        return [self documentsNamed:@"alpha.md"].count == 0;
    }), @"switching away from an unedited file should close it");
}

- (void)testDoubleClickOnFileOpensItOnce
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"gamma.md"), 2));
    MPSpin(1.0);

    XCTAssertEqual([self documentsNamed:@"gamma.md"].count, 1u);
    NSUInteger windows = 0;
    for (NSDocument *doc in [self documentsNamed:@"gamma.md"])
        windows += doc.windowControllers.count;
    XCTAssertEqual(windows, 1u, @"double-click must not open duplicate windows");
}

- (void)testSwitchingKeepsEditedDocumentOpen
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    [alpha updateChangeCount:NSChangeDone];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"beta.md"), 1));
    XCTAssertTrue(MPSpinUntil(5, ^BOOL{
        return [self documentsNamed:@"beta.md"].count == 1;
    }));
    MPSpin(0.5);

    XCTAssertEqual([self documentsNamed:@"alpha.md"].count, 1u,
                   @"a document with unsaved changes must never be closed by a sidebar click");
    XCTAssertTrue(alpha.isDocumentEdited);
}

- (void)testClickingNestedFileKeepsTheSameFolderInSidebar
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"nested.md"), 1));
    XCTAssertTrue(MPSpinUntil(5, ^BOOL{
        return [self documentsNamed:@"sub/nested.md"].count == 1;
    }));

    MPDocument *nested = (MPDocument *)[self documentsNamed:@"sub/nested.md"].firstObject;
    NSOutlineView *nestedFiles = nested.sidebarController.fileOutlineView;
    XCTAssertGreaterThanOrEqual(MPRowNamed(nestedFiles, @"alpha.md"), 0,
                                @"tree should stay rooted at the folder the user was browsing");
    XCTAssertEqual(nestedFiles.selectedRow, MPRowNamed(nestedFiles, @"nested.md"));
}

- (void)testClickingFolderDoesNotOpenAnything
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;
    NSUInteger before = [NSDocumentController sharedDocumentController].documents.count;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"sub"), 1));
    MPSpin(0.5);

    XCTAssertEqual([NSDocumentController sharedDocumentController].documents.count, before);
    XCTAssertEqual([self documentsNamed:@"alpha.md"].count, 1u);
}

- (void)testClickingCurrentFileIsANoOp
{
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"alpha.md"), 1));
    MPSpin(0.5);

    NSArray *docs = [self documentsNamed:@"alpha.md"];
    XCTAssertEqual(docs.count, 1u);
    XCTAssertEqual(docs.firstObject, alpha, @"the current document must stay open");
}

- (void)testClickingAlreadyOpenFileFocusesItWithoutDuplicating
{
    MPDocument *beta = [self openDocumentNamed:@"beta.md"];
    MPDocument *alpha = [self openDocumentNamed:@"alpha.md"];
    NSOutlineView *files = alpha.sidebarController.fileOutlineView;

    XCTAssertTrue(MPClickRow(files, MPRowNamed(files, @"beta.md"), 1));
    MPSpin(0.5);

    NSArray *betas = [self documentsNamed:@"beta.md"];
    XCTAssertEqual(betas.count, 1u);
    XCTAssertEqual(betas.firstObject, beta);
    XCTAssertEqual(beta.windowControllers.count, 1u);
}

#pragma mark Tabs and outline (regressions)

- (void)testTabsSwitchBothWays
{
    MPDocument *doc = [self openDocumentNamed:@"alpha.md"];
    NSTabView *tabs = doc.sidebarController.tabView;
    XCTAssertEqualObjects([tabs.selectedTabViewItem identifier], @"files");

    XCTAssertTrue(MPClickTab(tabs, @"Outline"), @"Outline tab not found");
    MPSpin(0.2);
    XCTAssertEqualObjects([tabs.selectedTabViewItem identifier], @"outline");

    XCTAssertTrue(MPClickTab(tabs, @"Files"), @"Files tab not found");
    MPSpin(0.2);
    XCTAssertEqualObjects([tabs.selectedTabViewItem identifier], @"files");
}

- (void)testSingleClickOnHeadingStillNavigates
{
    MPDocument *doc = [self openDocumentNamed:@"alpha.md"];
    MPSidebarController *sidebar = doc.sidebarController;
    [sidebar.tabView selectTabViewItemWithIdentifier:@"outline"];
    [doc.windowControllers.firstObject.window layoutIfNeeded];
    MPSpin(0.2);

    __block NSString *title = nil;
    id token = [[NSNotificationCenter defaultCenter]
        addObserverForName:@"MPSidebarDidSelectHeading" object:sidebar queue:nil
                usingBlock:^(NSNotification *note) { title = note.userInfo[@"title"]; }];

    NSOutlineView *headings = sidebar.headingOutlineView;
    XCTAssertTrue(MPClickRow(headings, MPRowNamed(headings, @"Section B"), 1));
    MPSpin(0.2);
    [[NSNotificationCenter defaultCenter] removeObserver:token];

    XCTAssertEqualObjects(title, @"Section B");
    XCTAssertEqual([self documentsNamed:@"alpha.md"].count, 1u);
}

@end
