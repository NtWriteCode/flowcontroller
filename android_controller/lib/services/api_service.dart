import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/server_config.dart';

class ApiService {
  final ServerConfig config;
  
  ApiService(this.config);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiToken}',
  };

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('${config.baseUrl}/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  Future<HealthCheckResult> healthCheckWithPing() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await http.get(
        Uri.parse('${config.baseUrl}/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      stopwatch.stop();
      final pingMs = stopwatch.elapsedMilliseconds;
      
      return HealthCheckResult(
        isOnline: response.statusCode == 200,
        pingMs: pingMs,
      );
    } catch (e) {
      stopwatch.stop();
      print('Health check failed: $e');
      return HealthCheckResult(
        isOnline: false,
        pingMs: -1, // -1 indicates timeout/error
      );
    }
  }

  Future<bool> sendArrowKey(String direction) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/arrow'),
        headers: _headers,
        body: jsonEncode({'direction': direction}),
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Arrow key failed: $e');
      return false;
    }
  }

  Future<bool> sendKey(String key) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/key'),
        headers: _headers,
        body: jsonEncode({'key': key}),
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Key press failed: $e');
      return false;
    }
  }

  Future<bool> sendText(String text) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/type'),
        headers: _headers,
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Text input failed: $e');
      return false;
    }
  }

  Future<bool> sendVolumeControl(String action) async {
    try {
      final response = await http.post(
        Uri.parse('${config.baseUrl}/volume'),
        headers: _headers,
        body: jsonEncode({'action': action}),
      ).timeout(const Duration(seconds: 2));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Volume control failed: $e');
      return false;
    }
  }

  Future<String?> getMacAddress() async {
    try {
      final response = await http.get(
        Uri.parse('${config.baseUrl}/mac'),
        headers: _headers,
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok' && data['mac_address'] != null) {
          return data['mac_address'] as String;
        }
      }
      return null;
    } catch (e) {
      print('MAC address retrieval failed: $e');
      return null;
    }
  }
}

class HealthCheckResult {
  final bool isOnline;
  final int pingMs;
  
  HealthCheckResult({
    required this.isOnline,
    required this.pingMs,
  });
}
