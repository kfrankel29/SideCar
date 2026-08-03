import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class RidePageScaffold extends StatelessWidget {
  const RidePageScaffold({
    required this.body,
    required this.role,
    required this.navigationIndex,
    super.key,
    this.showNavigation = true,
  });

  final Widget body;
  final PrimaryRole role;
  final int navigationIndex;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: showNavigation
          ? RideBottomNavigation(role: role, selectedIndex: navigationIndex)
          : null,
    );
  }
}

class RideBottomNavigation extends StatelessWidget {
  const RideBottomNavigation({
    required this.role,
    required this.selectedIndex,
    super.key,
  });

  final PrimaryRole role;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_outlined,
      Icons.search_rounded,
      Icons.view_carousel_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.person_outline_rounded,
    ];
    final driverIcons = [
      Icons.home_outlined,
      Icons.add_box_outlined,
      Icons.view_carousel_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.person_outline_rounded,
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.softSurface)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            return IconButton(
              key: ValueKey('ride-nav-$index'),
              tooltip: _tooltip(index),
              onPressed: AppHaptics.wrap(() => _open(context, index)),
              icon: Icon(
                role == PrimaryRole.driver ? driverIcons[index] : icons[index],
                size: 25,
                color: selectedIndex == index
                    ? AppColors.ink
                    : const Color(0xFFB0B0B0),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _tooltip(int index) => switch (index) {
    0 => 'Home',
    1 => role == PrimaryRole.driver ? 'Post a ride' : 'Search rides',
    2 => 'My rides',
    3 => 'Messages',
    _ => 'Profile',
  };

  void _open(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(
          role == PrimaryRole.driver
              ? AppRoutes.postRide
              : AppRoutes.searchRides,
        );
      case 2:
        if (role == PrimaryRole.driver) context.go(AppRoutes.myRides);
      case 4:
        context.go(AppRoutes.profileGate);
      case 3:
        return;
    }
  }
}

class RideChoiceChip extends StatelessWidget {
  const RideChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: AppHaptics.wrap(onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: compact ? 35 : 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.white,
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? Colors.white : AppColors.ink,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ),
      ),
    );
  }
}

class RideCard extends StatelessWidget {
  const RideCard({
    required this.ride,
    super.key,
    this.onTap,
    this.selected = false,
  });

  final Ride ride;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap == null ? null : AppHaptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 13, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RideAvatar(initials: ride.driverInitials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ride.driverName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.star_rounded, size: 17),
                      const SizedBox(width: 3),
                      Text(
                        ride.driverRating == 0
                            ? 'New'
                            : ride.driverRating.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Dep ${formatTime(ride.departureAt)} · ${ride.vehicle.makeAndModel}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      const RideBadge(label: 'Verified', checked: true),
                      if (ride.genderRestriction != RideGenderRestriction.any)
                        RideBadge(label: ride.genderRestriction.label),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ride.priceLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${ride.seatsAvailable} ${ride.seatsAvailable == 1 ? 'seat' : 'seats'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RideAvatar extends StatelessWidget {
  const RideAvatar({required this.initials, super.key, this.radius = 23});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE9E9E9),
      child: Text(
        initials.isEmpty ? 'SC' : initials,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class RideBadge extends StatelessWidget {
  const RideBadge({required this.label, super.key, this.checked = false});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (checked) ...[
            const Icon(Icons.check_rounded, size: 15),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryInk),
          ),
        ],
      ),
    );
  }
}

class RideRouteCard extends StatelessWidget {
  const RideRouteCard({
    required this.origin,
    required this.destination,
    super.key,
    this.originSubtitle,
    this.destinationSubtitle,
    this.onTap,
    this.onOriginTap,
    this.onDestinationTap,
  });

