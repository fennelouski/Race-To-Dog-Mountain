//
//  DMSettingsViewController.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 2/24/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMSettingsViewController.h"
#import "DMGameViewController.h"
#import "DMPlusGameViewController.h"
#import "UIColor+AppColors.h"
#import "DMProjectManager.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kStatusBarHeight (([[UIApplication sharedApplication] statusBarFrame].size.height == 20.0f) ? 20.0f : (([[UIApplication sharedApplication] statusBarFrame].size.height == 40.0f) ? 20.0f : 0.0f))
#define kScreenHeight (([[UIApplication sharedApplication] statusBarFrame].size.height > 20.0f) ? [UIScreen mainScreen].bounds.size.height - 20.0f : [UIScreen mainScreen].bounds.size.height)
#define FONT_SCALE 55.0f
#define SHORTER_SIDE ((kScreenWidth < kScreenHeight) ? kScreenWidth : kScreenHeight)

@interface DMSettingsViewController ()

@end

@implementation DMSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setUpColors];
    
    [self.view addSubview:self.player1TextField];
    [self.view addSubview:self.player2TextField];
    
    [self.view addSubview:self.player1AISwitch];
    [self.view addSubview:self.player2AISwitch];
    
    [self.view addSubview:self.computerLabel1];
    [self.view addSubview:self.computerLabel2];
    
    [self.view addSubview:self.doneButton];
    
    [self.view addSubview:self.complexityLabel];
    [self.view addSubview:self.complexitySlider];
    
    [self.view addSubview:self.gameModeLabel];
    [self.view addSubview:self.gameModeSwitch];
    
    [self setUpColors];
    [self changeColors];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self  selector:@selector(updateViews)    name:UIDeviceOrientationDidChangeNotification  object:nil];
    [nc addObserver:self selector:@selector(updateViews) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:self];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:self];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillChangeFrameNotification object:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [self layoutTextFields];
    [self layoutAISwitches];
    [self gameModeSwitchTouched];
    
    [self.doneButton setFrame:CGRectMake(0.0f,
                                         kScreenHeight - (kScreenHeight + kScreenWidth)/20.0f,
                                         kScreenWidth,
                                         (kScreenHeight + kScreenWidth)/20.0f)];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *player1AI = [defaults objectForKey:@"player1AI"];
    if (player1AI) {
        [_player1AISwitch setOn:[player1AI boolValue] animated:YES];
    }
    
    NSNumber *player2AI = [defaults objectForKey:@"player2AI"];
    if (player2AI) {
        [_player2AISwitch setOn:[player2AI boolValue] animated:YES];
    }
    
    [self textFieldShouldReturn:self.player1TextField];
    
    //    [self playGame];
}

- (void)updateViews {
    [UIView animateWithDuration:0.35f animations:^{
        [self layoutTextFields];
        [self layoutAISwitches];
        
        [self.doneButton setFrame:CGRectMake(0.0f,
                                             kScreenHeight - (kScreenHeight + kScreenWidth)/20.0f,
                                             kScreenWidth,
                                             (kScreenHeight + kScreenWidth)/20.0f)];
    }];
}

