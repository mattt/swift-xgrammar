import Cxgrammar
import CxxStdlib

public enum XGrammarError: Error, CustomStringConvertible {
    case nativeError(String)

    public var description: String {
        switch self {
        case .nativeError(let message):
            return message
        }
    }
}

private typealias CxxGrammar = xgrammar.Grammar
private typealias CxxTokenizerInfo = xgrammar.TokenizerInfo
private typealias CxxCompiledGrammar = xgrammar.CompiledGrammar
private typealias CxxGrammarCompiler = xgrammar.GrammarCompiler
private typealias CxxGrammarMatcher = xgrammar.GrammarMatcher
private typealias CxxVocabType = xgrammar.VocabType

public enum VocabType {
    case raw
    case byteFallback
    case byteLevel

    fileprivate var cxxValue: CxxVocabType {
        switch self {
        case .raw:
            return .RAW
        case .byteFallback:
            return .BYTE_FALLBACK
        case .byteLevel:
            return .BYTE_LEVEL
        }
    }

    fileprivate init(_ cxxValue: CxxVocabType) {
        switch cxxValue {
        case .RAW:
            self = .raw
        case .BYTE_FALLBACK:
            self = .byteFallback
        case .BYTE_LEVEL:
            self = .byteLevel
        default:
            self = .raw
        }
    }
}

public struct Grammar {
    fileprivate var raw: CxxGrammar

    fileprivate init(raw: CxxGrammar) {
        self.raw = raw
    }

    public func toString() -> String {
        String(raw.ToString())
    }

    public func serializeJSON() -> String {
        String(raw.SerializeJSON())
    }

    public static func deserializeJSON(_ json: String) throws -> Grammar {
        var result = CxxGrammar(xgrammar.NullObj())
        var error = std.string()
        let ok = xgrammar.swift_api.GrammarDeserializeJSON(std.string(json), &result, &error)
        if !ok {
            throw XGrammarError.nativeError(String(error))
        }
        return Grammar(raw: result)
    }

    public static func fromEBNF(_ ebnf: String, rootRuleName: String = "root") -> Grammar {
        Grammar(raw: CxxGrammar.FromEBNF(std.string(ebnf), std.string(rootRuleName)))
    }

    public static func fromRegex(_ regex: String, printConvertedEBNF: Bool = false) -> Grammar {
        Grammar(raw: CxxGrammar.FromRegex(std.string(regex), printConvertedEBNF))
    }

    public static func fromJSONSchema(
        _ schema: String,
        anyWhitespace: Bool = true,
        strictMode: Bool = true,
        printConvertedEBNF: Bool = false
    ) -> Grammar {
        Grammar(
            raw: xgrammar.swift_api.GrammarFromJSONSchemaBasic(
                std.string(schema),
                anyWhitespace,
                strictMode,
                printConvertedEBNF
            )
        )
    }

    public static func fromStructuralTag(_ structuralTagJSON: String) throws -> Grammar {
        var result = CxxGrammar(xgrammar.NullObj())
        var error = std.string()
        let ok = xgrammar.swift_api.GrammarFromStructuralTag(
            std.string(structuralTagJSON),
            &result,
            &error
        )
        if !ok {
            throw XGrammarError.nativeError(String(error))
        }
        return Grammar(raw: result)
    }

    public static func builtinJSONGrammar() -> Grammar {
        Grammar(raw: CxxGrammar.BuiltinJSONGrammar())
    }

