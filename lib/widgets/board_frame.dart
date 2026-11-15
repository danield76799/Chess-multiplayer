import 'package:flutter/material.dart';
import '../theme.dart';

/// Lichaam van het schaakbord: subtiel verloop met gouden rand en diepe
/// schaduw, zodat het bord als een fysiek speelbord overkomt.
class BoardFrame extends StatelessWidget {
  final Widget child;

  const BoardFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2E1B), Color(0xFF241C10)],
        ),
        border: Border.all(color: ChessTheme.goldDark, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}

/// Afgeronde statuspil boven het bord (wie is aan zet / remise e.d.).
class StatusPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? trailing;

  const StatusPill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ChessTheme.surfaceHigh.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ChessTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ChessTheme.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
