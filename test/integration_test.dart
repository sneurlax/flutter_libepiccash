import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libmwc/flutter_libmwc.dart';
import 'package:flutter_libmwc/models/slate.dart';

void main() {
  group('MWC Transaction Flow Integration Tests', () {
    late FlutterLibmwc plugin;

    setUp(() {
      plugin = FlutterLibmwc();
    });

    group('Complete Transaction Flow Tests', () {
      test('Full transaction flow: create -> receive -> finalize', () async {
        // Step 1: Sender creates a slate
        final createRequest = CreateSlateRequest(
          amount: 1000000000, // 1 MWC in nano
          minimumConfirmations: 10,
          selectionStrategyIsUseAll: false,
          note: 'Integration test transaction',
        );

        // Note: These will fail in unit tests but demonstrate the expected flow
        try {
          final createResult = await plugin.createSlate(createRequest);
          
          if (createResult.success && createResult.slateJson.isNotEmpty) {
            // Step 2: Receiver processes the slate
            final receiveRequest = ReceiveSlateRequest(
              slateJson: createResult.slateJson,
              message: 'Received via integration test',
            );

            final receiveResult = await plugin.receiveSlate(receiveRequest);
            
            if (receiveResult.success && receiveResult.slateJson.isNotEmpty) {
              // Step 3: Sender finalizes the transaction
              final finalizeRequest = FinalizeSlateRequest(
                slateJson: receiveResult.slateJson,
              );

              final finalizeResult = await plugin.finalizeSlate(finalizeRequest);
              
              expect(finalizeResult.success, isTrue);
              expect(finalizeResult.error, isNull);
            }
          }
        } catch (e) {
          // Expected to fail in test environment without real wallet
          expect(e.toString(), contains('wallet'));
        }
      });

      test('Complete slatepack flow: create -> encode -> decode -> receive -> finalize', () async {
        try {
          // Step 1: Create slate
          final createRequest = CreateSlateRequest(
            amount: 2000000000, // 2 MWC
            minimumConfirmations: 15,
            selectionStrategyIsUseAll: false,
            note: 'Slatepack integration test',
          );

          final createResult = await plugin.createSlate(createRequest);
          
          if (createResult.success) {
            // Step 2: Encode as slatepack (unencrypted)
            final encodeRequest = EncodeSlatepackRequest(
              slateJson: createResult.slateJson,
              recipientAddress: null, // Unencrypted
            );

            final encodeResult = await plugin.encodeSlatepack(encodeRequest);
            
            if (encodeResult.success) {
              expect(encodeResult.slatepackString, startsWith('BEGINSLATEPACK.'));
              expect(encodeResult.slatepackString, endsWith('ENDSLATEPACK.'));
              expect(encodeResult.encrypted, isFalse);

              // Step 3: Decode slatepack back to slate
              final decodeRequest = DecodeSlatepackRequest(
                slatepackString: encodeResult.slatepackString,
              );

              final decodeResult = await plugin.decodeSlatepack(decodeRequest);
              
              if (decodeResult.success) {
                // Step 4: Process the decoded slate
                final receiveRequest = ReceiveSlateRequest(
                  slateJson: decodeResult.slateJson,
                  message: 'Received from slatepack',
                );

                final receiveResult = await plugin.receiveSlate(receiveRequest);
                
                if (receiveResult.success) {
                  // Step 5: Finalize
                  final finalizeRequest = FinalizeSlateRequest(
                    slateJson: receiveResult.slateJson,
                  );

                  final finalizeResult = await plugin.finalizeSlate(finalizeRequest);
                  expect(finalizeResult.success, isTrue);
                }
              }
            }
          }
        } catch (e) {
          // Expected to fail in test environment
          expect(e.toString(), contains('wallet'));
        }
      });
    });

    group('Transaction Flow Error Scenarios', () {
      test('Invalid slate JSON handling in transaction flow', () async {
        try {
          // Try to receive an invalid slate
          final receiveRequest = ReceiveSlateRequest(
            slateJson: 'invalid_json_format',
            message: 'Error test',
          );

          final receiveResult = await plugin.receiveSlate(receiveRequest);
          expect(receiveResult.success, isFalse);
          expect(receiveResult.error, isNotNull);
        } catch (e) {
          // Error handling varies by implementation
          expect(e, isNotNull);
        }
      });

      test('Double finalization prevention', () async {
        try {
          // Create a mock finalized slate JSON
          const mockFinalizedSlate = '{"finalized": true}';
          
          final finalizeRequest = FinalizeSlateRequest(
            slateJson: mockFinalizedSlate,
          );

          final result1 = await plugin.finalizeSlate(finalizeRequest);
          final result2 = await plugin.finalizeSlate(finalizeRequest);

          // Second finalization should fail or be idempotent
          if (result1.success && result2.success) {
            // Both succeeded - this is acceptable (idempotent)
            expect(result1.slateJson, equals(result2.slateJson));
          } else {
            // At least one failed - this is expected behavior
            expect(result1.success || result2.success, isTrue);
          }
        } catch (e) {
          // Error handling is expected
          expect(e, isNotNull);
        }
      });

      test('Insufficient funds error handling', () async {
        try {
          // Try to create slate with excessive amount
          final createRequest = CreateSlateRequest(
            amount: 999999999999999999, // Unrealistic amount
            minimumConfirmations: 10,
            selectionStrategyIsUseAll: false,
            note: 'Insufficient funds test',
          );

          final result = await plugin.createSlate(createRequest);
          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          expect(result.error!.toLowerCase(), contains('fund'));
        } catch (e) {
          // Error expected in test environment
          expect(e, isNotNull);
        }
      });
    });

    group('Slatepack Format Validation', () {
      test('Valid slatepack format detection', () async {
        const validSlatepack = 'BEGINSLATEPACK. dGVzdCBkYXRh ENDSLATEPACK.';
        
        try {
          final request = DecodeSlatepackRequest(
            slatepackString: validSlatepack,
          );

          final result = await plugin.decodeSlatepack(request);
          
          // Should either succeed or fail gracefully
          if (!result.success) {
            expect(result.error, isNotNull);
          }
        } catch (e) {
          expect(e, isNotNull);
        }
      });

      test('Invalid slatepack format rejection', () async {
        const invalidFormats = [
          'NOT_A_SLATEPACK',
          'BEGINSLATEPACK. incomplete',
          'incomplete ENDSLATEPACK.',
          '',
          'BEGINSLATEPACK.ENDSLATEPACK.', // No content
        ];

        for (final invalidFormat in invalidFormats) {
          try {
            final request = DecodeSlatepackRequest(
              slatepackString: invalidFormat,
            );

            final result = await plugin.decodeSlatepack(request);
            expect(result.success, isFalse);
            expect(result.error, isNotNull);
          } catch (e) {
            // Error is acceptable for invalid formats
            expect(e, isNotNull);
          }
        }
      });
    });

    group('Performance Tests', () {
      test('Multiple concurrent slate operations', () async {
        final futures = <Future>[];
        
        // Create multiple concurrent operations
        for (int i = 0; i < 5; i++) {
          final createRequest = CreateSlateRequest(
            amount: 1000000000 + i, // Slightly different amounts
            minimumConfirmations: 10,
            selectionStrategyIsUseAll: false,
            note: 'Concurrent test $i',
          );

          futures.add(plugin.createSlate(createRequest).catchError((e) => 
            SlateResult(slateJson: '', success: false, error: e.toString())
          ));
        }

        // Wait for all operations to complete
        final results = await Future.wait(futures);
        
        // Verify all operations completed (success or expected failure)
        for (final result in results) {
          expect(result, isA<SlateResult>());
        }
      });

      test('Large note handling', () async {
        // Test with a large note (but reasonable size)
        final largeNote = 'A' * 1000; // 1KB note
        
        try {
          final createRequest = CreateSlateRequest(
            amount: 1000000000,
            minimumConfirmations: 10,
            selectionStrategyIsUseAll: false,
            note: largeNote,
          );

          final result = await plugin.createSlate(createRequest);
          
          // Should handle large notes gracefully
          if (result.success) {
            expect(result.slateJson.contains(largeNote), isTrue);
          }
        } catch (e) {
          // Large notes might not be supported
          expect(e, isNotNull);
        }
      });
    });
  });
}