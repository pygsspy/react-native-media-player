import ReactNative, {
  PixelRatio,
  NativeModules,
  NativeAppEventEmitter,
  DeviceEventEmitter
} from "react-native";
import RNFS from "react-native-fs";

import MediaPlayer from "./media_player";

module.exports = new MediaPlayer({
  PixelRatio,
  NativeModules,
  NativeAppEventEmitter,
  DeviceEventEmitter,
  RNFS
});
