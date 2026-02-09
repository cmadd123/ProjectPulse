# ProjectPulse - Complete Launch Plan

**Last Updated:** 2026-01-27

---

## **Core Vision**

**Problem:** Contractors struggle with two major pain points:
1. **Communication transparency** - Clients want to see progress, contractors hate texting 50 photos
2. **Cash flow** - Contractors wait 30-90 days for payment, can't take multiple jobs

**Solution:** Beautiful photo timeline + Protected milestone payments with instant releases

**Value Proposition:** "Get paid as you work. Show clients every step. Build trust."

---

## **Revenue Model (FINAL)**

### **Free Tier**
- 1 active project
- Basic photo timeline
- Watermarked updates
- No milestone payments (traditional invoicing only)

### **Pro Tier: $25/month**
- Unlimited projects
- Unlimited photos
- Up to 5 team members (can post updates)
- **Protected milestone payments:**
  - **3% transaction fee (instant payout - same day)**
  - Stripe fees absorbed by ProjectPulse
- Change orders
- Messaging
- Email notifications

### **Premium Tier: $50/month**
- Everything in Pro
- Unlimited team members
- **Lower transaction fees:**
  - **2% transaction fee (instant payout - same day)**
  - Stripe fees absorbed by ProjectPulse
- Analytics dashboard
- White-label branding
- Priority support
- Before/after portfolio tools

**Note:** We removed the "Standard" payout option. All payouts are instant (same-day) because:
1. Simpler messaging - no decision fatigue
2. Justified by speed - contractors get paid 60+ days faster than invoicing
3. 3% instant is competitive with credit card float and invoice factoring
4. ProjectPulse absorbs Stripe's instant payout fees (~0.5%) for cleaner UX

---

## **Milestone Payment System**

### **How It Works:**

**1. Project Setup (Contractor)**
- Create project: "$15,000 Kitchen Remodel"
- Define milestones:
  - Demo Complete: $3,000 (20%)
  - Rough Electrical/Plumbing: $4,500 (30%)
  - Drywall/Cabinets: $4,500 (30%)
  - Final Walkthrough: $3,000 (20%)
- Or use template (Kitchen, Bathroom, Roofing, etc.)

**2. Client Payment (Upfront Escrow)**
- Client receives invite link
- Views milestone breakdown
- Pays $15,000 via Stripe (one-time charge)
- Funds held in ProjectPulse escrow account
- Client sees "Protected Balance: $15,000"

**3. Work & Progress**
- Contractor posts photos as work completes
- Team members can also post updates
- Client watches progress in real-time

**4. Milestone Approval**
- Contractor marks "Demo Complete"
- Client gets push notification + email
- Client reviews photos/work
- Client clicks "Approve Milestone"
- **Funds released instantly** (or 2-day standard)

**5. Payout to Contractor**
- Milestone 1: $3,000
- Transaction fee (3% instant): $90
- Contractor receives: $2,910
- **Same day payout to bank account**

**6. Repeat Until Complete**
- Continues for all milestones
- Client always sees remaining protected balance
- Final milestone completes → project marked complete

---

## **Client Messaging (Critical)**

**How we frame escrow to clients:**

### **Landing Page / Marketing**
> "Protected Milestone Payments - You Control When Your Contractor Gets Paid"

> "Your money is protected by escrow until you approve each stage of work. If your contractor doesn't complete the work, you get a full refund. It's like having a built-in project manager watching your money."

### **Client Dashboard**
```
Kitchen Remodel - $15,000 total
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Demo Complete - $3,000 (Released Jan 15)
🔒 Rough Work - $4,500 (In Progress)
⏳ Cabinets - $4,500 (Not Started)
⏳ Final - $3,000 (Not Started)

Your Protected Balance: $12,000
(Released when you approve each milestone)
```

### **Benefits to Client**
- ✅ Your money is protected until work is approved
- ✅ Full refund if contractor doesn't complete work
- ✅ You approve each stage before payment releases
- ✅ No more "pay upfront and hope for the best"
- ✅ Built-in dispute resolution

