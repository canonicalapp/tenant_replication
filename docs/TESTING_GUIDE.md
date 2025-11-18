# Testing Guide - Tenant Replication SDK

Complete guide for testing the mtds Flutter SDK with your MTDD ecosystem.

## 📁 Example Application Structure

### Current Example Application Files

```
example/
├── lib/
│   ├── database.dart                       # Drift schema + migrations
│   ├── main.dart                           # App entry point
│   ├── screens/
│   │   └── test_screen.dart                # Main UI with SDK operations
│   ├── services/
│   │   └── sdk_service.dart               # SDK initialization
│   ├── utils/
│   │   ├── jwt_helper.dart                # JWT token generation
│   │   └── activity_logger.dart           # Activity logging
│   └── widgets/                            # Reusable UI components
├── pubspec.yaml                            # Dependencies
└── README.md                               # Example app documentation
```

## 🚀 Testing Options

### Option 1: Quick Test (Recommended for First-Time)

**Time:** ~5 minutes  
**What:** Test Flutter app with local PostgreSQL  
**Guide:** [example/README.md](../example/README.md)

```bash
# 1. Start server (from tenant_replication_postgres/examples/example-app)
cd ../../tenant_replication_postgres/examples/example-app
npm install
npm run setup:db  # Creates database and tables
npm run dev       # Starts server on http://localhost:3000

# 2. Run Flutter app
cd ../../tenant_replication/example
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
```

**Best For:**
- ✅ First-time testing
- ✅ Understanding the SDK
- ✅ Quick feature demos
- ✅ Local development

---

### Option 2: Full MTDD Ecosystem

**Time:** ~30 minutes  
**What:** Complete multi-shard gRPC setup  
**Note:** For full MTDD ecosystem setup, refer to the server-side library documentation

```bash
# 1. Setup databases
createdb mtdd_shard_0
createdb mtdd_shard_1
createdb mtdd_shard_2

# 2. Start MTDD query servers
cd mtdd
npm install && npm start  # Port 50051

# 3. Start MTDDLookup service
cd ../mtddlookup
npm install && npm start  # Port 50054

# 4. Start REST API (production mode)
cd ../mtdd-test-app
npm run prod  # Port 3000

# 5. Run Flutter app
cd ../mtds/example
flutter run
```

**Best For:**
- ✅ Production-like testing
- ✅ Multi-tenant scenarios
- ✅ Understanding gRPC routing
- ✅ Shard isolation testing

---

### Option 3: Development Mode (SDK Only)

**Time:** ~2 minutes  
**What:** Test SDK features without backend  
**Guide:** Flutter app only

```bash
cd mtds/example
flutter pub get
flutter run
```

**What You Can Test:**
- ✅ Local SQLite operations
- ✅ MTDS field generation
- ✅ Change tracking triggers
- ✅ UI and navigation
- ❌ Server sync (no backend)
- ❌ Real-time updates

**Best For:**
- ✅ SDK development
- ✅ UI testing
- ✅ Local database features

---

## 🎯 Testing Scenarios by Component

### Testing Components Available in Your Repo

| Component | Location | Purpose | Port |
|-----------|----------|---------|------|
| **Flutter Example** | `mtds/example/` | Client app | - |
| **REST API** | `mtdd-test-app/` | HTTP endpoints | 3000 |
| **Query Server** | `mtdd/` | gRPC executor | 50051+ |
| **Lookup Service** | `mtddlookup/` | Tenant routing | 50054 |
| **Library** | `mtds_postgres/` | Knex extension | - |

### What Each Component Provides

#### 1. Flutter Example App ✨ **NEW**

**Location:** `mtds/example/`

**Features:**
- Complete UI for testing SDK
- Authentication setup (JWT + Direct)
- Database CRUD operations
- Sync management
- SSE connection handling
- Real-time logs

**Test It:**
```bash
cd mtds/example
flutter run
```

#### 2. mtdd-test-app (REST API)

**Location:** `mtdd-test-app/`

**Features:**
- HTTP endpoints for Flutter
- Environment-based routing
- Development mode (no gRPC)
- Production mode (with gRPC)

**Test It:**
```bash
cd mtdd-test-app
npm run dev   # Development mode
# OR
npm run prod  # Production mode
```

#### 3. MTDD Services (Backend)

**Locations:**
- `mtdd/` - Query execution
- `mtddlookup/` - Tenant routing

**Features:**
- gRPC binary protocol
- Multi-shard support
- Tenant isolation

**Test It:**
```bash
# Terminal 1
cd mtdd
npm start

# Terminal 2
cd mtddlookup
npm start
```

---

## 📝 Step-by-Step Testing Plan

### Phase 1: Verify Setup (5 min)

```bash
# Check Flutter
flutter doctor

# Check Node.js
node --version  # Should be 20+

# Check PostgreSQL
psql --version
pg_isready

# Check all components exist
ls -la mtds/example/
ls -la mtdd-test-app/
ls -la mtdd/
ls -la mtddlookup/
```

### Phase 2: Test Flutter App Alone (10 min)

```bash
cd mtds/example
flutter pub get
flutter run -d chrome
```

**Actions:**
1. ✅ App opens without errors
2. ✅ Navigate through all screens
3. ✅ Setup authentication
4. ✅ Create users locally
5. ✅ View change logs

### Phase 3: Test with REST API (20 min)

```bash
# Terminal 1: Start API
cd mtdd-test-app
npm install
npm run dev

# Terminal 2: Run Flutter
cd mtds/example
flutter run
```

**Actions:**
1. ✅ Configure auth in Flutter
2. ✅ Create multiple users
3. ✅ Click "Sync with Server"
4. ✅ Verify in database:
   ```bash
   psql -U postgres -d mtdd_dev -c "SELECT * FROM users;"
   ```
