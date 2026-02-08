import Testing

@testable import XGrammar

@Suite("Regex Grammar Tests")
struct RegexGrammarTests {
    private func assertRegex(
        _ pattern: String,
        accepts: [String],
        rejects: [String]
    ) async {
        let tokenizer = TokenizerInfo(encodedVocab: ["a", "b", "c", "0", "1", "2", "-", "m"])
        let grammar = Grammar(regex: pattern)

        for value in accepts {
            let matcher = Grammar.Matcher(
                await grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(accepted)
            #expect(matcher.isTerminated)
        }

        for value in rejects {
            let matcher = Grammar.Matcher(
                await grammar.compiled(for: tokenizer),
                terminatesWithoutStopToken: true
            )
            let accepted = matcher.accept(value)
            #expect(!accepted || !matcher.isTerminated)
        }
    }

    @Test func literalRegex() async {
        await assertRegex("abc", accepts: ["abc"], rejects: ["ab", "abcd"])
    }

    @Test func characterClasses() async {
        await assertRegex("[a-z]", accepts: ["m"], rejects: ["1"])
        await assertRegex("[^0-9]", accepts: ["a"], rejects: ["2"])
    }

    @Test func quantifiers() async {
        await assertRegex("a?", accepts: ["", "a"], rejects: ["aa"])
        await assertRegex("a*", accepts: ["", "a", "aa"], rejects: ["b"])
        await assertRegex("a+", accepts: ["a", "aa"], rejects: [""])
        await assertRegex("a{2,4}", accepts: ["aa", "aaaa"], rejects: ["a", "aaaaa"])
    }

    @Test func alternation() async {
        await assertRegex("a|b", accepts: ["a", "b"], rejects: ["c"])
    }

    @Test func complexPattern() async {
        await assertRegex("\\d{4}-\\d{2}-\\d{2}", accepts: ["2024-01-02"], rejects: ["2024-1-02"])
    }
}
