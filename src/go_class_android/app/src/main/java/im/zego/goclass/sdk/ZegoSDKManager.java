package im.zego.goclass.sdk;

import android.app.Application;
import android.content.Context;
import android.os.Environment;
import android.util.Log;

import org.jetbrains.annotations.NotNull;

import java.io.File;

import im.zego.goclass.AppConstants;
import im.zego.goclass.AuthConstants;
import im.zego.goclass.network.ZegoApiClient;
import im.zego.goclass.tool.SharedPreferencesUtil;
import im.zego.zegodocs.IZegoDocsViewUploadListener;
import im.zego.zegodocs.ZegoDocsViewConfig;
import im.zego.zegodocs.ZegoDocsViewManager;
import im.zego.zegowhiteboard.ZegoWhiteboardConfig;
import im.zego.zegowhiteboard.ZegoWhiteboardManager;
import im.zego.zegowhiteboard.callback.IZegoWhiteboardGetListListener;
import im.zego.zegowhiteboard.callback.IZegoWhiteboardManagerListener;

import static im.zego.goclass.widget.FontConfig.FONT_FAMILY_DEFAULT_PATH;
import static im.zego.goclass.widget.FontConfig.FONT_FAMILY_DEFAULT_PATH_BOLD;

/**
 * 主要是对liveroom/express的封装，和白板view,docsview相关回调的监听
 * 小班课的相关逻辑在 {@link im.zego.goclass.classroom.ClassRoomManager} 中
 */
public class ZegoSDKManager {
    private final String TAG = getClass().getSimpleName();
    private Application application;

    private ZegoSDKManager() {
    }

    private static final class Holder {
        private static final ZegoSDKManager INSTANCE = new ZegoSDKManager();
    }

    public static ZegoSDKManager getInstance() {
        return Holder.INSTANCE;
    }

    private IZegoVideoSDKProxy zegoSDKProxy = new ZegoExpressWrapper();

    private ZegoStreamService streamService = new ZegoStreamService(zegoSDKProxy);
    private ZegoDeviceService deviceService = new ZegoDeviceService(zegoSDKProxy);
    private ZegoRoomService roomService = new ZegoRoomService(zegoSDKProxy);

    public static final int MAX_PURE_WB_COUNT = 10;
    public static final int MAX_FILE_WB_COUNT = 10;
    public static final int MAX_USER_COUNT = 10;
    public static final int MAX_STREAM_COUNT = 4;

    public static int whiteboardNameIndex = 1;
    private boolean isMainLandEnv = true;
    private boolean isSmallClass = true;

    private Boolean initVideoResult = null;
    private Boolean initDocsResult = null;
    private Boolean initWhiteboardResult = null;


    public void initSDKEnvironment(Application application, InitResult initCallback) {
        // 在这里面配置测试环境等开关
        configTestEnvSwitch();

        initVideoSDK(application, initCallback);
        initDocSdk(application, initCallback);
        initZegoApiClient(application, isMainLandEnv());
    }

    /**
     * 在这里配置测试环境等开关
     * 其中环境设置时传入 true 表示开启测试环境，传入 false 表示开启正式环境
     */
    private void configTestEnvSwitch() {
        // 是否开启业务后台测试环境
        SharedPreferencesUtil.setGoClassTestEnv(true);

        // 是否开启房间服务测试环境
        SharedPreferencesUtil.setVideoSDKTestEnv(true);

        // 是否开启文件服务测试环境
        SharedPreferencesUtil.setDocsViewTestEnv(true);

        // 是否开启点击触发翻页功能
        SharedPreferencesUtil.setNextStepFlipPage(true);
    }



    /**
     * 初始化liveroom/express
     *
     * @param application
     * @param initCallback
     */
    private void initVideoSDK(Application application, InitResult initCallback) {
        this.application = application;
        boolean isVideoSDKTest = SharedPreferencesUtil.isVideoSDKTestEnv();
        Log.i(TAG, "init initRoomSDK isVideoSDKTest " + isVideoSDKTest + ",version:" + zegoSDKProxy.version());

        zegoSDKProxy.initSDK(application, getAppID(), getAppSign(), isVideoSDKTest, success -> {
            Log.i(TAG, "init zegoLiveRoomSDK result:" + success);
            initVideoResult = success;
            if (success) {
                initWhiteboardSDK(application, initCallback);
            } else {
                initWhiteboardResult = false;
                notifyInitResult(initCallback);
            }
        });
    }

    private void notifyInitResult(InitResult initCallback) {
        if (initVideoResult != null && initDocsResult != null && initWhiteboardResult != null) {
            initCallback.initResult(initVideoResult && initDocsResult && initWhiteboardResult);
        }
    }

    public boolean isMainLandEnv() {
        return isMainLandEnv;
    }

