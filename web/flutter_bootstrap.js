{{flutter_js}}
{{flutter_build_config}}

// Load the latest deployed bundle directly. The app performs its own one-time
// cleanup of legacy Flutter service-worker caches in index.html.
_flutter.loader.load();
