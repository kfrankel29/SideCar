import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/rides/domain/encoded_polyline.dart';
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
            color: selected ? AppColors.primary : Colors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
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
    return RideSummaryCard(
      origin: ride.origin.displayName,
      destination: ride.destination.displayName,
      dateLabel: formatShortDate(ride.departureAt),
      timeLabel: formatTime(ride.departureAt),
      priceLabel: ride.priceLabel,
      bookedLabel: '${ride.bookedSeats}/${ride.seatsTotal} booked',
      profileName: ride.driverName,
      profileInitials: ride.driverInitials,
      profilePhotoUrl: ride.driverPhotoUrl,
      profileRating: ride.driverRating,
      selected: selected,
      onTap: onTap,
      keyPrefix: 'ride-card-${ride.id}',
    );
  }
}

/// The M7 ride-information contract used across home, search, My Rides, and
/// ride details. It intentionally has no fixed height or ellipsis: long names
/// and locations wrap and make the card taller while preserving equal spacing.
class RideSummaryCard extends StatelessWidget {
  const RideSummaryCard({
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.timeLabel,
    required this.priceLabel,
    required this.bookedLabel,
    super.key,
    this.profileName,
    this.profileInitials = '',
    this.profilePhotoUrl = '',
    this.profileRating,
    this.selected = false,
    this.onTap,
    this.keyPrefix,
    this.footer,
  });

  final String origin;
  final String destination;
  final String dateLabel;
  final String timeLabel;
  final String priceLabel;
  final String bookedLabel;
  final String? profileName;
  final String profileInitials;
  final String profilePhotoUrl;
  final double? profileRating;
  final bool selected;
  final VoidCallback? onTap;
  final String? keyPrefix;
  final Widget? footer;

  Key? _contentKey(String part) =>
      keyPrefix == null ? null : ValueKey<String>('$keyPrefix-$part');

  @override
  Widget build(BuildContext context) {
    final displayOrigin = abbreviateRidePlaceName(origin);
    final displayDestination = abbreviateRidePlaceName(destination);
    const strong = TextStyle(
      fontFamily: 'Arial',
      color: AppColors.ink,
      fontSize: 17,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );
    const secondary = TextStyle(
      fontFamily: 'Arial',
      color: AppColors.secondaryInk,
      fontSize: 14,
      height: 1.25,
      fontWeight: FontWeight.w700,
    );
    final hasProfile = profileName?.trim().isNotEmpty == true;

    return Semantics(
      button: onTap != null,
      label:
          '$displayOrigin to $displayDestination, $dateLabel at $timeLabel, '
          '$priceLabel per seat, $bookedLabel',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null ? null : AppHaptics.wrap(onTap),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      displayOrigin,
                      key: _contentKey('origin'),
                      softWrap: true,
                      style: strong,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '→',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        color: AppColors.secondaryInk,
                        fontSize: 28,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      displayDestination,
                      key: _contentKey('destination'),
                      textAlign: TextAlign.end,
                      softWrap: true,
                      style: strong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          key: _contentKey('date'),
                          softWrap: true,
                          style: strong,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          timeLabel,
                          key: _contentKey('time'),
                          style: secondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        priceLabel,
                        key: _contentKey('price'),
                        style: strong.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 3),
                      const Text('per seat', style: secondary),
                      if (!hasProfile) ...[
                        const SizedBox(height: 5),
                        Text(
                          bookedLabel,
                          key: _contentKey('booked'),
                          style: secondary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (hasProfile) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    RideAvatar(
                      initials: profileInitials,
                      photoUrl: profilePhotoUrl,
                      radius: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileName!,
                            key: _contentKey('profile'),
                            softWrap: true,
                            style: strong,
                          ),
                          if ((profileRating ?? 0) > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '★ ${(profileRating ?? 0).toStringAsFixed(1)}',
                              style: secondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      bookedLabel,
                      key: _contentKey('booked'),
                      textAlign: TextAlign.end,
                      style: secondary,
                    ),
                  ],
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 14),
                footer!,
              ],
            ],
          ),
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
    this.routeMarkerColor = AppColors.primary,
    this.locationTextStyle,
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
  final Color routeMarkerColor;
  final TextStyle? locationTextStyle;

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
                      border: Border.all(color: routeMarkerColor, width: 2),
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      painter: _DottedLinePainter(),
                      child: const SizedBox(width: 1),
                    ),
                  ),
                  CircleAvatar(radius: 6, backgroundColor: routeMarkerColor),
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
                          textStyle: locationTextStyle,
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
                          textStyle: locationTextStyle,
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
    this.textStyle,
  });

  final String title;
  final String placeholder;
  final String? subtitle;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.trim().isEmpty ? placeholder : title,
          softWrap: true,
          style: title.trim().isEmpty
              ? (textStyle ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
                  color: AppColors.secondaryInk,
                  height: 1.1,
                )
              : (textStyle ?? Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(height: 1.1),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            softWrap: true,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.1),
          ),
      ],
    );
  }
}

