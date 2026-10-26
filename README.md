# Privatus Analytics for Swift and Vapor

**Simple, private website analytics for your Swift web app. No cookies, honest numbers,
and a dashboard you understand in seconds.**

## Why Privatus Analytics

**Google Analytics is slow, confusing and hungry for data.** It sends what your
visitors do to Google. In many countries it means showing a cookie pop-up (the box
that asks visitors to accept cookies), and many people click "reject", so you never
see them. Bots pad the numbers that are left.

**Privatus Analytics fixes that.** It counts visits to your Swift web app without cookies and
never stores IP addresses. Bots are filtered out before they are counted. Your
data is never sold or shared.

What you get:

- **A dashboard you understand in seconds.** Visitors, top pages and where people
  came from, all on one screen.
- **No cookie pop-up needed for our analytics.** We set no cookies and store no
  personal data. Laws differ by country, so check your own legal advice.
- **Honest numbers.** Known bots and fake traffic are left out on every plan.
- **A fast site.** The tracking script is about 3 KB, tiny next to most tracking tags.
- **Data you own.** We never sell it or show you ads, and you can pull it out
  any time through the API.

**Start free.** The Free plan has 10,000 events a month and 3 sites, with no card.
Every new account also gets 14 days of Pro free, with no card.
[Create your account](https://privatusanalytics.com).

## What this package does

- Leaf tags, a Vapor middleware that puts the script in the `<head>` for you,
  and plain Swift functions for any HTML builder, such as Elementary or Plot.
- `PrivatusAnalytics` is the core. It needs only Foundation, so it works with
  any Swift server framework or HTML builder.
- `PrivatusAnalyticsVapor` adds Vapor 4 settings, a middleware, and Leaf tags.
  It includes the core, so one import is enough.
- The package only prints the browser script and a few HTML attributes. It
  never sends events from your server, makes no network requests and sets no
  cookies.

You need a Privatus Analytics account to see your reports, and there is a
free plan. [Sign up at privatusanalytics.com](https://privatusanalytics.com).

## Requirements

* Swift 5.9 or later, on Linux or macOS. The tests need Swift 6, since they use
  swift-testing.
* Vapor 4 and Leaf 4, if you use `PrivatusAnalyticsVapor`.
* A Privatus Analytics site id (it starts with `pa_`). You find it under
  Site settings, Tracking.

## Install

Add the package to your `Package.swift`:

```swift
dependencies: [
  .package(url: "https://github.com/Privatus-Analytics/swift.git", from: "1.0.0"),
],
targets: [
  .executableTarget(
    name: "App",
    dependencies: [
      .product(name: "PrivatusAnalyticsVapor", package: "swift"),
      // or, without Vapor: .product(name: "PrivatusAnalytics", package: "swift"),
    ]
  ),
]
```

For the full setup guide and every tracker option, see the [Privatus
Analytics docs](https://privatusanalytics.com/docs).

Set your site id with an environment variable:

```sh
PRIVATUS_SITE_ID=pa_YOURSITEID
```

or in `configure.swift`:

```swift
import PrivatusAnalyticsVapor

app.privatusAnalytics.configuration.siteID = "pa_YOURSITEID"
```

## Add the tag

Turn on the Leaf tags in `configure.swift`:

```swift
app.views.use(.leaf)
app.privatusAnalytics.useLeafTags()
```

`useLeafTags()` is short for:

```swift
app.leaf.tags["privatusAnalytics"] = PrivatusAnalyticsLeafTag()
app.leaf.tags["privatusEvent"] = PrivatusEventLeafTag()
app.leaf.tags["privatusClick"] = PrivatusClickLeafTag()
```

Then put the tag in the `<head>` of your layout, for example
`Resources/Views/base.leaf`:

```html
<head>
  <title>My app</title>
  #privatusAnalytics()
</head>
```

Render the view with `req.view.render(...)` so the tag can see the request. In
production it prints:

```html
<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID"></script>
```

The tag prints nothing when there is no site id, and nothing outside the
production environment (see below).

Not using Leaf? Get the same text in a route with
`req.privatusAnalytics.tag()`.

### Or let the package add it

If you would rather not touch your layouts, switch on auto inject:

```swift
app.privatusAnalytics.useAutoInject()
```

This sets `configuration.autoInject = true` and adds
`PrivatusAnalyticsMiddleware`. You can also add the middleware yourself with
`app.middleware.use(PrivatusAnalyticsMiddleware())` and set `autoInject`
yourself. The middleware does nothing while `autoInject` is `false`.

It adds the tag just before `</head>` in `text/html` responses with status
200, and fixes the `Content-Length` header. It skips Ajax requests (those that
send `X-Requested-With: XMLHttpRequest`), pages without a `<head>`, pages that
already have the tag, and streamed bodies. Responses that have a
`Content-Encoding` header (compressed responses) are left alone.

### Content Security Policy nonce

A Content Security Policy (CSP) can block scripts unless they have a one-time
code called a nonce. Vapor has no nonce of its own, so tell the package where
yours is. The Leaf tag, `req.privatusAnalytics.tag()` and the middleware all
use it:

```swift
app.privatusAnalytics.nonce = { req in req.storage[CSPNonceKey.self] }
```

## Configuration

Every setting is optional except the site id.

```swift
// configure.swift
app.privatusAnalytics.configuration = PrivatusConfiguration(
  siteID: "pa_YOURSITEID",                 // or PRIVATUS_SITE_ID
  scriptHost: "https://privatusstats.com", // or PRIVATUS_SCRIPT_HOST
  modules: ["engage", "auto", "vitals", "clicks", "ask"],
  excludedPaths: ["/admin/*", "/preview/*"],
  domains: ["example.com", "www.example.com"],
  spa: .auto,                              // .auto, .history, .hash or .off
  manual: false,                           // true turns off the automatic pageview
  enabled: nil,                            // nil means production only
  autoInject: false,
  extraAttributes: ["data-mask": "/orders/*->/orders/:id"],
  props: ["app_version": "2.4"],
  queueStub: false
)
app.privatusAnalytics.requestProps = { req in ["plan": req.auth.get(User.self)?.plan] }
app.privatusAnalytics.nonce = { req in req.storage[CSPNonceKey.self] }
```

| Setting | Default | What it does |
|---|---|---|
| `siteID` | `PRIVATUS_SITE_ID` | The `data-site` attribute. Nothing prints without it |
| `scriptHost` | `https://privatusstats.com` | Where `/js/pa.js` is served. `PRIVATUS_SCRIPT_HOST` also works. Change it only if you host your own copy |
| `modules` | tracker default (`engage`) | The `data-modules` attribute. Setting it replaces the default, so keep `engage` for time on page and scroll depth. `[]` loads none |
| `excludedPaths` | none | The `data-exclude` attribute. Path globs the tracker never counts |
| `domains` | all hosts | The `data-domains` attribute. Count only these hostnames |
| `spa` | `.auto` | The `data-spa` attribute, for single-page apps |
| `manual` | `false` | The `data-manual` attribute |
| `enabled` | `nil` | `true` or `false` forces the tag on or off. `nil` turns it on only when `app.environment == .production` |
| `autoInject` | `false` | Lets the middleware add the tag |
| `extraAttributes` | `[:]` | Any other `data-*` attribute. They print sorted by name |
| `props` | `[:]` | Page props sent with every pageview and event. See below |
| `queueStub` | `false` | Prints a small script first, so `privatus.track` calls made before the tracker loads are kept and sent later |
| `requestProps` | `nil` | A closure that gets the request and returns page props for it. Laid over `props` |
| `nonce` | `nil` | A closure that gets the request and returns your CSP nonce |

Each tracker attribute is explained in the [script attributes
reference](https://privatusanalytics.com/docs/tracker/attributes), and the
modules in [Modules](https://privatusanalytics.com/docs/tracker/modules).

The configuration is a plain value. To change a setting for one page, pass a
closure that changes a copy:

```swift
let tag = req.privatusAnalytics.tag { $0.modules = ["engage", "auto"]; $0.excludedPaths = ["/preview/*"] }
```

In Leaf, `#privatusAnalytics(pageProps)` takes a dictionary from your context
for this page's props. A second dictionary from your context changes settings
for this page: `#privatusAnalytics(pageProps, settings)`. It may hold
`enabled`, `queueStub`, `siteID`, `scriptHost`, `modules`, `excludedPaths`,
`domains`, `spa` and `manual`.

### Development and test

Development and test runs are not counted by default, so your own clicking
around never reaches your reports. The tag prints only when
`app.environment == .production`. To see the tag while you build, set
`configuration.enabled = true`. The tracker also ignores `localhost` unless you
pass `data-allow-local` or `data-debug` (see [Debug
mode](https://privatusanalytics.com/docs/tracker/debug)):

```swift
app.privatusAnalytics.configuration.extraAttributes = ["data-debug": "true"]
```

If `queueStub` is on, the tag still prints the small queue stub (and nothing
else), so `privatus.track` calls in your own JavaScript keep working. They
wait in a queue and are never sent. The middleware adds nothing when the tag
is off.

### Leaving people out

Use `data-exclude` through `excludedPaths` for admin areas. To leave out
signed-in staff, skip the tag for them:

```html
#if(!isStaff):#privatusAnalytics()#endif
```

## Product analytics: see which features people use

Privatus Analytics can show which buttons, forms and features people really use. You
add a few attributes to your HTML. The tracker reads them in the browser and
sends the events. Your server still sends nothing.

### Name events well

Use a short "Noun verb" name, like `Report exported` or `Invite sent`. Put the
details in props, not in the name. So write `Report exported` with
`format: csv`, not `Report exported as CSV`. Then all exports add up in one
place, and you can split them by format.

### Events on buttons, links and forms

In Leaf, `#privatusEvent` takes the name, then pairs of prop keys and values:

```html
<button #privatusEvent("Report exported", "format", "csv", "source", "toolbar")>Export</button>
```

It prints:

```html
<button data-privatus-event="Report exported" data-privatus-prop-format="csv" data-privatus-prop-source="toolbar">Export</button>
```

You can also pass a dictionary from your context:
`#privatusEvent("Report exported", exportProps)`.

On a form, the event is sent when the form is submitted:

```html
<form method="post" action="/newsletter" #privatusEvent("Newsletter joined", "list", "weekly")>
```

In plain Swift, `Privatus.eventAttributes` returns the same HTML text, and
`Privatus.eventData` returns the attributes as a list of names and values:

```swift
Privatus.eventAttributes("Report exported", ["format": "csv", "rows": 120])
// data-privatus-event="Report exported" data-privatus-prop-format="csv" data-privatus-prop-rows="120"
```

The rules:

* The name is trimmed and cut to 120 characters. An empty name prints nothing.
* Prop keys are made lowercase. Anything that is not a letter, a digit or `_`
  becomes `_`, so `"Report Type"` becomes `report_type`. Keys are cut to 64
  characters.
* At most 30 props. Values become text: `true`, `false`, numbers as written,
  lists joined with commas. `nil` values are left out. Values are cut to 500
  characters.
* Everything is escaped for HTML.
* The attributes print in every environment, even when the tag is off. They do
  nothing without the tracker, so your pages look the same in development and
  production.

### Click maps

A click map shows where people click on a page. Give the important parts a
name so they stay easy to find, even when the page changes:

```html
<a href="/pricing" #privatusClick("pricing.cta")>See plans</a>
```

It prints `data-privatus-click="pricing.cta"`. In plain Swift use
`Privatus.clickAttribute("pricing.cta")` or `Privatus.clickData("pricing.cta")`.

A name may use letters, digits and `_ . : -`, up to 100 characters. Anything
else prints nothing. Outside production, the Leaf tag also writes a warning to
the log.

### Page props: plan, role and other groups

Page props are sent with every pageview and event on the page. Use them to
split your reports by plan, role, app version, feature flag or account tier.

Set them for every page with a closure. It runs on each request and gets the
request:

```swift
app.privatusAnalytics.requestProps = { req in
  ["plan": req.auth.get(User.self)?.plan, "role": req.auth.get(User.self)?.role, "app_version": "2.4"]
}
```

Props that never change can go in `configuration.props`. You can also set or
change props for one page. They are laid over the others, and `nil` removes
one:

```swift
req.privatusAnalytics.tag(props: ["section": "billing", "role": nil])
```

The tag then prints a small script before the tracker, with your nonce when
you have one, and points the tracker at it:

```html
<script nonce="...">window.privatusPageProps=function(){return {"plan":"pro","role":"admin"}}</script>
<script defer src="https://privatusstats.com/js/pa.js" data-site="pa_YOURSITEID" data-props="privatusPageProps"></script>
```

Keys follow the same rules as event props. Numbers and `true` or `false` stay
as they are, and lists stay lists (up to 30 items). The props are escaped so
they are safe inside a script. The closure only runs when the tag prints. The
middleware uses the same settings.

**Never put names, emails, user ids or anything that points to one person in
props.** Privatus Analytics counts visitors without any id. Put groups (like the plan or
the role), not people. The server also removes emails and long ids it finds.

### Track from your own JavaScript

For things that are not a click or a submit, call the tracker from your
JavaScript, as the [JavaScript API
docs](https://privatusanalytics.com/docs/tracker/javascript-api) explain:

```js
privatus.track("Feature used", { feature: "export" })
```

If your code may run before the tracker has loaded, switch on the queue stub.
It prints a tiny script before the tracker that keeps your calls in a list and
sends them once the tracker is ready:

```swift
app.privatusAnalytics.configuration.queueStub = true
```

or for one page: `req.privatusAnalytics.tag { $0.queueStub = true }`.

The stub prints even when the tag is off (outside production, without a site
id, or with `enabled = false`). Only the stub prints then: no tracker and no
page props. So your `privatus.track` calls never fail. They wait in the queue
and are never sent.

### See the results

* [Funnels](https://privatusanalytics.com/docs/features/funnels): how many
  people go from one step to the next.
* [Click maps](https://privatusanalytics.com/docs/features/click-maps): where
  people click.
* [Goals](https://privatusanalytics.com/docs/features/goals): turn an event
  into a goal to count conversions.
* [Events](https://privatusanalytics.com/docs/events): every custom event and
  its props.

## Without Vapor or Leaf

The `PrivatusAnalytics` core needs only Foundation. Pass the settings in, and
say whether the app runs in production:

```swift
import PrivatusAnalytics

let privatus = PrivatusConfiguration(siteID: "pa_YOURSITEID")

Privatus.tag(privatus, isProduction: true, nonce: cspNonce, props: ["plan": "pro"])
Privatus.eventAttributes("Report exported", ["format": "csv"])  // HTML text
Privatus.eventData("Report exported", ["format": "csv"])        // [PrivatusAttribute]
Privatus.clickAttribute("pricing.cta")                          // HTML text
Privatus.clickData("pricing.cta")                               // [PrivatusAttribute]
Privatus.pagePropsJSON(["plan": "pro"])                         // {"plan":"pro"}
```

`isProduction` is `false` when you leave it out, so the tag stays off unless
you pass `true` or set `enabled: true`.

HTML builders escape attribute values for you. So use the `...Data` functions
there, which give names and values that are not escaped yet. Use the tag as
raw HTML, since it is already escaped.

### Elementary

With [Elementary](https://github.com/elementary-swift/elementary):

```swift
import Elementary
import PrivatusAnalytics

struct Page: HTMLDocument {
  let privatus: PrivatusConfiguration
  let isProduction: Bool
  var title = "My app"

  var head: some HTML {
    HTMLRaw(Privatus.tag(privatus, isProduction: isProduction))
  }

  var body: some HTML {
    button(attributes: Privatus.eventData("Report exported", ["format": "csv"]).map {
      .custom(name: $0.name, value: $0.value)
    }) { "Export" }

    a(attributes: [.href("/pricing")] + Privatus.clickData("pricing.cta").map {
      .custom(name: $0.name, value: $0.value)
    }) { "See plans" }
  }
}
```

### Plot

With [Plot](https://github.com/JohnSundell/Plot):

```swift
import Plot
import PrivatusAnalytics

let page = HTML(
  .head(
    .title("My app"),
    .raw(Privatus.tag(privatus, isProduction: isProduction))
  ),
  .body(
    .button(
      .group(Privatus.eventData("Report exported", ["format": "csv"]).map {
        .attribute(named: $0.name, value: $0.value)
      }),
      .text("Export")
    ),
    .a(
      .href("/pricing"),
      .group(Privatus.clickData("pricing.cta").map { .attribute(named: $0.name, value: $0.value) }),
      .text("See plans")
    )
  )
)
```

## Privacy

The script sets no cookies and stores nothing in the browser. The event, click
and props helpers only print HTML attributes and a small script. The package
never reads or stores IP addresses, user agents or any visitor id. Keep people
out of your props and event props: no names, emails or user ids. See the
[privacy documentation](https://privatusanalytics.com/docs/privacy) for what is
collected.

If you have a privacy policy, it should say which tools handle your visitors' data. You can paste this:

> This website uses [Privatus Analytics](https://privatusanalytics.com/privacy-analytics) to count visits. It
> does not use cookies and does not follow you from one website to another. Your IP address is used for a moment
> to count visits and is never stored.

Change it to fit your site. The [privacy policy generator](https://privatusanalytics.com/tools/privacy-policy-generator)
makes a longer version with your site's name in it.

## Development

The checks run in Docker so your local Swift does not matter:

```sh
./run-docker.sh
```

It runs `swift format lint`, the swift-testing suite (the core, the middleware and
the Leaf tags in a test Vapor app), and a release build, in the official
`swift:6.0` image.

## Contributing

Bug reports and pull requests are welcome at
https://github.com/Privatus-Analytics/swift.

## License

MIT. See [LICENSE](LICENSE). Privatus Analytics is a product of Two Phase LLC,
Wyoming, USA.
