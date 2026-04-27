import SwiftUI

struct AttributesView: View {

    var body: some View {
        List {
            ForEach(Dependency.all) { dependency in
                Section {
                    Text(dependency.licenseText)
                        .font(.caption)
                        .monospaced()
                        .listRowBackground(Color.clear)
                } header: {
                    Text(dependency.name)
                }
            }
        }
        .listStyle(.grouped)
        .navigationTitle("More.Attribution")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
    }
}

private struct Dependency: Identifiable {
    let id: String
    let name: String
    let license: String
    let licenseText: String

    static let all: [Dependency] = [
        Dependency(
            id: "sponsorblock",
            name: "SponsorBlock",
            license: "CC BY-NC-SA 4.0",
            licenseText: """
            Uses SponsorBlock data licensed under CC BY-NC-SA 4.0 \
            from https://sponsor.ajay.app/.
            """
        ),
        Dependency(
            id: "faviconfinder",
            name: "FaviconFinder",
            license: "MIT License",
            licenseText: """
            Copyright (c) 2022 William Lumley <will@lumley.io>

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
            """
        ),
        Dependency(
            id: "fluidaudio",
            name: "FluidAudio",
            license: "Apache License 2.0",
            licenseText: """
            Copyright Fluid Inference

            Licensed under the Apache License, Version 2.0 (the "License");
            you may not use this file except in compliance with the License.
            You may obtain a copy of the License at

                http://www.apache.org/licenses/LICENSE-2.0

            Unless required by applicable law or agreed to in writing, software
            distributed under the License is distributed on an "AS IS" BASIS,
            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
            See the License for the specific language governing permissions and
            limitations under the License.
            """
        ),
        Dependency(
            id: "readability",
            name: "Readability.js",
            license: "Apache License 2.0",
            licenseText: """
            Copyright (c) 2010 Arc90 Inc

            Licensed under the Apache License, Version 2.0 (the "License");
            you may not use this file except in compliance with the License.
            You may obtain a copy of the License at

               http://www.apache.org/licenses/LICENSE-2.0

            Unless required by applicable law or agreed to in writing, software
            distributed under the License is distributed on an "AS IS" BASIS,
            WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
            See the License for the specific language governing permissions and
            limitations under the License.
            """
        ),
        Dependency(
            id: "sqlite-swift",
            name: "SQLite.swift",
            license: "MIT License",
            licenseText: """
            (The MIT License)

            Copyright (c) 2014-2015 Stephen Celis <stephen@stephencelis.com>

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
            """
        ),
        Dependency(
            id: "swiftsoup",
            name: "SwiftSoup",
            license: "MIT License",
            licenseText: """
            The MIT License

            Copyright (c) 2009-2025 Jonathan Hedley <https://jsoup.org/>
            Swift port copyright (c) 2016-2025 Nabil Chatbi

            Permission is hereby granted, free of charge, to any person obtaining a copy
            of this software and associated documentation files (the "Software"), to deal
            in the Software without restriction, including without limitation the rights
            to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
            copies of the Software, and to permit persons to whom the Software is
            furnished to do so, subject to the following conditions:

            The above copyright notice and this permission notice shall be included in all
            copies or substantial portions of the Software.

            THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
            IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
            FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
            AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
            LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
            OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
            SOFTWARE.
            """
        )
    ]
}