    public void setMainLandEnv(boolean mainLandEnv, InitResult initCallback) {
        Log.d(TAG, "setMainLandEnv() called with: mainLandEnv = [" + mainLandEnv + "], initCallback = [" + initCallback + "]");
        if (isMainLandEnv != mainLandEnv) {
            zegoSDKProxy.unInitSDK();
            isMainLandEnv = mainLandEnv;
            initVideoResult = null;
            initVideoSDK(application, success -> {
                if (!success) {
                    isMainLandEnv = !mainLandEnv;
                }
                initCallback.initResult(success);
            });
            initZegoApiClient(application, isMainLandEnv());
        }
    }

    public void setRoomType(boolean smallClass, InitResult initCallback) {
        Log.d(TAG, "setRoomType() called with: smallClass = [" + smallClass + "], initCallback = [" + initCallback + "]");
        if (isSmallClass != smallClass) {
            ZegoWhiteboardManager.getInstance().uninit();
            zegoSDKProxy.unInitSDK();
            isSmallClass = smallClass;
            initVideoResult = null;
            initVideoSDK(application, success -> {
                if (!success) {
                    isSmallClass = !smallClass;
                }
                initCallback.initResult(success);
            });
        }
    }

    public void changeLanguage(InitResult initCallback) {
        Log.d(TAG, "changeLanguage() called");
        ZegoWhiteboardManager.getInstance().uninit();
        zegoSDKProxy.unInitSDK();
        initVideoResult = null;
        initVideoSDK(application, success -> {
            initCallback.initResult(success);
        });
    }

    /**
     * 初始化业务后台
     *
     * @param application
     * @param isMainLandEnv
     */
    private void initZegoApiClient(Application application, boolean isMainLandEnv) {
        boolean goClassEnvTest = SharedPreferencesUtil.isGoClassTestEnv();
        Log.i(TAG, "initZegoApiClient()  : application = " + application + ", isMainLandEnv = " + isMainLandEnv + ", isGoClassEnvTest = " + goClassEnvTest);
        ZegoApiClient.setAppContext(application, goClassEnvTest, isMainLandEnv);
    }

    private long getAppID() {
        // isSmallClass 区分大班课时的国内与海外 APPID
        if (isMainLandEnv) {
            return isSmallClass ? AuthConstants.APP_ID : AuthConstants.APP_ID_LARGE;
        } else {
            return isSmallClass ? AuthConstants.APP_ID_OVERSEAS : AuthConstants.APP_ID_LARGE_OVERSEAS;
        }
    }

    private String getAppSign() {
        // isSmallClass 区分大班课时的国内与海外 APP_SIGN
        if (isMainLandEnv) {
            return isSmallClass ? AuthConstants.APP_SIGN : AuthConstants.APP_SIGN_LARGE;
        } else {
            return isSmallClass ? AuthConstants.APP_SIGN_OVERSEAS : AuthConstants.APP_SIGN_LARGE_OVERSEAS;
        }
    }

    public String roomSDKMessage() {
        return zegoSDKProxy.rtcSDKName() + zegoSDKProxy.version();
    }

    public String rtcSDKName() {
        return zegoSDKProxy.rtcSDKName();
    }

    public boolean isLiveRoom() {
        return zegoSDKProxy.isLiveRoom();
    }

    public boolean isVideoInitSuccess() {
        return initVideoResult != null && initVideoResult;
    }

    public boolean isDocsInitSuccess() {
        return initDocsResult != null && initDocsResult;
    }

    public boolean isWhiteboardInitSuccess() {
        return initWhiteboardResult != null && initWhiteboardResult;
    }

    public void uploadLog() {
        zegoSDKProxy.uploadLog();
    }

    /**
     * 大班课和小班课发送消息是通过 SDK 的不同方法
     * 发送聊天消息
     *
     * @param content
     * @param callback
     */
    public void sendLargeClassMsg(String content, IZegoSendMsgCallback callback) {
        zegoSDKProxy.sendLargeClassMsg(content, callback);
    }

    /**
     * 大班课和小班课接收消息是通过 SDK 的不同回调
     * 设置接收消息的监听
     *
     * @param msgListener
     */
    public void setLargeClassMsgListener(IZegoMsgListener msgListener) {
        zegoSDKProxy.setLargeClassMsgListener(msgListener);
    }