---

## **Benefits to Contractor**

**Why contractors will use this:**

### **Cash Flow (Primary)**
- Get paid as work completes (not 60-90 days later)
- No more waiting on client invoices
- Take 3x more projects (cash not tied up)
- Pay subs/suppliers immediately

### **Client Trust**
- Escrow proves you're legitimate
- "Your money is protected" = easier sales
- Reduces client anxiety
- Professional image

### **Marketing Tool**
- Public portfolio with before/after photos
- Client reviews displayed prominently
- Share profile link on social media
- Stand out from competitors

### **Cost Analysis**
**Without ProjectPulse:**
- Wait 60 days for $3,000 payment
- Cost of capital: Using credit card @ 18% APR = $90
- OR: Factor invoice @ 3-5% per month = $90-150

**With ProjectPulse:**
- Get $2,910 same day ($90 fee @ 3%)
- **Same or cheaper than alternatives**
- PLUS get project management tools
- No waiting period - instant access to funds

---

## **Technical Implementation**

### **Firestore Schema Updates**

```javascript
// projects collection (add fields)
{
  project_id: "...",
  // ... existing fields ...

  // NEW: Milestone payment fields
  payment_status: "unpaid" | "escrowed" | "partially_released" | "completed",
  escrow_amount: 15000,
  total_released: 3000,
  remaining_balance: 12000,
  milestones_enabled: true,
  stripe_payment_intent_id: "pi_...",
  stripe_account_id: "acct_...", // Contractor's Stripe Connect account
}

// NEW: milestones subcollection
// projects/{project_id}/milestones/{milestone_id}
{
  milestone_id: "auto_id",
  name: "Demo Complete",
  description: "Tear out old kitchen, dispose of debris",
  amount: 3000,
  percentage: 20,
  order: 1,
  status: "pending" | "in_progress" | "awaiting_approval" | "approved" | "disputed",
  marked_complete_at: timestamp,
  approved_at: timestamp,
  released_at: timestamp,
  released_amount: 2910, // After fees
  transaction_fee: 90,
  payout_speed: "instant" | "standard",
  dispute_reason: "...", // If disputed
  created_at: timestamp,
}

// users collection (add contractor fields)
{
  contractor_profile: {
    // ... existing fields ...

    // NEW: Stripe Connect fields
    stripe_account_id: "acct_...",
    stripe_onboarding_complete: true,
    payouts_enabled: true,
    bank_account_last4: "1234",
  }
}

// NEW: transactions collection (for accounting/reporting)
{
  transaction_id: "auto_id",
  type: "milestone_release" | "refund" | "fee",
  project_ref: DocumentReference,
  milestone_ref: DocumentReference,
  contractor_ref: DocumentReference,
  amount: 3000,
  fee_amount: 90,
  net_amount: 2910,
  stripe_transfer_id: "tr_...",
  payout_speed: "instant" | "standard",
  status: "pending" | "completed" | "failed",
  created_at: timestamp,
  completed_at: timestamp,
}
```

### **Stripe Integration**

**1. Stripe Connect Setup**
- Use "Connect Onboarding" for contractors
- Collect: Business info, bank account, tax ID
- Store `stripe_account_id` in Firestore

**2. Payment Flow**
```dart
// Step 1: Client pays (create Payment Intent)
final paymentIntent = await Stripe.instance.createPaymentIntent(
  amount: 15000 * 100, // Convert to cents
  currency: 'usd',
  customer: clientStripeId,
  metadata: {
    'project_id': projectId,
    'contractor_id': contractorId,
  },
);

// Step 2: Hold in platform account (automatic with Payment Intent)
// Funds sit in ProjectPulse Stripe account

// Step 3: Milestone approved → Transfer to contractor
final transfer = await Stripe.instance.createTransfer(
  amount: 2910 * 100, // After 3% fee
  currency: 'usd',
  destination: contractorStripeAccountId,
  metadata: {
    'project_id': projectId,
    'milestone_id': milestoneId,
  },
);

// Step 4: Instant vs Standard payout
if (payoutSpeed == 'instant') {
  // Use Instant Payouts API (1% Stripe fee, we charge 3% total)
  await Stripe.instance.createPayout(
    amount: 2910 * 100,
    destination: contractorStripeAccountId,
    method: 'instant',
  );
} else {
  // Standard ACH (free from Stripe, we charge 0.5%)
  // Arrives in 2 business days automatically
}
```

