# 🛍️ Online Shop Management System

A complete online shopping system that allows customers to browse and purchase products, vendors to manage and sell their own products, and administrators to manage the entire platform.

---

## 📌 Why Do We Use This Website?

This website is designed to provide a complete online shopping platform where:

- 👤 Users can browse and purchase products.
- 🏪 Vendors can add and sell their own products.
- 🛠️ Admins can manage users, vendors, products, orders, payments, and the overall system.
- 💳 Users can make payments before placing orders.
- 📦 Users can track their order status.
- ⭐ Users can provide feedback and reviews.
- 💬 Users can communicate with Chat Support.
- 📊 Admins can view reports and system activities.

The main purpose of this system is to connect **Customers, Vendors, and Admins** in one platform.

---

# 👥 User Roles

The system has three main roles:

## 1. 👤 User

A User is a customer who can:

- Register an account
- Login / Logout
- Browse products
- Search for products
- View product details
- Add products to cart
- Manage cart quantity
- Add products to favorites
- Checkout
- Enter delivery information
- Make payment
- Place orders
- View Order History
- Track order status
- View payment information
- Give product feedback/reviews
- Use Chat Support
- Manage their profile
- Change settings

### User Order Flow

```text
Login
   ↓
Browse Products
   ↓
Select Product
   ↓
Add to Cart
   ↓
View Cart
   ↓
Checkout
   ↓
Enter Delivery Address
   ↓
Scan / Complete Payment
   ↓
Payment Verification
   ↓
"I Have Paid - Place Order"
   ↓
Order Created
   ↓
Track Order
   ↓
Delivered
   ↓
Give Feedback
```

## 2. 🏪 Vendor

A Vendor is a seller who can manage and sell their own products.

### Vendor Features

- Login
- Vendor Dashboard
- Add Product
- View Product
- Edit Product
- Delete Product
- Manage Product Price
- Manage Product Stock
- Manage Product Images
- View Orders
- See which customers ordered their products
- View Order Details
- Track Order Status
- View Payments
- View Sales / Revenue
- View Customer Feedback
- View Product Ratings

### Vendor Flow

```text
Login
   ↓
Vendor Dashboard
   ↓
Add Product
   ↓
Product Available in Shop
   ↓
Customer Purchases Product
   ↓
Vendor Receives Order
   ↓
View Customer / Order Information
   ↓
Manage Order
   ↓
Receive Payment
   ↓
View Customer Feedback
```

### Vendor Permission

A Vendor can only manage:

- Their own products
- Their own orders
- Payments related to their products
- Feedback related to their products

A Vendor **cannot** edit or delete another Vendor's products.

## 3. 🛠️ Admin

The Admin manages the entire online shop system.

### Admin Features

- Dashboard
- Manage Users
- Manage Vendors
- Manage Products
- Manage Categories
- Manage Shops
- Manage Orders
- Manage Payments
- Manage Feedback
- Reports
- Notifications
- Settings
- Administration
- Roles & Permissions
- Activity Logs

### Admin Order Flow

```text
New Order
   ↓
Processing
   ↓
Shipped
   ↓
Delivered
```

The Admin can update the order status, and the User should see the same latest status in their Order History.

For example:

```text
Admin:
Order #1001 → Delivered
        ↓
User:
Order History → Order #1001 → Delivered
```

## 🔔 Notifications

The Admin notification system can show important events such as:

- New Order
- New User
- New Vendor
- Payment Received
- Order Status Changed
- New Feedback
- Low Stock
- Cancelled Order

Example:

```text
🔔 New Order
A customer placed a new order.

👤 New User
A new user registered.

📦 Order Delivered
Order #1001 has been delivered.

⚠️ Low Stock
Product "Example Product" has low stock.
```

## 📊 Reports

The Reports page provides information about the shop. Reports can include:

