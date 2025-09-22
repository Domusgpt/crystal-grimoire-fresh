import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ConfidenceLevel {
  uncertain,
  low,
  medium,
  high,
  certain,
}

enum ChakraAssociation {
  root,
  sacral,
  solarPlexus,
  heart,
  throat,
  thirdEye,
  crown,
  all,
}

class Crystal {
  final String id;
  final String name;
  final String scientificName;
  final String group;
  final String description;
  final List<String> metaphysicalProperties;
  final List<String> healingProperties;
  final List<String> chakras;
  final List<String> elements;
  final Map<String, dynamic> properties;
  final String colorDescription;
  final String hardness;
  final String formation;
  final String careInstructions;
  final DateTime? identificationDate;
  final List<String> imageUrls;
  final ConfidenceLevel? confidence;
  final String? userNotes;
  
  // Auto-classified metaphysical properties
  final String type;
  final String color;
  final String imageUrl;
  final List<String> planetaryRulers;
  final List<String> zodiacSigns;
  final String crystalSystem;
  final List<String> formations;
  final List<String> chargingMethods;
  final List<String> cleansingMethods;
  final List<String> bestCombinations;
  final List<String> recommendedIntentions;
  final String vibrationFrequency;
  final String energyType;
  final String bestTimeToUse;
  final String effectDuration;
  final Map<String, dynamic> birthChartAlignment;
  final List<String> keywords;

  Crystal({
    required this.id,
    required this.name,
    required this.scientificName,
    this.group = 'Unknown',
    required this.description,
    this.metaphysicalProperties = const [],
    this.healingProperties = const [],
    this.chakras = const [],
    
    // Auto-classified properties
    this.type = 'Unknown',
    this.color = 'Unknown',
    this.imageUrl = '',
    this.planetaryRulers = const [],
    this.zodiacSigns = const [],
    this.crystalSystem = 'Unknown',
    this.formations = const [],
    this.chargingMethods = const [],
    this.cleansingMethods = const [],
    this.bestCombinations = const [],
    this.recommendedIntentions = const [],
    this.vibrationFrequency = 'Medium',
    this.energyType = 'Balancing',
    this.bestTimeToUse = 'Anytime',
    this.effectDuration = 'Hours',
    this.birthChartAlignment = const {},
    this.keywords = const [],
    this.elements = const [],
    this.properties = const {},
    this.colorDescription = '',
    this.hardness = '',
    this.formation = '',
    required this.careInstructions,
    this.identificationDate,
    this.imageUrls = const [],
    this.confidence,
    this.userNotes,
  });

  factory Crystal.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Crystal(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Crystal',
      scientificName: json['scientificName'] ?? '',
      group: json['group'] ?? 'Unknown',
      description: json['description'] ?? '',
      metaphysicalProperties: List<String>.from(json['metaphysicalProperties'] ?? []),
      healingProperties: List<String>.from(json['healingProperties'] ?? []),
      chakras: List<String>.from(json['chakras'] ?? []),
      elements: List<String>.from(json['elements'] ?? []),
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      colorDescription: json['colorDescription'] ?? '',
      hardness: json['hardness'] ?? '',
      formation: json['formation'] ?? '',
      careInstructions: json['careInstructions'] ?? '',
      identificationDate: parseDate(json['identificationDate']),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      confidence: json['confidence'] != null 
          ? ConfidenceLevel.values.byName(json['confidence']) 
          : null,
      userNotes: json['userNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scientificName': scientificName,
      'group': group,
      'description': description,
      'metaphysicalProperties': metaphysicalProperties,
      'healingProperties': healingProperties,
      'chakras': chakras,
      'elements': elements,
      'properties': properties,
      'colorDescription': colorDescription,
      'hardness': hardness,
      'formation': formation,
      'careInstructions': careInstructions,
      'identificationDate': identificationDate?.toIso8601String(),
      'imageUrls': imageUrls,
      'confidence': confidence?.name,
      'userNotes': userNotes,
    };
  }

