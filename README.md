# HTN-APP -- Remote Blood Pressure Monitoring Platform

A HIPAA-compliant remote blood pressure monitoring platform that connects patients with Bluetooth-enabled BP cuffs, captures readings via BLE, and provides administrators with real-time dashboards for population health management.

Built for union and employer hypertension prevention programs, the platform handles the full lifecycle from patient enrollment through ongoing monitoring.

## Architecture Overview

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Mobile App** | Flutter / Dart | BLE device pairing, BP reading capture, patient self-service |
| **Backend API** | Flask / Python | REST API, PHI encryption, HIPAA audit logging |
| **Admin Dashboard** | React / Vite | User management, analytics, cuff fulfillment |
| **Database** | PostgreSQL (prod) / SQLite (dev) | Encrypted-at-rest patient data storage |

```
+------------------+       BLE        +-------------------+
|   Omron / Transtek |<-------------->|   Flutter Mobile   |
|   BP Cuff (BLE)   |   IEEE-11073   |   Application      |
+------------------+                  +--------+----------+
                                               |
                                          HTTPS/TLS
                                               |
                                      +--------v----------+
                                      |   Flask REST API   |
                                      |  (AES-256-GCM PHI) |
                                      +--------+----------+
                                               |
                                      +--------v----------+
                                      |   PostgreSQL DB    |
                                      |  (Encrypted PHI)   |
                                      +--------+----------+
                                               |
                                      +--------v----------+
                                      |  React Admin       |
                                      |  Dashboard         |
                                      +-------------------+
```

---

## Bluetooth Low Energy (BLE) Capabilities

The mobile app communicates with FDA-cleared Bluetooth blood pressure monitors using the Bluetooth Low Energy (BLE) protocol, implementing the standard Blood Pressure Profile as defined by the Bluetooth SIG.

### Supported Devices

| Manufacturer | Models | Protocol |
|-------------|--------|----------|
| **Omron** | BP7000, BP7150 (3-Series), BP7250 (5-Series) | BLE Blood Pressure Profile |
| **Transtek** | BP7150 | BLE Blood Pressure Profile |

Device identification patterns: `BP7`, `BLESMART`, `OMRON`, `EVOLV`, `HEM-`, `HEM7`

### BLE Service & Characteristic UUIDs

| Service/Characteristic | UUID | Purpose |
|----------------------|------|---------|
| Device Information Service | `0000180A-0000-1000-8000-00805f9b34fb` | Device identification |
| Blood Pressure Service | `00001810-0000-1000-8000-00805f9b34fb` | BP measurement data |
| BP Measurement Characteristic | `00002A35-0000-1000-8000-00805f9b34fb` | Individual readings |
| Manufacturer Name | `00002A29-0000-1000-8000-00805f9b34fb` | Manufacturer identification |
| Serial Number | `00002A25-0000-1000-8000-00805f9b34fb` | Device serial tracking |

### Connection Workflow

```
1. SCAN (15s)          Scan without UUID filter (Omron doesn't advertise BP service)
       |               Filter results by known device name patterns
       v
2. CONNECT             Establish BLE connection (15s timeout)
       |
       v
3. PAIR                Android: explicit createBond()
       |               iOS: automatic bonding on characteristic access
       v
4. DISCOVER            Enumerate services and characteristics
       |
       v
5. SUBSCRIBE           Enable indications on BP Measurement characteristic
       |
       v
6. REQUEST             Send measurement command [0x02] to device
       |
       v
7. RECEIVE             Parse IEEE-11073 SFLOAT notification data
       |
       v
8. DISCONNECT          Clean disconnect after data transfer
```

### Data Parsing (IEEE-11073)

Blood pressure readings are transmitted as IEEE-11073 16-bit SFLOAT values:

| Byte Offset | Field | Format |
|-------------|-------|--------|
| 0 | Flags | Bitmask |
| 1-2 | Systolic (mmHg) | SFLOAT |
| 3-4 | Diastolic (mmHg) | SFLOAT |
| 5-6 | Mean Arterial Pressure | SFLOAT |
| 7-13 | Timestamp (if flag bit 1) | Year(2), Month, Day, Hour, Min, Sec |
| 14+ | Pulse Rate (if flag bit 2) | SFLOAT |

### Reliability Features

- **Retry logic**: Up to 15 connection attempts with 2-second intervals (~30s total)
- **BLE cache refresh**: 5-second pre-connect scan clears stale GATT cache
- **Connection monitoring**: Real-time connection state listener detects unexpected disconnects
- **Timestamp validation**: Rejects readings with dates outside 2020 to current year + 5
- **Offline queue**: Readings captured offline are queued locally and synced when connectivity returns