**3. Webhook Handlers**
- `payment_intent.succeeded` → Update project status to "escrowed"
- `transfer.created` → Log transaction
- `payout.paid` → Notify contractor
- `payout.failed` → Alert support team

**4. Fee Calculation**
```dart
double calculateFee(double amount, String tier) {
  double feeRate;

  if (tier == 'pro') {
    feeRate = 0.03; // 3% for all payouts (instant)
  } else if (tier == 'premium') {
    feeRate = 0.02; // 2% for all payouts (instant)
  } else {
    return 0; // Free tier - no milestone payments
  }

  return amount * feeRate;
}

// Example:
// $3,000 milestone, Pro tier
// Fee: $3,000 * 0.03 = $90
// Contractor gets: $2,910 (same day)
// Stripe's instant payout fee (~$15) absorbed by ProjectPulse
// ProjectPulse nets: $75
```

---

## **UI/UX Screens to Build**

### **1. Milestone Setup (Contractor)**
- Screen: "Define Project Milestones"
- Fields per milestone:
  - Name (text)
  - Description (textarea)
  - Amount or % (number)
  - Order (drag to reorder)
- Templates dropdown:
  - Kitchen Remodel (4 milestones)
  - Bathroom Remodel (3 milestones)
  - Roofing (3 milestones)
  - Custom
- Preview: Shows client what they'll see
- Save button

### **2. Stripe Connect Onboarding (Contractor)**
- Screen: "Get Paid Faster - Connect Your Bank"
- Explanation: "Connect your bank account to receive instant milestone payments"
- Button: "Connect Stripe Account"
- Opens Stripe Connect Onboarding (embedded)
- Returns to app when complete
- Success state: "✅ Bank Connected - You're ready to receive payments"

### **3. Client Payment Screen**
- Screen: "Project Payment - $15,000"
- Milestone breakdown (table):
  - Milestone name, description, amount
  - Total at bottom
- "Protected by Escrow" badge
- Explanation: "Your money is protected until you approve each stage"
- Payment form (Stripe Elements):
  - Card number
  - Exp date / CVC
  - Name
- Button: "Pay $15,000 Securely"
- Success: Redirect to project timeline

### **4. Protected Balance Dashboard (Client)**
- Widget on project timeline:
  - "Your Protected Balance: $12,000"
  - Breakdown:
    - ✅ Released: $3,000
    - 🔒 Protected: $12,000
  - Info icon → Explains escrow protection

### **5. Milestone Approval UI (Client)**
- Notification: "Smith Construction marked 'Demo Complete' ready for review"
- Button: "Review Milestone"
- Modal:
  - Milestone name + description
  - Photos from this milestone
  - Amount to be released: "$3,000"
  - Fee breakdown: "$2,910 to contractor ($90 processing fee)"
  - Info: "Payment arrives in contractor's account today"
  - Buttons:
    - "Approve & Release Payment" (green)
    - "Request Changes" (yellow)
    - "Dispute" (red)

### **6. Dispute Resolution (Both)**
- Client submits dispute reason
- Contractor responds with evidence
- Both can upload photos/messages
- Admin reviews (manual for MVP)
- Decision: Refund or Release
- Email notifications to both parties

---

## **Quick Wins to Add (7 hours)**

