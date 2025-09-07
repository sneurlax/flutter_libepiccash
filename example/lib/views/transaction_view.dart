import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/wallet_service.dart';

class TransactionView extends StatelessWidget {
  TransactionView({Key? key, required this.password}) : super(key: key);

  final String password;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet Transactions',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MwcTransactionView(
        title: 'Transactions',
        password: password,
      ),
    );
  }
}

class MwcTransactionView extends StatefulWidget {
  final String password;

  const MwcTransactionView(
      {Key? key, required this.title, required this.password})
      : super(key: key);

  final String title;

  @override
  State<MwcTransactionView> createState() => _MwcTransactionView();
}

class _MwcTransactionView extends State<MwcTransactionView> {
  String? _currentWallet;
  Map<String, dynamic>? _walletInfo;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  Future<void> _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('=== Loading Wallet Balance Info ===');
      
      // Get current wallet.
      final currentWallet = await WalletService.getCurrentWallet();
      print('Current wallet: $currentWallet');
      
      if (currentWallet != null) {
        setState(() {
          _currentWallet = currentWallet;
        });

        // Try to get wallet information, but handle the case where wallet needs to be opened.
        try {
          final walletInfo = await WalletService.getWalletInfo(currentWallet);
          print('Wallet info retrieved: $walletInfo');

          // Check if wallet needs to be opened.
          if (walletInfo != null && walletInfo['error'] != null) {
            if (walletInfo['error'].toString().contains('not opened')) {
              setState(() {
                _errorMessage = 'Wallet needs to be opened with password first';
                _walletInfo = {'needs_password': true, 'wallet_name': currentWallet};
              });
              return;
            } else {
              setState(() {
                _errorMessage = walletInfo['error'].toString();
              });
              return;
            }
          }

          setState(() {
            _walletInfo = walletInfo;
          });
        } catch (e) {
          print('Error getting wallet info: $e');
          setState(() {
            _errorMessage = 'Wallet needs to be opened with password first';
            _walletInfo = {'needs_password': true, 'wallet_name': currentWallet};
          });
        }
      } else {
        setState(() {
          _errorMessage = 'No wallet found';
        });
      }
    } catch (e) {
      print('Error loading wallet info: $e');
      setState(() {
        _errorMessage = 'Error loading wallet info: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.000000000';
    try {
      // Convert from nanograms to MWC (divide by 1,000,000,000).
      final mwcAmount = (amount as num) / 1000000000;
      return mwcAmount.toStringAsFixed(9);
    } catch (e) {
      return '0.000000000';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadWalletInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _walletInfo?['needs_password'] == true
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, color: Colors.orange, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Wallet Not Opened',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This wallet needs to be opened with a password before accessing balance information.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/open-wallet');
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Open Wallet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadWalletInfo,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_currentWallet != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_wallet),
                            title: const Text('Current Wallet'),
                            subtitle: Text(_currentWallet!),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Wallet Balance Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBalanceCard(
                        'Total Amount',
                        _formatAmount(_walletInfo?['total']),
                        Icons.account_balance,
                        Colors.green,
                      ),
                      _buildBalanceCard(
                        'Amount Awaiting Finalization',
                        _formatAmount(_walletInfo?['amount_awaiting_finalization']),
                        Icons.schedule,
                        Colors.orange,
                      ),
                      _buildBalanceCard(
                        'Amount Awaiting Confirmation',
                        _formatAmount(_walletInfo?['amount_awaiting_confirmation']),
                        Icons.hourglass_empty,
                        Colors.amber,
                      ),
                      _buildBalanceCard(
                        'Amount Currently Spendable',
                        _formatAmount(_walletInfo?['amount_currently_spendable']),
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),
                      _buildBalanceCard(
                        'Amount Locked',
                        _formatAmount(_walletInfo?['amount_locked']),
                        Icons.lock,
                        Colors.red,
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBalanceCard(String title, String amount, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amount MWC',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
