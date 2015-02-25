//
//  DMPlusGameViewController.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 2/23/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMPlusGameViewController.h"
#import "UIColor+AppColors.h"
#import "DMProjectManager.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kStatusBarHeight (([[UIApplication sharedApplication] statusBarFrame].size.height == 20.0f) ? 20.0f : (([[UIApplication sharedApplication] statusBarFrame].size.height == 40.0f) ? 20.0f : 0.0f))
#define kScreenHeight (([[UIApplication sharedApplication] statusBarFrame].size.height > 20.0f) ? [UIScreen mainScreen].bounds.size.height - 20.0f : [UIScreen mainScreen].bounds.size.height)
#define BUFFER 2.0f
#define SQUARE_SIZE (((kScreenWidth < kScreenHeight) ? kScreenWidth : kScreenHeight - kStatusBarHeight) / self.numberOfRows)
#define FONT_SCALE 12.0f
#define ANIMATION_DURATION 0.35f

#define PLAYER_1_TAG 123479
#define PLAYER_2_TAG 523458
#define AI_ANIMATION_TIME ((self.player1AI && self.player2AI) ? (0.167f/(float)self.numberOfRows) : 0.4f)
#define DIM_VALUE ((self.player1AI && self.player2AI) ? 0.5f : 0.3f)
#define BRIGHT_VALUE ((self.player1AI && self.player2AI) ? 0.5f : 0.45f)

@interface DMPlusGameViewController ()

@end

@implementation DMPlusGameViewController


- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.player1Colors = [[NSMutableArray alloc] init];
        self.player2Colors = [[NSMutableArray alloc] init];
        
        [self.player1Colors addObjectsFromArray:@[[UIColor darkBlue],
                                                  [UIColor darkBrown],
                                                  [UIColor darkBrownTangelo],
                                                  [UIColor darkByzantium],
                                                  [UIColor darkCandyAppleRed],
                                                  [UIColor darkCerulean],
                                                  [UIColor darkChestnut],
                                                  [UIColor darkCoral],
                                                  [UIColor darkCyan],
                                                  [UIColor darkElectricBlue],
                                                  [UIColor darkGoldenrod],
                                                  [UIColor darkOrange],
                                                  [UIColor darkSkyBlue],
                                                  [UIColor darkSlateBlue],
                                                  [UIColor darkImperialBlue],
                                                  [UIColor darkImperialBlue2],
                                                  [UIColor darkMidnightBlue],
                                                  [UIColor frenchPuce],
                                                  [UIColor oxfordBlue],
                                                  [UIColor persianIndigo],
                                                  [UIColor royalBlue],
                                                  [UIColor sealBrown],
                                                  [UIColor spaceCadet],
                                                  [UIColor yankeesBlue],
                                                  [UIColor zinnwalditeBrown]]
         ];
        [self.player2Colors addObjectsFromArray:@[[UIColor crimsonRed],
                                                  [UIColor darkGreen],
                                                  [UIColor mediumJungleGreen],
                                                  [UIColor darkJungleGreen],
                                                  [UIColor darkLava],
                                                  [UIColor darkLavender],
                                                  [UIColor darkLiver],
                                                  [UIColor darkLiverHorses],
                                                  [UIColor darkMagenta],
                                                  [UIColor deepRed],
                                                  [UIColor darkMossGreen],
                                                  [UIColor darkOliveGreen],
                                                  [UIColor darkOrchid],
                                                  [UIColor darkPuce],
                                                  [UIColor darkPurple],
                                                  [UIColor darkRed],
                                                  [UIColor darkScarlet],
                                                  [UIColor eerieBlack],
                                                  [UIColor darkSienna],
                                                  [UIColor darkSlateGray],
                                                  [UIColor darkSpringGreen],
                                                  [UIColor charcoal],
                                                  [UIColor forestGreenTraditional],
                                                  [UIColor darkTerraCotta],
                                                  [UIColor darkViolet],
                                                  [UIColor charlestonGreen],
                                                  [UIColor dartmouthGreen]]
         ];
        
        self.finalAnimationTime = ANIMATION_DURATION;
    }
    
    return self;
}

