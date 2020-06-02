#import "BlePacket.h"

#import <React/RCTLog.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BabyBluetooth.h"
#import "PacketCommand.h"

#import "UUID.h"
#import "NSDate+Datestring.h"
#import "OpmodeObject.h"
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
 *  Bluetooth proxy
 */
-(void)BleDelegate
{
    __weak typeof(baby) weakbaby = baby;
    __weak typeof(self) weakself =self;
    // Determine the Bluetooth status of the phone
     [baby setBlockOnCentralManagerDidUpdateState:^(CBCentralManager *central) {
         // Check Bluetooth status
         if (central.state==CBCentralManagerStatePoweredOn) {
             Log(@"Bluetooth is on");
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
             //Log(@"The device does not support Bluetooth BLE");
             weakself.blestate=BleStateUnknown;
         }
         if (central.state==CBCentralManagerStatePoweredOff) {
             Log(@"Bluetooth is off");
             weakself.blestate=BleStatePoweroff;
         }
     }];

    //搜索蓝牙
    [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
        RCTLog(@"Device found:%@,%@",peripheral.name,advertisementData);
        //Add the scanned device to the array
        //NSString *serialnumber=[BLEdataFunc GetSerialNumber:advertisementData];
        //NSString *name=[NSString stringWithFormat:@"%@%@",peripheral.name,serialnumber];
        NSString *name=[NSString stringWithFormat:@"%@",peripheral.name];
        if (![BLEdataFunc isAleadyExist:name BLEDeviceArray:weakself.BLEDeviceArray])
        {
            BLEDevice *device=[[BLEDevice alloc]init];
            device.name=name;
            device.Peripheral=peripheral;
            device.uuidBle = peripheral.identifier.UUIDString;
            [weakself.BLEDeviceArray addObject:device];
            weakself.bleDevicesSaveDic[device.uuidBle] = device;

        }
    }];
    
    // Set scan filter
    [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI)
     {
         if ([peripheralName hasPrefix:filterBLEname])
         {
             return YES;
         }
         return NO;
     }];
    
    // Set connection filter
    [baby setFilterOnConnectToPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI) {
        
        if ([peripheralName hasPrefix:filterBLEname]) {
            //isFirst=NO;
            RCTLog(@"Ready to connect");
            weakself.blestate=BleStateConnecting;
            return YES;
        }
        return NO;
    }];

    //connection succeeded
    [baby setBlockOnConnected:^(CBCentralManager *central, CBPeripheral *peripheral) {
        RCTLog(@"Device '%@': connection succeeded",peripheral.name);
        BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
        device.isConnected = YES;
        //Cancel the auto-reconnect function (you must clear the auto-reconnect after successful connection, otherwise it will crash)
        [weakself AutoReconnectCancel:weakself.currentdevice.Peripheral];
        
        }];
        weakself.ESP32data=NULL;
        weakself.length=0;
    
    //Device connection failed
    [baby setBlockOnFailToConnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        RCTLog(@"Device '%@': Connection failed",peripheral.name);
        BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
        device.isConnected = NO;
        // Clear the active disconnect sign
        weakself.APPCancelConnect=NO;
        //[LocalNotifyFunc DeleteAllUserDefaultsAndCancelnotifyWithBlestate:weakself.blestate];
    }];
    //Discover services commissioned by the device
    [baby setBlockOnDiscoverServices:^(CBPeripheral *peripheral, NSError *error) {
        RCTLog(@"Discovery Service");
        //Update Bluetooth status and enter connected status
        weakself.blestate=BleStateConnected;
        //weakself.title=weakself.currentdevice.name;    
    }];

    [baby setBlockOnDidReadRSSI:^(NSNumber *RSSI, NSError *error) {
        RCTLog(@"The RSSI value of the currently connected device:%@",RSSI);
    }];

    // Set the characteristics of discovered services
    [baby setBlockOnDiscoverCharacteristics:^(CBPeripheral *peripheral, CBService *service, NSError *error) {
        RCTLog(@"===service name:%@",service.UUID);
        for (CBCharacteristic *characteristic in service.characteristics)
        {
            if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ESPRESSIF_Notify])
            {
                //Subscription notification
                [weakbaby notify:peripheral characteristic:characteristic block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error){
                     NSData *data=characteristic.value;
                    if (data.length<3) {
                        return ;
                    }
                    // RCTLog(@"The received data is%@>>>>>>>>>>>>",data);
                    // RCTLog(@"%@",[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]);
                    NSMutableData *Mutabledata=[NSMutableData dataWithData:data];
                    [weakself analyseData:Mutabledata];
                    
                     if(weakself.ConnectTimeoutTimer)
                     {
                        // Destroy connection timeout timer
                        [weakself.ConnectTimeoutTimer invalidate];
                     }
                         
                    }];
            }
            if ([characteristic.UUID.UUIDString isEqualToString:UUIDSTR_ESPRESSIF_Write])
            {
                RCTLog(@"UUIDSTR_ESPRESSIF_RX");
                _WriteCharacteristic=characteristic;
            }
        }
    }];
    
    // Read characteristic
    [baby setBlockOnReadValueForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error)
     {
         
     }];
    
    // Set up a delegate to discover descriptors of characteristics
    [baby setBlockOnDiscoverDescriptorsForCharacteristic:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
    }];
    
    //Set the delegate to read the descriptor
    [baby setBlockOnReadValueForDescriptors:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        // Log(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    }];
    
    // //Disconnect callback
    [baby setBlockOnDisconnect:^(CBCentralManager *central, CBPeripheral *peripheral, NSError *error) {
        if (error) {
            RCTLog(@"Disconnect Error %@",error);
        }
        BLEDevice *device = weakself.bleDevicesSaveDic[peripheral.identifier.UUIDString];
        device.isConnected = NO;
        
        if (weakself.APPCancelConnect) {
            // Clear flag
            weakself.APPCancelConnect=NO;
            weakself.blestate=BleStateDisconnect;
             RCTLog(@"device '%@': Disconnect",peripheral.name);
        }
        else{
            // Update Bluetooth status, connected status
            weakself.blestate=BleStateReConnect;
            // Add auto-connect
            if (weakself.currentdevice.Peripheral) {
                [weakself AutoReconnect:weakself.currentdevice.Peripheral];
                RCTLog(@"Device '%@': Reconnect",peripheral.name);
            }
        }
        // When disconnected, if there is data, save it to the database
    }];

    //Cancel all connection callbacks
    [baby setBlockOnCancelAllPeripheralsConnectionBlock:^(CBCentralManager *centralManager) {
        RCTLog(@"setBlockOnCancelAllPeripheralsConnectionBlock");
    }];

    //******** Cancel scan callback ***********//
    [baby setBlockOnCancelScanBlock:^(CBCentralManager *centralManager) {
        Log(@"Cancel scan");
         weakself.blestate=BleStateWaitToConnect;
        NSInteger count=weakself.BLEDeviceArray.count;
    }];

    // Scan Options->CBCentralManagerScanOptionAllowDuplicatesKey: Ignore multiple discovery events on the same Peripheral side are aggregated into one discovery event
    NSDictionary *scanForPeripheralsWithOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
    
    NSDictionary *connectOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnDisconnectionKey:@YES,
                                     CBConnectPeripheralOptionNotifyOnNotificationKey:@YES};
    // Connect the device->
    [baby setBabyOptionsWithScanForPeripheralsWithOptions:scanForPeripheralsWithOptions connectPeripheralWithOptions:connectOptions scanForPeripheralsWithServices:nil discoverWithServices:nil discoverWithCharacteristics:nil];
    // Subscription status changed
    [baby setBlockOnDidUpdateNotificationStateForCharacteristic:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            RCTLog(@"Subscription Error");
        }
        if (characteristic.isNotifying) {
            RCTLog(@"Subscription successful");
            [weakself writeStructDataWithCharacteristic:weakself.WriteCharacteristic WithData:[PacketCommand GetDeviceInforWithSequence:weakself.sequence]];
            [weakself SendNegotiateData];
        }
        else
        {
            RCTLog(@"Unsubscribed");
        }
    }];

    // Send data completion callback
    [weakbaby setBlockOnDidWriteValueForCharacteristic:^(CBCharacteristic *characteristic, NSError *error)
     {
         if (error)
         {
             RCTLog(@"%@",error);
             return ;
         }
         RCTLog(@"Sending data is complete");
        
    }];
}

/**
 *  Direct connection
 *
 *  @param peripheral Bluetooth device to be connected
 */
-(void)connect:(CBPeripheral *)peripheral
{
    baby.having(peripheral).connectToPeripherals().discoverServices().discoverCharacteristics().begin();
}
// Disconnect automatic reconnection
-(void)AutoReconnect:(CBPeripheral *)peripheral
{
    [baby AutoReconnect:peripheral];
}
// Delete auto reconnect
- (void)AutoReconnectCancel:(CBPeripheral *)peripheral;
{
    [baby AutoReconnectCancel:peripheral];
}

// Disconnect
-(void)Disconnect:(CBPeripheral *)Peripheral
{
    self.APPCancelConnect=YES;
    BLEDevice *device = self.bleDevicesSaveDic[Peripheral.identifier.UUIDString];
    if (device.isConnected) {
        // Cancel a connection
        [baby cancelPeripheralConnection:Peripheral];
        self.blestate=BleStateDisconnect;
    }
    
}
// Cancel all connections
-(void)CancelAllConnect
{
    if([baby findConnectedPeripherals].count>0)
    {
        self.APPCancelConnect=YES;
        // Disconnect all Bluetooth connections
        [baby cancelAllPeripheralsConnection];
    }
}

@end