- (void)layoutTextFields {
    float leftSideOffset = 80.0f;
    
    
    // portrait
    if (kScreenHeight > kScreenWidth) {
        [self.player1TextField setFrame:CGRectMake(leftSideOffset,
                                                   kScreenHeight/8.0f,
                                                   kScreenWidth - leftSideOffset,
                                                   40.0f)];
        [self.player2TextField setFrame:CGRectMake(leftSideOffset,
                                                   kScreenHeight/4.0f,
                                                   kScreenWidth - leftSideOffset,
                                                   40.0f)];
        [self.complexityLabel setFrame:CGRectMake(0.0f,
                                                  kScreenHeight / 2.5f,
                                                  kScreenWidth,
                                                  44.0f)];
        [self.complexitySlider setFrame:CGRectMake(leftSideOffset,
                                                   kScreenHeight/2.5f + 44.0f,
                                                   kScreenWidth - 2.0f*leftSideOffset,
                                                   30.0f)];
        [self.gameModeLabel setFrame:CGRectMake(leftSideOffset,
                                                kScreenHeight/1.5f - 5.0f,
                                                kScreenWidth - leftSideOffset,
                                                40.0f)];
    }
    
    // landscape
    else {
        [self.player1TextField setFrame:CGRectMake(leftSideOffset,
                                                   kStatusBarHeight  + 5.0f,
                                                   kScreenWidth/2.0f - leftSideOffset,
                                                   kScreenHeight/4.0f)];
        [self.player2TextField setFrame:CGRectMake(kScreenWidth/2.0f + leftSideOffset,
                                                   kStatusBarHeight + 5.0f,
                                                   kScreenWidth/2.0f - leftSideOffset,
                                                   kScreenHeight/4.0f)];
        [self.gameModeLabel setFrame:CGRectMake(0.0f,
                                                kScreenHeight/1.5f - 5.0f,
                                                kScreenWidth,
                                                40.0f)];
        
        // if the screen is tall in enough in landscape for the keyboard, slider, and name textfields then move the slider to above the input accessory view on the keyboard
        if (kScreenHeight > 400.0f) {
            [self.complexityLabel setFrame:CGRectMake(0.0f,
                                                      kScreenHeight / 2.2f,
                                                      kScreenWidth,
                                                      44.0f)];
            [self.complexitySlider setFrame:CGRectMake(kScreenWidth/4.0f,
                                                       kScreenHeight/2.2f + 44.0f,
                                                       kScreenWidth/2.0f,
                                                       40.0f)];
        }
        
        // this is (probably) an iPhone 6 and there is enough room for the slider between the keyboard and name textfields, so position the slider a little more precisely to make it look good
        if (kScreenHeight > 340.0f) {
            [self.complexityLabel setFrame:CGRectMake(0.0f,
                                                      kScreenHeight / 2.5f,
                                                      kScreenWidth,
                                                      44.0f)];
            [self.complexitySlider setFrame:CGRectMake(kScreenWidth/4.0f,
                                                       kScreenHeight/2.5f + 44.0f,
                                                       kScreenWidth/2.0f,
                                                       40.0f)];
        }
        
        // the screen isn't tall enough to show the slider in between the keyboard and name textfields so hide it behind the keyboard (this is only a problem on iphone 4s/5/5s/6)
        else {
            [self.complexityLabel setFrame:CGRectMake(0.0f,
                                                      kScreenHeight / 2.8f,
                                                      kScreenWidth,
                                                      44.0f)];
            [self.complexitySlider setFrame:CGRectMake(kScreenWidth/4.0f,
                                                       kScreenHeight/2.8f + 44.0f,
                                                       kScreenWidth/2.0f,
                                                       40.0f)];
        }
    }
}

