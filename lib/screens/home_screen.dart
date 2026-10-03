import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../storage.dart';
import '../theme/ops_theme.dart';
import '../ttlock_api.dart';
import '../widgets/ops_ui.dart';
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

  Widget _labeledField({
    required String label,
    required Widget field,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OpsFieldLabel(label),
        field,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filtered;
    final connected = _accessToken != null && _locks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TTLock Ops'),
        actions: [
          TextButton(
            onPressed: _openGateways,
            style: TextButton.styleFrom(foregroundColor: OpsColors.ink),
            child: const Text('Gateways'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _persist();
              messenger.showSnackBar(
                const SnackBar(content: Text('Αποθηκεύτηκε τοπικά')),
              );
            },
            child: const Text('Save'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const OpsSectionHeader(
            eyebrow: 'TTLock Ops / Cloud',
            title: 'Σύνδεση',
            subtitle: 'Έλεγχος πρόσβασης, χωρίς περισπασμούς.',
          ),
          const SizedBox(height: 16),
          if (connected) ...[
            OpsConnectedStrip(
              baseUrl: _baseUrl,
              clientId: _clientIdCtrl.text.trim(),
            ),
            const SizedBox(height: 16),
          ],
          _labeledField(
            label: 'API URL',
            field: DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _baseUrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final u in kBaseUrls)
                  DropdownMenuItem(value: u, child: Text(u, maxLines: 1)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _baseUrl = v);
              },
            ),
          ),
          const SizedBox(height: 8),
          _labeledField(
            label: 'clientId',
            field: TextField(
              controller: _clientIdCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              autocorrect: false,
            ),
          ),
          const SizedBox(height: 8),
          if (!_useToken) ...[
            _labeledField(
              label: 'clientSecret',
              field: TextField(
                controller: _clientSecretCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                obscureText: true,
                autocorrect: false,
              ),
            ),
            const SizedBox(height: 8),
            _labeledField(
              label: 'username',
              field: TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                autocorrect: false,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            const SizedBox(height: 8),
            _labeledField(
              label: 'password',
              field: TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                obscureText: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Σύνδεση με token',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OpsColors.ink,
              ),
            ),
            value: _useToken,
            onChanged: (v) => setState(() => _useToken = v),
          ),
          if (_useToken) ...[
            const SizedBox(height: 8),
            _labeledField(
              label: 'access_token',
              field: TextField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                obscureText: true,
                autocorrect: false,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OpsPrimaryButton(
            label: _loading ? 'Φόρτωση…' : 'Σύνδεση & κλειδαριές',
            onPressed: _loading ? null : _loadLocks,
            busy: _loading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            OpsErrorBanner(_error!),
          ],
          if (!_loading && _error == null && _locks.isEmpty) ...[
            const SizedBox(height: 16),
            const OpsNote(
              'Χρησιμοποιήστε τα στοιχεία της εφαρμογής σας στο TTLock Cloud.',
            ),
          ],
          if (_locks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'ΚΛΕΙΔΑΡΙΕΣ ${filtered.length}/${_locks.length}',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: OpsColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filterCtrl,
              decoration: const InputDecoration(
                hintText: 'Φίλτρο alias / name / MAC',
                prefixIcon: Icon(Icons.search, color: OpsColors.ink),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            ...filtered.map((lk) {
              final alias = lk['lockAlias']?.toString() ?? '';
              final name = lk['lockName']?.toString() ?? '';
              final title = alias.isNotEmpty ? alias : name;
              final mac = lk['lockMac']?.toString() ?? '—';
              final bat = lk['electricQuantity'];
              final batNum = bat is num ? bat : num.tryParse('$bat');
              final gw = lk['hasGateway'] == 1;
              final id = lk['lockId'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OpsPanel(
                  onTap: () => _openLock(lk),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Κλειδαριά $id' : title,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: OpsColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'id=$id · mac=$mac',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 11,
                                color: OpsColors.muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                OpsStamp(
                                  'BAT ${bat ?? '—'}%',
                                  color: opsBatteryColor(batNum),
                                ),
                                OpsStamp(
                                  gw ? 'GATEWAY YES' : 'GATEWAY NO',
                                  color: gw
                                      ? OpsColors.success
                                      : OpsColors.muted,
                                  bg: gw
                                      ? const Color(0x1A3D7C2E)
                                      : OpsColors.field,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: OpsColors.ink),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
          Center(
            child: Text(
              'TTLOCK CLOUD API  /  ANDROID',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 9,
                color: OpsColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
