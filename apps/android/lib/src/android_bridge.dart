import 'package:flutter/services.dart';

class AndroidScreenscrabBridge {
  static const MethodChannel _channel = MethodChannel('screenscrab/native');

  Future<String> platformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion') ?? 'unknown';
  }

  Future<bool> setClipboardText(String text) async {
    return await _channel.invokeMethod<bool>('setClipboardText', <String, Object?>{'text': text}) ?? false;
  }

  Future<String> readClipboardText() async {
    return await _channel.invokeMethod<String>('readClipboardText') ?? '';
  }

  Future<bool> playAudio() async {
    return await _channel.invokeMethod<bool>('playAudioPlaceholder') ?? false;
  }

  Future<bool> touchToMouse({required double x, required double y, required String action}) async {
    return await _channel.invokeMethod<bool>(
          'touchToMouse',
          <String, Object?>{'x': x, 'y': y, 'action': action},
        ) ??
        false;
  }

  Future<bool> sendKeyEvent({required int keyCode, required bool down}) async {
    return await _channel.invokeMethod<bool>(
          'sendKeyEvent',
          <String, Object?>{'keyCode': keyCode, 'down': down},
        ) ??
        false;
  }

  Future<bool> decodeFrame(Uint8List frameBytes, {required int width, required int height}) async {
    return await _channel.invokeMethod<bool>(
          'decodeFrame',
          <String, Object?>{'frameBytes': frameBytes, 'width': width, 'height': height},
        ) ??
        false;
  }
}