- (void)layoutAISwitches {
    // portrait
    if (kScreenHeight > kScreenWidth) {
        [self.player1AISwitch setFrame:CGRectMake(20.0f,
                                                  kScreenHeight/8.0f,
                                                  kScreenWidth,
                                                  40.0f)];
        [self.player1AISwitch setCenter:CGPointMake(self.player1AISwitch.center.x,
                                                    self.player1TextField.center.y)];
        [self.player2AISwitch setFrame:CGRectMake(20.0f,
                                                  kScreenHeight/4.0f,
                                                  kScreenWidth,
                                                  40.0f)];
        [self.player2AISwitch setCenter:CGPointMake(self.player2AISwitch.center.x,
                                                    self.player2TextField.center.y)];
        [self.gameModeSwitch setFrame:CGRectMake(20.0f,
                                                 kScreenHeight/1.5f,
                                                 kScreenWidth,
                                                 40.0f)];
        [self.gameModeSwitch setCenter:CGPointMake(self.gameModeSwitch.center.x,
                                                   self.gameModeSwitch.center.y)];
    }
    
    // landscape
    else {
        [self.player1AISwitch setFrame:CGRectMake(20.0f,
                                                  kScreenHeight/8.0f,
                                                  kScreenWidth/2.0f,
                                                  kScreenHeight/4.0f)];
        [self.player1AISwitch setCenter:CGPointMake(self.player1AISwitch.center.x,
self.player1TextField.center.y)];
        [self.player2AISwitch setFrame:CGRectMake(kScreenWidth/2.0f + 20.0f,
                                                  kScreenHeight/8.0f,
                                                  kScreenWidth/2.0f,
                                                  kScreenHeight/4.0f)];
        [self.player2AISwitch setCenter:CGPointMake(self.player2AISwitch.center.x,
                                                    self.player2TextField.center.y)];
        [self.gameModeSwitch setFrame:CGRectMake(20.0f,
                                                 kScreenHeight/1.5f,
                                                 kScreenWidth,
                                                 40.0f)];
        [self.gameModeSwitch setCenter:CGPointMake(self.gameModeSwitch.center.x,
                                                   self.gameModeSwitch.center.y)];
    }
    
    [self.computerLabel1 setCenter:CGPointMake(self.player1AISwitch.center.x,
                                               self.player1AISwitch.center.y - 30.0f)];
    [self.computerLabel2 setCenter:CGPointMake(self.player2AISwitch.center.x,
                                               self.player2AISwitch.center.y - 30.0f)];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSLog(@"keyboardWillShow");
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSLog(@"keyboardWillHide");
}

- (void)setUpColors {
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:86400 * 29 * 0 + 31536000 * (arc4random() % 1) + 0 * 43000];
    
    NSArray *colors = [UIColor holidayColorsForDate:now];
    
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComps = [gregorianCalendar components:(NSCalendarUnitHour) fromDate: now];
    NSInteger hour = [dateComps hour];
    
    if (!self.nightModeSet) {
        if (hour > 6 && hour < 22) {
            self.nightMode = NO;
        }
        
        else {
            self.nightMode = YES;
        }
        
        self.nightModeSet = YES;
    }
    
    if (colors.count > 0) {
        // daytime so use lighter colors
        if (!self.nightMode) {
            self.backgroundColor = [colors objectAtIndex:3];
            self.textColor = [colors objectAtIndex:1];
            self.tintColor = [colors objectAtIndex:2];
            [self.player1TextField setKeyboardAppearance:UIKeyboardAppearanceLight];
            [self.player2TextField setKeyboardAppearance:UIKeyboardAppearanceLight];
            [self.player1TextField reloadInputViews];
            [self.player2TextField reloadInputViews];
        }
        
        else {
            self.backgroundColor = [colors objectAtIndex:0];
            self.textColor = [colors objectAtIndex:2];
            self.tintColor = [colors objectAtIndex:1];
            [self.player1TextField setKeyboardAppearance:UIKeyboardAppearanceDark];
            [self.player2TextField setKeyboardAppearance:UIKeyboardAppearanceDark];
            [self.player1TextField reloadInputViews];
            [self.player2TextField reloadInputViews];
        }
    }
    
    // just as a backup
    else if (!self.nightMode) {
        self.backgroundColor = [UIColor colorWithRed:45.0f/255.0f green:159.0f/255.0f blue:169.0f/255.0f alpha:1.0f];
        self.textColor = [UIColor colorWithRed:1.0f green:0.97f blue:206.0f/255.0f alpha:1.0f];
        self.tintColor = [UIColor colorWithRed:16.0f/255.0f green:21.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
    }
    
    // second backup...just in case
    else {
        self.backgroundColor = [UIColor colorWithRed:16.0f/255.0f green:21.0f/255.0f blue:43.0f/255.0f alpha:1.0f];
        self.textColor = [UIColor colorWithRed:1.0f green:0.97f blue:206.0f/255.0f alpha:1.0f];
        self.tintColor = [UIColor colorWithRed:45.0f/255.0f green:159.0f/255.0f blue:169.0f/255.0f alpha:1.0f];
    }
}

