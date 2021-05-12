//
//  ZegoClassViewController.m
//  ZegoWhiteboardVideoDemo
//
//  Created by zego on 2020/6/1.
//  Copyright © 2020 zego. All rights reserved.
//

#import "ZegoClassViewController.h"
#import "ZegoLiveCenter.h"
#import "ZegoAuthConstants.h"
#import "ZegoUIConstant.h"
#import "ZegoToast.h"
#import "ZegoWhiteBoardViewContainerModel.h"
#import "ZegoHUD.h"

#import "ZegoViewAnimator.h"
#import "ZegoStreamTableView.h"
#import "ZegoUserTableView.h"
#import "ZegoFileListView.h"
#import "ZegoExcelSheetListView.h"

#import "ZegoBoardContainer.h"
#import "ZegoDrawingToolView.h"
#import "ZegoWhiteboardListView.h"
#import "ZegoPageControlView.h"
#import "ZegoChatViewController.h"

#import "ZegoClassRoomTopBar.h"
#import "ZegoClassRoomBottomBar.h"
#import "ZegoClassRoomCoverView.h"
#import "ZegoAlertView.h"
#import "ZegoClassDefaultNoteView.h"

#import "ZegoClassInviteManager.h"
#import "ZegoDefaultFileLoader.h"

#import "UIColor+ZegoExtension.h"
#import "ZegoFilePreviewViewModel.h"

#import "ZegoClassCommand.h"
#import "ZegoNetworkManager.h"
#import "ZegoHttpHeartbeat.h"
#import "ZegoDispath.h"

#import "ZegoWhiteBoardService.h"
#import "ZegoLoginService.h"
#import "ZegoFormatToolService.h"

#import "ZegoRoomMemberListRspModel.h"
#import <YYModel/YYModel.h>
#import <AVFoundation/AVFoundation.h>
#import "ZegoRotationManager.h"
#import "ZegoClassJustTestViewController.h"
#import "ZegoClassEnvManager.h"
#import <Masonry/Masonry.h>
#import "ZegoViewCaptor.h"
#ifdef IS_USE_LIVEROOM
#import <ZegoLiveRoom/ZegoLiveRoomApi.h>
#else
#import <ZegoExpressEngine/ZegoExpressEngine.h>
#endif
#import "NSString+ZegoExtension.h"
typedef void(^ZegoCompleteBlock)(NSInteger errorCode);

@interface ZegoClassViewController ()<ZegoWhiteboardListViewDelegate, ZegoFileListViewDelegate, ZegoExcelSheetListViewDelegate, ZegoWhiteboardManagerDelegate, ZegoLiveCenterDelegate, ZegoClassRoomBottomBarDelegate, ZegoClassRoomTopBarDelegate,ZegoPageControlViewDelegate, ZegoWhiteboardViewDelegate, ZegoHttpHeartbeatDelegate,ZegoWhiteBoardServiceDelegate, ZegoDocsViewDelegate, ZegoDrawingToolViewDelegate, ZegoClassJustTestViewControllerDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate,UIDocumentPickerDelegate>

@property (weak, nonatomic) IBOutlet ZegoClassDefaultNoteView *defaultNoteView;
@property (nonatomic, assign) BOOL isFrontCamera;
@property (nonatomic, assign) BOOL isEnvAbroad;
@property (nonatomic, assign) ZegoClassPatternType classType;
@property (nonatomic, copy) NSString *publishStreamID;
@property (nonatomic, copy) NSString *roomId;

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (weak, nonatomic) IBOutlet ZegoClassRoomTopBar *topBar;
@property (weak, nonatomic) IBOutlet ZegoClassRoomBottomBar *bottomBar;
@property (weak, nonatomic) ZegoClassRoomCoverView *topCoverView;
@property (weak, nonatomic) IBOutlet UIView *pageControlCarrierView;

@property (nonatomic, weak) IBOutlet ZegoStreamTableView *streamTableView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *streamTableViewWidth;

@property (nonatomic, strong) ZegoUserTableView *userTableView;
@property (nonatomic, strong) NSMutableArray <ZegoLiveStream *> *streamList;

@property (nonatomic, strong)ZegoChatViewController *chatList;

@property (nonatomic, strong) ZegoFileListView *fileListView;
@property (nonatomic, strong) ZegoExcelSheetListView *excelSheetListView;
@property (nonatomic, strong) ZegoPageControlView *pageControlView;

@property (nonatomic, strong) ZegoWhiteBoardService *whiteBoardService;
@property (nonatomic, strong) ZegoLiveReliableMessage *whiteBoardSeqMessage;
@property (nonatomic, strong) ZegoDrawingToolView *drawingToolView;
@property (nonatomic, strong) ZegoWhiteboardListView *boardListView;
//排序，整理好的ZegoWhiteBoardViewContainerModel数组，供显示白板列表使用

@property (nonatomic, strong) ZegoRoomMemberInfoModel *currentUserModel;//当前登录用户模型

@property (nonatomic, strong) ZegoLoginService *loginService;
@property (nonatomic, strong) ZegoFormatToolService *drawingToolViewService;

@property (nonatomic, strong) ZegoFilePreviewViewModel *previewManager;
@property (nonatomic, strong) NSMutableArray <ZegoRoomMemberInfoModel *> *roomMemberArray;
@property (nonatomic, strong) NSMutableArray <ZegoStreamWrapper *> *joinLiveMemberArray;
@property (nonatomic, assign) BOOL uploadDynamicFile;

@end

@implementation ZegoClassViewController

- (instancetype)initWithRoomID:(NSString *)roomID user:(ZegoRoomMemberInfoModel *)user classType:(NSInteger)classType streamList: (NSArray<ZegoLiveStream *> * _Nonnull) streamList isEnvAbroad:(BOOL)isEnvAbroad {
    if (self = [super initWithNibName:@"ZegoClassViewController" bundle:[NSBundle mainBundle]]) {
        self.currentUserModel = user;
        self.currentUserModel.isMyself = YES;
        self.roomId = roomID;
        _isEnvAbroad = isEnvAbroad;
        self.classType = (ZegoClassPatternType)classType;
        self.whiteBoardService = [[ZegoWhiteBoardService alloc] initWithUser:self.currentUserModel roomId:self.roomId delegate:self];
        [ZegoLiveCenter setDelegate: self];
        [ZegoLiveCenter muteVideo:YES];
        [ZegoLiveCenter muteAudio:YES];
        _streamList = [NSMutableArray arrayWithArray:streamList];
        self.publishStreamID = [NSString stringWithFormat:@"a_%@_%ld", self.roomId, (long)self.currentUserModel.uid];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isFrontCamera = YES;
    [self reset];
    [self setupWhiteboard];
    [self setupUI];
    [self loadInitRoomMemberInfo];
    [self startHeartbeat];
    [self forceOrientationLandscape];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"room_login_time_limit_15"] Indicator:NO];
    });
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutRoomEndClass:) name:kZegoAPPTeminalNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kZegoAPPTeminalNotification object:nil];
}

- (void)loadInitRoomMemberInfo {
    //进入房间自动上麦
    [self loadRoomMemberListComplement:nil];
    [self loadJoinLiveListComplement:^(BOOL success) {
        if (success) {
            //老师不管是大班课还是小班课 都要自动开启摄像头和麦克风，学生只有在小班课，且上麦人数不超过3人的情况下才会开启。
            if (self.classType == ZegoClassPatternTypeBig && self.currentUserModel.role == ZegoUserRoleTypeStudent) {
                return;
            }
            if ([self getJoinLiveStudensCount] < 3 || self.currentUserModel.role == ZegoUserRoleTypeTeacher) {
                [self checkAuthorityForMediaType:AVMediaTypeVideo showTip:YES complement:^(BOOL authority) {
                    if (authority ) {
                        [self.bottomBar setupCameraOpen:YES react:YES];
                    }
                }];
            }
            if (([self getJoinLiveStudensCount] < 3) || self.currentUserModel.role == ZegoUserRoleTypeTeacher) {
                [self checkAuthorityForMediaType:AVMediaTypeAudio showTip:YES complement:^(BOOL authority) {
                    if (authority) {
                        [self.bottomBar setupMicOpen:YES react:YES];
                    }
                }];
            }
        }
    }];
}

- (void)forceOrientationLandscape {
    [ZegoRotationManager defaultManager].orientation = UIDeviceOrientationLandscapeRight;
}

- (void)reset {
    [ZegoViewAnimator dismiss];
    [ZegoAlertView dismiss];
    [self.activityIndicator stopAnimating];
    [self.whiteBoardService reset];
    self.streamTableView.currentModel = self.currentUserModel;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)startHeartbeat {
    [ZegoHttpHeartbeat startBeatWithUserID:self.currentUserModel.uid roomID:self.roomId classType:self.classType delegate:self];
}

- (void)setupWhiteboard {
    [self.view addSubview:self.whiteBoardService.whiteBoardContentView];
    [self.view insertSubview:self.whiteBoardService.whiteBoardContentView belowSubview:self.pageControlCarrierView];
    @weakify(self);
    [self loadWhiteboardListWithCompleteBlock:^(ZegoWhiteboardViewError errorCode, NSArray *whiteBoardViewList) {
        @strongify(self);
        if (errorCode == 0 && whiteBoardViewList.count < 1 && self.currentUserModel.canShare == 2) {
            [self.whiteBoardService addWhiteboard];
            [self refreshTopBar];
        }
    }];
    [self.activityIndicator stopAnimating];
    [ZegoWhiteboardManager sharedInstance].delegate = self;
}


