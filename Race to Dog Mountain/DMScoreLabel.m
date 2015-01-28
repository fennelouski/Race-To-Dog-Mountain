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
    [self addSubview:self.nameLabel];
    [self addSubview:self.scoreLabel];
    
    [self.nameLabel setText:self.name];
    [self.scoreLabel setText:[NSString stringWithFormat:@"%d", self.score]];
    
    float fontSize = 16.0f;
    float longestText = (self.name.length > 3) ? (float)self.name.length : (float)3.0f;
    if (self.frame.size.height/longestText > fontSize) {
        fontSize = self.frame.size.height/longestText;
    }
    
    [self.nameLabel setFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height/2.0f)];
    [self.scoreLabel setFrame:CGRectMake(0.0f, self.frame.size.height/2.0f, self.frame.size.width, self.frame.size.height/2.0f)];
    
    [self.nameLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
    [self.scoreLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
    
    [self addGestureRecognizer:self.tap];
}

- (UILabel *)nameLabel {
    if (!_nameLabel) {
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_nameLabel setTextAlignment:NSTextAlignmentCenter];
        [_nameLabel setTextColor:[UIColor whiteColor]];
        [_nameLabel setText:self.name];
    }
    
    return _nameLabel;
}

- (UILabel *)scoreLabel {
    if (!_scoreLabel) {
        _scoreLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        [_scoreLabel setTextAlignment:NSTextAlignmentCenter];
        [_scoreLabel setTextColor:[UIColor whiteColor]];
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