- (void)changeColors {
    [_player1TextField setTintColor:self.tintColor];
    [_player2TextField setTintColor:self.tintColor];
    [_player1AISwitch setTintColor:self.tintColor];
    [_player2AISwitch setTintColor:self.tintColor];
    [_complexitySlider setTintColor:self.tintColor];
    [_player1AISwitch setOnTintColor:self.tintColor];
    [_player2AISwitch setOnTintColor:self.tintColor];
    [_gameModeSwitch setTintColor:self.tintColor];
    [_gameModeSwitch setOnTintColor:self.tintColor];
    
    UIColor *placeholderColor = [self.backgroundColor lightenColorBy:0.5f];
    [placeholderColor setValue:[NSNumber numberWithFloat:0.95f] forKey:@"alphaComponent"];
    [_player1TextField setValue:placeholderColor forKeyPath:@"_placeholderLabel.textColor"];
    [_player2TextField setValue:placeholderColor forKeyPath:@"_placeholderLabel.textColor"];
    
    [_player1TextField setTextColor:self.textColor];
    [_player2TextField setTextColor:self.textColor];
    [_computerLabel1 setTextColor:self.textColor];
    [_computerLabel2 setTextColor:self.textColor];
    [_gameModeLabel setTextColor:self.textColor];
    [_complexityLabel setTextColor:self.textColor];
    
    [self.view setBackgroundColor:self.backgroundColor];
}

#pragma mark - Subviews

- (UITextField *)player1TextField {
    if (!_player1TextField) {
        _player1TextField = [[UITextField alloc] initWithFrame:CGRectZero];
        [_player1TextField setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/FONT_SCALE]];
        [_player1TextField setPlaceholder:@"Player 1 Name"];
        [_player1TextField setTextAlignment:NSTextAlignmentCenter];
        [_player1TextField.layer setCornerRadius:5.0f];
        [_player1TextField setInputAccessoryView:self.doneButton2];
        [_player1TextField setDelegate:self];
        [_player1TextField setKeyboardType:UIKeyboardTypeAlphabet];
        [_player1TextField setReturnKeyType:UIReturnKeyDone];
        [_player1TextField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_player1TextField setAutocorrectionType:UITextAutocorrectionTypeNo];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *player1String = [defaults objectForKey:@"player1Name"];
        if (player1String) {
            [_player1TextField setText:player1String];
        }
    }
    
    return _player1TextField;
}

- (UITextField *)player2TextField {
    if (!_player2TextField) {
        _player2TextField = [[UITextField alloc] initWithFrame:CGRectZero];
        [_player2TextField setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/FONT_SCALE]];
        [_player2TextField setPlaceholder:@"Player 2 Name"];
        [_player2TextField setTextAlignment:NSTextAlignmentCenter];
        [_player2TextField.layer setCornerRadius:5.0f];
        [_player2TextField setInputAccessoryView:self.doneButton2];
        [_player2TextField setDelegate:self];
        [_player2TextField setKeyboardType:UIKeyboardTypeAlphabet];
        [_player2TextField setReturnKeyType:UIReturnKeyDone];
        [_player2TextField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_player2TextField setAutocorrectionType:UITextAutocorrectionTypeNo];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *player2String = [defaults objectForKey:@"player2Name"];
        if (player2String) {
            [_player2TextField setText:player2String];
        }
    }
    
    return _player2TextField;
}

