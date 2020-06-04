#import "BlePacket.h"

#import <React/RCTLog.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BabyBluetooth.h"
#import "PacketCommand.h"
#import "DH_AES.h"

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

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"devices"];
}

RCT_EXPORT_METHOD(setup)
{
    RCTLog(@"Init...");
    // Initialize the Bluetooth BabyBluetooth library
    baby=[BabyBluetooth shareBabyBluetooth];
    // Set up Bluetooth delegation
    [self BleDelegate];
    // Scanned Bluetooth device collection
    NSMutableArray *array=[NSMutableArray array];
    // Bluetooth device connection storage
    self.bleDevicesSaveDic = [NSMutableDictionary dictionaryWithCapacity:0];
    self.ESP32data=[NSMutableData data];
    self.length=0;
    self.BLEDeviceArray=array;
    // Set Bluetooth status, idle status
    self.blestate=BleStateIdle;
    // Clear the disconnect sign
    self.APPCancelConnect=NO;
    self.sequence=0;
    // Get SSH key
    self.rsaobject=[DH_AES DHGenerateKey];
}

RCT_EXPORT_METHOD(scanDevices: (RCTResponseSenderBlock)callback)
{
    RCTLog(@"scanning...");
    baby.scanForPeripherals().begin().stop(SCANTIME);
}

RCT_EXPORT_METHOD(connectDevice: (NSInteger)index)
{
    RCTLog(@"connecting to: %ld", (long)index);
    
    if (self.blestate==BleStateScan){
        [baby cancelScan];
        [baby cancelAllPeripheralsConnection];
    }
    if (index>=self.BLEDeviceArray.count) {
        return;
    }
    RCTLog(@"Take out the device");
    // Take out the device
    BLEDevice *device = self.BLEDeviceArray[index];
    CBPeripheral *Peripheral=device.Peripheral;
    device.isConnected = NO;
    RCTLog(@"DEVICE SELECTED: %@",device.name);
    // Connection
    [self connect:Peripheral];
    // Update Bluetooth status and enter connection status
    self.blestate=BleStateConnecting;
    // Save the current device information
    self.currentdevice=device;
}

RCT_EXPORT_METHOD(connectToWiFi: (NSString *)ssid password:(NSString *)password)
{
    RCTLog(@"CONECCTING TO NETWORK '%@', with password: %@",ssid, password);

    // [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetOpmode:STAOpmode Sequence:self.sequence]];
    // [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetStationSsid:ssid Sequence:self.sequence Encrypt:YES WithKeyData:self.Securtkey]];
    // [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetStationPassword:password Sequence:self.sequence Encrypt:YES WithKeyData:self.Securtkey]];
    // [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand ConnectToAPWithSequence:self.sequence]];

    [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetOpmode:STAOpmode Sequence:self.sequence]];
    [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetStationSsid:@"Fios-VNTKJ" Sequence:self.sequence Encrypt:YES WithKeyData:self.Securtkey]];
    [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand SetStationPassword:@"ribs6288dad9217wet" Sequence:self.sequence Encrypt:YES WithKeyData:self.Securtkey]];
    [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand ConnectToAPWithSequence:self.sequence]];
}

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
             RCTLog(@"Bluetooth is on");
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
             //RCTLog(@"The device does not support Bluetooth BLE");
             weakself.blestate=BleStateUnknown;
         }
         if (central.state==CBCentralManagerStatePoweredOff) {
             RCTLog(@"Bluetooth is off");
             weakself.blestate=BleStatePoweroff;
         }
     }];

    //搜索蓝牙
    [baby setBlockOnDiscoverToPeripherals:^(CBCentralManager *central, CBPeripheral *peripheral, NSDictionary *advertisementData, NSNumber *RSSI) {
//        RCTLog(@"Device found:%@,%@",peripheral.name,advertisementData);
        //Add the scanned device to the array
        //NSString *serialnumber=[BLEdataFunc GetSerialNumber:advertisementData];
        //NSString *name=[NSString stringWithFormat:@"%@%@",peripheral.name,serialnumber];
        NSString *name=[NSString stringWithFormat:@"%@",peripheral.name];
        if (![BLEdataFunc isAleadyExist:name BLEDeviceArray:weakself.BLEDeviceArray])
        {
            RCTLog(@"Device NAME: %@",name);
            BLEDevice *device=[[BLEDevice alloc]init];
            device.name=name;
            device.Peripheral=peripheral;
            device.uuidBle = peripheral.identifier.UUIDString;
            [weakself.BLEDeviceArray addObject:device];
            weakself.bleDevicesSaveDic[device.uuidBle] = device;

            [self sendEventWithName:@"devices" body:@{@"name": name, @"uuid": peripheral.identifier.UUIDString}];

        }
    }];
    
    // Set scan filter
