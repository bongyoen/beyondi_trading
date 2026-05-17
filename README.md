# Beyondi Trading

A production-ready trading application built with Flutter, featuring a modern responsive UI, secure authentication flow, and scalable architecture following Feature-Sliced Design principles.

---

## Project Overview

| Property | Value |
|----------|-------|
| **Project Name** | Beyondi Trading |
| **Platform** | Windows (primary target), Mobile-ready (responsive) |
| **Description** | Trading application with dashboard, portfolio tracking, market data, and analytics |
| **Flutter Version** | 3.38.1 |
| **Dart Version** | 3.10.0 |
| **Project Location** | `/mnt/c/Users/kuhj1/WebstormProjects/beyondi_trading` |

---

## Technology Stack

| Category | Technology | Version |
|----------|------------|---------|
| Framework | Flutter | 3.38.1 |
| Language | Dart | 3.10.0 |
| State Management | flutter_bloc | ^9.1.1 |
| Equality | equatable | ^2.0.8 |
| Typography | google_fonts | ^6.2.1 |
| Icons | cupertino_icons | ^1.0.8 |

---

## Architecture

### Feature-Sliced Design (FSD)

The project follows Feature-Sliced Design, a architectural methodology that separates code by business capabilities (features) rather than technical roles. This ensures high cohesion within features and loose coupling between them.

```
lib/
├── app/                    # Root application widget & routing
├── entities/               # Shared domain entities (User)
├── features/               # Feature modules (auth, counter, ...)
│   └── {feature}/
│       ├── data/           # Data layer: repositories, data sources
│       ├── domain/         # Domain layer: entities, use cases
│       └── presentation/   # Presentation layer: pages, widgets, BLoCs
├── pages/                  # Top-level page compositions (AppShell, Home)
├── shared/                # Cross-cutting concerns
│   ├── constants/          # App-wide constants (spacing, breakpoints)
│   └── theme/             # Theme configuration (colors, typography)
└── widgets/               # Reusable UI components (Sidebar, SidebarItem)
```

### Layer Separation

Each feature follows a strict three-layer architecture:

| Layer | Responsibility | Contents |
|-------|---------------|----------|
| **Data** | Data access and storage | Repositories, data sources, models |
| **Domain** | Business logic and rules | Entities, use cases, domain interfaces |
| **Presentation** | UI and state management | Pages, widgets, BLoCs, states, events |

### State Management: BLoC Pattern

The project uses `flutter_bloc` for predictable state management. Each feature has its own BLoC that receives events, processes them through use cases, and emits states.

```
User Action → Event → BLoC → UseCase → Repository → State → UI Update
```

---

## Features Implemented

### Authentication System

- **Login Page** with ID/Password form
- **Form validation** with real-time error feedback
- **Loading states** with animated spinner
- **Failure handling** with descriptive error messages
- **Demo mode**: any ID/password combination succeeds

### Responsive Navigation

| Viewport | Behavior |
|----------|----------|
| **Desktop** (≥768px) | Fixed sidebar (260px) with gradient background |
| **Mobile** (<768px) | Hamburger menu triggering a drawer sidebar |

### Modern UI with Material 3

- Full **Material 3** theming with dynamic color support
- **Light and dark** theme variants following system preference
- **Glass morphism** login card with frosted effect
- **Gradient backgrounds** (navy-to-purple login, dark sidebar)
- **Smooth animations** (fade + slide entrance, page transitions)

---

## Design System

### Color Palette

| Role | Light Mode | Dark Mode | Usage |
|------|------------|-----------|-------|
| Primary | `#1E3A5F` (Navy) | `#9ECAFF` | Brand, selected states |
| Secondary | `#B8860B` (Amber/Gold) | `#F5C542` | Accents, CTAs, highlights |
| Tertiary | `#006B5E` (Teal) | `#5BD9C6` | Supporting accents |
| Surface | `#F8F9FF` | `#111318` | Backgrounds |
| Error | `#BA1A1A` | `#FFB4AB` | Validation, errors |

### Gradient Assets

| Name | Colors | Usage |
|------|--------|-------|
| `sidebarGradient` | `#1A1A2E` → `#16213E` | Desktop sidebar background |
| `loginGradient` | `#0F0C29` → `#1E3A5F` → `#2C1654` | Login page background |
| `buttonGradient` | `#B8860B` → `#D4A017` | Primary action buttons |

### Typography

| Role | Font | Weight | Usage |
|------|------|--------|-------|
| Headings (H1-H6) | Poppins | 600-700 | Titles, labels, emphasis |
| Body Text | Inter | 400-500 | Paragraphs, descriptions |
| UI Elements | Inter | 400-600 | Buttons, form fields, navigation |

