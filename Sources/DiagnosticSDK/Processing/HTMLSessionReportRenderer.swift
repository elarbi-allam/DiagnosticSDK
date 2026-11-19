import Foundation

struct HTMLSessionReportRenderer: SessionReportRendering {

    private static let longBodyLineThreshold = 18
    private static let longBodyCharacterThreshold = 1_800
    private static let longHeaderValueThreshold = 120
    private static let slowDurationMs = 1_000
    private static let verySlowDurationMs = 3_000

    let fileExtension = "html"

    func renderDocumentStart(_ summary: SessionReportSummary) -> String {
        let hostChips = summary.hosts.map { host in
            "<button type=\"button\" class=\"chip\" data-filter=\"host:\(escaped(host.name))\" aria-pressed=\"false\">\(escaped(host.name))<span class=\"chip-count\">\(host.requestCount)</span></button>"
        }.joined()
        let screenLinks = summary.screens.map { screen in
            "<a class=\"chip\" href=\"#screen-\(screen.number)\"><span class=\"chip-number\">\(screen.number)</span>\(escaped(screen.shortName))<span class=\"chip-count\">\(screen.requestCount)</span></a>"
        }.joined()
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <meta name="color-scheme" content="light dark">
        <title>Network Session Report</title>
        <script>document.documentElement.classList.add('js')</script>
        <style>\(Self.styleSheet)</style>
        </head>
        <body>
        <div class="page" id="top">
        <header class="hero">
        <p class="eyebrow">Network session report</p>
        <h1>\(escaped(summary.startedAtText))</h1>
        <p class="hero-meta">\(escaped(summary.applicationText))</p>
        <div class="stats">
        \(statMarkup(value: summary.requestCount, label: "Requests"))
        \(statMarkup(value: summary.failedRequestCount, label: "Failed", isAlert: summary.failedRequestCount > 0))
        \(statMarkup(value: summary.screens.count, label: "Screens"))
        \(statMarkup(value: summary.hosts.count, label: "Hosts"))
        </div>
        <p class="session-id">Session \(escaped(summary.sessionId))</p>
        </header>
        <div class="toolbar js-only">
        <input id="search" type="search" placeholder="Search path, host, method, status…" autocomplete="off" autocapitalize="off" spellcheck="false">
        <div class="chip-row" role="group" aria-label="Filters">
        <button type="button" class="chip" data-filter="all" aria-pressed="true">All<span class="chip-count">\(summary.requestCount)</span></button>
        <button type="button" class="chip chip-alert" data-filter="failures" aria-pressed="false">Failures<span class="chip-count">\(summary.failedRequestCount)</span></button>
        \(hostChips)
        </div>
        <p class="visible-count" id="visible-count">\(SessionReportCountFormatting.text(count: summary.requestCount, noun: "request"))</p>
        </div>
        <nav class="screen-nav" aria-label="Screens">
        <h2 class="section-label">Screens</h2>
        <div class="chip-row">\(screenLinks)</div>
        </nav>
        <main>

        """
    }

    func renderScreenStart(_ screen: SessionReportScreenHeader) -> String {
        let moduleName = screen.name == screen.shortName
            ? ""
            : "<span class=\"screen-module\">\(escaped(screen.name))</span>"
        return """
        <section class="screen" id="screen-\(screen.number)">
        <header class="screen-header">
        <span class="screen-number">\(screen.number)</span>
        <div class="screen-title"><h2>\(escaped(screen.shortName))</h2>\(moduleName)</div>
        <span class="screen-meta">\(escaped(screen.enteredAtText)) · \(escaped(screen.requestCountText))</span>
        </header>

        """
    }

    func renderEntry(_ entry: SessionReportEntry) -> String {
        let searchText = "\(entry.method) \(entry.url) \(entry.status.label)".lowercased()
        var parts = [requestPart(entry.request)]
        if let response = entry.response {
            parts.append(responsePart(response))
        } else {
            parts.append("<section class=\"part\"><h3>Response</h3><p class=\"placeholder\">No response received.</p></section>")
        }
        let error = entry.errorDescription.map {
            "<div class=\"error-box\"><strong>Error</strong><p>\(escaped($0))</p></div>"
        } ?? ""
        return """
        <details class="entry" id="request-\(entry.number)" data-search="\(escaped(searchText))" data-host="\(escaped(entry.host))" data-failure="\(entry.status.isFailure)" data-url="\(escaped(entry.url))" data-curl="\(escaped(entry.curlCommand))">
        <summary>
        <div class="entry-line">
        <span class="badge method-\(methodClass(of: entry.method))">\(escaped(entry.method))</span>
        <span class="badge status-\(statusClass(of: entry.status))">\(escaped(entry.status.label))</span>
        <span class="duration \(durationClass(of: entry.durationMs))">\(escaped(entry.durationText))</span>
        <span class="entry-number">#\(entry.number)</span>
        </div>
        <div class="entry-path">\(escaped(entry.pathAndQuery))</div>
        <div class="entry-host">\(escaped(entry.host)) · \(escaped(entry.startedAtText))</div>
        </summary>
        <div class="entry-content">
        <div class="url-box"><span class="url-label">URL</span><span class="url-value">\(escaped(entry.url))</span></div>
        <div class="actions js-only">
        <button type="button" class="action" data-action="copy-url">Copy URL</button>
        <button type="button" class="action" data-action="copy-curl">Copy as cURL</button>
        </div>
        \(error)
        <div class="parts">
        \(parts.joined(separator: "\n"))
        </div>
        \(timingMarkup(entry))
        </div>
        </details>

        """
    }

    func renderScreenEnd() -> String {
        "</section>\n"
    }

    func renderDocumentEnd() -> String {
        """
        </main>
        <p class="footer">Generated by DiagnosticSDK</p>
        </div>
        <a class="to-top js-only" id="to-top" href="#top" aria-label="Back to top">↑</a>
        <div class="toast" id="toast" role="status">Copied</div>
        <script>\(Self.script)</script>
        </body>
        </html>

        """
    }

    private func statMarkup(value: Int, label: String, isAlert: Bool = false) -> String {
        "<div class=\"stat\"><span class=\"stat-value\(isAlert ? " stat-alert" : "")\">\(value)</span><span class=\"stat-label\">\(label)</span></div>"
    }

    private func requestPart(_ message: SessionReportMessage) -> String {
        let blocks = [headersBlock(message.headers), message.hasBody ? bodyBlock(message) : ""]
            .filter { !$0.isEmpty }
        let content = blocks.isEmpty
            ? "<p class=\"placeholder\">No headers or body.</p>"
            : blocks.joined(separator: "\n")
        return "<section class=\"part\"><h3>Request</h3>\(content)</section>"
    }

    private func responsePart(_ message: SessionReportMessage) -> String {
        let body = message.hasBody ? bodyBlock(message) : "<p class=\"placeholder\">No body.</p>"
        return "<section class=\"part\"><h3>Response</h3>\(headersBlock(message.headers))\(body)</section>"
    }

    private func headersBlock(_ headers: [(name: String, value: String)]) -> String {
        guard !headers.isEmpty else { return "" }
        let rows = headers.map { header -> String in
            guard header.value.count > Self.longHeaderValueThreshold else {
                return "<dt>\(escaped(header.name))</dt><dd>\(escaped(header.value))</dd>"
            }
            return "<dt>\(escaped(header.name))</dt><dd class=\"is-long\"><span class=\"value\">\(escaped(header.value))</span><button type=\"button\" class=\"link js-only\" data-action=\"toggle-value\">Show all \(header.value.count) characters</button></dd>"
        }.joined()
        return """
        <details class="block headers"><summary>Headers<span class="pill">\(headers.count)</span></summary><dl class="pairs">\(rows)</dl></details>
        """
    }

    private func bodyBlock(_ message: SessionReportMessage) -> String {
        let notice = message.bodyNotice.map { "<p class=\"notice\">\(escaped($0))</p>" } ?? ""
        let copyButton = "<button type=\"button\" class=\"link js-only\" data-action=\"copy-body\">Copy</button>"
        switch message.body {
        case .placeholder(let text):
            return "<div class=\"block\"><div class=\"block-title\">Body<span class=\"muted\">\(escaped(message.bodyTitle))</span></div>\(notice)<p class=\"placeholder\">\(escaped(text))</p></div>"
        case .json(let text), .text(let text):
            let lineCount = text.reduce(into: 1) { count, character in if character == "\n" { count += 1 } }
            let isLong = lineCount > Self.longBodyLineThreshold || text.count > Self.longBodyCharacterThreshold
            let languageAttribute: String
            if case .json = message.body {
                languageAttribute = " data-language=\"json\""
            } else {
                languageAttribute = ""
            }
            let expandButton = isLong
                ? "<button type=\"button\" class=\"expand js-only\" data-action=\"toggle-body\" data-label=\"Show full body\">Show full body</button>"
                : ""
            return """
            <div class="block"><div class="block-title">Body<span class="muted">\(escaped(message.bodyTitle))</span>\(copyButton)</div>\(notice)<pre class="code\(isLong ? " is-long" : "")"\(languageAttribute)>\(escapedTextContent(text))</pre>\(expandButton)</div>
            """
        }
    }

    private func timingMarkup(_ entry: SessionReportEntry) -> String {
        guard !entry.timingRows.isEmpty else { return "" }
        let rows = entry.timingRows
            .map { "<dt>\(escaped($0.title))</dt><dd>\(escaped($0.value))</dd>" }
            .joined()
        return "<details class=\"block timing\"><summary>Timing<span class=\"muted\">\(escaped(entry.durationText))</span></summary><dl class=\"pairs\">\(rows)</dl></details>"
    }

    private func methodClass(of method: String) -> String {
        ["GET", "POST", "PUT", "PATCH", "DELETE"].contains(method) ? method.lowercased() : "other"
    }

    private func statusClass(of status: SessionReportStatus) -> String {
        switch status {
        case .success: return "success"
        case .redirection: return "redirection"
        case .clientError: return "client-error"
        case .serverError, .transportFailure: return "server-error"
        case .noResponse: return "neutral"
        }
    }

    private func durationClass(of durationMs: Int?) -> String {
        guard let durationMs else { return "" }
        if durationMs >= Self.verySlowDurationMs { return "is-very-slow" }
        if durationMs >= Self.slowDurationMs { return "is-slow" }
        return ""
    }

    private func escapedTextContent(_ text: String) -> String {
        var escapedText = ""
        escapedText.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": escapedText += "&amp;"
            case "<": escapedText += "&lt;"
            case ">": escapedText += "&gt;"
            default: escapedText.append(character)
            }
        }
        return escapedText
    }

    private func escaped(_ text: String) -> String {
        var escapedText = ""
        escapedText.reserveCapacity(text.utf8.count)
        for character in text {
            switch character {
            case "&": escapedText += "&amp;"
            case "<": escapedText += "&lt;"
            case ">": escapedText += "&gt;"
            case "\"": escapedText += "&quot;"
            case "'": escapedText += "&#39;"
            default: escapedText.append(character)
            }
        }
        return escapedText
    }

    private static let styleSheet = """
    :root{--bg:#f2f3f6;--surface:#fff;--surface-alt:#f4f5f8;--text:#14171c;--muted:#687080;--border:#e1e4ea;--accent:#2563eb;--accent-soft:#e3ecff;--code-bg:#f7f8fa;--json-key:#1f5fae;--json-string:#0d7a3e;--json-number:#b45309;--json-literal:#7c3aed;--json-punctuation:#7a8291;--success:#13753a;--success-bg:#dcf5e5;--redirection:#1d4ed8;--redirection-bg:#dde8fd;--client-error:#9a5b00;--client-error-bg:#fdf0c9;--server-error:#b42318;--server-error-bg:#fde3e1;--neutral:#4b5563;--neutral-bg:#e6e8ec;--shadow:0 1px 2px rgba(16,24,40,.06),0 1px 3px rgba(16,24,40,.08);--radius:16px;--mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
    @media (prefers-color-scheme:dark){:root{--bg:#0b0d11;--surface:#15181e;--surface-alt:#1c2028;--text:#e8eaee;--muted:#98a1ae;--border:#272c35;--accent:#6aa6ff;--accent-soft:#1b2a44;--code-bg:#101318;--json-key:#7cb4ff;--json-string:#7ee2a8;--json-number:#f5b971;--json-literal:#c4a7ff;--json-punctuation:#8b93a0;--success:#4ade80;--success-bg:#12301d;--redirection:#93c5fd;--redirection-bg:#172a46;--client-error:#fbbf24;--client-error-bg:#382a0d;--server-error:#f87171;--server-error-bg:#3c1616;--neutral:#cbd5e1;--neutral-bg:#272c35;--shadow:none}}
    *{box-sizing:border-box}
    html{-webkit-text-size-adjust:100%;scroll-padding-top:150px}
    html:not(.js) .js-only{display:none!important}
    body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;-webkit-font-smoothing:antialiased}
    .page{max-width:1180px;margin:0 auto;padding:max(16px,env(safe-area-inset-top)) max(14px,env(safe-area-inset-right)) 96px max(14px,env(safe-area-inset-left))}
    .hero{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);padding:20px 18px;box-shadow:var(--shadow)}
    .eyebrow{margin:0 0 4px;font-size:12px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:var(--accent)}
    h1{margin:0;font-size:22px;line-height:1.25}
    .hero-meta{margin:6px 0 0;color:var(--muted);font-size:14px}
    .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:16px}
    .stat{background:var(--surface-alt);border-radius:12px;padding:10px 8px;text-align:center}
    .stat-value{display:block;font-size:22px;font-weight:700;line-height:1.1}
    .stat-alert{color:var(--server-error)}
    .stat-label{display:block;margin-top:2px;font-size:11px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;color:var(--muted)}
    .session-id{margin:14px 0 0;font:12px var(--mono);color:var(--muted);word-break:break-all}
    .toolbar{position:sticky;top:0;z-index:5;margin:12px -14px 0;padding:10px 14px;background:color-mix(in srgb,var(--bg) 88%,transparent);-webkit-backdrop-filter:saturate(180%) blur(16px);backdrop-filter:saturate(180%) blur(16px);border-bottom:1px solid var(--border)}
    #search{width:100%;height:44px;padding:0 14px;border-radius:12px;border:1px solid var(--border);background:var(--surface);color:var(--text);font-size:16px;-webkit-appearance:none;appearance:none}
    #search:focus{outline:2px solid var(--accent);outline-offset:-1px}
    .chip-row{display:flex;gap:8px;overflow-x:auto;padding:10px 2px 2px;scrollbar-width:none;-webkit-overflow-scrolling:touch}
    .chip-row::-webkit-scrollbar{display:none}
    .chip{flex:0 0 auto;display:inline-flex;align-items:center;gap:6px;min-height:36px;padding:0 14px;border-radius:18px;border:1px solid var(--border);background:var(--surface);color:var(--text);font:500 14px -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;text-decoration:none;white-space:nowrap;cursor:pointer}
    .chip[aria-pressed=true]{background:var(--accent);border-color:var(--accent);color:#fff}
    .chip[aria-pressed=true] .chip-count{background:rgba(255,255,255,.25);color:#fff}
    .chip-alert[aria-pressed=true]{background:var(--server-error);border-color:var(--server-error)}
    .chip-count{min-width:22px;padding:1px 7px;border-radius:10px;background:var(--surface-alt);color:var(--muted);font-size:12px;font-weight:600;text-align:center}
    .chip-number{display:inline-flex;align-items:center;justify-content:center;width:20px;height:20px;border-radius:10px;background:var(--accent-soft);color:var(--accent);font-size:11px;font-weight:700}
    .visible-count{margin:4px 2px 0;font-size:12px;color:var(--muted)}
    .screen-nav{margin-top:18px}
    .section-label{margin:0 2px;font-size:12px;font-weight:600;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
    .screen{margin-top:28px}
    .screen[hidden],.entry[hidden]{display:none}
    .screen-header{display:grid;grid-template-columns:auto 1fr;gap:2px 10px;align-items:center;margin:0 2px 10px}
    .screen-number{grid-row:span 2;display:inline-flex;align-items:center;justify-content:center;width:32px;height:32px;border-radius:16px;background:var(--accent);color:#fff;font-weight:700;font-size:14px}
    .screen-title{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px 8px;min-width:0}
    .screen-title h2{margin:0;font-size:19px;line-height:1.2;word-break:break-word}
    .screen-module{font:12px var(--mono);color:var(--muted);word-break:break-all}
    .screen-meta{font-size:13px;color:var(--muted)}
    .entry{background:var(--surface);border:1px solid var(--border);border-radius:var(--radius);margin:10px 0;box-shadow:var(--shadow);overflow:hidden}
    .entry>summary{list-style:none;cursor:pointer;padding:14px 16px;-webkit-tap-highlight-color:transparent}
    .entry>summary::-webkit-details-marker{display:none}
    .entry>summary:active{background:var(--surface-alt)}
    .entry[open]>summary{background:var(--surface-alt);border-bottom:1px solid var(--border)}
    .entry-line{display:flex;align-items:center;gap:8px;flex-wrap:wrap}
    .entry-number{margin-left:auto;font-size:12px;color:var(--muted)}
    .entry-path{margin-top:8px;font:600 15px/1.4 var(--mono);overflow-wrap:anywhere;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
    .entry-host{margin-top:4px;font-size:13px;color:var(--muted);overflow-wrap:anywhere}
    .badge{display:inline-flex;align-items:center;height:24px;padding:0 9px;border-radius:7px;font:700 12px var(--mono);background:var(--neutral-bg);color:var(--neutral);white-space:nowrap}
    .method-get{background:var(--redirection-bg);color:var(--redirection)}
    .method-post{background:var(--success-bg);color:var(--success)}
    .method-put,.method-patch{background:var(--client-error-bg);color:var(--client-error)}
    .method-delete{background:var(--server-error-bg);color:var(--server-error)}
    .status-success{background:var(--success-bg);color:var(--success)}
    .status-redirection{background:var(--redirection-bg);color:var(--redirection)}
    .status-client-error{background:var(--client-error-bg);color:var(--client-error)}
    .status-server-error{background:var(--server-error-bg);color:var(--server-error)}
    .duration{font-size:13px;font-weight:600;color:var(--muted)}
    .duration.is-slow{color:var(--client-error)}
    .duration.is-very-slow{color:var(--server-error)}
    .entry-content{padding:14px 16px 16px}
    .url-box{display:flex;flex-direction:column;gap:2px;padding:10px 12px;border-radius:12px;background:var(--surface-alt)}
    .url-label{font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
    .url-value{font:13px/1.45 var(--mono);overflow-wrap:anywhere;-webkit-user-select:text;user-select:text}
    .actions{display:flex;gap:8px;margin-top:10px}
    .action{flex:1 1 0;min-height:40px;border-radius:10px;border:1px solid var(--border);background:var(--surface);color:var(--accent);font:600 14px -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;cursor:pointer}
    .action:active{background:var(--accent-soft)}
    .error-box{margin-top:12px;padding:12px;border-radius:12px;background:var(--server-error-bg);color:var(--server-error)}
    .error-box p{margin:4px 0 0;font:13px/1.45 var(--mono);overflow-wrap:anywhere}
    .parts{display:grid;gap:4px;margin-top:6px}
    .part h3{margin:16px 0 8px;font-size:13px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:var(--muted)}
    .block{margin:8px 0;border:1px solid var(--border);border-radius:12px;background:var(--surface);overflow:hidden}
    details.block>summary{list-style:none;cursor:pointer;display:flex;align-items:center;gap:8px;min-height:44px;padding:0 14px;font-weight:600;font-size:15px}
    details.block>summary::-webkit-details-marker{display:none}
    details.block>summary::after{content:"";margin-left:auto;width:8px;height:8px;border-right:2px solid var(--muted);border-bottom:2px solid var(--muted);transform:rotate(45deg);transition:transform .15s}
    details.block[open]>summary::after{transform:rotate(225deg)}
    details.block[open]>summary{border-bottom:1px solid var(--border)}
    .block-title{display:flex;align-items:center;gap:8px;min-height:44px;padding:0 14px;font-weight:600;font-size:15px;border-bottom:1px solid var(--border)}
    .block-title .link{margin-left:auto}
    .muted{color:var(--muted);font-weight:500;font-size:13px}
    .pill{padding:1px 8px;border-radius:10px;background:var(--surface-alt);color:var(--muted);font-size:12px;font-weight:600}
    .pairs{margin:0;padding:6px 14px 10px;font:13px/1.45 var(--mono)}
    .pairs dt{margin-top:8px;color:var(--json-key);font-weight:600;overflow-wrap:anywhere}
    .pairs dd{margin:2px 0 0;overflow-wrap:anywhere;-webkit-user-select:text;user-select:text}
    .js .pairs dd.is-long:not(.is-expanded) .value{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
    .link{border:none;background:none;padding:6px 0;color:var(--accent);font:600 13px -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;cursor:pointer}
    .pairs .link{display:block}
    .code{margin:0;padding:12px 14px;background:var(--code-bg);font:13px/1.5 var(--mono);white-space:pre-wrap;overflow-wrap:anywhere;tab-size:2;-webkit-user-select:text;user-select:text}
    .js .code.is-long:not(.is-expanded){max-height:20em;overflow:hidden;-webkit-mask-image:linear-gradient(180deg,#000 75%,transparent);mask-image:linear-gradient(180deg,#000 75%,transparent)}
    .expand{display:block;width:100%;min-height:44px;border:none;border-top:1px solid var(--border);background:var(--surface-alt);color:var(--accent);font:600 14px -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;cursor:pointer}
    .placeholder{margin:6px 2px;color:var(--muted);font-style:italic;font-size:14px}
    .notice{margin:0;padding:8px 14px;background:var(--client-error-bg);color:var(--client-error);font-size:13px}
    .timing{margin-top:14px}
    .json-key{color:var(--json-key)}
    .json-string{color:var(--json-string)}
    .json-number{color:var(--json-number)}
    .json-literal{color:var(--json-literal)}
    .json-punctuation{color:var(--json-punctuation)}
    .footer{margin:32px 0 0;text-align:center;font-size:12px;color:var(--muted)}
    .to-top{position:fixed;right:max(16px,env(safe-area-inset-right));bottom:max(16px,env(safe-area-inset-bottom));width:48px;height:48px;border-radius:24px;display:flex;align-items:center;justify-content:center;background:var(--accent);color:#fff;font-size:22px;text-decoration:none;box-shadow:0 6px 16px rgba(0,0,0,.25);opacity:0;pointer-events:none;transition:opacity .2s}
    .to-top.is-visible{opacity:1;pointer-events:auto}
    .toast{position:fixed;left:50%;bottom:max(24px,env(safe-area-inset-bottom));transform:translate(-50%,20px);padding:10px 18px;border-radius:20px;background:var(--text);color:var(--bg);font-weight:600;font-size:14px;opacity:0;pointer-events:none;transition:opacity .2s,transform .2s}
    .toast.is-visible{opacity:1;transform:translate(-50%,0)}
    @media (min-width:760px){.page{padding:28px 24px 96px}.hero{padding:26px 28px}h1{font-size:26px}.toolbar{margin:16px 0 0;border:1px solid var(--border);border-radius:var(--radius);top:12px}.chip-row{flex-wrap:wrap;overflow:visible}.pairs{display:grid;grid-template-columns:minmax(160px,max-content) 1fr;gap:6px 16px}.pairs dt{margin-top:0}.pairs dd{margin:0}.actions{max-width:420px}}
    @media (min-width:1024px){.parts{grid-template-columns:1fr 1fr;gap:20px;align-items:start}.entry>summary{display:grid;grid-template-columns:auto 1fr;gap:4px 16px;align-items:center}.entry-line{grid-row:span 2}.entry-path{margin-top:0}.entry-host{margin-top:0}}
    @media (hover:hover){.chip:hover,.action:hover{border-color:var(--accent)}.entry>summary:hover{background:var(--surface-alt)}}
    """

    private static let script = """
    (function(){var entries=Array.prototype.slice.call(document.querySelectorAll('.entry'));var screens=Array.prototype.slice.call(document.querySelectorAll('.screen'));var search=document.getElementById('search');var chips=Array.prototype.slice.call(document.querySelectorAll('[data-filter]'));var visibleCount=document.getElementById('visible-count');var toastElement=document.getElementById('toast');var toTop=document.getElementById('to-top');var activeFilter='all';var toastTimer;function isVisible(entry,query){if(activeFilter==='failures'&&entry.dataset.failure!=='true'){return false;}if(activeFilter.indexOf('host:')===0&&entry.dataset.host!==activeFilter.slice(5)){return false;}return !query||entry.dataset.search.indexOf(query)>=0;}function applyFilters(){var query=search.value.trim().toLowerCase();var shown=0;entries.forEach(function(entry){var visible=isVisible(entry,query);entry.hidden=!visible;if(visible){shown+=1;}});screens.forEach(function(screen){screen.hidden=!screen.querySelector('.entry:not([hidden])');});visibleCount.textContent=shown===entries.length?entries.length+(entries.length===1?' request':' requests'):shown+' of '+entries.length+' requests';}function showToast(){toastElement.classList.add('is-visible');clearTimeout(toastTimer);toastTimer=setTimeout(function(){toastElement.classList.remove('is-visible');},1400);}function copyWithSelection(text){var field=document.createElement('textarea');field.value=text;field.setAttribute('readonly','');field.style.position='fixed';field.style.top='0';field.style.opacity='0';document.body.appendChild(field);field.select();field.setSelectionRange(0,text.length);try{document.execCommand('copy');showToast();}catch(error){}document.body.removeChild(field);}function copy(text){if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(text).then(showToast,function(){copyWithSelection(text);});}else{copyWithSelection(text);}}search.addEventListener('input',applyFilters);chips.forEach(function(chip){chip.addEventListener('click',function(){activeFilter=chip.dataset.filter;chips.forEach(function(other){other.setAttribute('aria-pressed',String(other===chip));});applyFilters();});});document.addEventListener('click',function(event){var button=event.target.closest('button[data-action]');if(!button){return;}var entry=button.closest('.entry');var block=button.closest('.block');switch(button.dataset.action){case 'copy-url':copy(entry.dataset.url);break;case 'copy-curl':copy(entry.dataset.curl);break;case 'copy-body':copy(block.querySelector('.code').textContent);break;case 'toggle-body':var expanded=block.querySelector('.code').classList.toggle('is-expanded');button.textContent=expanded?'Show less':button.dataset.label;break;case 'toggle-value':var value=button.closest('dd');var valueExpanded=value.classList.toggle('is-expanded');button.dataset.label=button.dataset.label||button.textContent;button.textContent=valueExpanded?'Show less':button.dataset.label;break;}});var maximumHighlightedLength=300000;function escapeMarkup(text){return text.replace(/[&<>]/g,function(character){return character==='&'?'&amp;':character==='<'?'&lt;':'&gt;';});}function highlightJSON(code){if(code.dataset.highlighted||code.textContent.length>maximumHighlightedLength){return;}code.innerHTML=escapeMarkup(code.textContent).replace(/("(?:\\\\.|[^"\\\\])*")(\\s*:)?|\\b(true|false|null)\\b|-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?/g,function(match,string,colon,literal){if(string){return colon?'<span class="json-key">'+string+'</span><span class="json-punctuation">'+colon+'</span>':'<span class="json-string">'+string+'</span>';}if(literal){return '<span class="json-literal">'+match+'</span>';}return '<span class="json-number">'+match+'</span>';});code.dataset.highlighted='true';}entries.forEach(function(entry){entry.addEventListener('toggle',function(){if(entry.open){Array.prototype.forEach.call(entry.querySelectorAll('.code[data-language=json]'),highlightJSON);}});});window.addEventListener('scroll',function(){toTop.classList.toggle('is-visible',window.scrollY>700);},{passive:true});})();
    """
}
