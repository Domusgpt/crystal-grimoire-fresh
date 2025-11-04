# 🧪 Crystal Grimoire - Comprehensive Testing Plan

**Before production deployment, all tests must pass**

---

## 📋 **Testing Phases**

### **Phase 1: Local Emulator Testing** ⚙️
### **Phase 2: Staging Environment Testing** 🔧
### **Phase 3: Production Smoke Testing** 🚀
### **Phase 4: Load Testing** 📊

---

## ⚙️ **PHASE 1: Local Emulator Testing**

### **Setup**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Start emulators
cd functions
npm install
cd ..
firebase emulators:start --only functions,firestore,auth
```

### **Test Environment Variables**

Before testing, ensure `.runtimeconfig.json` exists:

```json
{
  "gemini": {
    "api_key": "YOUR_GEMINI_API_KEY"
  }
}
```

---

## 🧪 **Test Suite 1: Credit System**

### **Test 1.1: New User Initialization**

**Objective:** Verify new users get 15 starting credits

**Steps:**
1. Create new Firebase Auth user
2. Call `dailyCheckIn` function
3. Verify Firestore document created at `users/{uid}/credits/balance`
4. Verify balance is 15 credits

**Expected Result:**
```json
{
  "balance": 15,
  "totalEarned": 15,
  "totalSpent": 0,
  "createdAt": "[timestamp]",
  "lastUpdated": "[timestamp]"
}
```

**Pass Criteria:**
- ✅ Document created automatically
- ✅ Balance = 15
- ✅ Timestamps are present

---

### **Test 1.2: Credit Deduction**

**Objective:** Verify credits are deducted correctly

**Steps:**
1. Create test user with 10 credits
2. Call `identifyCrystalGamified` with valid image
3. Verify 1 credit deducted
4. Verify transaction logged

**Expected Result:**
- Balance: 9 credits
- Transaction document created in `users/{uid}/credits/transactions/history/{id}`

**Pass Criteria:**
- ✅ Balance decremented
- ✅ Transaction logged with correct metadata
- ✅ `totalSpent` incremented

---

### **Test 1.3: Insufficient Credits**

**Objective:** Verify error when user has 0 credits

**Steps:**
1. Create test user with 0 credits
2. Call `identifyCrystalGamified`

**Expected Result:**
```javascript
{
  code: 'resource-exhausted',
  message: 'Not enough credits. Need 1, have 0. Earn more or upgrade to Premium!'
}
```

**Pass Criteria:**
- ✅ Function throws HttpsError
- ✅ Error code is 'resource-exhausted'
- ✅ No Gemini API call made

---

### **Test 1.4: Credit Awards**

**Objective:** Verify credits awarded correctly

**Steps:**
1. Create test user with 5 credits
2. Award 10 credits via `awardCredits` function
3. Verify balance is 15

**Expected Result:**
- Balance: 15
- totalEarned: 15 (initial) + 10 = 25
- Transaction logged as 'award'

**Pass Criteria:**
- ✅ Balance correct
- ✅ totalEarned tracked
- ✅ Transaction logged

---

### **Test 1.5: Paid Tier Bypass**

**Objective:** Verify premium users bypass credit checks

**Steps:**
1. Create user with `subscriptionTier: 'premium'`
2. Set credits to 0
3. Call `identifyCrystalGamified`

**Expected Result:**
- Function succeeds
- No credits deducted
- Gemini API called successfully

**Pass Criteria:**
- ✅ No credit check performed
- ✅ Identification completes
- ✅ Balance remains 0

---

## 🔥 **Test Suite 2: Streak System**

### **Test 2.1: First Check-In**

**Objective:** Verify first daily check-in works

**Steps:**
1. Create new user
2. Call `dailyCheckIn`
3. Verify streak created at `users/{uid}/engagement/streak`

**Expected Result:**
```json
{
  "current": 1,
  "longest": 1,
  "lastCheckIn": "[timestamp]",
  "totalCheckIns": 1,
  "freezesRemaining": 0
}
```

**Pass Criteria:**
- ✅ Streak starts at 1
- ✅ Credits awarded (+1)
- ✅ lastCheckIn timestamp set

---

### **Test 2.2: Consecutive Check-In**

**Objective:** Verify streak increments on consecutive days

**Steps:**
1. Create user with check-in yesterday
2. Call `dailyCheckIn` today
3. Verify streak increments

**Setup:**
```javascript
// Set lastCheckIn to yesterday
const yesterday = new Date();
yesterday.setDate(yesterday.getDate() - 1);
```

**Expected Result:**
- current: 2
- longest: 2
- Credits: +1

**Pass Criteria:**
- ✅ Streak incremented
- ✅ Credits awarded
- ✅ lastCheckIn updated to today

---

### **Test 2.3: Duplicate Check-In Prevention**

**Objective:** Verify users can't check in twice in same day

**Steps:**
1. Create user
2. Call `dailyCheckIn` (succeeds)
3. Call `dailyCheckIn` again immediately

**Expected Result:**
```javascript
{
  code: 'already-exists',
  message: 'Already checked in today! Come back tomorrow for your streak.'
}
```

**Pass Criteria:**
- ✅ Second call throws error
- ✅ No duplicate credits awarded
- ✅ Streak not incremented

---

### **Test 2.4: Streak Break**

**Objective:** Verify streak resets after missing day

**Steps:**
1. Create user with last check-in 3 days ago
2. Call `dailyCheckIn`

**Expected Result:**
- current: 1 (reset)
- longest: [previous streak] (preserved)
- Console log shows "💔 Streak broken"

**Pass Criteria:**
- ✅ Current streak reset to 1
- ✅ Longest streak preserved
- ✅ Credits still awarded (+1)

---

### **Test 2.5: 7-Day Milestone**

**Objective:** Verify milestone bonus at 7 days

**Steps:**
1. Create user with 6-day streak
2. Call `dailyCheckIn`

**Expected Result:**
- current: 7
- Badge: 'week_warrior'
- Credits: +1 (daily) + +5 (milestone) = 6 total

**Pass Criteria:**
- ✅ Milestone bonus awarded
- ✅ Badge saved to `users/{uid}/badges/week_warrior`
- ✅ Total 6 credits awarded

---

### **Test 2.6: Streak Freeze (Premium)**

**Objective:** Verify freeze saves streak for premium users

**Steps:**
1. Create user with tier='premium', 7-day streak, 3 freezes
2. Set lastCheckIn to 2 days ago
3. Call `dailyCheckIn`

**Expected Result:**
- current: 8 (streak continues)
- freezesRemaining: 2 (used 1)
- Console: "🧊 Streak freeze used"

**Pass Criteria:**
- ✅ Streak not broken
- ✅ Freeze consumed
- ✅ Credits awarded

---

## 🏆 **Test Suite 3: Achievement System**

### **Test 3.1: First Identification Achievement**

**Objective:** Verify first identification awards achievement

**Steps:**
1. Create new user with 10 credits
2. Call `identifyCrystalGamified` with valid image

**Expected Result:**
- Achievement 'first_identification' created
- Credits awarded: +2 (achievement bonus)
- Badge 'novice_seeker' awarded
- Achievement returned in response

**Pass Criteria:**
- ✅ Achievement document created
- ✅ Credits awarded
- ✅ Badge awarded
- ✅ Achievement in `_gamification.achievements`

---

### **Test 3.2: Duplicate Achievement Prevention**

**Objective:** Verify achievement only awarded once

**Steps:**
1. Create user with 'first_identification' already earned
2. Call `identifyCrystalGamified` again

**Expected Result:**
- No duplicate achievement
- No duplicate credits
- Response shows 0 achievements

**Pass Criteria:**
- ✅ checkAchievement returns null
- ✅ No duplicate credits
- ✅ achievements array empty

---

### **Test 3.3: Collection Milestones**

**Objective:** Verify collection count triggers achievements

**Steps:**
1. Create user with 9 crystals in collection
2. Call `addToCollection` with new crystal

**Expected Result:**
- Achievement 'collect_10' unlocked
- Credits: +5
- Badge: 'collector_bronze'

**Pass Criteria:**
- ✅ Achievement triggered at exactly 10
- ✅ Credits awarded
- ✅ Achievement in response

---

### **Test 3.4: Referral Milestones**

**Objective:** Verify referral count triggers achievements

**Steps:**
1. Create user with 4 completed referrals
2. Process 5th referral via `processReferralSignup`

**Expected Result:**
- Achievement 'refer_5' unlocked
- Credits: +50 (milestone) + +10 (referral) = 60
- Badge: 'ambassador'

**Pass Criteria:**
- ✅ Achievement triggered
- ✅ Total credits correct
- ✅ Badge awarded

---

## 🤝 **Test Suite 4: Referral System**

### **Test 4.1: Generate Referral Code**

**Objective:** Verify unique code generation

**Steps:**
1. Create new user
2. Call `getMyReferralCode`

**Expected Result:**
- Code format: `CG` + 6 characters
- Code saved to user document
- shareUrl contains code

**Pass Criteria:**
- ✅ Code matches format (e.g., "CGAB3XY9")
- ✅ Code is unique (verify with multiple users)
- ✅ shareUrl: `https://crystalgrimoire.app?ref={code}`

