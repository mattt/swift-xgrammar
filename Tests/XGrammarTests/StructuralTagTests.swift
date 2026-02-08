import Testing

@testable import XGrammar

@Suite("Structural Tag Tests")
struct StructuralTagTests {
    @Test func validConstStringStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"const_string","value":"Hello"}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func validJSONSchemaStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"json_schema","json_schema":{"type":"string"}}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func validRegexStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"regex","pattern":"a+"}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func validSequenceStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"sequence","elements":[{"type":"const_string","value":"a"},{"type":"const_string","value":"b"}]}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func validOrStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"or","elements":[{"type":"const_string","value":"a"},{"type":"const_string","value":"b"}]}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func validTagStructuralTag() throws {
        let json = #"""
            {"type":"structural_tag","format":{"type":"tag","begin":"<think>","content":{"type":"any_text"},"end":"</think>"}}
            """#
        let grammar = try Grammar(structuralTag: json)
        #expect(!grammar.description.isEmpty)
    }

    @Test func invalidStructuralTagDefinitionThrows() {
        let json = #"""
            {"type":"structural_tag","format":{"type":"tag","begin":"<a>","end":"</a>"}}
            """#
        do {
            _ = try Grammar(structuralTag: json)
            #expect(Bool(false))
        } catch let error as XGrammarError {
            switch error {
            case .invalidStructuralTag, .invalidJSONSchema:
                #expect(Bool(true))
            default:
                #expect(Bool(false))
            }
        } catch {
            #expect(Bool(false))
        }
    }

    @Test func invalidJSONThrows() {
        do {
            _ = try Grammar(structuralTag: "not json")
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
