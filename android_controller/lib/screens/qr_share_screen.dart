import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/server_config.dart';

class QRShareScreen extends StatelessWidget {
  final ServerConfig config;

  const QRShareScreen({
    super.key,
    required this.config,
  });

  String _generateQRData() {
    // Generate JSON in the same format expected by the scanner
    final data = {
      'host': config.host,
      'port': config.port,
      'token': config.apiToken,
      'mac': config.macAddress,
    };
    return jsonEncode(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Connection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_2,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                'Scan this QR code',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use another device to scan and connect',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _generateQRData(),
                  version: QrVersions.auto,
                  size: 280.0,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) {
                    return const Center(
                      child: Text(
                        'Error generating QR code',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connection Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        icon: Icons.computer,
                        label: 'Host',
                        value: config.host,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        icon: Icons.settings_ethernet,
                        label: 'Port',
                        value: config.port.toString(),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        icon: Icons.security,
                        label: 'Token',
                        value: '••••••••',
                      ),
                      if (config.macAddress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context,
                          icon: Icons.network_check,
                          label: 'MAC',
                          value: config.macAddress,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Keep this QR code private. It contains your API token.',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
