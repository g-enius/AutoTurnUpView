//
//  LDPMLiveRoomDetailViewController.m
//  PreciousMetals
//
//  Created by LiuLiming on 15/7/29.
//  Copyright (c) 2015年 NetEase. All rights reserved.
//

#import "LDPMLiveRoomDetailViewController.h"
#import "LDPMLiveRoomListStore.h"
#import "LDPMLiveRoom.h"
#import "LDPMLiveDetailStore.h"
#import "LDPMLiveDetailTableViewHeader.h"
#import "LDPMLiveDetailStrategyCell.h"
#import "LDPMLiveDetailNews.h"
#import "LDPMLiveDetailStrategy.h"
#import "NPMMarketInfoService.h"
#import "LDPMLiveRoomMarketInfoView.h"
#import <MSWeakTimer/MSWeakTimer.h>
#import "MJRefresh.h"
#import "LDPMLiveNoDataCell.h"
#import "LDPMLiveQAViewController.h"
#import "NPMUIFactory.h"
#import "LDNetworkService.h"
#import "LDPMLiveNoConnectionView.h"
#import "NPMProduct.h"
#import "NPMProductViewController.h"
#import "LDPMLiveLoadingCell.h"
#import "LDPMLiveLoadMoreView.h"
#import <JLRoutes/JLRoutes.h>
#import "LDPMUserEvent.h"
#import "UIAlertView+MKBlockAdditions.h"
#import "LDPMLiveDetailNewsWithImageCell.h"
#import "LDPMLiveDetailQaCell.h"
#import "LDPMLiveDetailQa.h"
#import "LDPMLiveDetailSectionHeader.h"
#import "LDPMLiveDetailNewsImage.h"
#import "LDPMLiveDetailObject.h"
#import "LDCPCirclePhotoZoom.h"
#import "LDCPCirclePhoto.h"
#import "LDPMLiveService.h"
#import "LDPMTableViewHeader.h"
#import "LDPMTableViewFooter.h"
#import "ECLaunch.h"
#import "LDPMErrorCell.h"
#import "UITableViewCell+LDConvenienceCategory.h"
#import "CBAutoScrollLabel.h"
#import "UIViewController+TopmostViewController.h"
#import "LDPMLiveRoomTopMessage.h"
#import "LDPMLiveStrategyViewController.h"
#import "LDPMLiveRoomAlertView.h"
#import "UITableView+FDTemplateLayoutCell.h"
#import "NPMRealTimeMarketInfo.h"
#import "LDPMAutoTurnUpView.h"
#import "LDPMLiveRoomPartnerGoods.h"

static NSString * const LDPMPullDownRefreshDateKey = @"LiveRoomDetailPullDownRefreshDateKey";
static NSInteger const LDPMSubscribeAlertTag = 100;
static NSInteger const LDPMUnsubscribeAlertTag = 101;
static CGFloat const noConnectionViewHeight = 30;
static CGFloat const promptBarLableHeight = 28;
static NSInteger const AnnouncementMaskViewTag = 55685;

@interface LDPMLiveRoomDetailViewController () <UITableViewDataSource, UITableViewDelegate, LDPMLiveDetailTableViewHeaderDelegate, UIAlertViewDelegate, LDPMLiveDetailStrategyCellDelegate, LDPMLiveRoomMarketInfoViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, LDPMLiveDetailNewsWithImageDelegate, LDPMAutoTurnUpViewDelegate>

@property (nonatomic, strong) LDPMLiveRoom *liveRoom;
@property (nonatomic, strong) LDPMLiveDetailStore *store;

@property (nonatomic, strong) LDPMLiveNoConnectionView *noConnectionView;

@property (nonatomic, strong) MSWeakTimer *liveRoomStatusTimer;
@property (nonatomic, strong) MSWeakTimer *marketInfoTimer;
@property (nonatomic, strong) NPMMarketInfoService *marketInfoService;

@property (nonatomic, strong) MSWeakTimer *answerTimer;
@property (nonatomic, strong) MSWeakTimer *liveTimer;

@property (nonatomic, strong) LDPMLiveDetailTableViewHeader *tableHeaderView;

@property (nonatomic, strong) LDPMLiveNoDataCell *noDataCell;
@property (nonatomic, strong) LDPMLiveLoadingCell *loadingCell;

@property (nonatomic, strong) LDPMLiveLoadMoreView *reachEndView;

@property (nonatomic, strong) UIButton *subscribeButton;

@property (strong, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, assign) BOOL showNetworkError;

@property (nonatomic, assign) BOOL firstLoading;
@property (nonatomic, assign) BOOL hasGottenUserLiveRoomQualification;
@property (nonatomic, assign) BOOL jump2Question;

@property (nonatomic, strong) LDCPCirclePhotoZoom *photoZoom;
@property (nonatomic, strong) CBAutoScrollLabel *promptBarLabel;
@property (nonatomic, strong) NSLayoutConstraint *noConnectionViewConstraint;
@property (nonatomic, strong) NSLayoutConstraint *promptBarLabelConstraint;
@property (nonatomic, strong) MSWeakTimer *promptBarLabelTimer;
@property (nonatomic, strong) LDPMLiveRoomAlertView *alertView;

@property (nonatomic, strong) LDPMAutoTurnUpView *autoTurnUpView;
@property (nonatomic, strong) NSMutableArray *marketInfoArray;

@end

@implementation LDPMLiveRoomDetailViewController

#pragma mark - JLRoutes

+ (void)load
{
    [self registerRoutes];
}

+ (void)registerRoutes
{
    [JLRoutes addRoute:@"/liveRoom" handler:^BOOL(NSDictionary *parameters) {
        NSString *roomId = parameters[@"roomId"];
        if (!roomId.length) {
            return YES;
        }
        
        BOOL go2Question = [parameters[@"question"] integerValue] == 1;
        [[LDPMLiveRoomListStore sharedStore] getLiveRoomWithRoomId:roomId forceLogin:YES completion:^(BOOL success, LDPMLiveRoom *liveRoom, NSError *error, NSError *httpError) {
            if (success && liveRoom) {
                LDPMLiveRoomDetailViewController *liveRoomVC = [[LDPMLiveRoomDetailViewController alloc] initWithLiveRoom:liveRoom];
                if (go2Question) {
                    liveRoomVC.hasGottenUserLiveRoomQualification = YES; //直接跳转提问页的话，不需要再次获取权限，免得等待时间过长
                    liveRoomVC.jump2Question = YES;
                }
                [ECLaunch launchViewController:liveRoomVC];
            } else if (error.localizedDescription) {
                UIViewController *rootViewController = [UIViewController topmostViewController];
                [rootViewController showToast:error.localizedDescription];
            }
        }];
        return YES;
    }];
}

#pragma mark - View life cycle

