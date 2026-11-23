import 'dart:io';

/// HTTP port your API listens on (`launchSettings.json` → `http` profile).
const int kApiHttpPort = 5254;

/// Physical phone on **Wi‑Fi** — your PC's local IP from `ipconfig`.
/// Leave as `null` and use `adb reverse` instead if you prefer USB-only setup.
//const String? kAndroidLanOverride = 'http://192.168.137.1:5254';
const String? kAndroidLanOverride = 'http://10.106.94.90:5058';//mymobile 
/// Backend base URL (no trailing slash).
///
/// **Wi‑Fi setup (current):**
/// Phone and PC must be on the same Wi‑Fi network. [kAndroidLanOverride] points
/// directly at the PC's IP, so no `adb reverse` or cable is needed.
///
/// **Override:** `flutter run --dart-define=API_BASE_URL=http://...`
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) {
    return fromEnv.replaceAll(RegExp(r'/$'), '');
  }

  final lan = kAndroidLanOverride?.trim();
  if (lan != null && lan.isNotEmpty) {
    return lan.replaceAll(RegExp(r'/$'), '');
  }

  if (Platform.isAndroid) {
    return 'http://127.0.0.1:$kApiHttpPort';
  }
  return 'http://localhost:$kApiHttpPort';
}

























// import 'dart:io';

// /// HTTP port your API listens on (`launchSettings.json` → `http` profile, usually **5215**).
// const int kApiHttpPort = 5148;
// //const int kApiHttpPort = 5215;
// //5215

// /// **Optional** — physical phone on **Wi‑Fi** only (no USB / no `adb reverse`).
// /// Example: `'http://192.168.0.45:5215'` from `ipconfig`. Leave **`null`** for normal dev.
// const String? kAndroidLanOverride = null;

// /// Backend base URL (no trailing slash).
// ///
// /// **Android (emulator + USB cable) — one setup:**
// /// 1. Start the API on your PC (e.g. port [kApiHttpPort]).
// /// 2. Connect **either** the emulator **or** the phone (USB).
// /// 3. Run once per machine/session (device must show in `adb devices`):
// ///    `adb reverse tcp:5215 tcp:5215`  (use the same port as [kApiHttpPort])
// /// 4. `flutter run` — the app uses `http://127.0.0.1` on the device; ADB forwards to your PC.
// ///
// /// Same command works for **AVD** and **real device**; whichever is the active ADB target gets the reverse.
// ///
// /// **Override:** `flutter run --dart-define=API_BASE_URL=http://...`
// String get apiBaseUrl {
//   const fromEnv = String.fromEnvironment('API_BASE_URL');
//   if (fromEnv.isNotEmpty) {
//     return fromEnv.replaceAll(RegExp(r'/$'), '');
//   }
//   if (Platform.isAndroid) {
//     final lan = kAndroidLanOverride?.trim();
//     if (lan != null && lan.isNotEmpty) {
//       return lan.replaceAll(RegExp(r'/$'), '');
//     }
//     return 'http://127.0.0.1:$kApiHttpPort';
//   }
//   return 'http://localhost:$kApiHttpPort';
// }




















// // import 'dart:io';

// // /// HTTP port your API listens on
// // const int kApiHttpPort = 5215;

// // /// YOUR PC LOCAL IP
// // const String? kAndroidLanOverride =
// //     'http://192.168.100.11:5215';

// // String get apiBaseUrl {

// //   const fromEnv =
// //       String.fromEnvironment('API_BASE_URL');

// //   if (fromEnv.isNotEmpty) {

// //     return fromEnv.replaceAll(
// //       RegExp(r'/$'),
// //       '',
// //     );
// //   }

// //   if (Platform.isAndroid) {

// //     final lan =
// //         kAndroidLanOverride?.trim();

// //     if (lan != null &&
// //         lan.isNotEmpty) {

// //       return lan.replaceAll(
// //         RegExp(r'/$'),
// //         '',
// //       );
// //     }

// //     return 'http://127.0.0.1:$kApiHttpPort';
// //   }

// //   return 'http://localhost:$kApiHttpPort';
// // }

