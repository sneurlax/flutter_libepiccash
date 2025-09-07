import 'package:flutter/material.dart';

import '../services/wallet_service.dart';

class RestoreWalletView extends StatefulWidget {
  const RestoreWalletView({super.key});

  @override
  State<RestoreWalletView> createState() => _RestoreWalletViewState();
}

class _RestoreWalletViewState extends State<RestoreWalletView> {
  final _formKey = GlobalKey<FormState>();
  final _walletNameController = TextEditingController();
  final _mnemonicController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _walletNameController.dispose();
    _mnemonicController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _restoreWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await WalletService.restoreWallet(
        walletName: _walletNameController.text.trim(),
        password: _passwordController.text,
        mnemonic: _mnemonicController.text.trim(),
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Wallet "${result.walletName}" restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to restore wallet'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore wallet: $e'),
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

  String? _validateMnemonic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your recovery phrase';
    }

    if (!WalletService.validateMnemonic(value.trim())) {
      return 'Recovery phrase must be 12-24 words';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Wallet'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _walletNameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                prefixIcon: Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(),
                helperText: 'Choose a name for the restored wallet',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a wallet name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mnemonicController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Recovery Phrase',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
                helperText: 'Enter your 12 or 24 word recovery phrase',
                alignLabelWithHint: true,
              ),
              validator: _validateMnemonic,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _isPasswordHidden,
              decoration: InputDecoration(
                labelText: 'New Password',
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
                helperText: 'Choose a strong password for your wallet',
              ),
              validator: (value) {
                // if (value == null || value.isEmpty) {
                //   return 'Please enter a password';
                // }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _isConfirmPasswordHidden,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordHidden
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                // if (value == null || value.isEmpty) {
                //   return 'Please confirm your password';
                // }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _restoreWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Restore Wallet',
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
