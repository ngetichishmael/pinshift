class SavedLogin {
  const SavedLogin({
    required this.id,
    required this.host,
    required this.username,
    required this.password,
  });

  final String id;
  final String host;
  final String username;
  final String password;

  SavedLogin copyWith({String? host, String? username, String? password}) {
    return SavedLogin(
      id: id,
      host: host ?? this.host,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'host': host,
    'username': username,
    'password': password,
  };

  factory SavedLogin.fromJson(Map<String, dynamic> json) {
    return SavedLogin(
      id: json['id'] as String,
      host: json['host'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }
}

/// Reduces a typed address or full URL to a bare lowercase host without
/// `www.`, so `https://WWW.Example.com/login` and `example.com` compare equal.
String normalizeHost(String input) {
  var value = input.trim().toLowerCase();
  if (value.isEmpty) {
    return '';
  }
  if (!value.contains('://')) {
    value = 'https://$value';
  }
  final host = Uri.tryParse(value)?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// A saved login may only be filled into its own site or one of its
/// subdomains, never into an unrelated page.
bool loginMatchesHost(SavedLogin login, String? pageHost) {
  if (pageHost == null || pageHost.isEmpty) {
    return false;
  }
  final page = normalizeHost(pageHost);
  return page == login.host || page.endsWith('.${login.host}');
}
