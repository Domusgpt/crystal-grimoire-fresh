/// Enhanced Crystal model for collection tracking
/// This is a simplified version that works with the collection system

enum CrystalSystem {
  cubic,
  tetragonal,
  orthorhombic,
  hexagonal,
  trigonal,
  monoclinic,
  triclinic,
  unknown,
}

enum ChakraType {
  root,
  sacral,
  solarPlexus,
  heart,
  throat,
  thirdEye,
  crown,
  all,
}

enum Rarity {
  common,
  uncommon,
  rare,
  veryRare,
  exceptional,
}

class Crystal {
  final String name;
  final String scientificName;
  final String crystalFamily;
  final CrystalSystem crystalSystem;
  final double hardness;
  final List<ChakraType> chakras;
  final List<String> metaphysicalProperties;
  final String description;
  final String color;
  final Rarity rarity;
  
  // Legacy compatibility
  String get group => crystalFamily;

  Crystal({
    required this.name,
    required this.scientificName,
    required this.crystalFamily,
    required this.crystalSystem,
    required this.hardness,
    required this.chakras,
    required this.metaphysicalProperties,
    required this.description,
    required this.color,
    required this.rarity,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientificName': scientificName,
      'crystalFamily': crystalFamily,
      'crystalSystem': crystalSystem.name,
      'hardness': hardness,
      'chakras': chakras.map((c) => c.name).toList(),
      'metaphysicalProperties': metaphysicalProperties,
      'description': description,
      'color': color,
      'rarity': rarity.name,
    };
  }

  factory Crystal.fromJson(Map<String, dynamic> json) {
    return Crystal(
      name: json['name'] ?? '',
      scientificName: json['scientificName'] ?? '',
      crystalFamily: json['crystalFamily'] ?? 'Unknown',
      crystalSystem: CrystalSystem.values.firstWhere(
        (e) => e.name == json['crystalSystem'],
        orElse: () => CrystalSystem.unknown,
      ),
      hardness: (json['hardness'] ?? 0).toDouble(),
      chakras: (json['chakras'] as List?)
          ?.map((c) => ChakraType.values.firstWhere(
                (e) => e.name == c,
                orElse: () => ChakraType.heart,
              ))
          .toList() ?? [],
      metaphysicalProperties: List<String>.from(json['metaphysicalProperties'] ?? []),
      description: json['description'] ?? '',
      color: json['color'] ?? 'Various',
      rarity: Rarity.values.firstWhere(
        (e) => e.name == json['rarity'],
        orElse: () => Rarity.common,
      ),
    );
  }
}