/// Empty in the repository; `ci_scripts/ci_pre_xcodebuild.sh` writes Xcode Cloud's
/// `SAKURA_CLOUD_URL` in here before the build.
nonisolated enum SakuraCloudAddress {
    static let url = ""
}
