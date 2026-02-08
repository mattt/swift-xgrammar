import Testing

@testable import XGrammar

@Suite("Configuration Tests")
struct ConfigurationTests {
    @Test func maxRecursionDepthRoundTrip() {
        let original = Grammar.Configuration.maxRecursionDepth
        defer { Grammar.Configuration.maxRecursionDepth = original }

        Grammar.Configuration.maxRecursionDepth = original + 1
        #expect(Grammar.Configuration.maxRecursionDepth == original + 1)
        #expect(Grammar.Configuration.maxRecursionDepth > 0)
    }

    @Test func serializationVersionIsNonEmpty() {
        #expect(!Grammar.Configuration.serializationVersion.isEmpty)
    }
}
