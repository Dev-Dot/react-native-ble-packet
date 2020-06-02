#import <React/RCTBridgeModule.h>

@interface BlePacket : NSObject <RCTBridgeModule>
typedef enum {
    BleStateUnknown=0,
    BleStatePowerOn,
    BleStatePoweroff,
    BleStateIdle,
    BleStateScan,
    BleStateCancelConnect,
    BleStateNoDevice,
    BleStateWaitToConnect,
    BleStateConnecting,
    BleStateConnected,
    BleStateDisconnect,
    BleStateReConnect,
    BleStateConnecttimeout,
    BleStateReconnecttimeout,
    //BleStateShutdown,
}BleState;

@property (weak, nonatomic) NSManagedObjectContext *managedObjectContext;

@property(nonatomic,strong) CBCharacteristic *WriteCharacteristic;
//当前连接设备信息
@property(nonatomic,strong)BLEDevice *currentdevice;
//断开连接标志,判断是自动断开还是意外断开
@property(nonatomic,assign)BOOL APPCancelConnect;
//扫描周围蓝牙设备集合
@property(nonatomic,strong)NSMutableArray *BLEDeviceArray;
//蓝牙状态
@property(nonatomic,assign)BleState blestate;
//App 运行模式
@property(nonatomic,assign)ActiveMode activemode;
//停止和开始布尔值
@property (nonatomic, assign) BOOL paused;
//环形进度条的进度,注意初始化时清零
@property (nonatomic, assign) CGFloat localProgress;
// //设置模型
// @property (strong, nonatomic)  STLoopProgressView *colorview;
//连接超时定时器
@property(nonatomic,strong)NSTimer *ConnectTimeoutTimer;
// //提示view
// @property(nonatomic,strong)PopView *popview;
//滑动手势
// @property (nonatomic, strong) UISwipeGestureRecognizer *leftSwipeGestureRecognizer;
// @property (nonatomic, strong) UISwipeGestureRecognizer *rightSwipeGestureRecognizer;
// @property(nonatomic,strong) UIView *ScanBleView;
// @property(nonatomic,strong) UILabel *titlelabel;
@property(nonatomic,assign)uint8_t sequence;
// @property(nonatomic,strong)UILabel *Opmodelabel;
// @property(nonatomic,strong)UILabel *STAStatelabel;
// @property(nonatomic,strong)UILabel *STACountlabel;
// @property(nonatomic,strong)UIButton *ConfigBtn;
// @property(nonatomic,strong)UILabel *BSSidSTAlabel;
// @property(nonatomic,strong)UILabel *SSidSTAlabel;
@property(nonatomic,strong)RSAObject *rsaobject;
@property(nonatomic,strong)NSData *senddata;
@property(nonatomic,copy)NSData *Securtkey;

//@property(nonatomic, strong)NSDate *lastTime;
@property(nonatomic, strong)NSMutableData *ESP32data;
@property(nonatomic, assign)NSInteger length;

@property(nonatomic, strong) NSMutableDictionary *bleDevicesSaveDic;

@end
