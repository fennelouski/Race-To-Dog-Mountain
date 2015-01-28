//
//  DMSquare.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMSquare.h"
#import "UIColor+AppColors.h"

@implementation DMSquare

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self.layer setBorderColor:[UIColor randomPastelColor].CGColor];
        [self.layer setBorderWidth:0.0f];
        [self addGestureRecognizer:self.tap];
        [self addSubview:self.label];
    }
    
    return self;
}

- (void)layoutSubviews {
    if (self.label.superview && self.squareValue && [self.squareValue intValue] > 0) {
        [self.label setText:[NSString stringWithFormat:@"%d", [self.squareValue intValue]]];
    }
    
    else if (self.label.superview) {
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionAutoreverse animations:^{
            [self setBackgroundColor:[UIColor whiteColor]];
        }completion:^(BOOL finished){
            [UIView animateWithDuration:0.2f animations:^{
                [self setBackgroundColor:[UIColor clearColor]];
                [self.label setAlpha:0.0f];
            }completion:^(BOOL finished){
                [self.label removeFromSuperview];
            }];
        }];
    }
}

- (UITapGestureRecognizer *)tap {
    if (!_tap) {
        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    }
    
    return _tap;
}

- (UILabel *)label {
    if (!_label) {
        _label = [[UILabel alloc] initWithFrame:self.bounds];
        
        float fontSize = 16.0f;
        if (self.frame.size.height/2.5f > fontSize) {
            fontSize = self.frame.size.height/2.5f;
        }
        
        [_label setFont:[UIFont boldSystemFontOfSize:fontSize]];
        [_label setTextAlignment:NSTextAlignmentCenter];
        [_label setTextColor:[UIColor lightTextColor]];
    }
    
    return _label;
}

- (void)tapped {
    if ([self.delegate respondsToSelector:@selector(squareTouched:)]) {
        if ([self.squareValue intValue] > 0) {
            [self.delegate squareTouched:self];
        }
        
        else {
            NSLog(@"the square doesn't have enough value to be selected!");
        }
    }
    
    else {
        NSLog(@"A selected square does not have its delegate set!");
    }
}

@end