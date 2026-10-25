import Foundation

/// One HTML attribute: a name and its value (not yet escaped).
public struct PrivatusAttribute: Sendable, Equatable {
  public var name: String
  public var value: String

  public init(name: String, value: String) {
    self.name = name
    self.value = value
  }
}

/// The Privatus Analytics helpers. They only build HTML text. They never send anything.
public enum Privatus {
  /// The package version.
  public static let version = "1.0.0"

  static let maxName = 120
  static let maxKey = 64
  static let maxProps = 30
  static let maxValue = 500
  static let maxClickName = 100

  // MARK: Custom events

  /// The attributes for a custom event, in order. Empty for an empty name.
  ///
  /// ```swift
  /// Privatus.eventData("Export CSV", ["format": "csv"])
  /// // [data-privatus-event="Export CSV", data-privatus-prop-format="csv"]
  /// ```
  ///
  /// Use this with HTML builders such as Elementary or Plot. On a `<form>` the
  /// event is sent when the form is submitted.
  public static func eventData(_ name: String, _ props: PrivatusProps = [:]) -> [PrivatusAttribute] {
    let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxName))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }

    var attributes = [PrivatusAttribute(name: "data-privatus-event", value: trimmed)]
    for (key, value) in normalize(props) {
      attributes.append(
        PrivatusAttribute(name: "data-privatus-prop-\(key)", value: String(value.text.prefix(maxValue))))
    }
    return attributes
  }

  /// The attributes for a custom event as escaped HTML, ready to put inside a tag:
  ///
  /// ```swift
  /// "<button \(Privatus.eventAttributes("Export CSV", ["format": "csv"]))>Export</button>"
  /// ```
  ///
  /// Returns `""` for an empty name. The attributes print even when the tag is
  /// off, so your pages look the same in development and production.
  public static func eventAttributes(_ name: String, _ props: PrivatusProps = [:]) -> String {
    html(eventData(name, props))
  }

  // MARK: Click maps

  /// Whether a click map name is valid: letters, digits and `_ . : -`, 1 to 100 characters.
  public static func isValidClickName(_ name: String) -> Bool {
    let bytes = Array(name.utf8)
    guard (1...maxClickName).contains(bytes.count) else { return false }
    return bytes.allSatisfy { byte in
      switch byte {
      case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
        UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "_"), UInt8(ascii: "."),
        UInt8(ascii: ":"), UInt8(ascii: "-"):
        return true
      default:
        return false
      }
    }
  }

  /// The click map name attribute, or an empty list when the name is not valid.
  public static func clickData(_ name: String) -> [PrivatusAttribute] {
    isValidClickName(name) ? [PrivatusAttribute(name: "data-privatus-click", value: name)] : []
  }

  /// The click map name attribute as HTML, for example `data-privatus-click="pricing.cta"`.
  /// Returns `""` when the name is not valid.
  public static func clickAttribute(_ name: String) -> String {
    html(clickData(name))
  }

  // MARK: HTML

  /// Turns attributes into HTML text, with every value escaped.
  public static func html(_ attributes: [PrivatusAttribute]) -> String {
    attributes.map { "\($0.name)=\"\(escapeHTML($0.value))\"" }.joined(separator: " ")
  }

  /// Escapes `& < > " '` for HTML.
  public static func escapeHTML(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.utf8.count)
    for character in text {
      switch character {
      case "&": result += "&amp;"
      case "<": result += "&lt;"
      case ">": result += "&gt;"
      case "\"": result += "&quot;"
      case "'": result += "&#39;"
      default: result.append(character)
      }
    }
    return result
  }

  // MARK: Keys

  /// Lowercases a prop key, swaps anything outside `a-z 0-9 _` for `_` and cuts it to 64 characters.
  public static func normalizeKey(_ key: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in key.lowercased().unicodeScalars {
      if result.count == maxKey { break }
      switch scalar {
      case "a"..."z", "0"..."9", "_": result.append(scalar)
      default: result.append("_")
      }
    }
    return String(result)
  }

  /// Clean keys, no `nil` values, at most 30 props. A repeated key keeps its first place.
  static func normalize(_ props: PrivatusProps) -> [(String, PrivatusValue)] {
    var keys: [String] = []
    var values: [String: PrivatusValue] = [:]
    for entry in props.entries {
      let key = normalizeKey(entry.key)
      guard !key.isEmpty, let value = entry.value else { continue }
      if values[key] == nil { keys.append(key) }
      values[key] = value
    }
    return keys.prefix(maxProps).map { ($0, values[$0]!) }
  }
}