### **1. Estimated Completion Date (1 hour)**
**Location:** Project details screen
```dart
// Add to project creation
final estimatedEndDate = DateTime.now().add(Duration(days: 14));

// Display on timeline
Text('Est. Completion: ${DateFormat.yMMMd().format(estimatedEndDate)}');

// Progress bar
LinearProgressIndicator(
  value: currentDay / totalDays,
  backgroundColor: Colors.grey[200],
  valueColor: AlwaysStoppedAnimation(Colors.orange),
);
```

### **2. Email Notifications (3 hours)**
**Use Firebase Cloud Functions + SendGrid**
```javascript
// functions/src/index.ts
exports.onPhotoUploaded = functions.firestore
  .document('projects/{projectId}/updates/{updateId}')
  .onCreate(async (snap, context) => {
    const update = snap.data();
    const project = await getProject(context.params.projectId);

    // Send email to client
    await sendEmail({
      to: project.client_email,
      subject: `New update on your ${project.project_name}`,
      body: `${update.caption}\n\nView photos: ${getProjectLink(projectId)}`,
    });
  });

exports.onMilestoneApproved = functions.firestore
  .document('projects/{projectId}/milestones/{milestoneId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'approved' && after.status === 'approved') {
      // Send email to contractor
      await sendEmail({
        to: contractor.email,
        subject: `Payment released - ${milestone.name}`,
        body: `${client.name} approved your milestone. $${milestone.amount} is on the way!`,
      });
    }
  });
```

### **3. Before/After Photo Slider (3 hours)**
**Location:** Public contractor profile
```dart
// Add to update document
{
  photo_url: "...",
  photo_type: "before" | "progress" | "after", // NEW field
}

// Slider widget
class BeforeAfterSlider extends StatefulWidget {
  final String beforeUrl;
  final String afterUrl;

  // Swipe slider implementation
  // Shows before on left, after on right
  // Divider moves with finger drag
}
```

---

## **Revenue Projections**

### **Conservative (Year 1)**
- 150 Pro users @ $25/month = $3,750/month
- 30 Premium users @ $50/month = $1,500/month
- **Subscription revenue: $5,250/month = $63k/year**

**Transaction fees:**
- Avg contractor processes $50k/year in milestones
- 50% use instant (3%), 50% use standard (0.5%)
- Avg fee: 1.75%
- 180 paid users × $50k × 1.75% = $157,500/year (~$13k/month)

**Total Year 1: $76k subscription + $157k fees = $233k**

### **Optimistic (Year 1)**
- 400 Pro users @ $25/month = $10,000/month
- 80 Premium users @ $50/month = $4,000/month
- **Subscription revenue: $14,000/month = $168k/year**

**Transaction fees:**
- 480 paid users × $50k × 1.75% = $420k/year (~$35k/month)

**Total Year 1: $168k subscription + $420k fees = $588k**

---

## **Go-to-Market Strategy**

### **Phase 1: Beta Launch (Month 1-2)**
- Reach out to 20 local contractors
- Offer 3 months free + lifetime Pro pricing ($19/month)
- Get 10 active users with real projects
- Collect feedback, iterate fast

### **Phase 2: Content Marketing (Month 3-4)**
- Blog: "How to Get Paid Faster as a Contractor"
- YouTube: "Stop Waiting 60 Days for Payment"
- Case study: "How John's Roofing Tripled Their Projects with ProjectPulse"
- Post in contractor Facebook groups, Reddit r/contractor

### **Phase 3: Paid Ads (Month 5-6)**
- Google Ads: "contractor payment app", "get paid faster"
- Facebook/Instagram: Target contractors 25-55
- $2k/month ad spend
- Goal: $50 CAC, 20% conversion = 40 new users/month

### **Phase 4: Referral Loop (Month 6+)**
- Contractor shares public profile → client sees app
- Client asks contractor about it → contractor explains benefits
- "Powered by ProjectPulse" badge on portfolios
- Referral program: Refer contractor → both get 1 month free

---

## **Success Metrics**