//    [baby setFilterOnDiscoverPeripherals:^BOOL(NSString *peripheralName, NSDictionary *advertisementData, NSNumber *RSSI)
//     {
//         if ([peripheralName hasPrefix:filterBLEname])
//         {
//             return YES;
//         }
//         return NO;
//     }];
    
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
    // Discover services commissioned by the device
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
        // RCTLog(@"Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
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
        RCTLog(@"Cancel scan");
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

-(void)writeStructDataWithCharacteristic:(CBCharacteristic *)Characteristic WithData:(NSData *)data
{
    if (self.blestate!=BleStateConnected) {
        RCTLog(@"Can't perform the operation");
        return;
    }
    
    if (self.currentdevice.Peripheral && Characteristic)
    {
        RCTLog(@"Sent data=%@,%lu",data,(unsigned long)data.length);
        [[baby findConnectedPeripherals].firstObject writeValue:data forCharacteristic:Characteristic type:CBCharacteristicWriteWithResponse];
        self.sequence=self.sequence+1;
    }
}

-(void)analyseData:(NSMutableData *)data
{
    Byte *dataByte = (Byte *)[data bytes];
    
    Byte Type=dataByte[0] & 0x03;
    Byte SubType=dataByte[0]>>2;
    Byte sequence=dataByte[2];
    Byte frameControl=dataByte[1];
    Byte length=dataByte[3];

    BOOL hash=frameControl & Packet_Hash_FrameCtrlType;
    BOOL checksum=frameControl & Data_End_Checksum_FrameCtrlType;
    //BOOL Drection=frameControl & Data_Direction_FrameCtrlType;
    BOOL Ack=frameControl & ACK_FrameCtrlType;
    BOOL AppendPacket=frameControl & Append_Data_FrameCtrlType;
    
    NSRange range=NSMakeRange(4, length);
    NSData *Decryptdata=[data subdataWithRange:range];
    if (hash) {
        RCTLog(@"With encryption");
        //Decrypt
        Byte *byte=(Byte *)[Decryptdata bytes];
        if (self.Securtkey != nil) {
            Decryptdata=[DH_AES blufi_aes_DecryptWithSequence:sequence data:byte len:length KeyData:self.Securtkey];
            [data replaceBytesInRange:range withBytes:[Decryptdata bytes]];
        }
    }else{
        RCTLog(@"No encryption");
    }
    if (checksum) {
        if (length+6 != data.length) {
            return;
        }
        RCTLog(@"Verified");
        // Calculation check
        if ([PacketCommand VerifyCRCWithData:data]) {
            RCTLog(@"Verify successfully");
        }else
        {
            RCTLog(@"Verification failed, return");
//            [HUDTips ShowLabelTipsToView:self.view WithText:@"Verification failed"];
            return;
        }
        
    }
    else{
        RCTLog(@"No check");
        if (length+4 != data.length) {
            return;
        }
    }
    if(Ack)
    {
        RCTLog(@"Reply ACK");
        [self writeStructDataWithCharacteristic:self.WriteCharacteristic WithData:[PacketCommand ReturnAckWithSequence:self.sequence BackSequence:sequence]];
    }else{
        RCTLog(@"Do not reply ACK");
    }
    NSMutableData *decryptdata=[NSMutableData dataWithData:Decryptdata];
    if (AppendPacket) {
        RCTLog(@"There are follow-up packages");
        [decryptdata replaceBytesInRange:NSMakeRange(0, 2) withBytes:NULL length:0];
        //拼包
        if(self.ESP32data){
             [self.ESP32data appendData:decryptdata];
        }else{
            self.ESP32data=[NSMutableData dataWithData:decryptdata];
        }
        self.length=self.length+length;
        return;
    }else{
        RCTLog(@"No follow-up package");
        if(self.ESP32data){
            [self.ESP32data appendData:decryptdata];
            decryptdata =[NSMutableData dataWithData:self.ESP32data];
            self.ESP32data=NULL;
            length = self.length+length;
            self.length=0;
        }
    }

    if (Type==ContolType)
    {
        RCTLog(@"Control packet received ===========");
        [self GetControlPacketWithData:decryptdata SubType:SubType];
    }
    else if (Type==DataType)
    {
        RCTLog(@"Received data packet ===========");
        [self GetDataPackectWithData:decryptdata SubType:SubType];
    }
    else
    {
        RCTLog(@"Abnormal packet");
//        [HUDTips ShowLabelTipsToView:self.view WithText:@"Abnormal packet"];
    }
}

