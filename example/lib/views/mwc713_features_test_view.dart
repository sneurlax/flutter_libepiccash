import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libmwc/lib.dart';
import 'package:flutter_libmwc/models/mwcmqs_address.dart';
import 'package:flutter_libmwc/models/payment_proof.dart';
import '../services/wallet_service.dart';
import 'dart:io';

class MWC713FeaturesTestView extends StatefulWidget {
  const MWC713FeaturesTestView({super.key});

  @override
  State<MWC713FeaturesTestView> createState() => _MWC713FeaturesTestViewState();
}

class _MWC713FeaturesTestViewState extends State<MWC713FeaturesTestView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _lastResult;

  // Controllers for different feature tests
  final _mwcmqsAddressController = TextEditingController();
  final _recipientAddressController = TextEditingController();
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  final _filePathController = TextEditingController();
  final _transactionIdController = TextEditingController();

  MwcmqsAddress? _currentMwcmqsAddress;
  PaymentProof? _currentPaymentProof;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeDefaults();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mwcmqsAddressController.dispose();
    _recipientAddressController.dispose();
    _amountController.dispose();
    _messageController.dispose();
    _filePathController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  void _initializeDefaults() {
    _amountController.text = '1000000000'; // 1 MWC in nano.
    _messageController.text = 'Test transaction from flutter_libmwc';
    _filePathController.text = '/tmp/test_slate.json';
  }

  void _setLoading(bool loading) {
    // Console log for visibility during actions.
    try {
      print('[MWC713] setLoading -> ${loading ? 'START' : 'END'}');
    } catch (_) {}
    setState(() {
      _isLoading = loading;
    });
  }

  void _setResult(String result, [Color color = Colors.green]) {
    // Always log results to console as well as show a toast.
    try {
      final level = color == Colors.red
          ? 'ERROR'
          : (color == Colors.orange ? 'WARN' : 'INFO');
      print('[MWC713][$level] $result');
    } catch (_) {}
    setState(() {
      _lastResult = result;
    });
    _showSnackBar(result, color);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method to get wallet handle with proper error handling.
  Future<String?> _getWalletHandle() async {
    print('[MWC713] _getWalletHandle called');
    if (!await WalletService.hasOpenWallet()) {
      _setResult('Please open a wallet first', Colors.red);
      return null;
    }

    final walletHandle = WalletService.getCurrentWalletHandle();
    if (walletHandle == null) {
      _setResult('No wallet handle available', Colors.red);
      return null;
    }
    print('[MWC713] Wallet handle acquired (len=${walletHandle.length})');
    return walletHandle;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MWC713 Features Test'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'MWCMQS'),
            Tab(text: 'File Transactions'),
            Tab(text: 'Payment Proofs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMwcmqsTab(),
          _buildFileTransactionTab(),
          _buildPaymentProofTab(),
        ],
      ),
    );
  }

  Widget _buildMwcmqsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MWCMQS Integration Test',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // MWCMQS Address Generation.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate MWCMQS Address',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_currentMwcmqsAddress != null) ...[
                    Text('Current Address: ${_currentMwcmqsAddress!.address}'),
                    Text('Domain: ${_currentMwcmqsAddress!.domain}'),
                    Text('Port: ${_currentMwcmqsAddress!.port}'),
                    Text('Is Mainnet: ${_currentMwcmqsAddress!.isMainnet}'),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateMwcmqsAddress,
                    child: const Text('Generate MWCMQS Address'),
                  ),
                ],
              ),
            ),
          ),

          // MWCMQS Transaction Sending.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Send via MWCMQS',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _recipientAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient MWCMQS Address',
                      hintText: 'gTesT7...@mwcmqs.mwc.mw:443',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (nano MWC)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendViaMwcmqs,
                    child: const Text('Send via MWCMQS'),
                  ),
                ],
              ),
            ),
          ),

          // MWCMQS Listener Control.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MWCMQS Listener',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : _startMwcmqsListener,
                        child: const Text('Start Listener'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _stopMwcmqsListener,
                        child: const Text('Stop Listener'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _getMwcmqsListenerStatus,
                        child: const Text('Get Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTransactionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'File-Based Transactions Test',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Path Configuration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _filePathController,
                    decoration: const InputDecoration(
                      labelText: 'File Path',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Create Slate to File.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Slate to File',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createSlateToFile,
                    child: const Text('Create Slate to File'),
                  ),
                ],
              ),
            ),
          ),

          // Receive Slate from File.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receive Slate from File',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _receiveSlateFromFile,
                    child: const Text('Receive Slate from File'),
                  ),
                ],
              ),
            ),
          ),

          // File Utilities.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'File Utilities',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading ? null : _validateSlateFile,
                        child: const Text('Validate File'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _getSlateFileInfo,
                        child: const Text('Get File Info'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProofTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Proofs Test',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate Payment Proof',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _transactionIdController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction ID (UUID)',
                      hintText: '0436430c-2b02-624c-2032-570501212b00',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generatePaymentProof,
                    child: const Text('Generate Payment Proof'),
                  ),
                ],
              ),
            ),
          ),

          if (_currentPaymentProof != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Payment Proof',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Transaction ID: ${_currentPaymentProof!.transactionId}'),
                    Text('Amount: ${_currentPaymentProof!.amountInMwc} MWC'),
                    Text('Sender: ${_currentPaymentProof!.senderAddress}'),
                    Text('Receiver: ${_currentPaymentProof!.receiverAddress}'),
                    if (_currentPaymentProof!.message != null)
                      Text('Message: ${_currentPaymentProof!.message}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPaymentProof,
                          child: const Text('Verify Proof'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _exportPaymentProof,
                          child: const Text('Export to File'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Payment Proof',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _importPaymentProof,
                    child: const Text('Import Proof from File'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // MWCMQS Feature Tests.
  void _generateMwcmqsAddress() async {
    print('[MWC713] _generateMwcmqsAddress pressed');
    _setLoading(true);
    try {
      if (!await WalletService.hasOpenWallet()) {
        _setResult('Please open a wallet first', Colors.red);
        return;
      }

      final walletHandle = WalletService.getCurrentWalletHandle();
      if (walletHandle == null) {
        _setResult('No wallet handle available', Colors.red);
        return;
      }

      print('[MWC713] Generating MWCMQS address (index=0)');
      final address = await Libmwc.generateMwcmqsAddress(
        wallet: walletHandle,
        index: 0,
      );

      setState(() {
        _currentMwcmqsAddress = address;
        _mwcmqsAddressController.text = address.address;
      });

      _setResult('MWCMQS Address generated: ${address.address}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _sendViaMwcmqs() async {
    print('[MWC713] _sendViaMwcmqs pressed');
    if (_recipientAddressController.text.isEmpty) {
      _setResult('Please enter recipient address', Colors.red);
      return;
    }

    _setLoading(true);
    try {
      if (!await WalletService.hasOpenWallet()) {
        _setResult('Please open a wallet first', Colors.red);
        return;
      }

      final walletHandle = WalletService.getCurrentWalletHandle();
      if (walletHandle == null) {
        _setResult('No wallet handle available', Colors.red);
        return;
      }

      print('[MWC713] Sending via MWCMQS -> to=${_recipientAddressController.text}, amount=${_amountController.text}');
      final result = await Libmwc.sendViaMwcmqs(
        wallet: walletHandle,
        mwcmqsAddress: _recipientAddressController.text,
        amount: int.parse(_amountController.text),
        message: _messageController.text,
        mwcmqsConfig: const MwcmqsConfig().toConfigString(),
      );

      _setResult('Transaction sent via MWCMQS: ${result.slateId}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _startMwcmqsListener() async {
    print('[MWC713] _startMwcmqsListener pressed');
    _setLoading(true);
    try {
      if (!await WalletService.hasOpenWallet()) {
        _setResult('Please open a wallet first', Colors.red);
        return;
      }

      final walletHandle = WalletService.getCurrentWalletHandle();
      if (walletHandle == null) {
        _setResult('No wallet handle available', Colors.red);
        return;
      }

      print('[MWC713] Starting MWCMQS listener');
      await Libmwc.startMwcmqsListener(
        wallet: walletHandle,
        config: const MwcmqsConfig(autoStart: true),
      );

      _setResult('MWCMQS Listener started');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _stopMwcmqsListener() async {
    print('[MWC713] _stopMwcmqsListener pressed');
    _setLoading(true);
    try {
      print('[MWC713] Stopping MWCMQS listener');
      await Libmwc.stopMwcmqsListener();
      _setResult('MWCMQS Listener stopped');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _getMwcmqsListenerStatus() async {
    print('[MWC713] _getMwcmqsListenerStatus pressed');
    _setLoading(true);
    try {
      print('[MWC713] Querying MWCMQS listener status');
      final status = await Libmwc.getMwcmqsListenerStatus();
      _setResult('Listener Status: Running=${status.isRunning}, Messages=${status.messagesReceived}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  // File Transaction Tests.
  void _createSlateToFile() async {
    print('[MWC713] _createSlateToFile pressed');
    _setLoading(true);
    try {
      final walletHandle = await _getWalletHandle();
      if (walletHandle == null) {
        _setLoading(false);
        return;
      }

      print('[MWC713] Creating slate to file ${_filePathController.text} amount=${_amountController.text}');
      final result = await Libmwc.createSlateToFile(
        wallet: walletHandle,
        filePath: _filePathController.text,
        amount: int.parse(_amountController.text),
        message: _messageController.text,
      );

      _setResult('Slate created to file: ${result.slateId}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _receiveSlateFromFile() async {
    print('[MWC713] _receiveSlateFromFile pressed');
    _setLoading(true);
    try {
      final walletHandle = await _getWalletHandle();
      if (walletHandle == null) {
        _setLoading(false);
        return;
      }

      print('[MWC713] Receiving slate from file ${_filePathController.text}');
      final result = await Libmwc.receiveSlateFromFile(
        wallet: walletHandle,
        inputPath: _filePathController.text,
        outputPath: _filePathController.text.replaceAll('.json', '_received.json'),
        message: _messageController.text,
      );

      _setResult('Slate received from file: ${result.slateId}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _validateSlateFile() async {
    print('[MWC713] _validateSlateFile pressed');
    _setLoading(true);
    try {
      print('[MWC713] Validating file ${_filePathController.text}');
      final isValid = await Libmwc.validateSlateFile(_filePathController.text);
      _setResult('File validation: ${isValid ? 'Valid' : 'Invalid'}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _getSlateFileInfo() async {
    print('[MWC713] _getSlateFileInfo pressed');
    _setLoading(true);
    try {
      print('[MWC713] Getting file info for ${_filePathController.text}');
      final info = await Libmwc.getSlateFileInfo(_filePathController.text);
      _setResult('File Info: Type=${info['fileType']}, Size=${info['size']}, Valid=${info['isValid']}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  // Payment Proof Tests.
  void _generatePaymentProof() async {
    print('[MWC713] _generatePaymentProof pressed');
    if (_transactionIdController.text.isEmpty) {
      _setResult('Please enter transaction ID', Colors.red);
      return;
    }

    _setLoading(true);
    try {
      if (!WalletService.isWalletOpen) {
        _setResult('Please open a wallet first', Colors.red);
        return;
      }

      print('[MWC713] Generating payment proof for txId=${_transactionIdController.text}');
      final proof = await Libmwc.generatePaymentProof(
        wallet: WalletService.getWalletString(),
        transactionId: _transactionIdController.text,
        message: _messageController.text,
      );

      setState(() {
        _currentPaymentProof = proof;
      });

      _setResult('Payment proof generated for: ${proof.transactionId}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _verifyPaymentProof() async {
    print('[MWC713] _verifyPaymentProof pressed');
    if (_currentPaymentProof == null) {
      _setResult('No payment proof to verify', Colors.red);
      return;
    }

    _setLoading(true);
    try {
      if (!WalletService.isWalletOpen) {
        _setResult('Please open a wallet first', Colors.red);
        return;
      }

      print('[MWC713] Verifying payment proof txId=${_currentPaymentProof!.transactionId}');
      final verification = await Libmwc.verifyPaymentProof(
        wallet: WalletService.getWalletString(),
        proof: _currentPaymentProof!,
      );

      _setResult('Proof Verification: Valid=${verification.isValid}, Kernel Found=${verification.kernelFound}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _exportPaymentProof() async {
    print('[MWC713] _exportPaymentProof pressed');
    if (_currentPaymentProof == null) {
      _setResult('No payment proof to export', Colors.red);
      return;
    }

    _setLoading(true);
    try {
      print('[MWC713] Exporting payment proof to /tmp/payment_proof.json');
      await Libmwc.exportPaymentProof(
        proof: _currentPaymentProof!,
        filePath: '/tmp/payment_proof.json',
      );

      _setResult('Payment proof exported to /tmp/payment_proof.json');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

  void _importPaymentProof() async {
    print('[MWC713] _importPaymentProof pressed');
    _setLoading(true);
    try {
      print('[MWC713] Importing payment proof from /tmp/payment_proof.json');
      final proof = await Libmwc.importPaymentProof(
        filePath: '/tmp/payment_proof.json',
      );

      setState(() {
        _currentPaymentProof = proof;
        _transactionIdController.text = proof.transactionId;
      });

      _setResult('Payment proof imported: ${proof.transactionId}');
    } catch (e) {
      _setResult('Error: $e', Colors.red);
    }
    _setLoading(false);
  }

}
