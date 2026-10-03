import 'package:flutter/material.dart';

import '../storage.dart';
import '../ttlock_api.dart';
import 'gateways_screen.dart';
import 'lock_detail_screen.dart';

const List<String> kBaseUrls = [
  'https://euapi.ttlock.com',
  'https://api.ttlock.com',
  'https://api.sciener.com',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _filterCtrl = TextEditingController();

  String _baseUrl = kBaseUrls.first;
  bool _useToken = false;
  bool _loading = false;
  bool _ready = false;
  String? _error;
  List<Map<String, dynamic>> _locks = [];
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final c = await AppStorage.load();
    setState(() {
      _baseUrl = kBaseUrls.contains(c.baseUrl) ? c.baseUrl : kBaseUrls.first;
      _clientIdCtrl.text = c.clientId;
      _clientSecretCtrl.text = c.clientSecret;
      _usernameCtrl.text = c.username;
      _passwordCtrl.text = c.password;
      _tokenCtrl.text = c.accessToken;
      _useToken = c.useToken;
      _accessToken = c.accessToken.isEmpty ? null : c.accessToken;
      _ready = true;
    });
  }

  Future<void> _persist({String? token}) async {
    await AppStorage.save(
      AppCredentials(
        baseUrl: _baseUrl,
        clientId: _clientIdCtrl.text.trim(),
        clientSecret: _clientSecretCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        accessToken: token ?? _tokenCtrl.text.trim(),
        useToken: _useToken,
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _filterCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _locks;
    return _locks.where((lk) {
      final name = '${lk['lockName'] ?? ''}'.toLowerCase();
      final alias = '${lk['lockAlias'] ?? ''}'.toLowerCase();
      final mac = '${lk['lockMac'] ?? ''}'.toLowerCase();
      return name.contains(q) || alias.contains(q) || mac.contains(q);
    }).toList();
  }

  Future<String> _resolveToken(TtlockApi api) async {
    if (_useToken) {
      final token = _tokenCtrl.text.trim();
      if (token.isEmpty) {
        throw TtlockException('Χρειάζεσαι clientId + access token');
      }
      return token;
    }
    final secret = _clientSecretCtrl.text.trim();
    final user = _usernameCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (secret.isEmpty || user.isEmpty || pass.isEmpty) {
      throw TtlockException(
        'Συμπλήρωσε clientId, clientSecret, username, password',
      );
    }
    final tokenData = await api.getToken(
      clientSecret: secret,
      username: user,
      password: pass,
    );
    final token = tokenData['access_token'] as String;
    _tokenCtrl.text = token;
    return token;
  }

  Future<void> _loadLocks() async {
    FocusScope.of(context).unfocus();
    final clientId = _clientIdCtrl.text.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Συμπλήρωσε clientId')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = TtlockApi(baseUrl: _baseUrl, clientId: clientId);
      final token = await _resolveToken(api);
      final data = await api.listLocks(accessToken: token);
      if (data.containsKey('errcode') &&
          data['errcode'] != 0 &&
          data['errcode'] != null &&
          !data.containsKey('list')) {
        throw TtlockException('API error: ${data['errmsg'] ?? data}', data);
      }
      final list = (data['list'] as List?) ?? [];
      final locks = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      await _persist(token: token);
      setState(() {
        _accessToken = token;
        _locks = locks;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _locks = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    return int.parse('$v');
  }

  void _openLock(Map<String, dynamic> lock) {
    if (_accessToken == null) return;
    final id = _asInt(lock['lockId']);
    final alias = lock['lockAlias']?.toString() ?? '';
    final name = lock['lockName']?.toString() ?? '';
    final title = alias.isNotEmpty ? alias : (name.isNotEmpty ? name : '$id');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LockDetailScreen(
          baseUrl: _baseUrl,
          clientId: _clientIdCtrl.text.trim(),
          accessToken: _accessToken!,
          lockId: id,
          title: title,
          hasGateway: lock['hasGateway'] == 1,
        ),
      ),
    );
  }

  void _openGateways() {
    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Φόρτωσε πρώτα τις κλειδαριές (login)')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GatewaysScreen(
          baseUrl: _baseUrl,
          clientId: _clientIdCtrl.text.trim(),
          accessToken: _accessToken!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _tokenCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTLock Ops'),
        actions: [
          IconButton(
            tooltip: 'Gateways',
            onPressed: _openGateways,
            icon: const Icon(Icons.router),
          ),
          IconButton(
            tooltip: 'Αποθήκευση',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _persist();
              messenger.showSnackBar(
                const SnackBar(content: Text('Αποθηκεύτηκε τοπικά')),
              );
            },
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Σύνδεση', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _baseUrl,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final u in kBaseUrls)
                DropdownMenuItem(value: u, child: Text(u, maxLines: 1)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _baseUrl = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientIdCtrl,
            decoration: const InputDecoration(
              labelText: 'clientId',
              border: OutlineInputBorder(),
            ),
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          if (!_useToken) ...[
            TextField(
              controller: _clientSecretCtrl,
              decoration: const InputDecoration(
                labelText: 'clientSecret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'TTLock App username',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'TTLock App password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Χρησιμοποίησε access token'),
            value: _useToken,
            onChanged: (v) => setState(() => _useToken = v),
          ),
          if (_useToken)
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'access_token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autocorrect: false,
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _loadLocks,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open),
            label: Text(_loading ? 'Φόρτωση…' : 'Σύνδεση & κλειδαριές'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (_locks.isNotEmpty) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _filterCtrl,
              decoration: const InputDecoration(
                labelText: 'Φίλτρο alias / name / MAC',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Κλειδαριές: ${filtered.length} / ${_locks.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...filtered.map((lk) {
              final alias = lk['lockAlias']?.toString() ?? '';
              final name = lk['lockName']?.toString() ?? '';
              final title = alias.isNotEmpty ? alias : name;
              final mac = lk['lockMac']?.toString() ?? '—';
              final bat = lk['electricQuantity'];
              final gw = lk['hasGateway'] == 1;
              final id = lk['lockId'];
              return Card(
                child: ListTile(
                  title: Text(title.isEmpty ? 'Κλειδαριά $id' : title),
                  subtitle: Text(
                    'id=$id · mac=$mac · μπατ=${bat ?? '—'}% · '
                    'gateway=${gw ? 'ναι' : 'όχι'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openLock(lk),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
