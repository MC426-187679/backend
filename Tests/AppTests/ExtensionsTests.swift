@testable import App
import XCTest

final class ExtensionsTests: XCTestCase {

    func testStringNormalized() {
        XCTAssertEqual("Sempre há uma solução".normalized(), "sempre ha uma solucao")
        XCTAssertEqual("sempre ha uma solucao".normalized(), "sempre ha uma solucao")
    }

    func testStringSplitWords() {
        XCTAssertEqual("   some    especially useful\n\ntext".splitWords(), ["some", "especially", "useful", "text"])
        XCTAssertEqual("someespeciallyusefultext".splitWords(), ["someespeciallyusefultext"])
    }

    func testStringReducingWhitespace() {
        XCTAssertEqual("   some    especially useful\n\ntext".reducingWhitespace(), "some especially useful text")
        XCTAssertEqual("some especially useful text".reducingWhitespace(), "some especially useful text")
    }

    func testStringReplacingNonAlphaNum() {
        XCTAssertEqual("file: /Resources.txt".replacingNonAlphaNum(), "file___Resources_txt")
        XCTAssertEqual("file___Resources_txt".replacingNonAlphaNum(), "file___Resources_txt")
    }
}
