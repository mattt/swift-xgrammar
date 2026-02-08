import Testing

@testable import XGrammar

@Suite("Regex Grammar Tests")
struct RegexGrammarTests {
    private func assertRegex(
        _ pattern: String,
        accepts: [String],
        rejects: [String]
    ) async throws {
        let tokenizer = try TokenizerInfo(encodedVocab: ["a", "b", "c", "0", "1", "2", "-", "m"])
        let grammar = Grammar(regex: pattern)

        for value in accepts {
            let matcher = try Grammar.Matcher(
                await grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(accepted)
            #expect(matcher.isTerminated)
        }

        for value in rejects {
            let matcher = try Grammar.Matcher(
                await grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(!accepted || !matcher.isTerminated)
        }
    }

    @Test func literalRegex() async throws {
        try await assertRegex("abc", accepts: ["abc"], rejects: ["ab", "abcd"])
    }

    @Test func characterClasses() async throws {
        try await assertRegex("[a-z]", accepts: ["m"], rejects: ["1"])
        try await assertRegex("[^0-9]", accepts: ["a"], rejects: ["2"])
    }

    @Test func quantifiers() async throws {
        try await assertRegex("a?", accepts: ["", "a"], rejects: ["aa"])
        try await assertRegex("a*", accepts: ["", "a", "aa"], rejects: ["b"])
        try await assertRegex("a+", accepts: ["a", "aa"], rejects: [""])
        try await assertRegex("a{2,4}", accepts: ["aa", "aaaa"], rejects: ["a", "aaaaa"])
    }

    @Test func alternation() async throws {
        try await assertRegex("a|b", accepts: ["a", "b"], rejects: ["c"])
    }

    @Test func complexPattern() async throws {
        try await assertRegex("\\d{4}-\\d{2}-\\d{2}", accepts: ["2024-01-02"], rejects: ["2024-1-02"])
    }
}
