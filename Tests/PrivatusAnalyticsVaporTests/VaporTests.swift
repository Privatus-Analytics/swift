import Leaf
import PrivatusAnalyticsVapor
import XCTVapor
import XCTest

struct NoContext: Encodable {}

struct PagePropsContext: Encodable {
  struct Props: Encodable {
    let section: String
    let seats: Int
  }
  let pageProps: Props
}

struct EventContext: Encodable {
  let props: [String: String]
}

final class VaporTests: XCTestCase {
  var app: Application!

  override func setUp() async throws {
    app = try await Application.make(.testing)
    app.privatusAnalytics.configuration = PrivatusConfiguration(siteID: "pa_TEST123456", enabled: true)
  }

  override func tearDown() async throws {
    try await app.asyncShutdown()
    app = nil
  }

  let page = "<html><head><title>Hi</title></head><body>Hello</body></html>"

  func html(_ text: String) -> Response {
    Response(status: .ok, headers: ["Content-Type": "text/html; charset=utf-8"], body: .init(string: text))
  }

  // MARK: Settings

  func testTheConfigurationIsStoredOnTheApp() {
    XCTAssertEqual(app.privatusAnalytics.configuration.siteID, "pa_TEST123456")
    app.privatusAnalytics.configuration.modules = ["engage"]
    XCTAssertEqual(app.privatusAnalytics.configuration.modules, ["engage"])
  }

  func testOnlyProductionIsOnByDefault() async throws {
    app.privatusAnalytics.configuration.enabled = nil
    XCTAssertFalse(app.privatusAnalytics.isEnabled)
    XCTAssertEqual(app.privatusAnalytics.tag(), "")

    let production = try await Application.make(.production)
    production.privatusAnalytics.configuration.siteID = "pa_TEST123456"
    XCTAssertTrue(production.privatusAnalytics.isEnabled)
    production.privatusAnalytics.configuration.enabled = false
    XCTAssertFalse(production.privatusAnalytics.isEnabled)
    try await production.asyncShutdown()
  }

  func testTheRequestTagUsesRequestPropsAndTheNonce() throws {
    app.privatusAnalytics.configuration.props = ["plan": "free", "role": "admin"]
    app.privatusAnalytics.requestProps = { req in ["plan": req.headers.first(name: "X-Plan")] }
    app.privatusAnalytics.nonce = { _ in "n0nce" }
    let request = Request(application: app, headers: ["X-Plan": "pro"], on: app.eventLoopGroup.next())

    let tag = request.privatusAnalytics.tag(props: ["role": nil]) { $0.modules = ["engage", "auto"] }

    XCTAssertEqual(
      tag,
      #"<script nonce="n0nce">window.privatusPageProps=function(){return {"plan":"pro"}}</script>"# + "\n"
        + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-modules="engage,auto" nonce="n0nce" data-props="privatusPageProps"></script>"#
    )
  }

  func testRequestPropsDoNotRunWhenTheTagIsOff() {
    app.privatusAnalytics.configuration.enabled = false
    app.privatusAnalytics.requestProps = { _ in fatalError("should not run") }
    let request = Request(application: app, on: app.eventLoopGroup.next())

    XCTAssertEqual(request.privatusAnalytics.tag(), "")
  }

  // MARK: Middleware

  func testAutoInjectAddsTheTagBeforeTheHead() async throws {
    app.privatusAnalytics.useAutoInject()
    app.get("page") { _ in self.html(self.page) }

    try await app.test(.GET, "page") { res async in
      let expected =
        #"<html><head><title>Hi</title><script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>"#
        + "\n</head><body>Hello</body></html>"
      XCTAssertEqual(res.body.string, expected)
      XCTAssertEqual(res.headers.first(name: .contentLength), String(expected.utf8.count))
    }
  }

  func testTheMiddlewareDoesNothingWithoutAutoInject() async throws {
    app.middleware.use(PrivatusAnalyticsMiddleware())
    app.get("page") { _ in self.html(self.page) }

    try await app.test(.GET, "page") { res async in
      XCTAssertEqual(res.body.string, self.page)
    }
  }

