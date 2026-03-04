import XCTest
@testable import mdprev

final class CodeFenceMetadataParserTests: XCTestCase {
    func testExtractParsesLanguageOnlyFence() {
        let markdown = """
        ```python
        print("hello")
        ```
        """

        let metadata = CodeFenceMetadataParser.extract(from: markdown)

        XCTAssertEqual(metadata, [CodeFenceMetadata(language: "python", fileName: nil)])
    }

    func testExtractParsesDocusaurusStyleTitleMetadata() {
        let markdown = """
        ```tsx {1,3-4} showLineNumbers title="/src/App.tsx"
        export function App() {}
        ```
        """

        let metadata = CodeFenceMetadataParser.extract(from: markdown)

        XCTAssertEqual(metadata, [CodeFenceMetadata(language: "tsx", fileName: "/src/App.tsx")])
    }

    func testExtractParsesPandocAttributes() {
        let markdown = """
        ``` {.py filename="test.py"}
        print("hello")
        ```
        """

        let metadata = CodeFenceMetadataParser.extract(from: markdown)

        XCTAssertEqual(metadata, [CodeFenceMetadata(language: "py", fileName: "test.py")])
    }
}