- (UISwitch *)player1AISwitch {
    if (!_player1AISwitch) {
        _player1AISwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_player1AISwitch setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
        [_player1AISwitch setOn:[[DMProjectManager sharedProjectManager] player1AI]];
        [_player1AISwitch addTarget:self action:@selector(player1AISwitchTouched) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _player1AISwitch;
}

- (UISwitch *)player2AISwitch {
    if (!_player2AISwitch) {
        _player2AISwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_player2AISwitch setOn:[[DMProjectManager sharedProjectManager] player1AI]];
        [_player2AISwitch addTarget:self action:@selector(player2AISwitchTouched) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _player2AISwitch;
}

- (UIButton *)doneButton {
    if (!_doneButton) {
        _doneButton = [[UIButton alloc] initWithFrame:CGRectZero];
        [_doneButton setTitle:@"Done" forState:UIControlStateNormal];
        [_doneButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
        [_doneButton setBackgroundColor:[UIColor colorWithWhite:0.1f alpha:0.3f]];
        [_doneButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_doneButton.titleLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(FONT_SCALE)]];
        [_doneButton addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _doneButton;
}

- (UIButton *)doneButton2 {
    if (!_doneButton2) {
        _doneButton2 = [[UIButton alloc] initWithFrame:CGRectMake(0.0f,
                                                                  0.0f,
                                                                  kScreenWidth,
                                                                  (kScreenHeight + kScreenWidth)/20.0f)];
        [_doneButton2 setTitle:@"Done" forState:UIControlStateNormal];
        [_doneButton2.titleLabel setTextAlignment:NSTextAlignmentCenter];
        [_doneButton2 setBackgroundColor:[UIColor colorWithWhite:0.1f alpha:1.0f]];
        [_doneButton2 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_doneButton2.titleLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(FONT_SCALE)]];
        [_doneButton2 addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _doneButton2;
}

- (UILabel *)computerLabel1 {
    if (!_computerLabel1) {
        _computerLabel1 = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                    0.0f,
                                                                    80.0f,
                                                                    20.0f)];
        [_computerLabel1 setText:@"Computer"];
        [_computerLabel1 setTextAlignment:NSTextAlignmentCenter];
        [_computerLabel1 setFont:[UIFont systemFontOfSize:14.0f]];
    }
    
    return _computerLabel1;
}

- (UILabel *)computerLabel2 {
    if (!_computerLabel2) {
        _computerLabel2 = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                    0.0f,
                                                                    80.0f,
                                                                    20.0f)];
        [_computerLabel2 setText:@"Computer"];
        [_computerLabel2 setTextAlignment:NSTextAlignmentCenter];
        [_computerLabel2 setFont:[UIFont systemFontOfSize:14.0f]];
    }
    
    return _computerLabel2;
}

- (UILabel *)complexityLabel {
    if (!_complexityLabel) {
        _complexityLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                     kScreenHeight/2.0f,
                                                                     kScreenWidth,
                                                                     40.0f)];
        [_complexityLabel setText:@"Game Board Size"];
        [_complexityLabel setTextAlignment:NSTextAlignmentCenter];
        [_complexityLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(FONT_SCALE)]];
    }
    
    return _complexityLabel;
}

- (UISlider *)complexitySlider {
    if (!_complexitySlider) {
        _complexitySlider = [[UISlider alloc] initWithFrame:CGRectZero];
        [_complexitySlider setMinimumValue:2.0f];
        [_complexitySlider setMaximumValue:11.0f];
        
        if (SHORTER_SIDE / 14.0f > 35.0f) {
            [_complexitySlider setMaximumValue:14.0f];
        }
        
        else if (SHORTER_SIDE / 13.0f > 30.0f) {
            [_complexitySlider setMaximumValue:13.0f];
        }
        
        else if (SHORTER_SIDE / 12.0f > 30.0f) {
            [_complexitySlider setMaximumValue:12.0f];
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSNumber *complexity = [defaults objectForKey:@"complexity"];
        if (complexity) {
            [_complexitySlider setValue:[complexity floatValue]];
        }
        
        else {
            [_complexitySlider setValue:6.0f];
        }
    }
    
    return _complexitySlider;
}

- (UILabel *)gameModeLabel {
    if (!_gameModeLabel) {
        _gameModeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f,
                                                                   kScreenHeight/1.5f,
                                                                   kScreenWidth,
                                                                   44.0f)];
        [_gameModeLabel setTextAlignment:NSTextAlignmentCenter];
        [_gameModeLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(FONT_SCALE)]];
        
        [_gameModeLabel setText:@"Rows & Columns"];
        
        if ([[DMProjectManager sharedProjectManager] isPlusGame]) {
            [_gameModeLabel setText:@"Flip Adjacent Squares"];
        }
    }
    
    return _gameModeLabel;
}

