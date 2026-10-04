import "package:flutter/material.dart";

import "../../core/motion/motion.dart";
import "../../core/theme/app_colors.dart";

/// Tombol ikon favorit dengan animasi pop.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 24,
  });

  final bool isFavorite;
  final ValueChanged<bool> onToggle;
  final double size;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _fav;

  @override
  void initState() {
    super.initState();
    _fav = widget.isFavorite;
  }

  @override
  void didUpdateWidget(FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _fav = widget.isFavorite;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      label: _fav ? "Hapus dari favorit" : "Tambah ke favorit",
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: AnimatedSwitcher(
          duration: Motion.micro,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(
            _fav ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(_fav),
            color: _fav ? c.heart : c.ink.withOpacity(0.4),
            size: widget.size,
          ),
        ),
        onPressed: () {
          setState(() => _fav = !_fav);
          widget.onToggle(_fav);
        },
      ),
    );
  }
}
