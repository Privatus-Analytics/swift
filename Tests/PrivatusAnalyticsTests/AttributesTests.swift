import PrivatusAnalytics
import XCTest

final class AttributesTests: XCTestCase {
  func value(_ attributes: [PrivatusAttribute], _ name: String) -> String? {
    attributes.first(where: { $0.name == name })?.value
  }

  func testAnEventBecomesDataAttributes() {
    XCTAssertEqual(
      Privatus.eventAttributes("Export CSV", ["format": "csv", "source": "toolbar"]),
      #"data-privatus-event="Export CSV" data-privatus-prop-format="csv" data-privatus-prop-source="toolbar""#
    )
  }

  func testTheEventNameIsTrimmedAndCutTo120Characters() {
    XCTAssertEqual(value(Privatus.eventData("  Export CSV  "), "data-privatus-event"), "Export CSV")
    XCTAssertEqual(
      value(Privatus.eventData(String(repeating: "a", count: 200)), "data-privatus-event"),
      String(repeating: "a", count: 120))
  }

  func testAnEmptyEventNameGivesNothing() {
    XCTAssertEqual(Privatus.eventData("   ", ["format": "csv"]), [])
    XCTAssertEqual(Privatus.eventAttributes(""), "")
  }

  func testPropKeysAreLowercasedCleanedAndCut() {
    let attributes = Privatus.eventData(
      "Saved", ["Report Type": "a", "x-y": "b", String(repeating: "K", count: 80): "c"])

    XCTAssertEqual(value(attributes, "data-privatus-prop-report_type"), "a")
    XCTAssertEqual(value(attributes, "data-privatus-prop-x_y"), "b")
    XCTAssertEqual(value(attributes, "data-privatus-prop-" + String(repeating: "k", count: 64)), "c")
  }

  func testValuesBecomeTextAndNilValuesAreDropped() {
    let team: String? = nil
    let attributes = Privatus.eventData(
      "Saved",
      ["on": true, "off": false, "count": 3, "ratio": 1.5, "tags": ["a", "b"], "gone": nil, "team": team])

    XCTAssertEqual(
      ["on", "off", "count", "ratio", "tags"].map { value(attributes, "data-privatus-prop-\($0)") },
      ["true", "false", "3", "1.5", "a,b"])
    XCTAssertNil(value(attributes, "data-privatus-prop-gone"))
    XCTAssertNil(value(attributes, "data-privatus-prop-team"))
  }

  func testOptionalVariablesWork() {
    let plan: String? = "pro"
    XCTAssertEqual(value(Privatus.eventData("Saved", ["plan": plan]), "data-privatus-prop-plan"), "pro")
  }

  func testValuesAreCutTo500CharactersAndAtMost30PropsAreKept() {
    let many = PrivatusProps((1...40).map { ("p\($0)", "v" as (any PrivatusValueConvertible)?) })

    XCTAssertEqual(Privatus.eventData("Saved", many).count, 31)
    XCTAssertEqual(
      value(Privatus.eventData("Saved", ["long": String(repeating: "x", count: 900)]), "data-privatus-prop-long")?
        .count, 500)
  }

  func testHTMLEscapesEveryValue() {
    XCTAssertEqual(
      Privatus.eventAttributes(#"Say "hi" <now>"#, ["note": "a&b'c"]),
      #"data-privatus-event="Say &quot;hi&quot; &lt;now&gt;" data-privatus-prop-note="a&amp;b&#39;c""#)
  }

  func testAValidClickNameBecomesADataAttribute() {
    XCTAssertEqual(Privatus.clickAttribute("pricing.cta"), #"data-privatus-click="pricing.cta""#)
    XCTAssertEqual(
      Privatus.clickData("a-b_c:d.1"), [PrivatusAttribute(name: "data-privatus-click", value: "a-b_c:d.1")])
    XCTAssertTrue(Privatus.isValidClickName(String(repeating: "x", count: 100)))
  }

  func testAnInvalidClickNameGivesNothing() {
    for name in ["", "has space", String(repeating: "x", count: 101), "<b>", "café"] {
      XCTAssertEqual(Privatus.clickAttribute(name), "", name)
      XCTAssertFalse(Privatus.isValidClickName(name), name)
    }
  }

  func testPropsMergeWithCleanKeysAndNilRemoves() {
    let merged = (["Plan": "pro", "role": "admin"] as PrivatusProps).merging(["role": nil, "tier": "gold"])

    XCTAssertEqual(merged.entries.map(\.key), ["plan", "role", "tier"])
    XCTAssertEqual(Privatus.pagePropsJSON(merged), #"{"plan":"pro","tier":"gold"}"#)
  }

  func testPropsFromADictionaryAreSorted() {
    XCTAssertEqual(PrivatusProps(["b": 2, "a": 1]).entries.map(\.key), ["a", "b"])
  }
}
