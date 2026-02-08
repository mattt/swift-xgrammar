import Testing

@testable import XGrammar

@Suite("Regex Grammar Tests")
struct RegexGrammarTests {
    private func assertRegex(
        _ pattern: String,
        accepts: [String],
        rejects: [String]
    ) {
        let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c", "0", "1", "2", "-", "m"])
        let grammar = Grammar(regex: pattern)

        for value in accepts {
            var matcher = Grammar.Matcher(
                grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(accepted)
            #expect(matcher.isTerminated)
        }

        for value in rejects {
            var matcher = Grammar.Matcher(
                grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(!accepted || !matcher.isTerminated)
        }
    }

    @Test func literalRegex() {
        assertRegex("abc", accepts: ["abc"], rejects: ["ab", "abcd"])
    }

    @Test func characterClasses() {
        assertRegex("[a-z]", accepts: ["m"], rejects: ["1"])
        assertRegex("[^0-9]", accepts: ["a"], rejects: ["2"])
    }

    @Test func quantifiers() {
        assertRegex("a?", accepts: ["", "a"], rejects: ["aa"])
        assertRegex("a*", accepts: ["", "a", "aa"], rejects: ["b"])
        assertRegex("a+", accepts: ["a", "aa"], rejects: [""])
        assertRegex("a{2,4}", accepts: ["aa", "aaaa"], rejects: ["a", "aaaaa"])
    }

    @Test func alternation() {
        assertRegex("a|b", accepts: ["a", "b"], rejects: ["c"])
    }

    @Test func complexPattern() {
        assertRegex("\\d{4}-\\d{2}-\\d{2}", accepts: ["2024-01-02"], rejects: ["2024-1-02"])
    }
}
