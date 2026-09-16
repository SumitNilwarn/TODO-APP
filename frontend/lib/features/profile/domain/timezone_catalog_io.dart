import 'timezone_catalog.dart';

/// IO/VM implementation: no `Intl.supportedValuesOf`, so the curated catalog
/// is the source of truth.
Future<List<String>> loadTimezoneCandidates() async =>
    List.unmodifiable(curatedTimezoneCatalog);