    public static func union(_ grammars: [Grammar]) -> Grammar {
        let rawGrammars = grammars.map { $0.raw }
        return rawGrammars.withUnsafeBufferPointer { buffer in
            Grammar(
                raw: xgrammar.swift_api.GrammarUnionFromArray(
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            )
        }
    }

    public static func concat(_ grammars: [Grammar]) -> Grammar {
        let rawGrammars = grammars.map { $0.raw }
        return rawGrammars.withUnsafeBufferPointer { buffer in
            Grammar(
                raw: xgrammar.swift_api.GrammarConcatFromArray(
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            )
        }
    }
}

public struct TokenizerInfo {
    fileprivate var raw: CxxTokenizerInfo

    fileprivate init(raw: CxxTokenizerInfo) {
        self.raw = raw
    }

    public init(
        encodedVocab: [String],
        vocabType: VocabType = .raw,
        vocabSize: Int? = nil,
        stopTokenIds: [Int32]? = nil,
        addPrefixSpace: Bool = false
    ) {
        let encodedStrings = encodedVocab.map { std.string($0) }
        let stopTokens = stopTokenIds ?? []
        self.raw = encodedStrings.withUnsafeBufferPointer { encodedBuffer in
            stopTokens.withUnsafeBufferPointer { stopBuffer in
                xgrammar.swift_api.CreateTokenizerInfoFromArray(
                    encodedBuffer.baseAddress,
                    Int32(encodedBuffer.count),
                    vocabType.cxxValue,
                    Int32(vocabSize ?? 0),
                    vocabSize != nil,
                    stopBuffer.baseAddress,
                    Int32(stopBuffer.count),
                    stopTokenIds != nil,
                    addPrefixSpace
                )
            }
        }
    }

    public var vocabType: VocabType {
        VocabType(raw.GetVocabType())
    }

    public var addPrefixSpace: Bool {
        raw.GetAddPrefixSpace()
    }

    public var vocabSize: Int {
        Int(raw.GetVocabSize())
    }

    public var decodedVocab: [String] {
        var result: [String] = []
        let count = Int(xgrammar.swift_api.TokenizerInfoDecodedVocabCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                String(xgrammar.swift_api.TokenizerInfoDecodedVocabAt(raw, Int32(index)))
            )
        }
        return result
    }

    public var stopTokenIds: [Int32] {
        var result: [Int32] = []
        let count = Int(xgrammar.swift_api.TokenizerInfoStopTokenIdsCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                xgrammar.swift_api.TokenizerInfoStopTokenIdAt(raw, Int32(index))
            )
        }
        return result
    }

    public var specialTokenIds: [Int32] {
        var result: [Int32] = []
        let count = Int(xgrammar.swift_api.TokenizerInfoSpecialTokenIdsCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                xgrammar.swift_api.TokenizerInfoSpecialTokenIdAt(raw, Int32(index))
            )
        }
        return result
    }

    public func dumpMetadata() -> String {
        String(raw.DumpMetadata())
    }

    public func serializeJSON() -> String {
        String(raw.SerializeJSON())
    }

    public static func deserializeJSON(_ json: String) throws -> TokenizerInfo {
        var result = CxxTokenizerInfo(xgrammar.NullObj())
        var error = std.string()
        let ok = xgrammar.swift_api.TokenizerInfoDeserializeJSON(std.string(json), &result, &error)
        if !ok {
            throw XGrammarError.nativeError(String(error))
        }
        return TokenizerInfo(raw: result)
    }

    public static func fromVocabAndMetadata(
        encodedVocab: [String],
        metadata: String
    ) -> TokenizerInfo {
        let encodedStrings = encodedVocab.map { std.string($0) }
        let rawInfo = encodedStrings.withUnsafeBufferPointer { buffer in
            xgrammar.swift_api.TokenizerInfoFromVocabAndMetadata(
                buffer.baseAddress,
                Int32(buffer.count),
                std.string(metadata)
            )
        }
        return TokenizerInfo(raw: rawInfo)
    }

    public static func detectMetadataFromHF(_ backendString: String) -> String {
        String(CxxTokenizerInfo.DetectMetadataFromHF(std.string(backendString)))
    }
}

public struct CompiledGrammar {
    fileprivate var raw: CxxCompiledGrammar

    fileprivate init(raw: CxxCompiledGrammar) {
        self.raw = raw
    }

    public func grammar() -> Grammar {
        Grammar(raw: raw.GetGrammar())
    }

    public func tokenizerInfo() -> TokenizerInfo {
        TokenizerInfo(raw: raw.GetTokenizerInfo())
    }

    public func memorySizeBytes() -> Int {
        Int(raw.MemorySizeBytes())
    }

    public func serializeJSON() -> String {
        String(raw.SerializeJSON())
    }

    public static func deserializeJSON(
        _ json: String,
        tokenizerInfo: TokenizerInfo
    ) throws -> CompiledGrammar {
        var result = CxxCompiledGrammar(xgrammar.NullObj())
        var error = std.string()
        let ok = xgrammar.swift_api.CompiledGrammarDeserializeJSON(
            std.string(json),
            tokenizerInfo.raw,
            &result,
            &error
        )
        if !ok {
            throw XGrammarError.nativeError(String(error))
        }
        return CompiledGrammar(raw: result)
    }
}

public struct GrammarCompiler {
    fileprivate var raw: CxxGrammarCompiler

    public init(
        tokenizerInfo: TokenizerInfo,
        maxThreads: Int = 8,
        cacheEnabled: Bool = true,
        maxMemoryBytes: Int64 = -1
    ) {
        self.raw = CxxGrammarCompiler(
            tokenizerInfo.raw,
            Int32(maxThreads),
            cacheEnabled,
            maxMemoryBytes
        )
    }

