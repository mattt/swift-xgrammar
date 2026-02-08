import Cxgrammar

public enum XGrammar {}

extension XGrammar {
    /// Global XGrammar configuration.
    public enum Configuration {
        /// The maximum recursion depth for grammar parsing.
        public static var maxRecursionDepth: Int {
            get { Int(xgrammar_get_max_recursion_depth()) }
            set { xgrammar_set_max_recursion_depth(Int32(newValue)) }
        }

        /// The serialization version for cache compatibility.
        public static var serializationVersion: String {
            consumeCString(xgrammar_get_serialization_version())
        }
    }
}