- (void)setupUI {
    self.bottomBar.delegate = self;
    self.topBar.delegate = self;
    self.topBar.hidden = YES;
    self.bottomBar.currentModel = self.currentUserModel;
    self.streamTableViewWidth.constant = kStreamCellWidth;
    self.streamTableView.publishStreamId = self.publishStreamID;
    self.streamTableView.teacherModel = (self.currentUserModel.role == ZegoUserRoleTypeTeacher)?self.currentUserModel:nil;
    self.boardListView = [[ZegoWhiteboardListView alloc] initWithFrame:CGRectMake(kScreenWidth - kSideListWidth, 0, kSideListWidth, kScreenHeight)];
    self.boardListView.delegate = self;
    [self setupBottomBarUI];
    [self setupDefaulNoteView];
    [self setupUserTableView];
    [self setUpChatList];
    [self setupFileListView];
    [self setupExcelSheetListView];
    [self setupPageControlView];
    [self setupDrawingToolView];
    [self handelFileShareAuthority:self.currentUserModel.role == ZegoUserRoleTypeTeacher changeTool:YES];
    [self setupPreviewManager];
    [self setupToggleCoverViewTapGestureRecognizer];
}

#pragma --mark  DataRequest & StatusSyn

// 获取房间内所有用户状态。
- (void)loadRoomMemberListComplement:(void(^)(BOOL success))complement {
    
    ZegoClassCommand *roomMemberListCommand = [ZegoClassCommand getAttendeeListCommandWithUserID:self.currentUserModel.uid roomID:self.roomId classType:self.classType];
    @weakify(self);
    [ZegoNetworkManager requestWithCommand:roomMemberListCommand success:^(ZegoResponseModel *response) {
        @strongify(self);
        if (response.code == 0) {
            DLog(@"获取房间成员列表成功。");
            ZegoRoomMemberListRspModel *rsp = [ZegoRoomMemberListRspModel yy_modelWithJSON:response.data];
            [self comprehensiveSortRoomMember:rsp.attendeeList updateLocalDisplay:YES operationType:0];
            
            self.userTableView.roomMemberArray = self.roomMemberArray;
            [self.bottomBar refreshUserCount:self.roomMemberArray.count];
            
        }
        if (complement) {
            complement(response.code == 0);
        }
    } failure:^(ZegoResponseModel *response) {
        @strongify(self);
        DLog(@"获取房间成员列表失败。");
        if (complement) {
            complement(response.code == 0);
        }
    }];
}

//对成员列表进行综合排序，同时更新本地设备状态
- (void)comprehensiveSortRoomMember:(NSArray *)roomMember updateLocalDisplay:(BOOL)update operationType:(NSInteger)operationType
{
    //重新对老师和自己进行排序
    ZegoRoomMemberInfoModel *teacher = nil;
    ZegoRoomMemberInfoModel *mySelf = nil;
    NSMutableArray *joinLiveArray = [NSMutableArray array];
    NSMutableArray *notJoinLiveArray = [NSMutableArray array];
    NSMutableArray *resultArray = [NSMutableArray array];
    for (int i = 0; i < roomMember.count; i++) {
        ZegoRoomMemberInfoModel *model = roomMember[i];
        if (model.uid == self.currentUserModel.uid) {
//            mySelf = model;
            if (update) {
                [self updateLocalDisplayAndDeviceStatus:model operationType:operationType];
                [self updateUserLocalModel:model];
            }
//            continue;
        }
        // 无需把自己的麦位前置
        if (model.role == ZegoUserRoleTypeTeacher) {
            teacher = model;
            continue;
        }
        if ([model isCameraOn] || [model isMicOn]) {
            [joinLiveArray addObject:model];
        } else {
            [notJoinLiveArray addObject: model];
        }
         
    }
    if (teacher) {
        [resultArray addObject:teacher];
        self.streamTableView.teacherModel = teacher;
    }
    if (mySelf) {
        [resultArray addObject:mySelf];
    }
    [self accordLoginTimeSortMemberArray:joinLiveArray];
    [self accordLoginTimeSortMemberArray:notJoinLiveArray];
    [resultArray addObjectsFromArray:joinLiveArray];
    [resultArray addObjectsFromArray:notJoinLiveArray];
    self.roomMemberArray = resultArray;
    self.userTableView.roomMemberArray = resultArray;
}

//按照登录时间排序
- (void)accordLoginTimeSortMemberArray:(NSMutableArray *)memberArray
{
    if (memberArray.count > 0) {
        for (int i = 1; i < memberArray.count ; i++) {
            for (int j = 0; j < memberArray.count -1; j++) {
                ZegoRoomMemberInfoModel *model = memberArray[j];
                ZegoRoomMemberInfoModel *compare = memberArray[j + 1];
                if (compare.loginTimer < model.loginTimer) {
                    [memberArray exchangeObjectAtIndex:i withObjectAtIndex:j];
                }
            }
        }
    }
}

//获取已经上麦位的用户列表
- (void)loadJoinLiveListComplement:(void(^)(BOOL success))complement {
    
    ZegoClassCommand *joinLiveListCommand = [ZegoClassCommand getJoinLiveListCommandWithUserID:self.currentUserModel.uid roomID:self.roomId classType:self.classType];
    @weakify(self);
    [ZegoNetworkManager requestWithCommand:joinLiveListCommand success:^(ZegoResponseModel *response) {
        @strongify(self);
        if (response.code == 0) {
            DLog(@"获取连麦成员列表成功。");
            ZegoJoinLiveListRspModel *rsp = [ZegoJoinLiveListRspModel yy_modelWithJSON:response.data];
            
            NSMutableArray *wrappers = [NSMutableArray array];
            //构造列表显示模型
            for (ZegoRoomMemberInfoModel *model in rsp.joinLiveList) {
                ZegoStreamWrapper *wrapper = [[ZegoStreamWrapper alloc] initWithiStream:nil ];
                [wrappers addObject:wrapper];
                wrapper.userStatusModel = model;
                if (model.uid == self.currentUserModel.uid) {
                    wrapper.userStatusModel.isMyself = YES;
                    wrapper.streamStatusType = ZegoStreamStatusTypeIdle;
                }

                for (ZegoLiveStream *stream  in self.streamList) {
                    if (stream.userID.integerValue == model.uid) {
                        wrapper.stream = stream;
                        break;
                    }
                }
            }
            self.joinLiveMemberArray = wrappers;
            [self.streamTableView setupStreamDataSources:wrappers];

        }
        if (complement) {
            complement(response.code == 0);
        }
    } failure:^(ZegoResponseModel *response) {
        @strongify(self);
        DLog(@"获取连麦成员列表失败。");
//        [ZegoToast showText:@"获取连麦成员列表失败"];
        if (complement) {
            complement(response.code == 0);
        }
    }];
}

//获取指定用户信息
//- (void)loadUserInfoByUserId:(NSString *)uid {
//
//    ZegoClassCommand *targetUserCommand = [ZegoClassCommand getUserInfoCommandWithUserID:self.currentUserModel.uid roomID:self.roomId targetUserID:uid];
//    [ZegoNetworkManager requestWithCommand:targetUserCommand success:^(ZegoResponseModel *response) {
//        ZegoRoomMemberInfoModel *model = [ZegoRoomMemberInfoModel yy_modelWithDictionary:response.data];
//        ZegoStreamWrapper *wrapper = [[ZegoStreamWrapper alloc] initWithiStream:nil];
//        wrapper.userStatusModel = model;
//        [self.roomMemberArray addObject:model];
//        [self.joinLiveMemberArray addObject:wrapper];
//        for (ZegoLiveStream *stream in self.streamList) {
//            if (stream.userID.integerValue == model.uid) {
//                wrapper.stream = stream;
//                break;
//            }
//        }
//        [self.streamTableView addStream:wrapper];
//        [self.userTableView reloadData];
//        DLog(@"获取指定用户信息成功");
//    } failure:^(ZegoResponseModel *response) {
//        DLog(@"获取指定用户信息失败");
//    }];
//}

//同步自己或老师设置学生 摄像头，麦克风和文件共享状态。
- (void)setupRoomMemberAuthority:(ZegoRoomMemberInfoModel *)userModel complement:(void(^)(BOOL success))complementBlock {
    ZegoClassCommand *setUserStatusCommand = [ZegoClassCommand setUserInfoCommandWithUserID:self.currentUserModel.uid roomID:self.roomId targetUserID:userModel.uid classType:self.classType isCameraOn:userModel.camera isMicOn:userModel.mic canShare:userModel.canShare];
    [ZegoNetworkManager requestWithCommand:setUserStatusCommand success:^(ZegoResponseModel *response) {
        if (response.code == 0) {
            DLog(@"设置用户状态成功\n%@。",setUserStatusCommand.paramDic);
        }
        if (complementBlock) {
            complementBlock(response.code == 0);
        }
    } failure:^(ZegoResponseModel *response) {
        DLog(@"设置用户状态失败\n%@, response: %@。",setUserStatusCommand.paramDic, response);
        
        if (complementBlock) {
            complementBlock(NO);
        }
    }];
}

