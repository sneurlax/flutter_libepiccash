
import 'dart:convert';
import 'flutter_libmwc_platform_interface.dart';
import 'models/slate.dart';
import 'mwc.dart' as mwc;

class FlutterLibmwc {
  Future<String?> getPlatformVersion() {
    return FlutterLibmwcPlatform.instance.getPlatformVersion();
  }

  /// Creates a new transaction slate using FFI (direct Rust binding)
  Future<SlateResult> createSlate(CreateSlateRequest request) async {
    try {
      final resultJson = await mwc.txCreate(
        "wallet", // TODO: Pass actual wallet instance
        request.amount,
        request.minimumConfirmations,
        request.selectionStrategyIsUseAll,
        request.note,
      );
      
      final result = json.decode(resultJson);
      return SlateResult.fromJson(result);
    } catch (e) {
      return SlateResult(
        slateJson: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Receives and processes a slate using FFI (direct Rust binding)
  Future<SlateResult> receiveSlate(ReceiveSlateRequest request) async {
    try {
      final resultJson = await mwc.txReceive(
        "wallet", // TODO: Pass actual wallet instance
        request.slateJson,
        request.message,
      );
      
      final result = json.decode(resultJson);
      return SlateResult.fromJson(result);
    } catch (e) {
      return SlateResult(
        slateJson: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Finalizes a slate using FFI (direct Rust binding)
  Future<SlateResult> finalizeSlate(FinalizeSlateRequest request) async {
    try {
      final resultJson = await mwc.txFinalize(
        "wallet", // TODO: Pass actual wallet instance
        request.slateJson,
      );
      
      final result = json.decode(resultJson);
      return SlateResult.fromJson(result);
    } catch (e) {
      return SlateResult(
        slateJson: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Encodes a slate as slatepack using FFI (direct Rust binding)
  Future<SlatepackResult> encodeSlatepack(EncodeSlatepackRequest request) async {
    try {
      final resultJson = await mwc.encodeSlatepack(
        request.slateJson,
        request.recipientAddress,
      );
      
      final result = json.decode(resultJson);
      return SlatepackResult.fromJson(result);
    } catch (e) {
      return SlatepackResult(
        slatepackString: '',
        encrypted: false,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Decodes a slatepack using FFI (direct Rust binding).
  Future<SlatepackDecodeResult> decodeSlatepack(DecodeSlatepackRequest request) async {
    try {
      final resultJson = await mwc.decodeSlatepack(request.slatepackString);
      final result = json.decode(resultJson);
      return SlatepackDecodeResult.fromJson(result);
    } catch (e) {
      return SlatepackDecodeResult(
        slateJson: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Alternative method channel-based implementations (for platform consistency).
  Future<SlateResult> createSlateViaChannel(CreateSlateRequest request) {
    return FlutterLibmwcPlatform.instance.createSlate(request);
  }

  Future<SlateResult> receiveSlateViaChannel(ReceiveSlateRequest request) {
    return FlutterLibmwcPlatform.instance.receiveSlate(request);
  }

  Future<SlateResult> finalizeSlateViaChannel(FinalizeSlateRequest request) {
    return FlutterLibmwcPlatform.instance.finalizeSlate(request);
  }

  Future<SlatepackResult> encodeSlatepackViaChannel(EncodeSlatepackRequest request) {
    return FlutterLibmwcPlatform.instance.encodeSlatepack(request);
  }

  Future<SlatepackDecodeResult> decodeSlatepackViaChannel(DecodeSlatepackRequest request) {
    return FlutterLibmwcPlatform.instance.decodeSlatepack(request);
  }
}
