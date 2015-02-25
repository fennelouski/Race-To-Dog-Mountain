//
//  ViewController.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "ViewController.h"
#import "DMSettingsViewController.h"
#import "DMGameViewController.h"
#import "DMPlusGameViewController.h"
#import "DMProjectManager.h"
#import "UIColor+AppColors.h"
#import <QuartzCore/QuartzCore.h>

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kStatusBarHeight (([[UIApplication sharedApplication] statusBarFrame].size.height == 20.0f) ? 20.0f : (([[UIApplication sharedApplication] statusBarFrame].size.height == 40.0f) ? 20.0f : 0.0f))
#define kScreenHeight (([[UIApplication sharedApplication] statusBarFrame].size.height > 20.0f) ? [UIScreen mainScreen].bounds.size.height - 20.0f : [UIScreen mainScreen].bounds.size.height)
#define FONT_SCALE 30.0f
#define SHORTER_SIDE ((kScreenWidth < kScreenHeight) ? kScreenWidth : kScreenHeight)
#define LONGER_SIDE ((kScreenWidth > kScreenHeight) ? kScreenWidth : kScreenHeight)
#define BUFFER 5.0f
#define BUTTON_SIZE 44.0f

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setUpColors];
    
    [self.view addSubview:self.backgroundView];
    [self.view addSubview:self.backgroundView.mountainView];
    [self.view addSubview:self.player1TextField];
    [self.view addSubview:self.backgroundView.mountainView2];
    [self.view addSubview:self.player2TextField];
    [self.view addSubview:self.backgroundView.mountainView3];
    
    [self animateTextField:self.player1TextField];
    [self animateTextField:self.player2TextField];
    
    [self.view addSubview:self.playGameButton];
    
    [self.view addSubview:self.winLossLabel];
    
    [self.view addSubview:self.settingsButton];
    
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
    [super viewWillAppear:animated];
    
    [self.player1TextField setText:[[DMProjectManager sharedProjectManager] player1Name]];
    [self.player2TextField setText:[[DMProjectManager sharedProjectManager] player2Name]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateViews];
    
    [self textFieldShouldReturn:self.player1TextField];
    
//    [self playGame]; // 
}

- (void)updateViews {
    [UIView animateWithDuration:0.35f animations:^{
        [self layoutTextFields];
        
        [self.playGameButton setFrame:CGRectMake(0.0f,
                                                 kScreenHeight - (kScreenHeight + kScreenWidth)/20.0f,
                                                 kScreenWidth,
                                                 (kScreenHeight + kScreenWidth)/20.0f)];
        [self.settingsButton setFrame:CGRectMake(kScreenWidth - BUTTON_SIZE - BUFFER,
                                                 kStatusBarHeight + BUFFER,
                                                 BUTTON_SIZE,
                                                 BUTTON_SIZE)];
        [self.backgroundView setFrame:CGRectMake(0.0f,
                                                 0.0f,
                                                 LONGER_SIDE,
                                                 LONGER_SIDE)];
    }];
}

