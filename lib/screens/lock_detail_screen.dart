import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../ttlock_api.dart';

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

class _LockDetailScreenState extends State<LockDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _customCodeCtrl = TextEditingController();
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _loading = true;
  bool _unlocking = false;
  bool _creating = false;
  String? _error;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _passcodes = [];
  String? _createdPwd;
  bool _useCustom = false;

  late DateTime _start;
  late DateTime _end;

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
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour);
    _end = _start.add(const Duration(days: 1));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _api.lockDetail(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      final pwdData = await _api.listPasscodes(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      final list = (pwdData['list'] as List?) ?? [];
      setState(() {
        _detail = detail;
        _passcodes = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlock() async {
    if (!_gatewayOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Χρειάζεται σύνδεση gateway / WiFi για remote unlock'),
        ),
      );
      return;
    }
    setState(() => _unlocking = true);
    try {
      await _api.unlock(
        accessToken: widget.accessToken,
        lockId: widget.lockId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unlock OK')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _unlocking = false);
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

  Future<void> _createPasscode() async {
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Η λήξη πρέπει να είναι μετά την έναρξη')),
      );
      return;
    }

    setState(() {
      _creating = true;
      _createdPwd = null;
    });

    try {
      final start = _toHour(_start);
      final end = _toHour(_end);
      if (_useCustom) {
        var code = _customCodeCtrl.text.trim();
        if (code.isEmpty) {
          code = (10000 + Random.secure().nextInt(90000)).toString();
          _customCodeCtrl.text = code;
        }
        if (!_gatewayOk) {
          throw TtlockException(
            'Custom κωδικός χρειάζεται gateway (addType=2)',
          );
        }
        await _api.addCustomPasscode(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
          keyboardPwd: code,
          startDateMs: start.millisecondsSinceEpoch,
          endDateMs: end.millisecondsSinceEpoch,
          keyboardPwdName: _nameCtrl.text.trim(),
        );
        setState(() => _createdPwd = code);
      } else {
        final data = await _api.createPeriodPasscode(
          accessToken: widget.accessToken,
          lockId: widget.lockId,
          startDateMs: start.millisecondsSinceEpoch,
          endDateMs: end.millisecondsSinceEpoch,
          keyboardPwdName: _nameCtrl.text.trim(),
        );
        setState(() => _createdPwd = data['keyboardPwd']?.toString());
      }
      await _load();
      if (mounted && _createdPwd != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Κωδικός: $_createdPwd')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  String _fmtMs(dynamic ms) {
    if (ms is! num) return '—';
    final v = ms.toInt();
    if (v <= 0) return '—';
    return _fmt.format(DateTime.fromMillisecondsSinceEpoch(v));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Ξανά')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Λεπτομέρειες',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_detail != null) ...[
                      _row('lockId', '${widget.lockId}'),
                      _row('Όνομα', '${_detail!['lockName'] ?? '—'}'),
                      _row('Alias', '${_detail!['lockAlias'] ?? '—'}'),
                      _row('MAC', '${_detail!['lockMac'] ?? '—'}'),
                      _row(
                        'Μπαταρία',
                        '${_detail!['electricQuantity'] ?? '—'}%',
                      ),
                      _row('Gateway', _gatewayOk ? 'ναι' : 'όχι'),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _unlocking || !_gatewayOk ? null : _unlock,
                      icon: _unlocking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open),
                      label: Text(
                        !_gatewayOk
                            ? 'Unlock (χωρίς gateway)'
                            : (_unlocking ? 'Unlock…' : 'Remote unlock'),
                      ),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Νέος κωδικός',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Επίλεξε έναρξη/λήξη με datepicker (period).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Custom 5ψήφιο (gateway)'),
                      value: _useCustom,
                      onChanged: (v) => setState(() => _useCustom = v),
                    ),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Όνομα (προαιρετικό)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_useCustom) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Κωδικός (κενό = τυχαίος 5ψήφιος)',
                          border: OutlineInputBorder(),
                        ),
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
                    FilledButton.icon(
                      onPressed: _creating ? null : _createPasscode,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.vpn_key),
                      label: Text(
                        _creating ? 'Δημιουργία…' : 'Δημιούργησε κωδικό',
                      ),
                    ),
                    if (_createdPwd != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            'Κωδικός: $_createdPwd',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    Text(
                      'Κωδικοί (${_passcodes.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_passcodes.isEmpty)
                      const Text('Δεν υπάρχουν κωδικοί ακόμη.')
                    else
                      ..._passcodes.map((p) {
                        final name = p['keyboardPwdName']?.toString();
                        final code = p['keyboardPwd']?.toString() ?? '—';
                        return Card(
                          child: ListTile(
                            title: Text(
                              (name != null && name.isNotEmpty) ? name : code,
                            ),
                            subtitle: Text(
                              'κωδικός: $code\n'
                              '${_fmtMs(p['startDate'])} → ${_fmtMs(p['endDate'])}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }),
                  ],
                ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