//处理房间成员状态更新逻辑
- (void)handleRoomMemberStatusChangeWithData:(NSDictionary *)data {
    ZegoRoomMemberUpdateRspModel *rsp = [ZegoRoomMemberUpdateRspModel yy_modelWithDictionary:data];
    BOOL updateLocalDisplay = NO;
    for (ZegoRoomMemberInfoModel *updateModel in rsp.users) {
        if (updateModel.uid == self.currentUserModel.uid) {
            updateLocalDisplay = YES;
        }
        //更新成员列表中的用户状态
        for (int i = 0; i < self.roomMemberArray.count; i++) {
            ZegoRoomMemberInfoModel *localModel = self.roomMemberArray[i];
            if (updateModel.uid == localModel.uid) {
                [self.roomMemberArray replaceObjectAtIndex:i withObject:updateModel];
                    
                break;
            }
        }
        //同步修改连麦列表中的成员状态
        for (int i = 0; i < self.joinLiveMemberArray.count; i++) {
            ZegoStreamWrapper *wrapper = self.joinLiveMemberArray[i];
            if (updateModel.uid == wrapper.userStatusModel.uid) {
                wrapper.userStatusModel = updateModel;
                DLog(@"成员状态变更");
                [self.streamTableView updateStream:wrapper];
                break;
            }
        }
    }
    NSInteger operationType = 0;
    if (self.currentUserModel.uid != rsp.operatorUID  && updateLocalDisplay) {
        operationType = rsp.type;
    }
 
    [self comprehensiveSortRoomMember:self.roomMemberArray.copy updateLocalDisplay:updateLocalDisplay operationType:operationType];
}

//处理房间成员更新逻辑
- (void)handleRoomMemberUpdateWithData:(NSDictionary *)data {
    ZegoRoomMemberInfoModel *model = [ZegoRoomMemberInfoModel yy_modelWithDictionary:data];

    if (model.delta == -1) {
        for (ZegoRoomMemberInfoModel *localModel in self.roomMemberArray) {
            if (model.uid == localModel.uid) {
                [self.roomMemberArray removeObject:localModel];
                break;
            }
        }
        [self.userTableView reloadData];
        if (model.role == ZegoUserRoleTypeTeacher) {
            self.streamTableView.teacherModel = nil;
        }
    } else if (model.delta == 1){
        [self.roomMemberArray addObject:model];
        if (model.role == ZegoUserRoleTypeTeacher) {
            self.streamTableView.teacherModel = model;
        }
        [self comprehensiveSortRoomMember:self.roomMemberArray.copy updateLocalDisplay:NO operationType:0];
    }
    
    [self.bottomBar refreshUserCount:self.roomMemberArray.count];
    [self.chatList updateRoomMemberInfo:model];
}

//处理连麦成员逻辑
- (void)handleJoinLiveMemberUpdateWithData:(NSDictionary *)data {
    ZegoRoomMemberInfoModel *model = [ZegoRoomMemberInfoModel yy_modelWithDictionary:data];
    //不管是新增还是删除，如果本地已经有数据，先删除，避免出现重复数据
    for (ZegoStreamWrapper *localModel in self.joinLiveMemberArray) {
        if (model.uid == localModel.userStatusModel.uid) {
            [self.streamTableView removeStream:localModel];
            [ZegoLiveCenter stopPlayingStream:localModel.stream.streamID];
            [self.joinLiveMemberArray removeObject:localModel];
            break;
        }
    }
    if (model.delta == -1) {
        for (ZegoLiveStream *stream  in self.streamList) {
            if (stream.userID.integerValue == model.uid) {
                [ZegoLiveCenter stopPlayingStream:stream.streamID];
                break;;
            }
        }
    } else if (model.delta == 1){
        ZegoStreamWrapper *wrapper = [[ZegoStreamWrapper alloc] initWithiStream:nil];
        wrapper.userStatusModel = model;
        if (model.uid == self.currentUserModel.uid) {
            wrapper.streamStatusType = ZegoStreamStatusTypeIdle;
            wrapper.userStatusModel.isMyself = YES;
        }
        [self.joinLiveMemberArray addObject:wrapper];
        [self.streamTableView addStream:wrapper];
    }
    [self comprehensiveSortRoomMember:self.roomMemberArray.copy updateLocalDisplay:NO operationType:0];
}

//处理连麦成员逻辑
- (void)handleClassOverWithData:(NSDictionary *)data {
    [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"room_tip_teacher_finished_teaching"] hasCancelButton:NO onTapYes:^{
        [self leaveRoom];
    }];
}

//更新本地设备及显示状态
- (void)updateLocalDisplayAndDeviceStatus:(ZegoRoomMemberInfoModel *)updateModel operationType:(NSInteger)operationType {
    
    if (operationType == 4 ) {
        if (updateModel.canShare == 2) {
            [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_permission"]];
        } else {
            [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_revoke_share"]];
        }
            
        
    }
    if (updateModel.canShare != self.currentUserModel.canShare) {
        [self handelFileShareAuthority:updateModel.canShare == 2 changeTool:YES];
    }
    
    //如果本地状态与远端状态不一致 或 本地设备状态与更新状态不一致，则认为需要更改设备状态
    if (updateModel.camera != self.currentUserModel.camera ) {
        @weakify(self);
        [self checkAuthorityForMediaType:AVMediaTypeVideo showTip:NO complement:^(BOOL authority) {
            @strongify(self);
            if (authority) {
                if (operationType == 2) {
                    if (updateModel.camera == 2) {
                        [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_turned_on_camera"]];
                    } else {
                        [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_turned_off_camera"]];
                    }
                }
                [self.bottomBar setupCameraOpen:updateModel.camera == 2 react:NO];
            } else {
                //如果本地没有权限 需要发送消息回置为关闭状态
                self.currentUserModel.camera = 1;
                [self setupRoomMemberAuthority:self.currentUserModel complement:nil];
            }
        }];
    }
    //如果本地状态与远端状态不一致 或 本地设备状态与更新状态不一致，则认为需要更改设备状态
    if (updateModel.mic != self.currentUserModel.mic ) {
        @weakify(self);
        [self checkAuthorityForMediaType:AVMediaTypeAudio showTip:NO complement:^(BOOL authority) {
            @strongify(self);
            if (authority) {
                if (operationType == 3) {
                    if (updateModel.mic == 2) {
                        [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_turned_on_mic"]];
                    } else {
                        [ZegoToast showText:[NSString zego_localizedString:@"room_student_tip_turned_off_mic"]];
                    }
                    
                }
                [self.bottomBar setupMicOpen:updateModel.mic == 2 react:NO];
            } else {
                //如果本地没有权限 需要发送消息回置为关闭状态
                self.currentUserModel.mic = 1;
                [self setupRoomMemberAuthority:self.currentUserModel complement:nil];
            }
        }];
    }

    
    [self refreshTopBar];
    [self.boardListView refreshWithBoardContainerModels:self.whiteBoardService.orderedBoardModelContainers selected:self.whiteBoardService.currentContainer];
}

//更新本地自己的数据模型
- (void)updateUserLocalModel:(ZegoRoomMemberInfoModel *)model {
    
    self.currentUserModel = model;
    self.currentUserModel.isMyself = YES;
    self.streamTableView.currentModel = self.currentUserModel;
    self.bottomBar.currentModel = self.currentUserModel;

}

// 处理文件权限逻辑
- (void)handelFileShareAuthority:(BOOL)allow changeTool:(BOOL)change{
    self.drawingToolView.hidden = !allow;
    if (change) {
        if (allow) {
            [self.drawingToolView changeToItemType:ZegoDrawingToolViewItemTypePath response:YES];
        } else {
            [self.drawingToolView changeToItemType:ZegoDrawingToolViewItemTypeDrag response:YES];
        }
        [self.whiteBoardService enableCurrentContainer:allow];
    }
    
    [self handleWhiteBoardContentDisplayLogic:allow];
    [self handleTopBarDisplayLogic:allow];
    
}

- (void)handleWhiteBoardContentDisplayLogic:(BOOL)display {
    if (self.whiteBoardService.currentContainer.isDynamicPPT && display) {
        self.pageControlCarrierView.hidden = NO;
    } else {
        self.pageControlCarrierView.hidden = YES;
    }
}

- (void)handleTopBarDisplayLogic:(BOOL)display
{
    //缩略图仅支持 （动态/静态）PPT，PDF
    if ( display && (self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypePDF || self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypePPT || self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypeDynamicPPTH5 || self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypeCustomH5)) {
        self.topBar.canPreview = YES;
        if (self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypeDynamicPPTH5 || self.whiteBoardService.currentContainer.fileInfo.fileType == ZegoDocsViewFileTypeCustomH5 ) {
            self.pageControlCarrierView.hidden = NO;
        }
    } else {
        self.pageControlCarrierView.hidden = YES;
        self.topBar.canPreview = NO;
    }
    self.topBar.canShare = display;
    if (self.previewManager.isShow && !display) {
        [self.previewManager hiddenPreview];
    }
}

#pragma mark - Action

- (void)logoutRoomEndClass:(BOOL)endClass {
    if ([self.whiteBoardService.currentContainer isDynamicPPT]) {
        [self.whiteBoardService stopDynamicPPTAnimation];
    }
    
    ZegoClassCommand *command = [ZegoClassCommand leaveRoomCommandWithUserID:self.currentUserModel.uid roomID:self.roomId classType:self.classType];
    if (endClass) {
        command = [ZegoClassCommand endTeachingCommandWithUserID:self.currentUserModel.uid roomID:self.roomId classType:self.classType];
    }
    [ZegoNetworkManager requestWithCommand:command success:^(ZegoResponseModel *response) {
        [self leaveRoom];
    } failure:^(ZegoResponseModel *response) {
        [self leaveRoom];
//        [ZegoToast showText:@"退出课堂失败，请重试"];
    }];
    
}

- (void)leaveRoom {
    [ZegoToast dismissStickyAnimation:NO];
    [ZegoHttpHeartbeat stop];
    [self.whiteBoardService.currentContainer.whiteboardView removeLaser];
    [self reset];
    [ZegoLiveCenter stopPublishingStream];
    [ZegoLiveCenter stopPreview];
    [ZegoLiveCenter logoutRoom:self.roomId];
    [ZegoLiveCenter setDelegate:nil];
    [ZegoWhiteboardManager sharedInstance].toolType = ZegoDrawingToolViewItemTypePath;
    [ZegoWhiteboardManager sharedInstance].isFontBold = NO;
    [ZegoWhiteboardManager sharedInstance].isFontItalic = NO;
    [[ZegoWhiteboardManager sharedInstance] clear];
    [ZegoLiveCenter setFrontCam:YES];
    [[ZegoDocsViewManager sharedInstance] uninit];
    [[ZegoWhiteboardManager sharedInstance] uninit];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openCamera:(void(^)(BOOL success))complementBlock {
    
    [self checkAuthorityForMediaType:AVMediaTypeVideo showTip:YES complement:^(BOOL authority) {
        if (!authority) {
            if (complementBlock) {
                complementBlock(authority);
            }
            return;
        }
        self.currentUserModel.camera = 2;
        [self setupRoomMemberAuthority:self.currentUserModel complement:^(BOOL success) {
            if (!success) {
                self.currentUserModel.camera = 1;
                NSInteger count = [self getJoinLiveStudensCount];
                if (count >= 3) {
                    [ZegoToast showText:[NSString zego_localizedString:@"room_tip_channels"]];
                } else {
                    [ZegoToast showText:[NSString zego_localizedString:@"room_open_camera_failed"]];
                }
            }
            [ZegoLiveCenter muteVideo:!success];
            if (complementBlock) {
                complementBlock(success);
            }
        }];
    }];
}

- (NSInteger)getJoinLiveStudensCount
{
    NSInteger count = 0;
    for (ZegoStreamWrapper *model in self.joinLiveMemberArray) {
        if (model.userStatusModel.role == ZegoUserRoleTypeStudent) {
            count++;
        }
    }
    return count;
}

- (void)closeCamera:(void(^)(BOOL success))complementBlock {
    
    self.currentUserModel.camera = 1;
    @weakify(self);
    [self setupRoomMemberAuthority:self.currentUserModel complement:^(BOOL success) {
        @strongify(self);
        if (!success) {
            self.currentUserModel.camera = 2;
            [ZegoToast showText:[NSString zego_localizedString:@"room_close_camera_failed"]];
        }
        [ZegoLiveCenter muteVideo:success];
        if (complementBlock) {
                complementBlock(success);
        }
    }];
}

- (void)openMic:(void(^)(BOOL success))complementBlock {
    @weakify(self);
    [self checkAuthorityForMediaType:AVMediaTypeAudio showTip:YES complement:^(BOOL authority) {
        @strongify(self);
        if (!authority) {
            if (complementBlock) {
                complementBlock(authority);
            }
            return;
        }
        self.currentUserModel.mic = 2;
        [self setupRoomMemberAuthority:self.currentUserModel complement:^(BOOL success) {
            @strongify(self);
            if (!success) {
                self.currentUserModel.mic = 1;
                
                NSInteger count = [self getJoinLiveStudensCount];
                if (count >= 3) {
                    [ZegoToast showText:[NSString zego_localizedString:@"room_tip_channels"]];
                } else {
                    [ZegoToast showText:[NSString zego_localizedString:@"room_open_mic_failed"]];
                }
            }
            [ZegoLiveCenter muteAudio:!success];
            if (complementBlock) {
                complementBlock(success);
            }
        }];
    }];
}

- (void)closeMic:(void(^)(BOOL success))complementBlock {

    self.currentUserModel.mic = 1;
    @weakify(self);
    [self setupRoomMemberAuthority:self.currentUserModel complement:^(BOOL success) {
        @strongify(self);
        if (!success) {
            self.currentUserModel.mic = 2;
            [ZegoToast showText:[NSString zego_localizedString:@"room_close_mic_failed"]];
        }
        [ZegoLiveCenter muteAudio:success];
        if (complementBlock) {
            complementBlock(success);
        }
    }];
}

- (void)checkAuthorityForMediaType:(AVMediaType)mediaType showTip:(BOOL)show complement:(void(^)(BOOL authority))complement {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if (status != AVAuthorizationStatusAuthorized && show) {
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!granted) {
                    [self showAuthorityTip:mediaType];
                }
                if (complement) {
                    complement(granted);
                }
            });
        }];
    } else {
        if (complement) {
            complement(status == AVAuthorizationStatusAuthorized);
        }
    }
}

- (void)showAuthorityTip:(AVMediaType)mediaType {
    NSString *tipTitle = nil;
    NSString *tipMessage = nil;
    if (mediaType == AVMediaTypeVideo) {
        tipTitle = [NSString zego_localizedString:@"NSCameraUsageDescription"];
        tipMessage = [NSString zego_localizedString:@"setting_private_camera"];
    } else if (mediaType == AVMediaTypeAudio) {
        tipTitle = [NSString zego_localizedString:@"NSMicrophoneUsageDescription"];
        tipMessage = [NSString zego_localizedString:@"setting_private_mic"];
    }
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:tipTitle message:tipMessage preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:[NSString zego_localizedString:@"setting_cancel"] style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancel];
    UIAlertAction *setting = [UIAlertAction actionWithTitle:[NSString zego_localizedString:@"setting_go"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if( [[UIApplication sharedApplication] canOpenURL:url] ) {
            
            if (@available(iOS 10.0, *)) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            } else {
                [[UIApplication sharedApplication] openURL:url];
            }
        }
        
    }];
    [alert addAction:setting];
    [self presentViewController:alert animated:NO completion:nil];
}

