import 'dart:math';
import '../data/crystal_database.dart';

class OfflineCrystalService {
  static final Random _random = Random();

  /// Simulates crystal identification based on color and characteristics
  static CrystalData? identifyCrystalByColor(String colorDescription) {
    final lowerColor = colorDescription.toLowerCase();
    
    // Search for crystals matching the color
    final matches = CrystalDatabase.crystals.where((crystal) {
      final crystalColor = crystal.colorDescription.toLowerCase();
      return crystalColor.contains(lowerColor) ||
             lowerColor.contains(crystalColor.split(',').first.trim()) ||
             _isColorMatch(lowerColor, crystalColor);
    }).toList();
    
    if (matches.isEmpty) {
      // Return a random crystal if no color match
      return CrystalDatabase.crystals[_random.nextInt(CrystalDatabase.crystals.length)];
    }
    
    // Return the best match or random from matches
    return matches[_random.nextInt(matches.length)];
  }

  /// Advanced color matching algorithm
  static bool _isColorMatch(String input, String crystalColor) {
    final colorMap = {
      'purple': ['violet', 'lavender', 'amethyst', 'indigo'],
      'pink': ['rose', 'blush', 'coral'],
      'blue': ['azure', 'sapphire', 'cobalt', 'navy'],
      'green': ['emerald', 'jade', 'mint', 'forest'],
      'yellow': ['gold', 'amber', 'citrine', 'honey'],
      'black': ['obsidian', 'onyx', 'jet', 'dark'],
      'white': ['clear', 'milky', 'opal', 'pearl'],
      'red': ['crimson', 'ruby', 'scarlet', 'garnet'],
      'orange': ['amber', 'peach', 'coral', 'tangerine'],
      'brown': ['chocolate', 'bronze', 'copper', 'mahogany'],
    };
    
    for (final entry in colorMap.entries) {
      final mainColor = entry.key;
      final variations = entry.value;
      
      if (input.contains(mainColor) || crystalColor.contains(mainColor)) {
        return true;
      }
      
      for (final variation in variations) {
        if (input.contains(variation) || crystalColor.contains(variation)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Generate spiritual guidance based on crystal properties
  static String generateGuidance(CrystalData crystal) {
    final guidanceTemplates = [
      'The ${crystal.name} you\'ve discovered resonates with ${crystal.chakras.join(" and ")} chakra${crystal.chakras.length > 1 ? "s" : ""}. ${crystal.metaphysicalProperties.first}',
      'This beautiful ${crystal.colorDescription} crystal brings powerful energy. ${crystal.metaphysicalProperties[_random.nextInt(crystal.metaphysicalProperties.length)]}',
      'Your ${crystal.name} is calling you to focus on ${_getRandomFocus(crystal)}. ${crystal.healing[_random.nextInt(crystal.healing.length)]}',
      'The universe has guided you to ${crystal.name} for a reason. Its ${crystal.hardness} hardness on the Mohs scale represents ${_getHardnessMetaphor(crystal.hardness)}.',
    ];
    
    return guidanceTemplates[_random.nextInt(guidanceTemplates.length)];
  }

  static String _getRandomFocus(CrystalData crystal) {
    final focuses = [];
    
    if (crystal.chakras.contains('Heart')) focuses.add('love and compassion');
    if (crystal.chakras.contains('Third Eye')) focuses.add('intuition and inner wisdom');
    if (crystal.chakras.contains('Crown')) focuses.add('spiritual connection');
    if (crystal.chakras.contains('Root')) focuses.add('grounding and stability');
    if (crystal.chakras.contains('Solar Plexus')) focuses.add('personal power');
    if (crystal.chakras.contains('Throat')) focuses.add('communication and truth');
    if (crystal.chakras.contains('Sacral')) focuses.add('creativity and passion');
    
    if (focuses.isEmpty) return 'personal growth';
    return focuses[_random.nextInt(focuses.length)];
  }

  static String _getHardnessMetaphor(double hardness) {
    if (hardness >= 7) return 'strength and resilience in your spiritual journey';
    if (hardness >= 5) return 'balance between flexibility and stability';
    if (hardness >= 3) return 'gentleness and adaptability in transformation';
    return 'softness and receptivity to spiritual energies';
  }

  /// Get a daily crystal recommendation
  static CrystalData getDailyCrystal() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final index = dayOfYear % CrystalDatabase.crystals.length;
    return CrystalDatabase.crystals[index];
  }

  /// Get crystals for specific intentions
  static List<CrystalData> getCrystalsForIntention(String intention) {
    final lowerIntention = intention.toLowerCase();
    
    final intentionMap = {
      'love': ['rose_quartz', 'malachite'],
      'protection': ['black_tourmaline', 'obsidian'],
      'abundance': ['citrine', 'malachite'],
      'clarity': ['clear_quartz', 'selenite'],
      'intuition': ['amethyst', 'labradorite', 'lapis_lazuli'],
      'healing': ['clear_quartz', 'malachite', 'rose_quartz'],
      'grounding': ['black_tourmaline', 'obsidian'],
      'transformation': ['labradorite', 'malachite'],
      'wisdom': ['lapis_lazuli', 'amethyst'],
      'peace': ['selenite', 'amethyst'],
    };
    
    for (final entry in intentionMap.entries) {
      if (lowerIntention.contains(entry.key)) {
        return entry.value
            .map((id) => CrystalDatabase.getCrystalById(id))
            .where((crystal) => crystal != null)
            .cast<CrystalData>()
            .toList();
      }
    }
    
    // Return random selection if no match
    return CrystalDatabase.crystals.take(3).toList();
  }

  /// Generate a personalized crystal reading
  static Map<String, dynamic> generateReading() {
    final crystal = CrystalDatabase.crystals[_random.nextInt(CrystalDatabase.crystals.length)];
    final moonPhase = _getCurrentMoonPhase();
    final dayEnergy = _getDayEnergy();
    
    return {
      'crystal': crystal,
      'message': _generatePersonalMessage(crystal, moonPhase, dayEnergy),
      'affirmation': _generateAffirmation(crystal),
      'ritual': _generateRitual(crystal),
      'moonPhase': moonPhase,
      'dayEnergy': dayEnergy,
    };
  }

  static String _getCurrentMoonPhase() {
    final phases = ['New Moon', 'Waxing Crescent', 'First Quarter', 'Waxing Gibbous', 
                   'Full Moon', 'Waning Gibbous', 'Last Quarter', 'Waning Crescent'];
    final daysSinceNewMoon = DateTime.now().difference(DateTime(2024, 1, 11)).inDays % 29.5;
    final phaseIndex = (daysSinceNewMoon / 29.5 * 8).round() % 8;
    return phases[phaseIndex];
  }

  static String _getDayEnergy() {
    final day = DateTime.now().weekday;
    const dayEnergies = {
      1: 'Fresh Beginnings', // Monday
      2: 'Building Momentum', // Tuesday
      3: 'Communication', // Wednesday
      4: 'Expansion', // Thursday
      5: 'Love & Beauty', // Friday
      6: 'Wisdom & Reflection', // Saturday
      7: 'Rest & Renewal', // Sunday
    };
    return dayEnergies[day] ?? 'Balance';
  }

  static String _generatePersonalMessage(CrystalData crystal, String moonPhase, String dayEnergy) {
    return 'Today\'s $dayEnergy energy combined with the $moonPhase makes ${crystal.name} '
           'especially powerful for you. ${crystal.metaphysicalProperties.first} '
           'Focus on ${crystal.chakras.first} chakra work today.';
  }

  static String _generateAffirmation(CrystalData crystal) {
    final affirmations = [
      'I am aligned with the ${crystal.name}\'s energy of ${crystal.keywords.first}',
      'My ${crystal.chakras.first} chakra radiates with ${crystal.colorDescription} light',
      'I embrace the ${crystal.keywords.join(", ")} that ${crystal.name} brings',
      'The wisdom of ${crystal.name} flows through me',
    ];
    return affirmations[_random.nextInt(affirmations.length)];
  }

  static String _generateRitual(CrystalData crystal) {
    final rituals = [
      'Hold ${crystal.name} during meditation and visualize ${crystal.colorDescription} light filling your ${crystal.chakras.first} chakra',
      'Place ${crystal.name} under your pillow tonight to enhance ${crystal.metaphysicalProperties.last}',
      'Carry ${crystal.name} in your left pocket to receive its ${crystal.keywords.first} energy throughout the day',
      'Create a crystal grid with ${crystal.name} at the center to amplify ${crystal.healing.first}',
    ];
    return rituals[_random.nextInt(rituals.length)];
  }
}