- (void)viewDidLoad {
    self.playerTurn = arc4random()%2;
    
    if (self.player1Name.length == 0) {
        self.player1Name = @"Player 1";
    }
    
    if (self.player2Name.length == 0) {
        self.player2Name = @"Player 2";
    }
    
    [self setPlayer1Color:[UIColor randomDarkColorFromString:self.player1Name]];
    [self setPlayer2Color:[UIColor randomDarkColorFromString:self.player2Name]];
    
    [self setUpColors];
    
    if (self.numberOfRows < 4) {
        self.numberOfRows = 4;
    }
    
    else {
        self.numberOfRows = self.numberOfRows;
    }
    
    if (self.numberOfRows > 10 && kScreenWidth + kScreenHeight < 900.0f) {
        self.numberOfRows = 10;
    }
    
    self.colors = [UIColor appColors];
    
    NSLog(@"%d", self.numberOfRows);
    [self.view addSubview:self.gridView];
    [self setupGrid];
    
    [self.view addSubview:self.player1ScoreLabel];
    [self.view addSubview:self.player2ScoreLabel];
    [self.view addSubview:self.headerToolbar];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self  selector:@selector(updateViews)    name:UIDeviceOrientationDidChangeNotification  object:nil];
    [nc addObserver:self selector:@selector(updateViews) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    
    [self updateViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self performSelector:@selector(updateViews) withObject:self afterDelay:0.26f];
    [self layoutSquares];
    
    [self performAI];
    
    if (self.playerTurn == 0) {
        [self.view setBackgroundColor:self.player1Color];
    }
    
    else {
        [self.view setBackgroundColor:self.player2Color];
    }
}

- (void)updateViews {
    float animationTime = 1.5f/self.numberOfRows;
    if (animationTime > ANIMATION_DURATION) animationTime = ANIMATION_DURATION;
    [UIView animateWithDuration:animationTime animations:^{
        [_gridView setFrame:CGRectMake(0.0f,
                                       kStatusBarHeight,
                                       self.numberOfRows * SQUARE_SIZE,
                                       self.numberOfRows * SQUARE_SIZE)];
        
        [self layoutScoreLabels];
        
        [_popOver setFrame:CGRectMake(50.0f,
                                      50.0f,
                                      kScreenWidth - 100.0f,
                                      kScreenHeight - 100.0f)];
        [_popOverBackButton setFrame:CGRectMake(_popOver.frame.size.width/4,
                                                _popOver.frame.size.height*4/5,
                                                _popOver.frame.size.width/2,
                                                30.0f)];
        [_popOverGameOverLabel setFrame:CGRectMake(0.0f,
                                                   0.0f,
                                                   _popOver.frame.size.width,
                                                   _popOver.frame.size.height * 0.4f)];
        [_userNameLabel setFrame:CGRectMake(0.0f,
                                            _popOver.frame.size.height * 0.4f,
                                            _popOver.frame.size.width,
                                            kScreenHeight/20.0f)];
        int finalScoreLabelHeight = abs((_userNameLabel.frame.origin.y + _userNameLabel.frame.size.height) - _popOverBackButton.frame.origin.y);
        [_finalScoreLabel setFrame:CGRectMake(0,
                                              _userNameLabel.frame.origin.y + _userNameLabel.frame.size.height,
                                              _popOver.frame.size.width,
                                              finalScoreLabelHeight)];
        float fontSize = finalScoreLabelHeight;
        CGSize size = [self.finalScoreLabel.text sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:fontSize]}];
        // find the right font that's still readable but fits on the popover
        while (size.width > self.popOver.frame.size.width * 0.85f && fontSize > 20.0f) {
            fontSize--;
            size = [self.finalScoreLabel.text sizeWithAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        }
        
        [_finalScoreLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
        [_userNameLabel setFont:[UIFont boldSystemFontOfSize:kScreenHeight/22.0f]];
        [_popOverGameOverLabel setFont:[UIFont boldSystemFontOfSize:kScreenWidth/FONT_SCALE]];
        [_headerToolbar setFrame:CGRectMake(0.0f,
                                            0.0f,
                                            kScreenWidth,
                                            kStatusBarHeight)];
    } completion:^(BOOL finished){
        if ([self checkForEndGame]) {
            if (!self.storedWin) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                
                NSString *player1ScoreString = [NSString stringWithFormat:@"%@vvv%@", self.player1Name, self.player2Name];
                
                NSNumber *player1Wins = [defaults valueForKey:player1ScoreString];
                
                if (!player1Wins) {
                    player1Wins = [NSNumber numberWithInt:0];
                    NSLog(@"Creating score for %@", player1ScoreString);
                }
                
                if (self.player1Score > self.player2Score) {
                    player1Wins = [NSNumber numberWithInt:[player1Wins intValue] + 1];
                }
                
                [defaults setValue:player1Wins forKey:player1ScoreString];
                
                
                NSString *player2ScoreString = [NSString stringWithFormat:@"%@vvv%@", self.player2Name, self.player1Name];
                
                NSNumber *player2Wins = [defaults valueForKey:player2ScoreString];
                
                if (!player2Wins) {
                    player2Wins = [NSNumber numberWithInt:0];
                    NSLog(@"Creating score for %@", player2ScoreString);
                }
                
                if (self.player2Score > self.player1Score) {
                    player2Wins = [NSNumber numberWithInt:[player2Wins intValue] + 1];
                }
                
                [defaults setValue:player2Wins forKey:player2ScoreString];
                
                self.storedWin = YES;
                
                NSLog(@"End Game! %f %d", (float)[player1Wins intValue]/(float)[player2Wins intValue], [player1Wins intValue] + [player2Wins intValue]);
                
//                [self backButtonTouched]; // used for AI testing
            }
            
            if (self.player1Score > self.player2Score) {
                [_userNameLabel setText:self.player1Name];
            }
            
            else if (self.player1Score < self.player2Score) {
                [_userNameLabel setText:self.player2Name];
            }
            
            else {
                [_userNameLabel setText:@"Tie!"];
            }
            
            [self.finalScoreLabel setText:[NSString stringWithFormat:@"%d - %d", self.player1Score, self.player2Score]];
            
            if (!self.isGameOver) {
                [self performSelector:@selector(gameOver) withObject:self afterDelay:ANIMATION_DURATION];
            }
        }
    }];
    
    if ((self.player1ScoreLabel.fontSize > 0 && !self.player1ScoreLabel.fontSizeOverwritten) || (self.player2ScoreLabel.fontSize > 0 && !self.player2ScoreLabel.fontSizeOverwritten)) {
        float fontSize = self.player1ScoreLabel.fontSize;
        if (self.player2ScoreLabel.fontSize < fontSize) {
            fontSize = self.player2ScoreLabel.fontSize;
        }
        
        [self.player1ScoreLabel setFontSize:fontSize];
        [self.player1ScoreLabel setFontSizeOverwritten:YES];
        [self.player1ScoreLabel layoutSubviews];
        [self.player2ScoreLabel setFontSize:fontSize];
        [self.player2ScoreLabel setFontSizeOverwritten:YES];
        [self.player2ScoreLabel layoutSubviews];
    }
    
    [UIView animateWithDuration:AI_ANIMATION_TIME animations:^{
        if (self.playerTurn == 1) {
            [self.view setBackgroundColor:self.player1Color];
            [self.player1ScoreLabel setBackgroundColor:[self.player1Color makeBrightnessOf:BRIGHT_VALUE]];
            [self.player2ScoreLabel setBackgroundColor:[self.player2Color makeBrightnessOf:DIM_VALUE]];
        }
        
        else {
            [self.view setBackgroundColor:self.player2Color];
            [self.player1ScoreLabel setBackgroundColor:[self.player1Color makeBrightnessOf:DIM_VALUE]];
            [self.player2ScoreLabel setBackgroundColor:[self.player2Color makeBrightnessOf:BRIGHT_VALUE]];
        }
    }];
    
    [self layoutSquares];
}

