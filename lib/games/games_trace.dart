/// Diagnostic switches for the games integration.
///
/// Its own file, and that is the whole point. `games_config_test.dart` bans
/// every `fromEnvironment` in `games_service.dart` outright - not by name,
/// because a name based version of that guard was evaded once already by a
/// second preview flag called something else. Putting a legitimate switch in
/// the guarded file would mean loosening a rule that has caught a real
/// mistake, so the switch moves instead of the rule.
///
/// Nothing here may invent state. These are read-only switches over logging.
library;

/// Whether the cloud save narrates what it did.
///
/// `--dart-define=TRACE_CLOUD_SAVE=true`, and off otherwise, so it can never
/// reach a shipped build by being left switched on.
///
/// A **release** build prints none of it either way: Dart's `print` does not
/// reach logcat there. Use `--profile`, which keeps the same application id
/// and so keeps Play Games working - unlike `--debug`, whose `.debug` suffix
/// does not match the OAuth credential and fails sign in with DEVELOPER_ERROR.
const bool kTraceCloudSave = bool.fromEnvironment('TRACE_CLOUD_SAVE');
