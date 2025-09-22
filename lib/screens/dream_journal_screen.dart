import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../services/crystal_service.dart';
import '../widgets/animations/mystical_animations.dart';
import '../widgets/common/mystical_button.dart';

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
  
  List<DreamEntry> _entries = [];
  StreamSubscription<QuerySnapshot>? _dreamSubscription;
  String? _errorMessage;
  String _selectedMood = 'neutral';
  bool _isWriting = false;
  bool _isSavingEntry = false;

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
    _listenToDreamEntries();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _dreamSubscription?.cancel();
    super.dispose();
  }

  void _listenToDreamEntries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _entries = [];
        _errorMessage = 'Please sign in to use the dream journal.';
      });
      return;
    }

    _dreamSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('dreams')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final entries = snapshot.docs
          .map((doc) => DreamEntry.fromDocument(doc))
          .toList();
      setState(() {
        _entries = entries;
        _errorMessage = null;
      });
    }, onError: (error) {
      setState(() {
        _errorMessage = 'Failed to load dream journal: $error';
      });
    });
  }

  Future<List<String>> _fetchUserCrystals(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('collection')
          .limit(50)
          .get();

      final names = snapshot.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] ?? data['crystalName'];
        return name is String ? name : null;
      }).whereType<String>().toSet();

      return names.toList();
    } catch (_) {
      return [];
    }
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
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            MysticalButton(
              text: 'Refresh',
              onPressed: () {
                _dreamSubscription?.cancel();
                _listenToDreamEntries();
              },
              color: Colors.deepPurple,
            ),
          ],
        ),
      );
    }

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
                child: AbsorbPointer(
                  absorbing: _isSavingEntry,
                  child: MysticalButton(
                    text: _isSavingEntry ? 'Saving...' : 'Save',
                    icon: _isSavingEntry ? Icons.hourglass_top : Icons.save,
                    onPressed: _isSavingEntry ? () {} : _saveEntry,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          if (_isSavingEntry) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.greenAccent),
          ],
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

  Widget _buildJournalEntryCard(DreamEntry entry) {
    final color = _getMoodColor(entry.mood);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.35),
            color.withOpacity(0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(entry.dreamDate ?? entry.createdAt),
                style: GoogleFonts.cinzel(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (entry.mood != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    entry.mood!,
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

          Text(
            entry.content,
            style: GoogleFonts.crimsonText(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          if (entry.crystalsUsed.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: entry.crystalsUsed
                  .map(
                    (crystal) => Chip(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      label: Text(
                        crystal,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Text(
              entry.analysis,
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.brightness_3, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                entry.moonPhase ?? 'Moon cycle unfolding',
                style: GoogleFonts.cinzel(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Icon(Icons.timelapse, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                _formatDate(entry.createdAt),
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

  Future<void> _saveEntry() async {
    if (_journalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to save journal entries'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSavingEntry = true;
    });

    try {
      final content = _journalController.text.trim();
      final moonPhase = _getCurrentMoonPhase();
      final dreamDate = DateTime.now();
      final crystals = await _fetchUserCrystals(user.uid);

      Map<String, dynamic>? analysisResult;
      try {
        final crystalService = context.read<CrystalService>();
        analysisResult = await crystalService.analyzeDream(
          dreamContent: content,
          userCrystals: crystals,
          dreamDate: dreamDate,
          mood: _selectedMood,
          moonPhase: moonPhase,
        );
      } catch (e) {
        analysisResult = {
          'analysis':
              'Unable to generate AI insight right now. Reflect gently on your dream and revisit soon.',
        };
      }

      final analysisText = (analysisResult?['analysis'] as String?) ??
          'Dream captured. Mystical insights will be available shortly.';
      final entryId = analysisResult?['entryId'] as String?;
      final suggestions = analysisResult?['crystalSuggestions'] as List<dynamic>? ?? const [];

      if (entryId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dreams')
            .doc(entryId)
            .set({
          'mood': _selectedMood,
          'moonPhase': moonPhase,
          'crystalsUsed': crystals,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('dreams')
            .add({
          'content': content,
          'analysis': analysisText,
          'crystalSuggestions': suggestions,
          'crystalsUsed': crystals,
          'dreamDate': Timestamp.fromDate(dreamDate),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'mood': _selectedMood,
          'moonPhase': moonPhase,
        });
      }

      if (!mounted) return;

      context.read<AppState>().incrementUsage('journal_entry');

      setState(() {
        _isWriting = false;
        _journalController.clear();
        _selectedMood = 'neutral';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save entry: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingEntry = false;
        });
      }
    }
  }

  Color _getMoodColor(String? mood) {
    switch (mood) {
      case 'peaceful':
        return Colors.blue;
      case 'energetic':
        return Colors.orange;
      case 'grateful':
        return Colors.pinkAccent;
      case 'reflective':
        return Colors.purple;
      case 'anxious':
        return Colors.redAccent;
      case 'hopeful':
        return Colors.yellow.shade600;
      case 'neutral':
        return Colors.teal;
      default:
        return Colors.indigo;
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
    const phases = [
      'New Moon',
      'Waxing Crescent',
      'First Quarter',
      'Waxing Gibbous',
      'Full Moon',
      'Waning Gibbous',
      'Last Quarter',
      'Waning Crescent',
    ];

    final now = DateTime.now().toUtc();
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14); // NASA reference
    const synodicMonth = 29.530588853; // days
    final daysSince = now.difference(knownNewMoon).inMilliseconds /
        Duration.millisecondsPerDay;
    final normalized = (daysSince % synodicMonth) / synodicMonth;
    final index = ((normalized * phases.length) + 0.5).floor() % phases.length;
    return phases[index];
  }
}

class DreamEntry {
  final String id;
  final String content;
  final String analysis;
  final List<String> crystalsUsed;
  final List<Map<String, dynamic>> crystalSuggestions;
  final DateTime? dreamDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? mood;
  final String? moonPhase;

  DreamEntry({
    required this.id,
    required this.content,
    required this.analysis,
    required this.crystalsUsed,
    required this.crystalSuggestions,
    required this.dreamDate,
    required this.createdAt,
    required this.updatedAt,
    required this.mood,
    required this.moonPhase,
  });

  factory DreamEntry.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final suggestionsRaw = data['crystalSuggestions'] as List<dynamic>? ?? const [];
    final suggestions = suggestionsRaw.map((item) {
      if (item is Map<String, dynamic>) {
        return item;
      }
      if (item is Map) {
        return Map<String, dynamic>.from(item);
      }
      return {'name': item?.toString() ?? 'Crystal Ally'};
    }).toList();

    DateTime resolveDate(dynamic value, {DateTime? fallback}) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      return fallback ?? DateTime.now();
    }

    final createdAtRaw = data['createdAt'] ?? data['timestamp'];
    final updatedAtRaw = data['updatedAt'];

    return DreamEntry(
      id: doc.id,
      content: data['content'] as String? ?? 'Dream entry',
      analysis: data['analysis'] as String? ??
          'Guidance will appear here once analysis completes.',
      crystalsUsed:
          List<String>.from((data['crystalsUsed'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())),
      crystalSuggestions:
          suggestions.map((entry) => Map<String, dynamic>.from(entry)).toList(),
      dreamDate: (data['dreamDate'] as Timestamp?)?.toDate(),
      createdAt: resolveDate(createdAtRaw),
      updatedAt: data['updatedAt'] != null
          ? resolveDate(updatedAtRaw, fallback: null)
          : null,
      mood: data['mood'] as String?,
      moonPhase: data['moonPhase'] as String?,
    );
  }
}