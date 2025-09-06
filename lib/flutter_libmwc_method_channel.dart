import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_libmwc_platform_interface.dart';
import 'models/slate.dart';

/// An implementation of [FlutterLibmwcPlatform] that uses method channels.
class MethodChannelFlutterLibmwc extends FlutterLibmwcPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_libmwc');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<SlateResult> createSlate(CreateSlateRequest request) async {
    final result = await methodChannel.invokeMethod(
      'createSlate',
      request.toJson(),
    );
    return SlateResult.fromJson(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<SlateResult> receiveSlate(ReceiveSlateRequest request) async {
    final result = await methodChannel.invokeMethod(
      'receiveSlate',
      request.toJson(),
    );
    return SlateResult.fromJson(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<SlateResult> finalizeSlate(FinalizeSlateRequest request) async {
    final result = await methodChannel.invokeMethod(
      'finalizeSlate',
      request.toJson(),
    );
    return SlateResult.fromJson(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<SlatepackResult> encodeSlatepack(EncodeSlatepackRequest request) async {
    final result = await methodChannel.invokeMethod(
      'encodeSlatepack',
      request.toJson(),
    );
    return SlatepackResult.fromJson(Map<String, dynamic>.from(result ?? {}));
  }

  @override
  Future<SlatepackDecodeResult> decodeSlatepack(DecodeSlatepackRequest request) async {
    final result = await methodChannel.invokeMethod(
      'decodeSlatepack',
      request.toJson(),
    );
    return SlatepackDecodeResult.fromJson(Map<String, dynamic>.from(result ?? {}));
  }
}
