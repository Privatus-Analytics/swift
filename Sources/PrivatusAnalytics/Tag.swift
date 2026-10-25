import Foundation

extension Privatus {
  /// The name of the page props function the tracker reads (`data-props`).
  public static let pagePropsFunction = "privatusPageProps"

  /// The official queue stub. It keeps `privatus.track` calls made before pa.js loads.
  public static let queueStub =
    "window.privatus=window.privatus||{q:[]};['track','pageview','props','optOut','optIn','ready']"
    + ".forEach(function(m){window.privatus[m]=window.privatus[m]||function(){window.privatus.q.push("
    + "[m,Array.prototype.slice.call(arguments)])}})"

  /// Whether a tag would print: there is a site id and the tag is on.
  public static func shouldRender(
    _ configuration: PrivatusConfiguration,
    isProduction: Bool = false,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    configuration.resolvedSiteID(environment: environment) != nil
      && configuration.isEnabled(isProduction: isProduction)
  }

  /// The Privatus Analytics script tag. Put it in the `<head>` of your pages.
  ///
  /// ```swift
  /// Privatus.tag(PrivatusConfiguration(siteID: "pa_YOURSITEID"), isProduction: true)
  /// // <script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID"></script>
  /// ```
  ///
  /// Returns `""` without a site id, or when the tag is off. The tag is on when
  /// `configuration.enabled` is `true`, or when it is `nil` and `isProduction` is `true`.
  ///
  /// - Parameters:
  ///   - nonce: Your Content Security Policy nonce, added to every script tag.
  ///   - props: Page props for this page, laid over `configuration.props`. A `nil` value removes one.
  ///   - environment: Where `PRIVATUS_SITE_ID` and `PRIVATUS_SCRIPT_HOST` are read from.
  public static func tag(
    _ configuration: PrivatusConfiguration,
    isProduction: Bool = false,
    nonce: String? = nil,
    props: PrivatusProps = [:],
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String {
    guard configuration.isEnabled(isProduction: isProduction),
      let siteID = configuration.resolvedSiteID(environment: environment)
    else { return "" }

    let propsJSON = pagePropsJSON(configuration.props.merging(props))
    var html: [String] = []
    if configuration.queueStub {
      html.append(inlineScript(queueStub, nonce: nonce))
    }
    if let propsJSON {
      html.append(inlineScript("window.\(pagePropsFunction)=function(){return \(propsJSON)}", nonce: nonce))
    }

    var attributes = trackerAttributes(
      configuration, siteID: siteID, scriptHost: configuration.resolvedScriptHost(environment: environment))
    if let nonce { attributes.append(PrivatusAttribute(name: "nonce", value: nonce)) }
    if propsJSON != nil { attributes.append(PrivatusAttribute(name: "data-props", value: pagePropsFunction)) }
    html.append("<script defer \(Privatus.html(attributes))></script>")
    return html.joined(separator: "\n")
  }

  static func trackerAttributes(
    _ configuration: PrivatusConfiguration, siteID: String, scriptHost: String
  ) -> [PrivatusAttribute] {
    var attributes = [
      PrivatusAttribute(name: "src", value: "\(scriptHost)/js/pa.js"),
      PrivatusAttribute(name: "data-site", value: siteID),
    ]
    // nil keeps the tracker default. An empty modules list loads none.
    if let modules = list(configuration.modules) {
      attributes.append(PrivatusAttribute(name: "data-modules", value: modules.joined(separator: ",")))
    }
    if let paths = list(configuration.excludedPaths), !paths.isEmpty {
      attributes.append(PrivatusAttribute(name: "data-exclude", value: paths.joined(separator: ",")))
    }
    if let domains = list(configuration.domains), !domains.isEmpty {
      attributes.append(PrivatusAttribute(name: "data-domains", value: domains.joined(separator: ",")))
    }
    if let spa = configuration.spa, spa != .auto {
      attributes.append(PrivatusAttribute(name: "data-spa", value: spa.rawValue))
    }
    if configuration.manual {
      attributes.append(PrivatusAttribute(name: "data-manual", value: "true"))
    }
    for name in configuration.extraAttributes.keys.sorted() {
      let value = configuration.extraAttributes[name]!
      if let index = attributes.firstIndex(where: { $0.name == name }) {
        attributes[index].value = value
      } else {
        attributes.append(PrivatusAttribute(name: name, value: value))
      }
    }
    return attributes
  }

  static func inlineScript(_ code: String, nonce: String?) -> String {
    let opening = nonce.map { "<script nonce=\"\(escapeHTML($0))\">" } ?? "<script>"
    return "\(opening)\(code)</script>"
  }

  /// `nil` stays `nil`. Anything else becomes clean items, split on commas.
  static func list(_ values: [String]?) -> [String]? {
    values?.flatMap { $0.split(separator: ",", omittingEmptySubsequences: false) }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