- (void)setUpColors {
    [self setPlayer1Color:[UIColor randomDarkColorFromString:self.player1Name]];
    [self setPlayer2Color:[UIColor randomDarkColorFromString:self.player2Name]];
    
    NSLog(@"Player Names: %@\t\t%@", self.player1Name, self.player2Name);
    
    self.whiteColor = [UIColor white];
}

#pragma mark - Subviews

- (UIView *)gridView {
    if (!_gridView) {
        _gridView = [[UIView alloc] initWithFrame:CGRectMake(0.0f,
                                                             kStatusBarHeight,
                                                             self.numberOfRows * SQUARE_SIZE,
                                                             self.numberOfRows * SQUARE_SIZE)];
        [_gridView setClipsToBounds:NO];
    }
    
    return _gridView;
}

- (DMScoreLabel *)player1ScoreLabel {
    if (!_player1ScoreLabel) {
        _player1ScoreLabel = [[DMScoreLabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                            self.gridView.frame.size.height + kStatusBarHeight,
                                                                            kScreenWidth/2.0f,
                                                                            kScreenHeight - (self.gridView.frame.size.height + kStatusBarHeight))];
        [_player1ScoreLabel setName:self.player1Name];
        [_player1ScoreLabel setBackgroundColor:self.player1Color];
        [_player1ScoreLabel setDelegate:self];
        [_player1ScoreLabel setPlayer:0];
        [_player1ScoreLabel setWhiteColor:self.whiteColor];
    }
    
    return _player1ScoreLabel;
}

