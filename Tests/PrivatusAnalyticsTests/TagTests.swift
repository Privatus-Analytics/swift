import PrivatusAnalytics
import XCTest

final class TagTests: XCTestCase {
  let noEnvironment: [String: String] = [:]
  var config = PrivatusConfiguration(siteID: "pa_TEST123456", enabled: true)

  func render(_ configuration: PrivatusConfiguration? = nil, nonce: String? = nil, props: PrivatusProps = [:])
    -> String
  {
    Privatus.tag(configuration ?? config, nonce: nonce, props: props, environment: noEnvironment)
  }

  func testPrintsTheBasicSnippet() {
    XCTAssertEqual(
      render(), #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>"#)
  }

  func testPrintsNothingWithoutASiteID() {
    config.siteID = nil
    XCTAssertEqual(render(), "")
  }

  func testOnlyProductionIsOnByDefault() {
    config.enabled = nil
    XCTAssertEqual(Privatus.tag(config, isProduction: false, environment: noEnvironment), "")
    XCTAssertNotEqual(Privatus.tag(config, isProduction: true, environment: noEnvironment), "")
  }

  func testEnabledForcesTheTagOnOrOff() {
    config.enabled = false
    XCTAssertEqual(Privatus.tag(config, isProduction: true, environment: noEnvironment), "")
    config.enabled = true
    XCTAssertTrue(config.isEnabled(isProduction: false))
  }

  func testSiteIDAndScriptHostFallBackToTheEnvironment() {
    let environment = ["PRIVATUS_SITE_ID": "pa_FROMENV123", "PRIVATUS_SCRIPT_HOST": "https://stats.example.com/"]
    let blank = PrivatusConfiguration(enabled: true)

    XCTAssertEqual(blank.resolvedSiteID(environment: environment), "pa_FROMENV123")
    XCTAssertEqual(
      Privatus.tag(blank, environment: environment),
      #"<script defer src="https://stats.example.com/js/pa.js" data-site="pa_FROMENV123"></script>"#)
    XCTAssertEqual(config.resolvedSiteID(environment: environment), "pa_TEST123456")
  }

  func testScriptHostDropsATrailingSlash() {
    XCTAssertEqual(config.resolvedScriptHost(environment: noEnvironment), "https://privatusstats.com")
    config.scriptHost = "https://stats.example.com/"
    XCTAssertEqual(config.resolvedScriptHost(environment: noEnvironment), "https://stats.example.com")
  }

  func testAddsModulesAndExclusions() {
    config.modules = ["engage", "auto"]
    config.excludedPaths = ["/admin/*", "/preview/*"]
    let tag = render()

    XCTAssertTrue(tag.contains(#"data-modules="engage,auto""#))
    XCTAssertTrue(tag.contains(#"data-exclude="/admin/*,/preview/*""#))
  }

  func testAnEmptyModulesListLoadsNone() {
    config.modules = []
    XCTAssertTrue(render().contains(#"data-modules="""#))
  }

  func testAddsDomainsSPAModeAndManualMode() {
    config.domains = ["example.com, www.example.com"]
    config.spa = .hash
    config.manual = true
    let tag = render()

    XCTAssertTrue(tag.contains(#"data-domains="example.com,www.example.com""#))
    XCTAssertTrue(tag.contains(#"data-spa="hash""#))
    XCTAssertTrue(tag.contains(#"data-manual="true""#))
  }

  func testTheAutoSPAModeIsNotPrinted() {
    config.spa = .auto
    XCTAssertFalse(render().contains("data-spa"))
  }

  func testEscapesAttributeValues() {
    config.excludedPaths = [#"/a"b"#]
    XCTAssertTrue(render().contains(#"data-exclude="/a&quot;b""#))
  }

  func testAddsExtraAttributesAndANonce() {
    config.extraAttributes = ["data-mask": "/orders/*->/orders/:id"]
    let tag = render(nonce: "abc123")

    XCTAssertTrue(tag.contains(#"data-mask="/orders/*-&gt;/orders/:id""#))
    XCTAssertTrue(tag.contains(#"nonce="abc123""#))
  }

  func testPagePropsPrintAnInlineScriptBeforeTheTag() {
    let html = render(props: ["plan": "pro", "role": "admin"])

    XCTAssertEqual(
      html,
      #"<script>window.privatusPageProps=function(){return {"plan":"pro","role":"admin"}}</script>"# + "\n"
        + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-props="privatusPageProps"></script>"#
    )
  }

  func testThePropsScriptGetsTheNonce() {
    XCTAssertTrue(
      render(nonce: "abc", props: ["plan": "pro"]).hasPrefix(#"<script nonce="abc">window.privatusPageProps="#))
  }

  func testEmptyPropsPrintNoScript() {
    XCTAssertFalse(render(props: ["plan": nil]).contains("privatusPageProps"))
  }

  func testConfiguredPropsAreMergedWithPerCallProps() {
    config.props = ["plan": "pro", "role": "admin"]
    XCTAssertTrue(render().contains(#"{"plan":"pro","role":"admin"}"#))
    XCTAssertTrue(render(props: ["role": nil, "tier": "gold"]).contains(#"{"plan":"pro","tier":"gold"}"#))
  }

  func testQueueStubPrintsTheOfficialStubFirst() {
    config.queueStub = true
    let parts = render(nonce: "abc", props: ["plan": "pro"]).components(separatedBy: "\n")

    XCTAssertEqual(parts[0], #"<script nonce="abc">"# + Privatus.queueStub + "</script>")
    XCTAssertTrue(parts[1].contains("privatusPageProps"))
    XCTAssertTrue(parts[2].contains("/js/pa.js"))
  }

  func testTheQueueStubIsTheOfficialOne() {
    XCTAssertEqual(
      Privatus.queueStub,
      "window.privatus=window.privatus||{q:[]};['track','pageview','props','optOut','optIn','ready']"
        + ".forEach(function(m){window.privatus[m]=window.privatus[m]||function(){window.privatus.q.push("
        + "[m,Array.prototype.slice.call(arguments)])}})")
  }

  func testNoQueueStubByDefault() {
    XCTAssertFalse(render().contains("q:[]"))
  }
}
