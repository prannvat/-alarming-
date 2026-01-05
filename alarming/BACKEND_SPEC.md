# Alarming Backend Specification

## Overview

This document outlines the backend requirements for the **Alarming** alarm clock app. The backend serves three primary purposes:

1. **User Authentication & Account Management** - Secure user accounts with email verification for prize distribution
2. **Daily Challenge System** - Synchronized daily challenges across all users
3. **Leaderboard & Rewards Tracking** - Global leaderboard with monthly prize distribution

---

## 1. Authentication System

### 1.1 User Model

```
User {
  id: UUID (primary key)
  email: string (unique, required, verified)
  username: string (unique, required, 3-20 chars, alphanumeric + underscore)
  password_hash: string (bcrypt, min 8 chars original)
  email_verified: boolean (default: false)
  email_verification_token: string (nullable)
  email_verification_expires: timestamp (nullable)
  password_reset_token: string (nullable)
  password_reset_expires: timestamp (nullable)
  created_at: timestamp
  updated_at: timestamp
  last_login: timestamp (nullable)
  is_active: boolean (default: true)
  profile_image_url: string (nullable)
  timezone: string (default: 'UTC')
  
  # Prize delivery info
  full_name: string (nullable) - Required for prize winners
  shipping_address: JSON (nullable) - Required for physical prizes
}
```

### 1.2 Authentication Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/auth/register` | Create new account | No |
| POST | `/auth/login` | Login, returns JWT | No |
| POST | `/auth/logout` | Invalidate refresh token | Yes |
| POST | `/auth/refresh` | Refresh access token | Refresh Token |
| POST | `/auth/verify-email` | Verify email with token | No |
| POST | `/auth/resend-verification` | Resend verification email | No |
| POST | `/auth/forgot-password` | Request password reset | No |
| POST | `/auth/reset-password` | Reset password with token | No |
| GET | `/auth/me` | Get current user profile | Yes |
| PATCH | `/auth/me` | Update profile | Yes |
| DELETE | `/auth/me` | Delete account | Yes |

### 1.3 Authentication Flow

1. **Registration**
   - Validate email format and uniqueness
   - Validate username (3-20 chars, alphanumeric + underscore, unique)
   - Validate password (min 8 chars, 1 uppercase, 1 lowercase, 1 number)
   - Hash password with bcrypt (cost factor 12)
   - Generate email verification token (secure random, 64 chars)
   - Send verification email
   - Return success (user cannot earn points until verified)

2. **Login**
   - Validate credentials
   - Check if account is active
   - Generate JWT access token (15 min expiry)
   - Generate refresh token (30 day expiry, stored in DB)
   - Return both tokens

3. **Token Structure**
   ```json
   {
     "sub": "user_id",
     "email": "user@example.com",
     "username": "player123",
     "email_verified": true,
     "iat": 1234567890,
     "exp": 1234567890
   }
   ```

### 1.4 Security Requirements

- **Rate Limiting**:
  - Login: 5 attempts per 15 minutes per IP
  - Registration: 3 per hour per IP
  - Password reset: 3 per hour per email
  
- **JWT**: 
  - Algorithm: RS256
  - Access token: 15 minutes
  - Refresh token: 30 days (stored, revocable)

- **Password Requirements**:
  - Minimum 8 characters
  - At least 1 uppercase, 1 lowercase, 1 number
  - Checked against common password list (top 10,000)

---

## 2. Daily Challenge System

### 2.1 Challenge Model

```
DailyChallenge {
  id: UUID (primary key)
  date: date (unique, indexed) - The day this challenge is for
  challenge_type: enum ['math', 'wordle', 'memory', 'general_knowledge']
  difficulty: enum ['easy', 'medium', 'hard']
  challenge_data: JSON - Type-specific challenge data
  created_at: timestamp
}
```

### 2.2 Challenge Data Structures

#### Math Challenge
```json
{
  "questions": [
    {
      "question": "23 + 45",
      "answer": 68
    },
    {
      "question": "12 × 8",
      "answer": 96
    },
    {
      "question": "144 ÷ 12",
      "answer": 12
    }
  ]
}
```

