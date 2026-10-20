/// Tiny key-value storage delegate so inspector settings (currently the tester
/// guide's "don't show again" choice) survive app restarts.
///
/// The package ships no implementation, to avoid pulling in a storage plugin.
/// Back it with `shared_preferences`, a file, Hive, etc.:
///
/// ```dart
/// class PrefsInspectorStorage implements FInspectorStorage {
///   @override
///   Future<String?> read(String key) async =>
///       (await SharedPreferences.getInstance()).getString(key);
///
///   @override
///   Future<void> write(String key, String value) async =>
///       (await SharedPreferences.getInstance()).setString(key, value);
/// }
/// ```
abstract class FInspectorStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