**Font Stack**: Google Fonts (Poppins + Inter)

### Spacing Scale

```
spacingXxs:  4px
spacingXs:   8px
spacingSm:  12px
spacingMd:  16px  ← Base unit
spacingLg:  24px
spacingXl:  32px
spacingXxl: 48px
spacingXxxl: 64px
```

### Border Radius

```
radiusSm:   8px   ← Inputs, small buttons
radiusMd:  12px   ← Cards, medium buttons
radiusLg:  16px   ← Large cards, dialogs
radiusXl:  20px   ← Feature cards
radiusFull: 999px ← Pills, avatars
```

### Responsive Breakpoints

| Breakpoint | Value | Layout |
|------------|-------|--------|
| Mobile | `< 768px` | Drawer navigation, stacked layout |
| Desktop | `≥ 768px` | Fixed sidebar, side-by-side layout |

### Animation Specifications

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| Page transitions | 300ms | `easeOut` | Content area switching |
| Sidebar entrance | 350ms | `easeOutCubic` | Sidebar slide + fade |
| Button feedback | 200ms | `easeInOut` | Loading spinner, icon swaps |
| Login card entrance | 800ms | `easeOut` | Initial page load |

---

## Directory Structure

```
beyondi_trading/
├── lib/
│   ├── app/
│   │   └── app.dart                 # Root app widget, auth-aware routing
│   ├── entities/
│   │   └── user.dart                # Shared User entity
│   ├── features/
│   │   ├── auth/                    # Authentication feature
│   │   │   ├── data/
│   │   │   │   └── repositories/
│   │   │   │       └── auth_repository.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── user_credentials.dart
│   │   │   │   └── usecases/
│   │   │   │       └── login.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── login_bloc.dart
│   │   │       │   ├── login_event.dart
│   │   │       │   └── login_state.dart
│   │   │       └── pages/
│   │   │           └── login_page.dart
│   │   └── counter/                 # Demo feature (BLoC example)
│   ├── pages/
│   │   ├── home/
│   │   │   └── home_page.dart
│   │   └── shell/
│   │       └── app_shell.dart       # Responsive shell (sidebar + content)
│   ├── shared/
│   │   ├── constants/
│   │   │   └── app_constants.dart  # Spacing, breakpoints, dimensions
│   │   └── theme/
│   │       └── app_theme.dart      # Colors, typography, components
│   ├── widgets/
│   │   ├── sidebar/
│   │   │   ├── responsive_sidebar.dart
│   │   │   └── sidebar_item.dart
│   │   └── app_widget.dart
│   ├── main.dart                    # App entry point, BLoC providers
│   └── ...
├── pubspec.yaml
├── README.md
└── ...
```

---

## How to Run

### Prerequisites

- Flutter SDK 3.38.1 or higher
- Dart SDK 3.10.0 or higher

### Commands

```bash
# Navigate to project
cd /mnt/c/Users/kuhj1/WebstormProjects/beyondi_trading

# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build for Windows (release)
flutter build windows --release

# Build for Windows (debug)
flutter build windows

# Analyze code
flutter analyze
```

### Build Output

- Windows release: `build/windows/runner/Release/beyondi_trading.exe`
- Windows debug: `build/windows/runner/Debug/beyondi_trading.exe`

---

## Backend Setup

### Cloudflare Workers + D1

The backend API is designed to run on Cloudflare Workers with D1 database for persistent storage.

**Current Status**: Infrastructure is ready. Manual binding configuration is required on first deployment.

**Required Setup Steps**:

1. **Create D1 Database**
   ```bash
   wrangler d1 create beyondi-trading-db
   ```

2. **Bind D1 to Worker**
   Add the following to `wrangler.toml`:
   ```toml
   [[d1_databases]]
   binding = "DB"
   database_name = "beyondi-trading-db"
   database_id = "<your-database-id>"
   ```

3. **Run Migrations**
   ```bash
   wrangler d1 migrations apply beyondi-trading-db --local
   # or --remote for production
   ```

4. **Deploy Worker**
   ```bash
   wrangler deploy
   ```

**API Base URL**: Configured via `APP_CONFIG.apiBaseUrl` in `lib/shared/config/app_config.dart`

---

## Demo Login

The application operates in demo mode — any ID and password combination will authenticate successfully.

**Test credentials**:
- ID: `demo` / Password: `demo`
- ID: any value / Password: any value

---

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_bloc: ^9.1.1
  equatable: ^2.0.8
  google_fonts: ^6.2.1
```