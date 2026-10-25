// The conformance example app for the Privatus Analytics Swift package (Vapor +
// Leaf). The conformance suite (https://github.com/Privatus-Analytics/conformance)
// builds it and checks every route in a real browser; see its CONTRACT.md. The
// site id and script host come from PRIVATUS_SITE_ID and PRIVATUS_SCRIPT_HOST.
import Foundation
import Leaf
import PrivatusAnalyticsVapor
import Vapor

let nonce = "testnonce"
let nasty = "</script><script>window.__pwned=1</script>\u{2028}\u{2029}&<>\"'"

let autoPage = """
  <!doctype html>
  <html lang="en">
  <head>
  <meta charset="utf-8">
  <title>Auto inject</title>
  </head>
  <body><h1>Auto inject</h1><p>No tag in the template. The middleware adds it.</p></body>
  </html>

  """

struct PageProps: Encodable {
  let plan = "pro"
  let role = "admin"
  let beta = true
  let seats = 3
  var nasty: String?
}

struct Settings: Encodable {
  let enabled: Bool
  let queueStub: Bool
}

struct PageContext: Encodable {
  let title: String
  var pageProps = PageProps()
  var nasty: String?
}

struct OffContext: Encodable {
  let pageProps = PageProps()
  let settings: Settings
}

/// Sends a Content Security Policy that allows the nonce and the script host.
struct ContentSecurityPolicy: AsyncMiddleware {
  let policy: String

  func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let response = try await next.respond(to: request)
    response.headers.replaceOrAdd(name: "Content-Security-Policy", value: policy)
    return response
  }
}

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = try await Application.make(env)

app.http.server.configuration.hostname = "0.0.0.0"
app.http.server.configuration.port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "") ?? 8080
app.views.use(.leaf)

// Forced on, so the tag prints whatever the environment. The site id and
// script host come from the environment. Auto inject is allowed, but the
// middleware is only on /auto, so the other routes test the Leaf tags alone.
app.privatusAnalytics.configuration = PrivatusConfiguration(enabled: true, autoInject: true, queueStub: true)
app.privatusAnalytics.nonce = { _ in nonce }
app.privatusAnalytics.useLeafTags()

let scriptHost = app.privatusAnalytics.configuration.resolvedScriptHost()
app.middleware.use(ContentSecurityPolicy(policy: "script-src 'nonce-\(nonce)' \(scriptHost)"))

app.get { req async throws -> View in
  try await req.view.render("home", PageContext(title: "Home"))
}
app.get("event") { req async throws -> View in
  try await req.view.render("event", PageContext(title: "Events"))
}
app.get("nasty") { req async throws -> View in
  try await req.view.render("nasty", PageContext(title: "Nasty", pageProps: PageProps(nasty: nasty), nasty: nasty))
}
// Off with the queue stub on prints only the stub, so privatus.track calls
// still work. Off without it prints nothing.
app.get("off") { req async throws -> View in
  try await req.view.render("off", OffContext(settings: Settings(enabled: false, queueStub: true)))
}
app.get("off-plain") { req async throws -> View in
  try await req.view.render("off", OffContext(settings: Settings(enabled: false, queueStub: false)))
}
app.grouped(PrivatusAnalyticsMiddleware()).get("auto") { _ in
  Response(status: .ok, headers: ["Content-Type": "text/html; charset=utf-8"], body: .init(string: autoPage))
}

try await app.execute()
try await app.asyncShutdown()
