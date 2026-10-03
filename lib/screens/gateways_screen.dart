import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ops_theme.dart';
import '../ttlock_api.dart';
import '../widgets/ops_ui.dart';

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
                        OpsErrorBanner(_error!),
                        const SizedBox(height: 16),
                        OpsPrimaryButton(label: 'Ξανά', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : _gateways.isEmpty
                  ? Center(
                      child: Text(
                        'Δεν βρέθηκαν gateways',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OpsColors.muted,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _gateways.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: OpsSectionHeader(
                              eyebrow: 'Network',
                              title: 'Gateways',
                              subtitle: 'Online status & bound locks.',
                            ),
                          );
                        }
                        final g = _gateways[i - 1];
                        final online = g['isOnline'] == 1;
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
                                  color: online
                                      ? OpsColors.orange
                                      : OpsColors.muted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g['gatewayName']?.toString() ??
                                            'Gateway ${g['gatewayId']}',
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: OpsColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'id=${g['gatewayId']} · mac=${g['gatewayMac'] ?? '—'}',
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
                                            online ? 'ONLINE' : 'OFFLINE',
                                            color: online
                                                ? OpsColors.orangeDeep
                                                : OpsColors.muted,
                                            bg: online
                                                ? OpsColors.orangeWash
                                                : OpsColors.field,
                                          ),
                                          OpsStamp(
                                            'LOCKS ${g['lockNum'] ?? '—'}',
                                          ),
                                          OpsStamp(
                                            'NET ${g['networkName'] ?? '—'}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
