import PrivatusAnalytics
import Testing

@Suite final class TagTests {
  let noEnvironment: [String: String] = [:]
  var config = PrivatusConfiguration(siteID: "pa_TEST123456", enabled: true)

  func render(_ configuration: PrivatusConfiguration? = nil, nonce: String? = nil, props: PrivatusProps = [:])
    -> String
  {
    Privatus.tag(configuration ?? config, nonce: nonce, props: props, environment: noEnvironment)
  }

  @Test func printsTheBasicSnippet() {
    #expect(render() == #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>"#)
  }

  @Test func printsNothingWithoutASiteID() {
    config.siteID = nil
    #expect(render() == "")
  }

  @Test func onlyProductionIsOnByDefault() {
    config.enabled = nil
    #expect(Privatus.tag(config, isProduction: false, environment: noEnvironment) == "")
    #expect(Privatus.tag(config, isProduction: true, environment: noEnvironment) != "")
  }

  @Test func enabledForcesTheTagOnOrOff() {
    config.enabled = false
    #expect(Privatus.tag(config, isProduction: true, environment: noEnvironment) == "")
    config.enabled = true
    #expect(config.isEnabled(isProduction: false))
  }

  @Test func siteIDAndScriptHostFallBackToTheEnvironment() {
    let environment = ["PRIVATUS_SITE_ID": "pa_FROMENV123", "PRIVATUS_SCRIPT_HOST": "https://stats.example.com/"]
    let blank = PrivatusConfiguration(enabled: true)

    #expect(blank.resolvedSiteID(environment: environment) == "pa_FROMENV123")
    #expect(
      Privatus.tag(blank, environment: environment)
        == #"<script defer src="https://stats.example.com/js/pa.js" data-site="pa_FROMENV123"></script>"#)
    #expect(config.resolvedSiteID(environment: environment) == "pa_TEST123456")
  }

  @Test func scriptHostDropsATrailingSlash() {
    #expect(config.resolvedScriptHost(environment: noEnvironment) == "https://privatusstats.com")
    config.scriptHost = "https://stats.example.com/"
    #expect(config.resolvedScriptHost(environment: noEnvironment) == "https://stats.example.com")
  }

  @Test func addsModulesAndExclusions() {
    config.modules = ["engage", "auto"]
    config.excludedPaths = ["/admin/*", "/preview/*"]
    let tag = render()

    #expect(tag.contains(#"data-modules="engage,auto""#))
    #expect(tag.contains(#"data-exclude="/admin/*,/preview/*""#))
  }

  @Test func anEmptyModulesListLoadsNone() {
    config.modules = []
    #expect(render().contains(#"data-modules="""#))
  }

  @Test func addsDomainsSPAModeAndManualMode() {
    config.domains = ["example.com, www.example.com"]
    config.spa = .hash
    config.manual = true
    let tag = render()

    #expect(tag.contains(#"data-domains="example.com,www.example.com""#))
    #expect(tag.contains(#"data-spa="hash""#))
    #expect(tag.contains(#"data-manual="true""#))
  }

  @Test func theAutoSPAModeIsNotPrinted() {
    config.spa = .auto
    #expect(!(render().contains("data-spa")))
  }

  @Test func escapesAttributeValues() {
    config.excludedPaths = [#"/a"b"#]
    #expect(render().contains(#"data-exclude="/a&quot;b""#))
  }

  @Test func addsExtraAttributesAndANonce() {
    config.extraAttributes = ["data-mask": "/orders/*->/orders/:id"]
    let tag = render(nonce: "abc123")

    #expect(tag.contains(#"data-mask="/orders/*-&gt;/orders/:id""#))
    #expect(tag.contains(#"nonce="abc123""#))
  }

  @Test func pagePropsPrintAnInlineScriptBeforeTheTag() {
    let html = render(props: ["plan": "pro", "role": "admin"])

    #expect(
      html == #"<script>window.privatusPageProps=function(){return {"plan":"pro","role":"admin"}}</script>"# + "\n"
        + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-props="privatusPageProps"></script>"#
    )
  }

  @Test func thePropsScriptGetsTheNonce() {
    #expect(render(nonce: "abc", props: ["plan": "pro"]).hasPrefix(#"<script nonce="abc">window.privatusPageProps="#))
  }

  @Test func emptyPropsPrintNoScript() {
    #expect(!(render(props: ["plan": nil]).contains("privatusPageProps")))
  }

  @Test func configuredPropsAreMergedWithPerCallProps() {
    config.props = ["plan": "pro", "role": "admin"]
    #expect(render().contains(#"{"plan":"pro","role":"admin"}"#))
    #expect(render(props: ["role": nil, "tier": "gold"]).contains(#"{"plan":"pro","tier":"gold"}"#))
  }

  @Test func queueStubPrintsTheOfficialStubFirst() {
    config.queueStub = true
    let parts = render(nonce: "abc", props: ["plan": "pro"]).components(separatedBy: "\n")

    #expect(parts[0] == #"<script nonce="abc">"# + Privatus.queueStub + "</script>")
    #expect(parts[1].contains("privatusPageProps"))
    #expect(parts[2].contains("/js/pa.js"))
  }

  @Test func theQueueStubIsTheOfficialOne() {
    #expect(
      Privatus.queueStub
        == "window.privatus=window.privatus||{q:[]};['track','pageview','props','optOut','optIn','ready']"
        + ".forEach(function(m){window.privatus[m]=window.privatus[m]||function(){window.privatus.q.push("
        + "[m,Array.prototype.slice.call(arguments)])}})")
  }

  @Test func noQueueStubByDefault() {
    #expect(!(render().contains("q:[]")))
  }
}
