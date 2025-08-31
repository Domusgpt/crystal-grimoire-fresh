import 'package:cloud_firestore/cloud_firestore.dart';

class Crystal {
  final String id;
  final String name;
  final String scientificName;
  final String variety;
  final String imageUrl;
  final Map<String, dynamic> metaphysicalProperties;
  final Map<String, dynamic> physicalProperties;
  final Map<String, dynamic> careInstructions;
  final List<String> healingProperties;
  final List<String> chakras;
  final List<String> zodiacSigns;
  final List<String> elements;
  final String description;
  DateTime? acquisitionDate;
  String? personalNotes;
  int usageCount;

  Crystal({
    required this.id,
    required this.name,
    required this.scientificName,
    this.variety = '',
    required this.imageUrl,
    required this.metaphysicalProperties,
    required this.physicalProperties,
    required this.careInstructions,
    required this.healingProperties,
    required this.chakras,
    required this.zodiacSigns,
    required this.elements,
    required this.description,
    this.acquisitionDate,
    this.personalNotes,
    this.usageCount = 0,
  });

  factory Crystal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Crystal(
      id: doc.id,
      name: data['name'] ?? '',
      scientificName: data['scientificName'] ?? '',
      variety: data['variety'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      metaphysicalProperties: data['metaphysicalProperties'] ?? {},
      physicalProperties: data['physicalProperties'] ?? {},
      careInstructions: data['careInstructions'] ?? {},
      healingProperties: List<String>.from(data['healingProperties'] ?? []),
      chakras: List<String>.from(data['chakras'] ?? []),
      zodiacSigns: List<String>.from(data['zodiacSigns'] ?? []),
      elements: List<String>.from(data['elements'] ?? []),
      description: data['description'] ?? '',
      acquisitionDate: data['acquisitionDate']?.toDate(),
      personalNotes: data['personalNotes'],
      usageCount: data['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'scientificName': scientificName,
      'variety': variety,
      'imageUrl': imageUrl,
      'metaphysicalProperties': metaphysicalProperties,
      'physicalProperties': physicalProperties,
      'careInstructions': careInstructions,
      'healingProperties': healingProperties,
      'chakras': chakras,
      'zodiacSigns': zodiacSigns,
      'elements': elements,
      'description': description,
      'acquisitionDate': acquisitionDate != null 
          ? Timestamp.fromDate(acquisitionDate!) 
          : null,
      'personalNotes': personalNotes,
      'usageCount': usageCount,
    };
  }
  
  // Helper method to get primary color for UI
  String get primaryColor {
    final colors = physicalProperties['colorRange'] as List<dynamic>?;
    if (colors != null && colors.isNotEmpty) {
      return colors.first.toString();
    }
    return 'Purple'; // Default color
  }
  
  // Helper method to get hardness rating
  String get hardness {
    return physicalProperties['hardness'] ?? 'Unknown';
  }
  
  // Helper method to check if crystal matches a chakra
  bool matchesChakra(String chakra) {
    return chakras.any((c) => 
      c.toLowerCase().contains(chakra.toLowerCase()));
  }
  
  // Helper method to check if crystal matches zodiac sign
  bool matchesZodiac(String sign) {
    return zodiacSigns.any((z) => 
      z.toLowerCase().contains(sign.toLowerCase()));
  }
}