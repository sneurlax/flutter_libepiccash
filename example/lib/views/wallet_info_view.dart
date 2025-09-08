import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libmwc/mwc.dart' as mwc;

import '../services/wallet_service.dart';

class WalletInfoView extends StatefulWidget {
  const WalletInfoView({super.key});

  @override
  State<WalletInfoView> createState() => _WalletInfoViewState();
}

class _WalletInfoViewState extends State<WalletInfoView> {
  String? _mnemonic;
  String? _currentWallet;
  Map<String, dynamic>? _walletInfo;
  String? _walletAddress;
  List<Map<String, dynamic>>? _transactions;
  int? _chainHeight;
  bool _isLoading = false;
  bool _showMnemonic = false;
  bool _isScanning = false;
  String _loadingStatus = '';

  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  void _loadWalletInfo() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Initializing...';
    });

    try {
      print('=== Loading Wallet Info Debug ===');
      
      // Step 1: Get current wallet.
      setState(() {
        _loadingStatus = 'Getting wallet information...';
      });
      await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to update.
      
      print('Getting current wallet...');
      final currentWallet = await WalletService.getCurrentWallet();
      print('Current wallet: $currentWallet');

      if (currentWallet != null) {
        setState(() {
          _currentWallet = currentWallet;
        });

        // First, ensure the wallet is opened.
        // Note: We would need the password here, but for now we'll try without opening.
        // TODO: Consider adding password prompt or storing session state.

        // Step 2: Load wallet info.
        setState(() {
          _loadingStatus = 'Synchronizing with blockchain...';
        });
        await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to update.
        
        Map<String, dynamic>? walletInfo;
        try {
          print('Getting wallet info...');
          walletInfo = await WalletService.getWalletInfo(currentWallet);
          print('Wallet info retrieved successfully');

          // Check if wallet needs to be opened.
          if (walletInfo != null && walletInfo['error'] != null) {
            if (walletInfo['error'].toString().contains('not opened')) {
              setState(() {
                _walletInfo = {
                  'needs_password': true,
                  'wallet_name': currentWallet
                };
              });
              return; // Exit early, don't try other operations.
            }
          }
        } catch (e) {
          print('Wallet info failed: $e');
          walletInfo = null;
        }

        // Step 3: Load additional wallet data.
        setState(() {
          _loadingStatus = 'Loading wallet address...';
        });
        await Future.delayed(const Duration(milliseconds: 50)); // Allow UI to update.

        String? walletAddress;
        try {
          print('Getting wallet address...');
          walletAddress = await WalletService.getWalletAddress(currentWallet);
          print('Wallet address retrieved successfully');
        } catch (e) {
          print('Wallet address failed: $e');
          walletAddress = null;
        }

        setState(() {
          _loadingStatus = 'Loading transactions...';
        });
        await Future.delayed(const Duration(milliseconds: 50)); // Allow UI to update.

        List<Map<String, dynamic>>? transactions;
        try {
          print('Getting wallet transactions...');
          transactions =
              await WalletService.getWalletTransactions(currentWallet);
          print('Wallet transactions retrieved successfully');
        } catch (e) {
          print('Wallet transactions failed: $e');
          transactions = null;
        }

        setState(() {
          _loadingStatus = 'Getting network status...';
        });
        await Future.delayed(const Duration(milliseconds: 50)); // Allow UI to update.

        int? chainHeight;
        try {
          print('Getting chain height...');
          chainHeight = await WalletService.getChainHeight(currentWallet);
          print('Chain height retrieved successfully');
        } catch (e) {
          print('Chain height failed: $e');
          chainHeight = null;
        }

        setState(() {
          _loadingStatus = 'Finalizing...';
        });
        await Future.delayed(const Duration(milliseconds: 50)); // Allow UI to update

        setState(() {
          _walletInfo = walletInfo;
          _walletAddress = walletAddress;
          _transactions = transactions;
          _chainHeight = chainHeight;
        });
      }

      // Get mnemonic from the library.
      final mnemonic = mwc.walletMnemonic();
      setState(() {
        _mnemonic = mnemonic;
      });
    } catch (e, stackTrace) {
      print('=== Wallet Info View Error ===');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      _showSnackBar('Error loading wallet info: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
        _loadingStatus = '';
      });
    }
  }

  void _scanWalletOutputs() async {
    if (_currentWallet == null) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final success = await WalletService.scanWalletOutputs(_currentWallet!);
      if (success) {
        _showSnackBar('Wallet scan completed', Colors.green);
        _loadWalletInfo(); // Refresh wallet info.
      } else {
        _showSnackBar('Wallet scan failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error scanning wallet: $e', Colors.red);
    } finally {
      setState(() {
        _isScanning = false;
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

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
    bool copyable = false,
    bool sensitive = false,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor ?? Theme.of(context).primaryColor,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: sensitive && !_showMnemonic
            ? const Text('Tap to reveal')
            : Text(
                value,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
        trailing: copyable
            ? IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(value, title),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Information'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _loadingStatus.isEmpty ? 'Loading...' : _loadingStatus,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_loadingStatus.contains('Synchronizing'))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'This may take 10-15 seconds',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Check if wallet needs to be opened.
                if (_walletInfo?['needs_password'] == true)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.lock,
                              color: Colors.orange, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Wallet Not Opened',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This wallet needs to be opened with a password before accessing information.',
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
                    ),
                  ),

                // Status Information.
                if (_walletInfo?['needs_password'] != true) ...[
                  _buildInfoCard(
                    title: 'Current Wallet',
                    value: _currentWallet ?? 'No wallet selected',
                    icon: Icons.account_balance_wallet,
                    iconColor:
                        _currentWallet != null ? Colors.green : Colors.orange,
                  ),

                  _buildInfoCard(
                    title: 'Network',
                    value: 'MWC Mainnet',
                    icon: Icons.network_check,
                    iconColor: Colors.blue,
                  ),

                  if (_walletAddress != null)
                    _buildInfoCard(
                      title: 'Wallet Address',
                      value: _walletAddress!,
                      icon: Icons.location_on,
                      iconColor: Colors.purple,
                      copyable: true,
                    ),

                  _buildInfoCard(
                    title: 'Balance',
                    value: _walletInfo != null
                        ? '${(_walletInfo!['amount_currently_spendable'] ?? 0) / 1000000000} MWC'
                        : '0.00000000 MWC',
                    icon: Icons.account_balance_wallet,
                    iconColor: Colors.green,
                  ),

                  if (_walletInfo != null) ...[
                    _buildInfoCard(
                      title: 'Total Balance',
                      value: '${(_walletInfo!['total'] ?? 0) / 1000000000} MWC',
                      icon: Icons.savings,
                      iconColor: Colors.teal,
                    ),
                    _buildInfoCard(
                      title: 'Awaiting Confirmation',
                      value:
                          '${(_walletInfo!['amount_awaiting_confirmation'] ?? 0) / 1000000000} MWC',
                      icon: Icons.hourglass_empty,
                      iconColor: Colors.orange,
                    ),
                    _buildInfoCard(
                      title: 'Locked Amount',
                      value:
                          '${(_walletInfo!['amount_locked'] ?? 0) / 1000000000} MWC',
                      icon: Icons.lock,
                      iconColor: Colors.red,
                    ),
                  ],

                  if (_transactions != null)
                    _buildInfoCard(
                      title: 'Transaction Count',
                      value: '${_transactions!.length} transactions',
                      icon: Icons.receipt,
                      iconColor: Colors.indigo,
                    ),

                  _buildInfoCard(
                    title: 'Chain Height',
                    value: _chainHeight != null
                        ? '$_chainHeight blocks'
                        : 'Network unavailable',
                    icon: Icons.link,
                    iconColor:
                        _chainHeight != null ? Colors.cyan : Colors.orange,
                  ),

                  // Recovery Phrase Card.
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.key, color: Colors.red.shade400),
                              const SizedBox(width: 8),
                              const Text(
                                'Recovery Phrase',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (_showMnemonic && _mnemonic != null)
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(
                                      _mnemonic!, 'Recovery phrase'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!_showMnemonic)
                            Column(
                              children: [
                                const Text(
                                  'Your recovery phrase is hidden for security.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showMnemonic = true;
                                      });
                                    },
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('Reveal Recovery Phrase'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (_mnemonic != null)
                            Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: SelectableText(
                                    _mnemonic!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showMnemonic = false;
                                      });
                                    },
                                    icon: const Icon(Icons.visibility_off),
                                    label: const Text('Hide Recovery Phrase'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'Error loading recovery phrase',
                              style: TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons.
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _loadWalletInfo,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_isScanning || _currentWallet == null)
                              ? null
                              : _scanWalletOutputs,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Scan Wallet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ], // Close the conditional block
              ],
            ),
    );
  }
}
