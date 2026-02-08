import Testing

@testable import XGrammar

@Suite("Configuration Tests")
struct ConfigurationTests {
    @Test func maxRecursionDepthRoundTrip() {
        let original = XGrammar.Configuration.maxRecursionDepth
        defer { XGrammar.Configuration.maxRecursionDepth = original }

        XGrammar.Configuration.maxRecursionDepth = original + 1
        #expect(XGrammar.Configuration.maxRecursionDepth == original + 1)
        #expect(XGrammar.Configuration.maxRecursionDepth > 0)
    }

    @Test func serializationVersionIsNonEmpty() {
        #expect(!XGrammar.Configuration.serializationVersion.isEmpty)
    }
}
