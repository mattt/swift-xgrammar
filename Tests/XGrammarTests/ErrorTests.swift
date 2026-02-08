import Testing

@testable import XGrammar

@Suite("Error Tests")
struct ErrorTests {
    @Test func errorDescriptionsMatchMessages() {
        let message = "message"
        let cases: [XGrammarError] = [
            .deserializeVersion(message),
            .deserializeFormat(message),
            .invalidJSON(message),
            .invalidStructuralTag(message),
            .invalidJSONSchema(message),
            .nativeError(message),
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
