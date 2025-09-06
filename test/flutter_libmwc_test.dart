import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libmwc/flutter_libmwc.dart';
import 'package:flutter_libmwc/flutter_libmwc_platform_interface.dart';
import 'package:flutter_libmwc/flutter_libmwc_method_channel.dart';
import 'package:flutter_libmwc/models/slate.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLibmwcPlatform
    with MockPlatformInterfaceMixin
    implements FlutterLibmwcPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<SlateResult> createSlate(CreateSlateRequest request) async {
    return SlateResult(
      slateJson: '{"slate": "mock_slate_json"}',
      success: true,
      error: null,
    );
  }

  @override
  Future<SlateResult> receiveSlate(ReceiveSlateRequest request) async {
    return SlateResult(
      slateJson: '{"slate": "mock_received_slate"}',
      success: true,
      error: null,
    );
  }

  @override
  Future<SlateResult> finalizeSlate(FinalizeSlateRequest request) async {
    return SlateResult(
      slateJson: '{"slate": "mock_finalized_slate"}',
      success: true,
      error: null,
    );
  }

  @override
  Future<SlatepackResult> encodeSlatepack(EncodeSlatepackRequest request) async {
    return SlatepackResult(
      slatepackString: 'BEGINSLATEPACK. mock_encoded_slatepack ENDSLATEPACK.',
      encrypted: request.recipientAddress != null,
      success: true,
      error: null,
    );
  }

  @override
  Future<SlatepackDecodeResult> decodeSlatepack(DecodeSlatepackRequest request) async {
    return SlatepackDecodeResult(
      slateJson: '{"slate": "mock_decoded_slate"}',
      success: true,
      error: null,
    );
  }
}

