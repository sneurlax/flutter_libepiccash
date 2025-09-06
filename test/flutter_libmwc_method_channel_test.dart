import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libmwc/flutter_libmwc_method_channel.dart';
import 'package:flutter_libmwc/models/slate.dart';

void main() {
  MethodChannelFlutterLibmwc platform = MethodChannelFlutterLibmwc();
  const MethodChannel channel = MethodChannel('flutter_libmwc');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return '42';
        case 'createSlate':
          return <String, dynamic>{
            'slate_json': '{"slate": "mock_created_slate"}',
            'success': true,
          };
        case 'receiveSlate':
          return <String, dynamic>{
            'slate_json': '{"slate": "mock_received_slate"}',
            'success': true,
          };
        case 'finalizeSlate':
          return <String, dynamic>{
            'slate_json': '{"slate": "mock_finalized_slate"}',
            'success': true,
          };
        case 'encodeSlatepack':
          return <String, dynamic>{
            'slatepack_string': 'BEGINSLATEPACK. mock_encoded ENDSLATEPACK.',
            'encrypted': false,
            'success': true,
          };
        case 'decodeSlatepack':
          return <String, dynamic>{
            'slate_json': '{"slate": "mock_decoded_slate"}',
            'success': true,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  group('Platform Method Tests', () {
    test('getPlatformVersion', () async {
      expect(await platform.getPlatformVersion(), '42');
    });

    test('createSlate method channel', () async {
      final request = CreateSlateRequest(
        amount: 1000000000,
        minimumConfirmations: 10,
        selectionStrategyIsUseAll: false,
        note: 'Test',
      );

      final result = await platform.createSlate(request);
      
      expect(result.success, isTrue);
      expect(result.slateJson, contains('mock_created_slate'));
    });

    test('receiveSlate method channel', () async {
      final request = ReceiveSlateRequest(
        slateJson: '{"slate": "test"}',
        message: 'Test receive',
      );

      final result = await platform.receiveSlate(request);
      
      expect(result.success, isTrue);
      expect(result.slateJson, contains('mock_received_slate'));
    });

    test('finalizeSlate method channel', () async {
      final request = FinalizeSlateRequest(
        slateJson: '{"slate": "test_finalize"}',
      );

      final result = await platform.finalizeSlate(request);
      
      expect(result.success, isTrue);
      expect(result.slateJson, contains('mock_finalized_slate'));
    });

    test('encodeSlatepack method channel', () async {
      final request = EncodeSlatepackRequest(
        slateJson: '{"slate": "test"}',
        recipientAddress: null,
      );

      final result = await platform.encodeSlatepack(request);
      
      expect(result.success, isTrue);
      expect(result.encrypted, isFalse);
      expect(result.slatepackString, startsWith('BEGINSLATEPACK.'));
    });

    test('decodeSlatepack method channel', () async {
      final request = DecodeSlatepackRequest(
        slatepackString: 'BEGINSLATEPACK. test ENDSLATEPACK.',
      );

      final result = await platform.decodeSlatepack(request);
      
      expect(result.success, isTrue);
      expect(result.slateJson, contains('mock_decoded_slate'));
    });
  });

  group('Error Handling Tests', () {
    setUp(() {
      channel.setMockMethodCallHandler((MethodCall methodCall) async {
        // Simulate error responses
        switch (methodCall.method) {
          case 'createSlate':
            return <String, dynamic>{
              'slate_json': '',
              'success': false,
              'error': 'Insufficient funds',
            };
          case 'receiveSlate':
            return <String, dynamic>{
              'slate_json': '',
              'success': false,
              'error': 'Invalid slate format',
            };
          case 'finalizeSlate':
            return <String, dynamic>{
              'slate_json': '',
              'success': false,
              'error': 'Transaction already finalized',
            };
          case 'encodeSlatepack':
            return <String, dynamic>{
              'slatepack_string': '',
              'encrypted': false,
              'success': false,
              'error': 'Invalid slate JSON',
            };
          case 'decodeSlatepack':
            return <String, dynamic>{
              'slate_json': '',
              'success': false,
              'error': 'Invalid slatepack format',
            };
          default:
            throw PlatformException(code: 'UNIMPLEMENTED');
        }
      });
    });

    test('createSlate handles errors', () async {
      final request = CreateSlateRequest(
        amount: 999999999999999, // Excessive amount
        minimumConfirmations: 10,
        selectionStrategyIsUseAll: false,
        note: 'Test',
      );

      final result = await platform.createSlate(request);
      
      expect(result.success, isFalse);
      expect(result.error, equals('Insufficient funds'));
      expect(result.slateJson, isEmpty);
    });

    test('receiveSlate handles errors', () async {
      final request = ReceiveSlateRequest(
        slateJson: 'invalid_json',
        message: null,
      );

      final result = await platform.receiveSlate(request);
      
      expect(result.success, isFalse);
      expect(result.error, equals('Invalid slate format'));
    });

    test('finalizeSlate handles errors', () async {
      final request = FinalizeSlateRequest(
        slateJson: '{"already": "finalized"}',
      );

      final result = await platform.finalizeSlate(request);
      
      expect(result.success, isFalse);
      expect(result.error, equals('Transaction already finalized'));
    });

    test('encodeSlatepack handles errors', () async {
      final request = EncodeSlatepackRequest(
        slateJson: 'invalid_slate_json',
        recipientAddress: null,
      );

      final result = await platform.encodeSlatepack(request);
      
      expect(result.success, isFalse);
      expect(result.error, equals('Invalid slate JSON'));
    });

    test('decodeSlatepack handles errors', () async {
      final request = DecodeSlatepackRequest(
        slatepackString: 'INVALID_SLATEPACK_FORMAT',
      );

      final result = await platform.decodeSlatepack(request);
      
      expect(result.success, isFalse);
      expect(result.error, equals('Invalid slatepack format'));
    });
  });
}
