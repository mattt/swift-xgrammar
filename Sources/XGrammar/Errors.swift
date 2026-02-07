import Cxgrammar
import Foundation

/// Errors surfaced by the XGrammar Swift API.
public enum XGrammarError: Error, CustomStringConvertible, LocalizedError, Sendable {
    case deserializeVersion(String)
    case deserializeFormat(String)
    case invalidJSON(String)
    case invalidStructuralTag(String)
    case invalidJSONSchema(String)
    case nativeError(String)

    /// A human-readable error message.
    public var description: String {
        switch self {
        case .deserializeVersion(let message),
            .deserializeFormat(let message),
            .invalidJSON(let message),
            .invalidStructuralTag(let message),
            .invalidJSONSchema(let message),
            .nativeError(let message):
            return message
        }
    }

    public var errorDescription: String? {
        description
    }
}

// MARK: -

@inline(__always)
func makeXGrammarError(
    kind: xgrammar.bridging.ErrorKind,
    message: String
) -> XGrammarError {
    switch kind {
    case .deserializeVersion:
        return .deserializeVersion(message)
    case .deserializeFormat:
        return .deserializeFormat(message)
    case .invalidJSON:
        return .invalidJSON(message)
    case .invalidStructuralTag:
        return .invalidStructuralTag(message)
    case .invalidJSONSchema:
        return .invalidJSONSchema(message)
    default:
        return .nativeError(message)
    }
}