void main() {
  final FlutterLibmwcPlatform initialPlatform = FlutterLibmwcPlatform.instance;

  group('FlutterLibmwc Platform Tests', () {
    test('$MethodChannelFlutterLibmwc is the default instance', () {
      expect(initialPlatform, isInstanceOf<MethodChannelFlutterLibmwc>());
    });

    test('getPlatformVersion', () async {
      FlutterLibmwc flutterLibmwcPlugin = FlutterLibmwc();
      MockFlutterLibmwcPlatform fakePlatform = MockFlutterLibmwcPlatform();
      FlutterLibmwcPlatform.instance = fakePlatform;

      expect(await flutterLibmwcPlugin.getPlatformVersion(), '42');
    });
  });

  group('Slate Operations Tests', () {
    late FlutterLibmwc plugin;
    late MockFlutterLibmwcPlatform mockPlatform;

    setUp(() {
      plugin = FlutterLibmwc();
      mockPlatform = MockFlutterLibmwcPlatform();
      FlutterLibmwcPlatform.instance = mockPlatform;
    });

    test('createSlate returns valid SlateResult', () async {
      final request = CreateSlateRequest(
        amount: 1000000000, // 1 MWC in nano
        minimumConfirmations: 10,
        selectionStrategyIsUseAll: false,
        note: 'Test transaction',
      );

      final result = await plugin.createSlateViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.slateJson, contains('mock_slate_json'));
    });

    test('receiveSlate returns valid SlateResult', () async {
      final request = ReceiveSlateRequest(
        slateJson: '{"slate": "test_slate"}',
        message: 'Test receive',
      );

      final result = await plugin.receiveSlateViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.slateJson, contains('mock_received_slate'));
    });

    test('finalizeSlate returns valid SlateResult', () async {
      final request = FinalizeSlateRequest(
        slateJson: '{"slate": "test_finalize_slate"}',
      );

      final result = await plugin.finalizeSlateViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.slateJson, contains('mock_finalized_slate'));
    });
  });

  group('Slatepack Operations Tests', () {
    late FlutterLibmwc plugin;
    late MockFlutterLibmwcPlatform mockPlatform;

    setUp(() {
      plugin = FlutterLibmwc();
      mockPlatform = MockFlutterLibmwcPlatform();
      FlutterLibmwcPlatform.instance = mockPlatform;
    });

    test('encodeSlatepack with unencrypted returns valid SlatepackResult', () async {
      final request = EncodeSlatepackRequest(
        slateJson: '{"slate": "test_slate"}',
        recipientAddress: null, // unencrypted
      );

      final result = await plugin.encodeSlatepackViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.encrypted, isFalse);
      expect(result.slatepackString, startsWith('BEGINSLATEPACK.'));
      expect(result.slatepackString, endsWith('ENDSLATEPACK.'));
    });

    test('encodeSlatepack with encryption returns encrypted SlatepackResult', () async {
      final request = EncodeSlatepackRequest(
        slateJson: '{"slate": "test_slate"}',
        recipientAddress: 'mwcmqs://test_address',
      );

      final result = await plugin.encodeSlatepackViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.encrypted, isTrue);
      expect(result.slatepackString, startsWith('BEGINSLATEPACK.'));
    });

    test('decodeSlatepack returns valid SlatepackDecodeResult', () async {
      final request = DecodeSlatepackRequest(
        slatepackString: 'BEGINSLATEPACK. mock_encoded_data ENDSLATEPACK.',
      );

      final result = await plugin.decodeSlatepackViaChannel(request);

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.slateJson, contains('mock_decoded_slate'));
    });
  });

  group('Data Model Tests', () {
    test('SlateResult fromJson and toJson', () {
      final json = {
        'slate_json': '{"test": "data"}',
        'success': true,
        'error': null,
      };

      final result = SlateResult.fromJson(json);
      expect(result.slateJson, equals('{"test": "data"}'));
      expect(result.success, isTrue);
      expect(result.error, isNull);

      final backToJson = result.toJson();
      expect(backToJson['slate_json'], equals('{"test": "data"}'));
      expect(backToJson['success'], isTrue);
      expect(backToJson.containsKey('error'), isFalse);
    });

    test('SlatepackResult fromJson and toJson', () {
      final json = {
        'slatepack_string': 'BEGINSLATEPACK. test ENDSLATEPACK.',
        'encrypted': false,
        'sender': null,
        'recipient': null,
        'success': true,
        'error': null,
      };

      final result = SlatepackResult.fromJson(json);
      expect(result.slatepackString, equals('BEGINSLATEPACK. test ENDSLATEPACK.'));
      expect(result.encrypted, isFalse);
      expect(result.success, isTrue);

      final backToJson = result.toJson();
      expect(backToJson['slatepack_string'], equals('BEGINSLATEPACK. test ENDSLATEPACK.'));
      expect(backToJson['encrypted'], isFalse);
    });

    test('CreateSlateRequest toJson', () {
      final request = CreateSlateRequest(
        amount: 1500000000,
        minimumConfirmations: 15,
        selectionStrategyIsUseAll: true,
        note: 'Test note',
      );

      final json = request.toJson();
      expect(json['amount'], equals(1500000000));
      expect(json['minimum_confirmations'], equals(15));
      expect(json['selection_strategy_is_use_all'], isTrue);
      expect(json['note'], equals('Test note'));
    });

    test('ReceiveSlateRequest toJson', () {
      final request = ReceiveSlateRequest(
        slateJson: '{"slate": "data"}',
        message: 'Test message',
      );

      final json = request.toJson();
      expect(json['slate_json'], equals('{"slate": "data"}'));
      expect(json['message'], equals('Test message'));
    });

    test('EncodeSlatepackRequest toJson with recipient', () {
      final request = EncodeSlatepackRequest(
        slateJson: '{"slate": "data"}',
        recipientAddress: 'mwcmqs://test@address',
      );

      final json = request.toJson();
      expect(json['slate_json'], equals('{"slate": "data"}'));
      expect(json['recipient_address'], equals('mwcmqs://test@address'));
    });

    test('EncodeSlatepackRequest toJson without recipient', () {
      final request = EncodeSlatepackRequest(
        slateJson: '{"slate": "data"}',
        recipientAddress: null,
      );

      final json = request.toJson();
      expect(json['slate_json'], equals('{"slate": "data"}'));
      expect(json.containsKey('recipient_address'), isFalse);
    });
  });
}