- (void)changeDocWhiteBoardToNextStep {
    @weakify(self);
    [self.whiteBoardService.currentContainer nextPPTStepCompletionBlock:^(BOOL isScrollSuccess) {
        @strongify(self);
        [self refreshTopBar];
    }];
}

- (void)changeDocWhiteBoardToPreStep {
    @weakify(self);
    [self.whiteBoardService.currentContainer prePPTStepCompletionBlock:^(BOOL isScrollSuccess) {
        @strongify(self);
        [self refreshTopBar];
    }];
}

- (void)changeWhiteBoardToNextPage {
    @weakify(self);
    [self.whiteBoardService.currentContainer nextPageCompletionBlock:^(BOOL isScrollSuccess) {
        @strongify(self);
        [self refreshTopBar];
        if (self.previewManager.isShow) {
            [self.previewManager setCurrentPageCount:self.whiteBoardService.currentContainer.docsView.currentPage-1];
        }
    }];
}

- (void)changeWhiteBoardToPreviousPage {
    @weakify(self);
    [self.whiteBoardService.currentContainer prePageCompletionBlock:^(BOOL isScrollSuccess) {
        @strongify(self);
        [self refreshTopBar];
        if (self.previewManager.isShow) {
            [self.previewManager setCurrentPageCount:self.whiteBoardService.currentContainer.docsView.currentPage -1];
        }
    }];
}

- (void)showFileList {
    [ZegoViewAnimator showView:self.fileListView fromRightSideInView:self.view];
    BOOL isDocTest = [ZegoClassEnvManager shareManager].docsSeviceTestEnv;
    @weakify(self);
    [[ZegoDefaultFileLoader defaultLoader] loadFileListWithEnv:isDocTest complete:^(NSArray<ZegoFileInfoModel *> * _Nonnull fileModels, NSError * _Nonnull error) {
        @strongify(self);
        if (fileModels) {
            [self.fileListView updateWithFiles:fileModels];
        }
    }];
}


- (void)toggleCoverView {
    if (self.topCoverView) {
        [ZegoViewAnimator toggleView:self.topCoverView inView:self.view autoHide:YES];
    } else {
        @weakify(self);
        ZegoClassRoomCoverView *cover = [[ZegoClassRoomCoverView alloc] initWithTitle:self.roomId exitButtonTapped:^{
            @strongify(self);
            if (self.currentUserModel.role == 1) { //1：老师
                [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"room_exit_class"] subTitle:[NSString zego_localizedString:@"room_tip_exit_class"] onTapYes:^{
                    @strongify(self);
                    [self logoutRoomEndClass:YES];
                } onTapSecondButton:^{
                    @strongify(self);
                    [self logoutRoomEndClass:NO];
                } themeStyle:ZegoAlertViewThemeStyleTeacher];
            } else { //2：学生
                [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"room_exit_class"] subTitle:[NSString zego_localizedString:@"room_tip_are_u_sure_exit"] onTapYes:^{
                    @strongify(self);
                    [self logoutRoomEndClass:NO];
                } onTapSecondButton:^{
                    @strongify(self);
                    DLog(@"取消");
                } themeStyle:ZegoAlertViewThemeStyleStudent];
            }
            
        }];
        self.topCoverView = cover;
        [ZegoViewAnimator toggleView:cover inView:self.view autoHide:YES];
    }
}

- (IBAction)onDefaultBoardButtonTapped:(id)sender {
    if (self.currentUserModel.canShare == 2) {
        [self.whiteBoardService addWhiteboard];
    } else {
        [ZegoToast showText:[NSString zego_localizedString:@"wb_tip_not_allowed_share"]];
    }
}

- (IBAction)onDefaultFileButtonTapped:(id)sender {
    if (self.currentUserModel.canShare == 2) {
        [self showFileList];
    } else {
        [ZegoToast showText:[NSString zego_localizedString:@"wb_tip_not_allowed_share"]];
    }
}

#pragma mark - Private File

- (void)refreshExcelSheetListView {
    if (self.whiteBoardService.currentContainer.docsView.sheetNameList && self.whiteBoardService.currentContainer.docsView.sheetNameList.count > 1) {
        [self.excelSheetListView updateViewWithSheetNameList:self.whiteBoardService.currentContainer.docsView.sheetNameList selectedSheet:@""];
    } else {
        [self.excelSheetListView updateViewWithSheetNameList:@[] selectedSheet:@""];
    }
}
#pragma mark - Private WhiteBoard

