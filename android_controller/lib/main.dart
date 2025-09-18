import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/server_config.dart';
import 'services/config_service.dart';
import 'services/theme_service.dart';
import 'screens/config_screen.dart';
import 'screens/control_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeService()..loadTheme(),
      child: const FlowControllerApp(),
    ),
  );
}

class FlowControllerApp extends StatelessWidget {
  const FlowControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'Flow Controller',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: themeService.themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  ServerConfig? _config;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await ConfigService.loadConfig();
      setState(() {
        _config = config;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load configuration: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onConfigChanged() {
    _loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading configuration...'),
            ],
          ),
        ),
      );
    }

    if (_config == null || !_config!.isValid) {
      return ConfigScreen(
        initialConfig: _config,
        onConfigSaved: _onConfigChanged,
      );
    }

    return ControlScreen(
      config: _config!,
      onConfigChanged: _onConfigChanged,
    );
  }
}