- (DMScoreLabel *)player2ScoreLabel {
    if (!_player2ScoreLabel) {
        _player2ScoreLabel = [[DMScoreLabel alloc] initWithFrame:CGRectMake(kScreenWidth/2.0f,
                                                                            self.gridView.frame.size.height + kStatusBarHeight,
                                                                            kScreenWidth/2.0f,
                                                                            kScreenHeight - (self.gridView.frame.size.height + kStatusBarHeight))];
        [_player2ScoreLabel setName:self.player2Name];
        [_player2ScoreLabel setBackgroundColor:self.player2Color];
        [_player2ScoreLabel setDelegate:self];
        [_player2ScoreLabel setPlayer:1];
        [_player2ScoreLabel setWhiteColor:self.whiteColor];
    }
    
    return _player2ScoreLabel;
}

- (UIToolbar *)headerToolbar {
    if (!_headerToolbar) {
        _headerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f,
                                                                     0.0f,
                                                                     kScreenWidth,
                                                                     kStatusBarHeight)];
        [_headerToolbar setAlpha:0.0f];
    }
    
    return _headerToolbar;
}

#pragma mark - End Game Pop Over

- (UIToolbar *)popOver {
    if (!_popOver) {
        _popOver = [[UIToolbar alloc] initWithFrame:CGRectMake(BUFFER,
                                                               BUFFER,
                                                               kScreenWidth - BUFFER*2,
                                                               kScreenHeight - BUFFER*2)];
        [_popOver setBarStyle:UIBarStyleBlackTranslucent];
        [_popOver.layer setCornerRadius:5.0f];
        
        
        [_popOver addSubview:self.popOverGameOverLabel];
        [_popOver addSubview:self.popOverBackButton];
        [_popOver addSubview:self.userNameLabel];
        [_popOver addSubview:self.finalScoreLabel];
    }
    
    return _popOver;
}

- (UILabel *)popOverGameOverLabel {
    if (!_popOverGameOverLabel) {
        _popOverGameOverLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                          _popOver.frame.size.height/5,
                                                                          _popOver.frame.size.width,
                                                                          kScreenWidth/FONT_SCALE)];
        [_popOverGameOverLabel setText:@"Game Over"];
        [_popOverGameOverLabel setTextAlignment:NSTextAlignmentCenter];
        [_popOverGameOverLabel setTextColor:[UIColor colorWithRed:0.98f green:0.99f blue:1.0f alpha:1.0f]];
        [_popOverGameOverLabel setFont:[UIFont boldSystemFontOfSize:kScreenWidth/FONT_SCALE]];
    }
    
    return _popOverGameOverLabel;
}

- (UIButton *)popOverBackButton {
    if (!_popOverBackButton) {
        _popOverBackButton = [[UIButton alloc] initWithFrame:CGRectMake(_popOver.frame.size.width/4.0f,
                                                                        _popOver.frame.size.height*0.8f,
                                                                        _popOver.frame.size.width/2.0f,
                                                                        30.0f)];
        [_popOverBackButton setTitle:@"Back" forState:UIControlStateNormal];
        [_popOverBackButton setTitleColor:[UIColor colorWithRed:0.98f green:0.99f blue:1.0f alpha:1.0f] forState:UIControlStateNormal];
        [_popOverBackButton addTarget:self action:@selector(backButtonTouched) forControlEvents:UIControlEventTouchUpInside];
        float fontSize = (kScreenWidth + kScreenHeight)/40.0f;
        if (fontSize > 40.0f) {
            fontSize = 40.0f;
        }
        [_popOverBackButton.titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
    }
    
    return _popOverBackButton;
}

- (UILabel *)userNameLabel {
    if (!_userNameLabel) {
        _userNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                   _popOver.frame.size.height * 0.4f,
                                                                   _popOver.frame.size.width,
                                                                   20.0f)];
        [_userNameLabel setFont:[UIFont systemFontOfSize:20.0f]];
        [_userNameLabel setTextAlignment:NSTextAlignmentCenter];
        [_userNameLabel setTextColor:[UIColor lightGray]];
    }
    
    return _userNameLabel;
}

- (UILabel *)finalScoreLabel {
    if (!_finalScoreLabel) {
        _finalScoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                     _userNameLabel.frame.origin.y + _userNameLabel.frame.size.height + 20.0f,
                                                                     _popOver.frame.size.width,
                                                                     (kScreenHeight + kScreenWidth)/10.0f)];
        [_finalScoreLabel setFont:[UIFont boldSystemFontOfSize:50.0f]];
        [_finalScoreLabel setTextAlignment:NSTextAlignmentCenter];
        [_finalScoreLabel setTextColor:[UIColor colorWithRed:0.98f green:0.99f blue:1.0f alpha:1.0f]];
    }
    
    return _finalScoreLabel;
}

