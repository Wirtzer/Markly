//
//  MPWritingTools.m
//  ReadDown
//

#import "MPWritingTools.h"


#pragma mark - WikiLink Processor

@implementation MPWikiLinkProcessor

+ (NSString *)processWikiLinksInMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL
{
    if (!markdown.length)
        return markdown;

    // Match [[link]] and [[link|display text]] patterns
    static NSRegularExpression *wikiLinkRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wikiLinkRegex = [NSRegularExpression regularExpressionWithPattern:
            @"\\[\\[([^\\]|]+?)(?:\\|([^\\]]+?))?\\]\\]"
            options:0 error:nil];
    });

    NSMutableString *result = [markdown mutableCopy];
    NSArray *matches = [wikiLinkRegex matchesInString:markdown options:0
                                                range:NSMakeRange(0, markdown.length)];

    // Process in reverse to preserve ranges
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator])
    {
        NSString *target = [markdown substringWithRange:[match rangeAtIndex:1]];
        NSString *display = nil;
        if ([match rangeAtIndex:2].location != NSNotFound)
            display = [markdown substringWithRange:[match rangeAtIndex:2]];
        else
            display = target;

        // Convert target to a filename: "My Note" -> "My Note.md"
        NSString *filename = target;
        if (![filename.pathExtension isEqualToString:@"md"] &&
            ![filename.pathExtension isEqualToString:@"markdown"])
            filename = [filename stringByAppendingPathExtension:@"md"];

        NSString *link;
        if (baseURL)
        {
            NSURL *targetURL = [baseURL URLByAppendingPathComponent:filename];
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:targetURL.path];
            NSString *cssClass = exists ? @"wikilink" : @"wikilink wikilink-new";
            link = [NSString stringWithFormat:@"<a href=\"%@\" class=\"%@\">%@</a>",
                    filename, cssClass, display];
        }
        else
        {
            link = [NSString stringWithFormat:@"<a href=\"%@\" class=\"wikilink\">%@</a>",
                    filename, display];
        }

        [result replaceCharactersInRange:match.range withString:link];
    }

    return result;
}

@end


#pragma mark - Prose Analysis

static NSSet *MPFillerWords()
{
    static NSSet *words = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        words = [NSSet setWithArray:@[
            @"actually", @"basically", @"certainly", @"clearly", @"definitely",
            @"effectively", @"essentially", @"extremely", @"fairly", @"frankly",
            @"generally", @"honestly", @"hopefully", @"importantly", @"incredibly",
            @"indeed", @"interestingly", @"ironically", @"just", @"largely",
            @"literally", @"mainly", @"merely", @"mostly", @"naturally",
            @"necessarily", @"notably", @"obviously", @"of course", @"overall",
            @"particularly", @"perhaps", @"personally", @"practically",
            @"presumably", @"pretty", @"primarily", @"probably", @"quite",
            @"rather", @"really", @"relatively", @"seemingly", @"seriously",
            @"significantly", @"simply", @"slightly", @"somewhat", @"sort of",
            @"specifically", @"strongly", @"stuff", @"surely", @"technically",
            @"that said", @"thing", @"things", @"totally", @"truly",
            @"typically", @"ultimately", @"undoubtedly", @"unfortunately",
            @"unnecessarily", @"usually", @"utterly", @"very", @"virtually",
        ]];
    });
    return words;
}

@implementation MPProseAnalysis

+ (MPProseAnalysis *)analyzeText:(NSString *)text
{
    MPProseAnalysis *analysis = [[MPProseAnalysis alloc] init];
    NSMutableArray<NSValue *> *fillerRanges = [NSMutableArray array];
    NSMutableArray<NSString *> *fillerWords = [NSMutableArray array];
    NSMutableArray<NSValue *> *repeatedRanges = [NSMutableArray array];
    NSMutableArray<NSString *> *repeatedWords = [NSMutableArray array];

    if (!text.length)
    {
        analysis.fillerWordRanges = fillerRanges;
        analysis.fillerWordsFound = fillerWords;
        analysis.repeatedWordRanges = repeatedRanges;
        analysis.repeatedWordsFound = repeatedWords;
        return analysis;
    }

    NSSet *fillers = MPFillerWords();

    // Use regex to find word boundaries — simple and reliable
    static NSRegularExpression *wordRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wordRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b[a-zA-Z]+\\b"
                                                              options:0 error:nil];
    });

    NSArray *matches = [wordRegex matchesInString:text options:0
                                            range:NSMakeRange(0, text.length)];

    NSString *prevWord = nil;
    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = match.range;
        NSString *word = [[text substringWithRange:range] lowercaseString];

        // Check filler words
        if ([fillers containsObject:word])
        {
            [fillerRanges addObject:[NSValue valueWithRange:range]];
            if (![fillerWords containsObject:word])
                [fillerWords addObject:word];
        }

        // Check repeated consecutive words
        if (prevWord && [prevWord isEqualToString:word])
        {
            [repeatedRanges addObject:[NSValue valueWithRange:range]];
            if (![repeatedWords containsObject:word])
                [repeatedWords addObject:word];
        }

        prevWord = word;
    }

    analysis.fillerWordRanges = fillerRanges;
    analysis.fillerWordsFound = fillerWords;
    analysis.repeatedWordRanges = repeatedRanges;
    analysis.repeatedWordsFound = repeatedWords;
    return analysis;
}

@end
