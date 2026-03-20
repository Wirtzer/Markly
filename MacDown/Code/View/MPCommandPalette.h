//
//  MPCommandPalette.h
//  ReadDown
//

#import <Cocoa/Cocoa.h>

@interface MPCommandItem : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *shortcut;
@property (nonatomic) SEL action;
@property (nonatomic, weak) id target;
+ (MPCommandItem *)itemWithTitle:(NSString *)title shortcut:(NSString *)shortcut action:(SEL)action target:(id)target;
@end

@interface MPCommandPalette : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

+ (void)showForWindow:(NSWindow *)parentWindow withCommands:(NSArray<MPCommandItem *> *)commands;

@end
