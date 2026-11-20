import XCTest
@testable import DiagnosticSDK

final class HTTPPayloadFormatterTests: XCTestCase {

    func testFormFieldsAreDecodedOnePerLine() {
        let body = Data("username=ada%40example.com&scope=read+write".utf8)

        let formattedBody = HTTPPayloadFormatter.format(bodyData: body, contentType: "application/x-www-form-urlencoded")

        XCTAssertEqual(plainText(of: formattedBody), "username = ada@example.com\nscope = read write")
    }

    func testXMLIsIndented() {
        let body = Data(#"<catalog><book id="1"><title>Swift</title></book></catalog>"#.utf8)

        let formattedBody = HTTPPayloadFormatter.format(bodyData: body, contentType: "application/xml")

        XCTAssertEqual(plainText(of: formattedBody), """
        <catalog>
          <book id="1">
            <title>Swift</title>
          </book>
        </catalog>
        """)
    }

    func testJSONLinesAreShownAsAJSONArray() {
        let body = Data("{\"id\":1}\n{\"id\":2}\n".utf8)

        let formattedBody = HTTPPayloadFormatter.format(bodyData: body, contentType: "application/x-ndjson")

        guard case .json(let document) = formattedBody else {
            return XCTFail("Expected a JSON document")
        }
        XCTAssertTrue(document.prettyJSON.hasPrefix("["))
    }

    func testMultipartTextPartsAreReadableAndBinaryPartsSummarized() {
        let body = Data("--XYZ\r\nContent-Disposition: form-data; name=\"title\"\r\n\r\nHello\r\n--XYZ\r\nContent-Disposition: form-data; name=\"file\"; filename=\"a.bin\"\r\nContent-Type: application/octet-stream\r\n\r\n\u{0}\u{1}\u{2}\r\n--XYZ--\r\n".utf8)

        let summary = plainText(of: HTTPPayloadFormatter.format(bodyData: body, contentType: "multipart/form-data; boundary=XYZ"))

        XCTAssertTrue(summary?.contains("Part 1\nContent-Disposition: form-data; name=\"title\"\n\nHello") == true)
        XCTAssertTrue(summary?.contains("Part 2") == true)
        XCTAssertTrue(summary?.contains("[Binary content, 3 bytes]") == true)
        XCTAssertFalse(summary?.contains("\u{0}") == true)
    }

    func testJSONSlashesAreNotEscaped() {
        let formattedBody = HTTPPayloadFormatter.format(bodyData: Data(#"{"url":"https://example.com/a"}"#.utf8), contentType: "application/json")

        guard case .json(let document) = formattedBody else {
            return XCTFail("Expected a JSON document")
        }
        XCTAssertTrue(document.prettyJSON.contains("https://example.com/a"))
    }

    private func plainText(of formattedBody: FormattedHTTPBody) -> String? {
        guard case .plain(let text) = formattedBody else { return nil }
        return text
    }
}
