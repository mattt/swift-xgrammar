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
    kind: xgrammar_error_kind,
    message: String
) -> XGrammarError {
    switch kind {
    case XGRAMMAR_ERROR_DESERIALIZE_VERSION:
        return .deserializeVersion(message)
    case XGRAMMAR_ERROR_DESERIALIZE_FORMAT:
        return .deserializeFormat(message)
    case XGRAMMAR_ERROR_INVALID_JSON:
        return .invalidJSON(message)
    case XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG:
        return .invalidStructuralTag(message)
    case XGRAMMAR_ERROR_INVALID_JSON_SCHEMA:
        return .invalidJSONSchema(message)
    default:
        return .nativeError(message)
    }
}