5. ✅ Test bulk load
6. ✅ Connect SSE

### Phase 4: Test Complete Ecosystem (1 hour)

```bash
# Terminal 1: Query Server
cd mtdd
npm start

# Terminal 2: Lookup Service
cd mtddlookup
npm start

# Terminal 3: REST API (production)
cd mtdd-test-app
npm run prod

# Terminal 4: Flutter
cd mtds/example
flutter run
```

**Actions:**
1. ✅ Register tenants
2. ✅ Test multi-tenant isolation
3. ✅ Verify shard routing
4. ✅ Test on multiple devices
5. ✅ Verify conflict resolution

---

## 🎓 Learning Path

### For New Users

1. **Start Here:** [QUICK_START.md](example/QUICK_START.md)
   - Get running in 5 minutes
   - Test basic features
   - Understand workflow

2. **Understand Architecture:** [ARCHITECTURE.md](example/ARCHITECTURE.md)
   - Visual diagrams
   - Data flow
   - Component responsibilities

3. **Full Setup:** [MTDD_ECOSYSTEM_SETUP.md](example/MTDD_ECOSYSTEM_SETUP.md)
   - Complete installation
   - All components
   - Production setup

4. **Customize:** [Example README](example/README.md)
   - Detailed API reference
   - Configuration options
   - Advanced usage

### For Experienced Users

1. **Quick Test:** Run Option 1 (5 min)
2. **Review Code:** Check `example/lib/screens/`
3. **Integrate:** Add SDK to your project
4. **Deploy:** Setup production environment

---

## 🧪 What Can You Test?

### SDK Features

| Feature | Test Location | Example |
|---------|--------------|---------|
| **Local Database** | Database Operations Screen | Create/Read/Update users |
| **MTDS Fields** | Database Operations | View auto-generated txid |
| **Change Tracking** | Change Logs viewer | See tbldmlog entries |
| **Soft Delete** | Database Operations | Delete button |
| **Auth Setup** | Auth Setup Screen | JWT vs Direct mode |
| **Sync** | Sync Screen | Push changes |
| **SSE** | Sync Screen | Real-time updates |
| **Bulk Load** | Sync Screen | Load all tables |

### Backend Features

| Feature | Component | Test Method |
|---------|-----------|-------------|
| **Local Queries** | mtdd-test-app (dev) | Use .mtdd() |
| **gRPC Routing** | mtdd-test-app (prod) | Multi-shard queries |
| **Tenant Lookup** | mtddlookup | Register/lookup tenants |
| **Query Execution** | mtdd | Execute on shards |
| **Connection Pooling** | mtdd | High-load testing |

---

## 🐛 Common Issues & Solutions

### "No server running"
```bash
# Start the REST API
cd mtdd-test-app
npm run dev
```

### "Database doesn't exist"
```bash
# Create it
createdb mtdd_dev

# Or check name
psql -U postgres -l | grep mtdd
```

### "Flutter app can't sync"
- Check server URL is correct
- For mobile: Use `http://192.168.x.x:3000` (not localhost)
- Verify server is accessible: `curl http://localhost:3000/health`

### "gRPC services won't start"
```bash
# Check ports aren't in use
lsof -i :50051
lsof -i :50054

# Install dependencies
cd mtdd && npm install
cd mtddlookup && npm install
```

---

## 📊 Testing Checklist

### Basic Testing ✓

- [ ] Flutter app runs without errors
- [ ] Can create auth credentials
- [ ] Can create users in local database
- [ ] MTDS fields auto-populate
- [ ] Change logs appear in tbldmlog
- [ ] Can view all created records

### Backend Integration ✓

- [ ] REST API server starts
- [ ] Flutter can connect to server
- [ ] Sync endpoint receives data
- [ ] Data appears in PostgreSQL
- [ ] Can load data from server
- [ ] SSE connection establishes

### Advanced Testing ✓

- [ ] MTDD services running
- [ ] Tenant registration works
- [ ] Shard routing functions
- [ ] Multi-tenant isolation verified
- [ ] Conflict resolution tested
- [ ] Real-time updates working

---

## 🚀 Next Steps

After testing:

1. **Understand the Code**
   - Review `example/lib/` source
   - Study MTDS field usage
   - Learn sync patterns

2. **Customize for Your Needs**
   - Modify UI screens
   - Add your tables
   - Implement business logic

3. **Integrate into Your Project**
   ```yaml
   dependencies:
     mtds: ^0.0.5
   ```

4. **Deploy to Production**
   - Setup MTDD services
   - Configure gRPC
   - Enable SSL/TLS

---

## 📚 Documentation Index

| Document | Purpose | Audience |
|----------|---------|----------|
| [QUICK_START.md](example/QUICK_START.md) | 5-min setup | Everyone |
| [README.md](example/README.md) | Complete guide | Developers |
| [ARCHITECTURE.md](example/ARCHITECTURE.md) | System design | Architects |
| [MTDD_ECOSYSTEM_SETUP.md](example/MTDD_ECOSYSTEM_SETUP.md) | Full setup | DevOps |
| [../README.md](README.md) | SDK reference | SDK users |

---

## 🎉 You're Ready!

You now have:
- ✅ Complete example Flutter app
- ✅ Backend services in your repo
- ✅ Multiple testing options
- ✅ Comprehensive documentation

**Recommended First Step:**

```bash
cd mtds/example
open QUICK_START.md  # Read this first!
flutter run          # Then run this!
```

Happy Testing! 🚀

---

Made with ❤️ by the MTDD Team



