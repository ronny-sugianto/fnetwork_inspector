/// Storage delegate that lets mock rules and scenarios survive app restarts.
///
/// The package ships **no** implementation (to avoid pulling in a storage
/// plugin). Back it with `shared_preferences`, a file, Hive, etc., then pass
/// it to `FNetworkInspector.initialize(mockPersistence: ...)`.
///
/// ```dart
/// class PrefsMockStore implements FMockPersistence {
///   @override
///   Future<String?> load() async =>
///       (await SharedPreferences.getInstance()).getString('fnetwork_mocks');
///
///   @override
///   Future<void> save(String json) async =>
///       (await SharedPreferences.getInstance())
///           .setString('fnetwork_mocks', json);
/// }
/// ```
abstract class FMockPersistence {
  /// Returns the previously saved payload (the string produced by
  /// `FMockStore.exportJson()`), or null when nothing is stored.
  Future<String?> load();

  /// Persists [json] (the output of `FMockStore.exportJson()`). Called,
  /// debounced, whenever rules or scenarios change.
  Future<void> save(String json);
}
