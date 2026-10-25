import Foundation

/// How the tracker follows page changes in a single-page app.
public enum PrivatusSPAMode: String, Sendable, CaseIterable {
  case auto
  case history
  case hash
  case off
}

/// Settings for the tracking script. Every setting is optional except the site id.
///
/// It is a plain value, so to change a setting for one page, copy it and change the copy.
public struct PrivatusConfiguration: Sendable, Equatable {
  /// Where `/js/pa.js` is served when nothing else is set.
  public static let defaultScriptHost = "https://privatusstats.com"

  /// The site id (starts with `pa_`). Falls back to the `PRIVATUS_SITE_ID` environment variable.
  public var siteID: String?
  /// Origin that serves `/js/pa.js`. Falls back to `PRIVATUS_SCRIPT_HOST`, then `https://privatusstats.com`.
  public var scriptHost: String?
  /// Tracker modules to load (`data-modules`), for example `["engage", "auto"]`.
  /// `nil` keeps the tracker default. `[]` loads none.
  public var modules: [String]?
  /// Path globs the tracker never counts (`data-exclude`), for example `["/admin/*"]`.
  public var excludedPaths: [String]
  /// Hostnames to count (`data-domains`). `nil` counts every host.
  public var domains: [String]?
  /// Single-page app mode (`data-spa`). `nil` and `.auto` keep the tracker default.
  public var spa: PrivatusSPAMode?
  /// `true` turns off the automatic pageview (`data-manual`).
  public var manual: Bool
  /// `true` or `false` forces the tag on or off. `nil` turns it on in production only.
  public var enabled: Bool?
  /// `true` lets the middleware add the tag to the head of HTML responses.
  public var autoInject: Bool
  /// Any other `data-*` attribute, for example `["data-mask": "/orders/*->/orders/:id"]`.
  /// They print sorted by name.
  public var extraAttributes: [String: String]
  /// Page props sent with every pageview and event, for example `["plan": "pro"]`.
  /// Never put names, emails, user ids or anything else that points to one person here.
  public var props: PrivatusProps
  /// `true` prints the tracker's queue stub first, so `privatus.track` works before pa.js loads.
  public var queueStub: Bool

  public init(
    siteID: String? = nil,
    scriptHost: String? = nil,
    modules: [String]? = nil,
    excludedPaths: [String] = [],
    domains: [String]? = nil,
    spa: PrivatusSPAMode? = nil,
    manual: Bool = false,
    enabled: Bool? = nil,
    autoInject: Bool = false,
    extraAttributes: [String: String] = [:],
    props: PrivatusProps = [:],
    queueStub: Bool = false
  ) {
    self.siteID = siteID
    self.scriptHost = scriptHost
    self.modules = modules
    self.excludedPaths = excludedPaths
    self.domains = domains
    self.spa = spa
    self.manual = manual
    self.enabled = enabled
    self.autoInject = autoInject
    self.extraAttributes = extraAttributes
    self.props = props
    self.queueStub = queueStub
  }

  /// The site id to print: `siteID`, else `PRIVATUS_SITE_ID`, else `nil`.
  public func resolvedSiteID(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    var value = (siteID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty {
      value = (environment["PRIVATUS_SITE_ID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return value.isEmpty ? nil : value
  }

  /// The script host to use, without a trailing slash.
  public func resolvedScriptHost(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String {
    var value = (scriptHost ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty {
      value = (environment["PRIVATUS_SCRIPT_HOST"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if value.isEmpty { value = Self.defaultScriptHost }
    if value.hasSuffix("/") { value.removeLast() }
    return value
  }

  /// Whether the tag should print: `enabled` when it is set, else only in production.
  public func isEnabled(isProduction: Bool) -> Bool {
    enabled ?? isProduction
  }
}
