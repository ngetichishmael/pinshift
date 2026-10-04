import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinshift/core/geo_pin.dart';
import 'package:pinshift/core/office_presets.dart';
import 'package:pinshift/core/place.dart';
import 'package:pinshift/data/pin_store.dart';
import 'package:pinshift/presentation/simulation_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('places round-trip through the store', () async {
    final store = PinStore();
    expect(await store.loadPlaces(), isNull);

    final places = [
      const Place(
        id: 'a',
        group: PlaceGroup.cities,
        pin: GeoPin(latitude: 1.5, longitude: -2.5, label: 'Somewhere'),
      ),
    ];
    await store.savePlaces(places);

    final loaded = await store.loadPlaces();
    expect(loaded, hasLength(1));
    expect(loaded!.single.id, 'a');
    expect(loaded.single.group, PlaceGroup.cities);
    expect(loaded.single.pin, places.single.pin);

    await store.clearPlaces();
    expect(await store.loadPlaces(), isNull);
  });

  test(
    'controller saves, edits, moves, deletes, restores and resets',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(simulationControllerProvider.notifier);
      List<Place> places() =>
          container.read(simulationControllerProvider).places;

      expect(places(), hasLength(defaultPlaces().length));

      await controller.setPin(
        const GeoPin(latitude: 10, longitude: 20, label: 'Dropped pin'),
      );
      await controller.savePlace('Depot', PlaceGroup.offices);
      final saved = places().last;
      expect(saved.name, 'Depot');
      expect(saved.group, PlaceGroup.offices);
      expect(container.read(simulationControllerProvider).pin.label, 'Depot');

      await controller.editPlace(saved.id, 'Depot 2', PlaceGroup.cities);
      expect(places().last.name, 'Depot 2');
      expect(places().last.group, PlaceGroup.cities);
      expect(container.read(simulationControllerProvider).pin.label, 'Depot 2');

      await controller.setPin(const GeoPin(latitude: 11, longitude: 21));
      await controller.movePlaceToPin(saved.id);
      expect(places().last.pin.latitude, 11);
      expect(places().last.name, 'Depot 2');

      final index = places().length - 1;
      await controller.deletePlace(saved.id);
      expect(places().any((p) => p.id == saved.id), isFalse);
      await controller.restorePlace(index, saved);
      expect(places().last.id, saved.id);

      expect((await PinStore().loadPlaces())!.last.id, saved.id);

      await controller.resetPlaces();
      expect(places(), hasLength(defaultPlaces().length));
      expect(await PinStore().loadPlaces(), isNull);
    },
  );
}
