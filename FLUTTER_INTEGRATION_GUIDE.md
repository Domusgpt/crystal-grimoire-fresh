# 🎮 Flutter Integration Guide - Gamified Crystal Grimoire

Complete guide to integrate all gamification features into your Flutter app.

---

## 📦 **Dependencies**

Add to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.0
  cloud_functions: ^4.5.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  share_plus: ^7.2.1  # For social sharing
  url_launcher: ^6.2.1  # For referral links
  flutter_local_notifications: ^16.2.0  # For streak reminders
```

---

## 🏗️ **Architecture**

```
lib/
├── services/
│   ├── gamification_service.dart  # Main service
│   ├── credit_service.dart
│   ├── streak_service.dart
│   ├── achievement_service.dart
│   └── referral_service.dart
├── models/
│   ├── credit_model.dart
│   ├── streak_model.dart
│   ├── achievement_model.dart
│   └── referral_model.dart
├── screens/
│   ├── dashboard_screen.dart
│   ├── achievements_screen.dart
│   ├── referral_screen.dart
│   └── credits_screen.dart
└── widgets/
    ├── credit_balance_widget.dart
    ├── streak_indicator.dart
    ├── achievement_card.dart
    └── referral_share_button.dart
```

---

## 📝 **1. Models**

### **credit_model.dart**

```dart
class CreditBalance {
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final DateTime? lastUpdated;

  CreditBalance({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    this.lastUpdated,
  });

  factory CreditBalance.fromJson(Map<String, dynamic> json) {
    return CreditBalance(
      balance: json['balance'] ?? 0,
      totalEarned: json['totalEarned'] ?? 0,
      totalSpent: json['totalSpent'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
    );
  }
}

class CreditTransaction {
  final String id;
  final String type;  // 'award' or 'deduction'
  final int amount;
  final String reason;
  final int balanceAfter;
  final DateTime timestamp;

  CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.balanceAfter,
    required this.timestamp,
  });

  factory CreditTransaction.fromJson(String id, Map<String, dynamic> json) {
    return CreditTransaction(
      id: id,
      type: json['type'],
      amount: json['amount'],
      reason: json['reason'],
      balanceAfter: json['balanceAfter'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
```

### **streak_model.dart**

```dart
class Streak {
  final int current;
  final int longest;
  final bool canCheckIn;
  final int? nextMilestone;
  final double milestoneProgress;
  final int freezesRemaining;
  final DateTime? lastCheckIn;

  Streak({
    required this.current,
    required this.longest,
    required this.canCheckIn,
    this.nextMilestone,
    required this.milestoneProgress,
    required this.freezesRemaining,
    this.lastCheckIn,
  });

  factory Streak.fromJson(Map<String, dynamic> json) {
    return Streak(
      current: json['current'] ?? 0,
      longest: json['longest'] ?? 0,
      canCheckIn: json['canCheckIn'] ?? true,
      nextMilestone: json['nextMilestone'],
      milestoneProgress: (json['milestoneProgress'] ?? 0).toDouble(),
      freezesRemaining: json['freezesRemaining'] ?? 0,
      lastCheckIn: json['lastCheckIn'] != null
          ? DateTime.parse(json['lastCheckIn'])
          : null,
    );
  }
}
```

### **achievement_model.dart**

```dart
class Achievement {
  final String id;
  final String name;
  final String description;
  final int credits;
  final String badge;
  final String icon;
  final String category;
  final bool earned;
  final DateTime? earnedAt;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.credits,
    required this.badge,
    required this.icon,
    required this.category,
    required this.earned,
    this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      credits: json['credits'],
      badge: json['badge'],
      icon: json['icon'],
      category: json['category'],
      earned: json['earned'] ?? false,
      earnedAt: json['earnedAt'] != null
          ? DateTime.parse(json['earnedAt'])
          : null,
    );
  }
}
```

---

## 🔧 **2. Services**

### **gamification_service.dart** (Main Service)

```dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================================
  // DAILY CHECK-IN
  // ============================================================================

  Future<CheckInResult> dailyCheckIn() async {
    try {
      final result = await _functions.httpsCallable('dailyCheckIn').call();
      return CheckInResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw Exception('Already checked in today!');
      }
      throw Exception('Check-in failed: ${e.message}');
    }
  }

  // ============================================================================
  // CRYSTAL IDENTIFICATION
  // ============================================================================

  Future<CrystalIdentificationResult> identifyCrystal({
    required String imageBase64,
    String? imagePath,
    bool saveToCollection = true,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('identifyCrystalGamified')
          .call({
        'imageData': imageBase64,
        'imagePath': imagePath,
        'saveToCollection': saveToCollection,
      });

      return CrystalIdentificationResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        // Not enough credits or limit reached
        throw InsufficientCreditsException(e.message ?? 'Not enough credits');
      }
      throw Exception('Identification failed: ${e.message}');
    }
  }

  // ============================================================================
  // COLLECTION
  // ============================================================================

  Future<AddToCollectionResult> addToCollection(Map<String, dynamic> crystalData) async {
    try {
      final result = await _functions
          .httpsCallable('addToCollection')
          .call({'crystalData': crystalData});

      return AddToCollectionResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw CollectionLimitException(e.message ?? 'Collection limit reached');
      }
      throw Exception('Failed to add to collection: ${e.message}');
    }
  }

  // ============================================================================
  // DASHBOARD
  // ============================================================================

  Future<UserDashboard> getDashboard() async {
    try {
      final result = await _functions.httpsCallable('getUserDashboard').call();
      return UserDashboard.fromJson(result.data);
    } catch (e) {
      throw Exception('Failed to load dashboard: $e');
    }
  }

  // ============================================================================
  // REFERRAL
  // ============================================================================

  Future<ReferralCode> getMyReferralCode() async {
    try {
      final result = await _functions.httpsCallable('getMyReferralCode').call();
      return ReferralCode.fromJson(result.data);
    } catch (e) {
      throw Exception('Failed to get referral code: $e');
    }
  }

  Future<ReferralApplyResult> applyReferralCode(String code) async {
    try {
      final result = await _functions
          .httpsCallable('applyReferralCode')
          .call({'referralCode': code});

      return ReferralApplyResult.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw Exception('Referral code already used');
      } else if (e.code == 'invalid-argument') {
        throw Exception('Invalid referral code');
      }
      throw Exception('Failed to apply referral code: ${e.message}');
    }
  }

  // ============================================================================
  // ACHIEVEMENTS
  // ============================================================================

  Future<AchievementsData> getMyAchievements() async {
    try {
      final result = await _functions.httpsCallable('getMyAchievements').call();
      return AchievementsData.fromJson(result.data);
    } catch (e) {
      throw Exception('Failed to get achievements: $e');
    }
  }
}

