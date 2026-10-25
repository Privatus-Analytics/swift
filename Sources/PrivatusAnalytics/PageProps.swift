extension Privatus {
  static let maxListItems = 30

  /// Page props as a JSON object that is safe inside a `<script>`, or `nil` when
  /// there is nothing to send.
  ///
  /// Keys follow the same rules as event props. Numbers, `true` and `false` stay
  /// JSON numbers and booleans, and lists stay JSON arrays (up to 30 items).
  /// `<`, `>`, `&`, U+2028 and U+2029 are written as `\u003c` and so on.
  public static func pagePropsJSON(_ props: PrivatusProps) -> String? {
    let members = normalize(props).compactMap { key, value -> String? in
      guard let json = jsonValue(value) else { return nil }
      return "\(jsonString(key)):\(json)"
    }
    return members.isEmpty ? nil : "{\(members.joined(separator: ","))}"
  }

  static func jsonValue(_ value: PrivatusValue) -> String? {
    if case .list(let items) = value {
      return "[\(items.prefix(maxListItems).compactMap(jsonScalar).joined(separator: ","))]"
    }
    return jsonScalar(value)
  }

  static func jsonScalar(_ value: PrivatusValue) -> String? {
    switch value {
    case .bool(let flag): return flag ? "true" : "false"
    case .int(let number): return String(number)
    case .double(let number): return number.isFinite ? String(number) : nil
    case .string(let text): return jsonString(String(text.prefix(maxValue)))
    case .list: return jsonString(String(value.text.prefix(maxValue)))
    }
  }

  static func jsonString(_ text: String) -> String {
    var result = "\""
    for scalar in text.unicodeScalars {
      switch scalar {
      case "\"": result += "\\\""
      case "\\": result += "\\\\"
      case "\n": result += "\\n"
      case "\r": result += "\\r"
      case "\t": result += "\\t"
      case "\u{08}": result += "\\b"
      case "\u{0C}": result += "\\f"
      case "<", ">", "&", "\u{2028}", "\u{2029}":
        result += unicodeEscape(scalar.value)
      default:
        if scalar.value < 0x20 {
          result += unicodeEscape(scalar.value)
        } else {
          result.unicodeScalars.append(scalar)
        }
      }
    }
    return result + "\""
  }

  static func unicodeEscape(_ value: UInt32) -> String {
    let hex = String(value, radix: 16)
    return "\\u" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
  }
}
