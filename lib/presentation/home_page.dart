import 'package:flutter/foundation.dart';
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
  final _sheetExtent = ValueNotifier<double>(controlSheetInitialExtent);
  final _statusOpen = ValueNotifier<bool>(false);
  var _movedForPin = false;

  @override
  void dispose() {
    _sheetExtent.dispose();
    _statusOpen.dispose();
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
      // Keep the pin centred in the map area left visible above the sheet.
      final camera = _mapController.camera;
      final lift = MediaQuery.sizeOf(context).height * _sheetExtent.value / 2;
      _mapController.move(
        camera.screenOffsetToLatLng(
          camera.latLngToScreenOffset(pin.latLng) + Offset(0, lift),
        ),
        13,
      );
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
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          _sheetExtent.value = n.extent;
          return false;
        },
        child: Stack(
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileBuilder: _neutralDarkTiles,
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
              ],
            ),
            ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, _) => Positioned(
                right: 8,
                bottom: MediaQuery.sizeOf(context).height * extent + 6,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _statusOpen,
                  builder: (context, open, child) => AnimatedOpacity(
                    opacity: open ? 0 : 1,
                    duration: const Duration(milliseconds: 150),
                    child: child,
                  ),
                  child: const _MapAttribution(),
                ),
              ),
            ),
            _ControlSheet(
              searchController: _searchController,
              state: state,
              controller: controller,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatusBanner(
                      state: state,
                      controller: controller,
                      open: _statusOpen,
                    ),
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
          ],
        ),
      ),
    );
  }
}

const controlSheetInitialExtent = 0.42;

final _pillButtonStyle = TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(vertical: 8),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

// Grayscale, inverted, compressed into a dark range (0.12-0.87) with a slight
// cool tint, so OSM's light tiles read as a neutral dark map.
const _tileLuma = [0.2126, 0.7152, 0.0722];
List<double> _tileRow(double tint) => [
  for (final w in _tileLuma) -0.75 * w * tint,
  0,
  0.87 * 255 * tint,
];

Widget _neutralDarkTiles(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix([
      ..._tileRow(0.82),
      ..._tileRow(0.90),
      ..._tileRow(1.0),
      0,
      0,
      0,
      1,
      0,
    ]),
    child: tileWidget,
  );
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          '© OpenStreetMap contributors',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white70),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatefulWidget {
  const _StatusBanner({
    required this.state,
    required this.controller,
    required this.open,
  });

  final SimulationViewState state;
  final SimulationController controller;
  final ValueNotifier<bool> open;

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner> {
  bool get _expanded => widget.open.value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final status = state.status;
    final checks = [
      (status.developerOptionsEnabled, 'Developer options'),
      (status.mockAppSelected, 'Mock location app'),
      (status.locationPermissionGranted, 'Location permission'),
    ];
    final android = defaultTargetPlatform == TargetPlatform.android;
    final ready = checks.where((c) => c.$1).length;
    String title;
    Color dot;
    if (status.simulating) {
      title = state.spoofHardening ? 'Simulating (stealth)' : 'Simulating';
      dot = const Color(0xFF3DDC84);
    } else if (status.canSimulate) {
      title = 'Ready to simulate';
      dot = scheme.primary;
    } else {
      title = 'Setup needed  $ready/${checks.length}';
      dot = const Color(0xFFFFB84D);
    }
    if (!android) {
      title = 'Android only';
      dot = scheme.onSurfaceVariant;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 4,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            widget.open.value = !widget.open.value;
            setState(() {});
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dot.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    if (android)
                      for (final c in checks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.$1
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: c.$1
                                    ? const Color(0xFF3DDC84)
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.$2,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        !android
                            ? 'Mock location only works on Android. This build is a UI preview.'
                            : status.simulating
                            ? 'Only GPS is changed. IP, Wi-Fi, and cell are unchanged.'
                            : 'GPS only, not a VPN. Select Pinshift as the mock location app, then start.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (android && !status.canSimulate)
                      Wrap(
                        spacing: 20,
                        children: [
                          TextButton(
                            style: _pillButtonStyle,
                            onPressed: widget.controller.openDeveloperSettings,
                            child: const Text('Developer options'),
                          ),
                          TextButton(
                            style: _pillButtonStyle,
                            onPressed: widget.controller.requestPermissions,
                            child: const Text('Grant location'),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimezoneBanner extends StatelessWidget {
  const _TimezoneBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, size: 18, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Device timezone looks far from this longitude. Sites can still fingerprint you via clock, locale, and IP.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final coords =
        '${state.pin.latitude.toStringAsFixed(5)}, ${state.pin.longitude.toStringAsFixed(5)}';
    final hasPin = state.pin.latitude != 0 || state.pin.longitude != 0;
    final simulating = state.status.simulating;

    return DraggableScrollableSheet(
      initialChildSize: controlSheetInitialExtent,
      minChildSize: 0.33,
      maxChildSize: 0.62,
      snap: true,
      snapSizes: const [controlSheetInitialExtent, 0.62],
      builder: (context, scrollController) {
        return Material(
          color: scheme.surfaceContainer,
          elevation: 12,
          shadowColor: Colors.black87,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search a place or paste lat, lng',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Use device location',
                          onPressed: state.busy || simulating
                              ? null
                              : controller.centerOnDevice,
                          icon: const Icon(Icons.my_location),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: controller.lookup,
                    ),
                    if (state.searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.searchError!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    if (state.status.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.status.error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: officePresets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final office = officePresets[i];
                          final selected =
                              office.latitude == state.pin.latitude &&
                              office.longitude == state.pin.longitude;
                          return ChoiceChip(
                            avatar: Icon(
                              Icons.apartment,
                              size: 16,
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.primary,
                            ),
                            label: Text(office.label ?? ''),
                            selected: selected,
                            showCheckmark: false,
                            side: BorderSide.none,
                            backgroundColor: scheme.surfaceContainerHighest,
                            onSelected: (_) => controller.setPin(office),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Accuracy jitter',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            child: Text(
                              '±${state.jitterMeters.round()} m',
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: '${state.jitterMeters.round()} m',
                      value: state.jitterMeters.clamp(0, 30),
                      onChanged: controller.setJitter,
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: const Icon(
                              Icons.visibility_off_outlined,
                            ),
                            title: const Text('Stealth mode'),
                            subtitle: const Text(
                              'Adds GPS extras and tries to clear the isMock flag. '
                              'Best-effort, Android only.',
                            ),
                            value: state.spoofHardening,
                            onChanged: controller.setSpoofHardening,
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(Icons.public),
                            title: const Text('In-app browser'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const BrowserPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.place, size: 18, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasPin
                                    ? '${state.pin.label ?? 'Dropped pin'}  ·  $coords'
                                    : 'Tap the map to drop a pin',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: simulating ? scheme.error : null,
                            foregroundColor: simulating ? scheme.onError : null,
                          ),
                          onPressed: state.busy || (!simulating && !hasPin)
                              ? null
                              : () {
                                  if (simulating) {
                                    controller.stop();
                                  } else {
                                    controller.start();
                                  }
                                },
                          icon: Icon(
                            simulating ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            simulating ? 'Stop simulation' : 'Start simulation',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