- (instancetype)initWithLiveRoom:(LDPMLiveRoom *)liveRoom
{
    self = [self initWithNibName:NSStringFromClass([LDPMLiveRoomDetailViewController class]) bundle:nil];
    if (self) {
        self.liveRoom = liveRoom;
        self.title = liveRoom.roomName;
        self.store = [[LDPMLiveDetailStore alloc] initWithRoomId:liveRoom.roomId];
        self.marketInfoService = [NPMMarketInfoService sharedService];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNavigationBar];
    [self.view addSubview:self.noConnectionView];
    [self.view addSubview:self.promptBarLabel];
    [self.view addSubview:self.autoTurnUpView];
    [self addAutoLayout];
    
    self.tableView.backgroundColor = [NPMColor mainBackgroundColor];
    self.tableView.tableHeaderView = self.tableHeaderView;

    self.tableView.tableFooterView = [UIView new];
    [self registerCells];
    [self setupPullDownRefresh];
    [self setupPullUpRefresh];
    self.reachEndView.loading = NO;
    self.reachEndView.reachEnd = NO;
    self.reachEndView.hidden = YES;
    
    self.firstLoading = YES;
    self.loadingCell.loading = YES;
    
    self.marketInfoArray = [NSMutableArray new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkBecameUnReachableNotification:) name:NETWORK_NOTIFICATION_BECOME_UNREACHABLE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkBecameReachableNotification:) name:NETWORK_NOTIFICATION_BECOME_REACHABLE object:nil];
    
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:self.liveRoom.roomName];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    //直播间资格审查
    [self hidePullUpDownRefresh];
    if (self.hasGottenUserLiveRoomQualification == NO) {
        [self checkUserLiveRoomQualification];
    } else {
        [self handlePermissionWithLiveRoomList:@[self.liveRoom]];
    }
    if (self.jump2Question) {
        [self performSelector:@selector(headerCellDidTapQuestionButton:) withObject:nil afterDelay:0.0];
        self.jump2Question = NO;
    }
    [self startAutoRefreshLiveRoomStatus];
    [self startAutoRefreshMarketInfo];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self stopAutoRefreshLiveRoomStatus];
    [self stopAutoRefreshMarketInfo];
    [self stopAutoRefreshLiveData];
    [self stopAutoRefreshNewAnswer];
    self.hasGottenUserLiveRoomQualification = NO;
}

#ifdef DEBUG
- (BOOL)willDealloc
{
    return NO;
}
#endif

- (void)dealloc
{
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAutoRefreshLiveRoomStatus];
    [self stopAutoRefreshMarketInfo];
    [self stopAutoRefreshLiveData];
    [self stopAutoRefreshNewAnswer];
}

#pragma mark - Set up

- (void)registerCells
{
    UINib *newsImageCellNib = [UINib nibWithNibName:NSStringFromClass([LDPMLiveDetailNewsWithImageCell class]) bundle:nil];
    [self.tableView registerNib:newsImageCellNib forCellReuseIdentifier:NSStringFromClass([LDPMLiveDetailNewsWithImageCell class])];
    
    UINib *strategyCellNib = [UINib nibWithNibName:NSStringFromClass([LDPMLiveDetailStrategyCell class]) bundle:nil];
    [self.tableView registerNib:strategyCellNib forCellReuseIdentifier:NSStringFromClass([LDPMLiveDetailStrategyCell class])];
    
    UINib *qaCellNib = [UINib nibWithNibName:NSStringFromClass([LDPMLiveDetailQaCell class]) bundle:nil];
    [self.tableView registerNib:qaCellNib forCellReuseIdentifier:NSStringFromClass([LDPMLiveDetailQaCell class])];
    [LDPMErrorCell ec_registerToTableView:self.tableView];
}

- (void)setupNavigationBar
{
    NSString *buttonTitle = self.liveRoom.isSub ? @"已订阅" : @"  订阅  ";
    self.subscribeButton = [NPMUIFactory naviButtonWithTitle:buttonTitle target:self selector:@selector(subcribeButtonAction:)];
    [self.subscribeButton setTitleColor:[NPMColor whiteTextColor] forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.subscribeButton];
}

- (void)addAutoLayout
{
    [self.noConnectionView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeBottom];
    [self.noConnectionView autoSetDimension:ALDimensionHeight toSize:noConnectionViewHeight];
    
    self.noConnectionViewConstraint = [self.autoTurnUpView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.noConnectionView withOffset:-noConnectionViewHeight];
    [self.autoTurnUpView autoPinEdgeToSuperviewEdge:ALEdgeLeft];
    [self.autoTurnUpView autoPinEdgeToSuperviewEdge:ALEdgeRight];
    [self.autoTurnUpView autoSetDimension:ALDimensionHeight toSize:32];
    
    self.promptBarLabelConstraint = [self.promptBarLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.autoTurnUpView withOffset:-promptBarLableHeight];
    [self.promptBarLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft];
    [self.promptBarLabel autoPinEdgeToSuperviewEdge:ALEdgeRight];
    [self.promptBarLabel autoSetDimension:ALDimensionHeight toSize:promptBarLableHeight];
    
    [self.tableView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
    [self.tableView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.promptBarLabel];
}

#pragma mark - 下拉刷新&上拉加载

- (void)setupPullDownRefresh
{
    @weakify(self);
    self.tableView.mj_header = [LDPMTableViewHeader headerWithRefreshingBlock:^{
        @strongify(self);
        if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
            [self fetchNewLiveDataWithCompletion:^{
                @strongify(self);
                [self.tableView.mj_header endRefreshing];
            } toastError:YES];
            [self refreshNewAnswer];
        } else {
            //无资格时下拉刷新不调用接口
            [self.tableView.mj_header endRefreshing];
        }
    }];
}

- (void)setupPullUpRefresh
{
    @weakify(self);
    self.tableView.mj_footer = [LDPMTableViewFooter footerWithRefreshingBlock:^{
        @strongify(self);
        if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
            [self fetchEarlierLiveDataWithCompletion:^{
                @strongify(self);
                [self.tableView.mj_footer endRefreshing];
            }];
        } else {
            [self fetchEarlierHistoryLiveDataWithCompletion:^{
                @strongify(self);
                [self.tableView.mj_footer endRefreshing];
            }];
        }
    }];
}

- (void)showPullUpDownRefresh
{
    self.tableView.mj_header.hidden = NO;
    self.tableView.mj_footer.hidden = NO;
}

- (void)hidePullUpDownRefresh
{
    self.tableView.mj_header.hidden = YES;
    self.tableView.mj_footer.hidden = YES;
    self.tableView.mj_footer.automaticallyHidden = NO;
}

#pragma mark - Handle status

- (void)checkUserLiveRoomQualification
{
    [self fetchUserLiveRoomQualification];
}

- (BOOL)isFirstSubcribedSuccessTipsShow
{
    NSString *key = [self getFirstSubcribedSuccessTipsShowKey];
    BOOL flag = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    return flag;
}

- (void)handleFristLoading
{
    if (self.firstLoading) {
        self.firstLoading = NO;
        self.loadingCell.loading = NO;
    }
}

- (void)handleReachEndView
{
    self.tableView.mj_footer.hidden = !(self.store.liveDetailInfoArray.count && !self.store.reachEnd);
    
    self.reachEndView.reachEnd = self.store.reachEnd;
    self.reachEndView.hidden = !(self.store.liveDetailInfoArray.count && self.store.reachEnd);
    
    if (self.reachEndView.hidden) {
        self.tableView.tableFooterView = [UIView new];
    } else {
        self.tableView.tableFooterView = self.reachEndView;
    }
}

- (void)backToStart
{
    [self.store clearLiveData];
    [self hidePullUpDownRefresh];
    self.firstLoading = YES;
    self.loadingCell.loading = YES;
    self.tableView.tableFooterView = [UIView new];
}

#pragma mark - Timers & Timer actions

