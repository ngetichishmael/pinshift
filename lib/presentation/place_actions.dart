import 'package:flutter/material.dart';
import 'package:pinshift/core/place.dart';
import 'package:pinshift/presentation/simulation_controller.dart';

typedef PlaceDraft = ({String name, PlaceGroup group});

Future<PlaceDraft?> showPlaceDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  PlaceGroup initialGroup = PlaceGroup.offices,
}) {
  return showDialog<PlaceDraft>(
    context: context,
    builder: (_) => _PlaceDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialGroup: initialGroup,
    ),
  );
}

class _PlaceDialog extends StatefulWidget {
  const _PlaceDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialGroup,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final PlaceGroup initialGroup;

  @override
  State<_PlaceDialog> createState() => _PlaceDialogState();
}

class _PlaceDialogState extends State<_PlaceDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late var _group = widget.initialGroup;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop((name: name, group: _group));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SegmentedButton<PlaceGroup>(
            showSelectedIcon: false,
            segments: [
              for (final group in PlaceGroup.values)
                ButtonSegment(value: group, label: Text(group.label)),
            ],
            selected: {_group},
            onSelectionChanged: (value) => setState(() => _group = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ),
      ],
    );
  }
}

Future<void> saveCurrentPinAsPlace(
  BuildContext context,
  SimulationViewState state,
  SimulationController controller,
) async {
  final label = state.pin.label ?? '';
  final generic = const {'Dropped pin', 'Drop a pin', 'Coordinates', 'Device'};
  final draft = await showPlaceDialog(
    context,
    title: 'Save place',
    confirmLabel: 'Save',
    initialName: generic.contains(label) ? '' : label,
  );
  if (draft != null) {
    await controller.savePlace(draft.name, draft.group);
  }
}

Future<void> showPlaceActions(
  BuildContext context, {
  required Place place,
  required SimulationViewState state,
  required SimulationController controller,
}) {
  final hasPin = state.pin.latitude != 0 || state.pin.longitude != 0;
  final sameSpot =
      state.pin.latitude == place.pin.latitude &&
      state.pin.longitude == place.pin.longitude;
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(place.name, style: theme.textTheme.titleMedium),
              subtitle: Text(
                '${place.group.label}  ·  '
                '${place.pin.latitude.toStringAsFixed(5)}, '
                '${place.pin.longitude.toStringAsFixed(5)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename or regroup'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final draft = await showPlaceDialog(
                  context,
                  title: 'Edit place',
                  confirmLabel: 'Save',
                  initialName: place.name,
                  initialGroup: place.group,
                );
                if (draft != null) {
                  await controller.editPlace(place.id, draft.name, draft.group);
                }
              },
            ),
            if (hasPin && !sameSpot)
              ListTile(
                leading: const Icon(Icons.pin_drop_outlined),
                title: const Text('Move to current pin'),
                subtitle: Text(
                  '${state.pin.latitude.toStringAsFixed(5)}, '
                  '${state.pin.longitude.toStringAsFixed(5)}',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.movePlaceToPin(place.id);
                },
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final index = state.places.indexWhere((p) => p.id == place.id);
                controller.deletePlace(place.id);
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('Deleted ${place.name}'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => controller.restorePlace(index, place),
                      ),
                    ),
                  );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Reset all places to defaults'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Reset places?'),
                    content: const Text(
                      'This replaces your saved places with the built-in '
                      'offices and cities.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await controller.resetPlaces();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}
