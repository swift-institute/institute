public import Institute_Model

extension Institute.Repository.Policy.Caller {
    /// The bounded forward transaction that replaces one package caller.
    /// Credential acquisition and iteration remain host effects; every
    /// mutation precondition and recovery obligation lives here.
    public enum Wave {}
}
