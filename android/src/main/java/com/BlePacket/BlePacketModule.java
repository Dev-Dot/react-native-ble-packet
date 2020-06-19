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

public class BlePacketModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;

    private static final long TIMEOUT_SCAN = 4000L;

    private static final int REQUEST_PERMISSION = 0x01;
    private static final int REQUEST_BLUFI = 0x10;

    private static final int MENU_SETTINGS = 0x01;

    // private SwipeRefreshLayout mRefreshLayout;

    // private RecyclerView mRecyclerView;
    private List<ScanResult> mBleList;
    // private BleAdapter mBleAdapter;

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
        // mBleAdapter = new BleAdapter();
        // mRecyclerView.setAdapter(mBleAdapter);

        mDeviceMap = new HashMap<>();
        mScanCallback = new ScanCallback();

        // ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, REQUEST_PERMISSION);
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
        // mBleAdapter.notifyDataSetChanged();
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
            // mLog.d("Scan ble thread is interrupted");
        });

    }

    @ReactMethod
    public void stopDeviceScan() {
        sendStatus("scanning");

    }

    @ReactMethod
    public void connectDevice(int index) {
        sendStatus("connecting");
    }

    @ReactMethod
    public void connectToWiFi(String ssid, String password) {
        Log.d("connectToWiFi", "Call to 'connectToWiFi' method with params " + ssid + " and " + password);
        sendStatus("sending-credentials");
    }

    @ReactMethod
    public void cancelConnections() {
        Log.d("cancelConnections", "Call to 'cancelConnections' method");
    }

    private void onIntervalScanUpdate(boolean over) {
        List<ScanResult> devices = new ArrayList<>(mDeviceMap.values());
        Collections.sort(devices, (dev1, dev2) -> {
            Integer rssi1 = dev1.getRssi();
            Integer rssi2 = dev2.getRssi();
            return rssi2.compareTo(rssi1);
        });
        
        // runOnUiThread(() -> {
        //     mBleList.clear();
        //     mBleList.addAll(devices);
        //     mBleAdapter.notifyDataSetChanged();

        //     if (over) {
        //         mRefreshLayout.setRefreshing(false);
        //     }
        // });
    }

    private void sendLog(String text) {
        WritableMap params = Arguments.createMap();
        params.putString("value", text);

        sendEvent(reactContext, "log", params);
    }

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

            sendDevice(scanResult.getDevice().getAddress(), name);

            mDeviceMap.put(scanResult.getDevice().getAddress(), scanResult);
        }
    }
}
