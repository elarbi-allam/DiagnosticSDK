import XCTest
@testable import DiagnosticSDK

final class DecodedTokenExtractorTests: XCTestCase {

    func testJWTInsideATokenFieldIsDecoded() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJl"
        let body = Data(#"{"access_token":"\#(jwt)"}"#.utf8)

        let tokens = DecodedTokenExtractor.extract(headers: nil, bodyData: body, sourcePrefix: "Response")

        XCTAssertEqual(tokens.map(\.rawToken), [jwt])
    }

    func testLongTokenValueWithoutDotsIsScannedInLinearTime() {
        let longValue = String(repeating: "QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVo", count: 6000)
        let body = Data(#"{"token":"\#(longValue)"}"#.utf8)
        let startDate = Date()

        let tokens = DecodedTokenExtractor.extract(headers: nil, bodyData: body, sourcePrefix: "Response")

        XCTAssertTrue(tokens.isEmpty)
        XCTAssertLessThan(Date().timeIntervalSince(startDate), 1)
    }
}