- (void)layoutTextFields {
    float leftSideOffset = 00.0f;
    // portrait
    if (kScreenHeight > kScreenWidth) {
        [self.player1TextField setFrame:CGRectMake(-50.0f,
                                                   kScreenHeight/5.5f - 120.0f,
                                                   kScreenWidth - leftSideOffset,
                                                   kScreenHeight/FONT_SCALE*20.0f)];
        [self.player2TextField setFrame:CGRectMake(20.0f,
                                                   kScreenHeight/3.5f - 70.0f,
                                                   kScreenWidth - leftSideOffset,
                                                   kScreenHeight/FONT_SCALE*20.0f)];
        [self.winLossLabel setCenter:CGPointMake(kScreenWidth/2.0f,
                                                 self.winLossLabel.center.y + kScreenHeight/10.0f)];
    }
    
    // landscape
    else {
        [self.player1TextField setFrame:CGRectMake(-20.0f,
                                                   kStatusBarHeight  - kScreenHeight / 5.0f,
                                                   kScreenWidth/1.5f - leftSideOffset,
                                                   kScreenHeight/FONT_SCALE*40.0f)];
        [self.player2TextField setFrame:CGRectMake(kScreenWidth/4.0f,
                                                   kStatusBarHeight - kScreenHeight / 5.0f,
                                                   kScreenWidth/1.5f - leftSideOffset,
                                                   kScreenHeight/FONT_SCALE*40.0f)];
        
        // if the screen is tall in enough in landscape for the keyboard, slider, and name textfields then move the slider to above the input accessory view on the keyboard
        if (kScreenHeight > 400.0f) {
            [self.winLossLabel setFrame:CGRectMake(kScreenWidth/4.0f,
                                                   kScreenHeight/1.5f,
                                                   kScreenWidth/2.0f,
                                                   40.0f)];
            [self.winLossLabel setCenter:CGPointMake(kScreenWidth/2.0f,
                                                     self.winLossLabel.center.y + kScreenHeight/3.0f)];
        }
        
        // this is (probably) an iPhone 6 and there is enough room for the slider between the keyboard and name textfields, so position the slider a little more precisely to make it look good
        if (kScreenHeight > 340.0f) {
            [self.winLossLabel setFrame:CGRectMake(kScreenWidth/4.0f,
                                                   kScreenHeight/2.5f,
                                                   kScreenWidth/2.0f,
                                                   40.0f)];
            [self.winLossLabel setCenter:CGPointMake(kScreenWidth/2.0f,
                                                     self.winLossLabel.center.y + kScreenHeight/3.0f)];
        }
        
        // the screen isn't tall enough to show the slider in between the keyboard and name textfields so hide it behind the keyboard (this is only a problem on iphone 4s/5/5s/6)
        else {
            [self.winLossLabel setFrame:CGRectMake(kScreenWidth/4.0f,
                                                   kScreenHeight/2.0f,
                                                   kScreenWidth/2.0f,
                                                   40.0f)];
            [self.winLossLabel setCenter:CGPointMake(kScreenWidth/2.0f,
                                                     self.winLossLabel.center.y + kScreenHeight/6.0f)];
        }
    }
    
    // 4s Screen
    if (kScreenHeight < 500.0f && kScreenWidth < 500.0f) {
        [self.winLossLabel removeFromSuperview];
    }
    
    [self.winLossLabel setAlpha:0.0f]; // just remove this until a better layout is determined
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
            self.textColor = [colors objectAtIndex:1];
            self.tintColor = [colors objectAtIndex:2];
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
    
    UIColor *placeholderColor = [self.backgroundColor lightenColorBy:0.5f];
    [placeholderColor setValue:[NSNumber numberWithFloat:0.95f] forKey:@"alphaComponent"];
    [_player1TextField setValue:placeholderColor forKeyPath:@"_placeholderLabel.textColor"];
    [_player2TextField setValue:placeholderColor forKeyPath:@"_placeholderLabel.textColor"];
    
    [_player1TextField setTextColor:[UIColor white]];
    [_player2TextField setTextColor:[UIColor white]];
    [_winLossLabel setTextColor:self.textColor];
    
    [self.view setBackgroundColor:[UIColor white]];
}

#pragma mark - Subviews

- (UITextField *)player1TextField {
    if (!_player1TextField) {
        _player1TextField = [[UITextField alloc] initWithFrame:CGRectMake(0.0f,
                                                                          kScreenHeight/2.0f,
                                                                          kScreenWidth,
                                                                          kScreenHeight/4.0f)];
        [_player1TextField setFont:[UIFont boldSystemFontOfSize:kScreenHeight/FONT_SCALE*2.5f]];
        [_player1TextField setPlaceholder:@"Player 1"];
        [_player1TextField setTextAlignment:NSTextAlignmentCenter];
        [_player1TextField.layer setCornerRadius:5.0f];
        [_player1TextField setInputAccessoryView:self.playGameButton2];
        [_player1TextField setDelegate:self];
        [_player1TextField setKeyboardType:UIKeyboardTypeAlphabet];
        [_player1TextField setReturnKeyType:UIReturnKeyDone];
        [_player1TextField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_player1TextField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_player1TextField setUserInteractionEnabled:NO];
        [_player1TextField setTransform:CGAffineTransformMakeRotation(M_PI/8.0f)];
        [_player1TextField setTag:1];
        [_player1TextField setTextColor:[UIColor white]];
        
        [_player1TextField setText:[[DMProjectManager sharedProjectManager] player1Name]];
    }
    
    return _player1TextField;
}

