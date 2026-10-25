import Leaf
import PrivatusAnalyticsVapor
import Testing
import XCTVapor

struct NoContext: Encodable {}

struct PagePropsContext: Encodable {
  struct Props: Encodable {
    let section: String
    let seats: Int
  }
  let pageProps: Props
}

struct SettingsContext: Encodable {
  struct Settings: Encodable {
    let enabled: Bool?
    let queueStub: Bool?
    let modules: [String]?
  }
  let pageProps: [String: String]
  let settings: Settings
}

struct EventContext: Encodable {
  let props: [String: String]
}

let page = "<html><head><title>Hi</title></head><body>Hello</body></html>"

func html(_ text: String) -> Response {
  Response(status: .ok, headers: ["Content-Type": "text/html; charset=utf-8"], body: .init(string: text))
}

/// Runs a test with a fresh app that has a site id and the tag forced on, then shuts the app down.
func withApp(_ body: (Application) async throws -> Void) async throws {
  let app = try await Application.make(.testing)
  app.privatusAnalytics.configuration = PrivatusConfiguration(siteID: "pa_TEST123456", enabled: true)
  do {
    try await body(app)
  } catch {
    try await app.asyncShutdown()
    throw error
  }
  try await app.asyncShutdown()
}

@Suite struct VaporTests {
  // MARK: Settings

  @Test func theConfigurationIsStoredOnTheApp() async throws {
    try await withApp { app in
      #expect(app.privatusAnalytics.configuration.siteID == "pa_TEST123456")
      app.privatusAnalytics.configuration.modules = ["engage"]
      #expect(app.privatusAnalytics.configuration.modules == ["engage"])
    }
  }

  @Test func onlyProductionIsOnByDefault() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.enabled = nil
      #expect(!(app.privatusAnalytics.isEnabled))
      #expect(app.privatusAnalytics.tag() == "")