### **Month 2 (MVP Validation)**
- 10 contractors actively using
- 20+ projects created
- 5+ projects using milestone payments
- $10k+ in transaction volume
- Positive feedback (NPS 40+)

### **Month 6 (Product-Market Fit)**
- 100+ paying contractors
- 70%+ retention after 3 months
- $50k+ monthly transaction volume
- 4+ star average rating
- Organic referrals happening

### **Year 1 (Scale)**
- 500+ paying contractors
- $200k+ annual revenue (conservative)
- Profitable after costs
- 10+ cities represented
- Raising seed round OR bootstrapping profitably

---

## **Next Steps (Implementation Order)**

### **Week 1: Milestone System Foundation**
1. Update Firestore schema (milestones subcollection)
2. Build milestone creation UI (contractor)
3. Add project templates (Kitchen, Bathroom, etc.)
4. Milestone list view (both contractor and client)

### **Week 2: Stripe Connect Integration**
1. Set up Stripe Connect in Firebase
2. Build contractor onboarding flow
3. Test Connect account creation
4. Store stripe_account_id in Firestore

### **Week 3: Payment Flow**
1. Client payment screen (Stripe Elements)
2. Payment Intent creation
3. Escrow holding logic
4. Protected balance dashboard (client view)

### **Week 4: Milestone Releases**
1. Milestone approval UI
2. Transfer to contractor (Stripe API)
3. Fee calculation and deduction
4. Transaction logging
5. Webhook handlers

### **Week 5: Polish & Quick Wins**
1. Add estimated completion date
2. Implement email notifications
3. Build before/after slider
4. Error handling & edge cases
5. End-to-end testing

### **Week 6: Launch Prep**
1. Marketing website updates
2. Help documentation
3. Onboarding flow improvements
4. Beta tester outreach
5. App Store submission

---

## **Legal/Compliance Notes**

### **Money Transmitter License**
- **Using Stripe Connect = Stripe handles compliance**
- We never hold funds ourselves
- Stripe is licensed in all 50 states
- ProjectPulse is just the platform/facilitator

### **1099 Reporting**
- Stripe handles 1099-K for contractors earning $600+/year
- We provide transaction reports
- Contractors responsible for filing taxes

### **Terms of Service Must Include:**
- Transaction fee disclosure (3% instant, 0.5% standard)
- Escrow holding period (until milestone approved)
- Dispute resolution process
- Refund policy
- Contractor classification (1099 vs W2 - not our responsibility)

### **Insurance**
- General Liability: $1M/$2M
- Errors & Omissions (E&O): $1M
- Cyber Liability: $1M
- Cost: ~$3-5k/year for startup

---

## **Team Hierarchy & Scalability**

### **Current Structure (MVP)**
**Flat hierarchy:**
```
Contractor (owner) → Team Members (workers)
```

- Contractor creates projects and milestones
- Team members can post photo updates
- All team members have equal permissions
- **Handles:** 1-20 person crews, small contractors

**Firestore schema (current):**
```javascript
{
  contractor_profile: {
    team_members: [
      { user_ref: "uid_1", email: "worker@email.com", added_at: timestamp }
    ]
  }
}
```

---

### **Phase 2: Role-Based Permissions**
**Add `role` field for 2-3 tier hierarchy:**

```
Owner (GC)
├── Project Manager
│   ├── Worker 1
│   ├── Worker 2
├── Project Manager 2
    ├── Worker 3
    ├── Worker 4
```

**Roles:**
- `owner` - Full control, manages milestones/payments, sees everything
- `project_manager` - Can invite workers, see all updates on their projects, cannot edit milestones
- `worker` - Can post updates only, limited visibility

**Schema update:**
```javascript
{
  team_members: [
    {
      user_ref: "sarah_uid",
      email: "sarah@company.com",
      role: "project_manager",
      projects: ["project_1", "project_2"], // Which projects they can access
      added_at: timestamp,
    },
    {
      user_ref: "joe_uid",
      role: "worker",
      projects: ["project_1"],
      added_at: timestamp,
    }
  ]
}
```

