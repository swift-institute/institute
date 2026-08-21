public import Package_Manager

extension Institute.Xcode {
    @discardableResult
    public static func materialize(
        _ specification: Institute.Workspace.Specification,
        at root: Institute.Root,
        packages: Package.Manager = .init()
    ) throws(Institute.Error) -> Institute.Xcode.Scheme.Plan {
        let plan = try Institute.Xcode.Scheme.plan(
            for: specification,
            at: root,
            packages: packages
        )
        try materialize(specification, scheme: plan, at: root)
        return plan
    }

    public static func materialize(
        _ specification: Institute.Workspace.Specification,
        scheme plan: Institute.Xcode.Scheme.Plan,
        at root: Institute.Root
    ) throws(Institute.Error) {
        if !current(specification, at: root.checkout) {
            try write(specification, at: root.checkout)
        }
        if !Institute.Xcode.Scheme.current(plan, at: root.checkout) {
            try Institute.Xcode.Scheme.write(plan, at: root.checkout)
        }
    }
}
