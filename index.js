import { NativeModules, NativeEventEmitter } from 'react-native';

const { BlePacket } = NativeModules;

BlePacket.init = function(statusCallback, devicesCallback, logCallback) {
	const BlePacketEvents = new NativeEventEmitter(BlePacket);

	if (BlePacket.statusSub) {
		BlePacket.statusSub.remove();
	}

	if (BlePacket.devicesSub) {
		BlePacket.devicesSub.remove();
	}

	// if (BlePacket.logSub) {
	// 	BlePacket.logSub.remove();
	// }

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

	// BlePacket.logSub = BlePacketEvents.addListener('log', (data) => {
	// 	if (logCallback) {
	// 		logCallback(data);
	// 	}
	// });

	BlePacket.setup();
};

export default BlePacket;
