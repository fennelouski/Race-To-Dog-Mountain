//
//  NSString+AppFunctions.m
//  Color Viewer
//
//  Created by Developer Nathan on 1/22/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "NSString+AppFunctions.h"

@implementation NSString (AppFunctions)

- (NSString *)portmonteau {
    NSArray *words = [self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // if there's only one word then there's nothing that can be done with it
    if (words.count < 2) {
        return self;
    }
    
    // randomly selects if the overlap should be 2 characters or three
    NSInteger possibleOverlap = (arc4random() % 5 == 2) ? 3 : 2;
    
    // the snippet is the part of the first word to find in the second
    NSString *snippet = @"";
    NSMutableString *finalWord = [[NSMutableString alloc] init];
    
    // iterate through each word in the string up until the second to last word so there's one to compare with
    for (int i = 0; i + 1 < words.count; i++) {
        NSString *firstWord = [words objectAtIndex:i];
        NSString *secondWord = [[words objectAtIndex:i + 1] lowercaseString];
        BOOL isPortmonteau = NO;
        
        // start half way through the first word so it's still recognizable
        for (int startingCharacter = firstWord.length/2.0f; firstWord.length > possibleOverlap + 1 && startingCharacter < firstWord.length - possibleOverlap; startingCharacter++) {
            
            snippet = [firstWord substringWithRange:NSMakeRange(startingCharacter, possibleOverlap)];
            
            if ([secondWord rangeOfString:snippet].location != NSNotFound && [secondWord rangeOfString:snippet].location < [secondWord length]*2.0f/3.0f) {
                isPortmonteau = YES;
                
                [finalWord appendFormat:@"%@%@", [firstWord substringToIndex:startingCharacter], [secondWord substringFromIndex:[secondWord rangeOfString:snippet].location]];
                
//                NSLog(@"Found one! %@ -> %@", self, finalWord);
                
                break;
            }
        }
        
        if (!isPortmonteau) {
            [finalWord appendFormat:@"%@ ", firstWord];
        }
        
        else {
            for (int j = i + 2; j < words.count; j++) {
                [finalWord appendFormat:@" %@", [words objectAtIndex:j]];
            }
            
            NSLog(@"Portmonteau Word: %@", finalWord);
            
            return finalWord;
        }
    }
    
    [finalWord appendString:[words lastObject]];
    
    return finalWord;
}

+ (NSString *)portmonteau:(NSString *)input {
    return [input portmonteau];
}

@end