- (void)backButtonTouched {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)animateFinalScore {
    if (self.popOver.superview && self.popOver.alpha > 0.0f) {
        if (!self.finalColorsLightened) {
            NSMutableArray *darkColors = [[NSMutableArray alloc] init];
            NSMutableArray *tempColors = [[NSMutableArray alloc] init];
            
            if (self.player1Score > self.player2Score) {
                [darkColors addObjectsFromArray:self.player1Colors];
            }
            
            else if (self.player1Score < self.player2Score) {
                [darkColors addObjectsFromArray:self.player2Colors];
            }
            
            else {
                [darkColors addObjectsFromArray:self.player1Colors];
                [darkColors addObjectsFromArray:self.player2Colors];
            }
            
            for (UIColor *darkColor in darkColors) {
                [tempColors addObject:[darkColor lightenColorBy:0.5f]];
            }
            
            self.colors = tempColors;
            
            self.finalColorsLightened = YES;
        }
        
        if (self.colors.count > 0) {
            int randomIndex = arc4random() % self.colors.count;
            
            if (self.colors.count > 0 && self.colors.count > randomIndex) {
                [self changeLabelColor:self.finalScoreLabel toColor:[self.colors objectAtIndex:randomIndex] startingColor:self.finalScoreLabel.textColor step:0 colors:nil];
            }
            
            [self performSelector:@selector(animateFinalScore) withObject:self afterDelay:self.finalAnimationTime + 0.1f];
        }
    }
}

- (void)changeLabelColor:(UILabel *)label toColor:(UIColor *)finalColor startingColor:(UIColor *)startingColor step:(int)step colors:(NSArray *)colors {
    int numberOfSteps = 50;
    if (self.finalAnimationTime * 30.0f > numberOfSteps) numberOfSteps = self.finalAnimationTime * 30.0f;
    
    if (!colors || [colors count] + 1 < numberOfSteps) {
        NSMutableArray *tempColors = [[NSMutableArray alloc] initWithCapacity:numberOfSteps];
        
        float startingRedValue = [[startingColor valueForKey:@"redComponent"] floatValue];
        float startingGreenValue = [[startingColor valueForKey:@"greenComponent"] floatValue];
        float startingBlueValue = [[startingColor valueForKey:@"blueComponent"] floatValue];
        float finalRedValue = [[finalColor valueForKey:@"redComponent"] floatValue];
        float finalGreenValue = [[finalColor valueForKey:@"greenComponent"] floatValue];
        float finalBlueValue = [[finalColor valueForKey:@"blueComponent"] floatValue];
        
        for (int i = 0; i < numberOfSteps; i++) {
            float finalTrueRedValue = (startingRedValue * (numberOfSteps - i) + finalRedValue * i) / numberOfSteps;
            float finalTrueGreenValue = (startingGreenValue * (numberOfSteps - i) + finalGreenValue * i) / numberOfSteps;
            float finalTrueBlueValue = (startingBlueValue * (numberOfSteps - i) + finalBlueValue * i) / numberOfSteps;
            
            [tempColors addObject:[UIColor colorWithRed:finalTrueRedValue green:finalTrueGreenValue blue:finalTrueBlueValue alpha:1.0f]];
        }
        
        colors = tempColors;
    }
    
    if (step >= numberOfSteps || step > [colors count]) {
        [label setTextColor:finalColor];
        self.finalAnimationTime += 0.01f;
        return;
    }
    
    if (step < [colors count]) {
        [label setTextColor:[colors objectAtIndex:step]];
    }
    
    else {
        NSLog(@"\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nError with colors\n\n\n\n\n- (void)changeLabelColor:(UILabel *)label toColor:(UIColor *)finalColor startingColor:(UIColor *)startingColor step:(int)step colors:(NSArray *)colors {\n\n\n\n\nI'm on step #%d and there are only %d colors in the array\n\n\n\n\n\n\n\n\n\n\n\n", step, (int)[colors count]);
    }
    
    NSMutableDictionary *arguments = [[NSMutableDictionary alloc] init];
    [arguments setObject:label forKey:@"label"];
    [arguments setObject:finalColor forKey:@"finalColor"];
    [arguments setObject:startingColor forKey:@"startingColor"];
    [arguments setObject:[NSNumber numberWithInt:step + 1] forKey:@"step"];
    [arguments setObject:colors forKey:@"colors"];
    
    [self performSelector:@selector(delayedLabelAnimation:) withObject:arguments afterDelay:self.finalAnimationTime/numberOfSteps];
}

