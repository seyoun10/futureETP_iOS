import ProjectDescription

// 타깃 의존 방향: App → features → Core (IOS-003). feature끼리, Core → feature 의존을 선언하지 않는다
let configurations: [Configuration] = [
  .debug(name: "Debug-Dev", xcconfig: "Config/Debug-Dev.xcconfig"),
  .release(name: "Release", xcconfig: "Config/Release.xcconfig"),
]

let destinations: Destinations = [.iPhone]
let deploymentTargets: DeploymentTargets = .iOS("18.0")

// Tuist 기본값(SWIFT_VERSION = 5)이 프로젝트·타깃 수준에서 xcconfig의 6.0을 덮어쓰지 않게 뺀다
let defaultSettings: DefaultSettings = .recommended(excluding: ["SWIFT_VERSION"])

// 화면 코드는 MainActor 기본 격리 (Swift 6 approachable concurrency)
let mainActorSettings: SettingsDictionary = ["SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor"]

func feature(_ name: String) -> Target {
  .target(
    name: name,
    destinations: destinations,
    product: .framework,
    bundleId: "io.github.seyoon.futureetp.\(name.lowercased())",
    deploymentTargets: deploymentTargets,
    sources: ["Features/\(name)/Sources/**"],
    dependencies: [.target(name: "Core")],
    settings: .settings(base: mainActorSettings, defaultSettings: defaultSettings)
  )
}

let features = ["CommodityList", "Commodity", "Settings"]
/// feature 화면 Model 테스트 타깃
func featureTests(_ name: String) -> Target {
  .target(
    name: "\(name)Tests",
    destinations: destinations,
    product: .unitTests,
    bundleId: "io.github.seyoon.futureetp.\(name.lowercased())tests",
    deploymentTargets: deploymentTargets,
    sources: ["Features/\(name)/Tests/**"],
    dependencies: [.target(name: name), .target(name: "Core")],
    settings: .settings(base: mainActorSettings, defaultSettings: defaultSettings)
  )
}

let project = Project(
  name: "FutureETP",
  // 문구 기준 언어는 ko, 번역은 en (D-033)
  options: .options(developmentRegion: "ko"),
  settings: .settings(configurations: configurations, defaultSettings: defaultSettings),
  targets: [
    .target(
      name: "FutureETP",
      destinations: destinations,
      product: .app,
      // configuration마다 xcconfig의 APP_BUNDLE_ID(.dev 포함)로 바뀐다
      bundleId: "$(APP_BUNDLE_ID)",
      deploymentTargets: deploymentTargets,
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "$(APP_DISPLAY_NAME)",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "UILaunchScreen": ["UIColorName": "LaunchBackground"],
        "UIUserInterfaceStyle": "Dark",
        // ProMotion 기기에서 차트 제스처를 120Hz로 그린다 (C-a 스파이크)
        "CADisableMinimumFrameDurationOnPhone": true,
        // 세로 고정, [⟲]로만 가로 전환 (D-076). 잠금은 코드에서 한다
        "UISupportedInterfaceOrientations": [
          "UIInterfaceOrientationPortrait",
          "UIInterfaceOrientationLandscapeLeft",
          "UIInterfaceOrientationLandscapeRight",
        ],
        // dev 서버(http://localhost, .local)만 허용
        "NSAppTransportSecurity": ["NSAllowsLocalNetworking": true],
        // 번역은 App/Resources/InfoPlist.xcstrings (D-033)
        "NSCameraUsageDescription": "서버 접근 키 QR 코드를 읽을 때 카메라를 씁니다.",
        "AppVariant": "$(APP_VARIANT)",
        "APIBaseURL": "$(API_BASE_URL)",
        "DevAPIToken": "$(DEV_API_TOKEN)",
      ]),
      sources: ["App/Sources/**"],
      resources: ["App/Resources/**"],
      dependencies: features.map { .target(name: $0) } + [.target(name: "Core")],
      settings: .settings(
        base: mainActorSettings.merging([
          "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
          "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
        ]) { $1 },
        defaultSettings: defaultSettings)
    ),
    .target(
      name: "Core",
      destinations: destinations,
      product: .framework,
      bundleId: "io.github.seyoon.futureetp.core",
      deploymentTargets: deploymentTargets,
      sources: ["Core/Sources/**"],
      settings: .settings(defaultSettings: defaultSettings)
    ),
    .target(
      name: "CoreTests",
      destinations: destinations,
      product: .unitTests,
      bundleId: "io.github.seyoon.futureetp.coretests",
      deploymentTargets: deploymentTargets,
      sources: ["Core/Tests/**"],
      // 계약 테스트 예시(dev 서버 응답, scripts/capture-fixtures.sh), 문구 helper 테스트용 앱 카탈로그
      resources: ["Core/Tests/Fixtures/**", "App/Resources/Localizable.xcstrings"],
      dependencies: [.target(name: "Core")],
      settings: .settings(defaultSettings: defaultSettings)
    ),
  ] + features.map(featureTests) + features.map(feature),
  schemes: [
    .scheme(
      name: "FutureETP-Dev",
      buildAction: .buildAction(targets: ["FutureETP"]),
      testAction: .targets(
        ["CoreTests"] + features.map { "\($0)Tests" }, configuration: "Debug-Dev"),
      runAction: .runAction(configuration: "Debug-Dev"),
      archiveAction: .archiveAction(configuration: "Debug-Dev"),
      profileAction: .profileAction(configuration: "Debug-Dev"),
      analyzeAction: .analyzeAction(configuration: "Debug-Dev")
    ),
    .scheme(
      name: "FutureETP",
      buildAction: .buildAction(targets: ["FutureETP"]),
      runAction: .runAction(configuration: "Release"),
      archiveAction: .archiveAction(configuration: "Release"),
      profileAction: .profileAction(configuration: "Release"),
      analyzeAction: .analyzeAction(configuration: "Release")
    ),
  ]
)
