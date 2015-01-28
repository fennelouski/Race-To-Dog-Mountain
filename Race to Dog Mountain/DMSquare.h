//
//  DMSquare.h
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 1/14/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DMSquareDelegate <NSObject>

@required
- (void)squareTouched:(NSObject *)squareTouched;

@end

@interface DMSquare : UIView

@property (nonatomic, strong) NSNumber *squareValue;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property int row, column;
@property (assign) id <DMSquareDelegate> delegate;

@end
