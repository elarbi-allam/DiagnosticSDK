import XCTest
@testable import DiagnosticSDK

final class CapturedBodyTests: XCTestCase {

    func testDeclaredContentTypesAreClassified() {
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/json; charset=utf-8"), .json)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/problem+json"), .json)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/x-ndjson"), .jsonLines)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/x-www-form-urlencoded"), .formURLEncoded)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/soap+xml"), .xml)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "text/html; charset=ISO-8859-1"), .html)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "text/csv"), .plainText)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/graphql"), .plainText)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "multipart/form-data; boundary=abc"), .multipart)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "image/png"), .image)
        XCTAssertEqual(NetworkContentType.kind(ofDeclaredContentType: "application/pdf"), .binary)
        XCTAssertNil(NetworkContentType.kind(ofDeclaredContentType: nil))
    }

    func testUndeclaredContentTypeIsSniffed() {
        XCTAssertEqual(NetworkContentType.kind(ofContentType: nil, sniffing: Data(#" {"a":1}"#.utf8)), .json)
        XCTAssertEqual(NetworkContentType.kind(ofContentType: nil, sniffing: Data("<root/>".utf8)), .xml)
        XCTAssertEqual(NetworkContentType.kind(ofContentType: nil, sniffing: Data("plain".utf8)), .plainText)
        XCTAssertEqual(NetworkContentType.kind(ofContentType: nil, sniffing: Data([0x89, 0x50, 0x4E, 0x47, 0x00])), .binary)
    }

    func testTextualBodyIsStoredAsText() {
        let body = CapturedBody(data: Data("a=1&b=two".utf8), contentType: "application/x-www-form-urlencoded")

        XCTAssertEqual(body.storedValue, "a=1&b=two")
        XCTAssertEqual(body.encoding, .text)
        XCTAssertEqual(body.sizeBytes, 9)
        XCTAssertFalse(body.isTruncated)
        XCTAssertNil(body.omission)
    }

    func testTextThatLooksLikeBase64RoundTripsUnchanged() {
        let body = CapturedBody(data: Data("true".utf8), contentType: "text/plain")

        let restoredData = CapturedBody.data(fromStoredValue: body.storedValue, encoding: body.encoding, contentType: "text/plain")

        XCTAssertEqual(restoredData, Data("true".utf8))
    }

    func testDeclaredCharsetRoundTrips() {
        let contentType = "text/html; charset=ISO-8859-1"
        let originalData = "café".data(using: .isoLatin1)!

        let body = CapturedBody(data: originalData, contentType: contentType)
        let restoredData = CapturedBody.data(fromStoredValue: body.storedValue, encoding: body.encoding, contentType: contentType)

        XCTAssertEqual(body.storedValue, "café")
        XCTAssertEqual(restoredData, originalData)
    }

    func testMultipartBodyIsStoredAsBase64() {
        let multipartData = Data("--abc\r\nContent-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n--abc--".utf8)

        let body = CapturedBody(data: multipartData, contentType: "multipart/form-data; boundary=abc")

        XCTAssertEqual(body.encoding, .base64)
        XCTAssertEqual(Data(base64Encoded: body.storedValue ?? ""), multipartData)
    }

    func testBinaryBodyIsOmittedButKeepsItsSize() {
        let body = CapturedBody(data: Data(repeating: 0xFF, count: 512), contentType: "application/pdf")

        XCTAssertNil(body.storedValue)
        XCTAssertEqual(body.omission, .binaryContent)
        XCTAssertEqual(body.sizeBytes, 512)
    }

    func testOversizedBodyIsTruncatedWithItsOriginalSize() {
        let oversizedData = Data(repeating: UInt8(ascii: "a"), count: CapturedBody.maximumStoredByteCount + 10)

        let body = CapturedBody(data: oversizedData, contentType: "text/plain")

        XCTAssertTrue(body.isTruncated)
        XCTAssertEqual(body.sizeBytes, oversizedData.count)
        XCTAssertEqual(body.storedValue?.utf8.count, CapturedBody.maximumStoredByteCount)
    }

    func testTruncationNeverSplitsAMultiByteCharacter() {
        var data = Data(repeating: UInt8(ascii: "a"), count: CapturedBody.maximumStoredByteCount - 1)
        data.append(contentsOf: Array("é".utf8))

        let body = CapturedBody(data: data, contentType: "text/plain")

        XCTAssertTrue(body.isTruncated)
        XCTAssertEqual(body.encoding, .text)
        XCTAssertEqual(body.storedValue?.utf8.count, CapturedBody.maximumStoredByteCount - 1)
    }

    func testUnobservedTextualBodyKeepsItsSizeAndReason() {
        let body = CapturedBody(data: nil, receivedByteCount: 2048, contentType: "application/json")

        XCTAssertNil(body.storedValue)
        XCTAssertEqual(body.sizeBytes, 2048)
        XCTAssertEqual(body.omission, .notObservableForTaskType)
    }

    func testUnobservedBinaryBodyIsReportedAsBinary() {
        let body = CapturedBody(data: nil, receivedByteCount: 2048, contentType: "application/octet-stream")

        XCTAssertEqual(body.omission, .binaryContent)
        XCTAssertEqual(body.sizeBytes, 2048)
    }

    func testEmptyBodyStoresNothing() {
        let body = CapturedBody(data: nil, contentType: "application/json")

        XCTAssertNil(body.storedValue)
        XCTAssertNil(body.omission)
        XCTAssertEqual(body.sizeBytes, 0)
    }

    func testLegacyRequestBodyIsReadAsText() {
        let request = RequestDetails(url: "https://example.com", method: "POST", headers: nil, bodyBase64: "abcd", bodySizeBytes: 4)

        XCTAssertEqual(request.bodyData, Data("abcd".utf8))
    }
}
