internal import Institute_Model

extension Institute.Inventory.Discovery {
    /// What a directory entry is, as far as the walk cares.
    enum Kind { case file, directory, other }
}
