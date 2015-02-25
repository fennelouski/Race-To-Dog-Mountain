//
//  DMProjectManager.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMProjectManager : NSObject

@property (nonatomic, strong) NSString *player1Name, *player2Name;
@property int complexity;

+ (instancetype)sharedProjectManager;
- (BOOL)isPlusGame;
- (void)setIsPlusGame:(BOOL)isPlusGame;
- (BOOL)player1AI;
- (BOOL)player2AI;
- (void)setPlayer1AI:(BOOL)player1AI;
- (void)setPlayer2AI:(BOOL)player2AI;

@end
