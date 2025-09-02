import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_state.dart';
import '../widgets/common/mystical_button.dart';
import '../widgets/animations/mystical_animations.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with TickerProviderStateMixin {
  final TextEditingController _journalController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  List<JournalEntry> _entries = [];
  String _selectedMood = 'neutral';
  bool _isWriting = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    _loadEntries();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadEntries() {
    // Mock journal entries for demo
    setState(() {
      _entries = [
        JournalEntry(
          id: '1',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          content: 'Today I felt a deep connection with my amethyst during meditation. The energy was particularly strong during the full moon.',
          mood: 'peaceful',
          moonPhase: 'Full Moon',
        ),
        JournalEntry(
          id: '2',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          content: 'Working with rose quartz for heart chakra healing. Feeling more open to love and compassion.',
          mood: 'hopeful',
          moonPhase: 'Waning Gibbous',
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: Text(
          'Spiritual Journal',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _startNewEntry,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background particles
          const Positioned.fill(
            child: FloatingParticles(
              particleCount: 20,
              color: Colors.deepPurple,
            ),
          ),
          
          // Main content
          FadeTransition(
            opacity: _fadeAnimation,
            child: _isWriting ? _buildWritingView() : _buildJournalView(),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalView() {
    return Column(
      children: [
        // Moon phase indicator
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.indigo.withOpacity(0.6),
                Colors.purple.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.brightness_3, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                _getCurrentMoonPhase(),
                style: GoogleFonts.cinzel(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Journal entries list
        Expanded(
          child: _entries.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    return FadeScaleIn(
                      delay: Duration(milliseconds: index * 100),
                      child: _buildJournalEntryCard(_entries[index]),
                    );
                  },
                ),
        ),
        
        // Write new entry button
        Padding(
          padding: const EdgeInsets.all(16),
          child: MysticalButton(
            text: 'New Entry',
            icon: Icons.create,
            onPressed: _startNewEntry,
            color: Colors.purple,
            width: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildWritingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Mood selector
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.3),
                  Colors.indigo.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How are you feeling?',
                  style: GoogleFonts.cinzel(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildMoodChips(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Writing area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.indigo.withOpacity(0.2),
                    Colors.purple.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white24),
              ),
              child: TextField(
                controller: _journalController,
                maxLines: null,
                expands: true,
                style: GoogleFonts.crimsonText(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: 'Write about your spiritual journey, crystal experiences, dreams, or insights...',
                  hintStyle: GoogleFonts.crimsonText(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: MysticalButton(
                  text: 'Cancel',
                  onPressed: _cancelEntry,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MysticalButton(
                  text: 'Save',
                  icon: Icons.save,
                  onPressed: _saveEntry,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CrystalSparkle(
            size: 60,
            color: Colors.purple,
          ),
          const SizedBox(height: 24),
          Text(
            'Your spiritual journey awaits',
            style: GoogleFonts.cinzel(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start documenting your crystal experiences,\nmeditation insights, and spiritual growth',
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonText(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalEntryCard(JournalEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getMoodColor(entry.mood).withOpacity(0.3),
            _getMoodColor(entry.mood).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _getMoodColor(entry.mood).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date and mood
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.timestamp),
                style: GoogleFonts.cinzel(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMoodColor(entry.mood).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getMoodColor(entry.mood)),
                ),
                child: Text(
                  entry.mood,
                  style: GoogleFonts.cinzel(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Content
          Text(
            entry.content,
            style: GoogleFonts.crimsonText(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Moon phase
          Row(
            children: [
              const Icon(Icons.brightness_3, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                entry.moonPhase,
                style: GoogleFonts.cinzel(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMoodChips() {
    final moods = [
      {'name': 'peaceful', 'icon': Icons.self_improvement, 'color': Colors.blue},
      {'name': 'energetic', 'icon': Icons.flash_on, 'color': Colors.orange},
      {'name': 'grateful', 'icon': Icons.favorite, 'color': Colors.pink},
      {'name': 'reflective', 'icon': Icons.psychology, 'color': Colors.purple},
      {'name': 'anxious', 'icon': Icons.warning, 'color': Colors.red},
      {'name': 'hopeful', 'icon': Icons.wb_sunny, 'color': Colors.yellow},
      {'name': 'neutral', 'icon': Icons.sentiment_neutral, 'color': Colors.grey},
    ];

    return moods.map((mood) {
      final isSelected = _selectedMood == mood['name'];
      return FilterChip(
        label: Text(
          mood['name'] as String,
          style: GoogleFonts.cinzel(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        avatar: Icon(
          mood['icon'] as IconData,
          color: mood['color'] as Color,
          size: 18,
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedMood = mood['name'] as String;
          });
        },
        backgroundColor: Colors.transparent,
        selectedColor: (mood['color'] as Color).withOpacity(0.3),
        side: BorderSide(
          color: isSelected
              ? mood['color'] as Color
              : (mood['color'] as Color).withOpacity(0.5),
        ),
      );
    }).toList();
  }

  void _startNewEntry() {
    setState(() {
      _isWriting = true;
      _selectedMood = 'neutral';
      _journalController.clear();
    });
  }

  void _cancelEntry() {
    setState(() {
      _isWriting = false;
      _journalController.clear();
    });
  }

  void _saveEntry() {
    if (_journalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newEntry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      content: _journalController.text.trim(),
      mood: _selectedMood,
      moonPhase: _getCurrentMoonPhase(),
    );

    setState(() {
      _entries.insert(0, newEntry);
      _isWriting = false;
      _journalController.clear();
    });

    // Update app state
    context.read<AppState>().incrementUsage('journal_entry');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'peaceful':
        return Colors.blue;
      case 'energetic':
        return Colors.orange;
      case 'grateful':
        return Colors.pink;
      case 'reflective':
        return Colors.purple;
      case 'anxious':
        return Colors.red;
      case 'hopeful':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getCurrentMoonPhase() {
    // Mock moon phase calculation
    final phases = [
      'New Moon',
      'Waxing Crescent',
      'First Quarter',
      'Waxing Gibbous',
      'Full Moon',
      'Waning Gibbous',
      'Last Quarter',
      'Waning Crescent',
    ];
    
    final dayOfMonth = DateTime.now().day;
    return phases[dayOfMonth % phases.length];
  }
}

class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String content;
  final String mood;
  final String moonPhase;

  JournalEntry({
    required this.id,
    required this.timestamp,
    required this.content,
    required this.mood,
    required this.moonPhase,
  });
}