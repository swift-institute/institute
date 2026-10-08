import Testing

@Test
func `The fixture git runner launches the git the client resolves`() throws {
    let directory = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(directory)

    try MainFixtureFiles.gitRequiringSuccess(["init", "--quiet"], in: directory)
    try MainFixtureFiles.gitRequiringSuccess(["rev-parse", "--git-dir"], in: directory)

    try MainFixtureFiles.remove(directory)
}