- (UISwitch *)gameModeSwitch {
    if (!_gameModeSwitch) {
        _gameModeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(0.0f,
                                                                     kScreenHeight/2.5f,
                                                                     80.0f,
                                                                     44.0f)];
        [_gameModeSwitch addTarget:self action:@selector(gameModeSwitchTouched) forControlEvents:UIControlEventTouchUpInside];
        [_gameModeSwitch setOn:[[DMProjectManager sharedProjectManager] isPlusGame] animated:YES];
    }
    
    return _gameModeSwitch;
}

#pragma mark - Game Mode

- (void)gameModeSwitchTouched {
    [[DMProjectManager sharedProjectManager] setIsPlusGame:self.gameModeSwitch.on];
    
    [_gameModeLabel setText:@"Rows & Columns"];
    
    if ([[DMProjectManager sharedProjectManager] isPlusGame]) {
        [_gameModeLabel setText:@"Flip Adjacent Squares"];
    }
}

#pragma mark - Done!

- (void)done {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:self.player1TextField.text forKey:@"player1Name"];
    [defaults setObject:self.player2TextField.text forKey:@"player2Name"];
    
    [[DMProjectManager sharedProjectManager] setComplexity:self.complexitySlider.value];
    
    [defaults setObject:[NSNumber numberWithBool:self.player1AISwitch.on] forKey:@"player1AI"];
    [defaults setObject:[NSNumber numberWithBool:self.player2AISwitch.on] forKey:@"player2AI"];
    
    [defaults setObject:[NSNumber numberWithFloat:self.complexitySlider.value] forKey:@"complexity"];
    
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

#pragma mark - AI Switches Touched

- (void)player1AISwitchTouched {
    [[DMProjectManager sharedProjectManager] setPlayer1AI:self.player1AISwitch.on];
}

- (void)player2AISwitchTouched {
    [[DMProjectManager sharedProjectManager] setPlayer2AI:self.player2AISwitch.on];
}

#pragma mark - Text Field delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField isEqual:self.player1TextField]) {
        //        if (self.player2TextField.text.length > 0.0f) {
        [textField resignFirstResponder];
        //        }
        //
        //        else {
        //            [self.player2TextField becomeFirstResponder];
        //        }
    }
    
    if ([textField isEqual:self.player2TextField]) {
        //        if (self.player1TextField.text.length > 0.0f) {
        [textField resignFirstResponder];
        //        }
        //
        //        else {
        //            [self.player1TextField becomeFirstResponder];
        //        }
    }
    
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    NSString *player1Name = self.player1TextField.text;
    NSString *player2Name = self.player2TextField.text;
    
    [[DMProjectManager sharedProjectManager] setPlayer1Name:player1Name];
    [[DMProjectManager sharedProjectManager] setPlayer2Name:player2Name];
    
    [self performSelector:@selector(updateViews) withObject:self afterDelay:0.001f];
    
    return YES;
}

#pragma mark Motion Gesture Methods

- (BOOL)canBecomeFirstResponder {
    return YES;
}


- (void)motionBegan:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake ) {
        self.nightMode = !self.nightMode;
        [self setUpColors];
        
        float screenBrightness = [[UIScreen mainScreen] brightness];
        if (self.nightMode) {
            screenBrightness *= 0.6666667f;
        }
        
        else {
            screenBrightness *= 1.5f;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"originalScreenBrightness"]) {
            float originalScreenBrightness = [[defaults objectForKey:@"originalScreenBrightness"] floatValue];
            if (originalScreenBrightness < screenBrightness) {
                screenBrightness = originalScreenBrightness;
            }
        }
        
        [UIView animateWithDuration:0.15f animations:^{
            [[UIScreen mainScreen] setBrightness:screenBrightness];
            [_player1TextField setAlpha:0.0f];
            [_player2TextField setAlpha:0.0f];
            [self setUpColors];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15f animations:^{
                [self changeColors];
                [_player1TextField setAlpha:1.0f];
                [_player2TextField setAlpha:1.0f];
            } completion:^(BOOL finished){
                [self updateViews];
            }];
        }];
    }
}

#pragma mark - Memory Warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