#### Wordle Challenge
```json
{
  "target_word": "CRANE",
  "max_attempts": 6
}
```

#### Memory Challenge
```json
{
  "grid_size": 4,
  "pairs_count": 8,
  "icons": [
    "rocket_launch",
    "pets",
    "eco",
    "bolt",
    "favorite",
    "star",
    "music_note",
    "flight"
  ],
  "seed": 12345  // For deterministic shuffle on client
}
```

#### General Knowledge Challenge
```json
{
  "questions": [
    {
      "question": "What is the capital of France?",
      "options": ["London", "Berlin", "Paris", "Madrid"],
      "correct_index": 2
    },
    {
      "question": "Which planet is known as the Red Planet?",
      "options": ["Venus", "Mars", "Jupiter", "Saturn"],
      "correct_index": 1
    },
    {
      "question": "Who painted the Mona Lisa?",
      "options": ["Van Gogh", "Picasso", "Da Vinci", "Michelangelo"],
      "correct_index": 2
    }
  ]
}
```

### 2.3 Challenge Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/challenges/today` | Get today's challenge | Yes |
| GET | `/challenges/{date}` | Get challenge for specific date | Yes |
| POST | `/challenges/submit` | Submit challenge completion | Yes |

### 2.4 Challenge Generation

A **scheduled job** runs daily at **00:00 UTC** to generate the next day's challenge:

1. Randomly select challenge type (weighted equally)
2. Randomly select difficulty based on day of week:
   - Monday-Wednesday: Easy (60%), Medium (30%), Hard (10%)
   - Thursday-Friday: Easy (30%), Medium (50%), Hard (20%)
   - Saturday-Sunday: Easy (20%), Medium (40%), Hard (40%)
3. Generate challenge data based on type
4. Store in database

**Important**: Challenges should be generated 7 days in advance to ensure reliability.

### 2.5 Challenge Submission

```
ChallengeSubmission {
  id: UUID (primary key)
  user_id: UUID (foreign key -> User)
  challenge_id: UUID (foreign key -> DailyChallenge)
  completion_time_seconds: integer
  attempts: integer (for wordle) / moves (for memory)
  correct_answers: integer (for math/GK)
  points_earned: integer
  completed_at: timestamp
  
  # Unique constraint on (user_id, challenge_id) - one submission per user per challenge
}
```

### 2.6 Points Calculation

Points are calculated server-side to prevent cheating:

```
Base Points by Challenge Type:
- Math: 100 base
- Wordle: 150 base (won) / 50 base (lost)
- Memory: 100 base
- General Knowledge: 150 base

Difficulty Multiplier:
- Easy: 1.0x
- Medium: 1.5x
- Hard: 2.0x

Time Penalty:
- Math/Memory: -0.5 points per second
- Wordle: -0.3 points per second
- GK: -0.5 points per second

Bonuses:
- Wordle: +20 points per remaining attempt
- GK: +50 points per correct answer
- Memory: -2 points per move over minimum

Final Score = (Base + Bonuses - Time Penalty) × Difficulty Multiplier
Minimum: 10 points
Maximum: 500 points
```

---

## 3. Leaderboard System

### 3.1 Leaderboard Model

```
MonthlyLeaderboard {
  id: UUID (primary key)
  user_id: UUID (foreign key -> User)
  year: integer
  month: integer (1-12)
  total_points: integer (default: 0)
  challenges_completed: integer (default: 0)
  average_completion_time: float (nullable)
  rank: integer (nullable) - Calculated at month end
  
  # Unique constraint on (user_id, year, month)
  # Index on (year, month, total_points DESC)
}

AllTimeLeaderboard {
  user_id: UUID (primary key, foreign key -> User)
  total_points: integer (default: 0)
  challenges_completed: integer (default: 0)
  current_streak: integer (default: 0)
  longest_streak: integer (default: 0)
  last_challenge_date: date (nullable)
  
  # Index on total_points DESC
}
```

