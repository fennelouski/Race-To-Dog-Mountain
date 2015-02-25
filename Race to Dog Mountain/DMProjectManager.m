//
//  DMProjectManager.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMProjectManager.h"

@implementation DMProjectManager {
    BOOL _isPlusGame;
    BOOL _player1AI, _player2AI;
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
        _player1AI = NO;
        _player2AI = YES;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *isPlusGame = [defaults objectForKey:@"isPlusGame"];
        
        if (isPlusGame && [isPlusGame boolValue]) {
            _isPlusGame = YES;
        }
        
        NSString *player1String = [defaults objectForKey:@"player1Name"];
        NSString *player2String = [defaults objectForKey:@"player2Name"];
        
        
        self.player1Name = player1String;
        self.player2Name = player2String;
        
        NSNumber *complexity = [defaults objectForKey:@"complexity"];
        if (complexity) {
            self.complexity = [complexity intValue];
        }
        
        else {
            self.complexity = 6;
        }
        
        if (self.complexity <= 2) {
            self.complexity = 4;
        }
        
        NSNumber *player1AI = [defaults objectForKey:@"player1AI"];
        if (player1AI) {
            [self setPlayer1AI:[player1AI boolValue]];
        }
        
        NSNumber *player2AI = [defaults objectForKey:@"player2AI"];
        if (player2AI) {
            [self setPlayer2AI:[player2AI boolValue]];
        }
    }
    
    return self;
}

- (BOOL)isPlusGame {
    return _isPlusGame;
}

- (void)makeIsPlusGame:(BOOL)isPlusGame {
    _isPlusGame = isPlusGame;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:isPlusGame] forKey:@"isPlusGame"];
}

- (BOOL)player1AI {
    return _player1AI;
}

- (BOOL)player2AI {
    return _player2AI;
}

- (void)setPlayer1AI:(BOOL)player1AI {
    _player1AI = player1AI;
}

- (void)setPlayer2AI:(BOOL)player2AI {
    _player2AI = player2AI;
}

@end