class RideMapPreview extends StatefulWidget {
  const RideMapPreview({
    super.key,
    this.mapPreviewUrl = '',
    this.encodedPolyline = '',
    this.origin,
    this.destination,
    this.topExtension = 0,
    this.showZoomControls = true,
  });

  final String mapPreviewUrl;
  final String encodedPolyline;
  final RideLocation? origin;
  final RideLocation? destination;
  final double topExtension;
  final bool showZoomControls;

  @override
  State<RideMapPreview> createState() => _RideMapPreviewState();
}

class _RideMapPreviewState extends State<RideMapPreview> {
  GoogleMapController? _controller;

  List<LatLng> get _route {
    try {
      return decodeEncodedPolyline(
        widget.encodedPolyline,
      ).map((point) => LatLng(point.latitude, point.longitude)).toList();
    } on FormatException {
      return const [];
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _fitRoute(List<LatLng> route) async {
    final controller = _controller;
    if (controller == null || route.isEmpty) return;
    // Android can invoke onMapCreated before the platform view has a non-zero
    // layout. Waiting for that first layout avoids newLatLngBounds throwing.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || controller != _controller) return;
    try {
      if (route.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(route.first, 13),
        );
        return;
      }
      var minLatitude = route.first.latitude;
      var maxLatitude = minLatitude;
      var minLongitude = route.first.longitude;
      var maxLongitude = minLongitude;
      for (final point in route.skip(1)) {
        minLatitude = math.min(minLatitude, point.latitude);
        maxLatitude = math.max(maxLatitude, point.latitude);
        minLongitude = math.min(minLongitude, point.longitude);
        maxLongitude = math.max(maxLongitude, point.longitude);
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLatitude, minLongitude),
            northeast: LatLng(maxLatitude, maxLongitude),
          ),
          36,
        ),
      );
    } on PlatformException {
      // A rapidly dismissed map can still disappear between layout and the
      // native camera update. The initial route camera remains a safe fallback.
    }
  }

  Future<void> _zoom(bool zoomIn) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.animateCamera(
      zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final routeMapHeight = constraints.maxWidth * 252 / 640;
          return SizedBox(
            height: routeMapHeight + widget.topExtension,
            child: route.length >= 2 && (Platform.isIOS || Platform.isAndroid)
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      GoogleMap(
                        key: const ValueKey('interactive-ride-route-map'),
                        initialCameraPosition: CameraPosition(
                          target: route.first,
                          zoom: 10,
                        ),
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('ride-route'),
                            points: route,
                            color: AppColors.primary,
                            width: 5,
                          ),
                        },
                        markers: {
                          Marker(
                            markerId: const MarkerId('route-origin'),
                            position: route.first,
                            infoWindow: InfoWindow(
                              title: widget.origin?.displayName ?? 'Departure',
                            ),
                          ),
                          Marker(
                            markerId: const MarkerId('route-destination'),
                            position: route.last,
                            infoWindow: InfoWindow(
                              title:
                                  widget.destination?.displayName ??
                                  'Destination',
                            ),
                          ),
                        },
                        compassEnabled: true,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        rotateGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                        tiltGesturesEnabled: true,
                        zoomControlsEnabled: false,
                        zoomGesturesEnabled: true,
                        onMapCreated: (controller) {
                          _controller = controller;
                          unawaited(_fitRoute(route));
                        },
                      ),
                      if (widget.showZoomControls)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Zoom in',
                                  onPressed: () => _zoom(true),
                                  icon: const Icon(Icons.add),
                                ),
                                const SizedBox(
                                  width: 34,
                                  child: Divider(height: 1),
                                ),
                                IconButton(
                                  tooltip: 'Zoom out',
                                  onPressed: () => _zoom(false),
                                  icon: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : widget.mapPreviewUrl.trim().isEmpty
                ? const _MapUnavailablePlaceholder()
                : Semantics(
                    image: true,
                    label: 'Ride route map',
                    child: CachedNetworkImage(
                      imageUrl: widget.mapPreviewUrl,
                      cacheKey: widget.mapPreviewUrl,
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
  return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day}';
}

String formatMonthDay(DateTime value) => '${value.month}/${value.day}';

String abbreviateRidePlaceName(String value) {
  final normalized = value.trim();
  if (RegExp(
    r'(?:university of california[,-]?|uc)\s*santa barbara',
    caseSensitive: false,
  ).hasMatch(normalized)) {
    return 'UCSB';
  }
  return normalized;
}

String routeName(Ride ride) =>
    '${abbreviateRidePlaceName(ride.origin.displayName)} → '
    '${abbreviateRidePlaceName(ride.destination.displayName)}';

double estimateEarnings(int cents, int seats) =>
    math.max(0, cents * seats / 100);
