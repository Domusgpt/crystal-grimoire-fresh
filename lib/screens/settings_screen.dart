import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/common/mystical_button.dart';
import '../widgets/animations/mystical_animations.dart';
import '../services/auth_service.dart';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              _saveSettings();
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
              _saveSettings();
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
              _saveSettings();
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
              _saveSettings();
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
              'English',
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
            onTap: () {
              // Language selection would go here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Language selection coming soon'),
                  backgroundColor: Colors.purple,
                ),
              );
            },
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
                _saveSettings();
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
                _saveSettings();
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
            onTap: () {
              // Privacy settings would go here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Privacy settings coming soon'),
                  backgroundColor: Colors.purple,
                ),
              );
            },
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
                await AuthService.signOut();
                Navigator.pushReplacementNamed(context, '/login');
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
            onTap: () {
              // Terms of service
            },
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
            onTap: () {
              // Privacy policy
            },
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
            onTap: () {
              // Help & support
            },
          ),
        ],
      ),
    );
  }
  
  void _saveSettings() {
    // Save settings to SharedPreferences or Firebase
    // This would be implemented with actual persistence
    print('Settings saved');
  }
}