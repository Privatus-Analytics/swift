import Foundation
import PrivatusAnalytics
import XCTest

final class PagePropsTests: XCTestCase {
  func object(_ json: String?) throws -> [String: Any] {
    let data = try XCTUnwrap(json).data(using: .utf8)!
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func testPropsBecomeAJSONObject() {
    XCTAssertEqual(Privatus.pagePropsJSON(["plan": "pro", "role": "admin"]), #"{"plan":"pro","role":"admin"}"#)
  }

  func testEmptyPropsGiveNil() {
    XCTAssertNil(Privatus.pagePropsJSON([:]))
    XCTAssertNil(Privatus.pagePropsJSON(["gone": nil]))
    XCTAssertNil(Privatus.pagePropsJSON(["nan": Double.nan]))
  }

  func testNumbersBooleansAndListsKeepTheirJSONTypes() {
    let flags: [PrivatusValue] = ["a", "b", 3]
    XCTAssertEqual(
      Privatus.pagePropsJSON([
        "seats": 5, "ratio": 1.5, "beta": true, "old": false, "flags": PrivatusValue.list(flags),
        "names": ["x", nil, "y"] as [String?],
      ]),
      #"{"seats":5,"ratio":1.5,"beta":true,"old":false,"flags":["a","b",3],"names":["x","y"]}"#)
  }

  func testKeysAreCleanedLikeEventProps() {
    XCTAssertEqual(Privatus.pagePropsJSON(["App Version": "2.1"]), #"{"app_version":"2.1"}"#)
  }

  func testLimitsPropsListItemsAndValueLength() throws {
    let many = PrivatusProps((1...40).map { ("p\($0)", $0 as (any PrivatusValueConvertible)?) })

    XCTAssertEqual(try object(Privatus.pagePropsJSON(many)).count, 30)
    XCTAssertEqual(
      try object(Privatus.pagePropsJSON(["list": (1...50).map(String.init)]))["list"].map { ($0 as! [Any]).count },
      30)
    XCTAssertEqual(
      try object(Privatus.pagePropsJSON(["long": String(repeating: "x", count: 900)]))["long"].map {
        ($0 as! String).count
      }, 500)
  }

  func testTheJSONIsSafeInsideAScriptTag() {
    let json = Privatus.pagePropsJSON(["note": "</script><b>&\u{2028}\u{2029}\"\\\n"])

    XCTAssertEqual(
      json, #"{"note":"\u003c/script\u003e\u003cb\u003e\u0026\u2028\u2029\"\\\n"}"#)
  }
}
