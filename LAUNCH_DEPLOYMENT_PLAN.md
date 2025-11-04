# 🚀 Crystal Grimoire - Launch & Deployment Plan

**Complete step-by-step guide to production deployment**

---

## 📋 **Table of Contents**

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Environment Setup](#environment-setup)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Rollback Procedure](#rollback-procedure)
6. [Monitoring & Alerts](#monitoring--alerts)
7. [Launch Strategy](#launch-strategy)
8. [Troubleshooting](#troubleshooting)

---

## ✅ **Pre-Deployment Checklist**

### **Code Review**

- [ ] All gamification system files reviewed
- [ ] Cost protection verified
- [ ] Image preprocessing tested
- [ ] Error handling comprehensive
- [ ] No console.log statements with sensitive data
- [ ] All TODOs addressed
- [ ] Code commented appropriately

### **Testing**

- [ ] All Phase 1 tests passed (local emulator)
- [ ] All Phase 2 tests passed (staging)
- [ ] Load testing completed
- [ ] Cost protection verified under load
- [ ] No memory leaks detected
- [ ] Response times meet benchmarks

### **Documentation**

- [ ] API documentation updated
- [ ] Flutter integration guide complete
- [ ] Testing plan documented
- [ ] Rollback procedure documented
- [ ] Team trained on new features

### **Infrastructure**

- [ ] Firebase project created
- [ ] Billing account linked
- [ ] Spending alerts configured
- [ ] Firestore security rules updated
- [ ] Firestore indexes deployed
- [ ] Gemini API key secured

### **Business**

- [ ] Legal review of terms (referral rewards, credits)
- [ ] Privacy policy updated (data collection)
- [ ] Stripe/payment integration tested
- [ ] Customer support trained
- [ ] Marketing assets ready

---

## 🏗️ **Environment Setup**

### **Step 1: Firebase Project Configuration**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize project (if not done)
firebase init

# Select:
# - Functions (JavaScript)
# - Firestore
# - Hosting (optional)
```

### **Step 2: Set Environment Variables**

```bash
# Production environment
firebase use production

# Set Gemini API key
firebase functions:config:set gemini.api_key="YOUR_PRODUCTION_GEMINI_API_KEY"

# Verify
firebase functions:config:get
```

**Output should show:**
```json
{
  "gemini": {
    "api_key": "AIza..."
  }
}
```

### **Step 3: Configure Firestore Security Rules**

**File: `firestore.rules`**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // Credits subcollection (read-only for users, write via functions)
      match /credits/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false; // Only via Cloud Functions
      }

      // Engagement (streaks) subcollection
      match /engagement/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false; // Only via Cloud Functions
      }

      // Achievements subcollection
      match /achievements/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false;
      }

      // Crystals collection
      match /crystals/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId;
      }

      // Identifications
      match /identifications/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false; // Only via Cloud Functions
      }

      // Badges
      match /badges/{document=**} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false;
      }
    }

    // Referrals collection (restricted)
    match /referrals/{document} {
      allow read: if request.auth != null &&
                     (resource.data.referrerId == request.auth.uid ||
                      resource.data.refereeId == request.auth.uid);
      allow write: if false; // Only via Cloud Functions
    }

    // Referral clicks (tracking)
    match /referral_clicks/{document} {
      allow read, write: if false; // Only via Cloud Functions
    }
  }
}
```

**Deploy rules:**
```bash
firebase deploy --only firestore:rules
```

### **Step 4: Configure Firestore Indexes**

**File: `firestore.indexes.json`**

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
    },
    {
      "collectionGroup": "referrals",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "referrerId", "order": "ASCENDING"},
        {"fieldPath": "signupAt", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "achievements",
      "queryScope": "COLLECTION",
      "fields": [
        {"fieldPath": "earnedAt", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
```

**Deploy indexes:**
```bash
firebase deploy --only firestore:indexes
```

**Note:** Index creation can take 5-10 minutes. Monitor progress:
```bash
firebase firestore:indexes
```

### **Step 5: Install Function Dependencies**

```bash
cd functions
npm install

# Verify package.json includes:
# - firebase-admin
# - firebase-functions
# - @google/generative-ai

# Check for vulnerabilities
npm audit fix

cd ..
```

### **Step 6: Configure Billing Alerts**

**In Google Cloud Console:**

1. Go to **Billing** → **Budgets & alerts**
2. Create budget alert:
   - **Name:** Crystal Grimoire Daily Budget
   - **Amount:** $50 per day
   - **Alerts:** 50%, 80%, 100%, 120%
   - **Recipients:** Your email + team

3. Create emergency alert:
   - **Name:** Emergency Spending Alert
   - **Amount:** $500 total
   - **Alert at:** 100% only
   - **Action:** Consider programmatic shutdown

---

## 🚀 **Deployment Steps**

### **Step 1: Pre-Deployment Verification**

```bash
# Verify you're on the correct project
firebase use production
firebase projects:list

# Should show production project active
```

### **Step 2: Backup Current Production**

```bash
# Backup Firestore data (if existing)
gcloud firestore export gs://YOUR_BUCKET_NAME/backup-$(date +%Y%m%d-%H%M%S)

# Backup functions code
mkdir -p backups/$(date +%Y%m%d)
cp -r functions backups/$(date +%Y%m%d)/
```

### **Step 3: Deploy Functions (Gradual Rollout)**

**Option A: Deploy All at Once (Recommended for new deployment)**

```bash
firebase deploy --only functions
```

**Option B: Deploy One Function at a Time (Safer for updates)**

```bash
# Deploy non-critical functions first
firebase deploy --only functions:getMyReferralCode
firebase deploy --only functions:getMyAchievements
firebase deploy --only functions:getUserDashboard

# Deploy engagement functions
firebase deploy --only functions:dailyCheckIn

# Deploy critical payment-related functions
firebase deploy --only functions:identifyCrystalGamified
firebase deploy --only functions:addToCollection

# Deploy referral processing
firebase deploy --only functions:applyReferralCode

# Deploy scheduled function
firebase deploy --only functions:resetStreakFreezes
```

**Monitor deployment:**
```bash
firebase functions:log --limit 10
```

### **Step 4: Deploy Firestore Rules & Indexes**

```bash
# Deploy rules
firebase deploy --only firestore:rules

# Deploy indexes (if not already done)
firebase deploy --only firestore:indexes

# Verify indexes are building
firebase firestore:indexes
```

### **Step 5: Verify Deployment**

```bash
# List deployed functions
firebase functions:list

# Check function URLs
firebase functions:config:get

# Test basic function
firebase functions:shell
# > dailyCheckIn()
```

---

## ✅ **Post-Deployment Verification**

### **Immediate Checks (First 5 Minutes)**

1. **Function Health Check**

```bash
# Check logs for errors
firebase functions:log --limit 50

# Look for:
# ✅ "🎮 GAMIFIED Crystal Grimoire Functions initialized"
# ✅ "✅ Credit system active"
# ✅ "✅ Streak system active"
# ❌ Any error stack traces
```

2. **Create Test User**

```javascript
// In Firebase Console > Authentication
// Create test user: test@example.com

// In your app or via Postman
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/dailyCheckIn
Headers: Authorization: Bearer {test-user-token}

// Expected response:
{
  "success": true,
  "streak": 1,
  "creditsEarned": 1,
  "newBalance": 16  // 15 initial + 1 check-in
}
```

3. **Verify Firestore Structure**

**Go to Firebase Console > Firestore:**

- [ ] `users/{testUserId}/credits/balance` exists
- [ ] `balance: 16` is correct
- [ ] `users/{testUserId}/engagement/streak` exists
- [ ] `current: 1` is correct

4. **Test Crystal Identification**

```javascript
POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/identifyCrystalGamified
Headers: Authorization: Bearer {test-user-token}
Body: {
  "imageData": "{base64-encoded-crystal-image}",
  "saveToCollection": true
}

// Expected:
// - Response < 10 seconds
// - Credits deducted: balance now 15
// - Identification saved
// - Achievement unlocked (first_identification)
```

5. **Verify Cost Protection**

```bash
# Check spending in Cloud Console
# Billing > Reports
# Filter: Last 1 hour
# Should be: < $0.50
```

### **First Hour Checks**

- [ ] No function errors in logs
- [ ] Response times < 10s average
- [ ] Total spending < $2
- [ ] No quota exceeded errors
- [ ] Test user journey works end-to-end
- [ ] Referral codes generated correctly

### **First Day Checks**

- [ ] Total spending < $10
- [ ] No circuit breaker activations
- [ ] User signups successful
- [ ] Credits awarded correctly
- [ ] Streaks tracking properly
- [ ] Achievements unlocking
- [ ] No data corruption

---

## ⏮️ **Rollback Procedure**

### **When to Rollback**

**Immediate rollback if:**
- ❌ Spending exceeds $100 in first hour
- ❌ Multiple function failures (>10% error rate)
- ❌ Data corruption detected
- ❌ Security vulnerability discovered

**Consider rollback if:**
- ⚠️ Response times exceed 30s consistently
- ⚠️ User reports of incorrect credit balances
- ⚠️ Achievements not unlocking

### **Rollback Steps**

**Option 1: Rollback Functions to Previous Version**

```bash
# List function versions
gcloud functions list --project YOUR_PROJECT_ID

# Rollback specific function
gcloud functions deploy FUNCTION_NAME \
  --source gs://BUCKET/path-to-previous-version \
  --project YOUR_PROJECT_ID

# OR use Firebase CLI
# (Note: Firebase doesn't have automatic rollback, need manual redeploy)

# Redeploy from backup
cd backups/20241103/  # Your backup date
firebase deploy --only functions
```

**Option 2: Disable Functions**

```bash
# Delete problematic function
firebase functions:delete identifyCrystalGamified

# This stops all calls immediately
```

**Option 3: Emergency Circuit Breaker**

If spending is out of control:

1. **Disable Gemini API calls:**
   - Go to Google Cloud Console
   - APIs & Services > Generative Language API
   - **Disable** (stops all Gemini calls immediately)

2. **Disable Cloud Functions:**
   - Firebase Console > Functions
   - Delete or disable critical functions

3. **Stop billing:**
   - Google Cloud Console > Billing
   - Disable billing (extreme measure, stops all services)

### **Post-Rollback**

1. **Notify users:**
   - In-app banner: "Service temporarily unavailable"
   - Email/social media update

2. **Investigate root cause:**
   - Analyze logs
   - Reproduce issue in staging
   - Fix bug

3. **Redeploy with fix:**
   - Test thoroughly in staging
   - Follow deployment steps again

---

## 📊 **Monitoring & Alerts**

### **Real-Time Monitoring**

**Dashboard to Monitor (Firebase Console):**

1. **Functions Tab:**
   - Invocations per minute
   - Error rate
   - Execution time (p50, p95, p99)
   - Memory usage

2. **Firestore Tab:**
   - Reads/writes per second
   - Document count
   - Storage size

3. **Authentication Tab:**
   - New user signups
   - Active users

### **Key Metrics to Watch**

| Metric | Warning Threshold | Critical Threshold |
|--------|------------------|-------------------|
| Function error rate | > 5% | > 10% |
| Response time (p95) | > 10s | > 30s |
| Daily spending | > $20 | > $50 |
| Memory usage | > 80% | > 95% |
| Firestore reads | > 100k/day | > 500k/day |

### **Set Up Alerts**

**Cloud Monitoring (Stackdriver):**

```bash
# Create alert policy
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="High Error Rate" \
  --condition-display-name="Error rate > 5%" \
  --condition-threshold-value=0.05
```

**Firebase Performance Monitoring:**

Add to Flutter app:
```dart
import 'package:firebase_performance/firebase_performance.dart';

final trace = FirebasePerformance.instance.newTrace('crystal_identification');
await trace.start();
// ... function call ...
await trace.stop();
```

### **Daily Monitoring Checklist**

**Every morning, check:**

- [ ] Firebase Functions logs (last 24h errors)
- [ ] Billing report (yesterday's spend)
- [ ] User growth (new signups)
- [ ] Conversion rate (free → paid)
- [ ] Average credits per user
- [ ] Streak retention rate

---

## 🎯 **Launch Strategy**

### **Phase 1: Soft Launch (Week 1)**

**Audience:** Internal team + close friends (50 users max)

**Goals:**
- Validate all features work
- Catch critical bugs
- Gather UX feedback
- Verify costs align with projections

**Checklist:**
- [ ] Invite 10 team members
- [ ] Invite 40 beta testers
- [ ] Monitor daily
- [ ] Fix critical bugs immediately
- [ ] Gather feedback via survey

**Success Metrics:**
- Zero P0 bugs
- Average response time < 5s
- Cost per user < $0.10
- User feedback > 4/5 stars

### **Phase 2: Private Beta (Week 2-3)**

**Audience:** Waitlist (500 users max)

**Goals:**
- Test at moderate scale
- Validate referral system
- Measure engagement metrics
- Refine conversion funnel

**Launch Channels:**
- Email waitlist
- Personal social media
- Spiritual/crystal communities (Reddit, Discord)

**Checklist:**
- [ ] Send waitlist invites (batches of 100/day)
- [ ] Monitor cost scaling
- [ ] Track streak retention
- [ ] Measure referral rate
- [ ] A/B test upgrade prompts

**Success Metrics:**
- Streak retention > 40% (day 3)
- Referral rate > 5%
- Collection limit hit by 60% of users
- Cost per active user < $0.08

### **Phase 3: Public Launch (Week 4+)**

**Audience:** General public

**Goals:**
- Achieve product-market fit
- Hit 5% conversion rate
- Sustain viral growth
- Reach 1000 active users by month 3

**Launch Channels:**
- Product Hunt launch
- Reddit (r/Crystals, r/spirituality)
- Instagram/TikTok (crystal community)
- App Store / Google Play optimization
- PR outreach (spiritual blogs)

**Checklist:**
- [ ] Prepare Product Hunt launch
- [ ] Create launch video
- [ ] Write press release
- [ ] Reach out to influencers
- [ ] Prepare customer support
- [ ] Scale infrastructure

**Success Metrics:**
- 1000 signups in first week
- 5% conversion to premium by month 2
- 7-day retention > 30%
- Viral coefficient > 0.1
- Cost per active user < $0.08

### **Growth Loops to Activate**

1. **Daily Check-In Loop:**
   - Push notification at 8 PM
   - "Don't lose your 5-day streak!"
   - Click → Check in → Earn credit → Feel accomplished

2. **Collection Limit Loop:**
   - Hit 8/10 crystals
   - See "2 slots left" warning
   - Either: Delete old crystals (painful) OR upgrade (easy)

3. **Referral Loop:**
   - Unlock "Crystal Ambassador" achievement at 5 referrals
   - Show progress: "3/5 friends joined"
   - Share code on social media for +2 credits per share

4. **Achievement Loop:**
   - Unlock first achievement
   - Show "17 more achievements to unlock"
   - Create FOMO (fear of missing out)

---

## 🛠️ **Troubleshooting**

### **Common Issues**

#### **Issue 1: Functions timing out**

**Symptoms:**
- Error: "Function execution took too long"
- Response time > 60s

**Solutions:**
1. Check Gemini API response time
2. Increase timeout in function config:
   ```javascript
   exports.identifyCrystalGamified = onCall({
     timeoutSeconds: 60  // Increase to 60
   }, ...)
   ```
3. Optimize image preprocessing (reduce quality further)

#### **Issue 2: Credits not updating in real-time**

**Symptoms:**
- User performs action, balance doesn't change
- Firestore shows correct value, but UI stale

**Solutions:**
1. Verify StreamBuilder is listening to correct path
2. Check Firestore security rules allow reads
3. Force refresh after operations:
   ```dart
   await gamification.dailyCheckIn();
   setState(() {});  // Force rebuild
   ```

#### **Issue 3: Spending exceeds projections**

**Symptoms:**
- Daily cost > $50
- Firestore reads > 100k/day

**Solutions:**
1. Check for infinite loops in functions
2. Verify cache hit rate (should be > 40%)
3. Reduce image quality further
4. Enable query tracking debug logs
5. Consider rate limiting per user

#### **Issue 4: Referral codes not working**

**Symptoms:**
- Invalid code errors
- Credits not awarded

**Solutions:**
1. Verify code saved to user document:
   ```javascript
   db.collection('users').doc(userId).get()
   // Check: data().referralCode exists
   ```
2. Check referral document created
3. Verify both users receive credits
4. Check transaction logs

#### **Issue 5: Achievements not unlocking**

**Symptoms:**
- User meets criteria, no achievement
- Badge not showing

**Solutions:**
1. Check achievement already earned (one-time only)
2. Verify milestone count calculation
3. Check badge document created in Firestore
4. Ensure `checkAchievement` called after milestone

#### **Issue 6: Stripe payments failing**

**Symptoms:**
- Upgrade button doesn't work
- Payment successful but tier not updated

**Solutions:**
1. Verify Stripe webhook configured
2. Check webhook secret matches
3. Update user tier in Firestore:
   ```javascript
   db.collection('users').doc(userId).update({
     subscriptionTier: 'premium'
   })
   ```
4. Test with Stripe test cards

---

## 📞 **Emergency Contacts**

### **On-Call Rotation**

**Week 1-2:** Primary developer (you)
**Week 3-4:** Backup developer

**Response times:**
- P0 (production down): 15 minutes
- P1 (major feature broken): 1 hour
- P2 (minor bug): 4 hours
- P3 (enhancement): 1 week

### **Escalation**

1. **Developer** → Fix directly
2. **Team Lead** → Resource allocation
3. **CTO** → Architecture decisions
4. **CEO** → Customer communication

### **Useful Links**

- Firebase Console: https://console.firebase.google.com/project/YOUR_PROJECT
- Google Cloud Console: https://console.cloud.google.com
- Gemini API Status: https://status.cloud.google.com
- Stripe Dashboard: https://dashboard.stripe.com
- Error tracking: [Your error tracking tool]
- Team Slack: [Your Slack workspace]

---

## 📅 **Post-Launch Timeline**

### **Week 1: Monitor Closely**
- Check logs 3x daily
- Respond to user feedback immediately
- Fix critical bugs within 24h
- Publish daily metrics report

### **Week 2-3: Optimize**
- A/B test credit earning rates
- Optimize conversion funnel
- Improve onboarding flow
- Add missing features from feedback

### **Week 4: Scale**
- Prepare for growth
- Optimize costs further
- Improve performance
- Plan next features

### **Month 2: Iterate**
- Launch shop integration
- Add social features
- Improve AI accuracy
- Expand achievement system

---

## ✅ **Final Pre-Launch Checklist**

**Before you deploy:**

- [ ] All tests passing
- [ ] Cost protection verified
- [ ] Billing alerts configured
- [ ] Firestore rules deployed
- [ ] Firestore indexes built
- [ ] Functions deployed successfully
- [ ] Test user journey works
- [ ] Rollback procedure documented
- [ ] Monitoring dashboard set up
- [ ] Team trained on incident response
- [ ] Customer support ready
- [ ] Marketing materials ready
- [ ] Legal disclaimers in place

**After you deploy:**

- [ ] Verify all functions healthy
- [ ] Create test user and verify flow
- [ ] Check spending after 1 hour
- [ ] Monitor logs for errors
- [ ] Post in team chat: "Deployed ✅"

---

## 🎉 **You're Ready to Launch!**

**Remember:**
1. Start small (soft launch)
2. Monitor closely (first 48h critical)
3. Fix fast (bugs will happen)
4. Iterate quickly (user feedback is gold)
5. Stay calm (you have rollback plan)

**Good luck! 🚀💎✨**

---

**Document version:** 1.0
**Last updated:** November 4, 2024
**Next review:** After Week 1 launch
