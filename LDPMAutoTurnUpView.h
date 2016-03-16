//
//  LDPMAutoTurnUpView.h
//  PreciousMetals
//
//  Created by wangchao on 3/10/16.
//  Copyright © 2016 NetEase. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, LDPMAutoTurnUpViewType) {
    LDPMAutoTurnUpViewTypeUp,
    LDPMAutoTurnUpViewTypeDown,
};

@protocol LDPMAutoTurnUpViewDelegate;

@interface LDPMAutoTurnUpView : UIView

@property (nonatomic, weak) id<LDPMAutoTurnUpViewDelegate> delegate;
@property (nonatomic, assign) NSInteger timeInterval;
@property (nonatomic, strong, readonly) UIView *currentCustomView;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign) BOOL isTurning;

- (void)startAutoTurn;
- (void)pauseAutoTurn;

@end

@protocol LDPMAutoTurnUpViewDelegate <NSObject>

- (NSInteger)numberOfCustomViewsInAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView;

- (UIView *)customViewWithAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView type:(LDPMAutoTurnUpViewType)type;

- (void)configAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView customView:(UIView *)customView index:(NSInteger)index;

@end