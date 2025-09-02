import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/crystal_database.dart';
import '../widgets/common/mystical_card.dart';

class SimpleCrystalCard extends StatelessWidget {
  final CrystalData crystal;
  final VoidCallback? onTap;

  const SimpleCrystalCard({
    Key? key,
    required this.crystal,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: _getCrystalColor(crystal.color),
      enableGlow: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Crystal of the Day',
                style: GoogleFonts.cinzel(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Crystal info
          Row(
            children: [
              // Crystal icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _getCrystalColor(crystal.color),
                      _getCrystalColor(crystal.color).withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getCrystalColor(crystal.color).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.diamond,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Crystal details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crystal.name,
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crystal.type,
                      style: GoogleFonts.crimsonText(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      crystal.description,
                      style: GoogleFonts.crimsonText(
                        fontSize: 12,
                        color: Colors.white60,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Properties
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: crystal.properties.take(3).map((property) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCrystalColor(crystal.color).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getCrystalColor(crystal.color).withOpacity(0.5),
                  ),
                ),
                child: Text(
                  property,
                  style: GoogleFonts.cinzel(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getCrystalColor(String color) {
    switch (color.toLowerCase()) {
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'clear':
      case 'white':
        return Colors.white;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }
}