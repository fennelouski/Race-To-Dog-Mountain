//
//  DMGameViewController.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DMSquare.h"
#import "DMScoreLabel.h"
#import <GameKit/GameKit.h>

@interface DMGameViewController : UIViewController <DMSquareDelegate, DMScoreLabelDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) NSMutableArray *grid, *player1Colors, *player2Colors;
@property (nonatomic, strong) UIView *gridView;
@property (nonatomic, strong) UIView *selectedView;
@property (nonatomic, strong) UIColor *player1Color, *player2Color;
@property int currentRow, currentColumn;
@property int lastRow, lastColumn;
@property int playerTurn;
@property int player1Score, player2Score;
@property (nonatomic, strong) NSString *player1Name, *player2Name;
@property (nonatomic, strong) DMScoreLabel *player1ScoreLabel, *player2ScoreLabel;
@property BOOL player1AI, player2AI, storedWin;
@property int numberOfRows;

@property (nonatomic, strong) UIToolbar *headerToolbar;

// game over label
@property (nonatomic, strong) UIToolbar *popOver;
@property (nonatomic, strong) UILabel *popOverGameOverLabel;
@property (nonatomic, strong) UIButton *popOverBackButton;
@property (nonatomic, strong) UILabel *userNameLabel, *finalScoreLabel;
@property (nonatomic, strong) NSArray *colors;
@property BOOL isGameOver;


@end
