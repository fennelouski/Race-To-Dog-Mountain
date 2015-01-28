//
//  ViewController.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *player1TextField, *player2TextField;
@property (nonatomic, strong) UISwitch *player1AISwitch, *player2AISwitch;
@property (nonatomic, strong) UIButton *playGameButton, *playGameButton2;
@property (nonatomic, strong) UILabel *computerLabel1, *computerLabel2;
@property (nonatomic, strong) UISlider *complexitySlider;

@end

