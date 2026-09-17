/// Which frontend this process is running.
///
/// The BACKEND is shared by every mode: `services/` (ApiService +
/// SupabaseService) talks to the same Supabase cloud database, so both
/// frontends always see the same products, categories, users and orders.
/// Only the user interface differs:
///
///  * [AppMode.combined]  — one app: the shop, plus the admin panel for
///                          admins on a computer (default, `lib/main.dart`)
///  * [AppMode.adminOnly] — the admin dashboard only (`lib/main_admin.dart`)
///  * [AppMode.userOnly]  — the shop only, every admin UI hidden
///                          (`lib/main_user.dart`)
enum AppMode { combined, adminOnly, userOnly }

class AppRunMode {
  /// Set once in `main()` before [runApp]. Defaults to the classic
  /// combined behaviour so existing entry points and tests are untouched.
  static AppMode mode = AppMode.combined;

  static bool get isAdminApp => mode == AppMode.adminOnly;
  static bool get isUserApp => mode == AppMode.userOnly;
  static bool get isCombined => mode == AppMode.combined;
}