- (UITextField *)player2TextField {
    if (!_player2TextField) {
        _player2TextField = [[UITextField alloc] initWithFrame:CGRectMake(0.0f,
                                                                          kScreenHeight/1.5f,
                                                                          kScreenWidth,
                                                                          kScreenHeight/4.0f)];
        [_player2TextField setFont:[UIFont boldSystemFontOfSize:kScreenHeight/FONT_SCALE*2.5f]];
        [_player2TextField setPlaceholder:@"Player 2"];
        [_player2TextField setTextAlignment:NSTextAlignmentCenter];
        [_player2TextField.layer setCornerRadius:5.0f];
        [_player2TextField setInputAccessoryView:self.playGameButton2];
        [_player2TextField setDelegate:self];
        [_player2TextField setKeyboardType:UIKeyboardTypeAlphabet];
        [_player2TextField setReturnKeyType:UIReturnKeyDone];
        [_player2TextField setAutocapitalizationType:UITextAutocapitalizationTypeWords];
        [_player2TextField setAutocorrectionType:UITextAutocorrectionTypeNo];
        [_player2TextField setUserInteractionEnabled:NO];
        [_player2TextField setTransform:CGAffineTransformMakeRotation(M_PI/8.0f)];
        [_player2TextField setTag:1];
        [_player2TextField setTextColor:[UIColor white]];
        
        [_player2TextField setText:[[DMProjectManager sharedProjectManager] player2Name]];
    }
    
    return _player2TextField;
}

- (UIButton *)playGameButton {
    if (!_playGameButton) {
        _playGameButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f,
                                                                     kScreenHeight,
                                                                     kScreenWidth,
                                                                     40.0f)];
        [_playGameButton setTitle:@"Play" forState:UIControlStateNormal];
        [_playGameButton.titleLabel setTextAlignment:NSTextAlignmentCenter];
        [_playGameButton setBackgroundColor:[UIColor colorWithWhite:0.1f alpha:0.3f]];
        [_playGameButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_playGameButton.titleLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(1.5f * FONT_SCALE)]];
        [_playGameButton addTarget:self action:@selector(playGame) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _playGameButton;
}

