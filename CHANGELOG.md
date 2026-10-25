# Changelog

## 1.0.0 - 2026-10-25

- Initial release.
- `PrivatusAnalytics` core (Foundation only): `Privatus.tag`, `Privatus.eventAttributes` and `Privatus.eventData`
  for custom events, `Privatus.clickAttribute` and `Privatus.clickData` for click map names, and
  `Privatus.pagePropsJSON` for page props.
- `PrivatusConfiguration` with site id, script host, modules, excluded paths, domains, single-page app mode,
  manual mode, extra attributes, page props and the queue stub.
- `PrivatusAnalyticsVapor`: `app.privatusAnalytics.configuration`, `requestProps` and `nonce` closures,
  `req.privatusAnalytics.tag()`, and `PrivatusAnalyticsMiddleware` for auto inject (off by default).
- Leaf tags `#privatusAnalytics()`, `#privatusEvent(...)` and `#privatusClick(...)`.
- The tag prints only when `app.environment == .production`, unless `enabled` is set.
