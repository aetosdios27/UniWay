import '../../data/models/destination.dart';

const defaultSearchLimit = 50;

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _parenthesized = RegExp(r'\(([^()]+)\)');

const _tierExact = 0;
const _tierPrefix = 1;
const _tierWordPrefix = 2;
const _tierSubstring = 3;

List<Destination> searchDestinations(List<Destination> all, String query) {
  if (query.trim().isEmpty) return all;
  return DestinationSearchIndex(all).search(query);
}

class DestinationSearchIndex {
  static final _cache = Expando<DestinationSearchIndex>('destinationSearchIndex');

  /// Returns the index for this exact list instance, building it at most once.
  static DestinationSearchIndex of(List<Destination> destinations) =>
      _cache[destinations] ??= DestinationSearchIndex(destinations);

  final List<Destination> _destinations;
  final List<_Entry> _entries;

  factory DestinationSearchIndex(List<Destination> destinations) {
    final seen = <String>{};
    final entries = <_Entry>[
      for (final destination in destinations)
        if (seen.add(destination.id)) _Entry(destination),
    ];
    return DestinationSearchIndex._(destinations, entries);
  }

  DestinationSearchIndex._(this._destinations, this._entries);

  int get length => _entries.length;

  List<Destination> search(String query, {int limit = defaultSearchLimit}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _destinations;

    final compactQuery = _compact(q);
    if (compactQuery.isEmpty || limit <= 0) return const [];
    final tokens = _words(q).toList();

    final best = <_Hit>[];
    for (final entry in _entries) {
      final tier = entry.tierFor(q, compactQuery, tokens);
      if (tier == null) continue;
      final hit = _Hit(tier, entry);
      if (best.length == limit && _compareHits(hit, best.last) >= 0) continue;

      var low = 0;
      var high = best.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (_compareHits(best[mid], hit) <= 0) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      best.insert(low, hit);
      if (best.length > limit) best.removeLast();
    }
    return [for (final hit in best) hit.entry.destination];
  }
}

class _Entry {
  final Destination destination;
  final String name;
  final String compactName;
  final Set<String> keys;
  final List<String> labels;
  final List<String> compactLabels;
  final List<String> words;

  _Entry._(
    this.destination,
    this.name,
    this.compactName,
    this.keys,
    this.labels,
    this.compactLabels,
    this.words,
  );

  factory _Entry(Destination destination) {
    final name = destination.name.toLowerCase();
    final aliases = [
      for (final match in _parenthesized.allMatches(name)) match.group(1)!.trim(),
    ];
    final tags = [for (final tag in destination.tags) tag.toLowerCase()];

    final keys = <String>{};
    for (final key in [...aliases, ...tags, ..._acronyms(name)]) {
      keys
        ..add(key)
        ..add(_compact(key));
    }

    final labels = [name, ...aliases, ...tags];
    return _Entry._(
      destination,
      name,
      _compact(name),
      keys,
      labels,
      [for (final label in labels) _compact(label)],
      [for (final label in labels) ..._words(label)],
    );
  }

  int? tierFor(String q, String compactQuery, List<String> tokens) {
    if (keys.contains(q) || keys.contains(compactQuery)) return _tierExact;
    if (name.startsWith(q) || compactName.startsWith(compactQuery)) return _tierPrefix;
    if (tokens.every((token) => words.any((word) => word.startsWith(token)))) {
      return _tierWordPrefix;
    }
    if (compactLabels.any((label) => label.contains(compactQuery)) ||
        tokens.every((token) => labels.any((label) => label.contains(token)))) {
      return _tierSubstring;
    }
    return null;
  }
}

class _Hit {
  final int tier;
  final _Entry entry;

  const _Hit(this.tier, this.entry);
}

int _compareHits(_Hit a, _Hit b) {
  final byTier = a.tier.compareTo(b.tier);
  if (byTier != 0) return byTier;
  final byLength = a.entry.name.length.compareTo(b.entry.name.length);
  if (byLength != 0) return byLength;
  final byName = a.entry.name.compareTo(b.entry.name);
  if (byName != 0) return byName;
  return a.entry.destination.id.compareTo(b.entry.destination.id);
}

/// Initials of a name's words, with any numbers kept: 'academic building 1'
/// yields 'ab1' and 'ab', so students can type the alias they use in person.
Iterable<String> _acronyms(String name) {
  final words = _words(name.replaceAll(_parenthesized, ' ')).toList();
  final letters = StringBuffer();
  final numbers = StringBuffer();
  for (final word in words) {
    if (RegExp(r'^\p{N}+$', unicode: true).hasMatch(word)) {
      numbers.write(word);
    } else {
      letters.write(word[0]);
    }
  }
  if (letters.length < 2) return const [];
  return {letters.toString(), '$letters$numbers'};
}

String _compact(String value) => value.replaceAll(_nonWord, '');

Iterable<String> _words(String value) =>
    value.split(_nonWord).where((word) => word.isNotEmpty);
