import 'package:flutter/material.dart';

import '../services/wallet_service.dart';

class OpenWalletView extends StatefulWidget {
  const OpenWalletView({super.key});

  @override
  State<OpenWalletView> createState() => _OpenWalletViewState();
}

class _OpenWalletViewState extends State<OpenWalletView> {
  final _formKey = GlobalKey<FormState>();
  final _walletNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isLoading = false;
  List<String> _availableWallets = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableWallets();
  }

  @override
  void dispose() {
    _walletNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableWallets() async {
    final wallets = await WalletService.getAvailableWallets();
    setState(() {
      _availableWallets = wallets;
    });
  }

  void _openWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.openWallet(
        walletName: _walletNameController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Wallet "${result.walletName}" opened successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to open wallet'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open wallet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Wallet'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _availableWallets.isEmpty
                ? TextFormField(
                    controller: _walletNameController,
                    decoration: const InputDecoration(
                      labelText: 'Wallet Name',
                      prefixIcon: Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(),
                      helperText: 'Enter the name of your wallet',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a wallet name';
                      }
                      return null;
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _walletNameController.text.isEmpty
                            ? null
                            : _walletNameController.text,
                        decoration: const InputDecoration(
                          labelText: 'Select Wallet',
                          prefixIcon: Icon(Icons.account_balance_wallet),
                          border: OutlineInputBorder(),
                          helperText: 'Choose from available wallets',
                        ),
                        items: _availableWallets.map((wallet) {
                          return DropdownMenuItem<String>(
                            value: wallet,
                            child: Text(wallet),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _walletNameController.text = value ?? '';
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a wallet';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _isPasswordHidden,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordHidden
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isPasswordHidden = !_isPasswordHidden;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _openWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Open Wallet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
