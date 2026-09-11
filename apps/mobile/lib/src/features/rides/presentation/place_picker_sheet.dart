import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/rides/domain/static_map_projection.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
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
      heightFactor: 0.96,
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
  bool _loadingGasStations = false;
  bool _gasStationsLoaded = false;
  String _gasStationSearchQuery = '';
  bool _pinning = false;
  String? _error;
  RidePlacePrediction? _selected;
  RideStopPickerContext? _routeContext;
  Offset? _pendingPinPosition;
  final FocusNode _queryFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TransformationController _mapTransformation =
      TransformationController();
  GoogleMapController? _googleMapController;
  LatLng? _visibleMapCenter;

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
    _queryFocus.addListener(_keepQueryVisible);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _queryFocus
      ..removeListener(_keepQueryVisible)
      ..dispose();
    _scrollController.dispose();
    _mapTransformation.dispose();
    _googleMapController?.dispose();
    super.dispose();
  }

  void _keepQueryVisible() {
    if (mounted) setState(() {});
    if (!_queryFocus.hasFocus) return;
    // The native map is removed while search owns the full sheet. Its plugin
    // controller becomes invalid as soon as that widget is disposed, so never
    // retain it across the search-to-map transition.
    _googleMapController = null;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_queryFocus.hasFocus || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _changed(String _) {
    _debounce?.cancel();
    // Switch to the results layout immediately while preserving the keyed
    // search field. Without this rebuild, the first async result rebuild moves
    // an unkeyed TextField to a different child index and iOS drops its focus.
    setState(() {});
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
      final repository = ref.read(rideRepositoryProvider);
      final places = await repository.searchPlaces(query);
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
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRouteContext({
    RidePlacePrediction? selected,
    bool? includeGasStations,
    LatLng? gasStationCenter,
  }) async {
    if (widget.rideId.isEmpty) return;
    final shouldLoadGasStations = includeGasStations ?? _gasStationsLoaded;
    setState(() {
      _loadingMap = true;
      _loadingGasStations = shouldLoadGasStations;
      _error = null;
      if (selected != null) _selected = selected;
    });
    try {
      final context = await ref
          .read(rideRepositoryProvider)
          .getRideStopPickerContext(
            widget.rideId,
            selectedPlaceId: _selected?.placeId ?? '',
            searchPlaceIds: _places
                .map((place) => place.placeId)
                .toList(growable: false),
            includeGasStations: shouldLoadGasStations,
            gasStationQuery: shouldLoadGasStations
                ? _gasStationSearchQuery
                : '',
            gasStationLatitude: gasStationCenter?.latitude,
            gasStationLongitude: gasStationCenter?.longitude,
          );
      if (mounted) {
        setState(() {
          _routeContext = context;
          if (shouldLoadGasStations) _gasStationsLoaded = true;
        });
        unawaited(
          _moveNativeMapToContext(
            context,
            preferGasStations: _gasStationSearchQuery.isNotEmpty,
          ),
        );
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not load the route map. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingMap = false;
          _loadingGasStations = false;
        });
      }
    }
  }

  Future<void> _showGasStations() {
    final selected = _selected;
    final selectedCenter =
        selected != null && (selected.latitude != 0 || selected.longitude != 0)
        ? LatLng(selected.latitude, selected.longitude)
        : null;
    return _loadRouteContext(
      includeGasStations: true,
      gasStationCenter: _gasStationsLoaded ? _visibleMapCenter : selectedCenter,
    );
  }

  void _choose(RidePlacePrediction place) {
    if (widget.rideId.isEmpty) {
      Navigator.pop(context, place);
      return;
    }
    final choosingGasStation =
        _routeContext?.gasStations.any(
          (station) => station.placeId == place.placeId,
        ) ??
        false;
    setState(() {
      _selected = place;
      if (!choosingGasStation) {
        _gasStationsLoaded = false;
        _gasStationSearchQuery = place.mainText;
      }
      _query
        ..text = place.displayName
        ..selection = TextSelection.collapsed(offset: place.displayName.length);
      _error = null;
    });
    _queryFocus.unfocus();
    unawaited(_loadRouteContext(selected: place));
  }

  void _addPlaceResult(RidePlacePrediction place) {
    final remaining = _places.where((item) => item.placeId != place.placeId);
    setState(() => _places = [place, ...remaining]);
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
      _addPlaceResult(place);
      _choose(place);
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

  Future<void> _dropNativePin(LatLng point) =>
      _resolvePin(latitude: point.latitude, longitude: point.longitude);

  Future<void> _resolvePin({
    required double latitude,
    required double longitude,
  }) async {
    if (_loadingMap || _pinning) return;
    setState(() {
      _pinning = true;
      _error = null;
    });
    try {
      final place = await ref
          .read(rideRepositoryProvider)
          .resolveRideStopPin(
            widget.rideId,
            latitude: latitude,
            longitude: longitude,
          );
      if (!mounted) return;
      _addPlaceResult(place);
      _choose(place);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not use that map point. Try again.');
      }
    } finally {
      if (mounted) setState(() => _pinning = false);
    }
  }

  Future<void> _moveNativeMapToContext(
    RideStopPickerContext route, {
    bool preferGasStations = false,
  }) async {
    final controller = _googleMapController;
    final resultPoints = <RideCoordinate>[
      for (final place in route.searchResults)
        if (place.latitude != 0 || place.longitude != 0)
          RideCoordinate(latitude: place.latitude, longitude: place.longitude),
      for (final station in route.gasStations)
        if (station.latitude != 0 || station.longitude != 0)
          RideCoordinate(
            latitude: station.latitude,
            longitude: station.longitude,
          ),
    ];
    final points = preferGasStations && resultPoints.isNotEmpty
        ? resultPoints
        : route.routePoints;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await _animateCamera(
        controller,
        CameraUpdate.newLatLngZoom(
          LatLng(points.first.latitude, points.first.longitude),
          14,
        ),
      );
      return;
    }
    var minLatitude = points.first.latitude;
    var maxLatitude = minLatitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = minLongitude;
    for (final point in points.skip(1)) {
      minLatitude = point.latitude < minLatitude ? point.latitude : minLatitude;
      maxLatitude = point.latitude > maxLatitude ? point.latitude : maxLatitude;
      minLongitude = point.longitude < minLongitude
          ? point.longitude
          : minLongitude;
      maxLongitude = point.longitude > maxLongitude
          ? point.longitude
          : maxLongitude;
    }
    if (minLatitude == maxLatitude && minLongitude == maxLongitude) return;
    await _animateCamera(
      controller,
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude),
        ),
        38,
      ),
    );
  }

  Future<void> _animateCamera(
    GoogleMapController controller,
    CameraUpdate update,
  ) async {
    try {
      await controller.animateCamera(update);
    } on StateError {
      if (identical(_googleMapController, controller)) {
        _googleMapController = null;
      }
    }
  }

  Future<void> _zoomMap({required bool zoomIn}) async {
    final controller = _googleMapController;
    if (controller != null) {
      await controller.animateCamera(
        zoomIn ? CameraUpdate.zoomIn() : CameraUpdate.zoomOut(),
      );
      return;
    }
    final current = _mapTransformation.value.getMaxScaleOnAxis();
    final target = (current * (zoomIn ? 1.4 : 1 / 1.4)).clamp(1.0, 5.0);
    _mapTransformation.value = Matrix4.diagonal3Values(target, target, 1);
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _queryFocus.hasFocus && _query.text.trim().isNotEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: ListView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (!showingSearch)
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          if (!showingSearch && widget.rideId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the map to drop an exact pin, search an address, or use Show gas stations for stops along the route.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(height: 300, child: _routeMap()),
            ),
          ],
          SizedBox(height: showingSearch ? 8 : 18),
          TextField(
            key: const ValueKey('place-search-field'),
            controller: _query,
            focusNode: _queryFocus,
            autofocus: widget.rideId.isEmpty,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: 'Search a place or address',
              prefixIcon: const Center(
                widthFactor: 1,
                heightFactor: 1,
                child: FinalDraftAssetIcon(
                  'search',
                  size: 20,
                  color: AppColors.mutedInk,
                ),
              ),
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
          if (showingSearch && _places.isNotEmpty) ...[
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
          if (!_queryFocus.hasFocus && _selected != null)
            _PlaceTile(
              place: _selected!,
              selected: true,
              icon: Icons.location_on_outlined,
              onTap: () => _queryFocus.requestFocus(),
            ),
          if (!showingSearch && widget.rideId.isNotEmpty) ...[
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey('use-selected-address'),
              onPressed: _selected == null || _loadingMap || _pinning
                  ? null
                  : () => Navigator.pop(context, _selected),
              child: Text(
                _selected == null ? 'Choose a pin' : 'Use this address',
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('show-gas-stations'),
                onPressed: _loadingMap ? null : _showGasStations,
                icon: _loadingGasStations
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_gas_station_outlined),
                label: Text(
                  _loadingGasStations
                      ? 'Loading gas stations…'
                      : _gasStationsLoaded
                      ? 'Reload gas stations in this map area'
                      : 'Show gas stations',
                ),
              ),
            ],
          ],
          if (!showingSearch &&
              widget.rideId.isNotEmpty &&
              _gasStationsLoaded &&
              _routeContext?.gasStations.isNotEmpty == true) ...[
            Padding(
              padding: EdgeInsets.only(top: _places.isEmpty ? 0 : 14),
              child: Text(
                _gasStationSearchQuery.isEmpty
                    ? 'Gas stations within 1 mile of the route'
                    : 'Gas stations near $_gasStationSearchQuery',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ..._routeContext!.gasStations
                .take(3)
                .map(
                  (place) => _PlaceTile(
                    place: place,
                    selected: _selected?.placeId == place.placeId,
                    icon: Icons.local_gas_station_outlined,
                    onTap: () => _choose(place),
                  ),
                ),
          ],
          if (!showingSearch &&
              widget.rideId.isNotEmpty &&
              _gasStationsLoaded &&
              _routeContext?.gasStations.isEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _gasStationSearchQuery.isEmpty
                    ? 'No gas stations found within 1 mile of this route.'
                    : 'No gas stations found near $_gasStationSearchQuery.',
              ),
            ),
          if (!showingSearch && widget.rideId.isNotEmpty)
            Text(
              'Route, places, and nearby gas stations are provided by Google Maps.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _routeMap() {
    final route = _routeContext;
    if (route != null &&
        route.routePoints.isNotEmpty &&
        (Platform.isIOS || Platform.isAndroid)) {
      final routeLine = route.routePoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);
      final markers = <Marker>{
        Marker(
          markerId: const MarkerId('route-origin'),
          position: routeLine.first,
          infoWindow: const InfoWindow(title: 'Driver departure'),
        ),
        Marker(
          markerId: const MarkerId('route-destination'),
          position: routeLine.last,
          infoWindow: const InfoWindow(title: 'Trip destination'),
        ),
        for (final (index, station) in route.gasStations.indexed)
          if (station.latitude != 0 || station.longitude != 0)
            Marker(
              markerId: MarkerId('gas-$index-${station.placeId}'),
              position: LatLng(station.latitude, station.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(title: station.mainText),
              onTap: () => _choose(station),
            ),
        for (final (index, place) in route.searchResults.indexed)
          if (place.latitude != 0 || place.longitude != 0)
            Marker(
              markerId: MarkerId('search-$index-${place.placeId}'),
              position: LatLng(place.latitude, place.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRose,
              ),
              infoWindow: InfoWindow(title: place.mainText),
              onTap: () => _choose(place),
            ),
        if (_selected case final selected?
            when selected.latitude != 0 || selected.longitude != 0)
          Marker(
            markerId: const MarkerId('selected-stop'),
            position: LatLng(selected.latitude, selected.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(title: selected.mainText),
          ),
      };
      return Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            key: const ValueKey('native-google-route-map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(route.mapCenterLatitude, route.mapCenterLongitude),
              zoom: route.mapZoom > 0 ? route.mapZoom.toDouble() : 10,
            ),
            markers: markers,
            polylines: {
              Polyline(
                polylineId: const PolylineId('ride-route'),
                points: routeLine,
                color: AppColors.primary,
                width: 5,
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
            onTap: _dropNativePin,
            onLongPress: _dropNativePin,
            onCameraMove: (position) => _visibleMapCenter = position.target,
            onMapCreated: (controller) {
              _googleMapController = controller;
              _visibleMapCenter = LatLng(
                route.mapCenterLatitude,
                route.mapCenterLongitude,
              );
              unawaited(
                _moveNativeMapToContext(
                  route,
                  preferGasStations: _gasStationSearchQuery.isNotEmpty,
                ),
              );
            },
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _MapZoomControls(onZoom: _zoomMap),
          ),
          if (_loadingMap || _pinning)
            const ColoredBox(
              color: Color(0x44FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              key: const ValueKey('interactive-route-map'),
              transformationController: _mapTransformation,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              trackpadScrollCausesScale: true,
              child: GestureDetector(
                key: const ValueKey('route-stop-map'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _dropPin(details.localPosition, size),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.softSurface,
                      child: route?.mapPreviewUrl.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: route!.mapPreviewUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: const Duration(milliseconds: 180),
                              errorWidget: (_, _, _) => const Center(
                                child: Text('Route map unavailable'),
                              ),
                            )
                          : const Center(child: Text('Loading route map…')),
                    ),
                    if (_pendingPinPosition case final position?)
                      Positioned(
                        left: position.dx - 15,
                        top: position.dy - 30,
                        child: const Icon(
                          Icons.location_pin,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: _MapZoomControls(onZoom: _zoomMap),
            ),
            if (_loadingMap || _pinning)
              const ColoredBox(
                color: Color(0x44FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({required this.onZoom});

  final Future<void> Function({required bool zoomIn}) onZoom;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('map-zoom-in'),
            tooltip: 'Zoom in',
            onPressed: () => onZoom(zoomIn: true),
            icon: const Icon(Icons.add),
          ),
          const Divider(height: 1),
          IconButton(
            key: const ValueKey('map-zoom-out'),
            tooltip: 'Zoom out',
            onPressed: () => onZoom(zoomIn: false),
            icon: const Icon(Icons.remove),
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
