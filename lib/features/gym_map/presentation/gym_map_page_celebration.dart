part of 'gym_map_page.dart';

class _ContributionCelebrationOverlay extends StatelessWidget {
  const _ContributionCelebrationOverlay({super.key});

  static const List<_CelebrationParticleData> _particles =
      <_CelebrationParticleData>[
        _CelebrationParticleData(
          end: Offset(-72, -94),
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFFFC94A),
          size: 18,
        ),
        _CelebrationParticleData(
          end: Offset(-44, -112),
          icon: Icons.circle,
          color: Color(0xFF93B4D9),
          size: 8,
        ),
        _CelebrationParticleData(
          end: Offset(-16, -126),
          icon: Icons.bolt_rounded,
          color: Color(0xFF4A7DBA),
          size: 16,
        ),
        _CelebrationParticleData(
          end: Offset(12, -128),
          icon: Icons.star_rounded,
          color: Color(0xFFFFB74D),
          size: 15,
        ),
        _CelebrationParticleData(
          end: Offset(40, -116),
          icon: Icons.circle,
          color: Color(0xFF6A9ACF),
          size: 9,
        ),
        _CelebrationParticleData(
          end: Offset(68, -96),
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFE09F3E),
          size: 18,
        ),
        _CelebrationParticleData(
          end: Offset(-84, -64),
          icon: Icons.favorite_rounded,
          color: Color(0xFFCC4A37),
          size: 14,
        ),
        _CelebrationParticleData(
          end: Offset(82, -66),
          icon: Icons.favorite_rounded,
          color: Color(0xFFCC4A37),
          size: 14,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final fadeOut = (1 - t).clamp(0.0, 1.0).toDouble();
        final pulse = (1 - (t - 0.35).abs().clamp(0.0, 1.0)).toDouble();
        return Opacity(
          opacity: fadeOut,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 86),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54 + (t * 14),
                    height: 54 + (t * 14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: withUiOpacity(GymMapColors.occupancyLow, 0.15),
                    ),
                  ),
                  for (var i = 0; i < _particles.length; i++)
                    _CelebrationParticle(
                      data: _particles[i],
                      progress: t,
                      spinDirection: i.isEven ? 1 : -1,
                    ),
                  Transform.scale(
                    scale: 0.9 + (0.2 * pulse),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: withUiOpacity(Colors.white, 0.96),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 3),
                            color: GymMapColors.cardShadow,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.celebration_rounded,
                        color: GymMapColors.occupancyLow,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CelebrationParticleData {
  const _CelebrationParticleData({
    required this.end,
    required this.icon,
    required this.color,
    required this.size,
  });

  final Offset end;
  final IconData icon;
  final Color color;
  final double size;
}

class _CelebrationParticle extends StatelessWidget {
  const _CelebrationParticle({
    required this.data,
    required this.progress,
    required this.spinDirection,
  });

  final _CelebrationParticleData data;
  final double progress;
  final int spinDirection;

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress);
    final drift = Offset(data.end.dx * eased, data.end.dy * eased);
    final scale = 0.7 + (0.5 * (1 - progress));
    final angle = progress * spinDirection * 1.3;

    return Transform.translate(
      offset: drift,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            data.icon,
            size: data.size,
            color: withUiOpacity(data.color, 0.92),
          ),
        ),
      ),
    );
  }
}