### Required Permissions

**Android** (`AndroidManifest.xml`):
- `BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`
- `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`

**iOS** (`Info.plist`):
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

---

## Security & HIPAA Compliance

This platform handles Protected Health Information (PHI) and implements layered security controls aligned with HIPAA Technical Safeguards (45 CFR 164.312).

### Encryption

| Layer | Method | Details |
|-------|--------|---------|
| **PHI at Rest** | AES-256-GCM | 256-bit key, 12-byte random nonce per encryption |
| **Transport** | TLS/HTTPS | Enforced in production via HSTS headers |
| **Mobile Storage** | Platform Keychain/KeyStore | JWT tokens stored via `flutter_secure_storage` |
| **Password Hashing** | bcrypt | Used for admin credential storage |
| **Email Lookup** | HMAC-SHA256 | Deterministic hash enables queries without exposing plaintext |

**Encrypted PHI Fields**: Name, Email, Date of Birth, Phone, Address, Medications

### Authentication Flow

```
                    Consumer Login                       Admin Login
                    ─────────────                       ───────────
                    Email input                         Email + Password
                         |                                    |
                    Email OTP (6-digit)                  TOTP / Email OTP
                    10-min expiry                        10-min session expiry
                         |                               Max 5 attempts
                    Verify OTP                                |
                         |                              Verify MFA
                    JWT issued (HS256)                        |
                    1-hour expiry                        JWT issued (HS256)
                         |                                    |
                    Optional biometric                   Dashboard access
                    unlock (Face ID /
                    Fingerprint)
```

### Multi-Factor Authentication (MFA)

- **Consumer users**: Email-based OTP required for every login
- **Admin users**: TOTP (authenticator app) required before dashboard access
- **Backup codes**: 10 single-use 8-character alphanumeric recovery codes
- **Session limits**: MFA sessions expire after 10 minutes; 5 failed attempts triggers lockout (HTTP 429)

### API Security

- **JWT tokens** signed with HS256, containing `user_id`, `email`, `jti`, `exp`, `iat`
- **Token revocation** tracked in database on logout
- **`@token_required` decorator** validates token signature, expiry, revocation status, and account status
- **Rate limiting** on login, MFA verification, and registration endpoints
- **Input validation** on all user-submitted data (BP ranges, date formats, field lengths)

### Security Headers

All API responses include:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'
Cache-Control: no-store, no-cache, must-revalidate
Strict-Transport-Security: max-age=31536000 (production)
Referrer-Policy: no-referrer
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

### HIPAA Audit Logging

All access to PHI is recorded in structured JSON logs:

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "action": "READ",
  "resource_type": "user_profile",
  "resource_id": "123",
  "user_id": "45",
  "ip_address": "192.168.1.1",
  "user_agent": "Flutter/3.5",
  "details": { "fields_accessed": ["name", "dob", "medications"] }
}
```

Logged actions: `CREATE`, `READ`, `UPDATE`, `DELETE`, `LOGIN`, `LOGIN_FAILED`, `MFA_VERIFY_FAILED`, `LOGOUT`, `EXPORT`

The `@audit_phi_access` decorator automatically logs access on sensitive endpoints.

---

## User Status Pipeline

Users progress through a defined enrollment pipeline:

```
pending_approval --> pending_registration --> pending_cuff --> pending_first_reading --> active
                                                                                          |
                                                                                     deactivated
                                                                                  (8+ months inactive)
