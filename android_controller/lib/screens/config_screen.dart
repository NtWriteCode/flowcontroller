import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_config.dart';
import '../services/config_service.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import 'qr_scanner_screen.dart';
import 'qr_share_screen.dart';

class ConfigScreen extends StatefulWidget {
  final ServerConfig? initialConfig;
  final VoidCallback onConfigSaved;

  const ConfigScreen({
    super.key,
    this.initialConfig,
    required this.onConfigSaved,
  });

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _tokenController = TextEditingController();
  final _macController = TextEditingController();
  
  bool _isLoading = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      _hostController.text = widget.initialConfig!.host;
      _portController.text = widget.initialConfig!.port.toString();
      _tokenController.text = widget.initialConfig!.apiToken;
      _macController.text = widget.initialConfig!.macAddress;
    } else {
      // Default values
      _portController.text = '8080';
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _macController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final config = ServerConfig(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        apiToken: _tokenController.text.trim(),
        macAddress: _macController.text.trim(),
      );

      final apiService = ApiService(config);
      final isHealthy = await apiService.healthCheck();

      String? discoveredMac;
      if (isHealthy) {
        // Get MAC address from server
        discoveredMac = await apiService.getMacAddress();
        if (discoveredMac != null) {
          // Update the MAC address field
          _macController.text = discoveredMac;
        }
      }

      setState(() {
        if (isHealthy) {
          _connectionStatus = discoveredMac != null 
            ? 'Connection successful! ✅\nMAC address discovered: $discoveredMac'
            : 'Connection successful! ✅\n(MAC address not found - Wake-on-LAN unavailable)';
        } else {
          _connectionStatus = 'Connection failed. Check server and network.';
        }
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final ServerConfig? scannedConfig = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const QRScannerScreen(),
        ),
      );

      if (scannedConfig != null) {
        setState(() {
          _hostController.text = scannedConfig.host;
          _portController.text = scannedConfig.port.toString();
          _tokenController.text = scannedConfig.apiToken;
          _macController.text = scannedConfig.macAddress;
          _connectionStatus = 'Configuration loaded from QR code successfully! ✅';
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration loaded from QR code!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning QR code: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareQRCode() {
    // Check if we have a valid configuration to share
    if (_hostController.text.trim().isEmpty || 
        _portController.text.trim().isEmpty ||
        _tokenController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields before sharing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final config = ServerConfig(
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 8080,
      apiToken: _tokenController.text.trim(),
      macAddress: _macController.text.trim(),
    );

    if (!config.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please ensure all fields are valid before sharing'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRShareScreen(config: config),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final config = ServerConfig(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        apiToken: _tokenController.text.trim(),
        macAddress: _macController.text.trim(),
      );

      final saved = await ConfigService.saveConfig(config);
      
      if (saved) {
        if (mounted) {
          // Show success message first
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Only pop if there's a route to pop back to
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            
            // Wait for navigation animation to complete before triggering callback
            Future.delayed(const Duration(milliseconds: 300), () {
              // Trigger callback after navigation animation is completely done
              widget.onConfigSaved();
            });
          } else {
            // No route to pop, directly trigger callback (first time setup)
            widget.onConfigSaved();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save configuration'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return IconButton(
                icon: Icon(
                  themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () => themeService.toggleTheme(),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Configure your PC server connection:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              
              // QR Code buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanQRCode,
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                      label: const Text(
                        'Scan QR',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareQRCode,
                      icon: const Icon(Icons.qr_code_2, color: Colors.green),
                      label: const Text(
                        'Share QR',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[400])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR ENTER MANUALLY',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[400])),
                ],
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Server IP Address',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter server IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '8080',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter port number';
                  }
                  final port = int.tryParse(value.trim());
                  if (port == null || port < 1 || port > 65535) {
                    return 'Please enter a valid port (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  hintText: 'secret-token',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter API token';
                  }
                  if (value.trim().length < 8) {
                    return 'API token should be at least 8 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // MAC address display (auto-discovered)
              TextFormField(
                controller: _macController,
                decoration: InputDecoration(
                  labelText: 'MAC Address (Auto-discovered)',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.network_check,
                    color: _macController.text.isNotEmpty 
                      ? Theme.of(context).colorScheme.primary
                      : null,
                  ),
                  helperText: 'Automatically discovered when connection test succeeds',
                  filled: _macController.text.isNotEmpty,
                  fillColor: _macController.text.isNotEmpty 
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                ),
                readOnly: true,
                style: TextStyle(
                  color: _macController.text.isNotEmpty 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: _macController.text.isNotEmpty 
                    ? FontWeight.w600 
                    : FontWeight.normal,
                ),
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                onPressed: _isTestingConnection ? null : _testConnection,
                icon: _isTestingConnection 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_find),
                label: Text(_isTestingConnection ? 'Testing...' : 'Test Connection'),
              ),
              
              if (_connectionStatus != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _connectionStatus!.contains('successful')
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _connectionStatus!.contains('successful')
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    ),
                  ),
                  child: Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: _connectionStatus!.contains('successful')
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                icon: _isLoading 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Configuration'),
              ),
              
              // Add some bottom padding for better scrolling
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
