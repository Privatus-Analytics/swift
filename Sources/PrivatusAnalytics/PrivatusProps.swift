/// Props for an event or a page, in the order you wrote them.
///
/// Write them as a dictionary literal. Values can be text, numbers, `true` or
/// `false`, lists, or optionals of those. A `nil` value is left out.
///
/// ```swift
/// let props: PrivatusProps = ["format": "csv", "rows": 120, "beta": true, "team": nil]
/// ```
///
/// Never put names, emails, user ids or anything that points to one person in props.
public struct PrivatusProps: Sendable, Equatable, ExpressibleByDictionaryLiteral {
  /// One key and its value. A `nil` value means "leave this prop out".
  public struct Entry: Sendable, Equatable {
    public var key: String
    public var value: PrivatusValue?

    public init(key: String, value: PrivatusValue?) {
      self.key = key
      self.value = value
    }
  }

  /// The props in the order they were given.
  public private(set) var entries: [Entry]

  public init() {
    entries = []
  }

  public init(dictionaryLiteral elements: (String, (any PrivatusValueConvertible)?)...) {
    entries = elements.map { Entry(key: $0.0, value: $0.1?.privatusValue) }
  }

  /// Props from a pair list, in that order.
  public init(_ pairs: [(String, (any PrivatusValueConvertible)?)]) {
    entries = pairs.map { Entry(key: $0.0, value: $0.1?.privatusValue) }
  }

  /// Props from a dictionary. Swift dictionaries have no order, so the keys are sorted.
  public init<Value: PrivatusValueConvertible>(_ dictionary: [String: Value]) {
    entries = dictionary.keys.sorted().map { Entry(key: $0, value: dictionary[$0]?.privatusValue) }
  }

  public var isEmpty: Bool { entries.isEmpty }

  /// The value for a key, or `nil`. Setting a value replaces the old one in place.
  public subscript(key: String) -> PrivatusValue? {
    get { entries.last(where: { $0.key == key })?.value ?? nil }
    set {
      if let index = entries.firstIndex(where: { $0.key == key }) {
        entries[index].value = newValue
      } else {
        entries.append(Entry(key: key, value: newValue))
      }
    }
  }

  /// These props with `other` laid on top. Keys are cleaned first, so `"Plan"` and
  /// `"plan"` are the same key. A `nil` value in `other` removes that prop.
  public func merging(_ other: PrivatusProps) -> PrivatusProps {
    var result = PrivatusProps()
    for entry in entries + other.entries {
      result[Privatus.normalizeKey(entry.key)] = entry.value
    }
    return result
  }
}
