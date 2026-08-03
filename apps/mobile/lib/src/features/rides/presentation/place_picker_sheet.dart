import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

Future<RidePlacePrediction?> showRidePlacePicker(
  BuildContext context, {
  required String title,
  String initialQuery = '',
}) {
  return showModalBottomSheet<RidePlacePrediction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: PlacePickerSheet(title: title, initialQuery: initialQuery),
    ),
  );
}

class PlacePickerSheet extends ConsumerStatefulWidget {
  const PlacePickerSheet({
    required this.title,
    required this.initialQuery,
    super.key,
  });

  final String title;
  final String initialQuery;

  @override
  ConsumerState<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<PlacePickerSheet> {
  late final TextEditingController _query;
  Timer? _debounce;
  List<RidePlacePrediction> _places = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.initialQuery);
    if (_query.text.trim().length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
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
            child: ListView.separated(
              itemCount: _places.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final place = _places[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(place.mainText),
                  subtitle: place.secondaryText.isEmpty
                      ? null
                      : Text(place.secondaryText),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
          Text(
            'Pickup and drop-off suggestions are provided by Google Places.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