  final String origin;
  final String destination;
  final String? originSubtitle;
  final String? destinationSubtitle;
  final VoidCallback? onTap;
  final VoidCallback? onOriginTap;
  final VoidCallback? onDestinationTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : AppHaptics.wrap(onTap),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink, width: 2),
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _DottedLinePainter(),
                      child: const SizedBox(width: 1),
                    ),
                  ),
                  const CircleAvatar(radius: 6, backgroundColor: AppColors.ink),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onOriginTap == null
                          ? null
                          : AppHaptics.wrap(onOriginTap!),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _RouteLocationText(
                          title: origin,
                          subtitle: originSubtitle,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 12),
                  Expanded(
                    child: InkWell(
                      onTap: onDestinationTap == null
                          ? null
                          : AppHaptics.wrap(onDestinationTap!),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _RouteLocationText(
                          title: destination,
                          subtitle: destinationSubtitle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLocationText extends StatelessWidget {
  const _RouteLocationText({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class RideMapPreview extends StatelessWidget {
  const RideMapPreview({super.key, this.encodedPolyline = ''});

  final String encodedPolyline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 155,
      width: double.infinity,
      child: CustomPaint(
        painter: _MapPreviewPainter(encodedPolyline: encodedPolyline),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1;
    for (var y = 4.0; y < size.height - 4; y += 6) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter({required this.encodedPolyline});

  final String encodedPolyline;

  @override
  void paint(Canvas canvas, Size size) {
    final street = Paint()
      ..color = const Color(0xFFF0F1F2)
      ..strokeWidth = 6;
    for (var y = 16.0; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), street);
    }
    for (var x = 28.0; x < size.width; x += 64) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), street);
    }
    final route = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final points = _decodePolyline(encodedPolyline);
    final projected = points.length > 1 ? _projectRoute(points, size) : null;
    final path = projected == null
        ? (Path()
            ..moveTo(size.width * 0.12, size.height * 0.75)
            ..quadraticBezierTo(
              size.width * 0.47,
              size.height * 0.1,
              size.width * 0.9,
              size.height * 0.18,
            ))
        : (Path()..moveTo(projected.first.dx, projected.first.dy));
    if (projected != null) {
      for (final point in projected.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, route);
    final start =
        projected?.first ?? Offset(size.width * 0.12, size.height * 0.75);
    final end = projected?.last ?? Offset(size.width * 0.9, size.height * 0.18);
    canvas.drawCircle(start, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(end, 7, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.encodedPolyline != encodedPolyline;
}

List<Offset> _decodePolyline(String value) {
  if (value.isEmpty) return const [];
  final points = <Offset>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  try {
    while (index < value.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      latitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = value.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      longitude += (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      points.add(Offset(longitude / 1e5, latitude / 1e5));
    }
  } on RangeError {
    return const [];
  }
  return points;
}

List<Offset> _projectRoute(List<Offset> points, Size size) {
  final minX = points.map((point) => point.dx).reduce(math.min);
  final maxX = points.map((point) => point.dx).reduce(math.max);
  final minY = points.map((point) => point.dy).reduce(math.min);
  final maxY = points.map((point) => point.dy).reduce(math.max);
  final spanX = math.max(maxX - minX, 0.000001);
  final spanY = math.max(maxY - minY, 0.000001);
  const padding = 20.0;
  final availableWidth = math.max(1.0, size.width - padding * 2);
  final availableHeight = math.max(1.0, size.height - padding * 2);
  return points
      .map(
        (point) => Offset(
          padding + ((point.dx - minX) / spanX) * availableWidth,
          padding + ((maxY - point.dy) / spanY) * availableHeight,
        ),
      )
      .toList(growable: false);
}

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String formatWeekday(DateTime value) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return weekdays[value.weekday - 1];
}

String formatShortDate(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[value.weekday - 1]} ${months[value.month - 1]} ${value.day}';
}

String routeName(Ride ride) =>
    '${ride.origin.displayName} → ${ride.destination.displayName}';

double estimateEarnings(int cents, int seats) =>
    math.max(0, cents * seats / 100);
