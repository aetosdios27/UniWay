import '../theme/uniway_theme.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/destination.dart';
import 'destination_search.dart';

const _debounceDelay = Duration(milliseconds: 150);
const _tileExtent = 72.0;

Future<Destination?> showDestinationSearchSheet(
  BuildContext context, {
  required List<Destination> destinations,
  required String title,
  Destination? selected,
  Destination? extraOption,
}) {
  return showModalBottomSheet<Destination>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DestinationSearchSheet(
      destinations: destinations,
      title: title,
      selected: selected,
      extraOption: extraOption,
    ),
  );
}

class _DestinationSearchSheet extends StatefulWidget {
  final List<Destination> destinations;
  final String title;
  final Destination? selected;
  final Destination? extraOption;

  const _DestinationSearchSheet({
    required this.destinations,
    required this.title,
    this.selected,
    this.extraOption,
  });

  @override
  State<_DestinationSearchSheet> createState() => _DestinationSearchSheetState();
}

class _DestinationSearchSheetState extends State<_DestinationSearchSheet> {
  final _input = TextEditingController();
  late DestinationSearchIndex _index;
  late List<Destination> _results;
  late bool _pinExtra;
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _index = DestinationSearchIndex.of(widget.destinations);
    _results = _index.search('');
    _pinExtra = _showsExtra('');
  }

  @override
  void didUpdateWidget(covariant _DestinationSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.destinations, widget.destinations)) {
      _index = DestinationSearchIndex.of(widget.destinations);
      _search(_query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(value));
  }

  void _clear() {
    _debounce?.cancel();
    _input.clear();
    _search('');
  }

  void _search(String query) {
    setState(() {
      _query = query.trim();
      _pinExtra = _showsExtra(query);
      _results = _index.search(query);
    });
  }

  bool _showsExtra(String query) {
    final extra = widget.extraOption;
    if (extra == null) return false;
    return query.trim().isEmpty || DestinationSearchIndex([extra]).search(query).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinned = _pinExtra ? widget.extraOption : null;
    final pinnedCount = pinned == null ? 0 : 1;
    final count = pinnedCount + _results.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _input,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Search destinations',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _input,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: _clear,
                          ),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: count == 0
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.isEmpty
                              ? 'No matching destinations'
                              : 'No matching destinations for "$_query"',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemExtent: _tileExtent,
                      itemCount: count,
                      itemBuilder: (context, index) {
                        if (pinned != null && index == 0) return _tile(pinned);
                        return _tile(_results[index - pinnedCount]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Destination destination) {
    return _DestinationTile(
      destination: destination,
      isSelected: destination == widget.selected,
      isGps: destination.id == widget.extraOption?.id,
    );
  }
}

class _DestinationTile extends StatelessWidget {
  final Destination destination;
  final bool isSelected;
  final bool isGps;

  const _DestinationTile({
    required this.destination,
    required this.isSelected,
    required this.isGps,
  });

  @override
  Widget build(BuildContext context) {
    void pick() => Navigator.pop(context, destination);
    final theme = Theme.of(context);
    final colors = UniWayColors.of(context);

    return Semantics(
      label: destination.name,
      button: true,
      selected: isSelected,
      onTap: pick,
      excludeSemantics: true,
      child: ListTile(
        leading: Icon(
          isGps ? Icons.my_location : Icons.place_outlined,
          color: isGps ? colors.you : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(destination.name),
        subtitle: Text(destination.category),
        trailing: isSelected ? const Icon(Icons.check) : null,
        onTap: pick,
      ),
    );
  }
}