- Total Sales
- Total Revenue
- Total Orders
- Processing Orders
- Shipped Orders
- Delivered Orders
- Cancelled Orders
- Total Users
- Total Vendors
- Best-Selling Products
- Product Performance
- Customer Statistics
- Sales Charts
- Revenue Charts

## ⚙️ Settings

The Settings page allows the Admin to configure the system.

### General Settings

- Store Name
- Store Logo
- Store Email
- Phone Number
- Address

### Order Settings

- Order Status
- Order Rules
- Cancellation Settings

### Payment Settings

- Payment Methods
- Currency
- Payment Configuration

### Shipping Settings

- Delivery Methods
- Delivery Fee
- Delivery Areas

### Language

- 🇬🇧 English
- 🇰🇭 Khmer

### Security

- Change Password
- Security Settings
- Login Sessions

## 🛡️ Administration

The Administration section controls system-level management.

### Administration Features

- Admin Users
- Vendor Management
- Roles & Permissions
- Activity Logs
- System Management

Example:

```text
Administration
├── Admin Users
├── Vendors
├── Roles & Permissions
├── Activity Logs
└── System Management
```

## 💳 Payment Flow

Payments use KHQR and are verified through the **Bakong Open API** — the system verifies that the money actually arrived before an order can be placed.

### Verified Payment Flow (implemented)

```text
Checkout → Delivery Address
        ↓
Payment QR displayed (payment registered as PENDING)
        ↓
User Scans QR & Completes Payment
        ↓
Backend asks Bakong (check_transaction_by_md5) every 5s
        ↓
Payment VERIFIED → "I Have Paid - Place Order" Enabled
        ↓
Click Button → Backend re-verifies → Order Created
```

### If Payment Is Not Completed

```text
Payment QR displayed
        ↓
No successful payment at Bakong
        ↓
Button stays DISABLED — "Waiting for payment confirmation..."
        ↓
Order Cannot Be Created
```

How it is enforced:

- The **"I have paid — place order" button stays disabled** until every vendor share of the payment is VERIFIED (a per-QR status chip shows *Payment verified / Checking payment… / Payment not received yet*).
- Tapping without a verified payment shows **"Please complete the payment before placing your order."**
- Opening or scanning the QR is **never** treated as payment — only Bakong's `responseCode = 0` for the exact QR hash marks a payment VERIFIED.
- The backend function `create_verified_order` **re-verifies the payment server-side** before inserting the order, so the client's button state alone is never trusted.
- The order id equals the checkout reference, making the RPC **idempotent** — repeated taps can never create duplicate orders.
- Fail closed: if Bakong or the cloud cannot be reached, everything reports NOT verified and no order can be placed.