- (void)loadWhiteboardListWithCompleteBlock:(ZegoGetWhiteboardListBlock)completeBlock {
    @weakify(self);
    [[ZegoWhiteboardManager sharedInstance] getWhiteboardListWithCompleteBlock:^(ZegoWhiteboardViewError errorCode, NSArray *whiteBoardList) {
        @strongify(self);
        [self.activityIndicator stopAnimating];
        self.defaultNoteView.hidden = whiteBoardList.count > 0;
        if (errorCode == 0) {
            [self reset];
            if (whiteBoardList.count) {
                [self.whiteBoardService createContainersWithWhiteBoardList:whiteBoardList];
            }
        }
        if (completeBlock) {
            completeBlock(errorCode, whiteBoardList);
        }
    }];
}

- (void)refreshTopBar {
    if (self.whiteBoardService.currentContainer) {
        self.topBar.hidden = NO;
    } else {
        self.topBar.hidden = YES;
    }
    CGFloat xPercent = self.whiteBoardService.currentContainer.whiteboardView.contentOffset.x / self.whiteBoardService.currentContainer.whiteboardView.contentSize.width;
    if (!self.whiteBoardService.currentContainer.whiteboardView) {
        return;
    }
    int currentIndex = 0, totalCount = 0;
    NSString *sheetName = nil;
    if (self.whiteBoardService.currentContainer.isFile) {
    
        totalCount = (int)self.whiteBoardService.currentContainer.docsView.pageCount;
        if (self.whiteBoardService.currentContainer.isExcel) {
            currentIndex = -1;
            sheetName = self.whiteBoardService.currentContainer.fileInfo.fileName;
        } else {
            DLog(@"刷新后的PAGE：%ld STEP: %ld", (long)self.whiteBoardService.currentContainer.docsView.currentPage, (long)self.whiteBoardService.currentContainer.docsView.currentStep);
            currentIndex = (int)MAX(self.whiteBoardService.currentContainer.docsView.currentPage - 1, 0);
        }
        
    } else {
        totalCount = 5;
        currentIndex = (int)roundf((xPercent * 10)/2.0);
    }
    //当更换白板时 如果此时预览视图处于显示状态，则重置显示样式
    if (!self.previewManager.isShow) {
        [self.topBar resetPreviewDisplay:NO];
    }
    [self.topBar refreshWithTitle:self.whiteBoardService.currentContainer.whiteBoardName currentIndex:currentIndex totalCount:totalCount sheetName:sheetName];
}

- (void)handleDynamicPPTClickLogicIfNeededWithContainer:(ZegoBoardContainer *)container {
    if (!container) {
        return;
    }
    //如果设置的不是动态ppt, 且当前 drawTool 选择的是'点击'工具的话, 则切换到画笔
    BOOL changeToDynamicPPT = container.isDynamicPPT;
    if ([ZegoWhiteboardManager sharedInstance].toolType == ZegoWhiteboardViewToolClick &&
        !changeToDynamicPPT) {
        [self.drawingToolView changeToItemType:ZegoDrawingToolViewItemTypePath response:YES];
    }
    // 如果当前是 动态ppt 且选择了点击工具, 则需要关掉白板的用户交互, 以响应 动态ppt 的点击事件
    if ([ZegoWhiteboardManager sharedInstance].toolType == ZegoWhiteboardViewToolClick) {
        [self.whiteBoardService.currentContainer.docsView setScaleEnable:NO];
        self.whiteBoardService.currentContainer.whiteboardView.userInteractionEnabled = NO;
    }else {
        [self.whiteBoardService.currentContainer.docsView setScaleEnable:YES];
        self.whiteBoardService.currentContainer.whiteboardView.userInteractionEnabled = YES;
    }
}

#pragma mark - ZegoHttpHeartbeatDelegate

- (void)httpHeartbeatDidInactivate {
    [ZegoLiveCenter writeLog:1 content:[NSString stringWithFormat:@"[DEMO]httpHeartbeatDidInactivate roomID:%@", self.roomId]];
    DLog(@"httpHeartbeatDidInactivate");
//    [self reLoginFailed];
}

- (void)httpHeartbeatDidReceived:(ZegoHttpHeartbeatResponse *)heartBeatResponse needUpdateAttendeeList:(BOOL)needUpdateAttendeeList needUpdateJoinLiveList:(BOOL)needUpdateJoinLiveList {
    if (needUpdateAttendeeList) {
        [self loadRoomMemberListComplement:nil];
    }
    if (needUpdateJoinLiveList) {
        [self loadJoinLiveListComplement:nil];
    }
}

#pragma mark - ZegoWhiteboardViewDelegate

- (void)onScrollWithHorizontalPercent:(CGFloat)horizontalPercent verticalPercent:(CGFloat)verticalPercent whiteboardView:(ZegoWhiteboardView *)whiteboardView {
    [self refreshTopBar];
    if (self.whiteBoardService.currentContainer) {
        self.topBar.hidden = NO;
    } else {
        self.topBar.hidden = YES;
    }
    if (!self.whiteBoardService.currentContainer.whiteboardView) {
        return;
    }
    CGFloat xPercent = self.whiteBoardService.currentContainer.whiteboardView.contentOffset.x / self.whiteBoardService.currentContainer.whiteboardView.contentSize.width;

    int currentIndex = 0, totalCount = 0;
    NSString *sheetName = nil;
    if (self.whiteBoardService.currentContainer.isFile) {
        totalCount = (int)self.whiteBoardService.currentContainer.docsView.pageCount;
        if (self.whiteBoardService.currentContainer.isExcel) {
            currentIndex = -1;
            sheetName = self.whiteBoardService.currentContainer.fileInfo.fileName;
        } else {
            currentIndex = (int)MAX(self.whiteBoardService.currentContainer.docsView.currentPage - 1, 0);
            
        }
    } else {
        totalCount = 5;
        currentIndex = (int)roundf((xPercent * 10)/2.0);
    }
    if (self.previewManager.isShow) {
        [self.previewManager setCurrentPageCount:currentIndex];
    }
    [self.topBar refreshWithTitle:self.whiteBoardService.currentContainer.whiteBoardName currentIndex:currentIndex totalCount:totalCount sheetName:sheetName];
}

- (void)onScaleChangedWithScaleFactor:(CGFloat)scaleFactor scaleOffsetX:(CGFloat)scaleOffsetX scaleOffsetY:(CGFloat)scaleOffsetY whiteboardView:(nonnull ZegoWhiteboardView *)whiteboardView {
    
}

#pragma mark - ZegoDocsViewDelegate
- (void)onStepChangeForClick {
    [self refreshTopBar];
}

#pragma mark - ZegoWhiteboardManagerDelegate
- (void)onError:(ZegoWhiteboardViewError)errorCode whiboardView:(ZegoWhiteboardView *)whiboardView {
    //    [ZegoToast showText:@"白板滑动错误回调"];
}

- (void)onWhiteboardAdd:(ZegoWhiteboardView *)whiteboardView {
    [self.whiteBoardService addWhiteBoardWithWhiteBoardView:whiteboardView];
}

- (void)onWhiteboardRemoved:(ZegoWhiteboardID)whiteboardID {
    [self.whiteBoardService removeWhiteBoardWithWhiteboardID:whiteboardID syncMessage:NO];
}

// 白板的回调, 需要调用 docsView -playAnimation: 方法
- (void)onPlayAnimation:(NSString *)animationInfo {
    [self.whiteBoardService animateDynamicPPTWithAnimationInfo:animationInfo];
}


#pragma mark - ZegoWhiteBoardServiceDelegate

- (void)onWhiteboardContainerChanged:(ZegoBoardContainer *)container {
    [self handleDynamicPPTClickLogicIfNeededWithContainer:container];
    container.whiteboardViewUIDelegate = self;
    container.docsViewUIDelegate = self;
    [container setupWhiteboardOperationMode:(_drawingToolView.isDragEnable?ZegoWhiteboardOperationModeScroll : ZegoWhiteboardOperationModeDraw) |ZegoWhiteboardOperationModeZoom];
    [self.drawingToolViewService refreshBoardContainer:container];
        
    self.defaultNoteView.hidden = container != nil;
    self.drawingToolView.hidden = !(self.currentUserModel.canShare == 2);
    [self refreshExcelSheetListView];
    [self.boardListView refreshWithBoardContainerModels:self.whiteBoardService.orderedBoardModelContainers selected:container];
    [self.previewManager hiddenPreview];
    //缩略图仅支持 （动态/静态）PPT，PDF
    if (container.docsView && self.currentUserModel.canShare == 2 && (container.fileInfo.fileType == ZegoDocsViewFileTypePDF || container.fileInfo.fileType == ZegoDocsViewFileTypePPT || container.fileInfo.fileType == ZegoDocsViewFileTypeDynamicPPTH5 || container.fileInfo.fileType == ZegoDocsViewFileTypeCustomH5)) {
        self.topBar.canPreview = YES;
        
    } else {
        self.topBar.canPreview = NO;
    }
    [self refreshTopBar];
    [self handelFileShareAuthority:self.currentUserModel.canShare == 2 changeTool:NO];
}

- (void)onChangedOrderedBoardContainerModels:(NSArray<ZegoWhiteBoardViewContainerModel *> *)orderedBoardModelContainers {
    [self.boardListView refreshWithBoardContainerModels:orderedBoardModelContainers selected:self.whiteBoardService.currentContainer];
    [self refreshExcelSheetListView];
    [self refreshTopBar];
}

