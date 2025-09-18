import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/server_config.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () async {
              await controller.toggleTorch();
            },
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: controller,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Point your camera at the QR code displayed on your PC screen',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!hasScanned && capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      if (code != null) {
        hasScanned = true;
        controller.stop();
        _processQRData(code);
      }
    }
  }

  void _processQRData(String qrData) {
    try {
      // Parse the JSON data from QR code
      final Map<String, dynamic> data = jsonDecode(qrData);
      
      // Validate required fields
      if (data['host'] == null || data['port'] == null || data['token'] == null) {
        _showError('Invalid QR code: Missing required configuration data');
        return;
      }

      // Create ServerConfig from QR data
      final config = ServerConfig(
        host: data['host'].toString(),
        port: int.tryParse(data['port'].toString()) ?? 8080,
        apiToken: data['token'].toString(),
        macAddress: data['mac']?.toString() ?? '',
      );

      // Validate the config
      if (!config.isValid) {
        _showError('Invalid QR code: Configuration data is not valid');
        return;
      }

      // Return the config to the previous screen
      Navigator.of(context).pop(config);
      
    } catch (e) {
      _showError('Invalid QR code: Could not parse configuration data');
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                hasScanned = false;
              });
              controller.start();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