      let production = try await Application.make(.production)
      production.privatusAnalytics.configuration.siteID = "pa_TEST123456"
      #expect(production.privatusAnalytics.isEnabled)
      production.privatusAnalytics.configuration.enabled = false
      #expect(!(production.privatusAnalytics.isEnabled))
      try await production.asyncShutdown()
    }
  }

  @Test func theRequestTagUsesRequestPropsAndTheNonce() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.props = ["plan": "free", "role": "admin"]
      app.privatusAnalytics.requestProps = { req in ["plan": req.headers.first(name: "X-Plan")] }
      app.privatusAnalytics.nonce = { _ in "n0nce" }
      let request = Request(application: app, headers: ["X-Plan": "pro"], on: app.eventLoopGroup.next())

      let tag = request.privatusAnalytics.tag(props: ["role": nil]) { $0.modules = ["engage", "auto"] }

      #expect(
        tag == #"<script nonce="n0nce">window.privatusPageProps=function(){return {"plan":"pro"}}</script>"# + "\n"
          + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-modules="engage,auto" nonce="n0nce" data-props="privatusPageProps"></script>"#
      )
    }
  }

  @Test func requestPropsDoNotRunWhenTheTagIsOff() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.enabled = false
      app.privatusAnalytics.requestProps = { _ in fatalError("should not run") }
      let request = Request(application: app, on: app.eventLoopGroup.next())

      #expect(request.privatusAnalytics.tag() == "")
    }
  }

  @Test func theRequestTagPrintsOnlyTheStubWhenOff() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.enabled = false
      app.privatusAnalytics.configuration.queueStub = true
      app.privatusAnalytics.configuration.props = ["plan": "pro"]
      app.privatusAnalytics.requestProps = { _ in fatalError("should not run") }
      app.privatusAnalytics.nonce = { _ in "n0nce" }
      let request = Request(application: app, on: app.eventLoopGroup.next())

      #expect(request.privatusAnalytics.tag() == #"<script nonce="n0nce">"# + Privatus.queueStub + "</script>")
      #expect(request.privatusAnalytics.tag { $0.queueStub = false } == "")
    }
  }

  // MARK: Middleware

  @Test func autoInjectAddsTheTagBeforeTheHead() async throws {
    try await withApp { app in
      app.privatusAnalytics.useAutoInject()
      app.get("page") { _ in html(page) }

      try await app.test(.GET, "page") { res async in
        let expected =
          #"<html><head><title>Hi</title><script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456"></script>"#
          + "\n</head><body>Hello</body></html>"
        #expect(res.body.string == expected)
        #expect(res.headers.first(name: .contentLength) == String(expected.utf8.count))
      }
    }
  }

  @Test func theMiddlewareDoesNothingWithoutAutoInject() async throws {
    try await withApp { app in
      app.middleware.use(PrivatusAnalyticsMiddleware())
      app.get("page") { _ in html(page) }

      try await app.test(.GET, "page") { res async in
        #expect(res.body.string == page)
      }
    }
  }

  @Test func theMiddlewareSkipsResponsesItShouldNotTouch() async throws {
    try await withApp { app in
      app.privatusAnalytics.useAutoInject()
      app.get("missing") { _ in
        Response(status: .notFound, headers: ["Content-Type": "text/html"], body: .init(string: page))
      }
      app.get("json") { _ in
        Response(status: .ok, headers: ["Content-Type": "application/json"], body: .init(string: page))
      }
      app.get("gzip") { _ in
        Response(
          status: .ok, headers: ["Content-Type": "text/html", "Content-Encoding": "gzip"],
          body: .init(string: page))
      }
      app.get("tagged") { _ in html(#"<head><script src="/js/pa.js"></script></head>"#) }
      app.get("nohead") { _ in html("<p>Hi</p>") }
      app.get("page") { _ in html(page) }

      for path in ["missing", "json", "gzip", "tagged", "nohead"] {
        try await app.test(.GET, path) { res async in
          #expect(res.body.string.contains("pa_TEST123456") == false, "\(path)")
        }
      }
      try await app.test(.GET, "page", headers: ["X-Requested-With": "XMLHttpRequest"]) { res async in
        #expect(res.body.string == page)
      }
    }
  }

  @Test func theMiddlewareSkipsWhenTheTagIsOff() async throws {
    try await withApp { app in
      app.privatusAnalytics.useAutoInject()
      app.privatusAnalytics.configuration.enabled = nil
      app.privatusAnalytics.configuration.queueStub = true
      app.get("page") { _ in html(page) }

      try await app.test(.GET, "page") { res async in
        #expect(res.body.string == page)
      }
    }
  }

  // MARK: Leaf

  func renderLeaf(
    _ app: Application, _ template: String, _ context: some Encodable = NoContext()
  ) async throws -> String {
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

  @Test func theLeafTagPrintsTheScriptTag() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.props = ["plan": "pro"]
      let body = try await renderLeaf(app, "<head>#privatusAnalytics()</head>")

      #expect(
        body == #"<head><script>window.privatusPageProps=function(){return {"plan":"pro"}}</script>"# + "\n"
          + #"<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-props="privatusPageProps"></script></head>"#
      )
    }
  }

  @Test func theLeafTagTakesPagePropsFromTheContext() async throws {
    try await withApp { app in
      let body = try await renderLeaf(
        app, "#privatusAnalytics(pageProps)", PagePropsContext(pageProps: .init(section: "billing", seats: 3)))

      #expect(body.contains(#"{"seats":3,"section":"billing"}"#), "\(body)")
    }
  }

  @Test func theLeafTagPrintsNothingWhenOff() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.enabled = nil
      let body = try await renderLeaf(app, "<head>#privatusAnalytics()</head>")
      #expect(body == "<head></head>")
    }
  }

  @Test func theEventLeafTagPrintsEventAttributes() async throws {
    try await withApp { app in
      app.privatusAnalytics.configuration.enabled = false
      let body = try await renderLeaf(
        app, #"<button #privatusEvent("Export CSV", "format", "csv", "rows", 12)>Export</button>"#)

      #expect(
        body
          == #"<button data-privatus-event="Export CSV" data-privatus-prop-format="csv" data-privatus-prop-rows="12">Export</button>"#
      )
    }
  }

  @Test func theEventLeafTagTakesADictionaryAndEscapes() async throws {
    try await withApp { app in
      let body = try await renderLeaf(
        app, #"<form #privatusEvent("Newsletter joined", props)>"#, EventContext(props: ["list": "<weekly>"]))

      #expect(body == #"<form data-privatus-event="Newsletter joined" data-privatus-prop-list="&lt;weekly&gt;">"#)
    }
  }

  @Test func theClickLeafTagPrintsTheClickName() async throws {
    try await withApp { app in
      let body = try await renderLeaf(
        app, #"<a #privatusClick("pricing.cta")>Plans</a><a #privatusClick("no good")>x</a>"#)

      #expect(body == #"<a data-privatus-click="pricing.cta">Plans</a><a >x</a>"#)
    }
  }

  @Test func theLeafTagTakesSettingsForOnePage() async throws {
    try await withApp { app in
      let body = try await renderLeaf(
        app, "<head>#privatusAnalytics(pageProps, settings)</head>",
        SettingsContext(
          pageProps: ["plan": "pro"], settings: .init(enabled: false, queueStub: true, modules: nil)))
      #expect(body == "<head><script>" + Privatus.queueStub + "</script></head>")
    }
    try await withApp { app in
      let plain = try await renderLeaf(
        app, "<head>#privatusAnalytics(pageProps, settings)</head>",
        SettingsContext(
          pageProps: ["plan": "pro"], settings: .init(enabled: false, queueStub: false, modules: nil)))
      #expect(plain == "<head></head>")
    }
    try await withApp { app in
      let on = try await renderLeaf(
        app, "<head>#privatusAnalytics(pageProps, settings)</head>",
        SettingsContext(pageProps: [:], settings: .init(enabled: nil, queueStub: nil, modules: ["engage"])))
      #expect(
        on
          == #"<head><script defer src="https://privatusstats.com/js/pa.js" data-site="pa_TEST123456" data-modules="engage"></script></head>"#
      )
    }
  }
}