- (void)onTapWhiteBoard {
    [self toggleCoverView];
}

#pragma mark - ZegoDrawingToolViewDelegate
- (void)selectItemType:(ZegoDrawingToolViewItemType)itemType selected:(BOOL)isSelected {
    switch (itemType) {
        case ZegoDrawingToolViewItemTypeEraser:
            [self.whiteBoardService deleteSelectedGraphics];
            break;
        case ZegoDrawingToolViewItemTypeSave:
            [self captureWhiteboard];
            break;
        case ZegoDrawingToolViewItemTypeJustTest:
            [self presentJustTestViewController];
            break;
        
            break;
        default:
            break;
    }
}

- (void)uploadFileWithType:(BOOL)isDynamicFile {
    if (self.whiteBoardService.orderedBoardModelContainers.count > 9) {
        [ZegoToast showText:[NSString zego_localizedString:@"wb_tip_exceed_max_number_file"]];
    } else {
        if (isDynamicFile) {
            self.uploadDynamicFile = YES;
        } else {
            self.uploadDynamicFile = NO;
        }
        [self selectFileToUpload];
    }
}

- (void)captureWhiteboard {
    UIView *container = self.whiteBoardService.currentContainer;
    [[ZegoViewCaptor sharedInstance] writeToAlbumWithView:container complete:^(BOOL success, BOOL alert) {
        if (success) {
            [ZegoToast showText:[NSString zego_localizedString:@"wb_tip_save_success"]];
        }else {
            if (alert) {
                [self presentGalleryAuthRequiredAlert];
            }
        }
    }];
}

- (void)presentGalleryAuthRequiredAlert {
    [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"wb_auth_photo"] subTitle:[NSString zego_localizedString:@"wb_tip_allow_access_photo"] onTapYes:^{
        NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        if (@available(iOS 10.0, *)) {
            if( [[UIApplication sharedApplication]canOpenURL:url] ) {
                [[UIApplication sharedApplication]openURL:url options:@{} completionHandler:nil];
            }
        }else {
            if( [[UIApplication sharedApplication]canOpenURL:url] ) {
                [[UIApplication sharedApplication]openURL:url];
            }
        }
    } onTapSecondButton:^{
        [ZegoAlertView dismiss];
    } themeStyle:ZegoAlertViewThemeStyleGalleryAuth];
}

- (void)presentJustTestViewController {
    NSNumber *whiteboardEnable = [self.whiteBoardService.currentContainer.whiteboardView valueForKey:@"enableUserOp"];
    NSDictionary *dict = @{
        ZegoJustTestWhiteboardEnabled: whiteboardEnable,
    };
    ZegoClassJustTestViewController *vc = [[ZegoClassJustTestViewController alloc] initWithDict:dict];
    vc.delegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)selectFileToUpload {
    NSArray *documentTypes = @[@"public.content",
                               @"com.adobe.pdf",
                               @"com.microsoft.word.doc",
                               @"com.microsoft.excel.xls",
                               @"com.microsoft.powerpoint.ppt",
                               @"public.image"];
    UIDocumentPickerViewController *documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
    documentPicker.delegate = self;
    if (@available(iOS 11.0, *)) {
        documentPicker.allowsMultipleSelection = NO;
    }
    documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

#pragma mark - UIDocumentPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray <NSURL *>*)urls NS_AVAILABLE_IOS(11_0)
{
    if([urls isKindOfClass:[NSArray class]])
        [self documentPicker:controller didPickDocumentAtURL:urls.firstObject];
}

// 选中icloud里的pdf文件 iOS 8-11
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    BOOL fileUrlAuthozied = [url startAccessingSecurityScopedResource];
    if(fileUrlAuthozied){
        NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
        NSError *error;
        __weak typeof(self) weakSelf = self;
        [fileCoordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *newURL) {
            [weakSelf uploadFileWithUrl:newURL ];
        }];
        if (error) {
            [url stopAccessingSecurityScopedResource];
        }
    } else {
        NSLog(@"--- no permission ---");
    }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"--- cancel ---");
    //重置上传按钮状态
    [self.drawingToolView enableItemType:ZegoDrawingToolViewItemTypeFileUpload isEnabled:YES];
}


