# Technical Documentation -- HTN Remote BP Monitoring Platform

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Bluetooth Low Energy (BLE) Technical Reference](#bluetooth-low-energy-ble-technical-reference)
3. [Security Architecture](#security-architecture)
4. [Data Models](#data-models)
5. [API Specification](#api-specification)
6. [Mobile Application](#mobile-application)
7. [Backend Services](#backend-services)
8. [Admin Dashboard](#admin-dashboard)
9. [Deployment](#deployment)

---

## 1. System Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Patient Environment                          │
│                                                                     │
│  ┌──────────────┐     BLE/GATT      ┌────────────────────────────┐ │
│  │  Omron BP    │◄──────────────────►│   Flutter Mobile App       │ │
│  │  Cuff        │  IEEE-11073 SFLOAT │                            │ │
│  │  (BLE 4.0+)  │                    │  ┌─────────────────────┐   │ │
│  └──────────────┘                    │  │ BluetoothManager    │   │ │
│                                      │  │  ├─ PairingManager  │   │ │
│                                      │  │  ├─ MeasurementMgr  │   │ │
│                                      │  │  └─ BP Parser       │   │ │
│                                      │  ├─────────────────────┤   │ │
│                                      │  │ TokenManager        │   │ │
│                                      │  │ (Secure Storage)    │   │ │
│                                      │  ├─────────────────────┤   │ │
│                                      │  │ BiometricService    │   │ │
│                                      │  │ (Face ID / Touch)   │   │ │
│                                      │  ├─────────────────────┤   │ │
│                                      │  │ OfflineQueueService │   │ │
│                                      │  │ (SQLite local DB)   │   │ │
│                                      │  └─────────────────────┘   │ │
│                                      └───────────┬────────────────┘ │
└──────────────────────────────────────────────────┼──────────────────┘
                                                   │
                                              HTTPS/TLS
                                                   │
┌──────────────────────────────────────────────────┼──────────────────┐
│                     Server Environment           │                  │
│                                                  │                  │
│  ┌───────────────────────────────────────────────▼───────────────┐  │
│  │                    Flask REST API                             │  │
│  │                                                               │  │
│  │  ┌───────────┐  ┌────────────┐  ┌─────────────┐             │  │
│  │  │ Auth      │  │ Encryption │  │ Audit       │             │  │
│  │  │ (JWT/MFA) │  │ (AES-256)  │  │ Logger      │             │  │
│  │  └───────────┘  └────────────┘  └─────────────┘             │  │
│  │  ┌───────────┐  ┌────────────┐  ┌─────────────┐             │  │
│  │  │ Rate      │  │ Validators │  │ Email/Push  │             │  │
│  │  │ Limiter   │  │            │  │ Notifications│             │  │
│  │  └───────────┘  └────────────┘  └─────────────┘             │  │
│  │                                                               │  │
│  │  Consumer Routes (/consumer/*)                                │  │
│  │  Admin Routes    (/admin/*)                                   │  │
│  └───────────────────────────┬───────────────────────────────────┘  │
│                              │                                      │
│  ┌───────────────────────────▼───────────────────────────────────┐  │
│  │              PostgreSQL Database                              │  │
│  │  ┌─────────┐ ┌──────────┐ ┌─────────────┐ ┌──────────────┐  │  │
│  │  │ users   │ │ readings │ │ cuff_requests│ │ mfa_secrets  │  │  │
│  │  │ (PHI    │ │          │ │             │ │              │  │  │
│  │  │ encrypt)│ │          │ │             │ │              │  │  │
│  │  └─────────┘ └──────────┘ └─────────────┘ └──────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │           React Admin Dashboard                               │  │
│  │  Dashboard | User Mgmt | Readings | Charts | Call List        │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile Framework | Flutter (Dart) | 3.5.4+ |
| BLE Library | flutter_blue_plus | 1.34.5 |
| Backend Framework | Flask (Python) | 3.0.0 |
| ORM | Flask-SQLAlchemy | 3.1.1 |
| Migration | Flask-Migrate (Alembic) | 4.0.5 |
| Database | PostgreSQL / SQLite | 14+ / 3 |
| Admin Frontend | React + Vite | 18.2.0 / 5.0.0 |
| Charting | Recharts (web), fl_chart (mobile) | 2.10.0 / 0.66.0 |

---

## 2. Bluetooth Low Energy (BLE) Technical Reference

### Overview

The mobile application acts as a BLE Central device, connecting to BLE Peripheral blood pressure monitors that implement the Bluetooth SIG Blood Pressure Profile (BLP). Communication follows the GATT (Generic Attribute Profile) client-server model.

**Source files**:
- `FlutterAppSamantha/lib/bluetoothmanager.dart` -- BLE connection management
- `FlutterAppSamantha/lib/bloodPressureData.dart` -- IEEE-11073 data parsing

### BLE Protocol Stack

```
┌──────────────────────────────────────┐
│          Application Layer           │
│  (BluetoothManager / MeasurementMgr) │
├──────────────────────────────────────┤
│          GATT Profile                │
│   Blood Pressure Profile (BLP)       │
├──────────────────────────────────────┤
│          ATT Protocol                │
│   Read/Write/Notify/Indicate         │
├──────────────────────────────────────┤
│          L2CAP                       │
├──────────────────────────────────────┤
│          HCI                         │
├──────────────────────────────────────┤
│          BLE Link Layer              │
│          (2.4 GHz ISM Band)          │
└──────────────────────────────────────┘
```

### GATT Service Map

```
Blood Pressure Monitor (Peripheral)
│
├── Device Information Service (0x180A)
│   ├── Manufacturer Name (0x2A29) ── Read
│   └── Serial Number (0x2A25) ────── Read
│
└── Blood Pressure Service (0x1810)
    └── Blood Pressure Measurement (0x2A35) ── Indicate
        └── Client Characteristic Config Descriptor (CCCD)
            └── Enable Indications = [0x02, 0x00]
```

### Device Discovery

The `BluetoothManager` class implements device scanning:

```dart
// Scan configuration
Duration: 15 seconds
Service UUID filter: None (Omron devices don't advertise BP service UUID in advertisements)
Name-based filtering: ["BP7", "BLESMART", "OMRON", "EVOLV", "HEM-", "HEM7"]
```

**Why no UUID filter**: Many Omron devices do not include the Blood Pressure Service UUID (`0x1810`) in their BLE advertisement packets. Instead, the service is only discoverable after a GATT connection is established and service discovery is performed. The app therefore scans for all BLE devices and filters by known device name patterns.

### Pairing Process (PairingManager)

Platform-specific bonding is required before measurement data can be read:

**Android**:
1. Connect to device via GATT
2. Call `createBond()` to initiate OS-level BLE bonding
3. Wait for bond state confirmation
4. Discover services
5. Enable indications on BP Measurement characteristic to verify pairing

**iOS**:
1. Connect to device via GATT
2. Discover services
3. Access encrypted characteristic (triggers automatic iOS bonding dialog)
4. Enable indications on BP Measurement characteristic

Connection timeout: 15 seconds. The device is disconnected after successful pairing verification.

### Measurement Collection (MeasurementManager)

Reading retrieval follows a multi-step process with retry logic:

```
┌─────────────────┐
│  Pre-scan (5s)  │  Clear BLE GATT cache by scanning
└────────┬────────┘
         │
┌────────▼────────┐
│  Connect        │  Establish GATT connection
└────────┬────────┘
         │
┌────────▼────────┐
│  Discover       │  Enumerate services and characteristics
│  Services       │
└────────┬────────┘
         │
┌────────▼────────┐
│  Subscribe      │  Enable indications on 0x2A35
└────────┬────────┘
         │
┌────────▼────────┐
│  Command [0x02] │  Write measurement request to device
└────────┬────────┘
         │
┌────────▼────────┐
│  Receive Data   │  Collect notification stream
│  (Parse IEEE    │  Parse SFLOAT values
│   11073)        │  Validate timestamps
└────────┬────────┘
         │
┌────────▼────────┐
│  Disconnect     │  Clean GATT disconnection
└─────────────────┘

Retry: up to 15 attempts, 2-second interval between retries
```

### IEEE-11073 SFLOAT Parsing

Blood pressure values are encoded as IEEE-11073 16-bit Short Float (SFLOAT):

```
Bit layout (16 bits):
┌──────────────┬─────────────────────┐
│  Exponent    │     Mantissa        │
│  (4 bits)    │     (12 bits)       │
│  [15:12]     │     [11:0]          │
└──────────────┴─────────────────────┘

Value = mantissa * 10^exponent
```

**Sign extension**: The mantissa is a 12-bit signed integer. If bit 11 is set, the value is sign-extended to a full integer by OR-ing with `0xFFFFF000`.

**Implementation** (`BloodPressureParser.parseSfloat`):
```dart
int mantissa = raw & 0x0FFF;
int exponent = (raw >> 12) & 0x0F;
if (mantissa >= 0x0800) mantissa |= 0xFFFFF000; // sign extension
if (exponent >= 0x08) exponent = exponent - 16;  // signed exponent
return mantissa * pow(10, exponent);
```

### BP Measurement Packet Structure

```
Byte:  0       1-2       3-4       5-6       7-13              14-15
     ┌──────┬─────────┬─────────┬─────────┬───────────────────┬──────────┐
     │Flags │Systolic │Diastolic│  MAP    │ Timestamp (opt)   │Pulse(opt)│
     │      │ (SFLOAT)│ (SFLOAT)│ (SFLOAT)│ Y,M,D,H,M,S      │ (SFLOAT) │
     └──────┴─────────┴─────────┴─────────┴───────────────────┴──────────┘

Flags byte:
  Bit 0: Units (0=mmHg, 1=kPa)
  Bit 1: Timestamp present
  Bit 2: Pulse rate present
  Bit 3: User ID present
  Bit 4: Measurement status present
```

**Timestamp bytes** (when flag bit 1 is set):
| Offset | Field | Size | Format |
|--------|-------|------|--------|
| 7-8 | Year | 2 bytes | Little-endian uint16 |
| 9 | Month | 1 byte | 1-12 |
| 10 | Day | 1 byte | 1-31 |
| 11 | Hour | 1 byte | 0-23 |
| 12 | Minute | 1 byte | 0-59 |
| 13 | Second | 1 byte | 0-59 |

### Return Format

```dart
Map<DateTime, List<int>>
// Key: DateTime of reading
// Value: [systolic, diastolic, pulseRate]
```

Multiple stored readings are returned as separate notifications, each parsed independently.

### BLE Error Handling

| Scenario | Behavior |
|----------|----------|
| Device not found during scan | Return empty list after 15s timeout |
| Connection failure | Retry up to 15 times with 2s delay |
| Service discovery failure | Disconnect, retry full connection |
| Unexpected disconnect | Log event, notify user via callback |
| Invalid timestamp | Reject reading (outside 2020 to year+5) |
| SFLOAT parse error | Skip individual reading, continue parsing |

---

## 3. Security Architecture

### Threat Model

The platform addresses the following threat categories:

| Threat | Mitigation |
|--------|-----------|
| Unauthorized PHI access | AES-256-GCM encryption, JWT auth, MFA |
| Man-in-the-middle | TLS/HTTPS enforcement, HSTS headers |
| Credential theft | Passwordless login (OTP), biometric unlock, secure storage |
| Brute-force attacks | Rate limiting, MFA session lockout (5 attempts) |
| Session hijacking | Short-lived JWTs (1h), token revocation on logout |
| SQL injection | ORM-based queries (SQLAlchemy), input validation |
| XSS / Clickjacking | CSP headers, X-Frame-Options, X-XSS-Protection |
| PHI exposure in logs | Structured audit logs with field-level tracking, no PHI in logs |
| Insider threat | Audit trail, admin MFA, role-based access |

### Encryption Implementation

**Source**: `backend/app/utils/encryption.py`

#### AES-256-GCM for PHI

```python
# Key derivation
key = base64.b64decode(os.environ['PHI_ENCRYPTION_KEY'])  # 32 bytes

# Encryption
nonce = os.urandom(12)                      # 12-byte random nonce
cipher = Cipher(algorithms.AES(key), modes.GCM(nonce))
encryptor = cipher.encryptor()
ciphertext = encryptor.update(plaintext) + encryptor.finalize()
stored_value = base64.b64encode(nonce + ciphertext + encryptor.tag)

# Decryption
decoded = base64.b64decode(stored_value)
nonce = decoded[:12]
tag = decoded[-16:]
ciphertext = decoded[12:-16]
cipher = Cipher(algorithms.AES(key), modes.GCM(nonce, tag))
decryptor = cipher.decryptor()
plaintext = decryptor.update(ciphertext) + decryptor.finalize()
```

**Properties**:
- Each encryption operation generates a unique 12-byte random nonce
- GCM mode provides both confidentiality and authenticity (AEAD)
- The nonce is prepended to the ciphertext for storage
- The 16-byte GCM authentication tag is appended

#### HMAC-SHA256 for Email Lookup

Emails are hashed deterministically to allow database lookups without storing plaintext:

```python
email_hash = hmac.new(key, email.lower().encode(), hashlib.sha256).hexdigest()
```

This enables `WHERE email_hash = ?` queries while keeping the actual email encrypted.

### Authentication System

**Source**: `backend/app/utils/auth.py`

#### JWT Token Structure

```json
{
  "user_id": 123,
  "email": "user@example.com",
  "jti": "unique-token-id-uuid",
  "iat": 1705312200,
  "exp": 1705315800
}
```

- **Algorithm**: HS256 (HMAC-SHA256)
- **Default expiry**: 3600 seconds (1 hour)
- **JTI**: UUID v4, stored in `revoked_tokens` table on logout

#### Token Validation Flow (`@token_required`)

```
1. Extract token from Authorization: Bearer <token>
2. Decode and verify JWT signature (HS256)
3. Check token expiration
4. Check JTI against revoked_tokens table
5. Load user from database by user_id
6. Verify user is_active = True
7. Verify user is_email_verified = True
8. Attach user to request context
```

### MFA Implementation

**Sources**:
- `backend/app/models/mfa_secret.py` -- TOTP secret and backup codes
- `backend/app/models/mfa_session.py` -- Login session state

#### Consumer MFA (Email OTP)

```
POST /consumer/login { email }
    │
    ├── Generate 6-digit OTP
    ├── Create MfaSession (10-min expiry)
    ├── Send OTP via email
    └── Return session_token
         │
POST /consumer/verify-mfa { session_token, otp_code }
    │
    ├── Validate session not expired
    ├── Check attempt count < 5
    ├── Verify OTP matches
    ├── Mark session as verified
    └── Issue JWT access token
```

#### Admin MFA (TOTP)

```
Initial Setup:
    ├── Generate TOTP secret (pyotp)
    ├── Generate 10 backup codes (8-char alphanumeric)
    ├── Store encrypted secret in mfa_secrets table
    └── Return QR code provisioning URI

Login:
    POST /admin/login { email, password }
        │
        ├── Verify bcrypt password hash
        ├── Create MfaSession
        └── Return session_token
             │
    POST /admin/verify-mfa { session_token, totp_code }
        │
        ├── Verify TOTP code against secret
        ├── (or) Verify against backup codes (single-use)
        └── Issue JWT access token
```

### Rate Limiting

**Source**: `backend/app/utils/rate_limiter.py`

| Endpoint | Key | Limit |
|----------|-----|-------|
| Login | Email address | Configurable per window |
| MFA verify | Session ID | 5 attempts per session |
| Registration | Client IP | Configurable per window |

### Input Validation

**Source**: `backend/app/utils/validators.py`

| Field | Validation Rule |
|-------|----------------|
| Systolic BP | 60--300 mmHg |
| Diastolic BP | 30--200 mmHg |
| Heart Rate | 30--250 BPM |
| Height | 24--108 inches |
| Weight | 50--700 lbs |
| Email | RFC-compliant regex |
| Date of Birth | Valid date, not in the future |
| Text fields | Maximum length enforcement |

### HIPAA Audit Logging

**Source**: `backend/app/utils/audit_logger.py`

Every access to PHI generates a structured log entry:

```json
{
  "timestamp": "2025-01-15T10:30:00.000Z",
  "event": "phi_access",
  "action": "READ",
  "resource_type": "user_profile",
  "resource_id": "123",
  "user_id": "45",
  "ip_address": "192.168.1.100",
  "user_agent": "FlutterApp/1.0",
  "details": {
    "fields_accessed": ["name", "dob", "medications"],
    "endpoint": "/consumer/profile"
  }
}
```

**Tracked Actions**:

| Action | Trigger |
|--------|---------|
| `CREATE` | New user registration, new reading |
| `READ` | Profile view, reading history |
| `UPDATE` | Profile edit, status change |
| `DELETE` | Account deactivation |
| `LOGIN` | Successful authentication |
| `LOGIN_FAILED` | Invalid credentials |
| `MFA_VERIFY_FAILED` | Invalid OTP/TOTP |
| `LOGOUT` | Token revocation |
| `EXPORT` | CSV/PDF data export |

The `@audit_phi_access` decorator can be applied to any Flask route to automatically log PHI access with request context.

### Mobile Security

| Feature | Implementation | Source |
|---------|---------------|--------|
| Token storage | iOS Keychain / Android KeyStore | `flutter_secure_storage` |
| Biometric unlock | Face ID, Touch ID, Fingerprint | `local_auth` via `BiometricService` |
| Certificate pinning | HTTPS enforced in production | `env.dart` config |
| Local data | SQLite with app sandbox | `sqflite` |
| Offline queue | Encrypted local queue, sync on connect | `OfflineQueueService` |

---

## 4. Data Models

### Entity Relationship Diagram

```
┌──────────────┐       ┌────────────────────┐       ┌───────────────┐
│    unions     │       │       users        │       │   readings    │
├──────────────┤       ├────────────────────┤       ├───────────────┤
│ id (PK)      │◄──────│ union_id (FK)      │──────►│ id (PK)       │
│ name         │  1:N  │ id (PK)            │  1:N  │ user_id (FK)  │
└──────────────┘       │ _name (encrypted)  │       │ systolic      │
                       │ _email (encrypted) │       │ diastolic     │
                       │ email_hash (HMAC)  │       │ heart_rate    │
                       │ _dob (encrypted)   │       │ reading_date  │
                       │ _phone (encrypted) │       │ device_id     │
                       │ _address (encrypted│       │ created_at    │
                       │ _medications (enc) │       └───────────────┘
                       │ gender             │
                       │ race, ethnicity    │       ┌───────────────┐
                       │ height_inches      │       │ cuff_requests │
                       │ weight_lbs         │       ├───────────────┤
                       │ user_status        │──────►│ id (PK)       │
                       │ is_active          │  1:N  │ user_id (FK)  │
                       │ is_admin           │       │ _shipping_addr│
                       │ is_email_verified  │       │ status        │
                       │ is_mfa_enabled     │       │ tracking_num  │
                       │ is_flagged         │       │ carrier       │
                       │ created_at         │       │ approved_by   │
                       │ updated_at         │       │ shipped_by    │
                       └────────┬───────────┘       └───────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
     ┌────────▼─────┐  ┌──────▼──────┐  ┌──────▼──────────┐
     │ mfa_secrets  │  │ mfa_sessions│  │ device_tokens   │
     ├──────────────┤  ├─────────────┤  ├─────────────────┤
     │ id (PK)      │  │ id (PK)     │  │ id (PK)         │
     │ user_id (FK) │  │ user_id (FK)│  │ user_id (FK)    │
     │ secret (enc) │  │ otp_code    │  │ token           │
     │ backup_codes │  │ expires_at  │  │ platform        │
     │ is_verified  │  │ attempts    │  │ created_at      │
     └──────────────┘  │ is_verified │  └─────────────────┘
                       └─────────────┘
```

### User Model Fields

**Source**: `backend/app/models/user.py`

#### PHI Fields (AES-256-GCM Encrypted)

| DB Column | Property | Type | Description |
|-----------|----------|------|-------------|
| `_name` | `name` | str | Full name |
| `_email` | `email` | str | Email address |
| `email_hash` | -- | str | HMAC-SHA256 for lookup |
| `_dob` | `dob` | str | Date of birth |
| `_phone` | `phone` | str | Phone number |
| `_address` | `address` | str | Mailing address |
| `_medications` | `medications` | str | Current medications |

PHI fields use Python `@property` decorators for transparent encrypt-on-set and decrypt-on-get.

#### Demographics and Health

| Field | Type | Constraints |
|-------|------|------------|
| `gender` | String(20) | -- |
| `race` | String(50) | -- |
| `ethnicity` | String(50) | -- |
| `work_status` | String(50) | -- |
| `rank` | String(50) | -- |
| `height_inches` | Float | 24--108 |
| `weight_lbs` | Float | 50--700 |
| `has_high_bp` | Boolean | -- |
| `on_bp_medication` | Boolean | -- |
| `missed_doses` | Integer | -- |
| `chronic_conditions` | JSON | Array of strings |
| `smoking_status` | String(20) | -- |

#### Lifestyle Fields

| Field | Type | Range |
|-------|------|-------|
| `exercise_days_per_week` | Integer | 0--7 |
| `exercise_minutes_per_session` | Integer | 0+ |
| `food_frequency` | JSON | Category -> frequency map |
| `financial_stress` | Integer | 1--10 |
| `stress_level` | Integer | 1--10 |
| `loneliness` | Integer | 1--10 |
| `sleep_quality` | Integer | 1--10 |
| `phq2_interest` | Integer | PHQ-2 screening |
| `phq2_depressed` | Integer | PHQ-2 screening |

#### Status Fields

| Field | Type | Values |
|-------|------|--------|
| `user_status` | String | See pipeline below |
| `is_active` | Boolean | Account enabled |
| `is_admin` | Boolean | Admin role |
| `is_email_verified` | Boolean | Email confirmed |
| `is_mfa_enabled` | Boolean | MFA configured |
| `is_flagged` | Boolean | Admin review needed |

### Blood Pressure Reading Model

**Source**: `backend/app/models/reading.py`

| Field | Type | Description |
|-------|------|-------------|
| `id` | Integer (PK) | Auto-increment |
| `user_id` | Integer (FK) | Reference to users table |
| `systolic` | Integer | Systolic pressure (mmHg) |
| `diastolic` | Integer | Diastolic pressure (mmHg) |
| `heart_rate` | Integer (nullable) | Pulse rate (BPM) |
| `reading_date` | DateTime | When reading was taken |
| `device_id` | String | BLE device identifier |
| `created_at` | DateTime | Server-side timestamp |

### Cuff Request Model

**Source**: `backend/app/models/cuff_request.py`

| Field | Type | Description |
|-------|------|-------------|
| `id` | Integer (PK) | Auto-increment |
| `user_id` | Integer (FK) | Reference to users table |
| `_shipping_address` | Text (encrypted) | Encrypted shipping address |
| `status` | String | pending, approved, shipped, delivered, cancelled |
| `tracking_number` | String | Shipping tracking number |
| `carrier` | String | Shipping carrier |
| `approved_by` | Integer | Admin user ID |
| `approved_at` | DateTime | Approval timestamp |
| `shipped_by` | Integer | Admin user ID |
| `shipped_at` | DateTime | Ship timestamp |
| `admin_notes` | Text | Internal notes |

---

## 5. API Specification

### Authentication

All authenticated endpoints require:
```
Authorization: Bearer <jwt_token>
```

Admin endpoints additionally verify `is_admin = True` on the user record.

### Consumer API (`/consumer/`)

#### POST `/register`

Register a new user. PHI fields are encrypted before storage.

**Request**:
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "dob": "1985-03-15",
  "phone": "555-0100",
  "union_id": 1,
  "gender": "male",
  "race": "white",
  "ethnicity": "non-hispanic",
  "height_inches": 70,
  "weight_lbs": 180,
  "has_high_bp": true,
  "on_bp_medication": false,
  "chronic_conditions": ["diabetes"],
  "smoking_status": "never",
  "exercise_days_per_week": 3,
  "exercise_minutes_per_session": 30,
  "stress_level": 4,
  "sleep_quality": 7
}
```

**Response** (201):
```json
{
  "message": "Registration successful",
  "token": "<registration_jwt>"
}
```

#### POST `/login`

Initiate passwordless login. Sends OTP to email.

**Request**:
```json
{ "email": "user@example.com" }
```

**Response** (200):
```json
{
  "message": "Verification code sent",
  "session_token": "<mfa_session_token>"
}
```

#### POST `/verify-mfa`

Verify OTP and receive access token.

**Request**:
```json
{
  "session_token": "<mfa_session_token>",
  "code": "123456"
}
```

**Response** (200):
```json
{
  "token": "<jwt_access_token>",
  "user": { "id": 123, "name": "John Doe", "user_status": "active" }
}
```

#### POST `/reading`

Submit a blood pressure reading.

**Request**:
```json
{
  "systolic": 120,
  "diastolic": 80,
  "heart_rate": 72,
  "reading_date": "2025-01-15T10:30:00Z",
  "device_id": "AA:BB:CC:DD:EE:FF"
}
```

**Response** (201):
```json
{
  "message": "Reading saved",
  "reading_id": 456
}
```

#### GET `/readings`

Retrieve reading history for the authenticated user.

**Response** (200):
```json
{
  "readings": [
    {
      "id": 456,
      "systolic": 120,
      "diastolic": 80,
      "heart_rate": 72,
      "reading_date": "2025-01-15T10:30:00Z",
      "device_id": "AA:BB:CC:DD:EE:FF"
    }
  ]
}
```

### Admin API (`/admin/`)

#### GET `/stats`

Dashboard statistics.

**Response** (200):
```json
{
  "total_users": 250,
  "active_users": 180,
  "total_readings": 5400,
  "pending_approvals": 12,
  "pending_cuffs": 8
}
```

#### GET `/users?status=active&page=1&per_page=20`

Paginated, filterable user list.

#### POST `/export/patient-pdf/<user_id>`

Generate a PDF report for a patient including demographics, reading history, and trend charts.

---

## 6. Mobile Application

### Screen Flow

```
Splash Screen
     │
     ├── (No token) ──► Login Screen
     │                       │
     │                  Enter Email
     │                       │
     │                  OTP Verification
     │                       │
     │                  (Optional) Biometric Setup
     │                       │
     ├── (Has token) ──► Home Screen
     │                       │
     │                  ┌────┴────────────────┐
     │                  │                     │
     │             Dashboard            Profile Screen
     │             (BP History,              │
     │              Charts)            Edit Profile
     │                  │
     │             ┌────┴─────┐
     │             │          │
     │        Take Reading   Pair Device
     │             │          │
     │        BLE Connect    BLE Scan
     │             │          │
     │        Parse Data    Select Device
     │             │          │
     │        Upload to     Bond/Pair
     │        Server
     │
     ├── (New user) ──► Registration Wizard
                           │
                      Step 1: Personal Info
                           │
                      Step 2: Contact Info
                           │
                      Step 3: Work Info
                           │
                      Step 4: Health History
                           │
                      Step 5: Lifestyle
                           │
                      Request Cuff ──► Pending Screen
```

### Key Services

| Service | File | Purpose |
|---------|------|---------|
| `BluetoothManager` | `bluetoothmanager.dart` | BLE scanning, device filtering |
| `PairingManager` | `bluetoothmanager.dart` | Platform-specific BLE bonding |
| `MeasurementManager` | `bluetoothmanager.dart` | Reading collection with retry |
| `BloodPressureParser` | `bloodPressureData.dart` | IEEE-11073 SFLOAT parsing |
| `TokenManager` | `tokenManager.dart` | JWT storage and retrieval |
| `BiometricService` | `services/biometric_service.dart` | Face ID / fingerprint auth |
| `SyncService` | `services/sync_service.dart` | Offline data synchronization |
| `OfflineQueueService` | `services/offline_queue_service.dart` | Local queue for offline reads |
| `NotificationService` | `services/notification_service.dart` | Firebase push notifications |
| `LocalNotificationService` | `services/local_notification_service.dart` | Scheduled local reminders |

### State Management

The app uses the **Provider** pattern for state management:
- `SourceManager` -- Singleton managing data source access
- `NavigationManager` -- App-wide navigation state

### Offline Capabilities

When the device has no network connectivity:
1. BP readings are saved to a local SQLite database via `OfflineQueueService`
2. `SyncService` monitors connectivity status via `connectivity_plus`
3. When connectivity is restored, queued readings are uploaded to the server
4. Successfully synced readings are removed from the local queue

---

## 7. Backend Services

### Application Factory

**Source**: `backend/app/__init__.py`

The Flask application is created via the factory pattern:

1. Load configuration from environment variables
2. Initialize SQLAlchemy and Alembic migrations
3. Register security headers on all responses
4. Register consumer and admin route blueprints
5. Configure CORS with whitelisted origins

### Utility Modules

| Module | Source | Responsibility |
|--------|--------|---------------|
| `auth.py` | `app/utils/auth.py` | JWT generation, validation, `@token_required` |
| `encryption.py` | `app/utils/encryption.py` | AES-256-GCM encrypt/decrypt, HMAC hashing |
| `audit_logger.py` | `app/utils/audit_logger.py` | Structured HIPAA audit logging |
| `validators.py` | `app/utils/validators.py` | Input validation for all user data |
| `rate_limiter.py` | `app/utils/rate_limiter.py` | Per-endpoint rate limiting |
| `email_sender.py` | `app/utils/email_sender.py` | SendGrid / SMTP / console email delivery |
| `push_notifications.py` | `app/utils/push_notifications.py` | Firebase Cloud Messaging |
| `export.py` | `app/utils/export.py` | CSV and PDF report generation |

### Database Migrations

Migrations are managed by Flask-Migrate (Alembic wrapper):

```bash
# Create a new migration after model changes
flask db migrate -m "description"

# Apply pending migrations
flask db upgrade

# Rollback last migration
flask db downgrade
```

Migration files are stored in `backend/migrations/versions/`.

---

## 8. Admin Dashboard

### Pages

| Page | Route | Description |
|------|-------|-------------|
| Login | `/login` | Admin credential entry |
| MFA Setup | `/mfa-setup` | TOTP authenticator configuration |
| MFA Verify | `/mfa-verify` | TOTP/backup code entry |
| Dashboard | `/` | Overview statistics and charts |
| Users | `/users` | Tabbed user management by status |
| Patient Detail | `/users/:id` | Individual patient profile and readings |
| Readings | `/readings` | Filterable reading list with export |
| Charts | `/charts` | Population-level BP analytics |
| Call List | `/call-list` | Outreach tracking for inactive users |
| Call Reports | `/call-reports` | Call center metrics |

### Authentication Flow

1. Admin enters email and password
2. Backend verifies credentials, returns MFA session token
3. Admin enters TOTP code from authenticator app (or backup code)
4. Backend verifies TOTP, returns JWT
5. JWT stored in React `AuthContext` and included in all API requests

### Data Visualization

The dashboard uses **Recharts** for:
- Blood pressure trend charts (systolic/diastolic over time)
- Population distribution histograms
- User enrollment pipeline funnel
- Reading frequency heatmaps

---

## 9. Deployment

### Production Requirements

| Requirement | Details |
|-------------|---------|
| Database | PostgreSQL 14+ with SSL connections |
| HTTPS | TLS certificate required (HSTS enforced) |
| Python | 3.10+ |
| WSGI Server | Gunicorn recommended |
| PHI Key | Generate with `base64.b64encode(secrets.token_bytes(32))` |
| JWT Secret | Generate with `secrets.token_hex(32)` |

### Production Startup

```bash
# Backend
gunicorn -w 4 -b 0.0.0.0:3001 --certfile cert.pem --keyfile key.pem wsgi:app

# Admin Dashboard
npm run build  # Output in dist/
# Serve dist/ via nginx or similar
```

### Mobile App Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### Environment Checklist

- [ ] `FLASK_ENV=production`
- [ ] `DATABASE_URL` points to PostgreSQL with SSL
- [ ] `PHI_ENCRYPTION_KEY` generated and securely stored
- [ ] `JWT_SECRET_KEY` generated and securely stored
- [ ] `SECRET_KEY` generated for Flask sessions
- [ ] `SSL_CERT_PATH` and `SSL_KEY_PATH` configured
- [ ] `ALLOWED_ORIGINS` restricted to production domains
- [ ] `EMAIL_BACKEND` set to `sendgrid` or `smtp`
- [ ] `SENDGRID_API_KEY` configured (if using SendGrid)
- [ ] `FIREBASE_CREDENTIALS_PATH` configured for push notifications
- [ ] `AUDIT_LOG_FILE` writable path configured
- [ ] Database migrations applied (`flask db upgrade`)
- [ ] Firewall rules restrict database access to application server only