- (void)startAutoRefreshLiveRoomStatus
{
    if (self.liveRoomStatusTimer == nil) {
        self.liveRoomStatusTimer = [MSWeakTimer scheduledTimerWithTimeInterval:5.0
                                                                        target:self
                                                                      selector:@selector(refreshLiveRoomStatus)
                                                                      userInfo:nil
                                                                       repeats:YES
                                                                 dispatchQueue:dispatch_get_main_queue()];
    }
    [self.liveRoomStatusTimer fire];
}

- (void)refreshLiveRoomStatus
{
    @weakify(self);
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"roomId"] = self.liveRoom.roomId;
    [LDPMLiveService fetchNewLiveNumberWithParameters:params completion:^(BOOL success, NSInteger liveNumber, NSInteger liveStatus, BOOL isNewTopContent, NSArray *noticeArray, NSError *error, NSError *httpError) {
        @strongify(self);
        if (success) {
            self.liveRoom.liveStatus = liveStatus;
            self.tableHeaderView.liveStatus = liveStatus;
        }
    }];
}

- (void)stopAutoRefreshLiveRoomStatus
{
    [_liveRoomStatusTimer invalidate];
    _liveRoomStatusTimer = nil;
}

- (void)startAutoRefreshMarketInfo
{
    if (self.marketInfoTimer == nil) {
        self.marketInfoTimer = [MSWeakTimer scheduledTimerWithTimeInterval:5.0
                                                                    target:self
                                                                  selector:@selector(refreshMarketInfo)
                                                                  userInfo:nil
                                                                   repeats:YES
                                                             dispatchQueue:dispatch_get_main_queue()];
    }
    
    [self.marketInfoTimer fire];
}

- (void)refreshMarketInfo
{

    NSMutableArray *productArray = [NSMutableArray new];
    for (LDPMLiveRoomPartnerGoods *goods in self.liveRoom.showGoodsList) {
        NPMProduct *product = [NPMProduct productWithGoodsId:goods.wareId goodsName:goods.wareDesc partnerId:goods.partnerId];
        [productArray addObject:product];
    }
    
    @weakify(self);
    [self.marketInfoService fetchRealTimeMarketInfoForProductList:productArray completion:^(NPMRetCode responseCode, NSError *error, NSDictionary *marketInfoDic) {
        @strongify(self);
        if(responseCode == NPMRetCodeSuccess && marketInfoDic && marketInfoDic.count > 0) {
            [self.marketInfoArray removeAllObjects];
            for (LDPMLiveRoomPartnerGoods *goods in self.liveRoom.showGoodsList) {
                NSString *key = [NSString stringWithFormat:@"%@%@", goods.wareId, goods.partnerId];
                [self.marketInfoArray addObject:[marketInfoDic objectForKey:key]];
            }
            if (!self.autoTurnUpView.isTurning) {
                [self.autoTurnUpView startAutoTurn];
            }
            [self setMarketInfoContentWith:self.autoTurnUpView.currentCustomView index:self.autoTurnUpView.currentIndex];
        }
    }];
}

- (void)stopAutoRefreshMarketInfo
{
    [_marketInfoTimer invalidate];
    _marketInfoTimer = nil;
}

- (void)startAutoRefreshNewAnswer
{
    if (self.answerTimer == nil) {
        self.answerTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.0
                                                                target:self
                                                              selector:@selector(refreshNewAnswer)
                                                              userInfo:nil
                                                               repeats:YES
                                                         dispatchQueue:dispatch_get_main_queue()];
    }
    [self.answerTimer fire];
}

- (void)refreshNewAnswer
{
    @weakify(self);
    [self.store fetchNewAnswerStateWithCompletion:^(BOOL success, BOOL hasNewAnswer, NSError *error, NSError *httpError) {
        @strongify(self);
        self.tableHeaderView.hasNewAnswer = success && hasNewAnswer;
    }];
}

- (void)stopAutoRefreshNewAnswer
{
    [_answerTimer invalidate];
    _answerTimer = nil;
}

- (void)startAutoRefreshLiveData
{
    if (self.liveTimer == nil) {
        self.liveTimer = [MSWeakTimer scheduledTimerWithTimeInterval:5.0
                                                              target:self
                                                            selector:@selector(refreshLiveData)
                                                            userInfo:nil
                                                             repeats:YES
                                                       dispatchQueue:dispatch_get_main_queue()];
    }
}

- (void)refreshLiveData
{
    [self fetchNewLiveDataWithCompletion:nil toastError:NO];
}

- (void)stopAutoRefreshLiveData
{
    [_liveTimer invalidate];
    _liveTimer = nil;
}

#pragma mark - Notifications

