#import "BlePacket.h"

#import <React/RCTLog.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BabyBluetooth.h"
#import "PacketCommand.h"

#import "UUID.h"
#import "BLEDevice.h"
#import "NSDate+Datestring.h"
#import "OpmodeObject.h"
#import "RSAObject.h"
#import "BLEdataFunc.h"
// #import "LocalNotifyFunc.h"
// #import "ConfigureVC.h"

#define filterBLEname   @"BLUFI_"
#define SCANTIME        20
#define ConnectTime     2*60
#define ReconnectTime   5*60
//指令超时时间
#define CommandBtnTimeout 30

#define ConnectedDeviceKey  @"ConnectedDevice"
#define ConnectedDeviceNameKey  @"ConnectedDeviceName"

#define AutoConnect  0

typedef enum {
    ForegroundMode=0,
    backgroundMode,
}ActiveMode;

typedef enum {
    ReconnecttimeoutAction=0,
    ConnectingAction,
    DisconnectAction,
    DeviceoverAction,
    CancelreconnectAction,
    StartSensorAction,
    DisconnectBLE,
    ClearData,
}AlertActionState;

@implementation BlePacket

BabyBluetooth *baby;
//蓝牙状态
//BleState blestate;

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(init: (RCTResponseSenderBlock)callback)
{
    RCTLog(@"Init...");
    // Initialize the Bluetooth BabyBluetooth library
    baby=[BabyBluetooth shareBabyBluetooth];
    // Set up Bluetooth delegation
    [self BleDelegate];
}

RCT_EXPORT_METHOD(scanDevices: (RCTResponseSenderBlock)callback)
{
    RCTLog(@"scanning...");
    baby.scanForPeripherals().begin();

  // NSArray *devices = []
  // if (devices) {
  //    RCTLog(@"scan: RESOLVE")
  //   resolve(devices);
  // } else {
  //    RCTLog(@"scan: REJECT")
  //   // NSError *error = 
  //   reject(@"no_devices", @"There were no devices", error);
  // }
}

// RCT_EXPORT_METHOD(getDeviceName:(RCTResponseSenderBlock)callback){
//  @try{
//    NSString *deviceName = [[UIDevice currentDevice] name];
//    callback(@[[NSNull null], deviceName]);
//  }
//  @catch(NSException *exception){
//    callback(@[exception.reason, [NSNull null]]);
//  }
// }


/**
 *  蓝牙代理
 */
