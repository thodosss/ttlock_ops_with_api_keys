import 'package:shared_preferences/shared_preferences.dart';

class AppCredentials {
  const AppCredentials({
    required this.baseUrl,
    required this.clientId,
    required this.clientSecret,
    required this.username,
    required this.password,
    required this.accessToken,
    required this.useToken,
  });

  final String baseUrl;
  final String clientId;
  final String clientSecret;
  final String username;
  final String password;
  final String accessToken;
  final bool useToken;
}

class AppStorage {
  static const _prefix = 'ops_';

  static Future<AppCredentials> load() async {
    final p = await SharedPreferences.getInstance();
    return AppCredentials(
      baseUrl: p.getString('${_prefix}base_url') ?? 'https://euapi.ttlock.com',
      clientId: p.getString('${_prefix}client_id') ?? '',
      clientSecret: p.getString('${_prefix}client_secret') ?? '',
      username: p.getString('${_prefix}username') ?? '',
      password: p.getString('${_prefix}password') ?? '',
      accessToken: p.getString('${_prefix}access_token') ?? '',
      useToken: p.getBool('${_prefix}use_token') ?? false,
    );
  }

  static Future<void> save(AppCredentials c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_prefix}base_url', c.baseUrl);
    await p.setString('${_prefix}client_id', c.clientId);
    await p.setString('${_prefix}client_secret', c.clientSecret);
    await p.setString('${_prefix}username', c.username);
    await p.setString('${_prefix}password', c.password);
    await p.setString('${_prefix}access_token', c.accessToken);
    await p.setBool('${_prefix}use_token', c.useToken);
  }
}