    /**
     * 初始化文档服务
     *
     * @param context
     * @param initCallback
     */
    private void initDocSdk(Application application, InitResult initCallback) {
        Log.i(TAG, "initDocSdk.... version:" + ZegoDocsViewManager.getInstance().getVersion());
        boolean docsViewEnvTest = SharedPreferencesUtil.isDocsViewTestEnv();
        Log.i(TAG, "initDocSdk.... isDocsViewEnvTest:" + docsViewEnvTest);
        ZegoDocsViewConfig config = new ZegoDocsViewConfig();
        config.setAppID(getAppID());
        config.setAppSign(getAppSign());
        config.setTestEnv(docsViewEnvTest);

        config.setLogFolder(application.getExternalFilesDir(null).getAbsolutePath() + File.separator + AppConstants.LOG_SUBFOLDER);
        config.setDataFolder(application.getExternalFilesDir(null).getAbsolutePath() + File.separator + "zegodocs" + File.separator + "data");
        config.setCacheFolder(application.getExternalFilesDir(null).getAbsolutePath() + File.separator + "zegodocs" + File.separator + "cache");

        String pptStepMode;
        if (SharedPreferencesUtil.isNextStepFlipPage()) {
            pptStepMode = "1";
        } else {
            pptStepMode = "2";
        }
        ZegoDocsViewManager.getInstance().setCustomizedConfig("pptStepMode", pptStepMode);
        ZegoDocsViewManager.getInstance().init(application, config, errorCode -> {
                    Log.i(TAG, "init docsView result:" + errorCode);
                    initDocsResult = errorCode == 0;
                    notifyInitResult(initCallback);
                }
        );


    }

    /**
     * 初始化白板sdk
     *
     * @param context
     * @param initCallback
     */
    private void initWhiteboardSDK(Context context, InitResult initCallback) {
        Log.i(TAG, "initWhiteboardSDK....,version:" + ZegoWhiteboardManager.getInstance().getVersion());
        ZegoWhiteboardConfig config = new ZegoWhiteboardConfig();
        config.setLogPath(context.getExternalFilesDir(null).getAbsolutePath() + File.separator+ AppConstants.LOG_SUBFOLDER);
        ZegoWhiteboardManager.getInstance().setConfig(config);
        ZegoWhiteboardManager.getInstance().init(context, errorCode -> {
            Log.i(TAG, "init Whiteboard  errorCode:" + errorCode);
            initWhiteboardResult = (errorCode == 0);
            if (errorCode == 0) {
                // 设置默认字体,内部使用，接口测试中
                ZegoWhiteboardManager.getInstance()
                        .setCustomFontFromAsset(FONT_FAMILY_DEFAULT_PATH, FONT_FAMILY_DEFAULT_PATH_BOLD);
            }
            notifyInitResult(initCallback);
        });
    }

    public void uninitSDKEnvironment() {
        Log.d(TAG, "unInitSDKEnvironment() called");
        initVideoResult = null;
        initDocsResult = null;
        initWhiteboardResult = null;
        ZegoDocsViewManager.getInstance().uninit();
        ZegoWhiteboardManager.getInstance().uninit();
        zegoSDKProxy.unInitSDK();
    }

    public void setWhiteboardCountListener(IZegoWhiteboardManagerListener listener) {
        ZegoWhiteboardManager.getInstance().setWhiteboardManagerListener(listener);
    }

    public void getWhiteboardViewList(@NotNull IZegoWhiteboardGetListListener listListener) {
        ZegoWhiteboardManager.getInstance().getWhiteboardViewList(listListener);
    }

    public void uploadFile(@NotNull String uploadFilePath, int renderType, @NotNull IZegoDocsViewUploadListener iZegoDocsViewUploadListener) {
        ZegoDocsViewManager.getInstance().uploadFile(uploadFilePath, renderType, iZegoDocsViewUploadListener);
    }

    public void clearDocsViewCache() {
        ZegoDocsViewManager.getInstance().clearCacheFolder();
    }


    public long calculateCacheSize() {
        return ZegoDocsViewManager.getInstance().calculateCacheSize();
    }

    public void setStreamCountListener(IStreamCountListener listener) {
        streamService.setStreamCountListener(listener);
    }

    public void setRemoteDeviceListener(IRemoteDeviceStateListener listener) {
        deviceService.setRemoteDeviceListener(listener);
    }

    public void setRoomStateListener(IZegoRoomStateListener listener) {
        roomService.setZegoRoomStateListener(listener);
    }

    public void setKickOutListener(IKickOutListener listener) {
        roomService.setKickOutListener(listener);
    }

    public void setWhiteboardSelectListener(OnWhiteboardSelectedListener listener) {
        roomService.setOnWhiteboardSelectListener(listener);
    }

    public void setCustomCommandListener(ICustomCommandListener listener) {
        roomService.setCustomCommandListener(listener);
    }

    public ZegoStreamService getStreamService() {
        return streamService;
    }

    public ZegoRoomService getRoomService() {
        return roomService;
    }

    public ZegoDeviceService getDeviceService() {
        return deviceService;
    }

    public interface InitResult {
        void initResult(boolean success);
    }
}
