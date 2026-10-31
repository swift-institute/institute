#if LinterRuleBuildErrors
    public import Lint

    extension Lint {

        /// Running lint rules as part of a build: the tool and plugin that fail the build on a finding.
        public enum Build {}
    }
#endif
