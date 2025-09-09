import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libmwc/flutter_libmwc.dart';
import 'package:flutter_libmwc/lib.dart';
import 'package:flutter_libmwc/models/slate.dart';

class SlatepackDemoView extends StatefulWidget {
  const SlatepackDemoView({super.key});

  @override
  State<SlatepackDemoView> createState() => _SlatepackDemoViewState();
}

class _SlatepackDemoViewState extends State<SlatepackDemoView> {
  final FlutterLibmwc _flutterLibmwc = FlutterLibmwc();
  final _slateController = TextEditingController();
  final _slatepackController = TextEditingController();
  final _recipientAddressController = TextEditingController();

  bool _isLoading = false;
  String? _lastResult;

  @override
  void dispose() {
    _slateController.dispose();
    _slatepackController.dispose();
    _recipientAddressController.dispose();
    super.dispose();
  }

  void _encodeSlatepack() async {
    if (_slateController.text.trim().isEmpty) {
      _showSnackBar('Please enter a slate JSON', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      print('=== Slatepack Encoding Debug Info ===');
      print('Slate JSON Input: ${_slateController.text.trim()}');
      print(
          'Recipient Address: ${_recipientAddressController.text.trim().isEmpty ? "None" : _recipientAddressController.text.trim()}');

      String slateJson = _slateController.text.trim();

      // Try to encode with original slate first.
      final request = EncodeSlatepackRequest(
        slateJson: slateJson,
        recipientAddress: _recipientAddressController.text.trim().isEmpty
            ? null
            : _recipientAddressController.text.trim(),
      );

      print('Calling encodeSlatepack...');
      var result = await _flutterLibmwc.encodeSlatepack(request);
      print('Encode result - Success: ${result.success}');
      print(
          'Encode result - Slatepack Length: ${result.slatepackString.length}');
      print(
          'Encode result - Slatepack Preview: ${result.slatepackString.length > 50 ? result.slatepackString.substring(0, 50) + '...' : result.slatepackString}');
      print('Encode result - Encrypted: ${result.encrypted}');
      print('Encode result - Error: ${result.error}');

      if (result.success) {
        setState(() {
          _slatepackController.text = result.slatepackString;
          _lastResult =
              'Slatepack encoded successfully! Encrypted: ${result.encrypted}';
        });
        _showSnackBar('Slatepack encoded successfully!', Colors.green);
      } else {
        print('=== Slatepack Encoding Failed ===');
        print('Error details: ${result.error}');
        setState(() {
          _lastResult = 'Encoding failed: ${result.error}';
        });
        _showSnackBar('Encoding failed: ${result.error}', Colors.red);
      }
    } catch (e, stackTrace) {
      print('=== Slatepack Encoding Exception ===');
      print('Exception: $e');
      print('Stack Trace: $stackTrace');
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _decodeSlatepack() async {
    if (_slatepackController.text.trim().isEmpty) {
      _showSnackBar('Please enter a slatepack string', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      print('=== Slatepack Decoding Debug Info ===');
      print('Slatepack Input: ${_slatepackController.text.trim()}');

      final request = DecodeSlatepackRequest(
        slatepackString: _slatepackController.text.trim(),
      );

      print('Calling decodeSlatepack...');
      final result = await _flutterLibmwc.decodeSlatepack(request);
      print('Decode result - Success: ${result.success}');
      print('Decode result - Slate JSON: ${result.slateJson}');
      print('Decode result - Error: ${result.error}');

      if (result.success) {
        setState(() {
          _slateController.text = result.slateJson;
          _lastResult = 'Slatepack decoded successfully!';
        });
        _showSnackBar('Slatepack decoded successfully!', Colors.green);
      } else {
        print('=== Slatepack Decoding Failed ===');
        print('Error details: ${result.error}');
        setState(() {
          _lastResult = 'Decoding failed: ${result.error}';
        });
        _showSnackBar('Decoding failed: ${result.error}', Colors.red);
      }
    } catch (e, stackTrace) {
      print('=== Slatepack Decoding Exception ===');
      print('Exception: $e');
      print('Stack Trace: $stackTrace');
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard', Colors.blue);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // Enhanced slatepack methods from MWC713 features
  void _encodeSlatepackUnencrypted() async {
    if (_slateController.text.isEmpty) {
      _showSnackBar('Please enter slate JSON', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Libmwc.encodeSlatepack(
        slateJson: _slateController.text,
        encrypt: false,
      );

      setState(() {
        _slatepackController.text = result.slatepack;
        _lastResult = 'Slatepack encoded (unencrypted)';
      });
      _showSnackBar('Slatepack encoded (unencrypted)', Colors.green);
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _encodeSlatepackEncrypted() async {
    if (_slateController.text.isEmpty) {
      _showSnackBar('Please enter slate JSON', Colors.red);
      return;
    }
    if (_recipientAddressController.text.isEmpty) {
      _showSnackBar(
          'Please enter recipient address for encryption', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Libmwc.encodeSlatepack(
        slateJson: _slateController.text,
        recipientAddress: _recipientAddressController.text,
        encrypt: true,
      );

      setState(() {
        _slatepackController.text = result.slatepack;
        _lastResult =
            'Slatepack encoded (encrypted for ${result.recipientAddress})';
      });
      _showSnackBar('Slatepack encoded (encrypted)', Colors.green);
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _decodeSlatepackAdvanced() async {
    if (_slatepackController.text.isEmpty) {
      _showSnackBar('Please enter slatepack', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Libmwc.decodeSlatepack(
        slatepack: _slatepackController.text,
      );

      setState(() {
        _slateController.text = result.slateJson;
        _lastResult = 'Slatepack decoded. Encrypted=${result.wasEncrypted}';
      });
      _showSnackBar('Slatepack decoded', Colors.green);
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _isSlatepackEncrypted() async {
    if (_slatepackController.text.isEmpty) {
      _showSnackBar('Please enter slatepack', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isEncrypted =
          await Libmwc.isSlatepackEncrypted(_slatepackController.text);
      setState(() {
        _lastResult =
            'Slatepack encryption status: ${isEncrypted ? 'Encrypted' : 'Unencrypted'}';
      });
      _showSnackBar('Encryption check complete', Colors.blue);
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _getSlatepackInfo() async {
    if (_slatepackController.text.isEmpty) {
      _showSnackBar('Please enter slatepack', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final info = await Libmwc.getSlatepackInfo(_slatepackController.text);
      setState(() {
        _lastResult =
            'Slatepack Info: ID=${info['slateId']}, Amount=${info['amount']}, Encrypted=${info['isEncrypted']}';
      });
      _showSnackBar('Slatepack info retrieved', Colors.blue);
    } catch (e) {
      setState(() {
        _lastResult = 'Error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _generateSampleSlate() {
    final sampleSlate = '''
{
  "version_info": {
    "orig_version": 3,
    "version": 3,
    "block_header_version": 2
  },
  "id": "0436430c-2b02-624c-2032-570501212b00",
  "sta": "S1",
  "num_participants": 2,
  "amount": "1000000000",
  "fee": "1000000",
  "height": "0",
  "lock_height": "0",
  "ttl_cutoff_height": null,
  "payment_proof": null,
  "participant_data": []
}''';

    setState(() {
      _slateController.text = sampleSlate;
    });
    _showSnackBar('Sample slate generated', Colors.blue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slatepack Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Slatepack Demo'),
                  content: const Text(
                    'This demo allows you to encode and decode MWC slatepacks.\n\n'
                    '1. Enter a slate JSON or use the sample\n'
                    '2. Optionally enter a recipient address for encryption\n'
                    '3. Encode to create a slatepack string\n'
                    '4. Decode to convert back to slate JSON',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.qr_code,
            size: 64,
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          const Text(
            'Slatepack Encoding & Decoding',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Demonstrate MWC Slatepack functionality',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Recipient Address (Optional).
          TextFormField(
            controller: _recipientAddressController,
            decoration: const InputDecoration(
              labelText: 'Recipient Address (Optional)',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
              helperText: 'For encrypted slatepacks',
            ),
          ),
          const SizedBox(height: 16),

          // Slate JSON Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.code, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Slate JSON',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _generateSampleSlate,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Sample'),
                      ),
                      if (_slateController.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _copyToClipboard(
                              _slateController.text, 'Slate JSON'),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _slateController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter slate JSON or use sample button',
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Enhanced Encoding Buttons.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enhanced Slatepack Encoding',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _encodeSlatepackUnencrypted,
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Encode (Unencrypted)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _encodeSlatepackEncrypted,
                          icon: const Icon(Icons.lock),
                          label: const Text('Encode (Encrypted)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _decodeSlatepackAdvanced,
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Decode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _isSlatepackEncrypted,
                          icon: const Icon(Icons.info),
                          label: const Text('Check Encryption'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getSlatepackInfo,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Get Slatepack Info'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Slatepack Section.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text(
                        'Slatepack String',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_slatepackController.text.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _copyToClipboard(
                              _slatepackController.text, 'Slatepack'),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _slatepackController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Encoded slatepack will appear here',
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Loading Indicator.
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Result Display.
          if (_lastResult != null)
            Card(
              color: _lastResult!.contains('Error') ||
                      _lastResult!.contains('failed')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _lastResult!.contains('Error') ||
                              _lastResult!.contains('failed')
                          ? Icons.error
                          : Icons.check_circle,
                      color: _lastResult!.contains('Error') ||
                              _lastResult!.contains('failed')
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_lastResult!)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Instructions Card.
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enhanced Slatepack Features:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Click "Sample" to generate a test slate JSON'),
                  Text('2. Enter recipient address for encrypted slatepacks'),
                  Text('3. Use "Encode (Unencrypted)" for plain slatepacks'),
                  Text('4. Use "Encode (Encrypted)" for secure transmission'),
                  Text('5. Use "Decode Enhanced" with improved error handling'),
                  Text('6. "Check Encryption" to verify slatepack security'),
                  Text('7. "Get Slatepack Info" for detailed metadata'),
                  Text('8. Use "Copy" buttons to share slatepacks easily'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