// Custom Exceptions
class InsufficientCreditsException implements Exception {
  final String message;
  InsufficientCreditsException(this.message);
}

class CollectionLimitException implements Exception {
  final String message;
  CollectionLimitException(this.message);
}
```

---

## 🎨 **3. Widgets**

### **credit_balance_widget.dart**

```dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreditBalanceWidget extends StatelessWidget {
  const CreditBalanceWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('credits')
          .doc('balance')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final balance = data?['balance'] ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'credits',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

### **streak_indicator.dart**

```dart
import 'package:flutter/material.dart';

class StreakIndicator extends StatelessWidget {
  final int currentStreak;
  final int? nextMilestone;
  final bool canCheckIn;
  final VoidCallback? onCheckIn;

  const StreakIndicator({
    Key? key,
    required this.currentStreak,
    this.nextMilestone,
    required this.canCheckIn,
    this.onCheckIn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                  color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$currentStreak Day Streak',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (nextMilestone != null)
                      Text(
                        '$currentStreak/$nextMilestone to next reward',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
            if (canCheckIn && onCheckIn != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCheckIn,
                icon: const Icon(Icons.check_circle),
                label: const Text('Check In Today'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ] else if (!canCheckIn)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '✅ Checked in today! Come back tomorrow.',
                  style: TextStyle(color: Colors.green[700]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

### **achievement_card.dart**

```dart
import 'package:flutter/material.dart';
import '../models/achievement_model.dart';

class AchievementCard extends StatelessWidget {
  final Achievement achievement;

  const AchievementCard({Key? key, required this.achievement}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      opacity: achievement.earned ? 1.0 : 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: achievement.earned ? Colors.purple : Colors.grey,
          child: Text(
            achievement.icon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(achievement.name),
        subtitle: Text(achievement.description),
        trailing: achievement.earned
            ? const Icon(Icons.check_circle, color: Colors.green)
            : Text(
                '+${achievement.credits}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
      ),
    );
  }
}
```

---

## 📱 **4. Screens**

### **dashboard_screen.dart**

```dart
import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../widgets/credit_balance_widget.dart';
import '../widgets/streak_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GamificationService _gamification = GamificationService();
  bool _loading = true;
  UserDashboard? _dashboard;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final dashboard = await _gamification.getDashboard();
      setState(() {
        _dashboard = dashboard;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dashboard: $e')),
      );
    }
  }

  Future<void> _checkIn() async {
    try {
      final result = await _gamification.dailyCheckIn();

      // Show success message
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🔥 Check-in Success!'),
          content: Text(result.message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadDashboard(); // Refresh
              },
              child: const Text('Awesome!'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_dashboard == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load dashboard'),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crystal Grimoire'),
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: CreditBalanceWidget(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Streak
            StreakIndicator(
              currentStreak: _dashboard!.streak['current'] ?? 0,
              nextMilestone: _dashboard!.streak['nextMilestone'],
              canCheckIn: _dashboard!.streak['canCheckIn'] ?? false,
              onCheckIn: _checkIn,
            ),

            const SizedBox(height: 16),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Achievements',
                    value: '${_dashboard!.achievements['earned']}/${_dashboard!.achievements['total']}',
                    icon: Icons.emoji_events,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: 'Collection',
                    value: '${_dashboard!.collection['current']}/${_dashboard!.collection['maxDisplay']}',
                    icon: Icons.collections,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Referral CTA
            Card(
              child: ListTile(
                leading: const Icon(Icons.card_giftcard),
                title: const Text('Invite Friends'),
                subtitle: Text('Earn 10 credits per friend'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pushNamed(context, '/referral');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔔 **5. Push Notifications for Streaks**

### **notification_service.dart**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  // Schedule daily streak reminder
  static Future<void> scheduleDailyStreakReminder() async {
    await _notifications.zonedSchedule(
      0,
      '🔥 Don\'t break your streak!',
      'Check in today to keep your streak alive',
      _nextInstanceOf(20, 0), // 8 PM every day
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminders',
          'Streak Reminders',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
```

---

## 🎯 **6. Usage Examples**

### **Identify Crystal with Credits**

```dart
Future<void> identifyCrystal(File imageFile) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Convert image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Call function
    final result = await GamificationService().identifyCrystal(
      imageBase64: base64Image,
      saveToCollection: true,
    );

    // Close loading
    Navigator.pop(context);

    // Show result
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${result.identification['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.description),
            const SizedBox(height: 16),
            Text(
              'Credits spent: ${result.gamification['creditsSpent']}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'New balance: ${result.gamification['newBalance']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            // Show achievements if any
            if (result.gamification['achievements'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('🏆 Achievement Unlocked!'),
              ...result.gamification['achievements'].map((ach) =>
                Text(ach['name'])),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

  } on InsufficientCreditsException catch (e) {
    Navigator.pop(context); // Close loading

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not Enough Credits'),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Earn More'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/upgrade');
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }
}
```

### **Share Referral Code**

```dart
Future<void> shareReferralCode() async {
  try {
    final referral = await GamificationService().getMyReferralCode();

    await Share.share(
      'Join me on Crystal Grimoire! Use my code ${referral.code} to get bonus credits. ${referral.shareUrl}',
      subject: 'Join Crystal Grimoire',
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to share: $e')),
    );
  }
}
```

---

## 🚀 **7. Deployment Checklist**

- [ ] Install all dependencies
- [ ] Create models (credit, streak, achievement, referral)
- [ ] Create services (gamification_service.dart)
- [ ] Create widgets (credit_balance, streak_indicator, etc.)
- [ ] Create screens (dashboard, achievements, referral)
- [ ] Set up push notifications
- [ ] Test daily check-in flow
- [ ] Test crystal identification with credits
- [ ] Test collection limits
- [ ] Test referral code sharing
- [ ] Test achievement unlocking
- [ ] Deploy Cloud Functions
- [ ] Configure Firestore indexes
- [ ] Test end-to-end

---

## 📈 **8. Firestore Indexes Required**

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "identifications",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "createdAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "history",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "referrals",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "referrerId", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy:
```bash
firebase deploy --only firestore:indexes
```

---

## 🎉 **You're Ready!**

Your Flutter app now has:
- ✅ Credit system with real-time balance
- ✅ Daily check-in streaks with rewards
- ✅ Achievement unlocking
- ✅ Referral system with sharing
- ✅ Collection limits
- ✅ Full gamification integration

Users will be engaged, retained, and motivated to upgrade!
