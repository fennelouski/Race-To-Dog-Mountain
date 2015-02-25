//
//  DMPlusGameViewController.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 2/23/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DMSquare.h"
#import "DMScoreLabel.h"

@interface DMPlusGameViewController : UIViewController <DMScoreLabelDelegate, DMSquareDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) NSMutableArray *grid, *player1Colors, *player2Colors;
@property (nonatomic, strong) NSMutableSet *playedSquares;
@property (nonatomic, strong) UIView *gridView;
@property (nonatomic, strong) UIColor *player1Color, *player2Color, *whiteColor;
@property (nonatomic, strong) NSString *player1Name, *player2Name;
@property (nonatomic, strong) UIToolbar *headerToolbar;
@property (nonatomic, strong) DMScoreLabel *player1ScoreLabel, *player2ScoreLabel;
@property int playerTurn;
@property int player1Score, player2Score;
@property BOOL player1AI, player2AI, storedWin, nightMode;
@property int numberOfRows;

// game over label
@property (nonatomic, strong) UIToolbar *popOver;
@property (nonatomic, strong) UILabel *popOverGameOverLabel;
@property (nonatomic, strong) UIButton *popOverBackButton;
@property (nonatomic, strong) UILabel *userNameLabel, *finalScoreLabel;
@property (nonatomic, strong) NSArray *colors;
@property BOOL isGameOver, finalColorsLightened;
@property float finalAnimationTime;


@end