```

| Status | Description |
|--------|-------------|
| `pending_approval` | Registered in app, awaiting union/admin approval |
| `pending_registration` | Approved, completing profile and health intake |
| `pending_cuff` | Cuff shipment requested, awaiting delivery |
| `pending_first_reading` | Cuff delivered, no BP readings submitted yet |
| `active` | Submitted at least one BP reading |
| `deactivated` | Inactive 8+ months or manually disabled by admin |
| `enrollment_only` | Registered via external form only, never used app |

---

## Getting Started

### Prerequisites

- Flutter SDK 3.5.4+
- Python 3.10+
- Node.js 18+
- PostgreSQL 14+ (production) or SQLite (development)

### Mobile App

```bash
cd FlutterAppSamantha
flutter pub get
flutter run
```

Configure the API endpoint in `lib/env.dart`.

### Backend API

```bash
cd backend
pip install -r requirements.txt
cp .env.example .env
# Edit .env with required values (see Environment Variables below)
flask db upgrade
python run.py
```

### Admin Dashboard

```bash
cd admin-dashboard
npm install
npm run dev
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FLASK_ENV` | Yes | `development` or `production` |
| `SECRET_KEY` | Yes | Flask session secret (`secrets.token_hex(32)`) |
| `DATABASE_URL` | Yes | PostgreSQL URI (prod) or SQLite path (dev) |
| `PHI_ENCRYPTION_KEY` | Yes | 32-byte AES key, base64-encoded |
| `JWT_SECRET_KEY` | Yes | JWT signing secret |
| `JWT_ACCESS_TOKEN_EXPIRES` | No | Token lifetime in seconds (default: 3600) |
| `AUDIT_LOG_FILE` | No | Path to audit log (default: `logs/audit.log`) |
| `SSL_CERT_PATH` | Prod | TLS certificate path |
| `SSL_KEY_PATH` | Prod | TLS private key path |
| `ALLOWED_ORIGINS` | Yes | CORS whitelist, comma-separated |
| `EMAIL_BACKEND` | Yes | `console`, `smtp`, or `sendgrid` |
| `SENDGRID_API_KEY` | Cond. | Required if `EMAIL_BACKEND=sendgrid` |
| `FIREBASE_CREDENTIALS_PATH` | No | Firebase service account JSON for push notifications |

---

## API Reference

### Consumer Endpoints (`/consumer/`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/unions` | No | List active unions |
| POST | `/register` | No | Register new user with encrypted PHI |
| POST | `/login` | No | Initiate passwordless login (sends OTP) |
| POST | `/verify-mfa` | No | Verify OTP, receive JWT |
| POST | `/logout` | JWT | Revoke token |
| GET | `/profile` | JWT | Get user profile |
| PUT | `/profile` | JWT | Update user profile |
| POST | `/reading` | JWT | Submit BP reading |
| GET | `/readings` | JWT | Get reading history |
| POST | `/cuff-request` | JWT | Request cuff shipment |
| GET | `/cuff-request` | JWT | Check cuff request status |

### Admin Endpoints (`/admin/`)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/stats` | JWT+Admin | Dashboard statistics |
| GET | `/users` | JWT+Admin | List users with filters/pagination |
| GET | `/users/<id>` | JWT+Admin | User detail view |
| PUT | `/users/<id>` | JWT+Admin | Update user record |
| PUT | `/users/<id>/status` | JWT+Admin | Change pipeline status |
| GET | `/users/tab-counts` | JWT+Admin | Badge counts per status |
| GET | `/users/tab/<status>` | JWT+Admin | Users by status tab |
| GET | `/readings` | JWT+Admin | Filter/export readings |
| POST | `/export/users-csv` | JWT+Admin | Export users CSV |
| POST | `/export/readings-csv` | JWT+Admin | Export readings CSV |
| POST | `/export/patient-pdf/<id>` | JWT+Admin | Generate patient PDF |
| GET | `/cuff-requests` | JWT+Admin | Manage cuff requests |

---

## Project Structure

```
HTN-APP-/
├── FlutterAppSamantha/          # Mobile application (Flutter/Dart)
│   ├── lib/
│   │   ├── bluetoothmanager.dart # BLE scanning, pairing, measurement
│   │   ├── bloodPressureData.dart # IEEE-11073 data parser
│   │   ├── devices/              # Device pairing & selection screens
│   │   ├── registration/         # Multi-step registration wizard
│   │   ├── services/             # Sync, biometric, notification services
│   │   └── env.dart              # API endpoint configuration
│   ├── android/                  # Android platform config & permissions
│   └── ios/                      # iOS platform config & permissions
│
├── backend/                      # REST API (Flask/Python)
│   ├── app/
│   │   ├── models/               # SQLAlchemy models (encrypted PHI)
│   │   ├── routes/               # Consumer & admin API endpoints
│   │   └── utils/                # Auth, encryption, audit, validation
│   ├── migrations/               # Alembic database migrations
│   └── requirements.txt
│
├── admin-dashboard/              # Web dashboard (React/Vite)
│   ├── src/
│   │   ├── pages/                # Dashboard, Users, Readings, Charts
│   │   ├── components/           # Shared UI components
│   │   └── context/              # Auth state management
│   └── package.json
│
└── mockups/                      # UI design mockups
```

---

## License

Proprietary. All rights reserved.
