import 'package:flutter/material.dart';

import '../../core/models/enums.dart';

/// Status badge with the verification-hierarchy colors (mobile-ui REQ-7).
class StatusBadge extends StatelessWidget {
  final ClaimStatus status;
  final bool small;

  const StatusBadge(this.status, {super.key, this.small = false});

  static Color colorFor(ClaimStatus status) => switch (status) {
        ClaimStatus.unverified => const Color(0xFFB26A00), // amber
        ClaimStatus.supported => const Color(0xFF1565C0), // blue
        ClaimStatus.crossChecked => const Color(0xFF6A1B9A), // purple
        ClaimStatus.humanVerified => const Color(0xFF2E7D32), // green
        ClaimStatus.contradicted => const Color(0xFFC62828), // red
        ClaimStatus.deprecated => const Color(0xFF616161), // grey
      };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
