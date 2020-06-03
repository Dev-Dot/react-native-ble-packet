import { NativeModules, NativeEventEmitter } from 'react-native';

const { BlePacket } = NativeModules;

BlePacket.init = function (callback) {
	const BlePacketEvents = new NativeEventEmitter(BlePacket);

	if (BlePacket.subscription) {
		BlePacket.subscription.remove();
	}

	BlePacket.subscription = BlePacketEvents.addListener('devices', (data) => {
		if (callback) {
			callback(data);
		}
	});

	BlePacket.setup();
};

export default BlePacket;
