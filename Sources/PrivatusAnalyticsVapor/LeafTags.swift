import Leaf
import Vapor

extension PrivatusAnalyticsApplication {
  /// Adds the Leaf tags `#privatusAnalytics()`, `#privatusEvent(...)` and `#privatusClick(...)`.
  ///
  /// It is the same as:
  ///
  /// ```swift
  /// app.leaf.tags["privatusAnalytics"] = PrivatusAnalyticsLeafTag()
  /// app.leaf.tags["privatusEvent"] = PrivatusEventLeafTag()
  /// app.leaf.tags["privatusClick"] = PrivatusClickLeafTag()
  /// ```
  public func useLeafTags() {
    application.leaf.tags["privatusAnalytics"] = PrivatusAnalyticsLeafTag()
    application.leaf.tags["privatusEvent"] = PrivatusEventLeafTag()
    application.leaf.tags["privatusClick"] = PrivatusClickLeafTag()
  }
}

/// `#privatusAnalytics()` prints the script tag. Put it in the `<head>` of your layout.
///
/// Pass a dictionary from your context to set page props for one page:
/// `#privatusAnalytics(pageProps)`. A second dictionary changes settings for
/// one page: `#privatusAnalytics(pageProps, settings)`, with any of the keys
/// `enabled`, `queueStub`, `siteID`, `scriptHost`, `modules`, `excludedPaths`,
/// `domains`, `spa` and `manual`.
public struct PrivatusAnalyticsLeafTag: UnsafeUnescapedLeafTag {
  public init() {}

  public func render(_ ctx: LeafContext) throws -> LeafData {
    guard let application = ctx.request?.application ?? ctx.application else {
      throw Abort(
        .internalServerError,
        reason: "#privatusAnalytics() needs a Vapor app. Render the view with req.view or app.view.")
    }
    var props = PrivatusProps()
    if let first = ctx.parameters.first, let dictionary = first.dictionary {
      props = PrivatusProps(leaf: dictionary)
    }
    let settings = ctx.parameters.count > 1 ? ctx.parameters[1].dictionary ?? [:] : [:]
    return .string(
      application.privatusAnalytics.tag(for: ctx.request, props: props) { Self.apply(settings, to: &$0) })
  }

  static func apply(_ settings: [String: LeafData], to configuration: inout PrivatusConfiguration) {
    func strings(_ key: String) -> [String]? {
      guard let value = settings[key], !value.isNil else { return nil }
      return value.array?.compactMap(\.string) ?? value.string.map { [$0] }
    }
    if let value = settings["enabled"], !value.isNil { configuration.enabled = value.bool }
    if let value = settings["queueStub"]?.bool { configuration.queueStub = value }
    if let value = settings["manual"]?.bool { configuration.manual = value }
    if let value = settings["siteID"]?.string { configuration.siteID = value }
    if let value = settings["scriptHost"]?.string { configuration.scriptHost = value }
    if let value = settings["spa"]?.string { configuration.spa = PrivatusSPAMode(rawValue: value) }
    if let value = strings("modules") { configuration.modules = value }
    if let value = strings("excludedPaths") { configuration.excludedPaths = value }
    if let value = strings("domains") { configuration.domains = value }
  }
}

/// `#privatusEvent("Export CSV", "format", "csv")` prints the attributes for a custom event.
///
/// After the name come key and value pairs. You can also pass one dictionary
/// from your context: `#privatusEvent("Export CSV", exportProps)`.
/// On a `<form>` the event is sent when the form is submitted.
public struct PrivatusEventLeafTag: UnsafeUnescapedLeafTag {
  public init() {}

  public func render(_ ctx: LeafContext) throws -> LeafData {
    guard let name = ctx.parameters.first?.string else {
      throw Abort(
        .internalServerError, reason: "#privatusEvent needs an event name, like #privatusEvent(\"Export CSV\").")
    }
    let rest = Array(ctx.parameters.dropFirst())
    var props = PrivatusProps()
    if rest.count == 1, let dictionary = rest[0].dictionary {
      props = PrivatusProps(leaf: dictionary)
    } else {
      guard rest.count.isMultiple(of: 2) else {
        throw Abort(
          .internalServerError,
          reason:
            "#privatusEvent needs a value for every prop key, like #privatusEvent(\"Export CSV\", \"format\", \"csv\")."
        )
      }
      for index in stride(from: 0, to: rest.count, by: 2) {
        guard let key = rest[index].string else { continue }
        props[key] = rest[index + 1].privatusValue
      }
    }
    return .string(Privatus.eventAttributes(name, props))
  }
}

/// `#privatusClick("pricing.cta")` prints the click map name attribute.
///
/// A name may use letters, digits and `_ . : -`, up to 100 characters. Anything
/// else prints nothing, and outside production a warning goes to the log.
public struct PrivatusClickLeafTag: UnsafeUnescapedLeafTag {
  public init() {}

  public func render(_ ctx: LeafContext) throws -> LeafData {
    let name = ctx.parameters.first?.string ?? ""
    let html = Privatus.clickAttribute(name)
    if html.isEmpty, let application = ctx.request?.application ?? ctx.application,
      application.environment != .production
    {
      (ctx.request?.logger ?? application.logger).warning(
        "[privatus-analytics] click map name \"\(name)\" is not valid. Use letters, digits and _ . : - only, at most 100 characters. Nothing was printed."
      )
    }
    return .string(html)
  }
}

extension PrivatusProps {
  init(leaf dictionary: [String: LeafData]) {
    self.init(dictionary.keys.sorted().map { ($0, dictionary[$0]?.privatusValue) })
  }
}

extension LeafData: PrivatusValueConvertible {
  /// The Leaf value as a prop value. `nil` for nil and for dictionaries.
  public var privatusValue: PrivatusValue? {
    if isNil { return nil }
    switch celf {
    case .bool: return bool.map(PrivatusValue.bool)
    case .int: return int.map(PrivatusValue.int)
    case .double: return double.map(PrivatusValue.double)
    case .string: return string.map(PrivatusValue.string)
    case .array: return array.map { .list($0.compactMap(\.privatusValue)) }
    default: return nil
    }
  }
}