- (void)delayedLabelAnimation:(NSDictionary *)arguments {
    [self changeLabelColor:[arguments objectForKey:@"label"] toColor:[arguments objectForKey:@"finalColor"] startingColor:[arguments objectForKey:@"startingColor"] step:[[arguments objectForKey:@"step"] intValue] colors:[arguments objectForKey:@"colors"]];
}

#pragma mark - Setup

- (void)setupGrid {
    self.grid = [[NSMutableArray alloc] initWithCapacity:self.numberOfRows];
    self.playedSquares = [[NSMutableSet alloc] initWithCapacity:self.numberOfRows * self.numberOfRows];
    
    NSMutableArray *numbers = [[NSMutableArray alloc] initWithCapacity:self.numberOfRows*self.numberOfRows];
    for (int i = 1; i <= self.numberOfRows * self.numberOfRows; i++) {
        NSNumber *number = [NSNumber numberWithInt:i];
        [numbers addObject:number];
    }
    
    for (int row = 0; row < self.numberOfRows; row++) {
        NSMutableArray *rowArray = [[NSMutableArray alloc] initWithCapacity:self.numberOfRows];
        for (int column = 0; column < self.numberOfRows && numbers.count > 0; column++) {
            NSNumber *randomNumber = [numbers objectAtIndex:arc4random()%[numbers count]];
            [numbers removeObject:randomNumber];
            
            DMSquare *square = [[DMSquare alloc] initWithFrame:CGRectMake(SQUARE_SIZE * row,
                                                                          SQUARE_SIZE * column,
                                                                          SQUARE_SIZE,
                                                                          SQUARE_SIZE)];
            [square setSquareValue:randomNumber];
            [square setDelegate:self];
            [square setRow:column];
            [square setColumn:row];
            [square setWhiteColor:self.whiteColor];
            [square setIsPlusGame:YES];
            
            if ((column + row)%2 == 0) {
                [square makeSquareSelected:YES];
                [square setBackgroundColor:self.player1Color];
            }
            
            else {
                [square makeSquareSelected:NO];
                [square setBackgroundColor:self.player2Color];
            }
            
            [square setBackgroundColor:[square.backgroundColor makeBrightnessOf:DIM_VALUE]];
            if ([square selected] != self.playerTurn == 0) {
                [square setBackgroundColor:[square.backgroundColor makeBrightnessOf:BRIGHT_VALUE]];
            }
            
            [square layoutSubviews];
            
            [rowArray addObject:square];
        }
        
        [self.grid addObject:rowArray];
    }
    
    [self layoutSquares];
    
    [self setPlayerTurn:arc4random()%2];
}

#pragma mark - Layouts and updates

- (void)layoutSquares {
    for (NSMutableArray *array in self.grid) {
        for (DMSquare *square in array) {
            [self.gridView addSubview:square];
            
            float animationDuration = (((float)(arc4random()%35) + 20.0f) / 40.0f) * AI_ANIMATION_TIME; // randomly changes the amount of time to switch the colors of the squares in the grid
            float squareValue = ((float)[[square squareValue] intValue] - self.numberOfRows*self.numberOfRows)/500.0f; // the amount of brightness to increase the high value squares
            if (self.player1AI && self.player2AI) squareValue *= 0.0f;
            [UIView animateWithDuration:animationDuration animations:^{
                if ([[square squareValue] intValue] > 0) {
                    [square setBackgroundColor:[square.backgroundColor makeBrightnessOf:BRIGHT_VALUE + squareValue]];
                    if ([square selected] != self.playerTurn == 0) {
                        [square setBackgroundColor:[square.backgroundColor makeBrightnessOf:DIM_VALUE - squareValue/4.0f]]; // dim the high value squares for the opponent
                    }
                }
            }];
            
            [square layoutSubviews];
        }
    }
}

- (void)layoutScoreLabels {
    // portrait
    if (kScreenWidth < kScreenHeight) {
        [_player1ScoreLabel setFrame:CGRectMake(0.0f,
                                                self.gridView.frame.size.height + kStatusBarHeight,
                                                kScreenWidth/2.0f,
                                                kScreenHeight - (self.gridView.frame.size.height + kStatusBarHeight))];
        [_player2ScoreLabel setFrame:CGRectMake(kScreenWidth/2.0f,
                                                self.gridView.frame.size.height + kStatusBarHeight,
                                                kScreenWidth/2.0f,
                                                kScreenHeight - (self.gridView.frame.size.height + kStatusBarHeight))];
    }
    
    // landscape
    else {
        [_player1ScoreLabel setFrame:CGRectMake(self.gridView.frame.size.width,
                                                kStatusBarHeight,
                                                kScreenWidth - self.gridView.frame.size.width,
                                                kScreenHeight/2.0f)];
        [_player2ScoreLabel setFrame:CGRectMake(self.gridView.frame.size.width,
                                                kStatusBarHeight + kScreenHeight/2.0f,
                                                kScreenWidth - self.gridView.frame.size.width,
                                                kScreenHeight/2.0f)];
    }
}

