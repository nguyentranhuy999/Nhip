# Third-party notices

The MIT license in [LICENSE](LICENSE) covers the original code, documentation,
and assets authored for Nhịp. It does not relicense third-party software,
SDKs, fonts, symbols, or catalog metadata.

## Apple frameworks and SF Symbols

Nhịp uses macOS frameworks and renders SF Symbols provided by the operating
system. These Apple components and symbol artwork are not licensed under
this project's MIT license; Apple's applicable terms continue to apply.

`Sources/Nhip/ActivitySymbolCatalog.swift` contains system symbol names and
catalog-derived search metadata, together with Vietnamese keywords added by
this project. This repository does not bundle SF Symbols artwork or Apple
framework binaries.

References: [SF Symbols](https://developer.apple.com/sf-symbols/) and
[Apple's SF Symbols guidelines](https://developer.apple.com/design/human-interface-guidelines/sf-symbols).

## SQLite

Nhịp links the system SQLite library through `Sources/CSQLite`. SQLite's
original deliverable code is dedicated to the public domain by its authors;
it is not relicensed under this project's MIT license. No SQLite library
source or binary is vendored in this repository.

Reference: [SQLite copyright and public-domain dedication](https://sqlite.org/copyright.html).
