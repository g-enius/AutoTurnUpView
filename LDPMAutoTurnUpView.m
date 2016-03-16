//
//  LDPMAutoTurnUpView.m
//  PreciousMetals
//
//  Created by wangchao on 3/10/16.
//  Copyright © 2016 NetEase. All rights reserved.
//

#import "LDPMAutoTurnUpView.h"


@interface LDPMAutoTurnUpView () <UIScrollViewDelegate>

@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) UIView *nextCustomView;
@property (assign, nonatomic) NSInteger numberOfCustomView;
@property (nonatomic, strong) NSTimer *animationTimer;
@property (nonatomic, strong, readwrite) UIView *currentCustomView;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@end

@implementation LDPMAutoTurnUpView

- (instancetype)initWithFrame:(CGRect)frame
{   //外部用的 autolayout 所以此处 frame = CGRectZero
    if (self = [super initWithFrame:frame]) {
        _scrollView = [[UIScrollView alloc]initWithFrame:self.bounds];
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrollView.delegate = self;
        _scrollView.backgroundColor = [UIColor colorWithRGB:0x0a223d];
        _isTurning = NO;
        [self addSubview:_scrollView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.currentCustomView.frame = self.bounds;
    CGRect bottomFrame = self.bounds;
    bottomFrame.origin.y += CGRectGetHeight(self.bounds);
    self.nextCustomView.frame = bottomFrame;
}

#pragma mark - Actions

- (void)startAutoTurn
{
    if (self.isTurning || self.timeInterval < FLT_MIN || !self.delegate || ![self.delegate respondsToSelector:@selector(numberOfCustomViewsInAutoTurnUpView:)] || ![self.delegate respondsToSelector:@selector(customViewWithAutoTurnUpView:type:)]) {
        return;
    }
    
    self.numberOfCustomView = [self.delegate numberOfCustomViewsInAutoTurnUpView:self];
    if (self.numberOfCustomView < 1) {
        return;
    }
    
    if (!self.currentCustomView || !self.nextCustomView) {
        self.currentCustomView = [self.delegate customViewWithAutoTurnUpView:self type:LDPMAutoTurnUpViewTypeUp];
        self.nextCustomView = [self.delegate customViewWithAutoTurnUpView:self type:LDPMAutoTurnUpViewTypeDown];
        //以下2句不写显示正确，但是会有约束警告
        self.currentCustomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.nextCustomView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.scrollView addSubview:self.currentCustomView];
        [self.scrollView addSubview:self.nextCustomView];
        //不赋初始值会报警告
        self.currentCustomView.frame = self.bounds;
        CGRect bottomFrame = self.bounds;
        bottomFrame.origin.y += CGRectGetHeight(self.bounds);
        self.nextCustomView.frame = bottomFrame;
    }
    
    if (self.numberOfCustomView > 1) {
        self.isTurning = YES;
        if (![self.animationTimer isValid]) {
            self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeInterval target:self selector:@selector(animationTimerAction:) userInfo:nil repeats:YES];
        } else {
            [self.animationTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:self.timeInterval]];
        }
    }
    
    [self configContentCustomViews];
}

- (void)pauseAutoTurn
{
    if ([self.animationTimer isValid]) {
        self.isTurning = NO;
        [self.animationTimer setFireDate:[NSDate distantFuture]];
    }
}

- (void)animationTimerAction:(NSTimer *)timer
{
    CGPoint newOffset = CGPointMake(0, CGRectGetHeight(self.scrollView.frame));
    [self.scrollView setContentOffset:newOffset animated:YES];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat contentOffsetY = scrollView.contentOffset.y;
    if (contentOffsetY >= CGRectGetHeight(scrollView.frame)) {
        self.currentIndex = [self getValidIndexWithIndex:self.currentIndex + 1];
        [self configContentCustomViews];
    }
}

#pragma mark - Content config

- (void)configContentCustomViews
{
    if (self.numberOfCustomView < 1) {
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(configAutoTurnUpView:customView:index:)]) {
        [self.delegate configAutoTurnUpView:self customView:self.currentCustomView index:self.currentIndex];
        if (self.numberOfCustomView > 1) {
            NSInteger nextIndex = [self getValidIndexWithIndex:self.currentIndex + 1];
            [self.delegate configAutoTurnUpView:self customView:self.nextCustomView index:nextIndex];
            [self.scrollView setContentOffset:CGPointZero animated:NO];
        }
    }
}

- (NSInteger)getValidIndexWithIndex:(NSInteger)index
{
    if (self.numberOfCustomView == 0) {
        return 0;
    }
    return (index + self.numberOfCustomView) % self.numberOfCustomView;
}

@end
