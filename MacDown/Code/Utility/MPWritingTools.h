//
//  MPWritingTools.h
//  ReadDown
//

#import <Foundation/Foundation.h>

// WikiLink processing
@interface MPWikiLinkProcessor : NSObject
+ (NSString *)processWikiLinksInMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL;
@end

// Filler word highlighting in HTML
@interface MPFillerHighlighter : NSObject
+ (NSString *)highlightFillersInHTML:(NSString *)html;
@end

// Prose quality analysis
@interface MPProseAnalysis : NSObject
@property (nonatomic, strong) NSArray<NSValue *> *fillerWordRanges;
@property (nonatomic, strong) NSArray<NSValue *> *repeatedWordRanges;
@property (nonatomic, strong) NSArray<NSString *> *fillerWordsFound;
@property (nonatomic, strong) NSArray<NSString *> *repeatedWordsFound;
+ (MPProseAnalysis *)analyzeText:(NSString *)text;
@end
