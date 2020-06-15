package com.BlePacket;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import android.util.Log;

public class BlePacketModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;

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
        Log.d("setup", "Call to 'setup' method");
    }

    @ReactMethod
    public void scanDevices() {
        WritableMap params = Arguments.createMap();
        params.putString("log", "Call to 'scanDevices' method");

        sendEvent(reactContext, "status", params);
    }

    @ReactMethod
    public void stopDeviceScan() {
        Log.d("stopDeviceScan", "Call to 'stopDeviceScan' method");
    }

    @ReactMethod
    public void connectDevice(int index) {
    String i = String.valueOf(index)
        Log.d("connectDevice", "Call to 'connectDevice' method with param " + i);
    }

    @ReactMethod
    public void connectToWiFi(String ssid, String password) {
        Log.d("connectToWiFi", "Call to 'connectToWiFi' method with params " + ssid + " and " + password);
    }

    @ReactMethod
    public void cancelConnections() {
        Log.d("cancelConnections", "Call to 'cancelConnections' method");
    }

    private void sendEvent(ReactContext reactContext, String eventName, WritableMap params) {
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(eventName, params);
    }
}
