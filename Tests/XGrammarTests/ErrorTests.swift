import Cxgrammar
import Testing

@testable import XGrammar

@Suite("Error Tests")
struct ErrorTests {
    @Test func errorDescriptionsMatchMessages() {
        let message = "message"
        let cases: [XGrammarError] = [
            XGrammarError(kind: XGRAMMAR_ERROR_DESERIALIZE_VERSION, message: message),
            XGrammarError(kind: XGRAMMAR_ERROR_DESERIALIZE_FORMAT, message: message),
            XGrammarError(kind: XGRAMMAR_ERROR_INVALID_JSON, message: message),
            XGrammarError(kind: XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG, message: message),
            XGrammarError(kind: XGRAMMAR_ERROR_INVALID_JSON_SCHEMA, message: message),
            XGrammarError(kind: XGRAMMAR_ERROR_UNKNOWN, message: message),
        ]

        for error in cases {
            #expect(error.description == message)
            #expect(error.errorDescription == message)
        }
    }

    @Test func invalidJSONErrorTypeFromTokenizer() {
        do {
            _ = try TokenizerInfo(jsonData: "not json".data(using: .utf8)!)
            #expect(Bool(false))
        } catch let error as XGrammarError {
            switch error {
            case .invalidJSON:
                #expect(Bool(true))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }
}