### 3.2 Leaderboard Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/leaderboard/monthly` | Current month leaderboard | Yes |
| GET | `/leaderboard/monthly/{year}/{month}` | Specific month leaderboard | Yes |
| GET | `/leaderboard/all-time` | All-time leaderboard | Yes |
| GET | `/leaderboard/me` | Current user's rank & stats | Yes |
| GET | `/leaderboard/me/history` | User's monthly history | Yes |

### 3.3 Leaderboard Response Format

```json
{
  "period": {
    "type": "monthly",
    "year": 2026,
    "month": 1
  },
  "last_updated": "2026-01-04T12:00:00Z",
  "top_10": [
    {
      "rank": 1,
      "user_id": "uuid",
      "username": "champion123",
      "total_points": 12450,
      "challenges_completed": 28,
      "average_time": 34.5
    }
    // ... 9 more
  ],
  "user_position": {
    "rank": 156,
    "total_points": 3420,
    "challenges_completed": 15,
    "points_to_next_rank": 80
  }
}
```

### 3.4 Leaderboard Update Strategy

- **Real-time**: Update user's monthly total immediately on challenge submission
- **Cached**: Top 100 cached in Redis, refreshed every 5 minutes
- **Rank Calculation**: Full rank recalculation every hour for display purposes

---

## 4. Prize Distribution System

### 4.1 Prize Model

```
MonthlyPrize {
  id: UUID (primary key)
  year: integer
  month: integer
  rank: integer (1-10)
  prize_description: string
  prize_value_usd: decimal
  prize_type: enum ['amazon_gift_card', 'physical', 'digital_other']
  
  # Unique constraint on (year, month, rank)
}

PrizeAward {
  id: UUID (primary key)
  user_id: UUID (foreign key -> User)
  prize_id: UUID (foreign key -> MonthlyPrize)
  status: enum ['pending', 'contact_sent', 'details_received', 'shipped', 'delivered', 'claimed']
  awarded_at: timestamp
  contact_sent_at: timestamp (nullable)
  details_received_at: timestamp (nullable)
  shipped_at: timestamp (nullable)
  delivered_at: timestamp (nullable)
  tracking_number: string (nullable)
  notes: text (nullable)
  
  # Unique constraint on (user_id, prize_id)
}
```

### 4.2 Prize Endpoints (Admin)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/admin/prizes` | List all prize awards | Admin |
| POST | `/admin/prizes/monthly` | Set prizes for a month | Admin |
| PATCH | `/admin/prizes/{id}/status` | Update award status | Admin |

### 4.3 Prize Endpoints (User)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/prizes/current-month` | See this month's prizes | Yes |
| GET | `/prizes/my-awards` | User's won prizes | Yes |
| POST | `/prizes/my-awards/{id}/claim` | Submit delivery details | Yes |

### 4.4 Monthly Prize Distribution Flow

1. **Month End** (1st of next month, 00:00 UTC):
   - Freeze previous month's leaderboard
   - Calculate final rankings
   - Create PrizeAward records for top 10

2. **Notification** (automated):
   - Send email to winners
   - In-app notification
   - Request delivery details (name, email, address for physical)

3. **Fulfillment** (manual/semi-automated):
   - For Amazon gift cards: Generate and send via email
   - For physical: Ship and update tracking
   - Update status at each stage

---

## 5. API Design Guidelines

### 5.1 Base URL
```
Production: https://api.alarming.app/v1
Staging: https://api-staging.alarming.app/v1
```

### 5.2 Request/Response Format

All requests and responses use JSON:

```
Content-Type: application/json
Accept: application/json
```

### 5.3 Authentication Header

```
Authorization: Bearer <access_token>
```