-(void)GetControlPacketWithData:(NSData *)data SubType:(Byte)subtype
{
    switch (subtype) {
        case ACK_Esp32_Phone_ControlSubType:
        {
            RCTLog(@"ACK received<<<<<<<<<<<<<<<");
        }
            break;
        case ESP32_Phone_Security_ControlSubType:
            break;
            
        case Wifi_Op_ControlSubType:
            break;
            
        case Connect_AP_ControlSubType:
            break;
        case Disconnect_AP_ControlSubType:
            break;
        case Get_Wifi_Status_ControlSubType:
            break;
        case Deauthenticate_STA_Device_SoftAP_ControlSubType:
            break;
        case Get_Version_ControlSubType:
            break;
        case Negotiate_Data_ControlSubType:
            break;
            
        default:
            break;
    }

}

-(void)GetDataPackectWithData:(NSData *)data SubType:(Byte)subtype
{
    Byte *dataByte = (Byte *)[data bytes];
    //Byte length=dataByte[3];
    
    switch (subtype) {
        case Negotiate_Data_DataSubType: //
        {
            //NSData *NegotiateData=[data subdataWithRange:NSMakeRange(4, length)];
            self.Securtkey=[DH_AES GetSecurtKey:data RsaObject:self.rsaobject];
            NSLog(@"%@", self.Securtkey);
            // Set encryption mode
            NSData *SetSecuritydata=[PacketCommand SetESP32ToPhoneSecurityWithSecurity:YES CheckSum:YES Sequence:self.sequence];
            [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:SetSecuritydata];
            
            // Get status report
            [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:[PacketCommand GetDeviceInforWithSequence:self.sequence]];
        }
            break;
            
        case BSSID_STA_DataSubType:
            
            break;
        case SSID_STA_DataSubType:
            
            break;
        case Password_STA_DataSubType:
            
            break;
        case SSID_SoftaAP_DataSubType:
            
            break;
        case Password_SoftAP_DataSubType:
            
            break;
        case Max_Connect_Number_SoftAP_DataSubType:
            
            break;
        case Authentication_SoftAP_DataSubType:
            
            break;
        case Channel_SoftAP_DataSubType:
            
            break;
            
        case Username_DataSubType:
            
            break;
        case CA_Certification_DataSubType:
            
            break;
        case Client_Certification_DataSubType:
            
            break;
        case Server_Certification_DataSubType:
            
            break;
        case Client_PrivateKey_DataSubType:
            
            break;
            
        case Server_PrivateKey_DataSubType:
            
            break;
        case Wifi_List_DataSubType:
            RCTLog(@"======Wifi_List_DataSubType");
            RCTLog(@"%@, %lu", data, (unsigned long)data.length);
            uint8_t ssid_length=dataByte[0];
            while (ssid_length>0) {
                if (data.length<(ssid_length+1)) {
                    break;
                }
                Byte *dataByte = (Byte *)[data bytes];
                int8_t rssi= dataByte[1];
                NSData *ssid=[data subdataWithRange:NSMakeRange(2, ssid_length-1)];
                NSString *ssidStr=[[NSString alloc]initWithData:ssid encoding:NSUTF8StringEncoding];
                RCTLog(@"%@, rssi %d", ssidStr, rssi);
                data=[data subdataWithRange:NSMakeRange(ssid_length+1, data.length-ssid_length-1)];
                if (data.length<=1) {
                    break;
                }
                Byte *RemainByte = (Byte *)[data bytes];
                ssid_length = RemainByte[0];
                
            }
            break;
        case blufi_error_DataSubType:
            if (data.length == 1) {
                RCTLog(@"report error %d", dataByte[0]);
            }
            break;
        case blufi_custom_DataSubType:{
            NSString *str=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            RCTLog(@"receive custom data %@", str);
            break;
        }
        case Wifi_Connection_state_Report_DataSubType: // Connection status report
        {
            if (data.length<3) {
                return;
            }
            RCTLog(@"Connection status packet received<<<<<<<<<<<<<<<<");
            NSString *OpmodeTitle;
            switch (dataByte[0])
            {
                case NullOpmode:
                {
                    OpmodeTitle=@"Null Mode";
                    
                }
                    break;
                case STAOpmode:
                    OpmodeTitle=@"STA mode";
                    
                    break;
                case SoftAPOpmode:
                    OpmodeTitle=@"SoftAP mode";
                    
                    break;
                case SoftAP_STAOpmode:
                    OpmodeTitle=@"SoftAP/STA mode";
                    
                    break;
                    
                default:
                    OpmodeTitle=@"Unknown mode";

                    break;
            }
            RCTLog(@"%@",OpmodeTitle);
//            self.Opmodelabel.text=OpmodeTitle;
            
            NSString *StateTitle;
            if (dataByte[1]==0x0) {
                StateTitle=@"STA connection status";
            }else
            {
                StateTitle=@"STA is not connected";
            }
            RCTLog(@"%@",StateTitle);
//            self.STAStatelabel.text=StateTitle;
            
            RCTLog(@"SoftAP connection status,%d 个STA",dataByte[2]);
//            self.STACountlabel.text=[NSString stringWithFormat:@"Number of SoftAP connected devices:%d",dataByte[2]];
//            self.BSSidSTAlabel.text=@"";
//            self.SSidSTAlabel.text=@"";
            if(data.length==0x13)
            {
                NSString *SSID=[[NSString alloc]initWithData:[data subdataWithRange:NSMakeRange(13, dataByte[12])] encoding:NSASCIIStringEncoding];
//                self.SSidSTAlabel.text=[NSString stringWithFormat:@"STA_WIFI_SSID:%@",SSID];
//                self.BSSidSTAlabel.text=[NSString stringWithFormat:@"STA_WIFI_BSSID:%02x%02x%02x%02x%02x%02x",dataByte[5],dataByte[6],dataByte[7],dataByte[8],dataByte[9],dataByte[10]];
            }
        }
            break;
        case Version_DataSubType:
            
            break;
            
        default:
            RCTLog(@"unknown data");
            break;
    }


}

