import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pinshift/core/geo_pin.dart';
import 'package:pinshift/core/office_presets.dart';
import 'package:pinshift/core/timezone_check.dart';
import 'package:pinshift/presentation/browser_page.dart';
import 'package:pinshift/presentation/simulation_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  var _movedForPin = false;

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _maybeMoveTo(GeoPin pin) {
    if (pin.latitude == 0 && pin.longitude == 0 && pin.label == 'Drop a pin') {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mapController.move(pin.latLng, 13);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulationControllerProvider);
    final controller = ref.read(simulationControllerProvider.notifier);
    ref.listen(simulationControllerProvider, (previous, next) {
      if (!_movedForPin &&
          (next.pin.latitude != 0 || next.pin.longitude != 0)) {
        _movedForPin = true;
        _maybeMoveTo(next.pin);
      } else if (previous != null && previous.pin != next.pin) {
        _maybeMoveTo(next.pin);
      }
    });

    final mismatched = timezoneLooksMismatched(
      longitude: state.pin.longitude,
      deviceOffset: DateTime.now().timeZoneOffset,
    );

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 3,
              onTap: (tap, latLng) {
                controller.setPin(
                  GeoPin(
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                    label: 'Dropped pin',
                  ),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pinshift.pinshift',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: state.pin.latLng,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: state.status.simulating
                          ? const Color(0xFF5AC8FA)
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap © CARTO'),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusBanner(state: state, controller: controller),
                  if (mismatched &&
                      (state.pin.latitude != 0 || state.pin.longitude != 0))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _TimezoneBanner(),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ControlSheet(
              searchController: _searchController,
              state: state,
              controller: controller,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state, required this.controller});

  final SimulationViewState state;
  final SimulationController controller;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  ok: status.developerOptionsEnabled,
                  label: 'Developer options',
                ),
                _Chip(ok: status.mockAppSelected, label: 'Mock location app'),
                _Chip(
                  ok: status.locationPermissionGranted,
                  label: 'Location permission',
                ),
                _Chip(ok: status.simulating, label: 'Simulating'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status.simulating
                  ? state.spoofHardening
                      ? 'Stealth mode active: GPS extras enriched, isMock flag cleared (best-effort). IP, Wi-Fi, and cell are unchanged.'
                      : 'Android is receiving this test location. Location.isMock stays true. IP, Wi-Fi, and cell are unchanged.'
                  : 'GPS only — not a VPN. Select Pinshift as the mock location app, then start.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!status.canSimulate) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: controller.openDeveloperSettings,
                    child: const Text('Developer options'),
                  ),
                  TextButton(
                    onPressed: controller.requestPermissions,
                    child: const Text('Grant location'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        size: 16,
        color: ok
            ? const Color(0xFF3DDC84)
            : Theme.of(context).colorScheme.error,
      ),
      label: Text(label),
    );
  }
}

class _TimezoneBanner extends StatelessWidget {
  const _TimezoneBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.tertiaryContainer.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Device timezone looks far from this longitude. Sites can still fingerprint you via clock, locale, and IP.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _ControlSheet extends StatelessWidget {
  const _ControlSheet({
    required this.searchController,
    required this.state,
    required this.controller,
  });

  final TextEditingController searchController;
  final SimulationViewState state;
  final SimulationController controller;

  @override
  Widget build(BuildContext context) {
    final coords =
        '${state.pin.latitude.toStringAsFixed(6)}, ${state.pin.longitude.toStringAsFixed(6)}';
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search a place or paste lat, lng',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Use device location',
                    onPressed: state.busy || state.status.simulating
                        ? null
                        : controller.centerOnDevice,
                    icon: const Icon(Icons.my_location),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: controller.lookup,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final office in officePresets)
                    ActionChip(
                      avatar: const Icon(Icons.apartment, size: 16),
                      label: Text(office.label ?? ''),
                      onPressed: () => controller.setPin(office),
                    ),
                ],
              ),
              if (state.searchError != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.searchError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (state.status.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.status.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                state.pin.label ?? 'Dropped pin',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                coords,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Jitter'),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: '${state.jitterMeters.round()} m',
                      value: state.jitterMeters.clamp(0, 30),
                      onChanged: controller.setJitter,
                    ),
                  ),
                  Text('${state.jitterMeters.round()} m'),
                ],
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BrowserPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.public),
                label: const Text('In-app browser'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stealth mode'),
                subtitle: const Text(
                  'Adds GPS extras and attempts to clear the isMock flag via reflection. '
                  'Effective on some OEM ROMs; limited on stock Android 12+.',
                ),
                value: state.spoofHardening,
                onChanged: controller.setSpoofHardening,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () {
                        if (state.status.simulating) {
                          controller.stop();
                        } else {
                          controller.start();
                        }
                      },
                icon: Icon(
                  state.status.simulating ? Icons.stop : Icons.play_arrow,
                ),
                label: Text(
                  state.status.simulating
                      ? 'Stop simulation'
                      : 'Start simulation',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
