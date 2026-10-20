// PostgREST's Dart client sends these headers even for ordinary table reads.
// Browsers must be able to preflight them before authenticated requests run.
export function createApiCorsOptions(origins, { log = console } = {}) {
  const allowed = new Set(origins.map(value => value.trim().toLowerCase().replace(/\/+$/, '')));
  return {
    origin(origin, callback) {
      if (!origin || allowed.has(origin.trim().toLowerCase().replace(/\/+$/, ''))) {
        return callback(null, true);
      }
      log.warn('CORS blocked an unlisted origin.');
      return callback(new Error('Origin not allowed by CORS.'));
    },
    credentials: true,
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
      'Content-Type', 'Authorization', 'Accept', 'X-Client-Info', 'Prefer',
      'Accept-Profile', 'Content-Profile', 'Range', 'Range-Unit',
    ],
    exposedHeaders: ['Content-Range', 'Range-Unit', 'Preference-Applied'],
    optionsSuccessStatus: 200,
  };
}