- (void)networkBecameUnReachableNotification:(NSNotification *)notification
{
    if (self.noConnectionViewConstraint.constant != 0) {
        self.noConnectionViewConstraint.constant = 0;
        
        [UIView animateWithDuration:1. animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

- (void)networkBecameReachableNotification:(NSNotification *)notification
{
    if (self.noConnectionViewConstraint.constant != -noConnectionViewHeight) {
        self.noConnectionViewConstraint.constant = -noConnectionViewHeight;
        
        [UIView animateWithDuration:1. animations:^{
            [self.view layoutIfNeeded];
        }];
    }
}

#pragma mark - PromptBarLabel 小黄条模块逻辑
//小黄条下拉显示,正常情况下下黄条下拉, tableView 的contentOffset不变, 所以不会被小黄条盖住, 而是被挤下来
- (void)showPromptBarLabelWithAnouncement:(id<LDPMLiveDetailObject>)announceInfo
{
    if (self.promptBarLabelConstraint.constant != 0) {
        self.promptBarLabelConstraint.constant = 0;
        [self setPromptBarLabelWithAnnounInfo:announceInfo];
        [UIView animateWithDuration:1. animations:^{
            [self.view layoutIfNeeded];//这句话会引发小黄条下拉动画
            //这里为了不让tableView被挤下来, 做了一个反向的偏移.
            self.tableView.contentOffset = CGPointMake(0, self.tableView.contentOffset.y + promptBarLableHeight);
        } completion:^(BOOL finished) {
            self.promptBarLabel.scrollSpeed = 30;
            [self showAnnouncementWithOffset];
            if (!self.promptBarLabelTimer) {
                self.promptBarLabelTimer = [MSWeakTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(hidePromptBarLabel) userInfo:nil repeats:NO dispatchQueue:dispatch_get_main_queue()];
            }
        }];
    } else {
        [self setPromptBarLabelWithAnnounInfo:announceInfo];
        [self showAnnouncementWithOffset];
        [self.promptBarLabelTimer invalidate];
        self.promptBarLabelTimer = nil;
        self.promptBarLabelTimer = [MSWeakTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(hidePromptBarLabel) userInfo:nil repeats:NO dispatchQueue:dispatch_get_main_queue()];
    }
}
//隐藏小黄条, 正常情况下小黄条上拉, tableView 的contentOffset不变, 所以tableView会被提上去
- (void)hidePromptBarLabel
{
    if (self.promptBarLabelConstraint.constant != -promptBarLableHeight) {
        self.promptBarLabelConstraint.constant = -promptBarLableHeight;
        self.promptBarLabel.scrollSpeed = 0;
        [UIView animateWithDuration:1. animations:^{
            [self.view layoutIfNeeded];//这句话会引发小黄条下拉动画
            // 注意当偏移量小于小黄条高度时,不做偏移动画, 否则偏移量会为负数, 此时是可以看到tableView被提上去的.
            if (self.tableView.contentOffset.y >= promptBarLableHeight) {
                //这里为了不让tableView被提上去, 做了一个反向的偏移.
                self.tableView.contentOffset = CGPointMake(0, self.tableView.contentOffset.y - promptBarLableHeight);
            }
        } completion:^(BOOL finished) {
            [self.promptBarLabelTimer invalidate];
            self.promptBarLabelTimer = nil;     
        }];
    }
}

- (void)setPromptBarLabelWithAnnounInfo:(id<LDPMLiveDetailObject>)announceInfo
{
    switch (announceInfo.liveType) {
        case LDPMLiveDetailTypeStrategy:{
            switch (((LDPMLiveDetailStrategy *)announceInfo).opType) {
                case LDPMLiveStrategyTypeBuy:
                case LDPMLiveStrategyTypeSell:
                {
                    LDPMLiveDetailStrategy *strategy = (LDPMLiveDetailStrategy *)announceInfo;
                    self.promptBarLabel.text =
                    [NSString stringWithFormat:@"  策略：%@%@%@，止盈%@，止损%@，仓位%@%%",
                     strategy.price, strategy.opType == LDPMLiveStrategyTypeBuy ? @"买入" : @"卖出",
                     strategy.wareDesc, strategy.upPrice, strategy.downPrice, strategy.positionRatio];
                    return;
                }
                case LDPMLiveStrategyTypeClose: {
                    LDPMLiveDetailStrategy *strategy = (LDPMLiveDetailStrategy *)announceInfo;
                    self.promptBarLabel.text =
                    [NSString stringWithFormat:@"  平仓：%@%@%@，原策略：%@%@%@，止盈%@，止损%@，仓位%@%%",
                     strategy.price, strategy.referVo.opType == LDPMLiveStrategyTypeBuy ? @"卖出" : @"买入",
                     strategy.wareDesc, strategy.referVo.price, strategy.referVo.opType == LDPMLiveStrategyTypeBuy ? @"买入" : @"卖出",
                     strategy.referVo.wareDesc, strategy.referVo.upPrice, strategy.referVo.downPrice, strategy.referVo.positionRatio];
                    return;
                }
            }
        }
            
        case LDPMLiveDetailTypeNews: {
            LDPMLiveDetailNews *news = (LDPMLiveDetailNews *)announceInfo;
            self.promptBarLabel.text = [NSString stringWithFormat:@"  %@", news.content];
            return;
        }
            
        default:
            return;
    }
}
//小黄条被点击时,tableView回到最顶端,并且隐藏小黄条
- (void)promptBarLabelTapped:(UIGestureRecognizer *)tap
{
    //如果被点击时tableView的偏移量大于小黄条的高度, tableView的偏移量不是回到0, 而是为小黄条的高度,此时tableView是被小黄条盖住的,
    //但是由于小黄条随即被收起,tableView会跟着向上移一个小黄条的高度, 而隐藏小黄条的逻辑中又会保持当前页面保持不动, 所以动画结束时, contentOffset又变为0, 并且tableView不会上移.
    if (self.tableView.contentOffset.y >= promptBarLableHeight) {
        [self.tableView setContentOffset:CGPointMake(0, promptBarLableHeight) animated:YES];
    } else {
    //但是如果偏移量太小, 隐藏小黄条时就不会做反向偏移动画, 此处就不需要把tableView多设一个小黄条高度的偏移量, 直接设为0即可,
    //效果就是小黄条不会盖住tableView,但是会带着它一起移上去. 注意此处动画效果与上面截然不同.
        [self.tableView setContentOffset:CGPointZero animated:YES];
    }
    [self hidePromptBarLabel];
}

#pragma mark - Announcement 直播间置顶模块
//此处为产品需求, 当有置顶时,用一个View直接加载tableView上, 盖住第0个sectionHeader左边的竖线, 且根据sectionHeader的高度不同, View的高度也不同.
- (void)addAnnouncementMaskView
{
    UIView *maskView = [self.tableView viewWithTag:AnnouncementMaskViewTag];
    if(maskView) {
        [maskView removeFromSuperview];
        maskView = nil;
    }
    
    CGFloat maskViewHeight = 0;
    CGFloat section0Height = CGRectGetHeight([self.tableView rectForHeaderInSection:0]);
    if (section0Height == LDPMDetailSectionHeaderFullHeight) {
        maskViewHeight = 20.;
    } else if (section0Height == LDPMDetailSectionHeaderShortHeight) {
        maskViewHeight = 15.;
    }
    maskView = [[UIView alloc]initWithFrame:CGRectMake(0, CGRectGetMaxY(self.tableHeaderView.frame), self.tableView.width, maskViewHeight)];
    maskView.tag = AnnouncementMaskViewTag;
    maskView.backgroundColor = self.tableView.backgroundColor;
    [self.tableView addSubview:maskView];
}
//由于置顶出现是有一个动画, 所以这里最先添加这个View到最终显示的地方有个动画调整过程.
- (void)updateAnnouncementMaskView
{
    UIView *maskView = [self.tableView viewWithTag:AnnouncementMaskViewTag];
    maskView.origin = CGPointMake(0, CGRectGetMaxY(self.tableHeaderView.frame));
}
//置顶取消的时候,顺便把这个View删掉.
- (void)removeAnnouncementMaskView
{
    UIView *maskView = [self.tableView viewWithTag:AnnouncementMaskViewTag];
    [maskView removeFromSuperview];
}
//以动画的形式显示置顶, tableViewHeader变大, tableView默认保证contentOffset不变, 所以底下cell会被挤下来
- (void)showAnnouncementWithAnimation
{
    [self addAnnouncementMaskView];//增加maskview
    [UIView animateWithDuration:1. animations:^{
        self.tableHeaderView.frame = CGRectMake(0, 0, self.tableView.width, self.tableHeaderView.analystView.height + self.tableHeaderView.announceHeight);
        [self updateAnnouncementMaskView];//移动maskview
        //此处不重新设置Header, tableView不会下移; 不放到animation里, 动画不协调.
        self.tableView.tableHeaderView = self.tableHeaderView;
    }];
}
//直接显示置顶, 不加动画, 并保证tableView不被挤下来
- (void)showAnnouncementWithOffset
{
    CGFloat newHeight = self.tableHeaderView.analystView.height + self.tableHeaderView.announceHeight;
    CGFloat relativeOffset = newHeight - CGRectGetHeight(self.tableHeaderView.frame);
    self.tableHeaderView.frame = CGRectMake(0, 0, self.tableView.width, newHeight);
    [self addAnnouncementMaskView];//由于没有动画跟新过程,maskview的创建要放在tableHeaderView的frame确定之后.
    //这里给tableView增加一个反向的偏移量,以保证tableView的内容不会被挤下来.
    self.tableView.contentOffset = CGPointMake(0, self.tableView.contentOffset.y + relativeOffset);
    self.tableView.tableHeaderView = self.tableHeaderView;
}
//以动画形式盖住置顶
- (void)hideAnnouncementWithAnimation
{
    [self removeAnnouncementMaskView];//移除maskView
    [UIView animateWithDuration:1. animations:^{
        self.tableHeaderView.frame = CGRectMake(0, 0, self.tableView.width, self.tableHeaderView.analystView.height);
        //此处不重新设置Header, tableView不会下移; 不放到animation里, 动画不协调.
        self.tableView.tableHeaderView = self.tableHeaderView;
    }];
}
//没有删除置顶, 直接把置顶盖住.
-(void)hideAnnouncementWithOffset
{
    [self removeAnnouncementMaskView];//移除maskView
    self.tableHeaderView.frame = CGRectMake(0, 0, self.tableView.width, self.tableHeaderView.analystView.height);
    self.tableView.contentOffset = CGPointMake(0, self.tableView.contentOffset.y - self.tableHeaderView.announceHeight);
    //此处不重新设置Header, tableView不会上移
    self.tableView.tableHeaderView = self.tableHeaderView;
}

#pragma mark - Actions

- (void)subcribeButtonAction:(id)sender
{
    if (self.hasGottenUserLiveRoomQualification == NO) {
        [self showToast:@"网络错误，请检查网络设置"];
        return;
    }
    
    NSString *prefixStr = self.liveRoom.refuseInfo.tips;
    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
        if (!self.liveRoom.isSub) {
            [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"订阅%@", self.liveRoom.roomName]];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"您只能订阅一个直播间，若已有订阅则将被替换，确定订阅吗？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.tag = LDPMSubscribeAlertTag;
            [alert show];
        } else {
            [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"取消订阅%@", self.liveRoom.roomName]];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"确定不再订阅该直播间？" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
            alert.tag = LDPMUnsubscribeAlertTag;
            [alert show];
        }
        return;
    } else if (self.liveRoom.allowed == LDPMLiveRoomAllowedNO) {
        prefixStr = [NSString stringWithFormat:@"订阅后，您可收到实时策略！\n%@", prefixStr];
    }
    [self showRefuseAlertWithMessage:prefixStr buttonTitle:self.liveRoom.refuseInfo.buttonDesc allowedType:self.liveRoom.allowed];
}