**Handles:** Mid-size contractors with 50-150 people, $5M-20M revenue

**Timeline:** 1-2 weeks after MVP launch

---

### **Phase 3: Nested Organizations (Future)**
**Subcontractors have their own accounts:**

```
GC (Smith Construction)
├── Subcontractor (Joe's Electric) - has own contractor account
│   ├── Electrician 1
│   ├── Electrician 2
├── Subcontractor (Mike's Plumbing) - has own contractor account
    ├── Plumber 1
    ├── Plumber 2
```

**How it works:**
1. GC invites subcontractor to project (sub already has contractor account)
2. Sub sees project in THEIR dashboard
3. Sub manages their own team
4. GC sees sub's updates on main timeline
5. Payment splits: GC milestone → auto-pays sub (if configured)

**Schema update:**
```javascript
// projects/{project_id}
{
  primary_contractor_ref: "smith_uid",
  subcontractors: [
    {
      contractor_ref: "joes_electric_uid",
      scope: "Electrical rough-in and finish",
      payment_amount: 5000,
      milestones: ["elec_m1", "elec_m2"],
    },
    {
      contractor_ref: "mikes_plumbing_uid",
      scope: "Plumbing",
      payment_amount: 4000,
      milestones: ["plumb_m1"],
    }
  ]
}
```

**Handles:** Large GCs with 200+ people, nested payment flows, $20M+ revenue

**Timeline:** 3-4 weeks, build after 50+ paying contractors request it

### **Phase 3 Deep Dive: Subcontractor Payment Flow**

**Payment Splitting Options:**

**Option A: Each party pays their own fee (Recommended)**
```
GC's milestone approved: $4,500
├── Sub 1 (Joe's Electric): $2,000 → Pays 3% ($60) → Gets $1,940
├── Sub 2 (Mike's Plumbing): $1,500 → Pays 3% ($45) → Gets $1,455
└── GC keeps: $1,000 → Pays 3% ($30) → Gets $970

Total fees collected: $135
PP net revenue: ~$100 (after Stripe costs)
```

**Option B: GC pays all fees**
```
GC's milestone approved: $4,500
├── PP charges GC: $135 (3% on full milestone)
├── Sub 1: $2,000 (no fee)
├── Sub 2: $1,500 (no fee)
└── GC gets: $865

Problem: GC loses $105 vs Option A
```

**Recommendation:** Option A - Fair, transparent, each business pays for their own instant payout.

**UI Flow:**
1. Client approves milestone ($4,500)
2. System detects subs assigned to this milestone
3. GC sees modal:
   ```
   Milestone Approved - $4,500

   Split Payment?

   ☑ Joe's Electric: $2,000 (3% fee = $60)
       Will receive: $1,940 today

   ☑ Mike's Plumbing: $1,500 (3% fee = $45)
       Will receive: $1,455 today

   Your share: $1,000 (3% fee = $30)
   You receive: $970 today

   [Release All Payments]  [Custom Split]
   ```
4. All parties paid instantly

