import Vapor

/// Adds the script tag just before `</head>` in HTML responses.
///
/// It does nothing unless `app.privatusAnalytics.configuration.autoInject` is `true`.
/// `app.privatusAnalytics.useAutoInject()` turns that on and adds this middleware for you.
///
/// It only changes responses with status 200, a `text/html` content type, no
/// `Content-Encoding` header, a body that is already in memory (not streamed), a
/// `</head>`, and no `/js/pa.js` yet. It skips Ajax requests (`X-Requested-With: XMLHttpRequest`).
public struct PrivatusAnalyticsMiddleware: AsyncMiddleware {
  static let marker = "/js/pa.js"

  public init() {}

  public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
    let response = try await next.respond(to: request)
    let privatus = request.application.privatusAnalytics
    guard privatus.configuration.autoInject, shouldInject(request: request, response: response),
      privatus.isEnabled
    else { return response }

    guard let buffer = response.body.buffer else { return response }
    let html = String(buffer: buffer)
    guard !html.contains(Self.marker), let head = html.range(of: "</head>", options: .caseInsensitive) else {
      return response
    }

    let tag = privatus.tag(for: request)
    guard !tag.isEmpty else { return response }

    var changed = html
    changed.replaceSubrange(head.lowerBound..<head.lowerBound, with: "\(tag)\n")
    response.body = Response.Body(string: changed)
    response.headers.replaceOrAdd(name: .contentLength, value: String(changed.utf8.count))
    return response
  }

  func shouldInject(request: Request, response: Response) -> Bool {
    guard response.status == .ok else { return false }
    guard let type = response.headers.first(name: .contentType), type.lowercased().hasPrefix("text/html") else {
      return false
    }
    guard response.headers.first(name: .contentEncoding) == nil else { return false }
    let requestedWith = request.headers.first(name: "X-Requested-With") ?? ""
    return requestedWith.caseInsensitiveCompare("XMLHttpRequest") != .orderedSame
  }
}