---

### **Test 4.2: Apply Referral Code**

**Objective:** Verify referral code application

**Steps:**
1. Create User A with referral code "CGTEST1"
2. Create new User B
3. User B calls `applyReferralCode` with "CGTEST1"

**Expected Result:**
- User A gets +10 credits (referrer reward)
- User B gets +5 credits (referee bonus)
- Referral document created with status 'completed'

**Pass Criteria:**
- ✅ Both users receive credits
- ✅ Referral document exists
- ✅ Rewards marked as given

---

### **Test 4.3: Invalid Referral Code**

**Objective:** Verify error handling for invalid codes

**Steps:**
1. Call `applyReferralCode` with "INVALID"

**Expected Result:**
```javascript
{
  code: 'invalid-argument',
  message: 'Invalid referral code'
}
```

**Pass Criteria:**
- ✅ Error thrown
- ✅ No credits awarded
- ✅ No referral document created

---

### **Test 4.4: Self-Referral Prevention**

**Objective:** Verify users can't refer themselves

**Steps:**
1. Create User A with code "CGTEST1"
2. User A calls `applyReferralCode` with "CGTEST1"

**Expected Result:**
- Function returns null (no credits)
- Console: "User tried to use their own referral code"

**Pass Criteria:**
- ✅ No credits awarded
- ✅ No referral document
- ✅ Warning logged

