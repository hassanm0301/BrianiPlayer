import 'dart:io';

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.label,
    required this.origin,
    this.allowInsecureHttp = false,
  });

  final String id;
  final String label;
  final Uri origin;
  final bool allowInsecureHttp;

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.label == label &&
      other.origin == origin &&
      other.allowInsecureHttp == allowInsecureHttp;

  @override
  int get hashCode => Object.hash(id, label, origin, allowInsecureHttp);

  static Uri parseOrigin(String input, {bool allowInsecureHttp = false}) {
    final uri = _parseOriginStructure(input);
    if (uri.scheme == 'http' && !_isLoopback(uri) && !allowInsecureHttp) {
      throw const FormatException(
        'Use HTTPS for a remote server, or explicitly allow unencrypted HTTP for a trusted local network.',
      );
    }
    return uri;
  }

  static Uri _parseOriginStructure(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter an HTTP or HTTPS server address without credentials, query, or fragment.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  static bool _isLoopback(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        (InternetAddress.tryParse(host)?.isLoopback ?? false);
  }

  void validateCredentialTransport() {
    if (!origin.hasScheme ||
        !const {'http', 'https'}.contains(origin.scheme.toLowerCase()) ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw const InsecureServerTransportException();
    }
    if (origin.scheme == 'http' && !_isLoopback(origin) && !allowInsecureHttp) {
      throw const InsecureServerTransportException();
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'origin': origin.toString(),
    'allowInsecureHttp': allowInsecureHttp,
  };

  factory ServerProfile.fromJson(Map<String, Object?> json) => ServerProfile(
    id: json['id']! as String,
    label: json['label']! as String,
    // Preserve legacy cleartext profiles so they remain visible and removable;
    // the API provider still blocks them before credentials are read.
    origin: _parseOriginStructure(json['origin']! as String),
    allowInsecureHttp: json['allowInsecureHttp'] == true,
  );
}

class InsecureServerTransportException implements Exception {
  const InsecureServerTransportException();

  @override
  String toString() => 'This server profile needs a secure connection setting.';
}