### 5.4 Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format"
      }
    ]
  }
}
```

### 5.5 Standard Error Codes

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| 400 | VALIDATION_ERROR | Invalid input data |
| 401 | UNAUTHORIZED | Missing or invalid token |
| 403 | FORBIDDEN | Valid token but insufficient permissions |
| 404 | NOT_FOUND | Resource not found |
| 409 | CONFLICT | Resource already exists |
| 429 | RATE_LIMITED | Too many requests |
| 500 | INTERNAL_ERROR | Server error |

### 5.6 Pagination

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 156,
    "total_pages": 8
  }
}
```

---

## 6. Security Considerations

### 6.1 Anti-Cheat Measures

1. **Server-Side Validation**:
   - All point calculations done server-side
   - Challenge answers never sent to client before completion
   - Completion time validated (minimum realistic time per challenge type)

2. **Completion Time Validation**:
   - Math: Minimum 5 seconds per question
   - Wordle: Minimum 3 seconds per guess
   - Memory: Minimum 10 seconds total
   - GK: Minimum 2 seconds per question
   - Submissions faster than minimum are flagged for review

3. **Request Signing** (Optional but recommended):
   - Sign challenge submission requests with app secret
   - Include timestamp to prevent replay attacks

4. **Device Fingerprinting** (Optional):
   - Track device ID to detect multi-accounting

### 6.2 Data Protection

1. **PII Handling**:
   - Encrypt sensitive fields at rest (email, address, full_name)
   - GDPR/CCPA compliant data export and deletion

2. **Audit Logging**:
   - Log all authentication events
   - Log all prize-related actions
   - Log admin actions

---

## 7. Infrastructure Recommendations

### 7.1 Tech Stack Suggestion

- **Runtime**: Node.js (Express/Fastify) or Python (FastAPI)
- **Database**: PostgreSQL (primary data)
- **Cache**: Redis (leaderboard cache, rate limiting, sessions)
- **Queue**: Redis Queue or RabbitMQ (email sending, prize processing)
- **Email**: SendGrid or AWS SES

### 7.2 Hosting

- **Compute**: AWS ECS/Fargate, Google Cloud Run, or Railway
- **Database**: AWS RDS, Google Cloud SQL, or Supabase
- **CDN**: CloudFlare (for API rate limiting at edge)

### 7.3 Estimated Scale

- Expected users: 10,000-100,000
- Daily challenges: 1 per day (lightweight)
- Peak load: Morning hours (alarm time)
- Database size: ~10GB first year

---

## 8. Development Phases

### Phase 1: Core (MVP)
- User authentication (register, login, JWT)
- Email verification
- Daily challenge API (GET today's challenge)
- Challenge submission
- Basic monthly leaderboard

### Phase 2: Enhanced
- Password reset flow
- Profile management
- All-time leaderboard
- Streak tracking
- Challenge history

### Phase 3: Prizes
- Prize management (admin)
- Prize claiming (user)
- Email notifications
- Winner announcement system

### Phase 4: Polish
- Rate limiting
- Anti-cheat measures
- Analytics dashboard
- Push notification integration

---

## 9. Client Integration Notes

### 9.1 App Changes Required

1. **Auth Flow**:
   - Add login/register screens
   - Store JWT securely (iOS Keychain, Android Keystore)
   - Handle token refresh automatically
   - Show "Guest Mode" for non-authenticated users (no points)

2. **Challenge Flow**:
   - Fetch daily challenge from API instead of local generation
   - Submit completion to API
   - Handle offline: Queue submission for when online

3. **Leaderboard Screen**:
   - New screen showing monthly and all-time rankings
   - User's current position
   - Prize information for top 10

4. **Profile Screen**:
   - Account settings
   - Prize claim interface
   - Challenge history and stats

### 9.2 Offline Support

The app should work offline with degraded functionality:
- Allow alarm dismissal with locally-generated challenges
- Queue challenge submissions for later
- Cache last-known leaderboard
- Show "Offline Mode" indicator

---

## 10. API Endpoint Summary

### Authentication
```
POST   /auth/register
POST   /auth/login
POST   /auth/logout
POST   /auth/refresh
POST   /auth/verify-email
POST   /auth/resend-verification
POST   /auth/forgot-password
POST   /auth/reset-password
GET    /auth/me
PATCH  /auth/me
DELETE /auth/me
```

### Challenges
```
GET    /challenges/today
GET    /challenges/{date}
POST   /challenges/submit
GET    /challenges/history
```

### Leaderboard
```
GET    /leaderboard/monthly
GET    /leaderboard/monthly/{year}/{month}
GET    /leaderboard/all-time
GET    /leaderboard/me
GET    /leaderboard/me/history
```

### Prizes
```
GET    /prizes/current-month
GET    /prizes/my-awards
POST   /prizes/my-awards/{id}/claim
```

### Admin
```
GET    /admin/prizes
POST   /admin/prizes/monthly
PATCH  /admin/prizes/{id}/status
GET    /admin/users
GET    /admin/challenges
POST   /admin/challenges
```

---

## Appendix A: Database Schema (SQL)

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verification_token VARCHAR(64),
    email_verification_expires TIMESTAMP,
    password_reset_token VARCHAR(64),
    password_reset_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    profile_image_url VARCHAR(500),
    timezone VARCHAR(50) DEFAULT 'UTC',
    full_name VARCHAR(255),
    shipping_address JSONB
);

