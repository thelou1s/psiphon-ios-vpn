/*
 * Copyright (c) 2018, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "PsiCashBalanceView.h"
#import "PsiCashBalanceView.h"
#import "PsiCashClient.h"
#import "PsiCashSpeedBoostMeterView.h"
#import "ReactiveObjC.h"

@interface PsiCashBalanceView ()
@property (atomic, readwrite) PsiCashClientModel *model;
@property (strong, nonatomic) UILabel *balance;
@property (strong, nonatomic) UIImageView *coin;
@end

#pragma mark -

@implementation PsiCashBalanceView {
    NSNumber *prevBalance;
    UIView *containerView;
    UIActivityIndicatorView *activityIndicator;
    BOOL authed;
}

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self setupViews];
        [self addViews];
        [self setupLayoutConstraints];
    }

    return self;
}

-(void)setBounds:(CGRect)bounds{
    [super setFrame:bounds];
    [self setRoundedCornersWithBounds:bounds];
}

- (void)setRoundedCornersWithBounds:(CGRect)bounds {
    UIBezierPath* rounded = [UIBezierPath bezierPathWithRoundedRect:bounds byRoundingCorners:UIRectCornerTopLeft|UIRectCornerTopRight cornerRadii:CGSizeMake(5, 5)];
    CAShapeLayer* shape = [[CAShapeLayer alloc] init];
    [shape setPath:rounded.CGPath];
    self.layer.mask = shape;
}

- (void)setupViews {
    self.clipsToBounds = YES;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:.12];
    self.contentEdgeInsets = UIEdgeInsetsMake(10.0f, 30.0f, 10.0f, 30.0f);

    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];

    // Setup container view
    containerView = [[UIView alloc] init];

    // Setup balance label
    _balance = [[UILabel alloc] init];
    _balance.backgroundColor = [UIColor clearColor];
    _balance.adjustsFontSizeToFitWidth = YES;
    _balance.font = [UIFont boldSystemFontOfSize:20];
    _balance.textAlignment = NSTextAlignmentLeft;
    _balance.textColor = [UIColor whiteColor];
    _balance.userInteractionEnabled = NO;

    // Setup coin graphic
    _coin = [[UIImageView alloc] init];
    _coin.image = [UIImage imageNamed:@"PsiCash_Coin"];
    [_coin.layer setMinificationFilter:kCAFilterTrilinear];
}

- (void)addViews {
    [self addSubview:containerView];
    [self addSubview:_balance];
    [self addSubview:_coin];
    [self addSubview:activityIndicator];
}

- (void)setupLayoutConstraints {
    CGFloat coinSize = 30.f;

    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
    [containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    [containerView.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-10].active = YES;
    [containerView.heightAnchor constraintLessThanOrEqualToAnchor:self.heightAnchor].active = YES;

    _balance.translatesAutoresizingMaskIntoConstraints = NO;
    [_balance.widthAnchor constraintGreaterThanOrEqualToConstant:coinSize].active = YES;
    [_balance.leadingAnchor constraintEqualToAnchor:_coin.trailingAnchor constant:10].active = YES;
    [_balance.trailingAnchor constraintLessThanOrEqualToAnchor:containerView.trailingAnchor].active = YES;
    [_balance.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:2].active = YES;

    _coin.translatesAutoresizingMaskIntoConstraints = NO;
    [_coin.heightAnchor constraintEqualToConstant:coinSize].active = YES;
    [_coin.widthAnchor constraintEqualToConstant:coinSize].active = YES;
    [_coin.centerYAnchor constraintEqualToAnchor:_balance.centerYAnchor].active = YES;
    [_coin.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor].active = YES;
    [_coin.trailingAnchor constraintEqualToAnchor:_balance.leadingAnchor constant:-10].active = YES;

    activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    [activityIndicator.centerXAnchor constraintEqualToAnchor:_coin.centerXAnchor].active = YES;
    [activityIndicator.centerYAnchor constraintEqualToAnchor:_coin.centerYAnchor].active = YES;
}

- (void)animateBalanceChangeFrom:(NSNumber*)previousBalance toNewBalance:(NSNumber*)newBalance {
    __block double currentBalance = previousBalance.doubleValue;
    double chunks = newBalance.doubleValue >= currentBalance ? 1e9 : -1e9;


    NSTimeInterval animationTime = 1;
    NSTimeInterval animationIntervals = animationTime / ((newBalance.doubleValue - currentBalance) / chunks);

    if (animationIntervals < 0.0001) {
        CGFloat minInterval = 0.001;
        chunks = 1e9 * roundf(((newBalance.doubleValue - currentBalance) * minInterval) / (animationTime * 1e9));
        animationIntervals = minInterval;
    }

    [NSTimer scheduledTimerWithTimeInterval:animationIntervals repeats:YES block:^(NSTimer * _Nonnull timer) {
        currentBalance += chunks;
        _balance.text = [PsiCashClientModel formattedBalance:[NSNumber numberWithDouble:currentBalance]];
        BOOL done = FALSE;
        if (chunks >= 0 && currentBalance >= self.model.balance.doubleValue) {
            done = TRUE;
        } else if (chunks < 0 && currentBalance <= self.model.balance.doubleValue) {
            done = TRUE;
        }

        if (done) {
            _balance.text = [PsiCashClientModel formattedBalance:self.model.balance];
            [timer invalidate];
        }
    }];
}

#pragma mark - State Changes

- (void)bindWithModel:(PsiCashClientModel*)clientModel {
    self.model = clientModel;

    if ([self.model hasAuthPackage]) {
        if ([self.model.authPackage hasIndicatorToken]) {
            if (self.model.refreshPending) {
                [activityIndicator startAnimating];
            } else {
                [activityIndicator stopAnimating];
            }
            if (!authed) {
                _balance.text = [PsiCashClientModel formattedBalance:clientModel.balance];
                authed = TRUE;
            } else {
                _balance.text = [PsiCashClientModel formattedBalance:prevBalance];
                [self animateBalanceChangeFrom:prevBalance toNewBalance:clientModel.balance];
            }
            prevBalance = clientModel.balance;
        } else {
            // First launch: the user has no indicator token
            _balance.text = [PsiCashClientModel formattedBalance:[NSNumber numberWithInteger:0]];
        }
    } else {
        // Do nothing
    }
}

@end
