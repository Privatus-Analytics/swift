/// One prop value: text, a whole number, a decimal number, true or false, or a list.
///
/// You rarely build one yourself. Plain Swift values (`String`, `Int`, `Double`,
/// `Bool`, arrays of them and optionals of them) turn into a `PrivatusValue` for you.
public enum PrivatusValue: Sendable, Equatable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case list([PrivatusValue])

  /// The value as text, the way event props send it:
  /// `true`, `false`, numbers as written, lists joined with commas.
  public var text: String {
    switch self {
    case .string(let value): return value
    case .int(let value): return String(value)
    case .double(let value): return String(value)
    case .bool(let value): return value ? "true" : "false"
    case .list(let items): return items.map(\.text).joined(separator: ",")
    }
  }
}

/// A Swift value that can be used as a prop value.
public protocol PrivatusValueConvertible {
  /// The prop value, or `nil` to leave the prop out.
  var privatusValue: PrivatusValue? { get }
}

extension PrivatusValue: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { self }
}

extension String: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .string(self) }
}

extension Substring: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .string(String(self)) }
}

extension Bool: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .bool(self) }
}

extension Int: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .int(self) }
}

extension Int32: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .int(Int(self)) }
}

extension Int64: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { Int(exactly: self).map(PrivatusValue.int) ?? .string(String(self)) }
}

extension UInt: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { Int(exactly: self).map(PrivatusValue.int) ?? .string(String(self)) }
}

extension UInt32: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { Int(exactly: self).map(PrivatusValue.int) ?? .string(String(self)) }
}

extension UInt64: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { Int(exactly: self).map(PrivatusValue.int) ?? .string(String(self)) }
}

extension Double: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .double(self) }
}

extension Float: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { .double(Double(self)) }
}

extension Optional: PrivatusValueConvertible where Wrapped: PrivatusValueConvertible {
  public var privatusValue: PrivatusValue? { self?.privatusValue }
}

extension Array: PrivatusValueConvertible where Element: PrivatusValueConvertible {
  /// A list. `nil` items are left out.
  public var privatusValue: PrivatusValue? { .list(compactMap(\.privatusValue)) }
}

extension PrivatusValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
  ExpressibleByBooleanLiteral
{
  public init(stringLiteral value: String) { self = .string(value) }
  public init(integerLiteral value: Int) { self = .int(value) }
  public init(floatLiteral value: Double) { self = .double(value) }
  public init(booleanLiteral value: Bool) { self = .bool(value) }
}