Setup: enable the `http` extension, run `supabase_payments.sql`, then store your Bakong developer token in the Vault as `BAKONG_API_TOKEN` (see the file's header comments).

## 📦 Order Tracking

Users can follow their orders through Order History.

Example:

```text
Processing
    ↓
Shipped
    ↓
Delivered
```

When the Admin changes the status, the User sees the updated status.

Example:

```text
Admin Orders Page
       ↓
Status = Shipped
       ↓
Database / API
       ↓
User Order History
       ↓
Status = Shipped
```

## 💬 Chat Support

Chat Support helps users ask questions about the system and their shopping experience.

The Chat Support:

- Understands the user's question.
- Answers the specific question.
- Remembers the current conversation context.
- Answers related follow-up questions.
- Saves questions and answers.
- Avoids repeating the same answer unnecessarily.
- Provides relevant answers instead of generic responses.

Example:

```text
User:
Where is my order?

Chat Support:
Your order #1001 is currently Shipped.

User:
When did it ship?

Chat Support:
Your order was changed to Shipped on the latest order update.
```

## 🔄 Real-Time Updates

The Admin pages automatically update when new data becomes available, powered by Supabase Realtime.

For example — Orders Page:

If the Admin is already on the Orders Page and a User places a new order:

```text
User Places Order
       ↓
New Order Saved
       ↓
Orders Page Detects New Data
       ↓
New Order Appears Automatically
```

The Admin does not need to:

- Refresh the browser manually
- Leave the page
- Open another page
- Return to the Orders Page

The existing design and functionality remain unchanged.

---

# 🧑‍💻 Technology Stack

| Part | Technology |
|---|---|
| **Frontend** | Flutter |
| **Programming language** | Dart |
| **Architecture** | MVP (View → Presenter → Repository → API Service) |
| **Backend** | Supabase (PostgREST auto REST API + Realtime + Auth) |
| **Database** | PostgreSQL (hosted on Supabase) |
| **API** | Supabase client / REST API |
| **Sign-in options** | Username + password, Google Sign-In, Telegram |

### Frontend

The frontend is developed using **Flutter** and **Dart**. Flutter builds the application's user interface and application logic.

Main frontend areas include:

```text
UI
 ↓
Pages / Screens
 ↓
Widgets
 ↓
Controllers / Presenters
 ↓
Repositories
 ↓
API Service
 ↓
Model
```

### Backend

The backend is **Supabase** — a hosted platform built on PostgreSQL that provides:

- **REST API** — every table is automatically exposed as a secure REST endpoint (PostgREST); no custom server code is required.
- **Realtime** — database changes are streamed live to the app (new orders, new users, new feedback appear in the admin panel instantly).
- **Auth** — vendor/admin authorization is resolved from Supabase Auth JWT claims (see `supabase_vendor_security.sql`).

The app also keeps a DummyJSON demo fallback (`https://dummyjson.com`) for offline / read-only mode when the cloud database is unreachable.

### Database

The database is **PostgreSQL**, hosted on Supabase. The main tables are:

| Table | Purpose |
|---|---|
| `products` | Products / shops (with `vendor_username`, `status`, `verified`) |
| `categories` | Product categories (slug, name, description, image) |
| `app_users` | Shop accounts (SHA-256 password hashes, `role`: user / vendor / admin) |
| `orders` | Orders with a full product snapshot per item |
| `feedback` | Customer feedback and ratings (optionally tied to a product) |

---

# 🏗️ Project Architecture

The project follows a structured architecture (MVP) to separate UI, business logic, data, and API communication:

```text
lib/
│
├── main.dart               # Combined app: shop + admin (default entry)
├── main_admin.dart         # Admin dashboard only
├── main_user.dart          # User shop only (admin UI hidden)
├── app_mode.dart           # Which frontend is running
│
├── models/                 # Data classes (User, Product, Category, Order, FeedbackItem...)
│
├── views/                  # UI screens
│   ├── views.dart          #   Shop: home, cart, checkout, orders, profile...
│   ├── admin_panel.dart    #   Admin: dashboard, shops, categories, products,
│   │                       #         users, orders, feedback, reports + detail pages
│   ├── vendor_panel.dart   #   Vendor dashboard
│   ├── admin_sections.dart #   Shared admin widgets (tables, dialogs)
│   ├── chat_support_page.dart
│   └── info_pages.dart
│
├── presenters/             # Business logic between views and repositories
│
├── repositories/           # Data sources (cloud first, local fallback)
│
├── services/
│   ├── api_service.dart            # DummyJSON demo API
│   ├── supabase_service.dart       # Supabase cloud database + realtime
│   ├── google_auth_service.dart    # Google Sign-In
│   ├── telegram_auth_service.dart  # Telegram login
│   ├── app_settings.dart           # Session, settings, admin activity log
│   └── support_bot.dart            # Chat support brain
│
└── l10n/                   # Localization (English 🇬🇧 / Khmer 🇰🇭)
```

```text
View → Presenter → Repository → API Service → Supabase (PostgreSQL) → Model → View
```

---

# 🚀 How to Run the Project

## 1. Requirements

Install:

- Flutter SDK (includes Dart)
- Git
- A browser (Chrome) for web, and/or an Android device/emulator
- A Supabase project (free tier works) — see Database Setup below

Check Flutter:

```bash
flutter doctor
flutter --version
```

## 2. Get the project and dependencies

```bash
git clone <your-repo-url>
cd <your-project-folder>
flutter pub get
```

## 3. ▶️ Run the Frontend

The two frontends share ONE backend (the Supabase cloud database), so everything changed in the admin app appears in the user app instantly — and the other way around.

### Windows — one-command scripts (`run.bat`)

```text
run.bat admin     ADMIN dashboard in Chrome
run.bat user      USER shop app in Chrome
run.bat phone     USER shop app on a connected Android phone
run.bat both      ADMIN + USER together (two Chrome windows)
```

### Or with Flutter directly

```bash
# Admin dashboard
flutter run -d chrome -t lib/main_admin.dart

# User shop
flutter run -d chrome -t lib/main_user.dart

# Default combined app (shop + admin for admins on desktop)
flutter run
```

### Build for release

```bash
flutter build web -t lib/main_admin.dart   # admin web app
flutter build web -t lib/main_user.dart    # user web app
flutter build apk  -t lib/main_user.dart   # Android shop app
```

---

# 🗄️ Database Setup

The database is Supabase (PostgreSQL). Setup is done once from the Supabase dashboard:

1. Create a project at [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Open **SQL Editor → New query**
3. Paste the whole contents of **`supabase_schema.sql`** and click **RUN**
   — creates the tables (`products`, `categories`, `app_users`, `orders`, `feedback`), RLS policies, and Realtime publications
4. Then paste **`supabase_vendor_security.sql`** and click **RUN**
   — adds vendor/admin roles, `vendor_username`, per-vendor security views and RLS
5. Then paste **`supabase_payments.sql`** and click **RUN**
   — adds the `payments` table plus the payment-verification functions (`verify_payment`, `create_verified_order`) that enforce Bakong-verified payment before any order is created

The connection settings live in `lib/services/supabase_service.dart` (`url` + `publishableKey`). Point them at your own Supabase project if you fork the app.

> ⚠️ **Production note:** the starter schema opens RLS to the `anon` role for demo purposes. Before real customers, apply the hardening steps described at the bottom of `supabase_schema.sql` (scoped policies + Supabase Auth).

---

# 🔑 Telegram Sign-In Setup

The **Continue with Telegram** button lets every user log in with their own Telegram account (name, @username and profile photo are used as the shop profile). This uses Telegram's official Login Widget and needs a one-time setup by the shop owner:

1. In the Telegram app, open **@BotFather** → send `/newbot` → choose a display name and a username that ends with `bot` (for example `GlobalOnlineShopBot`). This is free and takes one minute.
2. Still in **@BotFather**, open your bot → **Login Widget** → add an **Allowed URL**: create a free short link that opens the app (for example `https://myshop.tinyurl.com`) and add it there. Telegram only shows the login confirmation when the login page is opened from this exact URL.
3. In the app, open **Settings → Telegram Sign-In**, paste the bot username (with or without `@`) and the same Allowed URL, then tap **Save**. The app opens the login page from that URL, so Telegram shows the confirm step and the app receives the account.

That's it — every device can now **Continue with Telegram** and each user signs in with their own Telegram account.

> ⚠️ A **personal** Telegram account (for example `@Lin_Sreymao`) cannot be used for login — Telegram only allows the Login Widget for bots created with @BotFather. The personal account stays useful as the support contact on the Contact Us page.

> ℹ️ If Telegram is not configured yet, tapping **Continue with Telegram** opens a step-by-step setup dialog (with a copy button for the Allowed URL and a direct link to @BotFather) instead of signing in as a guest.

---

# 🔑 Google Sign-In Setup (Android)

The account picker opens but sign-in fails with the "Google Sign-In setup incomplete" message when the app itself is not registered with Google:

1. Go to [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials) (open the dialog in the app — it shows this computer's debug SHA-1 with a copyable field).
2. In the SAME project as your Web client ID: **Create credentials → OAuth client ID → Android**.
3. Package name: `com.example.online_shop_mvp_full`; SHA-1: your debug keystore's SHA-1 (`keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`).
4. Save, wait 5–10 minutes for Google to propagate, then rebuild and run the app again.

> The Web client ID alone authorizes the token request; the Android client authorizes **this app** (package + SHA-1). Both must live in the same Google Cloud project.

---

# 👤 How to Run as User

1. Start the app (user frontend or combined app).
2. Open the Login page.
3. Login with a User account.
4. Browse products.
5. Add products to the cart.
6. Checkout.
7. Enter delivery information.
8. Complete payment.
9. Place the order.
10. Open Order History.
11. Track the order status.

# 🏪 How to Run as Vendor

1. Start the app.
2. Login with a Vendor account.
3. Open the Vendor Dashboard.
4. Add a product.
5. Manage your products.
6. Wait for customers to purchase your products.
7. View customer orders.
8. View payment information.
9. Manage your products and stock.
10. View customer feedback.

# 🛠️ How to Run as Admin

1. Start the app (`run.bat admin` or the combined app on a computer).
2. Login with an Admin account — admins land directly on the Admin Dashboard.
3. Manage Users.
4. Manage Vendors.
5. Manage Products / Shops / Categories.
6. Manage Orders.
7. Manage Feedback.
8. View Reports.
9. Manage Settings.
10. Manage Administration and permissions.

### Demo login (offline fallback mode)

```text
username: emilys
password: emilyspass
```

---

# 🔐 Role Permissions

| Feature | User | Vendor | Admin |
|---|:-:|:-:|:-:|
| Browse Products | ✅ | ✅ | ✅ |
| Buy Products | ✅ | ✅ | ✅ |
| Add Product | ❌ | ✅ | ✅ |
| Edit Own Product | ❌ | ✅ | ✅ |
| Delete Own Product | ❌ | ✅ | ✅ |
| View Own Orders | ✅ | ✅ | ✅ |
| View Customer Orders | ❌ | ✅ | ✅ |
| View Payments | Own | Own Products | All |
| View Feedback | Own Purchases | Own Products | All |
| Manage Users | ❌ | ❌ | ✅ |
| Manage Vendors | ❌ | ❌ | ✅ |
| Manage All Products | ❌ | ❌ | ✅ |
| Manage All Orders | ❌ | ❌ | ✅ |
| Reports | ❌ | Own Sales | ✅ |
| Administration | ❌ | ❌ | ✅ |

---

# 🔄 Main System Flow

```text
                    ONLINE SHOP
                         │
          ┌──────────────┼──────────────┐
          ↓              ↓              ↓
        USER           VENDOR          ADMIN
          │              │              │
          ↓              ↓              ↓
      Buy Product    Sell Product    Manage System
          │              │              │
          ↓              ↓              ↓
       Payment       Manage Orders    Manage Orders
          │              │              │
          ↓              ↓              ↓
        Order        Get Payment      Reports
          │              │              │
          ↓              ↓              ↓
    Order History    Feedback        Notifications
          │
          ↓
      Delivered
          │
          ↓
       Feedback
```

---

# 🧪 Tests

```bash
flutter test
```

> Note: inside `flutter test` the cloud calls are short-circuited automatically and the app falls back to its local data sources, so the tests run without network access.

---

# 🎯 Project Goal

The goal of this project is to build a complete online shopping platform that provides:

- Easy shopping for customers
- Product management for vendors
- Complete system management for admins
- Secure payment verification
- Order tracking
- Customer feedback
- Real-time order updates
- Chat Support
- Role-based access control

The system connects **Users, Vendors, and Admins** in one online shopping platform.
