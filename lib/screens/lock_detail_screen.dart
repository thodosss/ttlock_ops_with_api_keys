import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/ops_theme.dart';
import '../ttlock_api.dart';
import '../widgets/ops_ui.dart';

class LockDetailScreen extends StatefulWidget {
  const LockDetailScreen({
    super.key,
    required this.baseUrl,
    required this.clientId,
    required this.accessToken,
    required this.lockId,
    required this.title,
    required this.hasGateway,
  });

  final String baseUrl;
  final String clientId;
  final String accessToken;
  final int lockId;
  final String title;
  final bool hasGateway;

  @override
  State<LockDetailScreen> createState() => _LockDetailScreenState();
}

class _LockDetailScreenState extends State<LockDetailScreen>
    with SingleTickerProviderStateMixin {
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  late final TabController _tabs;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _detail;
  int? _openState;
  int? _battery;
  List<Map<String, dynamic>> _passcodes = [];
  List<Map<String, dynamic>> _lockGateways = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _ekeys = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _fingerprints = [];
  String _title = '';

  // Passcode form
  final _nameCtrl = TextEditingController();
  final _customCodeCtrl = TextEditingController();
  bool _useCustom = false;
  int _pwdType = 3;
  late DateTime _start;
  late DateTime _end;
  String? _createdPwd;

  // Records filter
  DateTime? _recStart;
  DateTime? _recEnd;

  // Send ekey form
  final _ekeyUserCtrl = TextEditingController();
  final _ekeyNameCtrl = TextEditingController();
  final _ekeyRemarksCtrl = TextEditingController();
  late DateTime _ekeyStart;
  late DateTime _ekeyEnd;
  bool _ekeyRemote = true;

  TtlockApi get _api =>
      TtlockApi(baseUrl: widget.baseUrl, clientId: widget.clientId);

  bool get _gatewayOk {
    final fromDetail = _detail?['hasGateway'];
    if (fromDetail is int) return fromDetail == 1;
    return widget.hasGateway;
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _title = widget.title;
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour);
    _end = _start.add(const Duration(days: 1));
    _ekeyStart = _start;
    _ekeyEnd = _end;
    _recStart = now.subtract(const Duration(days: 7));
    _recEnd = now.add(const Duration(hours: 1));
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _reloadDetail(),
        _reloadPasscodes(),
        _reloadLockGateways(),
        _reloadRecords(),
        _reloadAccess(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadDetail() async {
    final detail = await _api.lockDetail(
      accessToken: widget.accessToken,
      lockId: widget.lockId,
    );
    int? openState;
    int? battery = _asIntOrNull(detail['electricQuantity']);
    if (_gatewayOk || detail['hasGateway'] == 1) {
      try {
        final st = await _api.queryOpenState(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
        );
        openState = _asIntOrNull(st['state']);
      } catch (_) {}
      try {
        final bat = await _api.queryElectricQuantity(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
        );
        battery = _asIntOrNull(bat['electricQuantity']) ?? battery;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _openState = openState;
      _battery = battery;
      final alias = detail['lockAlias']?.toString() ?? '';
      final name = detail['lockName']?.toString() ?? '';
      if (alias.isNotEmpty) {
        _title = alias;
      } else if (name.isNotEmpty) {
        _title = name;
      }
    });
  }

  Future<void> _reloadPasscodes() async {
    final pwdData = await _api.listPasscodes(
      accessToken: widget.accessToken,
      lockId: widget.lockId,
    );
    final list = (pwdData['list'] as List?) ?? [];
    if (!mounted) return;
    setState(() {
      _passcodes = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  Future<void> _reloadLockGateways() async {
    try {
      final data = await _api.listGatewaysByLock(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      final list = (data['list'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _lockGateways = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _lockGateways = []);
    }
  }

  Future<void> _reloadRecords() async {
    final data = await _api.listRecords(
      accessToken: widget.accessToken,
      lockId: widget.lockId,
      startDateMs: _recStart?.millisecondsSinceEpoch,
      endDateMs: _recEnd?.millisecondsSinceEpoch,
      pageSize: 50,
    );
    final list = (data['list'] as List?) ?? [];
    if (!mounted) return;
    setState(() {
      _records = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  Future<void> _reloadAccess() async {
    final results = await Future.wait([
      _api.listKeys(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      ),
      _api.listIdentityCards(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      ),
      _api.listFingerprints(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _ekeys = _mapList(results[0]['list']);
      _cards = _mapList(results[1]['list']);
      _fingerprints = _mapList(results[2]['list']);
    });
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    final list = (raw as List?) ?? [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Ημερομηνία',
      cancelText: 'Άκυρο',
      confirmText: 'OK',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Ώρα',
      cancelText: 'Άκυρο',
      confirmText: 'OK',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _toHour(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour);

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ναι'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _unlock() async {
    if (!_gatewayOk) {
      _snack('Χρειάζεται gateway / WiFi για remote unlock');
      return;
    }
    await _runBusy(() async {
      await _api.unlock(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      _snack('Unlock OK');
      await _reloadDetail();
    });
  }

  Future<void> _lockRemote() async {
    if (!_gatewayOk) {
      _snack('Χρειάζεται gateway / WiFi για remote lock');
      return;
    }
    await _runBusy(() async {
      await _api.lock(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      _snack('Lock OK');
      await _reloadDetail();
    });
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Μετονομασία alias'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'lockAlias',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Άκυρο'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Αποθήκευση'),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    await _runBusy(() async {
      await _api.renameLock(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
        lockAlias: next,
      );
      setState(() => _title = next);
      _snack('Alias ενημερώθηκε');
      await _reloadDetail();
    });
  }

  Future<void> _freeze(bool freeze) async {
    if (!_gatewayOk) {
      _snack('Χρειάζεται gateway για freeze/unfreeze');
      return;
    }
    final ok = await _confirm(
      freeze ? 'Freeze κλειδαριάς' : 'Unfreeze κλειδαριάς',
      freeze
          ? 'Όλες οι μέθοδοι ξεκλειδώματος θα απενεργοποιηθούν. Συνέχεια;'
          : 'Θα ξεπαγώσεις την κλειδαριά. Συνέχεια;',
    );
    if (!ok) return;
    if (freeze) {
      final ok2 = await _confirm(
        'Επιβεβαίωση',
        'Σίγουρα freeze; Είναι reversible μόνο με unfreeze.',
      );
      if (!ok2) return;
    }
    await _runBusy(() async {
      if (freeze) {
        await _api.freezeLock(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
        );
        _snack('Freeze OK');
      } else {
        await _api.unfreezeLock(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
        );
        _snack('Unfreeze OK');
      }
    });
  }

  Future<void> _createPasscode() async {
    final needsDates = _pwdType != 2 || _useCustom;
    if (needsDates && !_end.isAfter(_start)) {
      _snack('Η λήξη πρέπει να είναι μετά την έναρξη');
      return;
    }
    setState(() => _createdPwd = null);
    await _runBusy(() async {
      final start = _toHour(_start);
      final end = _toHour(_end);
      if (_useCustom) {
        var code = _customCodeCtrl.text.trim();
        if (code.isEmpty) {
          code = (10000 + Random.secure().nextInt(90000)).toString();
          _customCodeCtrl.text = code;
        }
        if (!_gatewayOk) {
          throw TtlockException('Custom κωδικός χρειάζεται gateway (addType=2)');
        }
        await _api.addCustomPasscode(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
          keyboardPwd: code,
          startDateMs: start.millisecondsSinceEpoch,
          endDateMs: end.millisecondsSinceEpoch,
          keyboardPwdName: _nameCtrl.text.trim(),
          keyboardPwdType: _pwdType == 2 ? 2 : 3,
        );
        setState(() => _createdPwd = code);
      } else {
        final data = await _api.createPasscode(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
          keyboardPwdType: _pwdType,
          startDateMs: start.millisecondsSinceEpoch,
          endDateMs: _pwdType == 2 ? null : end.millisecondsSinceEpoch,
          keyboardPwdName: _nameCtrl.text.trim(),
        );
        setState(() => _createdPwd = data['keyboardPwd']?.toString());
      }
      await _reloadPasscodes();
      if (_createdPwd != null) _snack('Κωδικός: $_createdPwd');
    });
  }

  Future<void> _deletePasscode(Map<String, dynamic> p) async {
    if (!_gatewayOk) {
      _snack('Διαγραφή via gateway χρειάζεται gateway');
      return;
    }
    final id = _asIntOrNull(p['keyboardPwdId']);
    if (id == null) {
      _snack('Λείπει keyboardPwdId');
      return;
    }
    final ok = await _confirm(
      'Διαγραφή κωδικού',
      'Διαγραφή ${p['keyboardPwd'] ?? id};',
    );
    if (!ok) return;
    await _runBusy(() async {
      await _api.deletePasscode(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
        keyboardPwdId: id,
      );
      _snack('Διαγράφηκε');
      await _reloadPasscodes();
    });
  }

  Future<void> _editPasscode(Map<String, dynamic> p) async {
    if (!_gatewayOk) {
      _snack('Αλλαγή via gateway χρειάζεται gateway');
      return;
    }
    final id = _asIntOrNull(p['keyboardPwdId']);
    if (id == null) {
      _snack('Λείπει keyboardPwdId');
      return;
    }
    final nameCtrl = TextEditingController(
      text: p['keyboardPwdName']?.toString() ?? '',
    );
    final codeCtrl = TextEditingController();
    var start = DateTime.fromMillisecondsSinceEpoch(
      _asIntOrNull(p['startDate']) ?? DateTime.now().millisecondsSinceEpoch,
    );
    var end = DateTime.fromMillisecondsSinceEpoch(
      _asIntOrNull(p['endDate']) ??
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Αλλαγή κωδικού'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Όνομα',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Νέος κωδικός (προαιρετικό)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Έναρξη'),
                      subtitle: Text(_fmt.format(start)),
                      onTap: () async {
                        final v = await _pickDateTime(start);
                        if (v != null) setLocal(() => start = v);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Λήξη'),
                      subtitle: Text(_fmt.format(end)),
                      onTap: () async {
                        final v = await _pickDateTime(end);
                        if (v != null) setLocal(() => end = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Άκυρο'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Αποθήκευση'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) return;
    await _runBusy(() async {
      await _api.changePasscode(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
        keyboardPwdId: id,
        keyboardPwdName: nameCtrl.text.trim(),
        newKeyboardPwd: codeCtrl.text.trim().isEmpty
            ? null
            : codeCtrl.text.trim(),
        startDateMs: _toHour(start).millisecondsSinceEpoch,
        endDateMs: _toHour(end).millisecondsSinceEpoch,
      );
      _snack('Κωδικός ενημερώθηκε');
      await _reloadPasscodes();
    });
  }

  Future<void> _sendEkey() async {
    final user = _ekeyUserCtrl.text.trim();
    final name = _ekeyNameCtrl.text.trim();
    if (user.isEmpty || name.isEmpty) {
      _snack('Συμπλήρωσε receiver + όνομα ekey');
      return;
    }
    if (!_ekeyEnd.isAfter(_ekeyStart) &&
        !(_ekeyStart.millisecondsSinceEpoch == 0 &&
            _ekeyEnd.millisecondsSinceEpoch == 0)) {
      // permanent = 0/0 allowed; otherwise end > start
    }
    await _runBusy(() async {
      await _api.sendKey(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
        receiverUsername: user,
        keyName: name,
        startDateMs: _ekeyStart.millisecondsSinceEpoch,
        endDateMs: _ekeyEnd.millisecondsSinceEpoch,
        remarks: _ekeyRemarksCtrl.text.trim(),
        remoteEnable: _ekeyRemote ? 1 : 2,
      );
      _snack('Ekey στάλθηκε');
      _ekeyUserCtrl.clear();
      await _reloadAccess();
    });
  }

  Future<void> _deleteEkey(Map<String, dynamic> k) async {
    final id = _asIntOrNull(k['keyId']);
    if (id == null) return;
    final ok = await _confirm(
      'Διαγραφή ekey',
      'Διαγραφή keyId=$id (${k['username'] ?? ''});\n'
      'ΠΡΟΣΟΧΗ: διαγραφή admin ekey σβήνει όλα τα ekeys/passcodes από τον server.',
    );
    if (!ok) return;
    await _runBusy(() async {
      await _api.deleteKey(accessToken: widget.accessToken, keyId: id);
      _snack('Ekey διαγράφηκε');
      await _reloadAccess();
    });
  }

  Future<void> _deleteCard(Map<String, dynamic> c) async {
    if (!_gatewayOk) {
      _snack('Διαγραφή IC card via gateway χρειάζεται gateway');
      return;
    }
    final id = _asIntOrNull(c['cardId']);
    if (id == null) return;
    final ok = await _confirm(
      'Διαγραφή IC card',
      'Διαγραφή ${c['cardNumber'] ?? id};',
    );
    if (!ok) return;
    await _runBusy(() async {
      await _api.deleteIdentityCard(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
        cardId: id,
      );
      _snack('IC card διαγράφηκε');
      await _reloadAccess();
    });
  }

  String _fmtMs(dynamic ms) {
    if (ms is! num) return '—';
    final v = ms.toInt();
    if (v <= 0) return 'μόνιμο / —';
    return _fmt.format(DateTime.fromMillisecondsSinceEpoch(v));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _customCodeCtrl.dispose();
    _ekeyUserCtrl.dispose();
    _ekeyNameCtrl.dispose();
    _ekeyRemarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Μετονομασία',
            onPressed: _busy ? null : _rename,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _loading || _busy ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Λεπτομέρειες'),
            Tab(text: 'Κωδικοί'),
            Tab(text: 'Records'),
            Tab(text: 'Access'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _detail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OpsErrorBanner(_error!),
                        const SizedBox(height: 16),
                        OpsPrimaryButton(label: 'Ξανά', onPressed: _loadAll),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    TabBarView(
                      controller: _tabs,
                      children: [
                        _buildDetailsTab(),
                        _buildPasscodesTab(),
                        _buildRecordsTab(),
                        _buildAccessTab(),
                      ],
                    ),
                    if (_busy)
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                  ],
                ),
    );
  }

  Widget _buildDetailsTab() {
    final stateLabel = TtlockApi.openStateLabel(_openState).toUpperCase();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OpsSectionHeader(
          eyebrow: 'Lock unit',
          title: 'Κατάσταση',
          subtitle: 'Remote ops via gateway / Wi‑Fi.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OpsStamp(
              stateLabel,
              color: _openState == 1 ? OpsColors.success : OpsColors.ink,
              bg: _openState == 1
                  ? const Color(0x1A3D7C2E)
                  : OpsColors.field,
            ),
            OpsStamp(
              'BAT ${_battery ?? '—'}%',
              color: opsBatteryColor(_battery),
            ),
            OpsStamp(
              _gatewayOk ? 'GATEWAY YES' : 'GATEWAY NO',
              color: _gatewayOk ? OpsColors.orangeDeep : OpsColors.muted,
              bg: _gatewayOk ? OpsColors.orangeWash : OpsColors.field,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_detail != null) ...[
          OpsPanel(
            child: Column(
              children: [
                _row('lockId', '${widget.lockId}'),
                _row('Όνομα', '${_detail!['lockName'] ?? '—'}'),
                _row('Alias', '${_detail!['lockAlias'] ?? '—'}'),
                _row('MAC', '${_detail!['lockMac'] ?? '—'}'),
                _row(
                  'Pwd ver',
                  '${_detail!['keyboardPwdVersion'] ?? '—'}',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        OpsPrimaryButton(
          label: !_gatewayOk ? 'Unlock (no GW)' : 'Unlock',
          onPressed: _busy || !_gatewayOk ? null : _unlock,
          busy: _busy,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy || !_gatewayOk ? null : _lockRemote,
            style: OutlinedButton.styleFrom(
              backgroundColor: OpsColors.darkPanel,
              foregroundColor: OpsColors.field,
              side: const BorderSide(color: OpsColors.ink, width: 2),
            ),
            child: Text(!_gatewayOk ? 'Lock (no GW)' : 'Lock'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy || !_gatewayOk ? null : () => _freeze(true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OpsColors.danger,
                  side: const BorderSide(color: OpsColors.danger, width: 2),
                ),
                child: const Text('Freeze'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy || !_gatewayOk ? null : () => _freeze(false),
                child: const Text('Unfreeze'),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        Text(
          'GATEWAYS ΚΛΕΙΔΑΡΙΑΣ (${_lockGateways.length})',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: OpsColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (_lockGateways.isEmpty)
          Text(
            'Δεν βρέθηκαν gateways για αυτή την κλειδαριά.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: OpsColors.muted,
            ),
          )
        else
          ..._lockGateways.map((g) {
            final rssi = _asIntOrNull(g['rssi']);
            String strength = '—';
            if (rssi != null) {
              if (rssi > -75) {
                strength = 'ισχυρό';
              } else if (rssi > -85) {
                strength = 'μέτριο';
              } else {
                strength = 'αδύναμο';
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gateway ${g['gatewayId']}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'mac=${g['gatewayMac'] ?? '—'} · rssi=${rssi ?? '—'} ($strength)',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: OpsColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPasscodesTab() {
    final needsEnd = _pwdType != 2 || _useCustom;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OpsSectionHeader(
          eyebrow: 'Keyboard',
          title: 'Νέος κωδικός',
        ),
        const SizedBox(height: 16),
        const OpsFieldLabel('Τύπος'),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _pwdType,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 1, child: Text('One-time (1)')),
            DropdownMenuItem(value: 2, child: Text('Permanent (2)')),
            DropdownMenuItem(value: 3, child: Text('Period (3)')),
            DropdownMenuItem(value: 5, child: Text('Weekend cyclic (5)')),
            DropdownMenuItem(value: 6, child: Text('Daily cyclic (6)')),
            DropdownMenuItem(value: 7, child: Text('Workday cyclic (7)')),
            DropdownMenuItem(value: 8, child: Text('Monday cyclic (8)')),
            DropdownMenuItem(value: 9, child: Text('Tuesday cyclic (9)')),
            DropdownMenuItem(value: 10, child: Text('Wednesday cyclic (10)')),
            DropdownMenuItem(value: 11, child: Text('Thursday cyclic (11)')),
            DropdownMenuItem(value: 12, child: Text('Friday cyclic (12)')),
            DropdownMenuItem(value: 13, child: Text('Saturday cyclic (13)')),
            DropdownMenuItem(value: 14, child: Text('Sunday cyclic (14)')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _pwdType = v);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Custom 5ψήφιο (gateway)',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          value: _useCustom,
          onChanged: (v) => setState(() => _useCustom = v),
        ),
        const OpsFieldLabel('Όνομα (προαιρετικό)'),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_useCustom) ...[
          const SizedBox(height: 12),
          const OpsFieldLabel('Κωδικός (κενό = τυχαίος 5ψήφιος)'),
          TextField(
            controller: _customCodeCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Έναρξη'),
          subtitle: Text(_fmt.format(_start)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final v = await _pickDateTime(_start);
            if (v != null) setState(() => _start = v);
          },
        ),
        if (needsEnd)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Λήξη'),
            subtitle: Text(_fmt.format(_end)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final v = await _pickDateTime(_end);
              if (v != null) setState(() => _end = v);
            },
          ),
        OpsPrimaryButton(
          label: 'Δημιούργησε κωδικό',
          onPressed: _busy ? null : _createPasscode,
          busy: _busy,
        ),
        if (_createdPwd != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OpsColors.darkPanel,
              border: Border.all(color: OpsColors.orange, width: 2),
            ),
            child: SelectableText(
              'ΚΩΔΙΚΟΣ: $_createdPwd',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: OpsColors.field,
              ),
            ),
          ),
        ],
        const Divider(height: 32),
        Text(
          'ΚΩΔΙΚΟΙ (${_passcodes.length})',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_passcodes.isEmpty)
          Text(
            'Δεν υπάρχουν κωδικοί ακόμη.',
            style: GoogleFonts.ibmPlexSans(color: OpsColors.muted),
          )
        else
          ..._passcodes.map((p) {
            final name = p['keyboardPwdName']?.toString();
            final code = p['keyboardPwd']?.toString() ?? '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (name != null && name.isNotEmpty) ? name : code,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'κωδικός: $code\n'
                            '${_fmtMs(p['startDate'])} → ${_fmtMs(p['endDate'])}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: OpsColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Επεξεργασία',
                      onPressed: _busy ? null : () => _editPasscode(p),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Διαγραφή',
                      onPressed: _busy ? null : () => _deletePasscode(p),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecordsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OpsSectionHeader(
          eyebrow: 'Audit',
          title: 'Records',
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Από'),
          subtitle: Text(
            _recStart == null ? '—' : _fmt.format(_recStart!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final v = await _pickDateTime(_recStart ?? DateTime.now());
            if (v != null) setState(() => _recStart = v);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Έως'),
          subtitle: Text(_recEnd == null ? '—' : _fmt.format(_recEnd!)),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final v = await _pickDateTime(_recEnd ?? DateTime.now());
            if (v != null) setState(() => _recEnd = v);
          },
        ),
        OpsPrimaryButton(
          label: 'Φόρτωση records',
          onPressed: _busy
              ? null
              : () => _runBusy(() async {
                    await _reloadRecords();
                    _snack('Records: ${_records.length}');
                  }),
          busy: _busy,
        ),
        const Divider(height: 32),
        Text(
          'RECORDS (${_records.length})',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_records.isEmpty)
          Text(
            'Δεν βρέθηκαν records.',
            style: GoogleFonts.ibmPlexSans(color: OpsColors.muted),
          )
        else
          ..._records.map((r) {
            final type = _asIntOrNull(r['recordType']);
            final ok = r['success'] == 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 4),
                      color: ok ? OpsColors.success : OpsColors.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            TtlockApi.recordTypeLabel(type),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmtMs(r['lockDate'] ?? r['serverDate'])}\n'
                            'user=${r['username'] ?? '—'} · '
                            'pwd/card=${r['keyboardPwd'] ?? '—'}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: OpsColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAccessTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const OpsSectionHeader(
          eyebrow: 'Access',
          title: 'Αποστολή ekey',
        ),
        const SizedBox(height: 16),
        const OpsFieldLabel('Receiver username (email/mobile)'),
        TextField(
          controller: _ekeyUserCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autocorrect: false,
        ),
        const SizedBox(height: 12),
        const OpsFieldLabel('Όνομα ekey'),
        TextField(
          controller: _ekeyNameCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        const OpsFieldLabel('Σχόλιο (προαιρετικό)'),
        TextField(
          controller: _ekeyRemarksCtrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Remote unlock enabled',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          value: _ekeyRemote,
          onChanged: (v) => setState(() => _ekeyRemote = v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Έναρξη (0 = μόνιμο αν και λήξη 0)'),
          subtitle: Text(_fmt.format(_ekeyStart)),
          onTap: () async {
            final v = await _pickDateTime(_ekeyStart);
            if (v != null) setState(() => _ekeyStart = v);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Λήξη'),
          subtitle: Text(_fmt.format(_ekeyEnd)),
          onTap: () async {
            final v = await _pickDateTime(_ekeyEnd);
            if (v != null) setState(() => _ekeyEnd = v);
          },
        ),
        TextButton(
          onPressed: () => setState(() {
            _ekeyStart = DateTime.fromMillisecondsSinceEpoch(0);
            _ekeyEnd = DateTime.fromMillisecondsSinceEpoch(0);
          }),
          child: const Text('Μόνιμο ekey (start/end = 0)'),
        ),
        OpsPrimaryButton(
          label: 'Αποστολή ekey',
          onPressed: _busy ? null : _sendEkey,
          busy: _busy,
        ),
        const Divider(height: 32),
        Text(
          'EKEYS (${_ekeys.length})',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_ekeys.isEmpty)
          Text(
            'Δεν υπάρχουν ekeys.',
            style: GoogleFonts.ibmPlexSans(color: OpsColors.muted),
          )
        else
          ..._ekeys.map((k) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['keyName']?.toString() ?? 'key ${k['keyId']}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'user=${k['username'] ?? '—'} · status=${k['keyStatus'] ?? '—'}\n'
                            '${_fmtMs(k['startDate'])} → ${_fmtMs(k['endDate'])}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: OpsColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _deleteEkey(k),
                    ),
                  ],
                ),
              ),
            );
          }),
        const Divider(height: 32),
        Text(
          'IC CARDS (${_cards.length})',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_cards.isEmpty)
          Text(
            'Δεν υπάρχουν IC cards.',
            style: GoogleFonts.ibmPlexSans(color: OpsColors.muted),
          )
        else
          ..._cards.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['cardName']?.toString().isNotEmpty == true
                                ? c['cardName'].toString()
                                : (c['cardNumber']?.toString() ??
                                    'card ${c['cardId']}'),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'number=${c['cardNumber'] ?? '—'} · status=${c['status'] ?? '—'}\n'
                            '${_fmtMs(c['startDate'])} → ${_fmtMs(c['endDate'])}',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 11,
                              color: OpsColors.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy ? null : () => _deleteCard(c),
                    ),
                  ],
                ),
              ),
            );
          }),
        const Divider(height: 32),
        Row(
          children: [
            Text(
              'FINGERPRINTS (${_fingerprints.length})',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const OpsStamp('READ-ONLY', color: OpsColors.muted),
          ],
        ),
        const SizedBox(height: 8),
        if (_fingerprints.isEmpty)
          Text(
            'Δεν υπάρχουν fingerprints.',
            style: GoogleFonts.ibmPlexSans(color: OpsColors.muted),
          )
        else
          ..._fingerprints.map((f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OpsPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['fingerprintName']?.toString().isNotEmpty == true
                          ? f['fingerprintName'].toString()
                          : 'fp ${f['fingerprintId']}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'number=${f['fingerprintNumber'] ?? '—'} · '
                      'status=${f['status'] ?? '—'}\n'
                      '${_fmtMs(f['startDate'])} → ${_fmtMs(f['endDate'])}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 11,
                        color: OpsColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: OpsColors.muted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OpsColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
