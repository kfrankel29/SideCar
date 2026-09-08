import 'package:flutter/material.dart';
import 'package:sidecar/src/theme/app_theme.dart';

enum FinalDraftIconKind { home, search, post, rides, messages, profile }

enum FinalDraftChevronDirection { left, up, right, down }

class FinalDraftIcon extends StatelessWidget {
  const FinalDraftIcon({
    required this.kind,
    required this.selected,
    super.key,
    this.size = 25,
    this.color,
  });

  final FinalDraftIconKind kind;
  final bool selected;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        color ?? (selected ? AppColors.primary : const Color(0xFFB5B5BA)),
        BlendMode.srcIn,
      ),
      child: Image.asset(
        _assetPath,
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }

  String get _assetPath => switch (kind) {
    FinalDraftIconKind.home => 'assets/icons/tabs/home.png',
    FinalDraftIconKind.search => 'assets/icons/tabs/search.png',
    FinalDraftIconKind.post => 'assets/icons/tabs/post.png',
    FinalDraftIconKind.rides => 'assets/icons/tabs/rides.png',
    FinalDraftIconKind.messages => 'assets/icons/tabs/messages.png',
    FinalDraftIconKind.profile => 'assets/icons/tabs/profile.png',
  };
}

class FinalDraftBackIcon extends StatelessWidget {
  const FinalDraftBackIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/icons/figma/back.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
  );
}

class FinalDraftChevronIcon extends StatelessWidget {
  const FinalDraftChevronIcon({
    super.key,
    this.direction = FinalDraftChevronDirection.right,
    this.size = 18,
    this.color,
  });

  final FinalDraftChevronDirection direction;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = Image.asset(
      'assets/icons/figma/back.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    final filtered = color == null
        ? icon
        : ColorFiltered(
            colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
            child: icon,
          );
    return RotatedBox(quarterTurns: _turns, child: filtered);
  }

  int get _turns => switch (direction) {
    FinalDraftChevronDirection.left => 0,
    FinalDraftChevronDirection.up => 1,
    FinalDraftChevronDirection.right => 2,
    FinalDraftChevronDirection.down => 3,
  };
}

class FinalDraftAssetIcon extends StatelessWidget {
  const FinalDraftAssetIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      name == 'search'
          ? 'assets/icons/tabs/search.png'
          : 'assets/icons/figma/$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
    if (color == null) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color!, BlendMode.srcIn),
      child: image,
    );
  }
}