**Benefits to GC:**
- Don't have to manually pay subs (saves time)
- Subs get paid same day (happy subs = better work)
- Transparent paper trail for taxes
- No float risk (don't need cash on hand to pay subs)

**Benefits to Subs:**
- Get paid 60-90 days faster
- No chasing GC for payment
- Professional image
- Can use PP for their own projects too

**Schema additions:**
```javascript
// projects/{project_id}/milestones/{milestone_id}
{
  // ... existing fields ...

  // NEW: Payment splits
  payment_splits: [
    {
      contractor_ref: "joes_electric_uid",
      amount: 2000,
      percentage_of_milestone: 44.4, // 2000/4500
      status: "pending" | "released" | "disputed",
      released_at: timestamp,
      released_amount: 1940, // After 3% fee
      transaction_fee: 60,
    }
  ],
  primary_contractor_amount: 1000,
  primary_contractor_released: 970,
}
```

---

## **Edit Milestones Feature**

**Use Case:** Contractor needs to restructure milestones after project starts (NOT adding cost, just changing structure).

**Rules:**
- ✅ Can edit if milestone is `pending` or `in_progress`
- ❌ Cannot edit if `awaiting_approval` or `approved` (money involved)
- ✅ Total must still equal project cost
- ✅ Client receives notification and must approve changes

**UI Flow:**
```
[Contractor Project View]
Milestones (4)  [Edit Structure]
  ↓
[Edit Milestones Screen]
- Shows current milestones
- Can add/remove/reorder ONLY unlocked milestones
- Locked milestones shown with 🔒 icon
- Warning: "Client will be notified of changes"
- Save → Client notification
  ↓
[Client Notification]
"Smith Construction updated project milestones"
[View Changes] [Approve] [Discuss]
  ↓
[Comparison View for Client]
Before:                     After:
1. Demo - $3,000 ✅        1. Demo - $3,000 ✅ (locked)
2. Rough - $4,500          2. Electrical - $2,000
3. Cabinets - $4,500       3. Plumbing - $2,500
4. Final - $3,000          4. Cabinets - $4,500
                           5. Final - $3,000

[Approve Changes] [Request Discussion]
```

**Firestore Schema:**
```javascript
// projects/{project_id}
{
  milestone_edit_history: [
    {
      edited_at: timestamp,
      edited_by_ref: contractor_ref,
      approved_by_client_at: timestamp | null,
      status: "pending_approval" | "approved" | "rejected",
      changes: {
        added: [milestone_ids],
        removed: [milestone_ids],
        modified: [milestone_ids],
      }
    }
  ]
}
```

**When to Build:** After timeline view is complete (v0.0.43)

---

## **Client Notification System**

**Phase 1 (MVP - v0.0.42):** In-app notification badges
- ✅ Track notification events in Firestore
- Show red badge on milestone cards needing attention
- Visual indicators when opening app
- **Status:** Implemented (data tracking only)

**Phase 2 (Week 3 - with Stripe):** Email notifications via SendGrid
- Critical actions: milestone approvals, payments released, structure changes
- Firebase Cloud Functions triggers
- SendGrid free tier: 12,000 emails/month
- **Triggers:**
  - Milestone awaiting approval
  - Milestone structure changed
  - Payment released
  - Change order requested
- **Timeline:** 1 day implementation, build with payment flow

**Phase 3 (After PMF):** Push notifications via FCM
- Real-time alerts for all actions
- Requires client to have app installed
- **Timeline:** 2-3 days implementation

**Note:** Email notifications are essential before launch since clients may not have app installed initially (invited via link).

---

## **Open Questions / Decisions Needed**

1. ✅ **Escrow model:** Full upfront payment (decided)
2. ✅ **Transaction fees:** 3% instant (absorb Stripe's 1.5% for MVP, may raise to 4.5% after PMF) (decided)
3. ✅ **Team hierarchy:** Flat for MVP, role-based Phase 2, nested orgs Phase 3 (decided)
4. ✅ **Edit milestones:** Can edit unlocked milestones, requires client approval (decided - Option A)
5. ✅ **Sub payment splits:** Each party pays their own 3% fee (decided - Option A)
6. 📝 **MVP scope:** Launch with GC → Client only, revisit sub feature after launch based on contractor feedback
7. ⏳ **Dispute resolution:** Manual admin review for MVP, automate later?
8. ⏳ **Refund policy:** Full refund if 0 milestones approved? Partial if some approved?
9. ⏳ **Max escrow period:** Auto-refund if contractor inactive for 30 days?
10. ⏳ **Client payment methods:** Card only, or also ACH/bank transfer?
11. ⏳ **International contractors:** US only for MVP, expand later?

---

**This is the complete vision. Let's build it.**
