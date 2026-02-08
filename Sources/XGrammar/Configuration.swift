import Cxgrammar

extension Grammar {
    /// Global configuration settings for the XGrammar engine.
    public enum Configuration {
        /// The maximum recursion depth allowed during grammar parsing.
        ///
        /// Increase this value if you encounter errors
        /// when parsing deeply nested grammars.
        ///
        /// > Important: This is a process-wide setting.
        /// > Changing it affects all subsequent grammar operations.
        public static var maxRecursionDepth: Int {
            get { Int(xgrammar_get_max_recursion_depth()) }
            set { xgrammar_set_max_recursion_depth(Int32(newValue)) }
        }

        /// The serialization format version,
        /// used to verify cache compatibility.
        public static var serializationVersion: String {
            consumeCString(xgrammar_get_serialization_version())
        }
    }
}
