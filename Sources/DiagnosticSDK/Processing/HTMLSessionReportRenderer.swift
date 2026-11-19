import Foundation

struct HTMLSessionReportRenderer: SessionReportRendering {

    let fileExtension = "html"

    func renderDocumentStart(_ summary: SessionReportSummary) -> String {
        let screenLinks = summary.screens.map { screen in
            """
            <li><a href="#screen-\(screen.number)">\(escaped(screen.name))</a><span class="muted">\(escaped(screen.enteredAtText)) · \(screen.requestCountText)</span></li>
            """
        }.joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Diagnostic Session Report</title>
        <style>\(Self.styleSheet)</style>
        </head>
        <body>
        <div class="page">
        <header class="report-header">
        <h1>Diagnostic session</h1>
        <p class="muted">\(escaped(summary.startedAtText)) · \(escaped(summary.applicationText))</p>
        <div class="stats">
        <div class="stat"><span class="stat-value">\(summary.requestCount)</span><span class="stat-label">Requests</span></div>
        <div class="stat"><span class="stat-value \(summary.failedRequestCount > 0 ? "stat-failed" : "")">\(summary.failedRequestCount)</span><span class="stat-label">Failed</span></div>
        <div class="stat"><span class="stat-value">\(summary.screens.count)</span><span class="stat-label">Screens</span></div>
        </div>
        <p class="session-id">\(escaped(summary.sessionId))</p>
        </header>
        <nav class="toolbar" id="toolbar" hidden>
        <input id="filter" type="search" placeholder="Filter by URL, method or status">
        <label class="toggle"><input id="failures-only" type="checkbox"> Failures only</label>
        <button type="button" data-action="expand">Expand all</button>
        <button type="button" data-action="collapse">Collapse all</button>
        </nav>
        <nav class="screen-index">
        <h2>Screens</h2>
        <ol>
        \(screenLinks)
        </ol>
        </nav>
        <main>

        """
    }

    func renderScreenStart(_ screen: SessionReportScreenHeader) -> String {
        """
        <section class="screen" id="screen-\(screen.number)">
        <h2><span class="screen-number">\(screen.number)</span>\(escaped(screen.name))<span class="muted">\(escaped(screen.enteredAtText)) · \(screen.requestCountText)</span></h2>

        """
    }

    func renderEntry(_ entry: SessionReportEntry) -> String {
        let searchText = "\(entry.method) \(entry.url) \(entry.status.text)".lowercased()
        var sections = [messageSection(title: "Request", message: entry.request)]
        if let response = entry.response {
            sections.append(messageSection(title: "Response", message: response))
        } else {
            sections.append("<div class=\"message\"><h3>Response</h3><p class=\"placeholder\">No response received.</p></div>")
        }
        if let errorDescription = entry.errorDescription {
            sections.append("<div class=\"message\"><h3>Error</h3><pre class=\"code error\">\(escaped(errorDescription))</pre></div>")
        }
        if !entry.timingRows.isEmpty {
            let timingRows = entry.timingRows
                .map { "<dt>\(escaped($0.title))</dt><dd>\(escaped($0.value))</dd>" }
                .joined()
            sections.append("<div class=\"message\"><h3>Timing</h3><dl class=\"pairs\">\(timingRows)</dl></div>")
        }
        return """
        <details class="entry" data-search="\(escaped(searchText))" data-failure="\(entry.status.isFailure)">
        <summary>
        <span class="number">#\(entry.number)</span>
        <span class="badge method-\(methodClass(of: entry.method))">\(escaped(entry.method))</span>
        <span class="badge status-\(statusClass(of: entry.status))">\(escaped(entry.status.text))</span>
        <span class="url">\(escaped(entry.url))</span>
        <span class="meta">\(escaped(entry.durationText)) · \(escaped(entry.startedAtText))</span>
        </summary>
        <div class="entry-content">
        \(sections.joined(separator: "\n"))
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
        </div>
        <script>\(Self.script)</script>
        </body>
        </html>

        """
    }

    private func messageSection(title: String, message: SessionReportMessage) -> String {
        let headers = message.headers.isEmpty
            ? "<p class=\"placeholder\">No headers</p>"
            : "<dl class=\"pairs\">" + message.headers.map { "<dt>\(escaped($0.name))</dt><dd>\(escaped($0.value))</dd>" }.joined() + "</dl>"
        let notice = message.bodyNotice.map { "<p class=\"notice\">\(escaped($0))</p>" } ?? ""
        return """
        <div class="message">
        <h3>\(title)</h3>
        <h4>Headers</h4>
        \(headers)
        <h4>Body <span class="muted">\(escaped(message.bodyTitle))</span></h4>
        \(notice)\(bodyMarkup(of: message.body))
        </div>
        """
    }

    private func bodyMarkup(of body: SessionReportBody) -> String {
        switch body {
        case .json(let prettyJSON):
            let highlightedLines = prettyJSON
                .components(separatedBy: .newlines)
                .map(highlightedJSONLine)
                .joined(separator: "\n")
            return "<pre class=\"code\">\(highlightedLines)</pre>"
        case .text(let text):
            return "<pre class=\"code\">\(escaped(text))</pre>"
        case .placeholder(let message):
            return "<p class=\"placeholder\">\(escaped(message))</p>"
        }
    }

    private func highlightedJSONLine(_ line: String) -> String {
        let indentation = String(repeating: " ", count: DiagnosticJSONLineParser.leadingSpaceCount(of: line))
        switch DiagnosticJSONLineParser.classify(line) {
        case .keyValue(let keyValueLine):
            return indentation
                + "<span class=\"json-key\">\(escaped(keyValueLine.quotedKey))</span>"
                + "<span class=\"json-punctuation\">:</span>"
                + highlightedJSONValue(keyValueLine.value)
        case .structural:
            return "<span class=\"json-punctuation\">\(escaped(line))</span>"
        case .value:
            return indentation + highlightedJSONValue(String(line.dropFirst(indentation.count)))
        }
    }

    private func highlightedJSONValue(_ rawValue: String) -> String {
        let leadingSpace = String(rawValue.prefix { $0 == " " })
        var value = String(rawValue.dropFirst(leadingSpace.count))
        let hasTrailingComma = value.hasSuffix(",")
        if hasTrailingComma { value.removeLast() }
        let valueClass: String
        switch value.first {
        case "\"": valueClass = "json-string"
        case "{", "[": valueClass = "json-punctuation"
        case "t", "f", "n": valueClass = "json-literal"
        default: valueClass = "json-number"
        }
        return leadingSpace
            + "<span class=\"\(valueClass)\">\(escaped(value))</span>"
            + (hasTrailingComma ? "<span class=\"json-punctuation\">,</span>" : "")
    }

    private func methodClass(of method: String) -> String {
        ["GET", "POST", "PUT", "PATCH", "DELETE"].contains(method) ? method.lowercased() : "other"
    }

    private func statusClass(of status: SessionReportStatus) -> String {
        switch status {
        case .success: return "success"
        case .redirection: return "redirection"
        case .clientError: return "client-error"
        case .serverError: return "server-error"
        case .transportFailure, .noResponse: return "neutral"
        }
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
    :root{--bg:#f5f6f8;--surface:#fff;--surface-alt:#f0f2f5;--text:#1d2129;--muted:#6b7280;--border:#e2e5ea;--accent:#2563eb;--code-bg:#f7f8fa;--json-key:#1f5fae;--json-string:#0f7b3f;--json-number:#b45309;--json-literal:#7c3aed;--json-punctuation:#6b7280;--success:#15803d;--success-bg:#dcfce7;--redirection:#1d4ed8;--redirection-bg:#dbeafe;--client-error:#a16207;--client-error-bg:#fef3c7;--server-error:#b91c1c;--server-error-bg:#fee2e2;--neutral:#4b5563;--neutral-bg:#e5e7eb;--notice:#b45309}
    @media (prefers-color-scheme:dark){:root{--bg:#0e1014;--surface:#171a20;--surface-alt:#1e222a;--text:#e6e8eb;--muted:#9aa3ae;--border:#2a2f38;--accent:#60a5fa;--code-bg:#111419;--json-key:#7cb4ff;--json-string:#7ee2a8;--json-number:#f5b971;--json-literal:#c4a7ff;--json-punctuation:#8b93a0;--success:#4ade80;--success-bg:#13301e;--redirection:#93c5fd;--redirection-bg:#172a46;--client-error:#fbbf24;--client-error-bg:#3a2a0c;--server-error:#f87171;--server-error-bg:#3d1717;--neutral:#cbd5e1;--neutral-bg:#2a2f38;--notice:#fbbf24}}
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
    .page{max-width:1100px;margin:0 auto;padding:24px 16px 48px}
    h1{margin:0 0 4px;font-size:26px}
    h2{font-size:18px;margin:0 0 12px;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
    h3{margin:0 0 8px;font-size:15px;text-transform:uppercase;letter-spacing:.04em;color:var(--muted)}
    h4{margin:14px 0 6px;font-size:13px;font-weight:600}
    .muted{color:var(--muted);font-weight:400;font-size:13px}
    .report-header,.screen-index,.toolbar{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:18px;margin-bottom:16px}
    .stats{display:flex;gap:12px;margin:16px 0 8px;flex-wrap:wrap}
    .stat{background:var(--surface-alt);border-radius:10px;padding:10px 16px;min-width:96px;display:flex;flex-direction:column}
    .stat-value{font-size:24px;font-weight:700}
    .stat-failed{color:var(--server-error)}
    .stat-label{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.05em}
    .session-id{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--muted);margin:8px 0 0;word-break:break-all}
    .toolbar{display:flex;gap:10px;flex-wrap:wrap;align-items:center;position:sticky;top:8px;z-index:1}
    .toolbar[hidden]{display:none}
    .toolbar input[type=search]{flex:1 1 240px;padding:8px 12px;border-radius:8px;border:1px solid var(--border);background:var(--surface-alt);color:var(--text);font-size:14px}
    .toolbar button{padding:8px 12px;border-radius:8px;border:1px solid var(--border);background:var(--surface-alt);color:var(--text);font-size:13px;cursor:pointer}
    .toggle{font-size:13px;display:flex;gap:6px;align-items:center}
    .screen-index ol{margin:0;padding-left:20px}
    .screen-index li{margin:4px 0}
    .screen-index li .muted{margin-left:8px}
    a{color:var(--accent);text-decoration:none}
    .screen{margin:28px 0}
    .screen[hidden]{display:none}
    .screen-number{display:inline-flex;align-items:center;justify-content:center;min-width:28px;height:28px;border-radius:14px;background:var(--accent);color:#fff;font-size:13px}
    .entry{background:var(--surface);border:1px solid var(--border);border-radius:12px;margin:10px 0;overflow:hidden}
    .entry[hidden]{display:none}
    .entry>summary{list-style:none;cursor:pointer;padding:12px 14px;display:flex;gap:8px;align-items:center;flex-wrap:wrap}
    .entry>summary::-webkit-details-marker{display:none}
    .entry[open]>summary{border-bottom:1px solid var(--border);background:var(--surface-alt)}
    .number{color:var(--muted);font-size:12px;min-width:28px}
    .badge{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;padding:3px 8px;border-radius:6px;background:var(--neutral-bg);color:var(--neutral)}
    .method-get{background:var(--redirection-bg);color:var(--redirection)}
    .method-post{background:var(--success-bg);color:var(--success)}
    .method-put,.method-patch{background:var(--client-error-bg);color:var(--client-error)}
    .method-delete{background:var(--server-error-bg);color:var(--server-error)}
    .status-success{background:var(--success-bg);color:var(--success)}
    .status-redirection{background:var(--redirection-bg);color:var(--redirection)}
    .status-client-error{background:var(--client-error-bg);color:var(--client-error)}
    .status-server-error{background:var(--server-error-bg);color:var(--server-error)}
    .url{flex:1 1 280px;font:13px ui-monospace,SFMono-Regular,Menlo,monospace;word-break:break-all}
    .meta{color:var(--muted);font-size:12px}
    .entry-content{padding:6px 14px 14px;display:grid;gap:8px}
    .message{border-top:1px dashed var(--border);padding-top:12px}
    .message:first-child{border-top:none}
    .pairs{display:grid;grid-template-columns:minmax(120px,max-content) 1fr;gap:4px 14px;margin:0;font:13px ui-monospace,SFMono-Regular,Menlo,monospace}
    .pairs dt{color:var(--json-key)}
    .pairs dd{margin:0;word-break:break-all}
    .code{background:var(--code-bg);border:1px solid var(--border);border-radius:8px;padding:12px;margin:0;font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;overflow-wrap:anywhere;max-height:560px;overflow:auto}
    .code.error{color:var(--server-error)}
    .placeholder{color:var(--muted);font-style:italic;margin:4px 0}
    .notice{color:var(--notice);font-size:13px;margin:4px 0 8px}
    .json-key{color:var(--json-key)}
    .json-string{color:var(--json-string)}
    .json-number{color:var(--json-number)}
    .json-literal{color:var(--json-literal)}
    .json-punctuation{color:var(--json-punctuation)}
    @media (max-width:600px){.page{padding:16px 12px 32px}.pairs{grid-template-columns:1fr}.pairs dd{margin-bottom:6px}}
    """

    private static let script = """
    (function(){var toolbar=document.getElementById('toolbar');toolbar.hidden=false;var filter=document.getElementById('filter');var failuresOnly=document.getElementById('failures-only');var entries=Array.prototype.slice.call(document.querySelectorAll('.entry'));var screens=Array.prototype.slice.call(document.querySelectorAll('.screen'));function apply(){var query=filter.value.trim().toLowerCase();entries.forEach(function(entry){var matchesQuery=!query||entry.dataset.search.indexOf(query)>=0;var matchesFailure=!failuresOnly.checked||entry.dataset.failure==='true';entry.hidden=!(matchesQuery&&matchesFailure);});screens.forEach(function(screen){screen.hidden=!screen.querySelector('.entry:not([hidden])');});}filter.addEventListener('input',apply);failuresOnly.addEventListener('change',apply);toolbar.addEventListener('click',function(event){var action=event.target.dataset&&event.target.dataset.action;if(!action){return;}entries.forEach(function(entry){entry.open=action==='expand';});});})();
    """
}
