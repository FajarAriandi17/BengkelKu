// SOS UI Components - sesuai PRD v1.3 Section 3.9 & 3.10

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/motion/motion.dart';

/// SosButton - Tombol darurat dengan pulse animation
class SosButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool reduceMotion;

  const SosButton({
    super.key,
    required this.onTap,
    this.reduceMotion = false,
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (!widget.reduceMotion) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTapDown: (_) {
        if (!widget.reduceMotion) {
          setState(() {});
        }
      },
      onTapUp: (_) {
        widget.onTap();
      },
      onTapCancel: () {
        if (!widget.reduceMotion) {
          setState(() {});
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.reduceMotion ? 1.0 : _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.warnC,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: colors.warnC.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFF1B1200),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Motor mogok?',
                    style: TextStyle(
                      color: Color(0xFF1B1200),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
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

/// RadarPulse - Animasi radar mencari bengkel
class RadarPulse extends StatefulWidget {
  final List<MapEntry<double, double>> workshopPositions; // angle, distance
  final bool reduceMotion;

  const RadarPulse({
    super.key,
    this.workshopPositions = const [],
    this.reduceMotion = false,
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    if (!widget.reduceMotion) {
      _animateDots();
    }
  }

  void _animateDots() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      _dotsController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final size = 240.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar rings
          if (!widget.reduceMotion)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final delay = index * 0.33;
                  final progress = (_pulseController.value - delay) % 1.0;

                  return Opacity(
                    opacity: progress < 0 ? 0 : (1 - progress) * 0.7,
                    child: Transform.scale(
                      scale: 0.3 + (progress * 0.7),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.blue,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Core
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 34,
            ),
          ),

          // Workshop dots
          ...widget.workshopPositions.asMap().entries.map((entry) {
            final index = entry.key;
            final position = entry.value;
            final angle = position.key;
            final distance = position.value;

            final x = math.cos(angle) * distance;
            final y = math.sin(angle) * distance;

            return AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                final delay = index * 0.15;
                final progress = (_dotsController.value - delay).clamp(0.0, 1.0);

                return Positioned(
                  left: size / 2 + x - 7,
                  top: size / 2 + y - 7,
                  child: Transform.scale(
                    scale: widget.reduceMotion ? 1.0 : progress,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors.okC,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.okC.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

/// WaveProgress - Indikator gelombang pencarian
class WaveProgress extends StatelessWidget {
  final int currentWave;
  final int totalWaves;

  const WaveProgress({
    super.key,
    required this.currentWave,
    this.totalWaves = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: List.generate(totalWaves, (index) {
        final wave = index + 1;
        final isActive = wave <= currentWave;
        final isCurrent = wave == currentWave;

        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: index < totalWaves - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: isActive ? colors.blue : colors.line,
              borderRadius: BorderRadius.circular(9),
            ),
            child: isCurrent
                ? _AnimatedFill(color: colors.blue)
                : null,
          ),
        );
      }),
    );
  }
}

class _AnimatedFill extends StatefulWidget {
  final Color color;

  const _AnimatedFill({required this.color});

  @override
  State<_AnimatedFill> createState() => _AnimatedFillState();
}

class _AnimatedFillState extends State<_AnimatedFill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [_controller.value - 0.5, _controller.value],
              colors: [widget.color, widget.color.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(9),
          ),
        );
      },
    );
  }
}

/// MechanicCard - Kartu info mekanik
class MechanicCard extends StatelessWidget {
  final String name;
  final String workshopName;
  final String? photo;
  final String plate;
  final double rating;

  const MechanicCard({
    super.key,
    required this.name,
    required this.workshopName,
    this.photo,
    required this.plate,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 24,
          backgroundColor: colors.blueSoft,
          backgroundImage: photo != null ? NetworkImage(photo!) : null,
          child: photo == null
              ? Text(
                  name.substring(0, 2).toUpperCase(),
                  style: TextStyle(
                    color: colors.blueText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name · $workshopName',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    plate,
                    style: TextStyle(
                      color: colors.ink2,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.star,
                    size: 14,
                    color: colors.warnC,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      color: colors.ink2,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// EtaPill - Pill estimasi waktu tiba
class EtaPill extends StatelessWidget {
  final int minutes;
  final double distanceKm;

  const EtaPill({
    super.key,
    required this.minutes,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'Tiba ±$minutes menit · ${distanceKm.toStringAsFixed(1)} km',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// ArrivalCodeCard - Kartu kode 4 digit
class ArrivalCodeCard extends StatelessWidget {
  final String code;
  final bool reduceMotion;

  const ArrivalCodeCard({
    super.key,
    required this.code,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final digits = code.split('');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kode kedatangan',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sebutkan saat mekanik tiba',
                style: TextStyle(
                  color: colors.ink2,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: digits.asMap().entries.map((entry) {
              final index = entry.key;
              final digit = entry.value;

              return TweenAnimationBuilder<double>(
                duration: reduceMotion
                    ? const Duration(milliseconds: 100)
                    : const Duration(milliseconds: 400),
                curve: Motion.spring,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  final delay = index * 0.08;
                  final progress = (value - delay).clamp(0.0, 1.0);

                  return Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * progress),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 42,
                  margin: EdgeInsets.only(left: index > 0 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: colors.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      digit,
                      style: TextStyle(
                        color: colors.blueText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// FeeBreakdown - Rincian biaya SOS
class FeeBreakdown extends StatelessWidget {
  final int callFee;
  final int nightFee;
  final int serviceFee;
  final String tierLabel;

  const FeeBreakdown({
    super.key,
    required this.callFee,
    required this.nightFee,
    required this.serviceFee,
    required this.tierLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final total = callFee + nightFee + serviceFee;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.panel,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _FeeRow(
            label: 'Biaya panggilan ($tierLabel)',
            amount: callFee,
            isMuted: false,
          ),
          if (nightFee > 0) ...[
            const SizedBox(height: 6),
            _FeeRow(
              label: 'Biaya malam',
              amount: nightFee,
              isMuted: false,
            ),
          ],
          if (serviceFee > 0) ...[
            const SizedBox(height: 6),
            _FeeRow(
              label: 'Biaya layanan',
              amount: serviceFee,
              isMuted: false,
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Container(
              height: 1,
              color: colors.line,
            ),
          ),
          const SizedBox(height: 9),
          _FeeRow(
            label: 'Total',
            amount: total,
            isMuted: false,
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final int amount;
  final bool isMuted;
  final bool isTotal;

  const _FeeRow({
    required this.label,
    required this.amount,
    this.isMuted = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isMuted ? colors.ink2 : colors.ink,
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          'Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
          style: TextStyle(
            color: isTotal ? colors.blueText : colors.ink,
            fontSize: isTotal ? 15 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
