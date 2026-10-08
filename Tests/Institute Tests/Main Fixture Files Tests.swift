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
    #expect(failure?.output.isEmpty == false)
    try MainFixtureFiles.remove(directory)
}

@Test
func `A fixture git commit, which flushes its standard output, succeeds`() throws {
    let directory = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(directory)
    try MainFixtureFiles.gitRequiringSuccess(["init", "--quiet"], in: directory)
    try MainFixtureFiles.gitRequiringSuccess(["config", "user.email", "fixture@swift.institute"], in: directory)
    try MainFixtureFiles.gitRequiringSuccess(["config", "user.name", "Fixture"], in: directory)
    try MainFixtureFiles.write("committed\n", toFile: MainFixtureFiles.join(directory, "Fixture.txt"))
    try MainFixtureFiles.gitRequiringSuccess(["add", "Fixture.txt"], in: directory)

    try MainFixtureFiles.gitRequiringSuccess(["commit", "-m", "fixture"], in: directory)

    try MainFixtureFiles.gitRequiringSuccess(["rev-parse", "--verify", "HEAD"], in: directory)
    try MainFixtureFiles.remove(directory)
}

@Test
func `Fixture writes rewrite a file in place, never through a renamed temporary`() throws {
    let directory = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(directory)
    let path = MainFixtureFiles.join(directory, "Fixture.txt")
    try MainFixtureFiles.write("first\n", toFile: path)
    let before = try MainFixtureFiles.fileNumber(path)

    try MainFixtureFiles.write("second\n", toFile: path)
    try MainFixtureFiles.write(bytes: Swift.Array("third\n".utf8), to: path)

    #expect(try MainFixtureFiles.fileNumber(path) == before)
    #expect(try MainFixtureFiles.readStrictUTF8(path) == "third\n")
    try MainFixtureFiles.remove(directory)
}
