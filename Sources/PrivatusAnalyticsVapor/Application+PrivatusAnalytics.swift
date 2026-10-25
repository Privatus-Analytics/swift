@_exported import PrivatusAnalytics
import Vapor

extension Application {
  /// Privatus Analytics settings and helpers for this app.
  ///
  /// ```swift
  /// app.privatusAnalytics.configuration.siteID = "pa_YOURSITEID"
  /// ```
  public var privatusAnalytics: PrivatusAnalyticsApplication {
    PrivatusAnalyticsApplication(application: self)
  }
}

/// Privatus Analytics for one Vapor app. Get it with `app.privatusAnalytics`.
public struct PrivatusAnalyticsApplication {
  let application: Application

  struct Settings: Sendable {
    var configuration = PrivatusConfiguration()
    var requestProps: (@Sendable (Request) -> PrivatusProps)?
    var nonce: (@Sendable (Request) -> String?)?
  }

  struct SettingsKey: StorageKey {
    typealias Value = Settings
  }

  var settings: Settings {
    get { application.storage[SettingsKey.self] ?? Settings() }
    nonmutating set { application.storage[SettingsKey.self] = newValue }
  }

  /// The settings for the tracking script. Set them when the app starts, in `configure.swift`.
  public var configuration: PrivatusConfiguration {
    get { settings.configuration }
    nonmutating set { settings.configuration = newValue }
  }

  /// Page props worked out for each request, laid over `configuration.props`.
  ///
  /// ```swift
  /// app.privatusAnalytics.requestProps = { req in
  ///   ["plan": req.auth.get(User.self)?.plan, "app_version": "2.4"]
  /// }
  /// ```
  ///
  /// It only runs when the tag prints. Never put names, emails, user ids or
  /// anything else that points to one person here.
  public var requestProps: (@Sendable (Request) -> PrivatusProps)? {
    get { settings.requestProps }
    nonmutating set { settings.requestProps = newValue }
  }

  /// Your Content Security Policy nonce for a request, if your app uses one.
  /// Vapor has no nonce of its own, so tell the package where yours is.
  ///
  /// ```swift
  /// app.privatusAnalytics.nonce = { req in req.storage[CSPNonceKey.self] }
  /// ```
  public var nonce: (@Sendable (Request) -> String?)? {
    get { settings.nonce }
    nonmutating set { settings.nonce = newValue }
  }

  /// Whether the app runs in production (`app.environment == .production`).
  public var isProduction: Bool {
    application.environment == .production
  }

  /// Whether the tag prints: there is a site id, and `configuration.enabled` is
  /// `true`, or it is `nil` and the app runs in production.
  public var isEnabled: Bool {
    Privatus.shouldRender(configuration, isProduction: isProduction)
  }

  /// The script tag for a request. When the tag is off, only the queue stub
  /// (if `queueStub` is on) or `""`.
  ///
  /// - Parameters:
  ///   - request: Used for `requestProps` and `nonce`. Without it, only the configured props print.
  ///   - props: Page props for this page, laid over the others. A `nil` value removes one.
  ///   - update: Changes settings for this call only, for example `{ $0.modules = ["engage", "auto"] }`.
  public func tag(
    for request: Request? = nil,
    props: PrivatusProps = [:],
    update: (inout PrivatusConfiguration) -> Void = { _ in }
  ) -> String {
    var configuration = self.configuration
    update(&configuration)
    guard Privatus.shouldRender(configuration, isProduction: isProduction) else {
      // Off: only the queue stub (when on). requestProps does not run.
      guard configuration.queueStub else { return "" }
      return Privatus.tag(configuration, isProduction: isProduction, nonce: request.flatMap { self.nonce?($0) })
    }

    var allProps = PrivatusProps()
    var nonce: String?
    if let request {
      if let requestProps { allProps = requestProps(request) }
      nonce = self.nonce?(request)
    }
    return Privatus.tag(
      configuration, isProduction: isProduction, nonce: nonce, props: allProps.merging(props))
  }

  /// Turns on auto inject and adds ``PrivatusAnalyticsMiddleware`` to the app.
  ///
  /// The middleware adds the tag just before `</head>` in HTML responses.
  public func useAutoInject() {
    configuration.autoInject = true
    application.middleware.use(PrivatusAnalyticsMiddleware())
  }
}

extension Request {
  /// Privatus Analytics helpers for this request.
  public var privatusAnalytics: PrivatusAnalyticsRequest {
    PrivatusAnalyticsRequest(request: self)
  }
}

/// Privatus Analytics for one request. Get it with `req.privatusAnalytics`.
public struct PrivatusAnalyticsRequest {
  let request: Request

  /// The script tag for this request, with its page props and nonce. When the
  /// tag is off, only the queue stub (if `queueStub` is on) or `""`.
  public func tag(
    props: PrivatusProps = [:],
    update: (inout PrivatusConfiguration) -> Void = { _ in }
  ) -> String {
    request.application.privatusAnalytics.tag(for: request, props: props, update: update)
  }
}