- (void)showRefuseAlertWithMessage:(NSString *)message buttonTitle:(NSString *)title allowedType:(LDPMLiveRoomAllowed)allowedType
{
    if (self.alertView) {
        return;
    }
    
    self.alertView = [[LDPMLiveRoomAlertView alloc] initWithMessage:message buttonTitle:title parentView:self.view];
    @weakify(self);
    self.alertView.dismissBlock = ^(LDPMTradeConfirmAlertView *alertView, NSUInteger buttonIndex) {
        @strongify(self);
        if (buttonIndex == 1) {
            switch (allowedType) {
                case LDPMLiveRoomAllowedNO:{//不满足门槛
                    NSURL *url = [NSURL URLWithString:self.liveRoom.refuseInfo.buttonUrl];
                    [JLRoutes routeURL:url];
                }
                    break;
                    
                case LDPMLiveRoomAllowedConfirm: {//切换直播间,确定进入
                    @weakify(self);
                    [[LDPMLiveRoomListStore sharedStore] chooseRoomWithRoomId:self.liveRoom.roomId completion:^(BOOL success, NSError *error, NSError *httpError) {
                        @strongify(self);
                        if (success) {
                            [self.store clearLiveData];
                            @weakify(self);
                            [self fetchNewLiveDataWithCompletion:^{
                                 @strongify(self);
                                [self checkUserLiveRoomQualification];
                            } toastError:YES];
                        } else if(error.localizedDescription) {
                            [self showToast:error.localizedDescription];
                        }
                    }];
                }
                    break;
                    
                case LDPMLiveRoomAllowedHelp: {//联系客服
                    NSURL *url = [NSURL URLWithString:self.liveRoom.refuseInfo.buttonUrl];
                    [JLRoutes routeURL:url];
                }
                    return;
                    
                default:
                    break;
            }
            [self.alertView removeFromSuperview];
            self.alertView = nil;
        } else {
            [self.alertView removeFromSuperview];
            self.alertView = nil;
            return;
        }
    };
    [self.alertView show];
}


#pragma mark - Fetch data

- (void)fetchUserLiveRoomQualification
{
    self.showNetworkError = NO;
    [[LDPMLiveRoomListStore sharedStore] fetchLiveRoomListWithCompletion:^(BOOL success, NSArray *roomList, BOOL isShowTips, NSString *tips, NSError *error, NSError *httpError) {
        if (success) {
            [self handlePermissionWithLiveRoomList:roomList];
        } else {
            self.showNetworkError = YES;
            [self backToStart];
            if (error) {
                [self showToast:error.localizedDescription];
            }
            [self.tableView reloadData];
        }
    }];
}

- (void)fetchNewLiveDataWithCompletion:(void (^)(void))completion toastError:(BOOL)toastError
{
    self.showNetworkError = NO;
    
    __weak typeof(self) weakSelf = self;
    [self.store fetchNewLiveDataNumberWithCompletion:^(BOOL success, BOOL liveDataChanged, NSInteger liveStatus, BOOL isNewTopContent, NSError *error, NSError *httpError) {
        if (!success) {
            if (httpError && [weakSelf.store liveDetailInfoArray].count == 0) {
                weakSelf.showNetworkError = YES;
            }
            if (toastError) {
                [weakSelf showToast:error.localizedDescription];
            }
        } else {
            weakSelf.liveRoom.liveStatus = liveStatus;
            weakSelf.tableHeaderView.liveStatus = liveStatus;
            if (isNewTopContent) {
                [weakSelf.store fetchAnnouncementWithCompletion:^(BOOL success, id<LDPMLiveDetailObject> annouceInfo, NSError *error, NSError *httpError) {
                    if (success) {
                        if (weakSelf.tableView.contentOffset.y <= weakSelf.tableHeaderView.height) {
                            if(annouceInfo) {
                                [weakSelf.tableHeaderView updateAnnouncement:annouceInfo];
                                [weakSelf showAnnouncementWithAnimation];
                            } else {
                                [weakSelf hideAnnouncementWithAnimation];
                            }
                        } else {
                            if (annouceInfo) {
                                [weakSelf.tableHeaderView updateAnnouncement:annouceInfo];
                                [weakSelf showPromptBarLabelWithAnouncement:annouceInfo];
                            } else {
                                [weakSelf hideAnnouncementWithOffset];
                            }
                        }
                    }
                }];
            } 
        }
        [weakSelf handleFristLoading];
        weakSelf.tableView.mj_header.hidden = weakSelf.showNetworkError;
        [weakSelf handleReachEndView];
        if (liveDataChanged) {
            [weakSelf.tableView reloadData];
        }
        
        if (completion) {
            completion();
        }
    }];
}

- (void)fetchEarlierLiveDataWithCompletion:(void (^)(void))completion
{
    __weak typeof(self) weakSelf = self;
    
    [self.store fetchMoreLiveDetailInfoWithDirection:LiveRoomDataFetchingEarlierDirection completion:^(BOOL success, NSError *error, NSError *httpError) {
        if (!success) {
            [weakSelf showToast:error.localizedDescription];
        }
        [weakSelf handleReachEndView];
        [weakSelf.tableView reloadData];
        if (completion) {
            completion();
        }
    }];
}

- (void)fetchHistoryLiveDataWithCompletion:(void (^)(void))completion toastError:(BOOL)toastError
{
    self.showNetworkError = NO;
    
    __weak typeof(self) weakSelf = self;
    
    [self.store fetchMoreHistoryLiveDetailInfoWithDirection:LiveRoomDataFetchingLaterDirection completion:^(BOOL success, NSError *error, NSError *httpError) {
        if (!success) {
            if (httpError && [weakSelf.store liveDetailInfoArray].count == 0) {
                weakSelf.showNetworkError = YES;
            }
            if (toastError) {
                [weakSelf showToast:error.localizedDescription];
            }
        }
        weakSelf.tableView.mj_header.hidden = weakSelf.showNetworkError;
        [weakSelf handleFristLoading];
        [weakSelf handleReachEndView];
        [weakSelf.tableView reloadData];
        [weakSelf.tableView.mj_header endRefreshing];

        if (completion) {
            completion();
        }
    }];
}