// Send negotiation packet
-(void)SendNegotiateData
{
    if (!self.rsaobject) {
        self.rsaobject=[DH_AES DHGenerateKey];
    }
    NSInteger datacount=80;
    //Send data length
    uint16_t length=self.rsaobject.P.length+self.rsaobject.g.length+self.rsaobject.PublickKey.length+6;
    [self writeStructDataWithCharacteristic:self.WriteCharacteristic WithData:[PacketCommand SetNegotiatelength:length Sequence:self.sequence]];
    
    // Send data, need to subcontract
    self.senddata=[PacketCommand GenerateNegotiateData:self.rsaobject];
    // NSInteger number=self.senddata.length/datacount;
    NSInteger number = self.senddata.length / datacount + ((self.senddata.length % datacount)>0? 1:0);
    NSLog(@"number:%ld",(long)number);
    if (number>0) {
        for(NSInteger i = 0;i < number;i ++){
            if (i == number-1) {
                NSLog(@"i:%ld",(long)i);
                NSData *data=[PacketCommand SendNegotiateData:self.senddata Sequence:self.sequence Frag:NO TotalLength:self.senddata.length];
                [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:data];
                
            }else {
                NSLog(@"self.senddata.length:%lu",(unsigned long)self.senddata.length);
                NSData *data=[PacketCommand SendNegotiateData:[self.senddata subdataWithRange:NSMakeRange(0, datacount)] Sequence:self.sequence Frag:YES TotalLength:self.senddata.length];
                [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:data];
                self.senddata=[self.senddata subdataWithRange:NSMakeRange(datacount, self.senddata.length-datacount)];
            }
        }
        
    }else {
        NSData *data=[PacketCommand SendNegotiateData:self.senddata Sequence:self.sequence Frag:NO TotalLength:self.senddata.length];
        [self writeStructDataWithCharacteristic:_WriteCharacteristic WithData:data];
    }
}

@end