#pragma mark - Square Delegate

- (void)squareTouched:(NSObject *)squareTouched {
    DMSquare *square = (DMSquare *)squareTouched;
    
    if (!square || [square squareValue] == 0 || (self.playerTurn == 1 && square.selected) || (self.playerTurn == 0 && !square.selected)) {
        NSLog(@"Wrong player turn");
        [square printSquareDetails];
        return;
    }
    
    if ([self.playedSquares containsObject:square]) {
        NSLog(@"Square has already been played!");
        return;
    }
    
    else {
        [self.playedSquares addObject:square];
    }
    
    NSMutableArray *squaresToFlip = [NSMutableArray arrayWithObject:square];
    
    [squaresToFlip addObjectsFromArray:[self neighboringSquares:square]];
    
    for (DMSquare *flipSquare in squaresToFlip) {
        [flipSquare makeSquareSelected:!flipSquare.selected];
        
        if ([[flipSquare squareValue] intValue] > 0) {
            if (flipSquare.selected) {
                [flipSquare setBackgroundColor:self.player1Color];
            }
            
            else {
                [flipSquare setBackgroundColor:self.player2Color];
            }
        }
    }
    
    if (self.playerTurn == 0) {
        self.player1Score += [[square squareValue] intValue];
        [self.player1ScoreLabel updateScore:self.player1Score];
    }
    
    else {
        self.player2Score += [[square squareValue] intValue];
        [self.player2ScoreLabel updateScore:self.player2Score];
    }
    
    [square setSquareValue:[NSNumber numberWithInt:0]];
    [square layoutSubviews];
    [self updateViews];
    
    self.playerTurn = (self.playerTurn == 0) ? 1 : 0;
    
    [self layoutSquares];
    
    if (!self.isGameOver && ![self checkForEndGame]) {
        [self performAI];
    }
}

#pragma mark - Score Label Delegate

- (void)scoreLabelTapped:(int)player {
    if (self.isGameOver) {
        return;
    }
    
    if (player == 0) {
        NSString *otherButtonTitle = @"Finish Game with AI on";
        if (self.player1AI) {
            otherButtonTitle = @"Turn AI Off";
        }
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"%@", self.player1Name]
                                                                 delegate:self
                                                        cancelButtonTitle:@"Cancel"
                                                   destructiveButtonTitle:@"Forfeit"
                                                        otherButtonTitles:otherButtonTitle, nil];
        [actionSheet setTag:PLAYER_1_TAG];
        [actionSheet showInView:self.view];
    }
    
    else if (player == 1) {
        NSString *otherButtonTitle = @"Finish Game with AI on";
        if (self.player2AI) {
            otherButtonTitle = @"Turn AI Off";
        }
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:self.player2Name
                                                                 delegate:self
                                                        cancelButtonTitle:@"Cancel"
                                                   destructiveButtonTitle:@"Forfeit"
                                                        otherButtonTitles:otherButtonTitle, nil];
        [actionSheet setTag:PLAYER_2_TAG];
        [actionSheet showInView:self.view];
    }
}

#pragma mark - Action Sheet Delegate

- (void)actionSheet:(UIActionSheet *)actionSheet willDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ([actionSheet tag] == PLAYER_1_TAG) {
        switch (buttonIndex) {
                // forfeit
            case 0:
                self.player1Score = 0;
                [self gameOver];
                [self updateViews];
                break;
                
                // finish game with AI
            case 1:
                self.player1AI = !self.player1AI;
                [[DMProjectManager sharedProjectManager] setPlayer1AI:self.player1AI];
                [self updateViews];
                break;
                
                // cancel
            case 2:
                
                break;
                
            default:
                break;
        }
    }
    
    else if ([actionSheet tag] == PLAYER_2_TAG) {
        switch (buttonIndex) {
                // forfeit
            case 0:
                self.player2Score = 0;
                [self gameOver];
                [self updateViews];
                break;
                
                // finish game with AI
            case 1:
                self.player2AI = !self.player2AI;
                [[DMProjectManager sharedProjectManager] setPlayer2AI:self.player2AI];
                [self updateViews];
                break;
                
                // cancel
            case 2:
                
                break;
                
            default:
                break;
        }
    }
    
    [self performAI];
}

#pragma mark - check for end game