- (void)fetchEarlierHistoryLiveDataWithCompletion:(void (^)(void))completion
{
    __weak typeof(self) weakSelf = self;
    
    [self.store fetchMoreHistoryLiveDetailInfoWithDirection:LiveRoomDataFetchingEarlierDirection completion:^(BOOL success, NSError *error, NSError *httpError) {
        if (!success) {
            if (error) {
                [weakSelf showToast:error.localizedDescription];
            }
        }
        [weakSelf handleReachEndView];
        [weakSelf.tableView reloadData];
        if (completion) {
            completion();
        }
    }];
}
- (void)subscribeLiveRoom
{
    @weakify(self);
    [self.store subscribeLiveRoomWithCompletion:^(BOOL success, NSError *error, NSError *httpError) {
        @strongify(self);
        if (success) {
            BOOL isFirstSubcribedSuccessTipsShow = [self isFirstSubcribedSuccessTipsShow];
            if (isFirstSubcribedSuccessTipsShow == NO) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"订阅成功" message:@"您将收到该直播间推送的策略消息" delegate:nil cancelButtonTitle:@"知道了" otherButtonTitles:nil, nil];
                [alert show];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[self getFirstSubcribedSuccessTipsShowKey]];
                [[NSUserDefaults standardUserDefaults] synchronize];
            } else {
                [self showToast:@"直播间已成功订阅"];
            }
            self.liveRoom.isSub = YES;
            [self.subscribeButton setTitle:@"已订阅" forState:UIControlStateNormal];
        } else {
            [self showToast:error.localizedDescription];
        }
    }];
}

- (void)unsubScribleLiveRoom
{
    @weakify(self);
    [self.store unsubscribeLiveRoomWithCompletion:^(BOOL success, NSError *error, NSError *httpError) {
        @strongify(self);
        if (success) {
            [self showToast:@"直播间已取消订阅"];
            self.liveRoom.isSub = NO;
            [self.subscribeButton setTitle:@"  订阅  " forState:UIControlStateNormal];
        } else {
            [self showToast:error.localizedDescription];
        }
    }];
}

#pragma mark - Data process function

- (void)handleRefuseInfoWithRoomList:(NSArray *)roomList
{
    __weak typeof(self) weakSelf = self;
    for (LDPMLiveRoom *aLiveRoom in roomList) {
        if ([aLiveRoom.roomId isEqualToString:self.liveRoom.roomId]) {
            self.liveRoom.allowed = aLiveRoom.allowed;
            if (aLiveRoom.allowed != LDPMLiveRoomAllowedYES) {
                NSString *buttonTitle = aLiveRoom.refuseInfo.buttonDesc;//允许为nil
                NSString *alertMessage = aLiveRoom.refuseInfo.tips;
                if(aLiveRoom.allowed == LDPMLiveRoomAllowedNO) {
                    if (aLiveRoom.refuseInfo) {
                        if (aLiveRoom.refuseInfo.buttonType == LDPMLiveRoomRefuseActionGuide) {
                            alertMessage = [NSString stringWithFormat:@"开通直播间, 我们帮您赚钱!\n%@", aLiveRoom.refuseInfo.tips];
                        }
                    }
                }
                [weakSelf showRefuseAlertWithMessage:alertMessage buttonTitle:buttonTitle allowedType:aLiveRoom.allowed];
            }
            break;
        }
    }
}

- (void)handlePermissionWithLiveRoomList:(NSArray *)roomList
{
    [self handleRefuseInfoWithRoomList:roomList];
    self.hasGottenUserLiveRoomQualification = YES;
    [self showPullUpDownRefresh];
    if (self.store.liveDetailInfoArray.count == 0) {
        [self.tableView.mj_header beginRefreshing];
        //因为无资格时，历史直播的下拉刷新是不进行网络请求的，所以需要单独请求一次历史直播信息
        if (self.liveRoom.allowed != LDPMLiveRoomAllowedYES) {
            [self fetchHistoryLiveDataWithCompletion:^{
                [self.tableView reloadData];
            } toastError:YES];
        }
    }
    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
        [self startAutoRefreshLiveData];
        [self startAutoRefreshNewAnswer];
    }
}

#pragma mark - LDPMLiveRoomMarketInfoViewDelegate

- (void)marketInfoView:(LDPMLiveRoomMarketInfoView *)infoView didSelectMarketInfo:(NPMRealTimeMarketInfo *)marketInfo
{
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"行情%@", self.liveRoom.roomName]];
    NPMProduct *product = [NPMProduct productWithGoodsId:marketInfo.goodsId goodsName:marketInfo.goodsName partnerId:marketInfo.partnerId];
    NPMProductViewController *productViewController = [NPMProductViewController new];
    productViewController.product = product;
    productViewController.marketInfo = marketInfo;
    productViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:productViewController animated:YES];
}

#pragma mark - LDPMLiveDetailTableViewHeaderDelegate

- (void)headerCellDidTapQuestionButton:(LDPMLiveDetailTableViewHeader *)cell
{
    if (self.hasGottenUserLiveRoomQualification == NO) {
        [self showToast:@"网络错误，请检查网络设置"];
        return;
    }
    NSString *messageStr = self.liveRoom.refuseInfo.tips;
    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
        [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"提问%@", self.liveRoom.roomName]];
        LDPMLiveQAViewController *QAViewController = [[LDPMLiveQAViewController alloc] initWithLiveRoom:self.liveRoom];
        [self.navigationController pushViewController:QAViewController animated:YES];
        return;
    } else if (self.liveRoom.allowed == LDPMLiveRoomAllowedNO) {
        messageStr = [NSString stringWithFormat:@"开通直播间，和分析师深度沟通！\n%@", messageStr];
    }
    [self showRefuseAlertWithMessage:messageStr buttonTitle:self.liveRoom.refuseInfo.buttonDesc allowedType:self.liveRoom.allowed];
}


- (void)headerCellDidTapStrategyButton:(LDPMLiveDetailTableViewHeader *)headerView
{
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:@"策略按钮"];
    if (self.hasGottenUserLiveRoomQualification == NO) {
        [self showToast:@"网络错误，请检查网络设置"];
        return;
    }
    
    NSString *messageStr = self.liveRoom.refuseInfo.tips;
    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
        LDPMLiveStrategyViewController *viewController = [[LDPMLiveStrategyViewController alloc] initWithRoomId:self.liveRoom.roomId];
        [self.navigationController pushViewController:viewController animated:YES];
        return;
    } else if (self.liveRoom.allowed == LDPMLiveRoomAllowedNO) {
        messageStr = [NSString stringWithFormat:@"想看操作建议？快开通直播间！\n%@", messageStr];
    }
    [self showRefuseAlertWithMessage:messageStr buttonTitle:self.liveRoom.refuseInfo.buttonDesc allowedType:self.liveRoom.allowed];
}

