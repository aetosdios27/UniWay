import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniway_mobile/data/models/destination.dart';
import 'package:uniway_mobile/presentation/search/destination_search.dart';

List<Destination> _generate(int count) => [
      for (var i = 0; i < count; i++)
        Destination(
          id: 'POI-$i',
          name: 'Block ${i % 97} Room $i (B$i)',
          category: 'academic',
          latitude: 26.84,
          longitude: 75.56,
          tags: ['tag${i % 13}', 'floor ${i % 5}'],
        ),
    ];

List<String> _ids(List<Destination> destinations) =>
    destinations.map((d) => d.id).toList();

void main() {
  final all = _generate(10000);
  final index = DestinationSearchIndex(all);

  group('DestinationSearchIndex at 10,000 destinations', () {
    test('an exact alias ranks first', () {
      final results = index.search('B4242', limit: 10);

      expect(results.first.id, 'POI-4242');
      expect(results.length, lessThanOrEqualTo(10));
    });

    test('top-K is bounded by the limit and keeps the best hits first', () {
      final top = index.search('block 42');
      final five = index.search('block 42', limit: 5);

      expect(top, hasLength(defaultSearchLimit));
      expect(five, hasLength(5));
      expect(_ids(five), _ids(top.take(5).toList()));
    });

    test('every prefix match really starts with the query', () {
      final results = index.search('block 42');

      expect(
        results,
        everyElement(
          predicate<Destination>((d) => d.name.toLowerCase().startsWith('block 42')),
        ),
      );
    });

    test('multi-word token matches contain every token', () {
      final results = index.search('room 9 block', limit: 200);

      expect(results, isNotEmpty);
      expect(
        results,
        everyElement(
          predicate<Destination>((d) {
            final name = d.name.toLowerCase();
            return name.contains('room') && name.contains('block');
          }),
        ),
      );
    });

    test('order is deterministic regardless of input order', () {
      final shuffled = [...all]..shuffle(Random(7));

      final expected = _ids(index.search('block 42'));

      expect(_ids(index.search('block 42')), expected);
      expect(_ids(DestinationSearchIndex(shuffled).search('block 42')), expected);
    });

    test('blank query returns every destination and no match returns none', () {
      expect(index.search('   '), same(all));
      expect(index.search('zzqx'), isEmpty);
    });

    test('duplicate ids are indexed once', () {
      final doubled = DestinationSearchIndex([...all, ...all]);

      expect(doubled.length, all.length);
      expect(_ids(doubled.search('B4242')), ['POI-4242']);
    });
  });
}
