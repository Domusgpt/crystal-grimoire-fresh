import 'package:test/test.dart';
import 'package:crystal_grimoire_fresh/models/crystal_model.dart';

void main() {
  test('matchesChakra is case-insensitive and supports substrings', () {
    final crystal = Crystal(
      id: '1',
      name: 'Test',
      scientificName: 'Testus',
      variety: '',
      imageUrl: '',
      metaphysicalProperties: {},
      physicalProperties: {},
      careInstructions: {},
      healingProperties: const [],
      chakras: const ['Heart Chakra', 'Third Eye'],
      zodiacSigns: const [],
      elements: const [],
      description: '',
    );

    expect(crystal.matchesChakra('heart'), isTrue);
    expect(crystal.matchesChakra('HEART'), isTrue);
    expect(crystal.matchesChakra('eye'), isTrue);
    expect(crystal.matchesChakra('root'), isFalse);
  });
}
