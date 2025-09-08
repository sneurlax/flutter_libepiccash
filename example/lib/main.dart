import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libmwc/flutter_libmwc.dart';

import 'services/wallet_service.dart';
import 'views/create_wallet_view.dart';
import 'views/open_wallet_view.dart';
import 'views/restore_wallet_view.dart';
import 'views/slatepack_demo_view.dart';
import 'views/wallet_info_view.dart';
import 'views/wallet_settings_view.dart';
import 'views/mwc713_features_test_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize wallet service logging
  await WalletService.initializeLogs();

  runApp(const MWCWalletApp());
}

class MWCWalletApp extends StatelessWidget {
  const MWCWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_libmwc example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: const CardTheme(
          elevation: 4,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      home: const WalletHomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WalletHomeView extends StatefulWidget {
  const WalletHomeView({super.key});

  @override
  State<WalletHomeView> createState() => _WalletHomeViewState();
}

class _WalletHomeViewState extends State<WalletHomeView> {
  String? _platformVersion = 'Unknown';
  final FlutterLibmwc _flutterLibmwc = FlutterLibmwc();
  bool _isWalletOpen = false;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
    _checkWalletStatus();
  }

  @override
  void didUpdateWidget(WalletHomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkWalletStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check wallet status when returning from other screens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletStatus();
    });
  }

  void _checkWalletStatus() async {
    try {
      final currentWallet = await WalletService.getCurrentWallet();
      final hasOpenWallet = await WalletService.hasOpenWallet();
      setState(() {
        _isWalletOpen = currentWallet != null && hasOpenWallet;
      });
    } catch (e) {
      setState(() {
        _isWalletOpen = false;
      });
    }
  }

  Future<void> _initPlatformState() async {
    String? platformVersion;
    try {
      platformVersion = await _flutterLibmwc.getPlatformVersion();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    bool enabled = true,
  }) {
    final isEnabled = enabled && onPressed != null;
    final effectiveBackgroundColor =
        backgroundColor ?? Theme.of(context).primaryColor;

    return Card(
      child: ListTile(
        enabled: isEnabled,
        leading: CircleAvatar(
          backgroundColor:
              isEnabled ? effectiveBackgroundColor : Colors.grey.shade400,
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.grey.shade600,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isEnabled ? null : Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isEnabled ? null : Colors.grey.shade600,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isEnabled ? null : Colors.grey.shade400,
        ),
        onTap: isEnabled ? onPressed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MWC Wallet Demo'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Wallet Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildMenuButton(
                  title: 'Create New Wallet',
                  subtitle: 'Generate a new MWC wallet with recovery phrase',
                  icon: Icons.add_circle,
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const CreateWalletView(),
                      ),
                    );
                    _checkWalletStatus(); // Refresh status after returning.
                  },
                ),
                _buildMenuButton(
                  title: 'Restore from Seed',
                  subtitle: 'Recover wallet from recovery phrase',
                  icon: Icons.restore,
                  backgroundColor: Colors.orange,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const RestoreWalletView(),
                      ),
                    );
                    _checkWalletStatus(); // Refresh status after returning.
                  },
                ),
                _buildMenuButton(
                  title: 'Open Existing Wallet',
                  subtitle: 'Access your existing MWC wallet',
                  icon: Icons.folder_open,
                  backgroundColor: Colors.blue,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const OpenWalletView(),
                      ),
                    );
                    _checkWalletStatus(); // Refresh status after returning.
                  },
                ),
                _buildMenuButton(
                  title: 'Wallet Information',
                  subtitle: _isWalletOpen
                      ? 'View wallet details and mnemonic'
                      : 'Open a wallet first to view information',
                  icon: Icons.info,
                  backgroundColor: Colors.teal,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const WalletInfoView(),
                            ),
                          );
                        }
                      : null,
                ),
                _buildMenuButton(
                  title: 'Slatepack Demo',
                  subtitle: _isWalletOpen
                      ? 'Demonstrate Slatepack encoding and sharing'
                      : 'Open a wallet first to use Slatepack features',
                  icon: Icons.qr_code,
                  backgroundColor: Colors.purple,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const SlatepackDemoView(),
                            ),
                          );
                        }
                      : null,
                ),
                _buildMenuButton(
                  title: 'MWC713 Features Test',
                  subtitle: _isWalletOpen
                      ? 'Test MWCMQS, File Transactions, Payment Proofs & Encrypted Slatepacks'
                      : 'Open a wallet first to test MWC713 features',
                  icon: Icons.science,
                  backgroundColor: Colors.red,
                  enabled: _isWalletOpen,
                  onPressed: _isWalletOpen
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<dynamic>(
                              builder: (context) => const MWC713FeaturesTestView(),
                            ),
                          );
                        }
                      : null,
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildMenuButton(
                  title: 'Wallet Settings',
                  subtitle: 'Configure network, manage wallets',
                  icon: Icons.settings,
                  backgroundColor: Colors.purple,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<dynamic>(
                        builder: (context) => const WalletSettingsView(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Platform: $_platformVersion',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
