import Foundation
import PrivatusAnalytics
import Testing

@Suite final class PagePropsTests {
  func object(_ json: String?) throws -> [String: Any] {
    let data = try #require(json).data(using: .utf8)!
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  @Test func propsBecomeAJSONObject() {
    #expect(Privatus.pagePropsJSON(["plan": "pro", "role": "admin"]) == #"{"plan":"pro","role":"admin"}"#)
  }

  @Test func emptyPropsGiveNil() {
    #expect(Privatus.pagePropsJSON([:]) == nil)
    #expect(Privatus.pagePropsJSON(["gone": nil]) == nil)
    #expect(Privatus.pagePropsJSON(["nan": Double.nan]) == nil)
  }

  @Test func numbersBooleansAndListsKeepTheirJSONTypes() {
    let flags: [PrivatusValue] = ["a", "b", 3]
    #expect(
      Privatus.pagePropsJSON([
        "seats": 5, "ratio": 1.5, "beta": true, "old": false, "flags": PrivatusValue.list(flags),
        "names": ["x", nil, "y"] as [String?],
      ]) == #"{"seats":5,"ratio":1.5,"beta":true,"old":false,"flags":["a","b",3],"names":["x","y"]}"#)
  }

  @Test func keysAreCleanedLikeEventProps() {
    #expect(Privatus.pagePropsJSON(["App Version": "2.1"]) == #"{"app_version":"2.1"}"#)
  }

  @Test func limitsPropsListItemsAndValueLength() throws {
    let many = PrivatusProps(
      (1...40).map { (index: Int) -> (String, (any PrivatusValueConvertible)?) in ("p\(index)", index) })

    #expect(try object(Privatus.pagePropsJSON(many)).count == 30)
    #expect(
      try object(Privatus.pagePropsJSON(["list": (1...50).map(String.init)]))["list"].map { ($0 as! [Any]).count } == 30
    )
    #expect(
      try object(Privatus.pagePropsJSON(["long": String(repeating: "x", count: 900)]))["long"].map {
        ($0 as! String).count
      } == 500)
  }

  @Test func theJSONIsSafeInsideAScriptTag() {
    let json = Privatus.pagePropsJSON(["note": "</script><b>&\u{2028}\u{2029}\"\\\n"])

    #expect(json == #"{"note":"\u003c/script\u003e\u003cb\u003e\u0026\u2028\u2029\"\\\n"}"#)
  }
}
