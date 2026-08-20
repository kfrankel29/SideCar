import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/static_map_projection.dart';
import 'package:sidecar/src/theme/app_theme.dart';

Future<RidePlacePrediction?> showRidePlacePicker(
  BuildContext context, {
  required String title,
  String initialQuery = '',
  String rideId = '',
}) {
  return showModalBottomSheet<RidePlacePrediction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: PlacePickerSheet(
        title: title,
        initialQuery: initialQuery,
        rideId: rideId,
      ),
    ),
  );
}

class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({
    required this.title,
    required this.initialQuery,
    this.rideId = '',
    super.key,
  });

  final String title;
  final String initialQuery;
  final String rideId;

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  late final TextEditingController _query;
  Timer? _debounce;
  List<RidePlacePrediction> _places = const [];
  bool _loading = false;
  bool _loadingMap = false;
  bool _pinning = false;
  String? _error;
  RidePlacePrediction? _selected;
  RideStopPickerContext? _routeContext;
  Offset? _pendingPinPosition;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    if (_query.text.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
    if (widget.rideId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRouteContext());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() {
        _places = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await ref.read(rideRepositoryProvider).searchPlaces(query);
      if (mounted && query == _query.text.trim()) {
        setState(() => _places = places);
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not search places. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRouteContext([RidePlacePrediction? selected]) async {
    if (widget.rideId.isEmpty) return;
    setState(() {
      _loadingMap = true;
      _error = null;
      if (selected != null) _selected = selected;
    });
    try {
      final context = await ref
          .read(rideRepositoryProvider)
          .getRideStopPickerContext(
            widget.rideId,
            selectedPlaceId: _selected?.placeId ?? '',
          );
      if (mounted) setState(() => _routeContext = context);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not load the route map. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loadingMap = false);
    }
  }

  void _choose(RidePlacePrediction place) {
    if (widget.rideId.isEmpty) {
      Navigator.pop(context, place);
      return;
    }
    _loadRouteContext(place);
  }

  Future<void> _dropPin(Offset position, Size size) async {
    final routeContext = _routeContext;
    if (routeContext == null ||
        _loadingMap ||
        _pinning ||
        routeContext.mapZoom <= 0) {
      return;
    }
    final coordinate = coordinateForStaticMapTap(
      tapX: position.dx,
      tapY: position.dy,
      viewWidth: size.width,
      viewHeight: size.height,
      mapWidth: routeContext.mapWidth.toDouble(),
      mapHeight: routeContext.mapHeight.toDouble(),
      centerLatitude: routeContext.mapCenterLatitude,
      centerLongitude: routeContext.mapCenterLongitude,
      zoom: routeContext.mapZoom,
    );
    setState(() {
      _pinning = true;
      _pendingPinPosition = position;
      _error = null;
    });
    try {
      final place = await ref
          .read(rideRepositoryProvider)
          .resolveRideStopPin(
            widget.rideId,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
          );
      if (!mounted) return;
      await _loadRouteContext(place);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not use that map point. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _pinning = false;
          _pendingPinPosition = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineLarge),
          if (widget.rideId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the map to drop an exact pin, search an address, or choose a nearby gas station.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio:
                    (_routeContext?.mapWidth ?? 640) /
                    (_routeContext?.mapHeight ?? 352),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      key: const ValueKey('route-stop-map'),
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) =>
                          _dropPin(details.localPosition, size),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.softSurface,
                            child:
                                _routeContext?.mapPreviewUrl.isNotEmpty == true
                                ? CachedNetworkImage(
                                    imageUrl: _routeContext!.mapPreviewUrl,
                                    fit: BoxFit.fill,
                                    fadeInDuration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    errorWidget: (_, _, _) => const Center(
                                      child: Text('Route map unavailable'),
                                    ),
                                  )
                                : const Center(
                                    child: Text('Loading route map…'),
                                  ),
                          ),
                          if (_pendingPinPosition case final position?)
                            Positioned(
                              left: position.dx - 15,
                              top: position.dy - 30,
                              child: const Icon(
                                Icons.location_pin,
                                size: 30,
                                color: AppColors.ink,
                              ),
                            ),
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xEFFFFFFF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Tap to drop pin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_loadingMap || _pinning)
                            const ColoredBox(
                              color: Color(0x44FFFFFF),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: 'Search a place or address',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _query.clear();
                        _changed('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (_places.isNotEmpty) ...[
                  Text(
                    'Search results',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ..._places.map(
                    (place) => _PlaceTile(
                      place: place,
                      selected: _selected?.placeId == place.placeId,
                      icon: Icons.location_on_outlined,
                      onTap: () => _choose(place),
                    ),
                  ),
                ],
                if (widget.rideId.isNotEmpty &&
                    _routeContext?.gasStations.isNotEmpty == true) ...[
                  Padding(
                    padding: EdgeInsets.only(top: _places.isEmpty ? 0 : 14),
                    child: Text(
                      'Gas stations within 1 mile of the route',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ..._routeContext!.gasStations.map(
                    (place) => _PlaceTile(
                      place: place,
                      selected: _selected?.placeId == place.placeId,
                      icon: Icons.local_gas_station_outlined,
                      onTap: () => _choose(place),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.rideId.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _selected == null || _loadingMap || _pinning
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: Text(
                _selected == null ? 'Choose a pin' : 'Use this address',
              ),
            ),
          ],
          Text(
            'Route, places, and nearby gas stations are provided by Google Maps.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final RidePlacePrediction place;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(icon),
      title: Text(place.mainText),
      subtitle: place.secondaryText.isEmpty ? null : Text(place.secondaryText),
      trailing: selected ? const Icon(Icons.check_circle) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
