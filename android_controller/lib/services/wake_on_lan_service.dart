import 'package:wake_on_lan/wake_on_lan.dart';
import '../models/server_config.dart';

class WakeOnLanService {
  final ServerConfig config;
  
  WakeOnLanService(this.config);

  Future<bool> sendWakePacket() async {
    try {
      // Skip if MAC address is not configured
      if (config.macAddress.trim().isEmpty) {
        print('Wake-on-LAN: MAC address not configured, skipping');
        return false;
      }

      // Validate MAC address format
      final macValidation = MACAddress.validate(config.macAddress);
      if (!macValidation.state) {
        print('Wake-on-LAN: Invalid MAC address format: ${config.macAddress}');
        return false;
      }

      // Try all methods for maximum compatibility
      final mac = MACAddress(config.macAddress);
      
      // Method 1: Directed packet to server IP (works better with WiFi)
      try {
        final serverIp = IPAddress(config.host);
        final wolDirect = WakeOnLAN(serverIp, mac);
        print('Wake-on-LAN: Sending directed packet to ${config.macAddress} via ${config.host}');
        await wolDirect.wake(repeat: 2, repeatDelay: const Duration(milliseconds: 300));
      } catch (e) {
        print('Wake-on-LAN: Directed packet failed: $e');
      }
      
      // Method 2: Subnet broadcast (traditional method)
      try {
        final broadcastIp = _calculateBroadcastIp(config.host);
        final ip = IPAddress(broadcastIp);
        final wolBroadcast = WakeOnLAN(ip, mac);
        print('Wake-on-LAN: Sending broadcast packet to ${config.macAddress} via $broadcastIp');
        await wolBroadcast.wake(repeat: 2, repeatDelay: const Duration(milliseconds: 300));
      } catch (e) {
        print('Wake-on-LAN: Broadcast packet failed: $e');
      }
      
      // Method 3: Global broadcast (last resort)
      try {
        final globalBroadcast = IPAddress('255.255.255.255');
        final wolGlobal = WakeOnLAN(globalBroadcast, mac);
        print('Wake-on-LAN: Sending global broadcast packet to ${config.macAddress}');
        await wolGlobal.wake(repeat: 1, repeatDelay: const Duration(milliseconds: 200));
      } catch (e) {
        print('Wake-on-LAN: Global broadcast failed: $e');
      }

      print('Wake-on-LAN: All methods attempted. Check if PC wakes up.');
      return true;
    } catch (e) {
      print('Wake-on-LAN: Failed to send magic packet: $e');
      return false;
    }
  }

  /// Calculate broadcast IP from server IP
  /// For simplicity, assume /24 subnet (255.255.255.0)
  /// This works for most home networks
  String _calculateBroadcastIp(String serverIp) {
    try {
      final parts = serverIp.split('.');
      if (parts.length == 4) {
        // Replace last octet with 255 for /24 subnet
        return '${parts[0]}.${parts[1]}.${parts[2]}.255';
      }
    } catch (e) {
      print('Wake-on-LAN: Error calculating broadcast IP: $e');
    }
    
    // Fallback to common broadcast addresses
    return '255.255.255.255';
  }

  /// Check if Wake-on-LAN is properly configured
  bool get isConfigured {
    return config.macAddress.trim().isNotEmpty && 
           MACAddress.validate(config.macAddress).state;
  }
}
