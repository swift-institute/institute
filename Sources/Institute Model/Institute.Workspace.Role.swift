extension Institute.Workspace {
    public enum Role: Sendable, Equatable {
        case subject(Institute.Repository.Key)
        case control(Control)
    }
}