- (void)uploadFileWithUrl:(NSURL *)url
{
    [self.drawingToolView enableItemType:ZegoDrawingToolViewItemTypeFileUpload isEnabled:NO];
    NSLog(@"uploadFileWithUrl, url: %@", [url path]);

    [url startAccessingSecurityScopedResource];
    NSArray *component = [url.path componentsSeparatedByString:@"/"];
    if (component.count < 1) {
        return;
    }
    NSString *lastComponent = component.lastObject;
    NSArray *nameAndType = [lastComponent componentsSeparatedByString:@"."];
    
    if (nameAndType.count < 2) {
        return;
    }
    NSString *fileName = nameAndType.firstObject;
    NSString *fileType = nameAndType.lastObject;
    [ZegoToast showStickyWithMessage:[NSString stringWithFormat:@"%@(%%0)",[NSString zego_localizedString:@"doc_uploading"]] Indicator:YES];
    ZegoDocsViewRenderType type = self.uploadDynamicFile ? ZegoDocsViewRenderTypeDynamicPPTH5 : ZegoDocsViewRenderTypeVectorAndIMG;
    @weakify(self);
    [[ZegoDocsViewManager sharedInstance] uploadFile:[url path] renderType:type completionBlock:^(ZegoDocsViewUploadState state, ZegoDocsViewError errorCode, NSDictionary * _Nonnull infoDictionary) {
        @strongify(self);
        if (errorCode == ZegoDocsViewSuccess) {
            if (state == ZegoDocsViewUploadStateUpload) {
                NSNumber * upload_percent = infoDictionary[UPLOAD_PERCENT];
                NSLog(@"upload_percent is %0.2f",upload_percent.floatValue);
                [ZegoToast updateStickyMessage:[NSString stringWithFormat:@"%@(%.0f%%)",[NSString zego_localizedString:@"doc_uploading"],upload_percent.floatValue * 100]];
                if (upload_percent.floatValue >= 1) {
                    [ZegoToast updateStickyMessage:[NSString zego_localizedString:@"doc_converting"]];
                }
            }else if (state == ZegoDocsViewUploadStateConvert){
                NSString * fileID = infoDictionary[UPLOAD_FILEID];
                ZegoFileInfoModel *fileInfo = [[ZegoFileInfoModel alloc] init];
                fileInfo.fileID = fileID;
                fileInfo.fileName = fileName;
                fileInfo.fileType = [self getFileTypeFromString:fileType];
                [ZegoToast dismissStickyAnimation:YES];
                [self.whiteBoardService addDocBoardWithInfo:fileInfo whiteBoardName:fileInfo.fileName sheetIndex:0 createSheets:YES complete:^(ZegoWhiteboardViewError errorCode) {
                    
                }];
                [self.drawingToolView enableItemType:ZegoDrawingToolViewItemTypeFileUpload isEnabled:YES];
                [self.drawingToolView changeToItemType:self.drawingToolView.currentSelectedIndex response:YES];
            }
        }else{
            NSLog(@"error %lu",(unsigned long)errorCode);
            if (state == ZegoDocsViewUploadStateUpload) {
                [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_uploading_failed"] Indicator:NO];
            } else {
               
                if (errorCode == ZegoDocsViewErrorFileSizeLimit) {
                    [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_uploading_size_limit"] Indicator:NO];
                } else if (errorCode == ZegoDocsViewErrorFileNotExist) {
                    [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_file_not_found"] Indicator:NO];
                } else if (errorCode == ZegoDocsViewErrorFileContentEmpty) {
                    [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_file_empty"] Indicator:NO];
                } else if (errorCode == ZegoDocsViewErrorConvertFail) {
                    [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_formating_failed"] Indicator:NO];
                } else {
                    [ZegoToast showStickyWithMessage:[NSString zego_localizedString:@"doc_file_not_supported"] Indicator:NO];
                }
            }
            [self.drawingToolView enableItemType:ZegoDrawingToolViewItemTypeFileUpload isEnabled:YES];
        }
        [url stopAccessingSecurityScopedResource];
    }];

}

- (ZegoDocsViewFileType)getFileTypeFromString:(NSString *)typeString {
    NSDictionary *typeSummary = @{
        @"xls": @(ZegoDocsViewFileTypeELS),
        @"xlsx": @(ZegoDocsViewFileTypeELS),
        
        @"ppt": @(ZegoDocsViewFileTypePPT),
        @"pptx": @(ZegoDocsViewFileTypePPT),
        
        @"pdf": @(ZegoDocsViewFileTypePDF),
        
        @"doc": @(ZegoDocsViewFileTypeDOC),
        @"docx": @(ZegoDocsViewFileTypeDOC),
        
        @"txt": @(ZegoDocsViewFileTypeTXT),
        
        @"jpg": @(ZegoDocsViewFileTypeIMG),
        @"jpeg": @(ZegoDocsViewFileTypeIMG),
        @"png": @(ZegoDocsViewFileTypeIMG),
        @"bmp": @(ZegoDocsViewFileTypeIMG),
    };
    return [typeSummary[typeString] integerValue];
}

#pragma mark - ZegoFileListDelegate & ZegoSheetListDelegate & ZegoWhiteboardListViewDelegate

- (void)zegoFileListView:(ZegoFileListView *)listView didSelectFile:(ZegoFileInfoModel *)fileModel {
    [self.whiteBoardService zegoFileListViewDidSelectFile:fileModel];
}

- (void)zegoExcelSheetList:(ZegoExcelSheetListView *)listView didSelectSheet:(NSString *)sheetName index:(int)index {
    [self.whiteBoardService zegoExcelSheetListDidSelectSheet:sheetName index:index];
}

- (void)whiteBoardListDidSelectView:(ZegoWhiteBoardViewContainerModel *)whiteBoardViewContainerModel {
    [self.whiteBoardService changeWhiteBoardWithBoardContainer:whiteBoardViewContainerModel.selectedBoardContainer];
    [ZegoViewAnimator hideToRight];
}

- (void)whiteBoardListDidDeleteView:(ZegoWhiteBoardViewContainerModel *)whiteBoardViewContainerModel {
    @weakify(self);
    [ZegoAlertView alertWithTitle:[NSString stringWithFormat:@"%@【%@】？",[NSString zego_localizedString:@"wb_tip_are_u_sure_close"],whiteBoardViewContainerModel.selectedBoardContainer.whiteBoardName] onTapYes:^{
        @strongify(self);
        [self.whiteBoardService removeWhiteBoardWithWhiteBoardViewContainerModel:whiteBoardViewContainerModel];
    }];
    [ZegoViewAnimator hideToRight];
}

#pragma mark - ZegoTopBarDelegate & ZegoBottomBarDelegate & ZegoPageControlViewDelegate

- (void)topBar:(ZegoClassRoomTopBar *)functionCell didSelectAction:(ZegoClassRoomTopActionType)type {
    switch (type) {
        case ZegoClassRoomTopActionTypeBoardList:
            [ZegoViewAnimator showView:self.boardListView fromRightSideInView:self.view];
            break;
        case ZegoClassRoomTopActionTypeSheetList:
            [ZegoViewAnimator showView:self.excelSheetListView fromRightSideInView:self.view];
            break;
        case ZegoClassRoomTopActionTypePreBoard:
            [self changeWhiteBoardToPreviousPage];
            break;
        case ZegoClassRoomTopActionTypeNextBoard:
            [self changeWhiteBoardToNextPage];
            break;
        case ZegoClassRoomTopActionTypePreview:
            if (!self.previewManager.isShow && self.whiteBoardService.currentContainer.docsView) {
                NSArray *thumbnailUrls = [self.whiteBoardService.currentContainer.docsView getThumbnailUrlList];
                [self.previewManager setupPreviewViewFrame:CGRectOffset(self.streamTableView.frame, self.streamTableView.frame.size.width, 0) onSuperView:self.streamTableView.superview withData:thumbnailUrls];
                [self.previewManager showPreviewWithPage:self.whiteBoardService.currentContainer.docsView.currentPage-1];
            } else if (self.previewManager.isShow) {
                [self.previewManager hiddenPreview];
            }
            break;
            
        default:
            break;
    }
}

- (void)bottomBarDidTapBarArea {
    [self toggleCoverView];
}

- (void)bottomBarCell:(ZegoClassRoomBottomBarCell *)functionCell didSelectCellModel:(ZegoClassRoomBottomCellModel *)model {
    @weakify(self);
    switch (model.type) {
        case ZegoClassRoomBottomCellTypeMember:
            [ZegoViewAnimator showView:self.userTableView fromRightSideInView:self.view];
            break;
        case ZegoClassRoomBottomCellTypeCamera:
            if (model.isSelected) {
                [self closeCamera:^(BOOL success) {
                    @strongify(self);
                    model.isSelected = !success;
                    [self.bottomBar reloadData];
                }];
            } else {
                [self openCamera:^(BOOL success) {
                    @strongify(self);
                    model.isSelected = success;
                    [self.bottomBar reloadData];
                }];
            }
            break;
        case ZegoClassRoomBottomCellTypeCameraSwitch:
            self.isFrontCamera = !self.isFrontCamera;
            [ZegoLiveCenter setFrontCam:self.isFrontCamera];
            break;
        case ZegoClassRoomBottomCellTypeMic:
            if (model.isSelected) {
                [self closeMic:^(BOOL success) {
                    @strongify(self);
                    model.isSelected = !success;
                    [self.bottomBar reloadData];
                }];
                
            } else {
                [self openMic:^(BOOL success) {
                    @strongify(self);
                    model.isSelected = success;
                    [self.bottomBar reloadData];
                }];
            }
            break;
        case ZegoClassRoomBottomCellTypeShareBoard:
            [self.whiteBoardService addWhiteboard];
            break;
        case ZegoClassRoomBottomCellTypeShareFile:
        
            [self showFileList];
           
            break;
        case ZegoClassRoomBottomCellTypeInvite:
            [ZegoClassInviteManager pastInviteContentWithUserName:self.currentUserModel.userName roomID:self.roomId isEnvAbroad:self.isEnvAbroad];
            break;
        default:
            break;
    }
}

- (void)pageControlViewPreviousPage {
    [[UIApplication sharedApplication].keyWindow endEditing: YES];
    [self changeDocWhiteBoardToPreStep];
}

- (void)pageControlViewNextPage {
    [[UIApplication sharedApplication].keyWindow endEditing: YES];
    [self changeDocWhiteBoardToNextStep];
}

#pragma makr - Private Room

- (void)reLogin {
    [self.bottomBar setupMicOpen:NO react:NO];
    [self.bottomBar setupCameraOpen:NO react:NO];
    self.loginService = [ZegoLoginService new];
    @weakify(self);
    [self.loginService serverloginRoomWithRoomID:self.roomId
                                          userID:self.currentUserModel.uid
                                        userName:self.currentUserModel.userName
                                        userRole:self.currentUserModel.role
                                       classType:self.classType
                                         success:^(ZegoRoomMemberInfoModel *userModel, NSString *roomID) {
        @strongify(self);
        [self reloadRoom];
    } failure:^(ZegoResponseModel *response) {
        @strongify(self);
        DLog(@"serverloginRoomWithRoomID");
//        [self onTempBroken:-1 roomID:self.roomId];
        [self reLoginFailed];
    }];
}

- (void)reloadRoom {
    [ZegoHttpHeartbeat stop];
    [self startHeartbeat];
    [self loadInitRoomMemberInfo];
}

- (void)reLoginFailed {
    DLog(@"重试失败");
    
    [ZegoHUD dismiss];
    [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"room_rejoin_fail"] onTapYes:^{
        [self logoutRoomEndClass:NO];
    } onTapRetryButton:^{
        [self reLogin];
    }];
}

#pragma mark - LiveCenterDelegate

- (void)onReconnect:(int)errorCode roomID:(NSString *)roomID {
    [ZegoHUD dismiss];
    [ZegoLiveCenter writeLog:1 content:[NSString stringWithFormat:@"[DEMO]onReconnect errorCode:%d roomID:%@", errorCode, roomID]];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self reLogin];
}

- (void)onTempBroken:(int)errorCode roomID:(NSString *)roomID {
    DLog(@"网络异常，正在重新加入...");
    [ZegoHUD dismiss];
    [ZegoLiveCenter writeLog:1 content:[NSString stringWithFormat:@"[DEMO]onTempBroken roomID:%@", roomID]];
    [ZegoHUD showIndicatorHUDText:[NSString zego_localizedString:@"room_network_exception"]];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(reLoginFailed) withObject:self afterDelay:60];
}

- (void)onDisconnect:(int)errorCode roomID:(NSString *)roomID {
    [ZegoLiveCenter writeLog:1 content:[NSString stringWithFormat:@"[DEMO]onDisconnect roomID:%@", roomID]];
    [ZegoHUD dismiss];
    [self logoutRoomEndClass:NO];
}

- (void)onStreamUpdated:(int)type streams:(NSArray<ZegoLiveStream *> *)streamList roomID:(NSString *)roomID {

    for (ZegoLiveStream *stream in streamList) {
        //维护流列表数据
        for (ZegoLiveStream *localStream in self.streamList) {
            if ([stream.userID isEqualToString: localStream.userID]) {
                [self.streamList removeObject:localStream];
                break;
            }
        }
        if (type == ZegoDemoStreamTypeADD) {
            [self.streamList addObject:stream];
        }
        
        //更新 坐席列表显示
        BOOL check = NO;//是否找到本地数据源
        for (ZegoStreamWrapper *wrapper in self.joinLiveMemberArray) {
            if (stream.userID.integerValue == wrapper.userStatusModel.uid) {
                check = YES;
                if (type == ZegoDemoStreamTypeADD) {
                    DLog(@"流新增收到");
                    wrapper.stream = stream;
                    [self.streamTableView updateStream:wrapper];
                    
                } else {
                    DLog(@"流删除收到");
                    wrapper.streamStatusType = ZegoStreamStatusTypeNotFound;
                    [self.streamTableView updateStream:wrapper];
                }
                break;
            }
        }
        
        if (check == NO) {
            //如果遍历之后没有找到匹配的数据模型，则请求更新指定用户的信息
//            [self loadUserInfoByUserId:stream.userID];
        }
    }
}


- (void)onPlayStateUpdate:(int)stateCode streamID:(NSString *)streamID {
    //当拉流失败则重置列表显示
//    if (stateCode != 0) {
//        ZegoStreamWrapper *wrapper = [self.streamTableView getStreamWrapper:streamID];
//        if (wrapper) {
//            wrapper.streamStatusType = ZegoStreamStatusTypeIdle;
//            [self.streamTableView updateStream:wrapper];
//        }
//
//    }
}

- (void)onPublishStateUpdate:(int)stateCode streamID:(NSString *)streamID streamInfo:(NSDictionary<NSString *,NSArray<NSString *> *> *)info {
    //当推流失败则重置列表显示
//    if (stateCode != 0) {
//        ZegoStreamWrapper *wrapper = [self.streamTableView getStreamWrapper:self.publishStreamID];
//        if (wrapper) {
//            wrapper.streamStatusType = ZegoStreamStatusTypeIdle;
//            [self.streamTableView updateStream:wrapper];
//        }
//    }
    
}

- (void)onRecvWhiteboardChange:(unsigned long long)whiteboardID {
    
    [self.whiteBoardService changeWhiteBoardWithID:whiteboardID];
}

- (void)onReceiveCustomCommand:(NSString *)fromUserID userName:(NSString *)fromUserName content:(NSString *)content roomID:(NSString *)roomID {
    DLog(@"onReceiveCustomCommand %@",content);
    ZegoRoomMessageRspModel *rsp = [ZegoRoomMessageRspModel yy_modelWithJSON:content];
    switch (rsp.cmd) {
        case ZegoClassBusinessTypeRoomMemberStatusChange:
            [self handleRoomMemberStatusChangeWithData:rsp.data];
            break;
        case ZegoClassBusinessTypeRoomMemberUpdate:
            [self handleRoomMemberUpdateWithData:rsp.data];
            break;
        case ZegoClassBusinessTypeJoinLiveMemberUpdate:
            [self handleJoinLiveMemberUpdateWithData:rsp.data];
            break;
        case ZegoClassBusinessTypeClassOver:
            if (self.currentUserModel.role != 1) {
                [self handleClassOverWithData:rsp.data];
            }
            break;
        default:
            break;
    }
}

- (void)onReceiveRoomMessage:(NSArray<ZegoMessageInfo *> *)messageList roomID:(NSString *)roomId {
    [self.chatList onReceiveMessage:messageList roomID:roomId];
}

- (void)onKickOut:(int)reason roomID:(NSString *)roomID customReason:(NSString *)customReason {
    if ([customReason isEqual: @"online_time_limit"]) {
        UINavigationController *navVC = (UINavigationController *)[UIApplication sharedApplication].keyWindow.rootViewController;
        if ([navVC.visibleViewController.presentedViewController isKindOfClass:[UIDocumentPickerViewController class]]) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        @weakify(self)
        [ZegoAlertView alertWithTitle:[NSString zego_localizedString:@"room_login_time_out"] hasCancelButton:NO onTapYes:^{
            @strongify(self)
            [self leaveRoom];
        }];
    }
}

#pragma mark- --点击手势代理，为了去除手势冲突--

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch{
    if([touch.view isDescendantOfView:self.bottomBar] || [touch.view isDescendantOfView:self.boardListView] || [touch.view isDescendantOfView:self.userTableView] || [touch.view isDescendantOfView:self.fileListView] || [touch.view isDescendantOfView:self.excelSheetListView] || [touch.view isDescendantOfView:self.drawingToolView]|| [touch.view isDescendantOfView:(UIView *)self.previewManager.previewView]){
        return NO;
    }
    return YES;
}

#pragma mark UI
- (UIActivityIndicatorView *)activityIndicator {
    if (!_activityIndicator) {
        _activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleGray)];
        _activityIndicator.frame= self.defaultNoteView.frame;
        _activityIndicator.hidesWhenStopped = YES;
    }
    [self.view bringSubviewToFront:_activityIndicator];
    return _activityIndicator;
}

