# Freight Management System – End-to-End Flow

---

## 1. User Entry & Authentication Flow

### 1.1 Platform Entry
1. User opens the platform  
2. System checks: Is user registered?

---

### 1.2 If NOT Registered (Transporters Only)

3. User proceeds to registration  
4. Transporter fills details:
   - Business Name  
   - Owner Name  
   - Email  
   - Business Number  
   - Mobile Number  
   - GST (optional)  
   - Vehicles (optional)  
   - Drivers (optional)  
   - Documents (optional)  
   - Bank Account Details (Account No, IFSC, Check Upload)

5. Admin reviews registration  

6. Decision:
   - If Rejected → End  
   - If Approved → Access Granted  

---

### 1.3 If Registered

7. System performs login role check  

8. User is redirected to:
   - Admin Panel  
   - Logistics Manager  
   - Accounts Manager Panel  
   - Transporter  

---

## 2. Admin Dashboard Flow

### 2.1 Dashboard Entry

1. Admin logs in  
2. Lands on Admin Dashboard  

---

### 2.2 User Management

3. Admin can:
   - Add users  
   - Remove users  

4. User types:
   - Transporters  
   - Logistics Managers  

---

### 2.3 Permissions

5. Admin sets permissions per user:
   - Edit Freight  
   - View Analytics  
   - Finalise Booking  
   - View Only  

---

### 2.4 Monitoring

6. Admin can monitor:
   - All Bids (with IDs)  
   - Analytics  
   - Freight Lock status  
   - Invoice Mapping  
   - Cost Trends  

7. Admin can:
   - Add remarks on freight charges  

---

## 3. Admin / Logistics Analytics & Reporting Flow

### 3.1 Entry

1. Admin / Logistics Manager logs in  
2. Lands on Dashboard View  

---

### 3.2 Analytics Dashboard

3. User views:
   - Monthly Freight Total  
   - Transporter-wise Business Volume  
   - Per Case Freight Cost  
   - Per Unit Freight Cost  
   - Situation-wise Freight Match Trends  
   - Invoice vs Freight Match Reports  
   - Duplicate Freight Detection Alerts  

---

### 3.3 Report Generation

4. User generates reports:
   - Scheduled on 15th / 30th  
   - Transporter business contribution  
   - Total Freight Paid  
   - Cost trends  

5. Export formats:
   - PDF  
   - Excel  
   - CSV  

---

## 4. Bidding & Dispatch Flow (Core System)

### 4.1 Bidding Setup

1. Admin / Logistics Manager:
   - Sets internal calling bid (optional, anonymous)  
   - Defines bid-wise transporter preferences  

---

### 4.2 Bidding Start

2. Publish bidding  
3. Notify transporters  

4. Bidding window opens:
   - View bidders  
   - View bid amounts  
   - View details  

---

### 4.3 Winner Selection

5. Select winning transporter  
6. Notify winner  

7. Confirm dispatch details:
   - Vehicle Number  
   - Driver Name  
   - Driver Phone  
   - Dispatch confirmation  

---

### 4.4 Time Constraint Check

8. Check: Submitted within time?

---

#### Case A: Not within time

9. Penalty triggered:
   - Flag transporter  
   - Notify admin/logistics  
   - Re-bid OR manual assignment  

---

#### Case B: Within time

10. Proceed to cost adjustments  

---

### 4.5 Mid Cost Adjustments

11. Add:
   - Invoice Number (by logistics manager)  
   - Toll charges  
   - Club charges  
   - Dalla charges  
   - Other charges  

12. Subject to approval  

---

## 5. Freight–Invoice Linking Flow

1. Link freight with invoice using:
   - Invoice Number  
   - GR / Bilty Number  
   - Transporter (self / external)  
   - Town  
   - Weight  
   - Cases  

---

## 6. Invoice Validation Flow

1. Perform invoice check  

---

### Case A: Issue Found

2. Send alert  

---

### Case B: Valid

3. Finalize:
   - Base freight  
   - Additional charges  
   - Fully linked to Invoice & GR  

---

## 7. Post-Lock Handling

1. Check: Charges after lock?

---

### Case A: Yes

2. Admin adds remarks  

---

### Case B: No

3. Mark as Completed  

---

## 8. Transporter Flow

### 8.1 Entry

1. Transporter receives bid notification  
2. Opens app  

---

### 8.2 Bid Viewing

3. Opens bid request  

4. Views:
   - Town  
   - Weight  
   - Cases  
   - Time left  
   - Current ranking (anonymous)  

---

### 8.3 Decision

5. Check: Wants to bid?

---

#### Case A: No

6. Exit bid  

---

#### Case B: Yes

7. Enter bid price  

---

### 8.4 Live Bidding

8. View live bid board:
   - Rank  
   - Price  
   - Anonymous competitors  

---

### 8.5 Bidding Window

9. Check: Is bidding open?

---

#### Case A: Open

10. Transporter can modify bid  
(Loop until closed)

---

#### Case B: Closed

11. Bids are locked  

---

### 8.6 Result

12. System finalizes bids  
13. Winner is notified  

---

## 🔑 System-Level Understanding

- Authentication flow controls **who enters**
- Admin panel controls **who exists & what they can do**
- Bidding system is the **core transaction engine**
- Invoice linking is the **source of truth**
- Analytics & reports are **decision layers**
- Alerts & penalties handle **exceptions**

---

## 🧠 Key Design Insight

- This is NOT just CRUD  
- This is a **state-driven system**:
