//
//  ViewController.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DMMainScreenBackgroundView.h"

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *player1TextField, *player2TextField;
@property (nonatomic, strong) UIButton *playGameButton, *playGameButton2;
@property (nonatomic, strong) UILabel *winLossLabel;
@property (nonatomic, strong) UIColor *textColor, *backgroundColor, *tintColor;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) DMMainScreenBackgroundView *backgroundView;
@property BOOL keyboardShowing, nightModeSet, nightMode;

@end

