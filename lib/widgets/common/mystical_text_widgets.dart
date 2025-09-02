import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../animations/mystical_animations.dart';
import 'mystical_card.dart';

class ShimmeringText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color? shimmerColor;
  final Duration duration;

  const ShimmeringText({
    Key? key,
    required this.text,
    this.style,
    this.shimmerColor,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<ShimmeringText> createState() => _ShimmeringTextState();
}

class _ShimmeringTextState extends State<ShimmeringText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shimmerColor = widget.shimmerColor ?? Colors.white;
    final baseStyle = widget.style ?? GoogleFonts.cinzel(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseStyle.color!,
                shimmerColor,
                baseStyle.color!,
              ],
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: baseStyle,
          ),
        );
      },
    );
  }
}

class CrystalInfoCard extends StatelessWidget {
  final String crystalName;
  final String subtitle;
  final String? description;
  final List<String> properties;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CrystalInfoCard({
    Key? key,
    required this.crystalName,
    required this.subtitle,
    this.description,
    this.properties = const [],
    this.icon = Icons.diamond,
    this.color = Colors.purple,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MysticalCard(
      primaryColor: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crystalName,
                      style: GoogleFonts.cinzel(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.crimsonText(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description!,
              style: GoogleFonts.crimsonText(
                fontSize: 14,
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
          
          if (properties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: properties.map((property) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    property,
                    style: GoogleFonts.cinzel(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}