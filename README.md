# WINGSPAN Ground Control Station (GCS)

Welcome to the WINGSPAN Ground Control Station (GCS) frontend repository. This application is a robust, cross-platform dashboard built to monitor, control, and communicate with unmanned vehicles. 

## Technology Stack

The frontend has been carefully engineered using modern, high-performance frameworks to ensure a smooth, responsive, and maintainable user experience across all platforms. 

* **Framework:** [Flutter](https://flutter.dev/) - Chosen for its ability to compile natively to Web and Windows from a single codebase, ensuring a consistent UI and high performance.
* **State Management:** [Riverpod](https://riverpod.dev/) - Implemented for reactive and safe state management. It allows the UI to instantly react to incoming telemetry and connection state changes without unnecessary widget rebuilds.
* **Routing:** [GoRouter](https://pub.dev/packages/go_router) - Used for declarative routing, making deep linking and navigation between different dashboard views completely seamless.
* **UI/UX Design:** Designed with a dark-mode first approach, utilizing a custom color palette defined in our theme engine. The interface emphasizes data density, situational awareness, and ease of use in field environments.

## Project Architecture & File Structure

The codebase is heavily modularized to separate UI components from business logic and state management. This ensures scalability and makes it easy for backend engineers to integrate data streams. Below is a comprehensive guide to the project's file structure.

###  Root Level Configuration
* `pubspec.yaml` & `pubspec.lock`: Defines external package dependencies (like `flutter_map`, `flutter_riverpod`).
* `analysis_options.yaml`: Enforces strict code linting and formatting rules for maintainability.
* `.metadata` & `.flutter-plugins-dependencies`: Internal Flutter tracking files necessary for building the project.
* `web/` & `windows/`: Platform-specific runners and configuration files for compiling to Web and Desktop.

### `lib/` (Main Application Code)
This is where the core logic and UI of the application live.

#### `lib/main.dart`
The entry point of the application. It initializes the app, injects the Riverpod `ProviderScope`, and sets up the global theme and routing engine.

#### `lib/core/`
Contains the business logic, state, routing, and styling that is shared globally across the app.
* **`models/models.dart`**: Defines the data transfer objects (DTOs) and data shapes (e.g., Telemetry data, Drone status) expected by the frontend. 
* **`store/`**:
  * `gcs_state.dart`: Defines the structure of the application's global state.
  * `gcs_notifier.dart`: The core logic that updates the state. **(Integration Point: This is where backend APIs, WebSockets, or MAVLink streams will interface with the frontend to feed it real data.)**
* **`router/app_router.dart`**: Defines all the URL routes and navigation paths in the app.
* **`theme/`**:
  * `app_colors.dart`: The centralized color palette.
  * `app_theme.dart`: Global light/dark themes and typography settings.

#### `lib/shell/`
Contains the persistent layout components that act as the structural "shell" of the dashboard.
* `app_shell.dart`: The main layout wrapper tying the sidebar and top/bottom bars together.
* `sidebar.dart`: The main vertical navigation menu.
* `status_bar.dart`: The persistent top bar showing critical connection and vehicle status.
* `bottom_alert_strip.dart`: A persistent strip at the bottom of the screen for displaying critical system warnings.

#### `lib/pages/`
Contains the individual screens and feature views of the dashboard.
* `connection_page.dart`: Interface for establishing a connection to the vehicle via Serial, UDP, or TCP.
* `fly_view/fly_view.dart`: The primary flight interface, featuring a live map, HUD, and real-time telemetry overlays.
* `mission_page.dart`: Tooling for planning, editing, and uploading waypoint-based missions.
* `video_page.dart`: Renders live video feeds from the vehicle's payload cameras.
* `telemetry_page.dart`: Detailed dashboard for raw and graphed telemetry data.
* `parameters_page.dart`: Interface for viewing and modifying low-level firmware parameters.
* `alerts_page.dart`: A historical log of system warnings and alerts.
* `diagnostics_page.dart`: Tools for troubleshooting system health and sensor calibrations.
* `logs_page.dart`: Interface for downloading and analyzing flight logs.
* `simulation_page.dart`: Controls for configuring and connecting to SITL (Software-In-The-Loop) simulations.
* `vehicles_page.dart`: Management dashboard for multi-vehicle operations.
* `settings_page.dart`: Application-level preferences and configurations.

## Setup and Running

To run this project locally:

1. Ensure [Flutter](https://docs.flutter.dev/get-started/install) is installed on your machine.
2. Clone the repository.
3. Run `flutter pub get` to fetch all dependencies.
4. Run `flutter run -d windows` (for desktop) or `flutter run -d chrome` (for web).