-(void)BleDelegate
{
    __weak typeof(baby) weakbaby = baby;
    __weak typeof(self) weakself =self;
    //判断手机蓝牙状态
     [baby setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
         //检测蓝牙状态
         if (central.state==CBCentralManagerStatePoweredOn) {
             //Log(@"蓝牙已打开");
             weakself.blestate=BleStatePowerOn;
            
             NSString *UUIDStr=[[NSUserDefaults standardUserDefaults] objectForKey:ConnectedDeviceKey];
             if (UUIDStr && AutoConnect) {
                 CBPeripheral *peripheral=[weakbaby retrievePeripheralWithUUIDString:UUIDStr];
                 [weakself connect:peripheral];
                 weakself.blestate=BleStateConnecting;
                 BLEDevice *device=[[BLEDevice alloc]init];
                 device.Peripheral=peripheral;
                 device.name=[[NSUserDefaults standardUserDefaults] objectForKey:ConnectedDeviceNameKey];
                 weakself.currentdevice=device;
             }
         }
         if(central.state==CBCentralManagerStateUnsupported)
         {
             //Log(@"该设备不支持蓝牙BLE");
             weakself.blestate=BleStateUnknown;
         }
         if (central.state==CBCentralManagerStatePoweredOff) {
             //Log(@"蓝牙已关闭");
             weakself.blestate=BleStatePoweroff;
         }
     }];

    // //搜索蓝牙
    // [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
    //     //zwjLog(@"搜索到了设备:%@,%@",peripheral.name,advertisementData);
    //     //将扫描到的设备添加到数组中
    //     //NSString *serialnumber=[BLEdataFunc GetSerialNumber:advertisementData];
    //     //NSString *name=[NSString stringWithFormat:@"%@%@",peripheral.name,serialnumber];
    //     NSString *name=[NSString stringWithFormat:@"%@",peripheral.name];
    //     if (![BLEdataFunc isAleadyExist:name BLEDeviceArray:weakself.BLEDeviceArray])
    //     {
    //         BLEDevice *device=[[BLEDevice alloc]init];
    //         device.name=name;
    //         device.Peripheral=peripheral;
    //         device.uuidBle = peripheral.identifier.UUIDString;
    //         [weakself.BLEDeviceArray addObject:device];
    //         weakself.bleDevicesSaveDic[device.uuidBle] = device;

    //         if (weakself.popview) {
    //             weakself.popview.dataArray=weakself.BLEDeviceArray;
    //         }
    //         else if (!weakself.popview && weakself.BLEDeviceArray.count==1)
    //         {
    //             weakself.popview=[weakself PopScanViewWithTitle:NSLocalizedString(@"scaning", nil)];
    //         }

    //     }
    // }];
    
    // //设置扫描过滤器
    // [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI)
    //  {
    //      if ([peripheralName hasPrefix:filterBLEname])
    //      {
    //          return YES;
    //      }
    //      return NO;
    //  }];
    
    // //设置连接过滤器
    // [baby setFilterOnConnectToPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        
    //     if ([peripheralName hasPrefix:filterBLEname]) {
    //         //isFirst=NO;
    //         //zwjLog(@"准备连接");
    //         weakself.blestate=BleStateConnecting;
    //         return YES;
    //     }
    //     return NO;
    // }];
    // //连接成功
    // [baby setBlockOnConnected:^(CBCentralManager *central, CBPeripheral *peripheral) {
    //     zwjLog(@"设备：%@--连接成功",peripheral.name);
    //     BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
    //     device.isConnected = YES;
    //     //取消自动回连功能(连接成功后必须清除自动回连,否则会崩溃)
    //     [weakself AutoReconnectCancel:weakself.currentdevice.Peripheral];
        
    //     }];
    //     weakself.ESP32data=NULL;
    //     weakself.length=0;
    
    // //设备连接失败
    // [baby setBlockOnFailToConnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
    //     zwjLog(@"设备：%@--连接失败",peripheral.name);
    //     BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
    //     device.isConnected = NO;
    //     //清除主动断开标志
    //     weakself.APPCancelConnect=NO;
    //     //[LocalNotifyFunc DeleteAllUserDefaultsAndCancelnotifyWithBlestate:weakself.blestate];
    // }];
    // //发现设备的services委托
    // [baby setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
    //     zwjLog(@"发现服务");
    //     //更新蓝牙状态,进入已连接状态
    //     weakself.blestate=BleStateConnected;
    //     //weakself.title=weakself.currentdevice.name;
        
    // }];
    // [baby setBlockOnDidReadRSSI:^(NSNumber *RSSI, NSError *error) {
    //     //zwjLog(@"当前连接设备的RSSI值为:%@",RSSI);
    // }];
    // //设置发现services的characteristics
    // [baby setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
    //     zwjLog(@"===service name:%@",service.UUID);
    //     for (CBCharacteristic *characteristic in service.characteristics)
    //     {
    //         if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ESPRESSIF_Notify])
    //         {
    //             //订阅通知
    //             [weakbaby notify:peripheral characteristic:characteristic block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error){
    //                  NSData *data=characteristic.value;
    //                 if (data.length<3) {
    //                     return ;
    //                 }
    //                 //zwjLog(@"接收到数据为%@>>>>>>>>>>>>",data);
    //                 //zwjLog(@"%@",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);
    //                 NSMutableData *Mutabledata=[NSMutableData dataWithData:data];
    //                 [weakself analyseData:Mutabledata];
                    
    //                  if(weakself.ConnectTimeoutTimer)
    //                  {
    //                      //销毁连接超时定时器
    //                      [weakself.ConnectTimeoutTimer invalidate];
    //                  }
                         
    //                 }];
    //         }
    //         if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ESPRESSIF_Write])
    //         {
    //             zwjLog(@"UUIDSTR_ESPRESSIF_RX");
    //             _WriteCharacteristic=characteristic;
    //         }
    //     }
    // }];
    
    // //读取characteristic
    // [baby setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error)
    //  {
         
    //  }];
    
    // //设置发现characteristics的descriptors的委托
    // [baby setBlockOnDiscoverDescriptorsForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
    // }];
    
    // //设置读取Descriptor的委托
    // [baby setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
    //     //Log(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    // }];
    
    // //断开连接回调
    // [baby setBlockOnDisconnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
    //     if (error) {
    //         zwjLog(@"断开连接Error %@",error);
    //     }
    //     BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
    //     device.isConnected = NO;
        
    //     if (weakself.APPCancelConnect) {
    //         //清标志位
    //         weakself.APPCancelConnect=NO;
    //         weakself.blestate=BleStateDisconnect;
    //          zwjLog(@"设备：%@--断开连接",peripheral.name);
    //     }
    //     else{
    //         //更新蓝牙状态,已连接状态
    //         weakself.blestate=BleStateReConnect;
    //         //添加自动回连
    //         if (weakself.currentdevice.Peripheral) {
    //             [weakself AutoReconnect:weakself.currentdevice.Peripheral];
    //             zwjLog(@"设备：%@--重新连接",peripheral.name);
    //         }
    //     }
    //     //断开连接时,如果有数据就保存到数据库
    // }];
    // //取消所有连接回调
    // [baby setBlockOnCancelAllPeripheralsConnectionBlock:^(CBCentralManager *centralManager) {
    //     zwjLog(@"setBlockOnCancelAllPeripheralsConnectionBlock");
    // }];
    // //********取消扫描回调***********//
    // [baby setBlockOnCancelScanBlock:^(CBCentralManager *centralManager) {
    //     //Log(@"取消扫描");
    //     //停止进度条
    //     [weakself StopProgressView];
    //      weakself.blestate=BleStateWaitToConnect;
    //     NSInteger count=weakself.BLEDeviceArray.count;
    //     if(weakself.popview)
    //     {
    //         if (count<=0) {
    //             weakself.popview.titlelabel.text=NSLocalizedString(@"popviewnodevice", nil);
    //             //更新蓝牙状态,进入无设备状态
    //             weakself.blestate=BleStateNoDevice;
    //         }else
    //         {
    //             weakself.popview.titlelabel.text=NSLocalizedString(@"connect", nil);
    //         }
    //         return ;
            
    //     }else
    //     {
    //         if (count<=0) {
    //             weakself.popview.titlelabel.text=NSLocalizedString(@"popviewnodevice", nil);
    //             //更新蓝牙状态,进入无设备状态
    //             weakself.blestate=BleStateNoDevice;
    //         }else if (count>=1) {
    //             [weakself PopScanViewWithTitle:NSLocalizedString(@"connect", nil)];
    //         }
    //     }
        
    // }];
    // //扫描选项->CBCentralManagerScanOptionAllowDuplicatesKey:忽略同一个Peripheral端的多个发现事件被聚合成一个发现事件
    // NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    
    // NSDictionary *connectOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES,
    //                                  CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES,
    //                                  CBConnectPeripheralOptionNotifyOnNotificationKey:@YES};
    // //连接设备->
    // [baby setBabyOptionsWithScanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:connectOptions scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
    // //订阅状态改变
    // [baby setBlockOnDidUpdateNotificationStateForCharacteristic:^(CBCharacteristic *characteristic, NSError *error) {
    //     if (error) {
    //         zwjLog(@"订阅 Error");
    //     }
    //     if (characteristic.isNotifying) {
    //         zwjLog(@"订阅成功");
    //         [weakself writeStructDataWithCharacteristic:weakself.WriteCharacteristic WithData:[PacketCommand GetDeviceInforWithSequence:weakself.sequence]];
    //         [weakself SendNegotiateData];
    //     }
    //     else
    //     {
    //         zwjLog(@"已经取消订阅");
    //     }
        
    // }];
    // //发送数据完成回调
    // [weakbaby setBlockOnDidWriteValueForCharacteristic:^(CBCharacteristic *characteristic, NSError *error)
    //  {
    //      if (error)
    //      {
    //          zwjLog(@"%@",error);
    //          [HUDTips ShowLabelTipsToView:self.navigationController.view WithText:@"command error"];
    //          return ;
    //      }
    //      zwjLog(@"发送数据完成");
        
    // }];
}

/**
 *  直连
 *
 *  @param peripheral 要连接的蓝牙设备
 */
-(void)connect:(CBPeripheral *)peripheral
{
    baby.having(peripheral).connectToPeripherals().discoverServices().discoverCharacteristics().begin();
}
//断开自动重连
-(void)AutoReconnect:(CBPeripheral *)peripheral
{
    [baby AutoReconnect:peripheral];
}
//删除自动重连
- (void)AutoReconnectCancel:(CBPeripheral *)peripheral;
{
    [baby AutoReconnectCancel:peripheral];
}

/**
 *  断开连接
 */
-(void)Disconnect:(CBPeripheral *)Peripheral
{
    self.APPCancelConnect=YES;
    BLEDevice *device = self.bleDevicesSaveDic[Peripheral.identifier.UUIDString];
    if (device.isConnected) {
        //取消某个连接
        [baby cancelPeripheralConnection:Peripheral];
        self.blestate=BleStateDisconnect;
    }
    
}
//取消所有连接
-(void)CancelAllConnect
{
    if([baby findConnectedPeripherals].count>0)
    {
        self.APPCancelConnect=YES;
        //断开所有蓝牙连接
        [baby cancelAllPeripheralsConnection];
    }
}

@end
