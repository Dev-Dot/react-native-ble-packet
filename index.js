import { NativeModules, NativeEventEmitter } from 'react-native';

const { BlePacket } = NativeModules;

BlePacket.init = function(statusCallback, devicesCallback) {
	const BlePacketEvents = new NativeEventEmitter(BlePacket);

	if (BlePacket.statusSub) {
		BlePacket.statusSub.remove();
	}

	if (BlePacket.devicesSub) {
		BlePacket.devicesSub.remove();
	}

	BlePacket.statusSub = BlePacketEvents.addListener('status', (data) => {
		if (statusCallback) {
			statusCallback(data);
		}
	});

	BlePacket.devicesSub = BlePacketEvents.addListener('devices', (data) => {
		if (devicesCallback) {
			devicesCallback(data);
		}
	});

	BlePacket.setup();
};

export default BlePacket;
