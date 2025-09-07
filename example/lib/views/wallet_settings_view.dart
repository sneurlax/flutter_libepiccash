import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/wallet_service.dart';

class WalletSettingsView extends StatefulWidget {
  const WalletSettingsView({super.key});

  @override
  State<WalletSettingsView> createState() => _WalletSettingsViewState();
}

class _WalletSettingsViewState extends State<WalletSettingsView> {
  String? _currentWallet;
  List<String> _availableWallets = [];
  bool _isLoading = false;

  // Node configuration
  final _nodeAddressController = TextEditingController();
  final _apiPortController = TextEditingController();
  String _selectedNetwork = 'mainnet';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nodeAddressController.dispose();
    _apiPortController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentWallet = await WalletService.getCurrentWallet();
      final wallets = await WalletService.getAvailableWallets();

      setState(() {
        _currentWallet = currentWallet;
        _availableWallets = wallets;
        // Set default node configuration from centralized constants
        _nodeAddressController.text = WalletService.defaultNodeUrl;
        _apiPortController.text = WalletService.defaultNodePort.toString();
      });
    } catch (e) {
      _showSnackBar('Error loading settings: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _deleteWallet(String walletName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wallet'),
        content: Text(
            'Are you sure you want to delete wallet "$walletName"?\n\nThis action cannot be undone and you will lose access to your funds unless you have your recovery phrase saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await WalletService.deleteWallet(walletName);
        if (success) {
          _showSnackBar('Wallet deleted successfully', Colors.green);
          _loadSettings(); // Refresh the list
        } else {
          _showSnackBar('Failed to delete wallet', Colors.red);
        }
      } catch (e) {
        _showSnackBar('Error deleting wallet: $e', Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    VoidCallback? onTap,
    Widget? trailing,
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
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWalletList() {
    if (_availableWallets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No wallets found. Create a wallet to get started.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: _availableWallets.map((wallet) {
        final isCurrent = wallet == _currentWallet;
        return Card(
          color: isCurrent ? Colors.green.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrent ? Colors.green : Colors.blue,
              child: Icon(
                isCurrent ? Icons.check_circle : Icons.account_balance_wallet,
                color: Colors.white,
              ),
            ),
            title: Text(
              wallet,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(isCurrent ? 'Current wallet' : 'Available wallet'),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'delete') {
                  _deleteWallet(wallet);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'delete',
                  enabled: !isCurrent, // Don't allow deleting current wallet
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      const Text('Delete Wallet'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Settings'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current Wallet Section.
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Current Wallet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentWallet ?? 'No wallet selected',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Active wallet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Network Settings.
                Row(
                  children: [
                    Icon(Icons.network_check, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Network Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Configuration',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedNetwork,
                          decoration: const InputDecoration(
                            labelText: 'Network',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.public),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'mainnet',
                                child: Text('MWC Mainnet (Default)')),
                            DropdownMenuItem(
                                value: 'testnet', child: Text('MWC Testnet')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedNetwork = value!;
                              if (value == 'mainnet') {
                                _nodeAddressController.text =
                                    WalletService.defaultNodeUrl;
                              } else {
                                _nodeAddressController.text = WalletService
                                    .defaultNodeUrl; // Use same for both mainnet and testnet
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nodeAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Node Address',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                            helperText: 'MWC node HTTP API address',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _apiPortController,
                          decoration: const InputDecoration(
                            labelText: 'API Port',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.router),
                            helperText: 'Node API port',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showSnackBar('Network settings saved (demo)',
                                  Colors.green);
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Save Network Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Wallet Management.
                Row(
                  children: [
                    Icon(Icons.folder, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Wallet Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _buildWalletList(),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}
