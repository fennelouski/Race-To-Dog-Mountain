//
//  DMMainScreenBackgroundView.m
//  Race to Dog Mountain
//
//  Created by Developer Nathan on 2/24/15.
//  Copyright (c) 2015 Nathan Fennel. All rights reserved.
//

#import "DMMainScreenBackgroundView.h"
#import "UIColor+AppColors.h"

#define kScreenWidth [UIScreen mainScreen].bounds.size.width
#define kStatusBarHeight (([[UIApplication sharedApplication] statusBarFrame].size.height == 20.0f) ? 20.0f : (([[UIApplication sharedApplication] statusBarFrame].size.height == 40.0f) ? 20.0f : 0.0f))
#define kScreenHeight (([[UIApplication sharedApplication] statusBarFrame].size.height > 20.0f) ? [UIScreen mainScreen].bounds.size.height - 20.0f : [UIScreen mainScreen].bounds.size.height)
#define FONT_SCALE 30.0f
#define SHORTER_SIDE ((kScreenWidth < kScreenHeight) ? kScreenWidth : kScreenHeight)
#define LONGER_SIDE (((kScreenWidth > kScreenHeight) ? kScreenWidth : kScreenHeight) + 20.0f)

@implementation DMMainScreenBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setBackgroundColor:[UIColor black]];
        //Create a layer that holds your background image and add it as sublayer of your self.layer
        CALayer *layer = [CALayer layer];
        layer.frame = self.layer.frame;
        layer.contents = (id)[UIImage imageNamed:@"background.png"].CGImage;
        [self.layer addSublayer:layer];
        
        //Create your CAGradientLayer
        CAGradientLayer *gradientOverlay = [self lightBlueGradient];
        
        gradientOverlay.frame = CGRectMake(0.0f, 0.0f, LONGER_SIDE + 20.0f, LONGER_SIDE + 20.0f);
        //set its opacity from 0 ~ 1
        gradientOverlay.opacity = 0.6f;
        //add it as sublayer of self.layer (it will be over the layer with the background image
        [self.layer addSublayer:gradientOverlay];
        
        self.starColor = [UIColor yellow];
        
        [self addSubview:self.mountainView];
        [self addSubview:self.mountainView2];
        [self addSubview:self.mountainView3];
    }
    
    return self;
}

- (void)animateMountain:(UIView *)mountainView {
    if (mountainView.frame.origin.x + mountainView.frame.size.width > kScreenWidth * 2.0f) {
        float animationDuration = arc4random()%25 + 20.0f;
        if ([mountainView isEqual:self.mountainView]) {
            animationDuration += 95.0f;
        }
        
        else if ([mountainView isEqual:self.mountainView2]) {
            animationDuration += 45.0f;
        }
        
        else if ([mountainView isEqual:self.mountainView3]) {
            animationDuration += 15.0f;
        }

        [UIView animateWithDuration:animationDuration delay:0.0f options:UIViewAnimationOptionCurveLinear animations:^{
            [mountainView setCenter:CGPointMake(mountainView.center.x - mountainView.frame.size.width - LONGER_SIDE, mountainView.center.y)];
        } completion:^(BOOL finished) {
            [self animateMountain:mountainView];
        }];
    }
    
    else {
        [mountainView setFrame:CGRectMake(LONGER_SIDE, 0.0f, mountainView.frame.size.width, mountainView.frame.size.height)];
        [self animateMountain:mountainView];
    }
}

- (UIImageView *)mountainView {
    if (!_mountainView) {
        _mountainView = [self mountainViewImageView:0];
        [self animateMountain:_mountainView];
    }
    
    return _mountainView;
}

- (UIImageView *)mountainView2 {
    if (!_mountainView2) {
        _mountainView2 = [self mountainViewImageView:1];
        [self performSelector:@selector(animateMountain:) withObject:_mountainView2 afterDelay:0.3f];
    }
    
    return _mountainView2;
}

- (UIImageView *)mountainView3 {
    if (!_mountainView3) {
        _mountainView3 = [self mountainViewImageView:2];
        [self performSelector:@selector(animateMountain:) withObject:_mountainView3 afterDelay:0.3f];
    }
    
    return _mountainView3;
}