- (void)setupBottomBarUI
{
    if (self.classType == ZegoClassPatternTypeBig) {
        if (self.currentUserModel.role == ZegoUserRoleTypeStudent) {
            [self.bottomBar hiddenItems:@[@(ZegoClassRoomBottomCellTypeCamera),@(ZegoClassRoomBottomCellTypeMic),@(ZegoClassRoomBottomCellTypeShare)]];
        } else {
            
        }
    }
}

- (void)setupDefaulNoteView {
    if (self.currentUserModel.role == ZegoUserRoleTypeStudent ) {
        [self.defaultNoteView showTipStyleWithClassType:self.classType];
    } 
}

- (void)setupUserTableView {
    self.userTableView = [[ZegoUserTableView alloc] initWithFrame:CGRectMake(0, 0, kSideListWidth, kScreenHeight)];
    self.userTableView.showUserStatusOperationButton = !(self.classType == ZegoClassPatternTypeBig || self.currentUserModel.role == ZegoUserRoleTypeStudent);
    @weakify(self);
    self.userTableView.didClickAuthorityStatusBlock = ^(ZegoRoomMemberInfoModel * _Nonnull model) {
        @strongify(self);
        [self setupRoomMemberAuthority:model complement:^(BOOL success) {
            @strongify(self);
            // 如果失败，则刷新列表还原UI状态，如果成功则通过成员状态消息变更中的回调更新数据模型和UI
            if (!success) {
                [self.userTableView reloadData];
            }
        }];
    };
}

- (void)setUpChatList {
    if (self.classType == ZegoClassPatternTypeBig) {
        //大班课才添加讨论区
        self.chatList = [[ZegoChatViewController alloc] init];
        self.chatList.roomID = self.roomId;
        self.chatList.currentUserModel = self.currentUserModel;
        [self addChildViewController:self.chatList];
        [self.view addSubview:self.chatList.view];
        [self.chatList didMoveToParentViewController:self];
        [self.chatList.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view.mas_top).offset(kStreamCellHeight);
            make.right.equalTo(self.view.mas_right);
            make.bottom.equalTo(self.view.mas_bottom);
            make.width.mas_equalTo(kStreamCellWidth);
        }];
    }
}

- (void)setupPageControlView {
    self.pageControlCarrierView.layer.cornerRadius = self.pageControlCarrierView.frame.size.height /2;
    self.pageControlCarrierView.layer.masksToBounds = YES;
    if (!self.pageControlView) {
        self.pageControlView = [[ZegoPageControlView alloc] initWithFrame:self.pageControlCarrierView.bounds];
        self.pageControlView.delegate = self;
        [self.pageControlCarrierView addSubview:self.pageControlView];
    }
    self.pageControlCarrierView.hidden = NO;
}

- (void)setupDrawingToolView {
    self.drawingToolViewService = [[ZegoFormatToolService alloc] initWithBoardContainer:self.whiteBoardService.currentContainer];
    self.drawingToolViewService.delegate = self;
    self.drawingToolView = [ZegoDrawingToolView defaultInstance];
    self.drawingToolView.delegate = self.drawingToolViewService;
    [self.view addSubview:self.drawingToolView];
}

- (void)setupPreviewManager {
    self.previewManager = [[ZegoFilePreviewViewModel alloc] init];
    @weakify(self);
    self.previewManager.selectedPageBlock = ^(NSInteger index) {
        @strongify(self);
        NSInteger selectedPage = index + 1;
        if (self.whiteBoardService.currentContainer.docsView.currentPage != selectedPage) {
            [self.whiteBoardService.currentContainer scrollToPage:selectedPage pptStep:1 completionBlock:^(BOOL isScrollSuccess) {
                @strongify(self);
                [self refreshTopBar];
            }];
        }
    };
}

- (void)setupToggleCoverViewTapGestureRecognizer
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleCoverView)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    [self.view addSubview:self.activityIndicator];
}

- (void)setupFileListView {
    self.fileListView = [[ZegoFileListView alloc] initWithFrame:CGRectMake(0, 0, kSideListWidth, kScreenHeight)];
    self.fileListView.delegate = self;
}

- (void)setupExcelSheetListView {
    self.excelSheetListView = [[ZegoExcelSheetListView alloc] initWithFrame:CGRectMake(0, 0, kSideListWidth, kScreenHeight)];
    self.excelSheetListView.delegate = self;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

#pragma mark - ZegoClassJustTestViewControllerDelegate

- (void)addText:(NSString *)text positionX:(CGFloat)x positionY:(CGFloat)y {
    ZegoWhiteboardTool lastType = [ZegoWhiteboardManager sharedInstance].toolType;
    [ZegoWhiteboardManager sharedInstance].toolType = (ZegoWhiteboardTool)ZegoDrawingToolViewItemTypeText;
    [self.whiteBoardService.currentContainer setupWhiteboardOperationMode:(ZegoWhiteboardOperationModeDraw|ZegoWhiteboardOperationModeZoom)];
    [self.whiteBoardService.currentContainer.whiteboardView addText:text positionX:x positionY:y];
    [ZegoWhiteboardManager sharedInstance].toolType = lastType;
}

- (void)setCustomText:(NSString *)text {
    [ZegoWhiteboardManager sharedInstance].customText = text;
}

- (void)setWhiteboardEnabled:(BOOL)enable {
    [self.whiteBoardService.currentContainer.whiteboardView setWhiteboardOperationMode:enable?(ZegoWhiteboardOperationModeDraw | ZegoWhiteboardOperationModeZoom):ZegoWhiteboardOperationModeZoom];
}

- (void)clearPage:(NSInteger)page {
    CGRect rect;
    if (self.whiteBoardService.currentContainer.docsView) {
        ZegoDocsViewPage *pageInfo = [self.whiteBoardService.currentContainer.docsView getCurrentPageInfo];
        rect = pageInfo.rect;
        [self.whiteBoardService.currentContainer.whiteboardView clear:rect];
    }else {
        CGFloat percent = self.whiteBoardService.currentContainer.whiteboardView.whiteboardModel.horizontalScrollPercent;
        CGFloat width = self.whiteBoardService.currentContainer.whiteboardView.frame.size.width;
        CGFloat height = self.whiteBoardService.currentContainer.whiteboardView.frame.size.height;
        CGFloat offsetX = percent * width * self.whiteBoardService.currentContainer.whiteboardView.whiteboardModel.pageCount;
        CGFloat offsetY = 0;
        CGRect rect = CGRectMake(offsetX, offsetY, width, height);
        [self.whiteBoardService.currentContainer.whiteboardView clear:rect];
    }
}



@end
