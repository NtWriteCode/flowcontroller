class ServerConfig {
  final String host;
  final int port;
  final String apiToken;
  final String macAddress;

  ServerConfig({
    required this.host,
    required this.port,
    required this.apiToken,
    required this.macAddress,
  });

  String get baseUrl => 'http://$host:$port';

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'apiToken': apiToken,
    'macAddress': macAddress,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    host: json['host'] ?? '',
    port: json['port'] ?? 8080,
    apiToken: json['apiToken'] ?? '',
    macAddress: json['macAddress'] ?? '',
  );

  ServerConfig copyWith({
    String? host,
    int? port,
    String? apiToken,
    String? macAddress,
  }) => ServerConfig(
    host: host ?? this.host,
    port: port ?? this.port,
    apiToken: apiToken ?? this.apiToken,
    macAddress: macAddress ?? this.macAddress,
  );

  bool get isValid => host.isNotEmpty && apiToken.isNotEmpty && port > 0;
}