- (BOOL)checkForEndGame {
    for (NSArray *row in self.grid) {
        if (self.playerTurn == 0) {
            for (DMSquare *square in row) {
                if ([[square squareValue] intValue] > 0) {
                    if ([square selected]) {
                        return NO;
                    }
                }
            }
        }
        
        else {
            for (DMSquare *square in row) {
                if ([[square squareValue] intValue] > 0) {
                    if (![square selected]) {
                        return NO;
                    }
                }
            }
        }
    }
    
    return YES;
}

- (void)gameOver {
    [self.popOver setAlpha:0.0f];
    [self.view addSubview:self.popOver];
    self.isGameOver = YES;
    
    [UIView animateWithDuration:0.5f animations:^{
        [self.popOver setAlpha:1.0f];
        [self updateViews];
    } completion:^(BOOL finished){
        [self performSelector:@selector(animateFinalScore) withObject:self afterDelay:1.1f];
    }];
}

#pragma mark - AI

- (void)performAI {
    if (self.playerTurn == 0 && self.player1AI) {
        [self performSelector:@selector(player1AIMove) withObject:self afterDelay:AI_ANIMATION_TIME];
    }
    
    else if (self.playerTurn == 1 && self.player2AI) {
        [self performSelector:@selector(player2AIMove) withObject:self afterDelay:AI_ANIMATION_TIME];
    }
}

- (void)player1AIMove {
    DMSquare *highestSquare;
    int highestScore = -INT_MAX + 1;
    int originalSquareWeight = 4;
    for (NSArray *row in self.grid) {
        for (DMSquare *square in row) {
            if (![self.playedSquares containsObject:square] && [square selected]) {
                if (!highestSquare) {
                    highestSquare = square;
                }
                
                NSArray *neighbors = [self neighboringSquares:square];
                int neighboringDifference = 0;
                
                for (DMSquare *neighboringSquare in neighbors) {
                    if ([neighboringSquare selected]) {
                        neighboringDifference -= [[neighboringSquare squareValue] intValue];
                    }
                    
                    else {
                        neighboringDifference += [[neighboringSquare squareValue] intValue];
                    }
                }
                
                neighboringDifference += [[square squareValue] intValue] * originalSquareWeight;
                
                if (neighboringDifference > highestScore) {
                    highestSquare = square;
                    highestScore = neighboringDifference;
                }
            }
        }
    }
    
    [self squareTouched:highestSquare];
}

- (void)player2AIMove {
    DMSquare *highestSquare;
    int highestScore = -INT_MAX + 1;
    float originalSquareWeight = ((float)(arc4random()%5 + 2))/5.0f;
    for (NSArray *row in self.grid) {
        for (DMSquare *square in row) {
            if (![self.playedSquares containsObject:square] && ![square selected]) {
                if (!highestSquare) {
                    highestSquare = square;
                }
                
                NSArray *neighbors = [self neighboringSquares:square];
                int neighboringDifference = 0;
                
                for (DMSquare *neighboringSquare in neighbors) {
                    if (![neighboringSquare selected]) {
                        neighboringDifference -= [[neighboringSquare squareValue] intValue];
                    }
                    
                    else {
                        neighboringDifference += [[neighboringSquare squareValue] intValue];
                    }
                }
                
                neighboringDifference += [[square squareValue] intValue] * originalSquareWeight;
                
                if (neighboringDifference > highestScore) {
                    highestSquare = square;
                    highestScore = neighboringDifference;
                }
            }
        }
    }
    
    [self squareTouched:highestSquare];
}

#pragma mark - Neighboring Squares

- (NSArray *)neighboringSquares:(DMSquare *)square {
    NSMutableArray *neighbors = [[NSMutableArray alloc] init];
    
    NSArray *currentColumn = [self.grid objectAtIndex:square.column];
    if (currentColumn.count > square.row + 1) {
        DMSquare *bottomSquare = [currentColumn objectAtIndex:square.row + 1];
        [neighbors addObject:bottomSquare];
    }
    
    if (square.row > 0) {
        DMSquare *topSquare = [currentColumn objectAtIndex:square.row - 1];
        [neighbors addObject:topSquare];
    }
    
    if (square.column > 0) {
        DMSquare *leftSquare = [[self.grid objectAtIndex:square.column - 1] objectAtIndex:square.row];
        [neighbors addObject:leftSquare];
    }
    
    if (square.column + 1 < self.grid.count) {
        DMSquare *rightSquare = [[self.grid objectAtIndex:square.column + 1] objectAtIndex:square.row];
        [neighbors addObject:rightSquare];
    }
    
    return neighbors;
}

#pragma mark - Memory Warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
