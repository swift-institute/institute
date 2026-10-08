import Testing

@Test
func `The fixture git runner launches the git the client resolves`() throws {
    let directory = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(directory)

    try MainFixtureFiles.gitRequiringSuccess(["init", "--quiet"], in: directory)
    try MainFixtureFiles.gitRequiringSuccess(["rev-parse", "--git-dir"], in: directory)

    try MainFixtureFiles.remove(directory)
}

@Test
func `A failing fixture git command reports its arguments, status and stderr`() throws {
    let directory = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(directory)
    try MainFixtureFiles.gitRequiringSuccess(["init", "--quiet"], in: directory)

    let failure = #expect(throws: MainFixtureFiles.GitFailure.self) {
        try MainFixtureFiles.gitRequiringSuccess(["rev-parse", "--verify", "refs/heads/absent"], in: directory)
    }

    #expect(failure?.arguments == ["rev-parse", "--verify", "refs/heads/absent"])
    #expect(failure?.status != 0)
    #expect(failure?.standardError.isEmpty == false)
    try MainFixtureFiles.remove(directory)
}
