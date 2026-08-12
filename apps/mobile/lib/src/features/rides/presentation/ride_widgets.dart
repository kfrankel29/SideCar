import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class RidePageScaffold extends StatelessWidget {
  const RidePageScaffold({required this.body, super.key});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: body));
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
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.fromLTRB(12, 11, 13, 10),
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
            RideAvatar(
              initials: ride.driverInitials,
              photoUrl: ride.driverPhotoUrl,
              radius: 19,
            ),
            const SizedBox(width: 11),
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
                      if (ride.driverRating > 0) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '★',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          ride.driverRating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dep ${formatTime(ride.departureAt)} · ${ride.vehicle.makeAndModel}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${ride.origin.displayName} → ${ride.destination.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.secondaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ride.genderRestriction != RideGenderRestriction.any)
                  RideBadge(label: ride.genderRestriction.label),
                if (ride.genderRestriction != RideGenderRestriction.any)
                  const SizedBox(height: 5),
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
  const RideAvatar({
    required this.initials,
    super.key,
    this.radius = 23,
    this.photoUrl = '',
  });

  final String initials;
  final double radius;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initials.isEmpty ? 'SC' : initials,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
    return ClipOval(
      child: ColoredBox(
        color: const Color(0xFFE9E9E9),
        child: SizedBox.square(
          dimension: radius * 2,
          child: photoUrl.isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
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
    this.originPlaceholder = 'Choose pickup area',
    this.destinationPlaceholder = 'Choose drop-off area',
    this.onTap,
    this.onOriginTap,
    this.onDestinationTap,
    this.backgroundColor = Colors.white,
    this.showBorder = true,
  });

  final String origin;
  final String destination;
  final String? originSubtitle;
  final String? destinationSubtitle;
  final String originPlaceholder;
  final String destinationPlaceholder;
  final VoidCallback? onTap;
  final VoidCallback? onOriginTap;
  final VoidCallback? onDestinationTap;
  final Color backgroundColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : AppHaptics.wrap(onTap),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: showBorder ? Border.all(color: AppColors.border) : null,
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
                          placeholder: originPlaceholder,
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
                          placeholder: destinationPlaceholder,
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
  const _RouteLocationText({
    required this.title,
    required this.placeholder,
    this.subtitle,
  });

  final String title;
  final String placeholder;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? placeholder : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: title.trim().isEmpty
              ? Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.secondaryInk)
              : Theme.of(context).textTheme.titleMedium,
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
  const RideMapPreview({
    super.key,
    this.mapPreviewUrl = '',
    this.topExtension = 0,
  });

  final String mapPreviewUrl;
  final double topExtension;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final routeMapHeight = constraints.maxWidth * 252 / 640;
          return SizedBox(
            height: routeMapHeight + topExtension,
            child: mapPreviewUrl.trim().isEmpty
                ? const _MapUnavailablePlaceholder()
                : Semantics(
                    image: true,
                    label: 'Ride route map',
                    child: CachedNetworkImage(
                      imageUrl: mapPreviewUrl,
                      cacheKey: mapPreviewUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      useOldImageOnUrlChange: false,
                      filterQuality: FilterQuality.low,
                      memCacheWidth: 1280,
                      memCacheHeight: 704,
                      maxWidthDiskCache: 1280,
                      maxHeightDiskCache: 704,
                      placeholder: (_, _) => const _MapLoadingPlaceholder(),
                      errorWidget: (_, _, _) =>
                          const _MapUnavailablePlaceholder(),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _MapLoadingPlaceholder extends StatelessWidget {
  const _MapLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF5F6F7),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _MapUnavailablePlaceholder extends StatelessWidget {
  const _MapUnavailablePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F6F7),
      child: Center(
        child: Text(
          'Map unavailable',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
