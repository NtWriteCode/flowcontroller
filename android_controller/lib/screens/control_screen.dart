import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';
import '../services/api_service.dart';
import '../services/wake_on_lan_service.dart';
import 'config_screen.dart';

class ControlScreen extends StatefulWidget {
  final ServerConfig config;
  final VoidCallback onConfigChanged;

  const ControlScreen({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late ApiService _apiService;
  late WakeOnLanService _wolService;
  // Removed animation controller - using only haptic feedback now
  
  Timer? _holdTimer;
  String? _currentDirection;
  Timer? _tapDelayTimer; // Timer to wait for potential second tap
  String _lastGesture = '';
  DateTime _lastTapTime = DateTime(0);
  Offset? _lastTapPosition;
  
  // Hidden keyboard input
  final TextEditingController _keyboardController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _lastKeyboardText = '';
  bool _isKeyboardMode = false;
  
  // Swipe-and-hold tracking
  Offset? _panStartPosition;
  bool _isPanInProgress = false;
  bool _isHolding = false;
  
  // Volume tracking (approximate)
  int _volumeLevel = 50; // Start at 50% (reasonable default)
  
  // Hardware volume button interception
  static const volumeChannel = MethodChannel('com.ntwritecode.flowcontroller/volume');
  static const volumeEventChannel = EventChannel('com.ntwritecode.flowcontroller/volume_events');
  StreamSubscription<dynamic>? _volumeButtonSubscription;
  bool _hardwareVolumeEnabled = false;
  
  // Connection status tracking
  Timer? _healthCheckTimer;
  bool _isServerOnline = false;
  int _pingMs = -1;
  
  // Gesture sensitivity settings
  final double _swipeThreshold = 50.0;
  final double _doubleTapMaxDistance = 50.0;
  final Duration _doubleTapMaxDuration = const Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(widget.config);
    _wolService = WakeOnLanService(widget.config);
    
    // Setup keyboard input listener
    _keyboardController.addListener(_onKeyboardTextChanged);
    _keyboardFocusNode.addListener(_onKeyboardFocusChanged);
    
    // Load hardware volume preference and start listening if enabled
    _loadHardwareVolumePreference();
    
    // Start health checking
    _startHealthChecking();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _tapDelayTimer?.cancel();
    _healthCheckTimer?.cancel();
    _volumeButtonSubscription?.cancel();
    _keyboardController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // Hardware volume button handling
  Future<void> _loadHardwareVolumePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('hardware_volume_enabled') ?? false;
    setState(() {
      _hardwareVolumeEnabled = enabled;
    });
    if (enabled) {
      _startVolumeButtonListener();
    }
  }

  Future<void> _toggleHardwareVolume() async {
    final newValue = !_hardwareVolumeEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hardware_volume_enabled', newValue);
    
    setState(() {
      _hardwareVolumeEnabled = newValue;
    });
    
    if (newValue) {
      _startVolumeButtonListener();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hardware volume buttons will now control PC volume'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      _stopVolumeButtonListener();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hardware volume buttons restored to phone volume'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _startVolumeButtonListener() async {
    _volumeButtonSubscription?.cancel();
    
    // Enable volume button interception in native code
    try {
      await volumeChannel.invokeMethod('enableVolumeButtons');
      
      // Listen to volume button events
      _volumeButtonSubscription = volumeEventChannel.receiveBroadcastStream().listen((event) {
        if (event == 'volume_down') {
          HapticFeedback.lightImpact();
          _sendVolumeCommand('down');
        } else if (event == 'volume_up') {
          HapticFeedback.lightImpact();
          _sendVolumeCommand('up');
        }
      });
    } catch (e) {
      print('Error starting volume button listener: $e');
    }
  }

  void _stopVolumeButtonListener() async {
    _volumeButtonSubscription?.cancel();
    _volumeButtonSubscription = null;
    
    // Disable volume button interception in native code
    try {
      await volumeChannel.invokeMethod('disableVolumeButtons');
    } catch (e) {
      print('Error stopping volume button listener: $e');
    }
  }

  // Keyboard input handling
  void _onKeyboardFocusChanged() {
    setState(() {
      _isKeyboardMode = _keyboardFocusNode.hasFocus;
      if (_isKeyboardMode) {
        _lastGesture = 'Keyboard Active';
      } else {
        _lastGesture = '';
      }
    });
  }

  void _onKeyboardTextChanged() {
    final currentText = _keyboardController.text;
    
    if (currentText.length > _lastKeyboardText.length) {
      // Text was added - send the new character(s)
      final newChars = currentText.substring(_lastKeyboardText.length);
      for (final char in newChars.characters) {
        HapticFeedback.lightImpact();
        _tryWakeOnLan(); // Non-blocking WoL attempt
        _apiService.sendText(char);
      }
    } else if (currentText.length < _lastKeyboardText.length) {
      // Text was deleted - send backspace
      final deletedCount = _lastKeyboardText.length - currentText.length;
      for (int i = 0; i < deletedCount; i++) {
        HapticFeedback.lightImpact();
        _tryWakeOnLan(); // Non-blocking WoL attempt
        _apiService.sendKey('backspace');
      }
    }
    
    _lastKeyboardText = currentText;
  }

  void _toggleKeyboard() {
    if (_isKeyboardMode) {
      _keyboardFocusNode.unfocus();
      _keyboardController.clear();
      _lastKeyboardText = '';
    } else {
      _keyboardFocusNode.requestFocus();
    }
  }

  // Health checking methods
  void _startHealthChecking() {
    // Do initial health check
    _performHealthCheck();
    
    // Set up periodic health checks every 10 seconds
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() async {
    final result = await _apiService.healthCheckWithPing();
    
    if (mounted) {
      setState(() {
        _isServerOnline = result.isOnline;
        _pingMs = result.pingMs;
      });
    }
  }

  // Wake-on-LAN helper
  Future<void> _tryWakeOnLan() async {
    if (!_isServerOnline && _wolService.isConfigured) {
      print('Server is offline, attempting Wake-on-LAN...');
      final success = await _wolService.sendWakePacket();
      if (success && mounted) {
        setState(() {
          _lastGesture = 'Wake-on-LAN sent';
        });
        
        // Show brief feedback
        Timer(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _lastGesture = '';
            });
          }
        });
      }
    }
  }
  
