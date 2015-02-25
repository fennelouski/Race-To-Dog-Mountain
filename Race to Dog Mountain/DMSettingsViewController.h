//
//  DMSettingsViewController.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 2/24/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DMSettingsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *player1TextField, *player2TextField;
@property (nonatomic, strong) UISwitch *player1AISwitch, *player2AISwitch;
@property (nonatomic, strong) UIButton *doneButton, *doneButton2;
@property (nonatomic, strong) UILabel *computerLabel1, *computerLabel2;
@property (nonatomic, strong) UILabel *complexityLabel;
@property (nonatomic, strong) UISlider *complexitySlider;
@property (nonatomic, strong) UIColor *textColor, *backgroundColor, *tintColor;
@property BOOL keyboardShowing, nightModeSet, nightMode;

@property (nonatomic, strong) UILabel *gameModeLabel;
@property (nonatomic, strong) UISwitch *gameModeSwitch;

@end
