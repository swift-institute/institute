import File_System
import GitHub_Standard
import Institute_Model
import Institute_Source
import Institute_Source_Workspace
import Testing

import struct Swift.String

@Test(arguments: [
    ("https://github.com/swift-atoms/swift-geometry", "swift-atoms/swift-geometry"),
    ("https://github.com/swift-atoms/swift-geometry.git", "swift-atoms/swift-geometry"),
    ("https://github.com/swift-atoms/swift-geometry/", "swift-atoms/swift-geometry"),
    ("git@github.com:swift-atoms/swift-geometry.git", "swift-atoms/swift-geometry"),
    ("ssh://git@github.com/swift-atoms/swift-geometry.git", "swift-atoms/swift-geometry"),
    ("http://local_proxy@127.0.0.1:40783/git/swift-atoms/swift-geometry", "swift-atoms/swift-geometry"),
    ("/srv/mirrors/swift-atoms/swift-geometry", "swift-atoms/swift-geometry"),
])
func `the repository is the last two segments of origin's URL`(remote: String, expected: String) {
    #expect(Institute.Source.Workspace.repository(remote: remote)?.description == expected)
}

@Test(arguments: ["", "swift-geometry", "https://github.com/swift-geometry", "https://github.com", "git@github.com:"])
func `a URL that names no owner and name gives no repository`(remote: String) {
    #expect(Institute.Source.Workspace.repository(remote: remote) == nil)
}

@Test
func `the pinned tools are kept once per account, under the cache directory`() throws {
    typealias Lint = Institute.Source.Application
    let cache = MainFixtureFiles.temporaryPath("cache")
    let home = MainFixtureFiles.temporaryPath("home")
    let underCache = try File.Directory(validating: MainFixtureFiles.join(cache, "institute/source-tools"))
    let underHome = try File.Directory(validating: MainFixtureFiles.join(home, ".cache/institute/source-tools"))
    #expect(Lint.tools(cache: cache, home: home) == underCache)
    #expect(Lint.tools(cache: nil, home: home) == underHome)
    #expect(Lint.tools(cache: "", home: home + "/") == underHome)
    #expect(Lint.tools(cache: "relative", home: nil) == nil)
    #expect(Lint.tools(cache: nil, home: nil) == nil)
}
