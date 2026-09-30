extension Source.SourceSet {
  public static func digest(_ files: [Source.Repair.Staged.File]) -> Digest {
    var bytes: [Byte] = []
    for file in files.sorted(by: { $0.path < $1.path }) {
      bytes.append(contentsOf: file.path.utf8.map(Byte.init))
      bytes.append(Byte(0))
      if let contents = file.contents {
        let hex = FIPS_180_4.SHA256.digest(contents.map(Byte.init)).hex
        bytes.append(contentsOf: hex.utf8.map(Byte.init))
      } else {
        bytes.append(contentsOf: "absent".utf8.map(Byte.init))
      }
      bytes.append(Byte(10))
    }
    return .init(FIPS_180_4.SHA256.digest(bytes).hex)
  }
}
