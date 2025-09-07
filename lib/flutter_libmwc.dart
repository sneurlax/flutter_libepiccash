
import 'dart:convert';
import 'flutter_libmwc_platform_interface.dart';
import 'models/slate.dart';
import 'mwc.dart' as mwc;

class FlutterLibmwc {
  Future<String?> getPlatformVersion() {
    return FlutterLibmwcPlatform.instance.getPlatformVersion();
  }
  
  // Methods that require wallet handle - these should be called with walletHandle parameter
  // 
  // Example usage with WalletService (from example app):
  // ```dart
  // import 'package:flutter_libmwc_example/services/wallet_service.dart';
  // 
  // final walletHandle = WalletService.getCurrentWalletHandle();
  // final flutterLibmwc = FlutterLibmwc();
  // final result = await flutterLibmwc.createSlate(request, walletHandle: walletHandle);
  // ```

  /// Creates a new transaction slate using FFI (direct Rust binding)
  /// 
  /// [walletHandle] - The wallet handle obtained from wallet creation/opening operations.
  /// If using with the example app, get this from WalletService._currentWalletHandle.
  Future<SlateResult> createSlate(CreateSlateRequest request, {String? walletHandle}) async {
    try {
      if (walletHandle == null) {
        return SlateResult(
          slateJson: '',
          success: false,
          error: 'No wallet handle provided. Please open a wallet first.',
        );
      }
      
      final resultJson = await mwc.txCreate(
        walletHandle,
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
  /// 
  /// [walletHandle] - The wallet handle obtained from wallet creation/opening operations.
  Future<SlateResult> receiveSlate(ReceiveSlateRequest request, {String? walletHandle}) async {
    try {
      if (walletHandle == null) {
        return SlateResult(
          slateJson: '',
          success: false,
          error: 'No wallet handle provided. Please open a wallet first.',
        );
      }
      
      final resultJson = await mwc.txReceive(
        walletHandle,
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
  /// 
  /// [walletHandle] - The wallet handle obtained from wallet creation/opening operations.
  Future<SlateResult> finalizeSlate(FinalizeSlateRequest request, {String? walletHandle}) async {
    try {
      if (walletHandle == null) {
        return SlateResult(
          slateJson: '',
          success: false,
          error: 'No wallet handle provided. Please open a wallet first.',
        );
      }
      
      final resultJson = await mwc.txFinalize(
        walletHandle,
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

  /// Encodes a slate as slatepack using FFI (direct Rust binding).
  Future<SlatepackResult> encodeSlatepack(EncodeSlatepackRequest request) async {
    try {
      final slatepackString = await mwc.encodeSlatepack(
        request.slateJson,
        request.recipientAddress,
      );
      
      // Check if the result is a slatepack string (starts with BEGINSLATEPACK.).
      if (slatepackString.startsWith('BEGINSLATEPACK.')) {
        return SlatepackResult(
          slatepackString: slatepackString,
          encrypted: request.recipientAddress != null,
          success: true,
          error: null,
        );
      } else {
        // Try to parse as JSON error response.
        try {
          final result = json.decode(slatepackString);
          return SlatepackResult.fromJson(result);
        } catch (_) {
          // If not JSON and not slatepack, treat as error message.
          return SlatepackResult(
            slatepackString: '',
            encrypted: false,
            success: false,
            error: slatepackString,
          );
        }
      }
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
