import 'package:flutter/material.dart';

import '../ttlock_api.dart';

class GatewaysScreen extends StatefulWidget {
  const GatewaysScreen({
    super.key,
    required this.baseUrl,
    required this.clientId,
    required this.accessToken,
  });

  final String baseUrl;
  final String clientId;
  final String accessToken;

  @override
  State<GatewaysScreen> createState() => _GatewaysScreenState();
}

class _GatewaysScreenState extends State<GatewaysScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _gateways = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = TtlockApi(baseUrl: widget.baseUrl, clientId: widget.clientId);
      final data = await api.listGateways(accessToken: widget.accessToken);
      final list = (data['list'] as List?) ?? [];
      setState(() {
        _gateways = list
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gateways'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
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
              : _gateways.isEmpty
                  ? const Center(child: Text('Δεν βρέθηκαν gateways'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _gateways.length,
                      itemBuilder: (context, i) {
                        final g = _gateways[i];
                        final online = g['isOnline'] == 1;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.router,
                              color: online ? Colors.green : Colors.grey,
                            ),
                            title: Text(
                              g['gatewayName']?.toString() ??
                                  'Gateway ${g['gatewayId']}',
                            ),
                            subtitle: Text(
                              'id=${g['gatewayId']} · mac=${g['gatewayMac'] ?? '—'}\n'
                              'locks=${g['lockNum'] ?? '—'} · '
                              'online=${online ? 'ναι' : 'όχι'} · '
                              'net=${g['networkName'] ?? '—'}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}