-- Daily challenges table
CREATE TABLE daily_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE UNIQUE NOT NULL,
    challenge_type VARCHAR(20) NOT NULL,
    difficulty VARCHAR(10) NOT NULL,
    challenge_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_challenges_date ON daily_challenges(date);

-- Challenge submissions table
CREATE TABLE challenge_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id UUID NOT NULL REFERENCES daily_challenges(id) ON DELETE CASCADE,
    completion_time_seconds INTEGER NOT NULL,
    attempts INTEGER,
    correct_answers INTEGER,
    points_earned INTEGER NOT NULL,
    completed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, challenge_id)
);

CREATE INDEX idx_submissions_user ON challenge_submissions(user_id);
CREATE INDEX idx_submissions_challenge ON challenge_submissions(challenge_id);

-- Monthly leaderboard table
CREATE TABLE monthly_leaderboard (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_points INTEGER DEFAULT 0,
    challenges_completed INTEGER DEFAULT 0,
    average_completion_time FLOAT,
    rank INTEGER,
    UNIQUE(user_id, year, month)
);

CREATE INDEX idx_monthly_lb_period ON monthly_leaderboard(year, month, total_points DESC);

-- All-time leaderboard table  
CREATE TABLE all_time_leaderboard (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_points INTEGER DEFAULT 0,
    challenges_completed INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_challenge_date DATE
);

CREATE INDEX idx_alltime_lb_points ON all_time_leaderboard(total_points DESC);

-- Monthly prizes table
CREATE TABLE monthly_prizes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    rank INTEGER NOT NULL,
    prize_description VARCHAR(500) NOT NULL,
    prize_value_usd DECIMAL(10, 2),
    prize_type VARCHAR(50) NOT NULL,
    UNIQUE(year, month, rank)
);

-- Prize awards table
CREATE TABLE prize_awards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prize_id UUID NOT NULL REFERENCES monthly_prizes(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',
    awarded_at TIMESTAMP DEFAULT NOW(),
    contact_sent_at TIMESTAMP,
    details_received_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    tracking_number VARCHAR(100),
    notes TEXT,
    UNIQUE(user_id, prize_id)
);

-- Refresh tokens table
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    revoked BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
```

---

## Appendix B: Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/alarming

# Redis
REDIS_URL=redis://host:6379

# JWT
JWT_PRIVATE_KEY=<RSA private key>
JWT_PUBLIC_KEY=<RSA public key>
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=30d

# Email
SENDGRID_API_KEY=<key>
EMAIL_FROM=noreply@alarming.app

# App
APP_ENV=production
APP_URL=https://api.alarming.app
FRONTEND_URL=https://alarming.app

# Security
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
BCRYPT_ROUNDS=12
```

---

*Document Version: 1.0*
*Last Updated: January 4, 2026*
