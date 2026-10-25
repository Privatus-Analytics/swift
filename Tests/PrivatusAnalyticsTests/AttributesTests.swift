import PrivatusAnalytics
import Testing

@Suite final class AttributesTests {
  func value(_ attributes: [PrivatusAttribute], _ name: String) -> String? {
    attributes.first(where: { $0.name == name })?.value
  }

  @Test func anEventBecomesDataAttributes() {
    #expect(
      Privatus.eventAttributes("Export CSV", ["format": "csv", "source": "toolbar"])
        == #"data-privatus-event="Export CSV" data-privatus-prop-format="csv" data-privatus-prop-source="toolbar""#)
  }

  @Test func theEventNameIsTrimmedAndCutTo120Characters() {
    #expect(value(Privatus.eventData("  Export CSV  "), "data-privatus-event") == "Export CSV")
    #expect(
      value(Privatus.eventData(String(repeating: "a", count: 200)), "data-privatus-event")
        == String(repeating: "a", count: 120))
  }

  @Test func anEmptyEventNameGivesNothing() {
    #expect(Privatus.eventData("   ", ["format": "csv"]) == [])
    #expect(Privatus.eventAttributes("") == "")
  }

  @Test func propKeysAreLowercasedCleanedAndCut() {
    let attributes = Privatus.eventData(
      "Saved", ["Report Type": "a", "x-y": "b", String(repeating: "K", count: 80): "c"])

    #expect(value(attributes, "data-privatus-prop-report_type") == "a")
    #expect(value(attributes, "data-privatus-prop-x_y") == "b")
    #expect(value(attributes, "data-privatus-prop-" + String(repeating: "k", count: 64)) == "c")
  }

  @Test func valuesBecomeTextAndNilValuesAreDropped() {
    let team: String? = nil
    let attributes = Privatus.eventData(
      "Saved",
      ["on": true, "off": false, "count": 3, "ratio": 1.5, "tags": ["a", "b"], "gone": nil, "team": team])

    #expect(
      ["on", "off", "count", "ratio", "tags"].map { value(attributes, "data-privatus-prop-\($0)") } == [
        "true", "false", "3", "1.5", "a,b",
      ])
    #expect(value(attributes, "data-privatus-prop-gone") == nil)
    #expect(value(attributes, "data-privatus-prop-team") == nil)
  }

  @Test func optionalVariablesWork() {
    let plan: String? = "pro"
    #expect(value(Privatus.eventData("Saved", ["plan": plan]), "data-privatus-prop-plan") == "pro")
  }

  @Test func valuesAreCutTo500CharactersAndAtMost30PropsAreKept() {
    let many = PrivatusProps(
      (1...40).map { (index: Int) -> (String, (any PrivatusValueConvertible)?) in ("p\(index)", "v") })

    #expect(Privatus.eventData("Saved", many).count == 31)
    #expect(
      value(Privatus.eventData("Saved", ["long": String(repeating: "x", count: 900)]), "data-privatus-prop-long")?
        .count == 500)
  }

  @Test func hTMLEscapesEveryValue() {
    #expect(
      Privatus.eventAttributes(#"Say "hi" <now>"#, ["note": "a&b'c"])
        == #"data-privatus-event="Say &quot;hi&quot; &lt;now&gt;" data-privatus-prop-note="a&amp;b&#39;c""#)
  }

  @Test func aValidClickNameBecomesADataAttribute() {
    #expect(Privatus.clickAttribute("pricing.cta") == #"data-privatus-click="pricing.cta""#)
    #expect(Privatus.clickData("a-b_c:d.1") == [PrivatusAttribute(name: "data-privatus-click", value: "a-b_c:d.1")])
    #expect(Privatus.isValidClickName(String(repeating: "x", count: 100)))
  }

  @Test func anInvalidClickNameGivesNothing() {
    for name in ["", "has space", String(repeating: "x", count: 101), "<b>", "café"] {
      #expect(Privatus.clickAttribute(name) == "", "\(name)")
      #expect(!(Privatus.isValidClickName(name)), "\(name)")
    }
  }

  @Test func propsMergeWithCleanKeysAndNilRemoves() {
    let merged = (["Plan": "pro", "role": "admin"] as PrivatusProps).merging(["role": nil, "tier": "gold"])

    #expect(merged.entries.map(\.key) == ["plan", "role", "tier"])
    #expect(Privatus.pagePropsJSON(merged) == #"{"plan":"pro","tier":"gold"}"#)
  }

  @Test func propsFromADictionaryAreSorted() {
    #expect(PrivatusProps(["b": 2, "a": 1]).entries.map(\.key) == ["a", "b"])
  }
}