- (void)headerCellOnlySeeAnalystBtnTapped:(LDPMLiveDetailTableViewHeader *)cell
{
    if (self.hasGottenUserLiveRoomQualification == NO) {
        [self showToast:@"网络错误，请检查网络设置"];
        return;
    }
    
    NSNumber *showQa = [LDPMLiveDetailStore getShowQaSettingWithRoomId:self.liveRoom.roomId];
    BOOL tmp = !showQa.boolValue;
    showQa = [NSNumber numberWithBool:tmp];
    NSString *text = nil;
    if (showQa) {
        text = [NSString stringWithFormat:@"未选中+%@", self.liveRoom.roomName];
    } else {
        text = [NSString stringWithFormat:@"选中+%@", self.liveRoom.roomName];
    }
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:text];
    __weak typeof(self)weakSelf = self;
    [self startActivity:@"正在加载..."];
    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
        [self.store fetchLatestLiveDetailInfoWithQa:showQa completion:^(BOOL success, NSError *error, NSError *httpError) {
            [weakSelf stopActivity];
            cell.onlySeeAnalystBtn.enabled = YES;
            if (success) {
                [cell setShowQaSetting];
                [weakSelf handleFristLoading];
                [weakSelf handleReachEndView];
                [weakSelf.tableView reloadData];
            } else {
                if (error) {
                    [weakSelf showToast:error.localizedDescription];
                }
            }
        }];
    } else {
        [self.store fetchLatestHistoryLiveDetailInfoWithQa:showQa completion:^(BOOL success, NSError *error, NSError *httpError) {
            [weakSelf stopActivity];
            cell.onlySeeAnalystBtn.enabled = YES;
            if (success) {
                [cell setShowQaSetting];
                [weakSelf handleFristLoading];
                [weakSelf handleReachEndView];
                [weakSelf.tableView reloadData];
            } else {
                if (error) {
                    [weakSelf showToast:error.localizedDescription];
                }
            }
        }];
    }
}

-(void)announcementDidTapped:(id<LDPMLiveDetailObject>)announceInfo
{
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:@"置顶"];
    switch (announceInfo.liveType) {
        case LDPMLiveDetailTypeStrategy:{
            switch (((LDPMLiveDetailStrategy *)announceInfo).opType) {
                case LDPMLiveStrategyTypeBuy:
                case LDPMLiveStrategyTypeSell:
                case LDPMLiveStrategyTypeClose: {
                    [self routeWithStrategy:announceInfo];
                    return;
                }
            }
        }
            
        case LDPMLiveDetailTypeNews: {
            [JLRoutes routeURL:[NSURL URLWithString:((LDPMLiveDetailNews *)announceInfo).redirectUrl]];
            return;
        }
            
        default:
            return;
    }
}

#pragma mark - LDPMLiveDetailStrategyCellDelegate

- (void)strategyCell:(LDPMLiveDetailStrategyCell *)cell didTapOperateButtonWithStrategy:(LDPMLiveDetailStrategy *)strategy
{
    if (!strategy) {
        return;
    }
    if (strategy.status == LDPMLiveStrategyStatusClosed) {
        [self showToast:@"该条策略已过期"];
        return;
    }
    if (strategy.status == LDPMLiveStrategyStatusDisable) {
        [self showToast:@"该条策略已失效"];
        return;
    }
    if (strategy.opType == LDPMLiveStrategyTypeBuy) {
        [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"买入%@", self.liveRoom.roomName]];
    } else if (strategy.opType == LDPMLiveStrategyTypeSell) {
        [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"卖出%@", self.liveRoom.roomName]];
    } else if (strategy.opType == LDPMLiveStrategyTypeClose) {
        [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"平仓%@", self.liveRoom.roomName]];
    }
    [LDPMUserEvent addEvent:EVENT_LIVE_ROOM tag:[NSString stringWithFormat:@"策略%@", self.liveRoom.roomName]];
    
    [self routeWithStrategy:strategy];
}


- (void)routeWithStrategy:(LDPMLiveDetailStrategy *)strategy
{
    NSDictionary *tradeTabDict = @{@(LDPMLiveStrategyTypeBuy).stringValue:@"buy",
                                   @(LDPMLiveStrategyTypeSell).stringValue:@"sell",
                                   @(LDPMLiveStrategyTypeClose).stringValue:@"position"};
    NSString *urlString = [NSString stringWithFormat:@"ntesfa://tab?tab=trade&tradeTab=%@&partnerId=%@&wareID=%@&priceType=0",tradeTabDict[@(strategy.opType).stringValue], strategy.partnerId, [strategy.wareId URLEncodedString]];
    if (strategy.opType == LDPMLiveStrategyTypeBuy || strategy.opType == LDPMLiveStrategyTypeSell) {
        urlString = [urlString stringByAppendingFormat:@"&price=%@", strategy.price];
    }
    urlString = [urlString stringByAppendingFormat:@"&upPrice=%@&downPrice=%@", strategy.upPrice, strategy.downPrice];
    [JLRoutes routeURL:[NSURL URLWithString:urlString]];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.store.liveDetailInfoArray.count > 0) {
        return self.store.liveDetailInfoArray.count;
    }
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
        if (self.store.liveDetailInfoArray.count > 0) {
        NSArray *infoArray = [self.store.liveDetailInfoArray objectAtIndex:section];
        return infoArray.count;
    }
    
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    
    if (self.store.liveDetailInfoArray.count > 0) {
        NSArray *data = self.store.liveDetailInfoArray[section];
        CGFloat height = [LDPMLiveDetailSectionHeader sectionHeightWithData:data];
        return height;
    } else {
        return CGFLOAT_MIN;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return CGFLOAT_MIN;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.store.liveDetailInfoArray.count > 0) {
        NSArray *data = self.store.liveDetailInfoArray[section];
        LDPMLiveDetailSectionHeader *header = [[NSBundle mainBundle] loadNibNamed:@"LDPMLiveDetailSectionHeader" owner:nil options:nil].firstObject;
        
        CGFloat height = [LDPMLiveDetailSectionHeader sectionHeightWithData:data];
        [header handleStyleWithData:data];
        header.frame = CGRectMake(0, 0, SCREEN_WIDTH, height);
        UIView *maskView = [tableView viewWithTag:AnnouncementMaskViewTag];
        [self.tableView bringSubviewToFront:maskView];
        return header;
    } else {
        return [UIView new];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    if (self.store.liveDetailInfoArray.count) {
        NSArray *infoArray = self.store.liveDetailInfoArray[section];
        id<LDPMLiveDetailObject> detailObj = infoArray[row];
        if (detailObj.liveType == LDPMLiveDetailTypeNews) {
            return [tableView fd_heightForCellWithIdentifier:NSStringFromClass([LDPMLiveDetailNewsWithImageCell class]) cacheByIndexPath:indexPath configuration:^(id cell) {
                [cell setContentWithNews:detailObj];
            }];
        } else if (detailObj.liveType == LDPMLiveDetailTypeStrategy) {
            CGFloat height = [tableView fd_heightForCellWithIdentifier:NSStringFromClass([LDPMLiveDetailStrategyCell class]) cacheByIndexPath:indexPath configuration:^(id cell) {
                [(LDPMLiveDetailStrategyCell *)cell setContentWithStrategy:detailObj showTimeSection:YES];
            }];
            return height;
        } else {
            return [tableView fd_heightForCellWithIdentifier:NSStringFromClass([LDPMLiveDetailQaCell class]) cacheByIndexPath:indexPath configuration:^(id cell) {
                [cell setContentWithQaInfo:detailObj];
            }];
        }
    } else {
        return CGRectGetHeight(tableView.frame) - 60;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    if (self.store.liveDetailInfoArray.count) {
        NSArray *infoArray = self.store.liveDetailInfoArray[section];
        id<LDPMLiveDetailObject> detailObj = infoArray[row];
        if (detailObj.liveType == LDPMLiveDetailTypeNews) {
            LDPMLiveDetailNewsWithImageCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([LDPMLiveDetailNewsWithImageCell class])];
            [cell setContentWithNews:detailObj];
            cell.delegate = self;
            return cell;
        } else if (detailObj.liveType == LDPMLiveDetailTypeStrategy) {
            LDPMLiveDetailStrategyCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([LDPMLiveDetailStrategyCell class])];
            [cell setContentWithStrategy:detailObj showTimeSection:YES];
            cell.delegate = self;
            return cell;
        } else {
            LDPMLiveDetailQaCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([LDPMLiveDetailQaCell class])];
            [cell setContentWithQaInfo:detailObj];
            return cell;
        }
    } else {
        if (self.showNetworkError) {
            LDPMErrorTable *errorTable = [LDPMErrorTable errorTableWithImage:[UIImage imageNamed:@"network_error_icon"]
                                                                        text:@"网络不给力，请检查网络后刷新"
                                                                   retryText:@"刷新"];
            LDPMErrorCell *errorCell = [[LDPMErrorCell ec_dequeueFromTableView:tableView] ld_configCellWithData:errorTable];
            @weakify(self);
            errorCell.retryBlock = ^{
                @strongify(self);
                if (self.hasGottenUserLiveRoomQualification) {
                    if (self.liveRoom.allowed == LDPMLiveRoomAllowedYES) {
                        [self fetchNewLiveDataWithCompletion:nil toastError:YES];
                    } else {
                        [self fetchHistoryLiveDataWithCompletion:nil toastError:YES];
                    }
                } else {
                    [self fetchUserLiveRoomQualification];
                }
            };
            return errorCell;
        } else if (self.firstLoading) {
            return self.loadingCell;
        } else {
            [self.noDataCell setTitle:@"分析师还没有直播信息哦~"];
            return self.noDataCell;
        }
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case LDPMSubscribeAlertTag:
            if (buttonIndex == 1) {
                [self subscribeLiveRoom];
            }
            break;
            
        case LDPMUnsubscribeAlertTag:
            if (buttonIndex == 1) {
                [self unsubScribleLiveRoom];
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - LDPMLiveDetailNewsWithImageDelegate

- (void)transferTapEvent:(id)sender
{
    LDCPCirclePhoto *photo = sender;
    NSMutableArray *tempArray = [NSMutableArray array];
    [tempArray addObject:photo];
    
    self.photoZoom = [[LDCPCirclePhotoZoom alloc] initWithImageArray:tempArray currentIndex:photo.index];
    [self.photoZoom starZoomInAnimation];
    
    __weak typeof(self) weakSelf = self;
    [self.photoZoom setWillDismissBlock:^{
        [weakSelf.tableView reloadData];
    }];
}

- (NSInteger)numberOfCustomViewsInAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView
{
    return self.marketInfoArray.count;
}

- (UIView *)customViewWithAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView type:(LDPMAutoTurnUpViewType)type
{
    LDPMLiveRoomMarketInfoView *marketInfoView = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveRoomMarketInfoView class]) owner:nil options:nil] firstObject];
    marketInfoView.delegate = self;
    return marketInfoView;
}

