package com.BlePacket;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import android.util.Log;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothProfile;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;

import com.BlePacket.R;
import com.BlePacket.constants.BlufiConstants;
import com.BlePacket.constants.SettingsConstants;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.Toolbar;
import androidx.core.app.ActivityCompat;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import com.BlePacket.BlufiCallback;
import com.BlePacket.BlufiClient;
import com.BlePacket.params.BlufiConfigureParams;
import com.BlePacket.params.BlufiParameter;
import com.BlePacket.response.BlufiScanResult;
import com.BlePacket.response.BlufiStatusResponse;
import com.BlePacket.response.BlufiVersionResponse;

public class BlePacketModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;

    private static final long TIMEOUT_SCAN = 4000L;

    private static final int REQUEST_PERMISSION = 0x01;
    private static final int REQUEST_BLUFI = 0x10;

    private static final int MENU_SETTINGS = 0x01;

    private BluetoothDevice mDevice;
    private BlufiClient mBlufiClient;
    private volatile boolean mConnected;

    private List<ScanResult> mBleList;

    private Map<String, ScanResult> mDeviceMap;
    private ScanCallback mScanCallback;
    private String mBlufiFilter;
    private volatile long mScanStartTime;

    private ExecutorService mThreadPool;
    private Future mUpdateFuture;

    public BlePacketModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    @Override
    public String getName() {
        return "BlePacket";
    }

    @ReactMethod
    public void setup() {
        sendStatus("waiting");

        mThreadPool = Executors.newSingleThreadExecutor();
        mBleList = new LinkedList<>();
        mDeviceMap = new HashMap<>();
        mScanCallback = new ScanCallback();
    }

    @ReactMethod
    public void scanDevices() {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (!adapter.isEnabled() || scanner == null) {
            sendStatus("error");
            return;
        }

        mDeviceMap.clear();
        mBleList.clear();

        mBlufiFilter = (String) BlufiConstants.BLUFI_PREFIX;
        mScanStartTime = SystemClock.elapsedRealtime();

        sendStatus("scanning");
        scanner.startScan(null, new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                mScanCallback);
        mUpdateFuture = mThreadPool.submit(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                    break;
                }

                long scanCost = SystemClock.elapsedRealtime() - mScanStartTime;
                if (scanCost > TIMEOUT_SCAN) {
                    break;
                }

                onIntervalScanUpdate(false);
            }

            BluetoothLeScanner inScanner = BluetoothAdapter.getDefaultAdapter().getBluetoothLeScanner();
            if (inScanner != null) {
                inScanner.stopScan(mScanCallback);
            }
            onIntervalScanUpdate(true);
        });

    }

    @ReactMethod
    public void stopDeviceScan() {
        stopScan();
        sendStatus("stoped");

    }

    @ReactMethod
    public void connectDevice(int index) {
        sendStatus("connecting");

        List<ScanResult> devices = new ArrayList<>(mDeviceMap.values());
        ScanResult scanResult = devices.get(index);

        if (scanResult != null) {
            stopScan();
            gotoDevice(scanResult.getDevice());   
        } else {
            sendStatus("error");
        }
    }

    @ReactMethod
    public void connectToWiFi(String ssid, String password) {
        // sendLog("Call to 'connectToWiFi' method with params " + ssid + " and " + password);
        sendStatus("sending-credentials");

        final BlufiConfigureParams params = new BlufiConfigureParams();
        int deviceMode = BlufiParameter.OP_MODE_STA;
        params.setOpMode(deviceMode);
        params.setStaSSIDBytes(ssid.getBytes());
        params.setStaPassword(password);

        mBlufiClient.configure(params);
    }

    @ReactMethod
    public void cancelConnections() {
        // sendLog("Call to 'cancelConnections' method");
        if (mBlufiClient != null) {
            mBlufiClient.requestCloseConnection();
        }
    }

    private void onIntervalScanUpdate(boolean over) {
        List<ScanResult> devices = new ArrayList<>(mDeviceMap.values());
        Collections.sort(devices, (dev1, dev2) -> {
            Integer rssi1 = dev1.getRssi();
            Integer rssi2 = dev2.getRssi();
            return rssi2.compareTo(rssi1);
        });
    }

    private void stopScan() {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        BluetoothLeScanner scanner = adapter.getBluetoothLeScanner();
        if (scanner != null) {
            scanner.stopScan(mScanCallback);
        }
        if (mUpdateFuture != null) {
            mUpdateFuture.cancel(true);
        }
    }

    private void gotoDevice(BluetoothDevice device) {
        // connect device
        if (mBlufiClient != null) {
            mBlufiClient.close();
            mBlufiClient = null;
        }

        if (reactContext == null || device == null) {
            sendStatus("error");
            // sendLog("reactContext or device is null");
        }

        mBlufiClient = new BlufiClient(reactContext, device);
        mBlufiClient.setGattCallback(new GattCallback());
        mBlufiClient.setBlufiCallback(new BlufiCallbackMain());
        mBlufiClient.connect();

        mDeviceMap.clear();
        mBleList.clear();
    }

    private void onNegotiateSecurity() {
        if (mBlufiClient == null) {
            sendStatus("error");
        }

        // negotiate security
        mBlufiClient.negotiateSecurity();
    }

    // private void sendLog(String text) {
    //     WritableMap params = Arguments.createMap();
    //     params.putString("value", text);

    //     sendEvent(reactContext, "log", params);
    // }

    private void sendStatus(String status) {
        WritableMap params = Arguments.createMap();
        params.putString("value", status);

        sendEvent(reactContext, "status", params);
    }

    private void sendDevice(String uuid, String name) {
        WritableMap params = Arguments.createMap();
        params.putString("uuid", uuid);
        params.putString("name", name);

        sendEvent(reactContext, "devices", params);
    }

    private void sendEvent(ReactApplicationContext reactContext, String eventName, WritableMap params) {
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
    }

    private class ScanCallback extends android.bluetooth.le.ScanCallback {

        @Override
        public void onScanFailed(int errorCode) {
            super.onScanFailed(errorCode);
            sendStatus("error");
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            for (ScanResult result : results) {
                onLeScan(result);
            }
        }

        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            onLeScan(result);
        }

        private void onLeScan(ScanResult scanResult) {
            String name = scanResult.getDevice().getName();
            
            if (name == null || !name.startsWith(mBlufiFilter)) {
                return;
            }

            String address = scanResult.getDevice().getAddress();

            if (mDeviceMap.containsKey(address)) {
                return;
            }

            sendDevice(address, name);

            mDeviceMap.put(address, scanResult);
        }
    }

    /**
     * mBlufiClient call onCharacteristicWrite and onCharacteristicChanged is required
     */
    private class GattCallback extends BluetoothGattCallback {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            String devAddr = gatt.getDevice().getAddress();
            // sendLog("onConnectionStateChange addr="+devAddr+" status="+status+", newState="+newState);

            if (status == BluetoothGatt.GATT_SUCCESS) {
                switch (newState) {
                    case BluetoothProfile.STATE_CONNECTED:
                        // sendLog("Connected "+devAddr);
                        break;
                    case BluetoothProfile.STATE_DISCONNECTED:
                        gatt.close();
                        // sendLog("Disconnected "+devAddr);
                        break;
                }
            } else {
                gatt.close();
                // sendLog("Disconnect "+devAddr+", status="+status);
            }
        }

        @Override
        public void onMtuChanged(BluetoothGatt gatt, int mtu, int status) {
            // sendLog("onMtuChanged status="+status+", mtu="+mtu);
            if (status == BluetoothGatt.GATT_SUCCESS) {
                // sendLog("Set mtu complete, mtu="+mtu);
            } else {
                mBlufiClient.setPostPackageLengthLimit(20);
                // sendLog("Set mtu failed, mtu="+mtu+", status="+status);
                sendStatus("error");
            }

            onNegotiateSecurity();
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            // sendLog("onServicesDiscovered status="+status);
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.disconnect();
                // sendLog("Discover services error status "+status);
            }
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.disconnect();
                // sendLog("WriteChar error status "+status);
            }
        }
    }

    private class BlufiCallbackMain extends BlufiCallback {
        @Override
        public void onGattPrepared(BlufiClient client, BluetoothGatt gatt, BluetoothGattService service,
                                   BluetoothGattCharacteristic writeChar, BluetoothGattCharacteristic notifyChar) {
            if (service == null) {
                // sendLog("Discover service failed");
                gatt.disconnect();
                sendStatus("error");
                return;
            }
            if (writeChar == null) {
                // sendLog("Get write characteristic failed");
                gatt.disconnect();
                sendStatus("error");
                return;
            }
            if (notifyChar == null) {
                // sendLog("Get notification characteristic failed");
                gatt.disconnect();
                sendStatus("error");
                return;
            }

            // sendLog("Discover service and characteristics success");

            int mtu = BlufiConstants.DEFAULT_MTU_LENGTH;
            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.M && Build.MANUFACTURER.toLowerCase().startsWith("samsung")) {
                mtu = 23;
            }

            boolean requestMtu = gatt.requestMtu(mtu);
            if (!requestMtu) {
                client.setPostPackageLengthLimit(20);
                // sendLog("Request mtu "+mtu+" failed");
                onNegotiateSecurity();
            }
        }

        @Override
        public void onNegotiateSecurityResult(BlufiClient client, int status) {
            if (status == STATUS_SUCCESS) {
                // sendLog("Negotiate security complete");
                sendStatus("connected");
            } else {
                // sendLog("Negotiate security failed， code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onConfigureResult(BlufiClient client, int status) {
            if (status == STATUS_SUCCESS) {
                // sendLog("Post configure params complete");
                sendStatus("done");
            } else {
                // sendLog("Post configure params failed, code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onDeviceStatusResponse(BlufiClient client, int status, BlufiStatusResponse response) {
            if (status == STATUS_SUCCESS) {
                // sendLog("Receive device status response:\n"+response.generateValidInfo());
            } else {
                // sendLog("Device status response error, code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onDeviceScanResult(BlufiClient client, int status, List<BlufiScanResult> results) {
            if (status == STATUS_SUCCESS) {
                StringBuilder msg = new StringBuilder();
                msg.append("Receive device scan result:\n");
                for (BlufiScanResult scanResult : results) {
                    msg.append(scanResult.toString()).append("\n");
                }
                // sendLog(msg.toString());
            } else {
                // sendLog("Device scan result error, code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onDeviceVersionResponse(BlufiClient client, int status, BlufiVersionResponse response) {
            if (status == STATUS_SUCCESS) {
                // sendLog("Receive device version: "+response.getVersionString());
            } else {
                // sendLog("Device version error, code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onPostCustomDataResult(BlufiClient client, int status, byte[] data) {
            String dataStr = new String(data);
            String format = "Post data %s %s";
            if (status == STATUS_SUCCESS) {
                // sendLog(String.format(format, dataStr, "complete"));
            } else {
                // sendLog(String.format(format, dataStr, "failed"));
                sendStatus("error");
            }
        }

        @Override
        public void onReceiveCustomData(BlufiClient client, int status, byte[] data) {
            if (status == STATUS_SUCCESS) {
                String customStr = new String(data);
                // sendLog("Receive custom data:\n"+customStr);
            } else {
                // sendLog("Receive custom data error, code=" + status);
                sendStatus("error");
            }
        }

        @Override
        public void onError(BlufiClient client, int errCode) {
            // sendLog("Receive error code "+errCode);
            sendStatus("error");
        }
    }
}