    public mutating func compileJSONSchema(
        _ schema: String,
        anyWhitespace: Bool = true,
        strictMode: Bool = true
    ) -> CompiledGrammar {
        CompiledGrammar(
            raw: xgrammar.swift_api.GrammarCompilerCompileJSONSchemaBasic(
                &raw,
                std.string(schema),
                anyWhitespace,
                strictMode
            )
        )
    }

    public mutating func compileBuiltinJSONGrammar() -> CompiledGrammar {
        CompiledGrammar(raw: raw.CompileBuiltinJSONGrammar())
    }

    public mutating func compileGrammar(_ grammar: Grammar) -> CompiledGrammar {
        CompiledGrammar(raw: raw.CompileGrammar(grammar.raw))
    }

    public mutating func compileGrammar(
        ebnf: String,
        rootRuleName: String = "root"
    ) -> CompiledGrammar {
        CompiledGrammar(raw: raw.CompileGrammar(std.string(ebnf), std.string(rootRuleName)))
    }

    public mutating func compileStructuralTag(_ structuralTagJSON: String) -> CompiledGrammar {
        CompiledGrammar(raw: raw.CompileStructuralTag(std.string(structuralTagJSON)))
    }

    public mutating func compileRegex(_ regex: String) -> CompiledGrammar {
        CompiledGrammar(raw: raw.CompileRegex(std.string(regex)))
    }

    public mutating func clearCache() {
        raw.ClearCache()
    }

    public func cacheSizeBytes() -> Int64 {
        raw.GetCacheSizeBytes()
    }

    public func cacheLimitBytes() -> Int64 {
        raw.CacheLimitBytes()
    }
}

public struct GrammarMatcher {
    fileprivate var raw: CxxGrammarMatcher

    public init(
        compiledGrammar: CompiledGrammar,
        overrideStopTokens: [Int32]? = nil,
        terminateWithoutStopToken: Bool = false,
        maxRollbackTokens: Int = -1
    ) {
        let stopTokens = overrideStopTokens ?? []
        self.raw = stopTokens.withUnsafeBufferPointer { buffer in
            xgrammar.swift_api.CreateGrammarMatcherFromArray(
                compiledGrammar.raw,
                buffer.baseAddress,
                Int32(buffer.count),
                overrideStopTokens != nil,
                terminateWithoutStopToken,
                Int32(maxRollbackTokens)
            )
        }
    }

    public mutating func acceptToken(_ tokenId: Int32, debugPrint: Bool = false) -> Bool {
        raw.AcceptToken(tokenId, debugPrint)
    }

    public mutating func acceptString(_ input: String, debugPrint: Bool = false) -> Bool {
        raw.AcceptString(std.string(input), debugPrint)
    }

    public mutating func fillNextTokenBitmask(
        vocabSize: Int,
        index: Int = 0,
        debugPrint: Bool = false
    ) -> (needsApplying: Bool, bitmask: [Int32]) {
        let bitmaskCount = Int(xgrammar.GetBitmaskSize(Int32(vocabSize)))
        var bitmask = Array(repeating: Int32(0), count: bitmaskCount)
        let needsApplying = bitmask.withUnsafeMutableBufferPointer { buffer in
            xgrammar.swift_api.FillNextTokenBitmask(
                &raw,
                buffer.baseAddress,
                Int32(bitmaskCount),
                Int32(index),
                debugPrint
            )
        }
        return (needsApplying, bitmask)
    }

    public mutating func findJumpForwardString() -> String {
        String(raw.FindJumpForwardString())
    }

    public mutating func rollback(_ numTokens: Int = 1) {
        raw.Rollback(Int32(numTokens))
    }

    public func isTerminated() -> Bool {
        raw.IsTerminated()
    }

    public mutating func reset() {
        raw.Reset()
    }

    public func maxRollbackTokens() -> Int {
        Int(raw.GetMaxRollbackTokens())
    }

    public func stopTokenIds() -> [Int] {
        var result: [Int] = []
        let count = Int(xgrammar.swift_api.GrammarMatcherStopTokenIdsCount(raw))
        result.reserveCapacity(count)
        for index in 0..<count {
            result.append(
                Int(xgrammar.swift_api.GrammarMatcherStopTokenIdAt(raw, Int32(index)))
            )
        }
        return result
    }

    public func debugPrintInternalState() -> String {
        String(raw._DebugPrintInternalState())
    }
}

public enum XGrammarConfig {
    public static func setMaxRecursionDepth(_ depth: Int) {
        xgrammar.SetMaxRecursionDepth(Int32(depth))
    }

    public static func getMaxRecursionDepth() -> Int {
        Int(xgrammar.GetMaxRecursionDepth())
    }

    public static func serializationVersion() -> String {
        String(xgrammar.GetSerializationVersion())
    }
}
