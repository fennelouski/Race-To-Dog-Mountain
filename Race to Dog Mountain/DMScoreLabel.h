//
//  DMScoreLabel.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DMScoreLabelDelegate <NSObject>

@optional
- (void)scoreLabelTapped:(int)player;

@end

@interface DMScoreLabel : UIView

@property (nonatomic, strong) NSString *name;
@property int score;
@property (nonatomic, strong) UILabel *nameLabel, *scoreLabel;
@property int player;
@property (assign) id <DMScoreLabelDelegate> delegate;
@property (nonatomic, strong) UITapGestureRecognizer *tap;

@end
