//
//  DMScoreLabel.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMScoreLabel.h"

@implementation DMScoreLabel

- (void)layoutSubviews {
    if (!self.whiteColor) self.whiteColor = [UIColor whiteColor];
    [self addSubview:self.nameLabel];
    [self addSubview:self.scoreLabel];
    
    [self.nameLabel setText:self.name];
    
    if (!self.fontSizeOverwritten) self.fontSize = 16.0f;
    float longestText = (self.name.length > 3) ? (float)self.name.length : (float)3.0f;
    if (!self.fontSizeOverwritten && self.frame.size.height/longestText > self.fontSize) {
        self.fontSize = self.frame.size.height/longestText;
    }
    
    [self.nameLabel setFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height/2.0f)];
    [self.scoreLabel setFrame:CGRectMake(0.0f, self.frame.size.height/2.0f, self.frame.size.width, self.frame.size.height/2.0f)];
    
    [self.nameLabel setFont:[UIFont boldSystemFontOfSize:self.fontSize]];
    [self.scoreLabel setFont:[UIFont boldSystemFontOfSize:self.fontSize]];
    
    [self addGestureRecognizer:self.tap];
}

- (void)updateScore:(int)newScore {
    if (newScore != self.oldScore) {
        self.oldScore = self.score;
        self.score = newScore;
        [self animateScoreChangeFrom:self.oldScore to:newScore current:self.oldScore step:0];
    }
    
    [self layoutSubviews];
}

- (void)animateScoreChangeFrom:(int)from to:(int)to current:(int)current step:(int)step {
    int numberOfSteps = 35;
    
    float stepDistance = (float)step / (float)numberOfSteps;
    stepDistance *= stepDistance;
    
    int incrementAmount = (to - from) * stepDistance;
    
    if (incrementAmount < 1) {
        incrementAmount = 1;
    }
    
    int newCurrent = current + incrementAmount;
    if ((newCurrent >= to || step > numberOfSteps) || (from < self.oldScore || to < self.score)) {
        newCurrent = to;
        [self.scoreLabel setText:[NSString stringWithFormat:@"%d", to]];
        return;
    }
    
    [UIView animateWithDuration:stepDistance animations:^{
        [self.scoreLabel setText:[NSString stringWithFormat:@"%d", newCurrent]];
    } completion:^(BOOL finished){
        [self animateScoreChangeFrom:from to:to current:newCurrent step:step+1];
    }];
}

- (UILabel *)nameLabel {
    if (!_nameLabel) {
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_nameLabel setTextAlignment:NSTextAlignmentCenter];
        [_nameLabel setTextColor:self.whiteColor];
        [_nameLabel setText:self.name];
    }
    
    return _nameLabel;
}

- (UILabel *)scoreLabel {
    if (!_scoreLabel) {
        _scoreLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_scoreLabel setTextAlignment:NSTextAlignmentCenter];
        [_scoreLabel setTextColor:self.whiteColor];
        [_scoreLabel setText:[NSString stringWithFormat:@"%d", self.score]];
    }
    
    return _scoreLabel;
}

- (UITapGestureRecognizer *)tap {
    if (!_tap) {
        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    }
    
    return _tap;
}

- (void)tapped {
    if ([self.delegate respondsToSelector:@selector(scoreLabelTapped:)]) {
        [self.delegate scoreLabelTapped:self.player];
    }
    
    else {
        NSLog(@"Delegate not assigned for score label");
    }
}

@end