---

### **Test 4.5: Duplicate Referral Prevention**

**Objective:** Verify users can only use one referral code

**Steps:**
1. User B already used code "CGTEST1"
2. User B tries to use code "CGTEST2"

**Expected Result:**
```javascript
{
  code: 'already-exists',
  message: 'Referral code already used or invalid'
}
```

**Pass Criteria:**
- ✅ Error thrown
- ✅ No duplicate credits
- ✅ Original referral preserved

---

### **Test 4.6: Referral Purchase Bonus**

**Objective:** Verify bonus when referred user purchases

**Steps:**
1. User A referred User B
2. User B upgrades to premium
3. Call `processReferralPurchase(userB.id)`

**Expected Result:**
- User A gets +50 credits (purchase bonus)
- Referral document updated with `purchaseRewardGiven: true`

**Pass Criteria:**
- ✅ Bonus credits awarded
- ✅ Document updated
- ✅ One-time bonus (can't repeat)

---

## 💎 **Test Suite 5: Collection Limits**

### **Test 5.1: Free Tier Collection Limit**

**Objective:** Verify 10 crystal limit for free tier

**Steps:**
1. Create free user with 10 crystals
2. Call `addToCollection`

**Expected Result:**
```javascript
{
  code: 'resource-exhausted',
  message: 'Collection limit reached (10 crystals). Upgrade to Premium for unlimited storage!'
}
```

**Pass Criteria:**
- ✅ Error thrown at 10
- ✅ No 11th crystal added
- ✅ Upgrade message shown

---

### **Test 5.2: Premium Unlimited Collection**

**Objective:** Verify premium users have no limit

**Steps:**
1. Create premium user with 100 crystals
2. Call `addToCollection`

**Expected Result:**
- Crystal added successfully
- No error thrown

**Pass Criteria:**
- ✅ Collection grows beyond 10
- ✅ No limit checking for premium
- ✅ Success response

---

### **Test 5.3: Collection Stats**

**Objective:** Verify stats calculation

**Steps:**
1. Create free user with 8 crystals
2. Call `getCollectionStats`

**Expected Result:**
```json
{
  "current": 8,
  "max": 10,
  "maxDisplay": "10",
  "remaining": 2,
  "percentage": 80,
  "isUnlimited": false,
  "needsUpgrade": true
}
```

**Pass Criteria:**
- ✅ Stats accurate
- ✅ Percentage calculated
- ✅ needsUpgrade = true at 80%

---

## 🔒 **Test Suite 6: Cost Protection**

### **Test 6.1: Spending Limit Check**

**Objective:** Verify spending limits enforced

**Steps:**
1. Create free user
2. Make 50 identification requests in 1 hour

**Expected Result:**
- First ~10 succeed
- Subsequent requests fail with 'resource-exhausted'
- Console shows spending limit reached

**Pass Criteria:**
- ✅ Limit enforced
- ✅ No runaway costs
- ✅ Clear error message

---

### **Test 6.2: Query Tracking**

**Objective:** Verify database query limits

**Steps:**
1. Monitor Firestore queries during identification
2. Verify max 10 queries per request

**Expected Result:**
- QueryTracker throws error if > 10 queries

**Pass Criteria:**
- ✅ Query count tracked
- ✅ Limit enforced
- ✅ No infinite loops

---

### **Test 6.3: Image Preprocessing**

**Objective:** Verify grid extraction reduces costs

**Steps:**
1. Upload 3MB image
2. Call `preprocessImage` with tier='free'
3. Verify output size

**Expected Result:**
- Input: ~3MB (3000KB)
- Output: ~50KB (512x512, quality 60)
- Size reduction: ~98%

**Pass Criteria:**
- ✅ Image under 200KB
- ✅ Grid extracted (center 25%)
- ✅ Quality reduced appropriately

---

## 📊 **Test Suite 7: Dashboard Integration**

### **Test 7.1: Get User Dashboard**

**Objective:** Verify all data loads correctly

**Steps:**
1. Create user with:
   - 10 credits
   - 5-day streak
   - 3 achievements
   - 2 referrals
   - 7 crystals
2. Call `getUserDashboard`

**Expected Result:**
```json
{
  "user": { "tier": "free", "displayName": "..." },
  "credits": { "balance": 10, "analytics": {...} },
  "streak": { "current": 5, "longest": 5, ... },
  "achievements": { "earned": 3, "total": 20+, ... },
  "collection": { "current": 7, "max": 10, ... },
  "referrals": { "code": "CG...", "total": 2, "earned": 20 }
}
```

**Pass Criteria:**
- ✅ All data present
- ✅ Parallel loading (no sequential waits)
- ✅ Response < 2 seconds

---

## 🚨 **Test Suite 8: Error Handling**

### **Test 8.1: Unauthenticated Requests**

**Objective:** Verify auth required

**Steps:**
1. Call any function without auth token

**Expected Result:**
```javascript
{
  code: 'unauthenticated',
  message: 'Authentication required'
}
```

**Pass Criteria:**
- ✅ All functions protected
- ✅ Consistent error format
- ✅ No data leak

---

### **Test 8.2: Invalid Image Data**

**Objective:** Verify image validation

**Steps:**
1. Call `identifyCrystalGamified` with invalid base64

**Expected Result:**
- Error thrown before Gemini call
- No credits deducted
- Clear error message

**Pass Criteria:**
- ✅ Validation catches error
- ✅ No API cost incurred
- ✅ User-friendly error

---

### **Test 8.3: Gemini API Failure**

**Objective:** Verify graceful handling of API errors

**Steps:**
1. Simulate Gemini API timeout
2. Verify error handling

**Expected Result:**
- Credits NOT deducted (transaction rolled back)
- User-friendly error message
- Retry suggestion shown

**Pass Criteria:**
- ✅ Transaction rollback
- ✅ User not charged
- ✅ Error logged

---

## ⚡ **PHASE 2: Staging Environment Testing**

### **Setup**

```bash
# Deploy to staging project
firebase use staging
firebase deploy --only functions

# Set environment variables
firebase functions:config:set gemini.api_key="YOUR_KEY"
```

### **Test Suite 9: End-to-End Integration**

**Test 9.1: Complete User Journey**

**Steps:**
1. New user signs up
2. Check-in daily for 7 days
3. Identify 3 crystals
4. Add to collection
5. Generate referral code
6. Refer a friend
7. Hit collection limit
8. Upgrade to premium

**Pass Criteria:**
- ✅ All steps complete without errors
- ✅ Credits earned and spent correctly
- ✅ Achievements unlocked
- ✅ Upgrade flow works

---

### **Test Suite 10: Real Gemini API Testing**

**Test 10.1: Crystal Identification Accuracy**

**Test crystals:**
- Amethyst (purple cluster)
- Rose Quartz (pink smooth)
- Clear Quartz (transparent points)
- Black Tourmaline (dark opaque)
- Citrine (yellow/orange)

**Pass Criteria:**
- ✅ Confidence > 70% for clear images
- ✅ Correct identification
- ✅ Metaphysical properties accurate
- ✅ Response < 10 seconds

---

### **Test Suite 11: Performance Testing**

**Test 11.1: Response Times**

**Benchmarks:**
- dailyCheckIn: < 500ms
- identifyCrystalGamified: < 10s (includes Gemini)
- getUserDashboard: < 2s
- getMyReferralCode: < 300ms

**Pass Criteria:**
- ✅ 95th percentile meets benchmarks
- ✅ No timeout errors
- ✅ Consistent performance

---

## 📊 **PHASE 3: Load Testing**

### **Test Suite 12: Concurrent Users**

**Test 12.1: 100 Concurrent Check-Ins**

**Tool:** Apache JMeter or Artillery

**Configuration:**
```yaml
scenarios:
  - name: "Daily Check-in Load"
    requests:
      - function: "dailyCheckIn"
        users: 100
        duration: 60s
```

**Pass Criteria:**
- ✅ All requests succeed
- ✅ No rate limit errors
- ✅ Response time < 1s average

---

### **Test 12.2: Burst Traffic**

**Scenario:** 500 identifications in 5 minutes

**Pass Criteria:**
- ✅ Cost protection activates
- ✅ No Firebase quota exceeded
- ✅ Graceful degradation

---

## 🚀 **PHASE 4: Production Smoke Testing**

### **Post-Deployment Checklist**

**After deploying to production:**

1. ✅ **Verify Functions Deployed**
   ```bash
   firebase functions:list
   ```
   - dailyCheckIn
   - identifyCrystalGamified
   - addToCollection
   - getUserDashboard
   - getMyReferralCode
   - applyReferralCode
   - getMyAchievements
   - resetStreakFreezes

2. ✅ **Test with Real User**
   - Create test account
   - Perform 1 check-in
   - Identify 1 crystal
   - Verify credits work

3. ✅ **Monitor Logs**
   ```bash
   firebase functions:log --limit 50
   ```
   - No errors
   - Expected log messages
   - Performance metrics

4. ✅ **Check Firestore Structure**
   - users/{uid}/credits/balance
   - users/{uid}/engagement/streak
   - users/{uid}/achievements/{id}
   - referrals/{id}

5. ✅ **Verify Cost Protection**
   - Check spending in first hour < $1
   - Monitor query counts
   - Confirm rate limits active

---

## 📈 **Success Metrics**

### **Must Pass Before Production:**

- ✅ All Phase 1 tests pass (100%)
- ✅ All critical paths work in Phase 2
- ✅ No P0 bugs found
- ✅ Performance meets benchmarks
- ✅ Cost protection verified
- ✅ No data corruption
- ✅ Rollback plan tested

### **Monitoring After Launch:**

**Day 1:**
- Total spend < $10
- No function errors
- Average response time < 5s
- User signups > 0

**Week 1:**
- Conversion rate > 1%
- Free tier cost < $0.10 per active user
- Streak retention > 50%
- No emergency circuit breaker hits

**Month 1:**
- Conversion rate trending toward 5%
- Cost per active user < $0.08
- 7-day retention > 30%
- Referral rate > 5%

---

## 🔧 **Testing Tools**

### **Required:**
- Firebase Emulator Suite
- Postman or Insomnia (API testing)
- Firebase Console (monitoring)

### **Optional:**
- Artillery (load testing)
- Jest (unit tests for helper functions)
- Cypress (E2E UI testing)

---

## ⚠️ **Known Limitations & Edge Cases**

### **To Monitor:**

1. **Timezone Issues:**
   - Streak check-ins use UTC
   - User in different timezone might see unexpected behavior
   - **Mitigation:** Document timezone handling

2. **Referral Code Collisions:**
   - 36^6 = 2.2 billion combinations
   - Collision unlikely but possible
   - **Mitigation:** Retry up to 10 times

3. **Race Conditions:**
   - Multiple simultaneous check-ins
   - **Mitigation:** Firestore transactions used

4. **Credit Timing:**
   - Credit award happens after AI call
   - If AI call fails, credits not deducted
   - **Mitigation:** Transaction rollback

---

## ✅ **Sign-Off**

**Before deploying to production:**

- [ ] All Phase 1 tests passed
- [ ] All Phase 2 tests passed
- [ ] Performance benchmarks met
- [ ] Cost protection verified
- [ ] Documentation updated
- [ ] Team trained on monitoring
- [ ] Rollback procedure documented
- [ ] Emergency contacts listed

**Signed by:** _______________________
**Date:** _______________________

---

## 📞 **Emergency Contacts**

If tests fail or production issues occur:

- Firebase Console: https://console.firebase.google.com
- Gemini API Status: https://status.cloud.google.com
- Support: [Your support channel]

---

**All tests documented. Ready for systematic verification before launch.**
