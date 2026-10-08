import Testing

@Test
func `The development fixture git runner launches the git the client resolves`() throws {
    let directory = DevelopmentFixtureFiles.temporaryPath(
        resolvingSymlinks: false,
        DevelopmentFixtureFiles.uniqueName()
    )
    try DevelopmentFixtureFiles.createDirectory(directory)

    try DevelopmentFixtureFiles.git(["init", "--quiet"], in: directory)
    try DevelopmentFixtureFiles.git(["rev-parse", "--git-dir"], in: directory)

    try DevelopmentFixtureFiles.remove(directory)
}

@Test
func `A failing development fixture git command is reported, not ignored`() throws {
    let directory = DevelopmentFixtureFiles.temporaryPath(
        resolvingSymlinks: false,
        DevelopmentFixtureFiles.uniqueName()
    )
    try DevelopmentFixtureFiles.createDirectory(directory)
    try DevelopmentFixtureFiles.git(["init", "--quiet"], in: directory)

    #expect(throws: (any Error).self) {
        try DevelopmentFixtureFiles.git(["rev-parse", "--verify", "refs/heads/absent"], in: directory)
    }

    try DevelopmentFixtureFiles.remove(directory)
}