  void _sendVolumeCommand(String direction) async {
    // Try Wake-on-LAN if server is offline
    await _tryWakeOnLan();
    
    // Update approximate volume level
    if (direction == 'up') {
      _volumeLevel = (_volumeLevel + 10).clamp(0, 100);
    } else {
      _volumeLevel = (_volumeLevel - 10).clamp(0, 100);
    }
    
    // Send the command
    bool success = await _apiService.sendVolumeControl(direction);
    
    // Show volume percentage feedback
    if (success && mounted) {
      setState(() {
        _lastGesture = 'Volume $_volumeLevel%';
      });
      
      // Clear the text after a delay
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _lastGesture = '';
          });
        }
      });
    }
  }

  void _startHoldTimer(String direction) {
    _holdTimer?.cancel();
    _currentDirection = direction;
    
    _holdTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final direction = _currentDirection;
      if (direction != null) {
        _apiService.sendArrowKey(direction);
      }
    });
  }

  void _stopHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _currentDirection = null;
  }

  void _handlePanStart(DragStartDetails details) {
    _stopHoldTimer();
    _panStartPosition = details.globalPosition;
    _isPanInProgress = true;
    _isHolding = false;
    
    // Don't interfere with tap detection initially
    // Let panUpdate determine if this is actually a swipe
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isPanInProgress || _panStartPosition == null) return;
    
    // Calculate distance and direction from start
    final currentPos = details.globalPosition;
    final startPos = _panStartPosition!;
    final dx = currentPos.dx - startPos.dx;
    final dy = currentPos.dy - startPos.dy;
    final distance = sqrt(dx * dx + dy * dy);
    
    // Check if we've moved far enough to be considered a swipe
    if (distance > _swipeThreshold && !_isHolding) {
      // Determine direction
      String direction;
      if (dx.abs() > dy.abs()) {
        direction = dx > 0 ? 'right' : 'left';
      } else {
        direction = dy > 0 ? 'down' : 'up';
      }
      
      // Send initial arrow key
      HapticFeedback.lightImpact();
      _tryWakeOnLan(); // Non-blocking WoL attempt
      _apiService.sendArrowKey(direction);
      
      // Start holding (repeating)
      _isHolding = true;
      _startHoldTimer(direction);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isHolding) {
      // If we were holding, stop the timer
      _stopHoldTimer();
    } else if (_isPanInProgress && _panStartPosition != null) {
      // Check if this was actually a tap (very small movement)
      final endPos = details.globalPosition;
      final startPos = _panStartPosition!;
      final totalDistance = sqrt((endPos.dx - startPos.dx) * (endPos.dx - startPos.dx) + 
                                (endPos.dy - startPos.dy) * (endPos.dy - startPos.dy));
      
      if (totalDistance < _doubleTapMaxDistance) {
        // This was essentially a tap, handle it as such
        _handleTapFromPan(endPos);
      } else {
        // This was a quick swipe - use velocity for detection
        final velocity = details.velocity.pixelsPerSecond;
        final dx = velocity.dx.abs();
        final dy = velocity.dy.abs();
        
        String? direction;
        if (dx > dy && dx > _swipeThreshold) {
          direction = velocity.dx > 0 ? 'right' : 'left';
        } else if (dy > dx && dy > _swipeThreshold) {
          direction = velocity.dy > 0 ? 'down' : 'up';
        }
        
        if (direction != null) {
          HapticFeedback.lightImpact();
          _tryWakeOnLan(); // Non-blocking WoL attempt
          _apiService.sendArrowKey(direction);
        }
      }
    }
    
    // Reset state
    _isPanInProgress = false;
    _isHolding = false;
    _panStartPosition = null;
  }


  void _handleTapFromPan(Offset position) {
    final now = DateTime.now();
    
    // Check if this could be the second tap of a double-tap
    final lastPos = _lastTapPosition;
    if (lastPos != null) {
      final timeDiff = now.difference(_lastTapTime);
      final distance = (position - lastPos).distance;
      
      if (timeDiff <= _doubleTapMaxDuration && distance <= _doubleTapMaxDistance) {
        // This is a double-tap! Cancel any pending single tap and send ESC
        _tapDelayTimer?.cancel();
        HapticFeedback.mediumImpact();
        _tryWakeOnLan(); // Non-blocking WoL attempt
        _apiService.sendKey('escape');
        
        // Reset to prevent triple tap
        _lastTapPosition = null;
        _lastTapTime = DateTime(0);
        return;
      }
    }
    
    // This might be the first tap of a double-tap, so wait before sending Enter
    _lastTapTime = now;
    _lastTapPosition = position;
    
    // Cancel any previous timer
    _tapDelayTimer?.cancel();
    
    // Wait for potential second tap
    _tapDelayTimer = Timer(_doubleTapMaxDuration, () {
      // No second tap came, this was a single tap - send Enter
      HapticFeedback.lightImpact();
      _tryWakeOnLan(); // Non-blocking WoL attempt
      _apiService.sendKey('enter');
    });
  }

  // Removed _handleTap method - now using only pan gesture system for better reliability

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConfigScreen(
          initialConfig: widget.config,
          onConfigSaved: widget.onConfigChanged,
        ),
      ),
    );
  }

  void _openKeyboard() {
    HapticFeedback.lightImpact();
    _toggleKeyboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Hidden keyboard input field
            Positioned(
              left: -1000, // Hide it off-screen
              top: -1000,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: _keyboardController,
                  focusNode: _keyboardFocusNode,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                ),
              ),
            ),
            
            // Main gesture area
            GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              // Removed onTapDown to prevent conflicts with pan gestures
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 80,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gesture Control Area',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quick swipe: Single arrow key\nSwipe + hold: Continuous arrows\nTap: Enter\nDouble tap: Escape',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Visual feedback overlay
            // Only show feedback when there's actual text to display
            if (_lastGesture.isNotEmpty)
              Container(
                width: double.infinity,
                height: double.infinity,
                color: theme.colorScheme.primary.withOpacity(0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _lastGesture,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Top bar with settings and hardware volume toggle
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Hardware volume button toggle
                  IconButton(
                    onPressed: _toggleHardwareVolume,
                    icon: Icon(
                      _hardwareVolumeEnabled ? Icons.volume_up : Icons.volume_off,
                      color: _hardwareVolumeEnabled ? Colors.green : theme.colorScheme.onSurface,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                    ),
                    tooltip: _hardwareVolumeEnabled 
                        ? 'Hardware buttons control PC (tap to disable)'
                        : 'Hardware buttons control phone (tap to enable PC control)',
                  ),
                  const SizedBox(width: 8),
                  // Settings button
                  IconButton(
                    onPressed: _openSettings,
                    icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom controls
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Volume down
                  FloatingActionButton(
                    heroTag: "volume_down",
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _sendVolumeCommand('down');
                    },
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.volume_down),
                  ),
                  
                  // Keyboard
                  FloatingActionButton.extended(
                    heroTag: "keyboard",
                    onPressed: _openKeyboard,
                    backgroundColor: _isKeyboardMode 
                        ? Colors.green.withOpacity(0.8) 
                        : Colors.blue.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    icon: Icon(
                      _isKeyboardMode ? Icons.keyboard_hide : Icons.keyboard,
                    ),
                    label: Text(
                      _isKeyboardMode ? 'Hide' : 'Keyboard',
                    ),
                  ),
                  
                  // Volume up
                  FloatingActionButton(
                    heroTag: "volume_up",
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _sendVolumeCommand('up');
                    },
                    backgroundColor: Colors.green.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.volume_up),
                  ),
                ],
              ),
            ),
            
            // Connection status indicator
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isServerOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.config.host}:${widget.config.port}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isServerOnline && _pingMs >= 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_pingMs}ms',
                        style: TextStyle(
                          color: _pingMs < 100 ? Colors.green[300] : 
                                _pingMs < 300 ? Colors.yellow[300] : Colors.red[300],
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