- (CAGradientLayer *)lightBlueGradient {
    NSArray *colors = [NSArray arrayWithObjects:(id)[UIColor darkSkyBlue].CGColor, [UIColor skyBlue].CGColor, nil];
    
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComps = [gregorianCalendar components:(NSCalendarUnitHour) fromDate: [NSDate date]];
    NSInteger hour = [dateComps hour];
    
    if (hour < 6 || hour > 22) {
        colors = @[(id)[UIColor colorWithRed:0.03f green:0.0f blue:0.53f alpha:1.0f].CGColor, (id)[UIColor colorWithRed:0.0f green:0.0f blue:0.3f alpha:1.0f].CGColor];
    }
    
    NSNumber *stopOne = [NSNumber numberWithFloat:0.0f];
    NSNumber *stopTwo = [NSNumber numberWithFloat:0.5f];
    
    NSArray *locations = [NSArray arrayWithObjects:stopOne, stopTwo, nil];
    
    CAGradientLayer *headerLayer = [CAGradientLayer layer];
    headerLayer.colors = colors;
    headerLayer.locations = locations;
    
    return headerLayer;
}

- (UIImageView *)starView {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(LONGER_SIDE, LONGER_SIDE), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    float verticalScale = 1234.0f/LONGER_SIDE;
    float horizontalScale = 1234.0f/LONGER_SIDE;
    
    
    
    //// Star drawing
    UIBezierPath *star = [UIBezierPath bezierPath];
    [star moveToPoint:CGPointMake(244.011f/horizontalScale, -8.102f/verticalScale)];
    [star addLineToPoint:CGPointMake(238.267f/horizontalScale, 11.886f/verticalScale)];
    [star addLineToPoint:CGPointMake(216.798f/horizontalScale, 10.982f/verticalScale)];
    [star addLineToPoint:CGPointMake(234.718f/horizontalScale, 22.431f/verticalScale)];
    [star addLineToPoint:CGPointMake(227.193f/horizontalScale, 41.86f/verticalScale)];
    [star addLineToPoint:CGPointMake(244.011f/horizontalScale, 28.948f/verticalScale)];
    [star addLineToPoint:CGPointMake(260.829f/horizontalScale, 41.86f/verticalScale)];
    [star addLineToPoint:CGPointMake(253.304f/horizontalScale, 22.431f/verticalScale)];
    [star addLineToPoint:CGPointMake(271.223f/horizontalScale, 10.982f/verticalScale)];
    [star addLineToPoint:CGPointMake(249.755f/horizontalScale, 11.886f/verticalScale)];
    [star closePath];
    
    
    //Star color fill
    [self.starColor setFill];
    [star fill];
    
    //// Star2 drawing
    UIBezierPath *star2 = [UIBezierPath bezierPath];
    [star2 moveToPoint:CGPointMake(276.34f/horizontalScale, 24.008f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(261.744f/horizontalScale, 75.416f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(207.184f/horizontalScale, 73.091f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(252.723f/horizontalScale, 102.538f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(233.599f/horizontalScale, 152.509f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(276.34f/horizontalScale, 119.301f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(319.081f/horizontalScale, 152.509f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(299.958f/horizontalScale, 102.538f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(345.497f/horizontalScale, 73.091f/verticalScale)];
    [star2 addLineToPoint:CGPointMake(290.937f/horizontalScale, 75.416f/verticalScale)];
    [star2 closePath];
    
    
    //Star2 color fill
    [self.starColor setFill];
    [star2 fill];
    
    //// Star3 drawing
    UIBezierPath *star3 = [UIBezierPath bezierPath];
    [star3 moveToPoint:CGPointMake(189.369f/horizontalScale, 141.817f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(183.625f/horizontalScale, 161.805f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(162.156f/horizontalScale, 160.901f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(180.076f/horizontalScale, 172.35f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(172.551f/horizontalScale, 191.779f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(189.369f/horizontalScale, 178.867f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(206.187f/horizontalScale, 191.779f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(198.662f/horizontalScale, 172.35f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(216.581f/horizontalScale, 160.901f/verticalScale)];
    [star3 addLineToPoint:CGPointMake(195.112f/horizontalScale, 161.805f/verticalScale)];
    [star3 closePath];
    
    
    //Star3 color fill
    [self.starColor setFill];
    [star3 fill];
    
    //// Star4 drawing
    UIBezierPath *star4 = [UIBezierPath bezierPath];
    [star4 moveToPoint:CGPointMake(122.744f/horizontalScale, 102.547f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(117.f/horizontalScale, 122.535f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(95.531f/horizontalScale, 121.631f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(113.45f/horizontalScale, 133.08f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(105.925f/horizontalScale, 152.509f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(122.744f/horizontalScale, 139.598f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(139.562f/horizontalScale, 152.509f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(132.037f/horizontalScale, 133.08f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(149.956f/horizontalScale, 121.631f/verticalScale)];
    [star4 addLineToPoint:CGPointMake(128.487f/horizontalScale, 122.535f/verticalScale)];
    [star4 closePath];
    
    
    //Star4 color fill
    [self.starColor setFill];
    [star4 fill];
    
    //// Star5 drawing
    UIBezierPath *star5 = [UIBezierPath bezierPath];
    [star5 moveToPoint:CGPointMake(280.606f/horizontalScale, 166.798f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(274.862f/horizontalScale, 186.786f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(253.393f/horizontalScale, 185.882f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(271.313f/horizontalScale, 197.331f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(263.788f/horizontalScale, 216.76f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(280.606f/horizontalScale, 203.848f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(297.424f/horizontalScale, 216.76f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(289.899f/horizontalScale, 197.331f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(307.818f/horizontalScale, 185.882f/verticalScale)];
    [star5 addLineToPoint:CGPointMake(286.349f/horizontalScale, 186.786f/verticalScale)];
    [star5 closePath];
    
    
    //Star5 color fill
    [self.starColor setFill];
    [star5 fill];
    
    //// Star6 drawing
    UIBezierPath *star6 = [UIBezierPath bezierPath];
    [star6 moveToPoint:CGPointMake(362.484f/horizontalScale, 109.922f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(355.887f/horizontalScale, 132.676f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(331.23f/horizontalScale, 131.647f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(351.811f/horizontalScale, 144.68f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(343.168f/horizontalScale, 166.798f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(362.484f/horizontalScale, 152.099f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(381.8f/horizontalScale, 166.798f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(373.158f/horizontalScale, 144.68f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(393.738f/horizontalScale, 131.647f/verticalScale)];
    [star6 addLineToPoint:CGPointMake(369.081f/horizontalScale, 132.676f/verticalScale)];
    [star6 closePath];
    
    
    //Star6 color fill
    [self.starColor setFill];
    [star6 fill];
    
    //// Star7 drawing
    UIBezierPath *star7 = [UIBezierPath bezierPath];
    [star7 moveToPoint:CGPointMake(407.554f/horizontalScale, 57.883f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(400.958f/horizontalScale, 80.636f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(376.3f/horizontalScale, 79.607f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(396.881f/horizontalScale, 92.641f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(388.238f/horizontalScale, 114.759f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(407.554f/horizontalScale, 100.06f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(426.87f/horizontalScale, 114.759f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(418.228f/horizontalScale, 92.641f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(438.809f/horizontalScale, 79.607f/verticalScale)];
    [star7 addLineToPoint:CGPointMake(414.151f/horizontalScale, 80.636f/verticalScale)];
    [star7 closePath];
    
    
    //Star7 color fill
    [self.starColor setFill];
    [star7 fill];
    
    //// Star8 drawing
    UIBezierPath *star8 = [UIBezierPath bezierPath];
    [star8 moveToPoint:CGPointMake(583.247f/horizontalScale, 152.553f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(576.65f/horizontalScale, 175.307f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(551.992f/horizontalScale, 174.278f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(572.573f/horizontalScale, 187.311f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(563.931f/horizontalScale, 209.429f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(583.247f/horizontalScale, 194.73f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(602.563f/horizontalScale, 209.429f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(593.92f/horizontalScale, 187.311f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(614.501f/horizontalScale, 174.278f/verticalScale)];
    [star8 addLineToPoint:CGPointMake(589.843f/horizontalScale, 175.307f/verticalScale)];
    [star8 closePath];
    
    
    //Star8 color fill
    [self.starColor setFill];
    [star8 fill];
    
    //// Star9 drawing
    UIBezierPath *star9 = [UIBezierPath bezierPath];
    [star9 moveToPoint:CGPointMake(130.326f/horizontalScale, 19.956f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(122.982f/horizontalScale, 45.344f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(95.531f/horizontalScale, 44.195f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(118.443f/horizontalScale, 58.738f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(108.822f/horizontalScale, 83.416f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(130.326f/horizontalScale, 67.016f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(151.831f/horizontalScale, 83.416f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(142.209f/horizontalScale, 58.738f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(165.122f/horizontalScale, 44.195f/verticalScale)];
    [star9 addLineToPoint:CGPointMake(137.67f/horizontalScale, 45.344f/verticalScale)];
    [star9 closePath];
    
    
    //Star9 color fill
    [self.starColor setFill];
    [star9 fill];
    
    //// Star10 drawing
    UIBezierPath *star10 = [UIBezierPath bezierPath];
    [star10 moveToPoint:CGPointMake(184.67f/horizontalScale, 41.86f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(179.918f/horizontalScale, 57.567f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(162.156f/horizontalScale, 56.857f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(176.981f/horizontalScale, 65.854f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(170.756f/horizontalScale, 81.122f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(184.67f/horizontalScale, 70.976f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(198.585f/horizontalScale, 81.122f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(192.359f/horizontalScale, 65.854f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(207.184f/horizontalScale, 56.857f/verticalScale)];
    [star10 addLineToPoint:CGPointMake(189.422f/horizontalScale, 57.567f/verticalScale)];
    [star10 closePath];
    
    
    //Star10 color fill
    [self.starColor setFill];
    [star10 fill];
    
    //// Star11 drawing
    UIBezierPath *star11 = [UIBezierPath bezierPath];
    [star11 moveToPoint:CGPointMake(175.04f/horizontalScale, 19.213f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(172.321f/horizontalScale, 28.273f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(162.156f/horizontalScale, 27.863f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(170.64f/horizontalScale, 33.053f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(167.077f/horizontalScale, 41.86f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(175.04f/horizontalScale, 36.007f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(183.003f/horizontalScale, 41.86f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(179.44f/horizontalScale, 33.053f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(187.924f/horizontalScale, 27.863f/verticalScale)];
    [star11 addLineToPoint:CGPointMake(177.759f/horizontalScale, 28.273f/verticalScale)];
    [star11 closePath];
    
    
    //Star11 color fill
    [self.starColor setFill];
    [star11 fill];
    
    //// Star12 drawing
    UIBezierPath *star12 = [UIBezierPath bezierPath];
    [star12 moveToPoint:CGPointMake(296.85f/horizontalScale, 19.213f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(294.767f/horizontalScale, 26.672f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(286.978f/horizontalScale, 26.334f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(293.479f/horizontalScale, 30.607f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(290.749f/horizontalScale, 37.857f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(296.85f/horizontalScale, 33.039f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(302.951f/horizontalScale, 37.857f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(300.221f/horizontalScale, 30.607f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(306.722f/horizontalScale, 26.334f/verticalScale)];
    [star12 addLineToPoint:CGPointMake(298.934f/horizontalScale, 26.672f/verticalScale)];
    [star12 closePath];
    
    
    //Star12 color fill
    [self.starColor setFill];
    [star12 fill];
    
    //// Star13 drawing
    UIBezierPath *star13 = [UIBezierPath bezierPath];
    [star13 moveToPoint:CGPointMake(524.78f/horizontalScale, 59.51f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(519.036f/horizontalScale, 79.497f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(497.567f/horizontalScale, 78.593f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(515.487f/horizontalScale, 90.042f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(507.962f/horizontalScale, 109.472f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(524.78f/horizontalScale, 96.56f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(541.598f/horizontalScale, 109.472f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(534.073f/horizontalScale, 90.042f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(551.992f/horizontalScale, 78.593f/verticalScale)];
    [star13 addLineToPoint:CGPointMake(530.523f/horizontalScale, 79.497f/verticalScale)];
    [star13 closePath];
    
    
    //Star13 color fill
    [self.starColor setFill];
    [star13 fill];
    
    //// Star14 drawing
    UIBezierPath *star14 = [UIBezierPath bezierPath];
    [star14 moveToPoint:CGPointMake(470.138f/horizontalScale, 209.429f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(464.394f/horizontalScale, 229.416f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(442.925f/horizontalScale, 228.512f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(460.844f/horizontalScale, 239.962f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(453.319f/horizontalScale, 259.391f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(470.138f/horizontalScale, 246.479f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(486.956f/horizontalScale, 259.391f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(479.431f/horizontalScale, 239.962f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(497.35f/horizontalScale, 228.512f/verticalScale)];
    [star14 addLineToPoint:CGPointMake(475.881f/horizontalScale, 229.416f/verticalScale)];
    [star14 closePath];
    
    
    //Star14 color fill
    [self.starColor setFill];
    [star14 fill];
    
    //// Star15 drawing
    UIBezierPath *star15 = [UIBezierPath bezierPath];
    [star15 moveToPoint:CGPointMake(403.512f/horizontalScale, 170.159f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(397.769f/horizontalScale, 190.147f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(376.3f/horizontalScale, 189.243f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(394.219f/horizontalScale, 200.692f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(386.694f/horizontalScale, 220.121f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(403.512f/horizontalScale, 207.209f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(420.331f/horizontalScale, 220.121f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(412.806f/horizontalScale, 200.692f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(430.725f/horizontalScale, 189.243f/verticalScale)];
    [star15 addLineToPoint:CGPointMake(409.256f/horizontalScale, 190.147f/verticalScale)];
    [star15 closePath];
    
    
    //Star15 color fill
    [self.starColor setFill];
    [star15 fill];
    
    //// Star16 drawing
    UIBezierPath *star16 = [UIBezierPath bezierPath];
    [star16 moveToPoint:CGPointMake(465.439f/horizontalScale, 109.472f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(460.687f/horizontalScale, 125.179f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(442.925f/horizontalScale, 124.469f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(457.75f/horizontalScale, 133.466f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(451.525f/horizontalScale, 148.734f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(465.439f/horizontalScale, 138.587f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(479.353f/horizontalScale, 148.734f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(473.128f/horizontalScale, 133.466f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(487.953f/horizontalScale, 124.469f/verticalScale)];
    [star16 addLineToPoint:CGPointMake(470.191f/horizontalScale, 125.179f/verticalScale)];
    [star16 closePath];
    
    
    //Star16 color fill
    [self.starColor setFill];
    [star16 fill];
    
    //// Star17 drawing
    UIBezierPath *star17 = [UIBezierPath bezierPath];
    [star17 moveToPoint:CGPointMake(478.323f/horizontalScale, 84.286f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(475.604f/horizontalScale, 93.346f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(465.439f/horizontalScale, 92.936f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(473.923f/horizontalScale, 98.126f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(470.36f/horizontalScale, 106.932f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(478.323f/horizontalScale, 101.08f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(486.286f/horizontalScale, 106.932f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(482.723f/horizontalScale, 98.126f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(491.207f/horizontalScale, 92.936f/verticalScale)];
    [star17 addLineToPoint:CGPointMake(481.042f/horizontalScale, 93.346f/verticalScale)];
    [star17 closePath];
    
    
    //Star17 color fill
    [self.starColor setFill];
    [star17 fill];
    
    //// Star18 drawing
    UIBezierPath *star18 = [UIBezierPath bezierPath];
    [star18 moveToPoint:CGPointMake(600.133f/horizontalScale, 84.286f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(598.049f/horizontalScale, 91.744f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(590.261f/horizontalScale, 91.407f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(596.762f/horizontalScale, 95.679f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(594.032f/horizontalScale, 102.929f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(600.133f/horizontalScale, 98.111f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(606.234f/horizontalScale, 102.929f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(603.504f/horizontalScale, 95.679f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(610.004f/horizontalScale, 91.407f/verticalScale)];
    [star18 addLineToPoint:CGPointMake(602.216f/horizontalScale, 91.744f/verticalScale)];
    [star18 closePath];
    
    
    //Star18 color fill
    [self.starColor setFill];
    [star18 fill];
    
    //// Star19 drawing
    UIBezierPath *star19 = [UIBezierPath bezierPath];
    [star19 moveToPoint:CGPointMake(344.114f/horizontalScale, 172.494f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(341.394f/horizontalScale, 181.554f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(331.23f/horizontalScale, 181.144f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(339.714f/horizontalScale, 186.333f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(336.151f/horizontalScale, 195.14f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(344.114f/horizontalScale, 189.288f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(352.076f/horizontalScale, 195.14f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(348.514f/horizontalScale, 186.333f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(356.997f/horizontalScale, 181.144f/verticalScale)];
    [star19 addLineToPoint:CGPointMake(346.833f/horizontalScale, 181.554f/verticalScale)];
    [star19 closePath];
    
    
    //Star19 color fill
    [self.starColor setFill];
    [star19 fill];
    
    //// Star20 drawing
    UIBezierPath *star20 = [UIBezierPath bezierPath];
    [star20 moveToPoint:CGPointMake(465.924f/horizontalScale, 172.494f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(463.84f/horizontalScale, 179.952f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(456.052f/horizontalScale, 179.615f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(462.552f/horizontalScale, 183.887f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(459.823f/horizontalScale, 191.137f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(465.924f/horizontalScale, 186.319f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(472.025f/horizontalScale, 191.137f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(469.295f/horizontalScale, 183.887f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(475.795f/horizontalScale, 179.615f/verticalScale)];
    [star20 addLineToPoint:CGPointMake(468.007f/horizontalScale, 179.952f/verticalScale)];
    [star20 closePath];
    
    
    //Star20 color fill
    [self.starColor setFill];
    [star20 fill];
    
    CGContextRestoreGState(ctx);
    UIImageView *starView = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
    
    return starView;
}

- (UIImageView *)mountainViewImageView:(int)mountainNumber {
    UIColor *fillColor = [UIColor rocketMetallic];
    
    
    float verticalScale = 2050.0f/LONGER_SIDE;
    float horizontalScale = 1.0f;

    switch (mountainNumber) {
        case 0:
            verticalScale = 2050.0f/(LONGER_SIDE - 100.0f);
            break;
            
        case 1:
            fillColor = [UIColor redBrown];
            verticalScale = 2050.0f/(LONGER_SIDE + 10.0f);
            break;
            
        case 2:
            fillColor = [UIColor brownTraditional];
            verticalScale = 2050.0f/(LONGER_SIDE + 200.0f);
            break;
            
        default:
            break;
    }
    
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8000.0f, LONGER_SIDE), NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    
    //// Path drawing
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(-41.563/horizontalScale/horizontalScale, LONGER_SIDE)];
    [path addCurveToPoint:CGPointMake(-35.448/horizontalScale, LONGER_SIDE) controlPoint1:CGPointMake(-40.034/horizontalScale, 1313.788/verticalScale) controlPoint2:CGPointMake(-36.977/horizontalScale, 1311.91/verticalScale)];
    [path addCurveToPoint:CGPointMake(177.266/horizontalScale, 1180.283/verticalScale) controlPoint1:CGPointMake(17.73/horizontalScale, 1278.299/verticalScale) controlPoint2:CGPointMake(124.087/horizontalScale, 1212.955/verticalScale)];
    [path addLineToPoint:CGPointMake(258.555/horizontalScale, 1250.631/verticalScale)];
    [path addLineToPoint:CGPointMake(520.859/horizontalScale, 1063.962/verticalScale)];
    [path addLineToPoint:CGPointMake(624.219/horizontalScale, 1142.52/verticalScale)];
    [path addLineToPoint:CGPointMake(995.508/horizontalScale, 889.646/verticalScale)];
    [path addLineToPoint:CGPointMake(1212.695/horizontalScale, 1020.392/verticalScale)];
    [path addLineToPoint:CGPointMake(1344.258/horizontalScale, 959.106/verticalScale)];
    [path addLineToPoint:CGPointMake(1558.789/horizontalScale, 1167.634/verticalScale)];
    [path addLineToPoint:CGPointMake(1665.664/horizontalScale, 1105.127/verticalScale)];
    [path addLineToPoint:CGPointMake(1847.656/horizontalScale, 938.579/verticalScale)];
    [path addLineToPoint:CGPointMake(1985.352/horizontalScale, 1065.663/verticalScale)];
    [path addLineToPoint:CGPointMake(2189.453/horizontalScale, 951.746/verticalScale)];
    [path addLineToPoint:CGPointMake(2422.305/horizontalScale, 748.988/verticalScale)];
    [path addLineToPoint:CGPointMake(2653.359/horizontalScale, 670.837/verticalScale)];
    [path addLineToPoint:CGPointMake(2814.961/horizontalScale, 725.983/verticalScale)];
    [path addLineToPoint:CGPointMake(3102.969/horizontalScale, 923.008/verticalScale)];
    [path addLineToPoint:CGPointMake(3408.242/horizontalScale, 942.759/verticalScale)];
    [path addLineToPoint:CGPointMake(3612.773/horizontalScale, 844.893/verticalScale)];
    [path addLineToPoint:CGPointMake(3882.461/horizontalScale, 652.418/verticalScale)];
    [path addLineToPoint:CGPointMake(4057.969/horizontalScale, 514.682/verticalScale)];
    [path addLineToPoint:CGPointMake(4245.117/horizontalScale, 590.318/verticalScale)];
    [path addLineToPoint:CGPointMake(4598.633/horizontalScale, 509.688/verticalScale)];
    [path addLineToPoint:CGPointMake(4714.609/horizontalScale, 555.329/verticalScale)];
    [path addLineToPoint:CGPointMake(4950/horizontalScale, 704.531/verticalScale)];
    [path addLineToPoint:CGPointMake(5213.594/horizontalScale, 604.188/verticalScale)];
    [path addLineToPoint:CGPointMake(5450.234/horizontalScale, 741.924/verticalScale)];
    [path addLineToPoint:CGPointMake(5684.766/horizontalScale, 630.485/verticalScale)];
    [path addLineToPoint:CGPointMake(5882.344/horizontalScale, 768.221/verticalScale)];
    [path addLineToPoint:CGPointMake(6090.781/horizontalScale, 715.997/verticalScale)];
    [path addLineToPoint:CGPointMake(6321.016/horizontalScale, 993.984/verticalScale)];
    [path addLineToPoint:CGPointMake(6476.484/horizontalScale, 925.338/verticalScale)];
    [path addLineToPoint:CGPointMake(6615.039/horizontalScale, 991.099/verticalScale)];
    [path addLineToPoint:CGPointMake(6847.344/horizontalScale, 790.45/verticalScale)];
    [path addLineToPoint:CGPointMake(7017.148/horizontalScale, 862.832/verticalScale)];
    [path addLineToPoint:CGPointMake(7188.75/horizontalScale, 1046.209/verticalScale)];
    [path addLineToPoint:CGPointMake(7377.266/horizontalScale, 948.75/verticalScale)];
    [path addLineToPoint:CGPointMake(7543.164/horizontalScale, 1177.805/verticalScale)];
    [path addLineToPoint:CGPointMake(7711.719/horizontalScale, 1063.481/verticalScale)];
    [path addLineToPoint:CGPointMake(7825.508/horizontalScale, 1223.853/verticalScale)];
    [path addLineToPoint:CGPointMake(8099.609/horizontalScale, LONGER_SIDE)];
    [path addLineToPoint:CGPointMake(-273.555/horizontalScale, 2056.114/verticalScale)];
    [path addLineToPoint:CGPointMake(-269.648/horizontalScale, 1202.105/verticalScale)];
    [path addLineToPoint:CGPointMake(-41.563/horizontalScale, 1314.728/verticalScale)];
    
    
    [fillColor setFill];
    
    [path fill];
    
    
    
    
    CGContextRestoreGState(ctx);
    UIImageView *mountainView = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
    
    return mountainView;
}

@end