- (void)configAutoTurnUpView:(LDPMAutoTurnUpView *)autoTurnUpView customView:(UIView *)customView index:(NSInteger)index
{
    [self setMarketInfoContentWith:customView index:index];
}

#pragma mark - Getters & Setters

- (LDPMAutoTurnUpView *)autoTurnUpView
{
    if (!_autoTurnUpView) {
        _autoTurnUpView = [LDPMAutoTurnUpView new];
        _autoTurnUpView.delegate = self;
        _autoTurnUpView.timeInterval = 15;
    }
    return _autoTurnUpView;
}

- (LDPMLiveDetailTableViewHeader *)tableHeaderView
{
    if (!_tableHeaderView) {
        _tableHeaderView = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveDetailTableViewHeader class]) owner:nil options:nil].firstObject;
        _tableHeaderView.delegate = self;
        _tableHeaderView.liveRoom = self.liveRoom;
    }
    return _tableHeaderView;
}


- (LDPMLiveNoConnectionView *)noConnectionView
{
    if (!_noConnectionView) {
        _noConnectionView = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveNoConnectionView class]) owner:nil options:nil] firstObject];
    }
    return _noConnectionView;
}

- (LDPMLiveNoDataCell *)noDataCell
{
    if (!_noDataCell) {
        _noDataCell = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveNoDataCell class]) owner:nil options:nil] firstObject];
        _noDataCell.backgroundColor = [UIColor whiteColor];
        _noDataCell.verticalCenterConstraint.priority = UILayoutPriorityDefaultLow;
        _noDataCell.verticalTopConstraint.priority = UILayoutPriorityDefaultHigh;
    }
    return _noDataCell;
}

- (LDPMLiveLoadingCell *)loadingCell
{
    if (!_loadingCell) {
        _loadingCell = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveLoadingCell class]) owner:nil options:nil] firstObject];
    }
    return _loadingCell;
}

- (LDPMLiveLoadMoreView *)reachEndView
{
    if (!_reachEndView) {
        _reachEndView = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([LDPMLiveLoadMoreView class]) owner:nil options:nil] firstObject];
    }
    return _reachEndView;
}

- (CBAutoScrollLabel *)promptBarLabel
{
    if (!_promptBarLabel) {
        _promptBarLabel = [CBAutoScrollLabel new];
        _promptBarLabel.backgroundColor = [UIColor colorWithRGB:0xFFFAC4];
        _promptBarLabel.textColor = [UIColor colorWithRGB:0xF05500];
        _promptBarLabel.font = [UIFont systemFontOfSize:12];
        _promptBarLabel.labelSpacing = 48;
        _promptBarLabel.textAlignment = NSTextAlignmentLeft;
        _promptBarLabel.fadeLength = 12.f;
        _promptBarLabel.scrollSpeed = 0;
        _promptBarLabel.scrollDirection = CBAutoScrollDirectionLeft;
        [_promptBarLabel observeApplicationNotifications];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(promptBarLabelTapped:)];
        [_promptBarLabel addGestureRecognizer:tap];
        _promptBarLabel.userInteractionEnabled = YES;
    }
    return  _promptBarLabel;
}

#pragma mark - Help functions

- (void)setMarketInfoContentWith:(UIView *)marketInfoView index:(NSInteger)index
{
    LDPMLiveRoomMarketInfoView *aMarketInfoView = (LDPMLiveRoomMarketInfoView *)marketInfoView;
    LDPMLiveRoomPartnerGoods *currentGoods = self.liveRoom.showGoodsList[index];
    [aMarketInfoView setContentWithMarketInfo:self.marketInfoArray[index] defaultName:currentGoods.wareDesc];
}

- (NSString *)getFirstSubcribedSuccessTipsShowKey
{
    return [NSString stringWithFormat:@"%@+%@", [UserSession sharedSession].loginUserName, @"LDPMLiveRoomFirstSubcribedSuccessTipsShow"];
}

#pragma mark - 页面统计

- (NSString *)pageEventParam
{
    return self.liveRoom.roomName;
}

@end
