//
//  DMProjectManager.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMProjectManager.h"

@implementation DMProjectManager {
    
}

+ (instancetype)sharedProjectManager {
    static DMProjectManager *sharedProjectManager;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedProjectManager = [[DMProjectManager alloc] init];
    });
    
    return sharedProjectManager;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        
    }
    
    return self;
}

@end