- (UIButton *)playGameButton2 {
    if (!_playGameButton2) {
        _playGameButton2 = [[UIButton alloc] initWithFrame:CGRectMake(0.0f,
                                                                      0.0f,
                                                                      kScreenWidth,
                                                                      (kScreenHeight + kScreenWidth)/20.0f)];
        [_playGameButton2 setTitle:@"Play" forState:UIControlStateNormal];
        [_playGameButton2.titleLabel setTextAlignment:NSTextAlignmentCenter];
        [_playGameButton2 setBackgroundColor:[UIColor colorWithWhite:0.1f alpha:0.3f]];
        [_playGameButton2 setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_playGameButton2.titleLabel setFont:[UIFont systemFontOfSize:(kScreenHeight + kScreenWidth)/(1.5f * FONT_SCALE)]];
        [_playGameButton2 addTarget:self action:@selector(playGame) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _playGameButton2;
}

- (UILabel *)winLossLabel {
    if (!_winLossLabel) {
        _winLossLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_winLossLabel setTextAlignment:NSTextAlignmentCenter];
        [_winLossLabel setFont:[UIFont systemFontOfSize:kScreenHeight/FONT_SCALE]];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *player1Name = @"Player 1";
    if (self.player1TextField.text.length > 0) {
        player1Name = self.player1TextField.text;
    }
    
    NSString *player2Name = @"Player 2";
    if (self.player2TextField.text.length > 0) {
        player2Name = self.player2TextField.text;
    }
    
    NSNumber *player1Score = [defaults objectForKey:[NSString stringWithFormat:@"%@vvv%@", player1Name, player2Name]];
    NSNumber *player2Score = [defaults objectForKey:[NSString stringWithFormat:@"%@vvv%@", player2Name, player1Name]];
    
    if (player1Score && player2Score) {
        [_winLossLabel setText:[NSString stringWithFormat:@"%d - %d", [player1Score intValue], [player2Score intValue]]];
    }
    
    return _winLossLabel;
}

- (UIButton *)settingsButton {
    if (!_settingsButton) {
        _settingsButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f,
                                                                     kStatusBarHeight,
                                                                     44.0f,
                                                                     44.0f)];
        [_settingsButton setImage:[UIImage imageNamed:@"Gear Icon"] forState:UIControlStateNormal];
        [_settingsButton addTarget:self action:@selector(settingsButtonTouched) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return _settingsButton;
}

- (DMMainScreenBackgroundView *)backgroundView {
    if (!_backgroundView) {
        _backgroundView = [[DMMainScreenBackgroundView alloc] initWithFrame:CGRectMake(0.0f,
                                                                                       0.0f,
                                                                                       kScreenWidth,
                                                                                       kScreenHeight)];
    }
    
    return _backgroundView;
}

#pragma mark - Show Settings

- (void)settingsButtonTouched {
    [self showSettings];
}

- (void)showSettings {
    DMSettingsViewController *settingsViewController = [[DMSettingsViewController alloc] init];
    
    [self presentViewController:settingsViewController animated:YES completion:^{
        
    }];
}

#pragma mark - Play Game

- (void)playGame {
    DMGameViewController *gameViewController = [[DMGameViewController alloc] init];
    [gameViewController setPlayer1Name:self.player1TextField.text];
    [gameViewController setPlayer2Name:self.player2TextField.text];
    [gameViewController setPlayer1AI:[[DMProjectManager sharedProjectManager] player1AI]];
    [gameViewController setPlayer2AI:[[DMProjectManager sharedProjectManager] player2AI]];
    [gameViewController setNightMode:self.nightMode];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (self.player1TextField.text.length > 0) {
        [defaults setObject:self.player1TextField.text forKey:@"player1Name"];
    }
    
    if (self.player2TextField.text.length > 0) {
        [defaults setObject:self.player2TextField.text forKey:@"player2Name"];
    }
    
    [gameViewController setNumberOfRows:[[DMProjectManager sharedProjectManager] complexity]];
    
    DMPlusGameViewController *plusGameViewController = [[DMPlusGameViewController alloc] init];
    [plusGameViewController setPlayer1Name:[[DMProjectManager sharedProjectManager] player1Name]];
    [plusGameViewController setPlayer2Name:[[DMProjectManager sharedProjectManager] player2Name]];
    [plusGameViewController setPlayer1AI:[[DMProjectManager sharedProjectManager] player1AI]];
    [plusGameViewController setPlayer2AI:[[DMProjectManager sharedProjectManager] player2AI]];
    [plusGameViewController setNightMode:self.nightMode];
    [plusGameViewController setNumberOfRows:[[DMProjectManager sharedProjectManager] complexity]];
    
    if ([[DMProjectManager sharedProjectManager] player1AI]) {
        NSLog(@"Player1 is a computer");
    }
    
    if ([[DMProjectManager sharedProjectManager] player2AI]) {
        NSLog(@"Player2 is a computer");
    }

    if ([[DMProjectManager sharedProjectManager] isPlusGame]) {
        [self presentViewController:plusGameViewController animated:YES completion:^{
            
        }];
    }
    
    else {
        [self presentViewController:gameViewController animated:YES completion:^{
            
        }];
    }
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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *player1Name = @"Player 1";
    if (self.player1TextField.text.length > 0) {
        player1Name = self.player1TextField.text;
    }
    
    NSString *player2Name = @"Player 2";
    if (self.player2TextField.text.length > 0) {
        player2Name = self.player2TextField.text;
    }
    
    NSNumber *player1Score = [defaults objectForKey:[NSString stringWithFormat:@"%@vvv%@", player1Name, player2Name]];
    NSNumber *player2Score = [defaults objectForKey:[NSString stringWithFormat:@"%@vvv%@", player1Name, player2Name]];
    
    if (player1Score && player2Score) {
        if (!self.winLossLabel.superview) {
            [self.winLossLabel setAlpha:0.0f];
            [self.view addSubview:self.winLossLabel];
            [UIView animateWithDuration:0.35f animations:^{
                [self.winLossLabel setAlpha:1.0f];
            }];
        }
        
        [self.winLossLabel setText:[NSString stringWithFormat:@"%d - %d", [player1Score intValue], [player2Score intValue]]];
    }
    
    else {
        [UIView animateWithDuration:0.35f animations:^{
            [self.winLossLabel setAlpha:0.0f];
        } completion:^(BOOL finished){
            [self.winLossLabel removeFromSuperview];
            [self.winLossLabel setAlpha:1.0f];
        }];
    }
    
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

#pragma mark - Animate Text Field

- (void)animateTextField:(UITextField *)textField {
    float variance = 1.35f;
    if (textField.tag == 0) {
        [UIView animateWithDuration:3.35f delay:1.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            if (kScreenHeight > kScreenWidth || textField.center.y > kScreenHeight * 0.75f) {
                [textField setCenter:CGPointMake(textField.center.x,
                                                 textField.center.y / variance + textField.frame.origin.x/4.0f)];
            }
        } completion:^(BOOL finished) {
            textField.tag = 1;
            [self animateTextField:textField];
        }];
    }
    
    else {
        [UIView animateWithDuration:3.35f delay:1.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            if (kScreenHeight > kScreenWidth) {
                [textField setCenter:CGPointMake(textField.center.x,
                                                 (textField.center.y - textField.frame.origin.x/4.0f) * variance)];
            }
        } completion:^(BOOL finished) {
            textField.tag = 0;
            [self animateTextField:textField];
        }];
    }
}

#pragma mark - Memory Warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
