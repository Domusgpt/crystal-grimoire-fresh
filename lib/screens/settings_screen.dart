import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/environment_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _meditationReminder = 'Daily';
  String _crystalReminder = 'Weekly';
  bool _shareUsageData = true;
  bool _contentWarnings = true;
  String _selectedLanguage = 'en';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic> _settings = {};
  final EnvironmentConfig _config = EnvironmentConfig.instance;

  static const Map<String, String> _languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _user = FirebaseAuth.instance.currentUser;
      if (_user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      final rawSettings = doc.data()?['settings'] ?? {};
      final merged = <String, dynamic>{
        'notifications': rawSettings['notifications'] ?? true,
        'darkMode': rawSettings['darkMode'] ?? true,
        'sound': rawSettings['sound'] ?? true,
        'vibration': rawSettings['vibration'] ?? true,
        'meditationReminder': rawSettings['meditationReminder'] ?? 'Daily',
        'crystalReminder': rawSettings['crystalReminder'] ?? 'Weekly',
        'shareUsageData': rawSettings['shareUsageData'] ?? true,
        'contentWarnings': rawSettings['contentWarnings'] ?? true,
        'language': rawSettings['language'] ?? 'en',
      };

      if (!mounted) return;
      setState(() {
        _settings = merged;
        _notificationsEnabled = merged['notifications'];
        _darkModeEnabled = merged['darkMode'];
        _soundEnabled = merged['sound'];
        _vibrationEnabled = merged['vibration'];
        _meditationReminder = merged['meditationReminder'];
        _crystalReminder = merged['crystalReminder'];
        _shareUsageData = merged['shareUsageData'];
        _contentWarnings = merged['contentWarnings'];
        _selectedLanguage = merged['language'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load settings: $e';
        _isLoading = false;
      });
    }
  }

  void _showSnack(String message, {Color background = Colors.amber}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _openWebsiteLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty) {
      _showSnack('Link is not configured yet.', background: Colors.orange);
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!launched) {
        _showSnack('Unable to open link. Please try again later.', background: Colors.redAccent);
      }
    } catch (e) {
      _showSnack('Failed to open link: $e', background: Colors.redAccent);
    }
  }

  Future<void> _openSupportChannel() async {
    if (_config.supportUrl.isNotEmpty) {
      await _openWebsiteLink(_config.supportUrl);
      return;
    }

    final mailUri = Uri(
      scheme: 'mailto',
      path: _config.supportEmail,
      queryParameters: {
        'subject': 'Crystal Grimoire Support',
      },
    );

    try {
      await launchUrl(mailUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      _showSnack('Failed to open mail client: $e', background: Colors.redAccent);
    }
  }

  Future<void> _persistSettings({bool showMessage = false}) async {
    if (_user == null) {
      setState(() {
        _errorMessage = 'You must be signed in to update settings';
      });
      return;
    }

    final payload = <String, dynamic>{
      ..._settings,
      'notifications': _notificationsEnabled,
      'darkMode': _darkModeEnabled,
      'sound': _soundEnabled,
      'vibration': _vibrationEnabled,
      'meditationReminder': _meditationReminder,
      'crystalReminder': _crystalReminder,
      'shareUsageData': _shareUsageData,
      'contentWarnings': _contentWarnings,
      'language': _selectedLanguage,
    };

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _firestore.collection('users').doc(_user!.uid).set({
        'settings': payload,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _settings = payload;
        _isSaving = false;
      });

      if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings updated'),
            backgroundColor: Colors.purple[400],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to save settings: $e';
        _isSaving = false;
      });
    }
  }

  String get _languageLabel => _languages[_selectedLanguage] ?? 'English';

  Future<void> _showLanguageSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          children: _languages.entries.map((entry) {
            return RadioListTile<String>(
              value: entry.key,
              groupValue: _selectedLanguage,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
              activeColor: Colors.purple,
              title: Text(
                entry.value,
                style: GoogleFonts.crimsonText(color: Colors.white),
              ),
            );
          }).toList(),
        );
      },
    );

    if (selected != null && selected != _selectedLanguage) {
      setState(() {
        _selectedLanguage = selected;
      });
      _persistSettings(showMessage: true);
    }
  }

  Future<void> _showPrivacySheet() async {
    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      backgroundColor: const Color(0xFF1A1A3A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      builder: (context) {
        bool shareUsage = _shareUsageData;
        bool contentWarnings = _contentWarnings;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Privacy & Safety',
                    style: GoogleFonts.cinzel(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: shareUsage,
                    onChanged: (value) {
                      setModalState(() => shareUsage = value);
                    },
                    activeColor: Colors.purple,
                    title: Text(
                      'Share anonymized usage analytics',
                      style: GoogleFonts.crimsonText(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Helps improve guidance accuracy and feature planning',
                      style: GoogleFonts.crimsonText(color: Colors.white70),
                    ),
                  ),
                  SwitchListTile(
                    value: contentWarnings,
                    onChanged: (value) {
                      setModalState(() => contentWarnings = value);
                    },
                    activeColor: Colors.purple,
                    title: Text(
                      'Enable content warnings',
                      style: GoogleFonts.crimsonText(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Warns before sensitive dream or ritual insights',
                      style: GoogleFonts.crimsonText(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, {
                          'shareUsageData': shareUsage,
                          'contentWarnings': contentWarnings,
                        });
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _shareUsageData = result['shareUsageData'] ?? _shareUsageData;
        _contentWarnings = result['contentWarnings'] ?? _contentWarnings;
      });
      _persistSettings(showMessage: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.cinzel(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) _buildErrorBanner(),
                      _buildSectionTitle('Notifications'),
                      _buildNotificationSettings(),
                      const SizedBox(height: 30),

                      _buildSectionTitle('App Preferences'),
                      _buildAppPreferences(),
                      const SizedBox(height: 30),

                      _buildSectionTitle('Reminders'),
                      _buildReminderSettings(),
                      const SizedBox(height: 30),

                      _buildSectionTitle('Account'),
                      _buildAccountSettings(),
                      const SizedBox(height: 30),

                      _buildSectionTitle('About'),
                      _buildAboutSection(),
                    ],
                  ),
                ),
                if (_isSaving)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.purple[300],
        ),
      ),
    );
  }
  
  Widget _buildNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'Push Notifications',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              'Receive crystal insights and reminders',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _persistSettings();
            },
            activeColor: Colors.purple,
          ),
          const Divider(color: Colors.white24),
          SwitchListTile(
            title: Text(
              'Sound Effects',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              'Play sounds for interactions',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
              _persistSettings();
            },
            activeColor: Colors.purple,
          ),
          const Divider(color: Colors.white24),
          SwitchListTile(
            title: Text(
              'Vibration',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              'Haptic feedback for actions',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
              _persistSettings();
            },
            activeColor: Colors.purple,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppPreferences() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              'Dark Mode',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              'Use dark theme throughout the app',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
              _persistSettings();
            },
            activeColor: Colors.purple,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            title: Text(
              'Language',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              _languageLabel,
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
            onTap: _showLanguageSheet,
          ),
        ],
      ),
    );
  }
  
  Widget _buildReminderSettings() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Meditation Reminders',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              _meditationReminder,
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            trailing: DropdownButton<String>(
              value: _meditationReminder,
              dropdownColor: const Color(0xFF1A1A3A),
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 14,
              ),
              items: ['Never', 'Daily', 'Weekly', 'Monthly']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _meditationReminder = value!;
                });
                _persistSettings();
              },
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            title: Text(
              'Crystal Care Reminders',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              _crystalReminder,
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            trailing: DropdownButton<String>(
              value: _crystalReminder,
              dropdownColor: const Color(0xFF1A1A3A),
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 14,
              ),
              items: ['Never', 'Daily', 'Weekly', 'Monthly']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _crystalReminder = value!;
                });
                _persistSettings();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAccountSettings() {
    final user = FirebaseAuth.instance.currentUser;
    
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple,
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user?.displayName ?? 'User',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              user?.email ?? '',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.edit, color: Colors.purple),
            title: Text(
              'Edit Profile',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: Icon(Icons.security, color: Colors.purple),
            title: Text(
              'Privacy & Security',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            onTap: _showPrivacySheet,
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text(
              'Sign Out',
              style: GoogleFonts.crimsonText(
                color: Colors.red,
                fontSize: 18,
              ),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A3A),
                  title: Text(
                    'Sign Out',
                    style: GoogleFonts.cinzel(color: Colors.white),
                  ),
                  content: Text(
                    'Are you sure you want to sign out?',
                    style: GoogleFonts.crimsonText(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AuthService.signOutAndRedirect(context);
              }
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info, color: Colors.purple),
            title: Text(
              'Version',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            subtitle: Text(
              '1.0.0',
              style: GoogleFonts.crimsonText(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.article, color: Colors.purple),
            title: Text(
              'Terms of Service',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            onTap: () => _openWebsiteLink(_config.termsUrl),
          ),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Colors.purple),
            title: Text(
              'Privacy Policy',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            onTap: () => _openWebsiteLink(_config.privacyUrl),
          ),
          ListTile(
            leading: Icon(Icons.help, color: Colors.purple),
            title: Text(
              'Help & Support',
              style: GoogleFonts.crimsonText(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            onTap: _openSupportChannel,
          ),
        ],
      ),
    );
  }
  
}