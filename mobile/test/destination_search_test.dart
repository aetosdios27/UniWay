import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/data/models/phase0_destinations.dart';
import 'package:uniway_mobile/presentation/search/destination_search.dart';

const _ab1 = Destination(
  id: 'AB1',
  name: 'Academic Block 1 (AB1)',
  category: 'academic',
  latitude: 26.842601,
  longitude: 75.564172,
  tags: ['ab1', 'classes'],
);

const _ab1Annex = Destination(
  id: 'AB1_ANNEX',
  name: 'AB1 Annex',
  category: 'academic',
  latitude: 26.8,
  longitude: 75.5,
);

List<String> _names(List<Destination> destinations) =>
    destinations.map((d) => d.name).toList();

void main() {
  const all = Phase0Destinations.all;

  group('searchDestinations', () {
    test('matches the alias in parentheses, in any case', () {
      expect(_names(searchDestinations(all, 'AB1')), ['Academic Block 1 (AB1)']);
      expect(_names(searchDestinations(all, 'ab1')), ['Academic Block 1 (AB1)']);
    });

    test('ignores spaces, hyphens, and punctuation', () {
      expect(_names(searchDestinations(all, 'ab 1')), ['Academic Block 1 (AB1)']);
      expect(_names(searchDestinations(all, 'ab-1')), ['Academic Block 1 (AB1)']);
    });

    test('matches an alias that only appears in the name', () {
      expect(_names(searchDestinations(all, 'lhc')), ['Lecture Hall Complex (LHC)']);
    });

    test('matches a tag', () {
      expect(_names(searchDestinations(all, 'library')), ['Central Library']);
    });

    test('is case-insensitive', () {
      expect(_names(searchDestinations(all, 'CENTRAL library')), ['Central Library']);
    });

    test('trims surrounding whitespace', () {
      expect(_names(searchDestinations(all, '  library  ')), ['Central Library']);
    });

    test('blank query returns the full list unchanged', () {
      expect(searchDestinations(all, ''), same(all));
      expect(searchDestinations(all, '   '), same(all));
    });

    test('query with no match returns an empty list', () {
      expect(searchDestinations(all, 'swimming pool'), isEmpty);
    });

    test('ranks an exact alias before a name prefix, regardless of input order', () {
      final result = searchDestinations([_ab1Annex, _ab1], 'ab1');

      expect(result, [_ab1, _ab1Annex]);
    });

    test('ranks name and word prefixes before plain substrings', () {
      const prefix = Destination(
        id: 'PREFIX',
        name: 'Library Annex',
        category: 'academic',
        latitude: 0,
        longitude: 0,
      );
      const substring = Destination(
        id: 'SUBSTRING',
        name: 'Sublibrarian Office',
        category: 'admin',
        latitude: 0,
        longitude: 0,
      );

      final result = searchDestinations([substring, prefix], 'librar');

      expect(result, [prefix, substring]);
    });

    test('breaks ties within a rank by shorter name, then name', () {
      const longer = Destination(
        id: 'LONGER',
        name: 'Block Annex Long Name',
        category: 'academic',
        latitude: 0,
        longitude: 0,
      );
      const shorter = Destination(
        id: 'SHORTER',
        name: 'Block Hall',
        category: 'academic',
        latitude: 0,
        longitude: 0,
      );

      expect(searchDestinations([longer, shorter], 'block'), [shorter, longer]);
      expect(
        _names(searchDestinations(all, 'academic block')),
        ['Academic Block 1 (AB1)', 'Academic Block 2 (AB2)', 'Academic Block 3 (AB3)'],
      );
    });

    test('matches every word of a multi-word query by token prefix', () {
      expect(_names(searchDestinations(all, 'block 1')), ['Academic Block 1 (AB1)']);
      expect(_names(searchDestinations(all, 'old mess')), ['Old Mess (Food Court)']);
      expect(_names(searchDestinations(all, 'lecture hal')), ['Lecture Hall Complex (LHC)']);
    });

    test('a multi-word query needs every token to match', () {
      expect(searchDestinations(all, 'block library'), isEmpty);
    });

    test('index matches the wrapper and caps results at the limit', () {
      final index = DestinationSearchIndex(all);

      expect(index.search('academic block'), searchDestinations(all, 'academic block'));
      expect(index.search('academic', limit: 2), hasLength(2));
      expect(index.search('   '), same(all));
    });

    test('of() builds one index per list instance', () {
      final list = [_ab1, _ab1Annex];

      expect(DestinationSearchIndex.of(list), same(DestinationSearchIndex.of(list)));
      expect(DestinationSearchIndex.of(list), isNot(same(DestinationSearchIndex.of([_ab1, _ab1Annex]))));
    });

    test('derives acronym aliases from names when the backend sends no tags', () {
      const backendAb1 = Destination(
        id: 'DEST_03',
        routingNodeId: 'OUT_AB1_0_062',
        name: 'Academic Building 1',
        category: 'destination',
        latitude: 26.8424,
        longitude: 75.5640,
      );
      const backendAb2 = Destination(
        id: 'DEST_04',
        routingNodeId: 'OUT_AB2_0_041',
        name: 'Academic Building 2',
        category: 'destination',
        latitude: 26.8431,
        longitude: 75.5658,
      );
      const lhc = Destination(
        id: 'DEST_06',
        routingNodeId: 'OUT_LHC_0_010',
        name: 'LHC',
        category: 'destination',
        latitude: 26.8440,
        longitude: 75.5648,
      );
      final backend = [backendAb2, backendAb1, lhc];

      expect(searchDestinations(backend, 'ab1'), [backendAb1]);
      expect(searchDestinations(backend, 'AB 2'), [backendAb2]);
      expect(searchDestinations(backend, 'ab'), [backendAb1, backendAb2]);
      expect(searchDestinations(backend, 'lhc'), [lhc]);
    });

    test('returns each destination once', () {
      final result = searchDestinations([_ab1, _ab1], 'ab1');

      expect(result, [_ab1]);
    });
  });
}