  Crystal copyWith({
    String? id,
    String? name,
    String? scientificName,
    String? group,
    String? description,
    List<String>? metaphysicalProperties,
    List<String>? healingProperties,
    List<String>? chakras,
    List<String>? elements,
    Map<String, dynamic>? properties,
    String? colorDescription,
    String? hardness,
    String? formation,
    String? careInstructions,
    DateTime? identificationDate,
    List<String>? imageUrls,
    ConfidenceLevel? confidence,
    String? userNotes,
  }) {
    return Crystal(
      id: id ?? this.id,
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      group: group ?? this.group,
      description: description ?? this.description,
      metaphysicalProperties: metaphysicalProperties ?? this.metaphysicalProperties,
      healingProperties: healingProperties ?? this.healingProperties,
      chakras: chakras ?? this.chakras,
      elements: elements ?? this.elements,
      properties: properties ?? this.properties,
      colorDescription: colorDescription ?? this.colorDescription,
      hardness: hardness ?? this.hardness,
      formation: formation ?? this.formation,
      careInstructions: careInstructions ?? this.careInstructions,
      identificationDate: identificationDate ?? this.identificationDate,
      imageUrls: imageUrls ?? this.imageUrls,
      confidence: confidence ?? this.confidence,
      userNotes: userNotes ?? this.userNotes,
    );
  }
}

class CrystalIdentification {
  final String sessionId;
  final String fullResponse;
  final Crystal? crystal;
  final double confidence; // Changed to double for compatibility
  final bool needsMoreInfo;
  final List<String> suggestedAngles;
  final List<String> observedFeatures;
  final String mysticalMessage; // Renamed from spiritualMessage
  final DateTime timestamp;

  CrystalIdentification({
    required this.sessionId,
    required this.fullResponse,
    this.crystal,
    required this.confidence,
    this.needsMoreInfo = false,
    this.suggestedAngles = const [],
    this.observedFeatures = const [],
    required this.mysticalMessage,
    required this.timestamp,
  });

  factory CrystalIdentification.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return CrystalIdentification(
      sessionId: json['sessionId'] ?? '',
      fullResponse: json['fullResponse'] ?? '',
      crystal: json['crystal'] != null ? Crystal.fromJson(json['crystal']) : null,
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      needsMoreInfo: json['needsMoreInfo'] ?? false,
      suggestedAngles: List<String>.from(json['suggestedAngles'] ?? []),
      observedFeatures: List<String>.from(json['observedFeatures'] ?? []),
      mysticalMessage: json['mysticalMessage'] ?? json['spiritualMessage'] ?? '',
      timestamp: parseDate(json['timestamp'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'fullResponse': fullResponse,
      'crystal': crystal?.toJson(),
      'confidence': confidence,
      'needsMoreInfo': needsMoreInfo,
      'suggestedAngles': suggestedAngles,
      'observedFeatures': observedFeatures,
      'mysticalMessage': mysticalMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// Extension methods for convenience
extension ConfidenceLevelExtension on ConfidenceLevel {
  String get displayName {
    switch (this) {
      case ConfidenceLevel.uncertain:
        return 'Uncertain';
      case ConfidenceLevel.low:
        return 'Low';
      case ConfidenceLevel.medium:
        return 'Medium';
      case ConfidenceLevel.high:
        return 'High';
      case ConfidenceLevel.certain:
        return 'Certain';
    }
  }

  double get percentage {
    switch (this) {
      case ConfidenceLevel.uncertain:
        return 0.2;
      case ConfidenceLevel.low:
        return 0.4;
      case ConfidenceLevel.medium:
        return 0.6;
      case ConfidenceLevel.high:
        return 0.8;
      case ConfidenceLevel.certain:
        return 1.0;
    }
  }
}

extension ChakraAssociationExtension on ChakraAssociation {
  String get displayName {
    switch (this) {
      case ChakraAssociation.root:
        return 'Root Chakra';
      case ChakraAssociation.sacral:
        return 'Sacral Chakra';
      case ChakraAssociation.solarPlexus:
        return 'Solar Plexus Chakra';
      case ChakraAssociation.heart:
        return 'Heart Chakra';
      case ChakraAssociation.throat:
        return 'Throat Chakra';
      case ChakraAssociation.thirdEye:
        return 'Third Eye Chakra';
      case ChakraAssociation.crown:
        return 'Crown Chakra';
      case ChakraAssociation.all:
        return 'All Chakras';
    }
  }

  String get emoji {
    switch (this) {
      case ChakraAssociation.root:
        return '🔴';
      case ChakraAssociation.sacral:
        return '🟠';
      case ChakraAssociation.solarPlexus:
        return '🟡';
      case ChakraAssociation.heart:
        return '💚';
      case ChakraAssociation.throat:
        return '🔵';
      case ChakraAssociation.thirdEye:
        return '🟣';
      case ChakraAssociation.crown:
        return '🤍';
      case ChakraAssociation.all:
        return '🌈';
    }
  }
}