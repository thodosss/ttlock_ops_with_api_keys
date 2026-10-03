import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ops_theme.dart';

class OpsSectionHeader extends StatelessWidget {
  const OpsSectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: OpsColors.orangeDeep,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: OpsColors.ink,
            height: 1.25,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: OpsColors.muted,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class OpsStamp extends StatelessWidget {
  const OpsStamp(
    this.label, {
    super.key,
    this.color = OpsColors.ink,
    this.bg = OpsColors.field,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: OpsColors.ink, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.25,
        ),
      ),
    );
  }
}

class OpsPrimaryButton extends StatelessWidget {
  const OpsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Material(
      color: enabled ? OpsColors.orange : OpsColors.line,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: OpsColors.ink, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: busy
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: OpsColors.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: OpsColors.ink,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: enabled ? OpsColors.ink : OpsColors.muted,
                        ),
                      ),
              ),
              CustomPaint(
                size: const Size(24, 28),
                painter: _HazardStripePainter(
                  color: enabled ? OpsColors.ink : OpsColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  _HazardStripePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    for (var i = -1; i < 4; i++) {
      final x = i * 8.0;
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HazardStripePainter oldDelegate) =>
      oldDelegate.color != color;
}

class OpsNote extends StatelessWidget {
  const OpsNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 2, height: 32, color: OpsColors.ink),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: OpsColors.muted,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class OpsErrorBanner extends StatelessWidget {
  const OpsErrorBanner(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AE10600),
        border: Border.all(color: OpsColors.danger, width: 2),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OpsColors.danger,
        ),
      ),
    );
  }
}

class OpsPanel extends StatelessWidget {
  const OpsPanel({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: OpsColors.field,
        border: Border.all(color: OpsColors.ink, width: 1),
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: body),
    );
  }
}

class OpsConnectedStrip extends StatelessWidget {
  const OpsConnectedStrip({
    super.key,
    required this.baseUrl,
    required this.clientId,
  });

  final String baseUrl;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OpsColors.orangeWash,
        border: Border.all(color: OpsColors.ink, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONNECTED',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: OpsColors.orangeDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            baseUrl,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OpsColors.ink,
            ),
          ),
          Text(
            'clientId: $clientId',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              color: OpsColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class OpsFieldLabel extends StatelessWidget {
  const OpsFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: OpsColors.muted,
        ),
      ),
    );
  }
}

Color opsBatteryColor(num? bat) {
  if (bat == null) return OpsColors.muted;
  if (bat < 20) return OpsColors.danger;
  if (bat < 40) return OpsColors.warn;
  return OpsColors.success;
}
