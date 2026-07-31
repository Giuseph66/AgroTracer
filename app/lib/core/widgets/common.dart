import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models.dart';
import '../theme/tokens.dart';

final hourFmt = DateFormat('HH:mm');
final dayFmt = DateFormat('dd/MM');
final dayHourFmt = DateFormat('dd/MM · HH:mm');

/// Selo de estado de sincronização — presente em toda lista de eventos:
/// offline-first significa que o estado do dado é informação de primeira classe.
class SyncBadge extends StatelessWidget {
  const SyncBadge(this.state, {super.key, this.compact = false});

  final SyncState state;
  final bool compact;

  ({Color fg, Color bg, IconData icon}) get _style => switch (state) {
        SyncState.localDraft => (
            fg: TaColors.inkSoft,
            bg: TaColors.paperDim,
            icon: Icons.edit_outlined
          ),
        SyncState.pendingSync => (
            fg: TaColors.tagYellowDeep,
            bg: Color(0xFFFBF0CE),
            icon: Icons.schedule
          ),
        SyncState.syncing => (
            fg: TaColors.sky,
            bg: TaColors.skyBg,
            icon: Icons.sync
          ),
        SyncState.acceptedByApi || SyncState.pendingBlockchain => (
            fg: TaColors.sage,
            bg: TaColors.sageBg,
            icon: Icons.check
          ),
        SyncState.confirmedOnBlockchain => (
            fg: TaColors.sage,
            bg: TaColors.sageBg,
            icon: Icons.verified_outlined
          ),
        SyncState.rejectedByApi || SyncState.conflict => (
            fg: TaColors.clay,
            bg: TaColors.clayBg,
            icon: Icons.priority_high
          ),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 14, color: s.fg),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              state.label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: s.fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rótulo de seção em caixa alta ("eyebrow").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.onDark = false});
  final String text;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: onDark ? TaColors.paperInkSoft : TaColors.inkSoft,
          ),
    );
  }
}

/// Cartão padrão do app.
class TaCard extends StatelessWidget {
  const TaCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(TaSpace.md),
      decoration: const BoxDecoration(
        color: TaColors.paper,
        borderRadius: BorderRadius.all(TaRadius.rLg),
        border: Border.fromBorderSide(BorderSide(color: TaColors.line)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(TaRadius.rLg),
      child: card,
    );
  }
}

/// Pílula de conectividade — offline não é erro, é modo de operação.
class ConnectivityPill extends StatelessWidget {
  const ConnectivityPill({super.key, required this.online, required this.pending});
  final bool online;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final label = online ? 'Online' : 'Offline · $pending na fila';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? const Color(0xFF8FD14F) : TaColors.tagYellow,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: TaColors.paperInk, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
