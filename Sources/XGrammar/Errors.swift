import Cxgrammar
import Foundation

/// Errors surfaced by the XGrammar Swift API.
public enum XGrammarError: Error, Sendable {
    case deserializeVersion(String)
    case deserializeFormat(String)
    case invalidJSON(String)
    case invalidStructuralTag(String)
    case invalidJSONSchema(String)
    case runtimeError(String)

    init(kind: xgrammar_error_kind, message: String) {
        switch kind {
        case XGRAMMAR_ERROR_DESERIALIZE_VERSION:
            self = .deserializeVersion(message)
        case XGRAMMAR_ERROR_DESERIALIZE_FORMAT:
            self = .deserializeFormat(message)
        case XGRAMMAR_ERROR_INVALID_JSON:
            self = .invalidJSON(message)
        case XGRAMMAR_ERROR_INVALID_STRUCTURAL_TAG:
            self = .invalidStructuralTag(message)
        case XGRAMMAR_ERROR_INVALID_JSON_SCHEMA:
            self = .invalidJSONSchema(message)
        default:
            self = .runtimeError(message)
        }
    }

    init(context: String) {
        self = .runtimeError("XGrammar failed to create \(context).")
    }
}

// MARK: - CustomStringConvertible

extension XGrammarError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .deserializeVersion(let message),
            .deserializeFormat(let message),
            .invalidJSON(let message),
            .invalidStructuralTag(let message),
            .invalidJSONSchema(let message),
            .runtimeError(let message):
            return message
        }
    }
}

// MARK: - LocalizedError

extension XGrammarError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