  func testTheMiddlewareSkipsResponsesItShouldNotTouch() async throws {
    app.privatusAnalytics.useAutoInject()
    app.get("missing") { _ in
      Response(status: .notFound, headers: ["Content-Type": "text/html"], body: .init(string: self.page))
    }
    app.get("json") { _ in
      Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(string: self.page))
    }
    app.get("gzip") { _ in
      Response(
        status: .ok, headers: ["Content-Type": "text/html", "Content-Encoding": "gzip"],
        body: .init(string: self.page))
    }
    app.get("tagged") { _ in self.html(#"<head><script src="/js/pa.js"></script></head>"#) }
    app.get("nohead") { _ in self.html("<p>Hi</p>") }
    app.get("page") { _ in self.html(self.page) }

    for path in ["missing", "json", "gzip", "tagged", "nohead"] {
      try await app.test(.GET, path) { res async in
        XCTAssertEqual(res.body.string.contains("pa_TEST123456"), false, path)
      }
    }
    try await app.test(.GET, "page", headers: ["X-Requested-With": "XMLHttpRequest"]) { res async in
      XCTAssertEqual(res.body.string, self.page)
    }
  }

  func testTheMiddlewareSkipsWhenTheTagIsOff() async throws {
    app.privatusAnalytics.useAutoInject()
    app.privatusAnalytics.configuration.enabled = nil
    app.get("page") { _ in self.html(self.page) }

    try await app.test(.GET, "page") { res async in
      XCTAssertEqual(res.body.string, self.page)
    }
  }

  // MARK: Leaf

  func renderLeaf(_ template: String, _ context: some Encodable = NoContext()) async throws -> String {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let views = root.appendingPathComponent("Resources/Views")
    try FileManager.default.createDirectory(at: views, withIntermediateDirectories: true)
    try template.write(to: views.appendingPathComponent("page.leaf"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: root) }

    app.directory = DirectoryConfiguration(workingDirectory: root.path + "/")
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = false
    app.privatusAnalytics.useLeafTags()
    app.get("leaf") { req async throws -> View in
      try await req.view.render("page", context)
    }
    var body = ""
    try await app.test(.GET, "leaf") { res async in
      body = res.body.string
    }
    return body
  }

  func testTheLeafTagPrintsTheScriptTag() async throws {
    app.privatusAnalytics.configuration.props = ["plan": "pro"]
    let body = try await renderLeaf("<head>#privatusAnalytics()</head>")

    XCTAssertEqual(
      body,
      #"<head><script>window.privatusPageProps=function(){return {"plan":"pro"}}</script>"# + "\n"
        + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-props="privatusPageProps"></script></head>"#
    )
  }

  func testTheLeafTagTakesPagePropsFromTheContext() async throws {
    let body = try await renderLeaf(
      "#privatusAnalytics(pageProps)", PagePropsContext(pageProps: .init(section: "billing", seats: 3)))

    XCTAssertTrue(body.contains(#"{"seats":3,"section":"billing"}"#), body)
  }

  func testTheLeafTagPrintsNothingWhenOff() async throws {
    app.privatusAnalytics.configuration.enabled = nil
    let body = try await renderLeaf("<head>#privatusAnalytics()</head>")
    XCTAssertEqual(body, "<head></head>")
  }

  func testTheEventLeafTagPrintsEventAttributes() async throws {
    app.privatusAnalytics.configuration.enabled = false
    let body = try await renderLeaf(
      #"<button #privatusEvent("Export CSV", "format", "csv", "rows", 12)>Export</button>"#)

    XCTAssertEqual(
      body,
      #"<button data-privatus-event="Export CSV" data-privatus-prop-format="csv" data-privatus-prop-rows="12">Export</button>"#
    )
  }

  func testTheEventLeafTagTakesADictionaryAndEscapes() async throws {
    let body = try await renderLeaf(
      #"<form #privatusEvent("Newsletter joined", props)>"#, EventContext(props: ["list": "<weekly>"]))

    XCTAssertEqual(
      body, #"<form data-privatus-event="Newsletter joined" data-privatus-prop-list="&lt;weekly&gt;">"#)
  }

  func testTheClickLeafTagPrintsTheClickName() async throws {
    let body = try await renderLeaf(#"<a #privatusClick("pricing.cta")>Plans</a><a #privatusClick("no good")>x</a>"#)

    XCTAssertEqual(body, #"<a data-privatus-click="pricing.cta">Plans</a><a >x</a>"#)
  }
}
