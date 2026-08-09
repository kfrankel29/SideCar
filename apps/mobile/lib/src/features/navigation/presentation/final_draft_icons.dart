import 'package:flutter/material.dart';

enum FinalDraftIconKind { home, search, post, rides, messages, profile }

class FinalDraftIcon extends StatelessWidget {
  const FinalDraftIcon({
    required this.kind,
    required this.selected,
    super.key,
    this.size = 25,
  });

  final FinalDraftIconKind kind;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        selected ? const Color(0xFF111111) : const Color(0xFFB5B5BA),
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
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _BackPainter());
}

class _BackPainter extends CustomPainter {
  const _BackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .66, size.height * .18)
      ..lineTo(size.width * .32, size.height * .5)
      ..lineTo(size.width * .66, size.height * .82);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
