#!/usr/bin/env python3
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--swift-soup-path', type=Path, required=True)
parser.add_argument('--scratch-path', type=Path)
arguments = parser.parse_args()
repository = Path(__file__).resolve().parents[3]
provider = repository / 'Hanami/Feed Providers/Instagram'
files = [
    'InstagramFetchError.swift',
    'InstagramProfileBootstrap.swift',
    'InstagramProfileFetchResult.swift',
    'ParsedInstagramPost.swift',
    'InstagramProvider+Extraction.swift',
    'InstagramProvider+ProfileHTML.swift',
    'InstagramProvider+PostsParsing.swift',
    'InstagramProvider+PostsRequest.swift',
    'InstagramProvider+Requests.swift',
]
with tempfile.TemporaryDirectory(prefix='sakura-instagram-tests-') as directory:
    package = Path(directory)
    sources = package / 'Sources/InstagramFetch'
    tests = package / 'Tests/InstagramFetchTests'
    sources.mkdir(parents=True)
    tests.mkdir(parents=True)
    for name in files:
        shutil.copy2(provider / name, sources / name)
    shutil.copy2(Path(__file__).with_name('ProviderHarness.swift'), sources)
    shutil.copy2(Path(__file__).with_name('InstagramFetchTests.swift'), tests)
    dependency = str(arguments.swift_soup_path.resolve()).replace('\\', '\\\\').replace('"', '\\"')
    (package / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "InstagramFetch",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "''' + dependency + '''")],
    targets: [
        .target(name: "InstagramFetch", dependencies: [.product(name: "SwiftSoup", package: "SwiftSoup")]),
        .testTarget(name: "InstagramFetchTests", dependencies: ["InstagramFetch"])
    ]
)
''')
    command = ['swift', 'test', '--package-path', str(package)]
    if arguments.scratch_path:
        command.extend(['--scratch-path', str(arguments.scratch_path.resolve())])
    subprocess.run(command, check=True)
