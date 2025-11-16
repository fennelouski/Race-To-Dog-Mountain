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

        // Load AI difficulty settings
        NSNumber *player1Difficulty = [defaults objectForKey:@"player1AIDifficulty"];
        if (player1Difficulty) {
            self.player1AIDifficulty = [player1Difficulty integerValue];
        } else {
            self.player1AIDifficulty = DMAIDifficultyNormal;
        }

        NSNumber *player2Difficulty = [defaults objectForKey:@"player2AIDifficulty"];
        if (player2Difficulty) {
            self.player2AIDifficulty = [player2Difficulty integerValue];
        } else {
            self.player2AIDifficulty = DMAIDifficultyNormal;
        }
    }

    return self;
}

- (BOOL)isPlusGame {
    return _isPlusGame;
}

- (void)setIsPlusGame:(BOOL)isPlusGame {
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
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:player1AI] forKey:@"player1AI"];
}

- (void)setPlayer2AI:(BOOL)player2AI {
    _player2AI = player2AI;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithBool:player2AI] forKey:@"player2AI"];
}

- (void)setPlayer1AIDifficulty:(DMAIDifficulty)player1AIDifficulty {
    _player1AIDifficulty = player1AIDifficulty;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:player1AIDifficulty] forKey:@"player1AIDifficulty"];
}

- (void)setPlayer2AIDifficulty:(DMAIDifficulty)player2AIDifficulty {
    _player2AIDifficulty = player2AIDifficulty;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSNumber numberWithInteger:player2AIDifficulty] forKey:@"player2AIDifficulty"];
}

@end
