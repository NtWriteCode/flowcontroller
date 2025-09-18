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

      // Calculate broadcast IP from server IP
      final broadcastIp = _calculateBroadcastIp(config.host);
      final ipValidation = IPAddress.validate(broadcastIp);
      if (!ipValidation.state) {
        print('Wake-on-LAN: Invalid broadcast IP: $broadcastIp');
        return false;
      }

      // Create MAC and IP address objects
      final mac = MACAddress(config.macAddress);
      final ip = IPAddress(broadcastIp);

      // Create WakeOnLAN instance and send magic packet
      final wol = WakeOnLAN(ip, mac);
      
      print('Wake-on-LAN: Sending magic packet to ${config.macAddress} via $broadcastIp');
      
      await wol.wake(
        repeat: 3, // Send 3 packets for reliability
        repeatDelay: const Duration(milliseconds: 500),
      );

      print('Wake-on-LAN: Magic packet sent successfully');
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
