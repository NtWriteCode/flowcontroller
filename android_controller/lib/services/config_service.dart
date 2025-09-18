import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';

class ConfigService {
  static const String _configKey = 'server_config';

  static Future<ServerConfig?> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);
      
      if (configJson != null) {
        final config = ServerConfig.fromJson(jsonDecode(configJson));
        return config.isValid ? config : null;
      }
      
      return null;
    } catch (e) {
      print('Failed to load config: $e');
      return null;
    }
  }

  static Future<bool> saveConfig(ServerConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(config.toJson());
      return await prefs.setString(_configKey, configJson);
    } catch (e) {
      print('Failed to save config: $e');
      return false;
    }
  }

  static Future<bool> clearConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_configKey);
    } catch (e) {
      print('Failed to clear config: $e');
      return false;
    }
  }
}
