<div align="center">

# 🚕 Palestine Taxi Service

**A comprehensive digital platform for modernizing shared taxi transportation in Palestine**

<br/>

<img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=whsite" alt="Node.js" />
<img src="https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white" alt="Express" />
<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
<img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
<img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase" />
<img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
<img src="https://img.shields.io/badge/Stripe-008CDD?style=for-the-badge&logo=stripe&logoColor=white" alt="Stripe" />
<img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />

<br/><br/>

[Features](#-features) &nbsp;&bull;&nbsp; [Architecture](#-architecture) &nbsp;&bull;&nbsp; [Quick Start](#-quick-start) &nbsp;&bull;&nbsp; [API Reference](#-api-reference) &nbsp;&bull;&nbsp; 
<br/>

</div>

---

## 🚖 About

**Palestine Taxi Service** digitizes village taxi aggregator stations — central hubs inside Palestinian cities where shared service taxis depart to villages and return. The platform serves **passengers**, **drivers**, and **station administrators** through mobile apps, a web dashboard, and a walk-in terminal.

Unlike ride-sharing (Uber/Careem), Palestinian service taxis operate on **fixed routes**, carry **4–7 passengers**, depart when full or at **scheduled times**, and charge **fixed affordable fares** managed by local aggregators.

> 🚕 **Design Philosophy** — Enhance the existing aggregator system without radical changes. Respect driver autonomy (vehicles are driver-owned), preserve community practices, and layer modern digital tools on top.

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 🚕 Passengers
- 📱 Book via mobile app (iOS / Android / Web)
- 🖥️ Walk-in terminal for non-app users
- ⚡ Instant & future trip reservations
- 💳 Digital wallet + Stripe card top-up
- 💵 Cash payment for walk-ins
- 📲 QR code boarding pass
- 🔔 Real-time push notifications
- 🌐 Arabic (RTL) & English

</td>
<td width="50%" valign="top">

### 🚕 Drivers
- 📋 Fair FIFO queue-based trip assignment
- 📍 GPS-verified station check-in
- 🔄 Separate going / return queues
- 💰 Automatic wallet earnings
- 📷 QR scanner for passenger check-in
- 🗺️ Navigation & trip management
- 📊 Earnings history & tracking
- 🚗 Vehicle profile management

</td>
</tr>
<tr>
<td colspan="2">

### 🚕 Administrators
📊 Analytics dashboard &nbsp;|&nbsp; 📅 Schedule templates &nbsp;|&nbsp; 📈 Demand predictions &nbsp;|&nbsp; 👥 User & driver approval management &nbsp;|&nbsp; 🗺️ Route & station management &nbsp;|&nbsp; ⚙️ System configuration &nbsp;|&nbsp; 💳 Payment tracking &nbsp;|&nbsp; 🌙 Dark / light themes

</td>
</tr>
</table>

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      📱  FLUTTER FRONTEND                       │
│                                                                 │
│   👤 Passenger App    🚕 Driver App    ⚙️ Admin Dashboard       │
│                       🖥️ Walk-in Terminal                       │
└───────────────────────────────┬─────────────────────────────────┘
                                │  HTTPS / REST (JSON)
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   🖥️  NODE.JS + EXPRESS API                     │
│                                                                 │
│  🔐 Auth (JWT)     🚕 Trips & Bookings    💳 Payments & Wallets │
│  📋 Driver Queue    📅 Schedule Jobs       📈 Demand Analytics   │
│  ⭐ Ratings         📍 Location Tracking   🔔 Notifications     │
└──────────┬──────────────────┬───────────────────┬───────────────┘
           │                  │                   │
           ▼                  ▼                   ▼
    ┌─────────────┐   ┌─────────────┐    ┌─────────────┐
    │ 🗄️ Supabase │   │ 🔥 Firebase │    │ 💳 Stripe   │
    │ PostgreSQL  │   │    FCM      │    │  Payments   │
    └─────────────┘   └─────────────┘    └─────────────┘
```

### Tech Stack

| Layer | Technologies |
|:---|:---|
| **Backend** | Node.js &bull; Express.js &bull; JWT &bull; bcryptjs &bull; node-cron &bull; Swagger/OpenAPI |
| **Frontend** | Flutter &bull; Dart &bull; Material Design 3 &bull; fl_chart &bull; flutter_map |
| **Database** | Supabase (PostgreSQL) &bull; UUID keys &bull; Row-Level Security &bull; Real-time |
| **Payments** | Stripe SDK &bull; Payment Intents &bull; Webhooks &bull; Digital Wallets |
| **Notifications** | Firebase Cloud Messaging &bull; Admin SDK &bull; Device Token Management |
| **Analytics** | simple-statistics &bull; Rush hour detection &bull; Demand prediction |
| **Utilities** | Nodemailer &bull; QRCode &bull; Multer &bull; date-fns &bull; Luxon |

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version |
|:---|:---|
| **Node.js** | >= 18.x |
| **npm** | >= 9.x |
| **Flutter** | >= 3.x |
| **Dart** | >= 3.x |

External accounts needed: [Supabase](https://supabase.com) &bull; [Stripe](https://stripe.com) &bull; [Firebase](https://firebase.google.com)

### Backend

```bash
# Clone & install
git clone https://github.com/<your-username>/palestine-taxi-service.git
cd palestine-taxi-service
npm install

# Configure
cp .env.example .env          # Fill in your credentials (see below)

# Run database migrations against your Supabase project
# Execute SQL files from the migrations/ folder

# Start
npm run dev
```

| Endpoint | URL |
|:---|:---|
| 🚕 API | `http://localhost:3000/api` |
| 📖 Swagger Docs | `http://localhost:3000/api/docs` |
| ❤️ Health Check | `http://localhost:3000/health` |

### Frontend

```bash
cd frontend
flutter pub get

flutter run                # 📱 Mobile (device / emulator)
flutter run -d chrome      # 🌐 Web
flutter run -d windows     # 🖥️ Desktop
```

### Environment Variables

```env
# ── Server ──
NODE_ENV=development
PORT=3000

# ── Supabase ──
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# ── Auth ──
JWT_SECRET=your-secret-key

# ── Stripe ──
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_test_...

# ── Firebase ──
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email

# ── Email ──
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password

# ── CORS ──
CORS_ORIGINS=http://localhost:3000,http://localhost:5000
```

---

## 📡 API Reference

> 📖 **Interactive Swagger UI** available at `/api/docs` when the server is running.
>
> All protected endpoints require `Authorization: Bearer <token>`.

<details>
<summary><strong>🔐 Authentication</strong> — <code>/api/auth</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `POST` | `/register` | Register (passenger / driver) | — |
| `POST` | `/login` | Login → JWT token | — |
| `POST` | `/forgot-password` | Send reset email | — |
| `POST` | `/verify-reset-code` | Verify reset code | — |
| `POST` | `/reset-password` | Set new password | — |
| `GET` | `/me` | Current user profile | ✅ |
| `PUT` | `/profile` | Update profile | ✅ |
| `PUT` | `/fcm-token` | Update push token | ✅ |

</details>

<details>
<summary><strong>🛣️ Lines (Routes)</strong> — <code>/api/lines</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/` | List all lines | ✅ |
| `GET` | `/:id` | Line details | ✅ |
| `POST` | `/` | Create line | Admin |
| `PUT` | `/:id` | Update line | Admin |
| `DELETE` | `/:id` | Delete line | Admin |

</details>

<details>
<summary><strong>🚕 Trips</strong> — <code>/api/trips</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/` | List trips (filter by line, direction, date, status) | ✅ |
| `GET` | `/:id` | Trip details + reservations | ✅ |
| `POST` | `/` | Create manual trip | Admin |
| `PUT` | `/:id` | Update trip | Admin |
| `PUT` | `/:id/depart` | Mark as departed | Driver |
| `PUT` | `/:id/complete` | Mark as completed | Driver |
| `PUT` | `/:id/cancel` | Cancel trip | Admin |

</details>

<details>
<summary><strong>🎫 Reservations</strong> — <code>/api/reservations</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/` | User's reservations | ✅ |
| `GET` | `/:id` | Reservation details + QR | ✅ |
| `POST` | `/` | Book a trip (instant / future) | Passenger |
| `PUT` | `/:id/cancel` | Cancel booking (75% refund) | Passenger |
| `PUT` | `/:id/check-in` | QR check-in | Driver |
| `POST` | `/walk-in` | Walk-in terminal booking | — |

</details>

<details>
<summary><strong>💳 Wallets & Payments</strong> — <code>/api/wallets</code> · <code>/api/payments</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/wallets/balance` | Current balance | ✅ |
| `GET` | `/wallets/transactions` | Transaction history | ✅ |
| `POST` | `/wallets/topup` | Top up via Stripe | Passenger |
| `GET` | `/payments` | Payment records | ✅ |
| `GET` | `/payments/:id` | Payment details | ✅ |

</details>

<details>
<summary><strong>🚕 Drivers</strong> — <code>/api/drivers</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/queue` | Queue status & position | Driver |
| `POST` | `/queue/join` | Join queue (GPS validated) | Driver |
| `POST` | `/queue/leave` | Leave queue | Driver |
| `GET` | `/trips` | Driver's assigned trips | Driver |
| `GET` | `/earnings` | Earnings summary | Driver |
| `GET` | `/wallet` | Driver wallet | Driver |

</details>

<details>
<summary><strong>⚙️ Admin</strong> — <code>/api/admin</code></summary>
<br/>

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `GET` | `/dashboard` | Dashboard statistics | Admin |
| `GET` | `/users` | All users | Admin |
| `PUT` | `/users/:id` | Edit user | Admin |
| `PUT` | `/drivers/:id/approve` | Approve driver | Admin |
| `PUT` | `/drivers/:id/reject` | Reject driver | Admin |
| `GET` | `/analytics` | Reports & analytics | Admin |
| `GET` | `/predictions` | Demand predictions | Admin |
| `GET` | `/config` | System configuration | Admin |
| `PUT` | `/config` | Update configuration | Admin |

</details>

<details>
<summary><strong>📅 Schedules · ⭐ Ratings · 📍 Locations</strong></summary>
<br/>

**Schedules** `/api/schedules` (Admin)

| Method | Endpoint | Description |
|:---|:---|:---|
| `GET` | `/` | List schedule templates |
| `POST` | `/` | Create template |
| `PUT` | `/:id` | Update template |
| `DELETE` | `/:id` | Delete template |

**Ratings** `/api/ratings`

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `POST` | `/` | Rate a driver | Passenger |
| `GET` | `/driver/:id` | Driver's average rating | ✅ |

**Locations** `/api/locations`

| Method | Endpoint | Description | Auth |
|:---|:---|:---|:---:|
| `PUT` | `/update` | Update vehicle GPS | Driver |
| `GET` | `/vehicle/:id` | Current vehicle location | ✅ |

</details>

---

## 🚕 How It Works

### Booking Flow

```
  👤 Passenger                 🖥️ System                    🚕 Driver
      │                            │                            │
      │ ── Select line ──────────► │                            │
      │ ── Choose booking type ──► │                            │
      │                            │ ── Check driver queue ───► │
      │                            │ ◄── Assign (FIFO) ─────── │
      │ ◄── 💳 Deduct wallet ──── │ ── 💰 Pay driver ────────► │
      │ ◄── 📲 QR + notification ─ │ ── 🔔 Trip assigned ─────► │
      │                            │                            │
      │ ── 📱 Show QR at gate ────────────────────────────────► │
      │                            │ ◄── 📷 Scan QR ────────── │
      │ ◄── ✅ Checked in ──────── │                            │
```

- **Instant booking** → trip must be open with a driver → payment transfers immediately
- **Future booking** → reserves a seat even before the trip exists → auto-matched when trip opens
- **Cancellation** → 75% refund to wallet
- **No-show** → no refund

### Driver Queue

```
  📍 GPS validates driver at station
                 │
                 ▼
   ┌─────────────────────────────────────┐
   │         🚕 DRIVER QUEUE             │
   │                                     │
   │  ┌───┐   ┌───┐   ┌───┐   ┌───┐    │
   │  │ 1 │ → │ 2 │ → │ 3 │ → │ 4 │    │
   │  └───┘   └───┘   └───┘   └───┘    │
   │  next                              │
   │                                     │
   │  🔄 Going queue  ↔  Return queue   │
   └─────────────────────────────────────┘
   
   ✅ Fair FIFO rotation
   ✅ Transparent position display
   ✅ Auto-assign on new booking
   ✅ Respects driver autonomy
```

---

## ⏰ Background Jobs

| Job | Schedule | Description |
|:---|:---|:---|
| 🚕 **Trip Creation** | Daily 2:00 AM | Generate trips from schedule templates |
| 🚕 **Trip Opening** | Every minute | Open trips & assign drivers before departure |
| 🚕 **Departure Check** | Every minute | Auto-depart full trips past departure time |
| 🚕 **No-Show Check** | Post-departure | Mark absent passengers |
| 🚕 **Delayed Trip Check** | Every 5 min | Handle overdue trips |
| 🚕 **Prediction Update** | Hourly | Refresh demand statistics |

---

## 📂 Project Structure

```
🚕 palestine-taxi-service/
│
├── server.js                     # 🚀 Entry point
├── package.json                  # 📦 Dependencies
│
├── config/                       # ⚙️  App & DB configuration
├── controllers/                  # 🎮 Request handlers (15 files)
├── models/                       # 📦 Data models (19 files)
├── routes/                       # 🛣️  API routes (14 files)
├── services/                     # ⚡ Business logic (12 files)
├── jobs/                         # ⏰ Background cron jobs (6 files)
├── middleware/                    # 🛡️  Auth, validation, i18n, rate limit
├── utils/                        # 🔧 Helpers, email, QR, seat logic
├── migrations/                   # 🗄️  SQL migration scripts
├── docs/                         # 📖 Swagger / OpenAPI spec
├── uploads/                      # 📁 User-uploaded files
│
└── frontend/                     # 📱 Flutter application
    └── lib/
        ├── main.dart
        ├── config/
        ├── pages/
        │   ├── passenger/        # 👤 6 pages
        │   ├── driver/           # 🚕 8 pages
        │   └── admin/            # ⚙️  13 pages
        ├── screens/auth/         # 🔐 Login, register, password reset
        ├── services/             # 🌐 API, location, Stripe, Supabase
        ├── theme/                # 🎨 Light & dark themes
        ├── utils/                # 🔧 Utilities
        └── widgets/              # 🧩 Reusable components
```

---

## 🗄️ Database

**19 tables** on Supabase (PostgreSQL) — UUID keys, foreign key constraints, RLS policies, timestamp auditing.

```
┌──────────┐       ┌───────────┐       ┌──────────┐
│   user   │──1:1──│ passenger │       │  wallet  │
│          │──1:1──│  driver   │       │          │
│          │──1:1──│  admin    │       │          │
└──────────┘       └─────┬─────┘       └──────────┘
                         │
                ┌────────┴────────┐
                ▼                 ▼
          ┌──────────┐     ┌───────────┐
          │ vehicle  │     │driver_queue│
          └──────────┘     └───────────┘

┌──────┐     ┌──────┐     ┌─────────────┐     ┌─────────┐
│ line │──►  │ trip │──►  │ reservation │──►  │ payment │
└──┬───┘     └──────┘     └──────┬──────┘     └─────────┘
   │                             │
   ▼                             ▼
┌───────────┐              ┌──────────┐
│ line_path │              │  rating  │
└───────────┘              └──────────┘

+ base_station · vehicle_location · schedule_template
+ prediction_model · app_config · password_reset_token
```

---

## 🔒 Security

| Layer | Implementation |
|:---|:---|
| **Authentication** | JWT tokens with configurable expiry |
| **Passwords** | bcryptjs salted hashing |
| **Authorization** | Role-based middleware (passenger / driver / admin) |
| **Validation** | express-validator on all endpoints |
| **Rate Limiting** | express-rate-limit to prevent abuse |
| **CORS** | Configurable origin whitelist |
| **PCI Compliance** | Zero card data stored — Stripe handles everything |
| **Webhooks** | Stripe signature verification |
| **Database** | Supabase Row-Level Security policies |
| **Uploads** | Multer with file type & size restrictions |
| **Secrets** | `.env` file, never committed to VCS |

---

## 🌐 Internationalization

| Language | Direction | Status |
|:---|:---|:---|
| 🇸🇦 Arabic | RTL | ✅ Primary |
| 🇬🇧 English | LTR | ✅ Secondary |

- Backend: `Accept-Language` header detection via i18n middleware
- Frontend: `flutter_localizations` + Dart `intl` package
- Per-user language preference stored in profile

---

## 📋 Constraints

| | Constraint |
|:---:|:---|
| 🌐 | Requires internet connectivity for all features |
| 📊 | Demand predictions need 90+ days of historical data |
| 🗣️ | Arabic & English only (currently) |
| 💱 | Primary currency: Israeli Shekel (ILS) |
| ☁️ | Depends on Supabase, Firebase, Stripe uptime |
| 💳 | Stripe transaction fees ~2.9% per card payment |
| 🚕 | Cannot mandate driver attendance — vehicles are driver-owned |

---

## 🔮 Roadmap

- [ ] 📴 Offline mode for poor connectivity areas
- [ ] 📩 SMS notification fallback
- [ ] 📊 Advanced exportable analytics
- [ ] 🧾 Driver tax & earnings reports
- [ ] 🎁 Passenger loyalty program
- [ ] 💱 Multi-currency support
- [ ] 🗺️ External mapping / routing integration
- [ ] 🗣️ Additional languages

---

## 👥 Authors

<table>
<tr>
<td align="center"><strong>Osama Ishtaiwi</strong><br/>Developer</td>
<td align="center"><strong>Saif Shayeb</strong><br/>Developer</td>
</tr>
</table>

**Supervisor:** Dr. Samer Arandi

**Institution:** An-Najah National University — Faculty of Engineering & IT, Computer Engineering Department

---

<div align="center">

<br/>

🚕 🚕 🚕

**Built with ❤️ for Palestinian communities**

*Modernizing shared transportation &bull; Preserving community connections*

🚕 🚕 🚕

<br/>

*Software Graduation Project 1 — An-Najah National University — January 2026*

</div>
