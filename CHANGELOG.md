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
- When the tag is off (not enabled, outside production by default, or no site id)
  and `queueStub` is on, `Privatus.tag`, `req.privatusAnalytics.tag()` and
  `#privatusAnalytics()` print only the queue stub (with the nonce), so
  `privatus.track` calls never fail. No tracker and no page props script print
  then, and `requestProps` does not run. The middleware still adds nothing.
- `#privatusAnalytics(pageProps, settings)`: a second dictionary changes settings
  (such as `enabled` and `queueStub`) for one page.
- Add the conformance example app in `example/` (Vapor and Leaf).
- README: a privacy policy paragraph you can paste.
