#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repository = Path(__file__).resolve().parents[2]
checkouts = Path(sys.argv[1]).resolve()
source_files = [
    'Hanami/Feed Providers/Petal/PetalRecipe.swift',
    'Hanami/Feed Providers/Petal/PetalAutoDetect.swift',
    'Hanami/Feed Providers/Petal/PetalEngine/PetalEngine+Parsing.swift',
    'Hanami/Feed Providers/Petal/PetalEngine/PetalEngine+Dates.swift',
    'Hanami/RSS Parser/ParsedArticle.swift',
    'Hanami/Data Portability/PetalBackupArchive.swift',
]
with tempfile.TemporaryDirectory(prefix='SakuraPetalTests-') as directory:
    package = Path(directory)
    sources = package / 'Sources' / 'Regression'
    sources.mkdir(parents=True)
    shutil.copytree(checkouts / 'SQLite.swift' / 'Sources' / 'SQLite', package / 'Sources' / 'SQLite')
    for filename in source_files:
        shutil.copy2(repository / filename, sources / Path(filename).name)
    shutil.copy2(repository / 'ci_scripts/tests/petal-regressions.swift', sources / 'main.swift')
    soup_path = json.dumps(str(checkouts / 'SwiftSoup'))
    (package / 'Package.swift').write_text(f'''// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "Regression",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: {soup_path})],
    targets: [
        .target(name: "SQLite", exclude: ["Info.plist", "PrivacyInfo.xcprivacy"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "Regression", dependencies: ["SQLite", "SwiftSoup"])
    ]
)
''')
    subprocess.run(['swift', 'run', '--package-path', directory, 'Regression', *sys.argv[2:]], check=True)
