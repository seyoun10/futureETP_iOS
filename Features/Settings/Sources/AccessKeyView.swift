import Core
import SwiftUI

/// B-b 접근 키 (screens.md B-b, D-044). 키가 없으면 앱 루트가 첫 화면으로 띄운다([←] 없음).
/// 키가 있을 때 저장하면 들어온 화면으로 돌아간다.
/// QR이 기본이고, 카메라를 못 쓰면(권한 거부·시뮬레이터) 붙여넣기만 쓰라고 안내한다
public struct AccessKeyView: View {
  @State private var model: AccessKeyModel
  @State private var isScanning = false
  @Environment(\.dismiss) private var dismiss

  /// - Parameter onSaved: 저장 뒤 옛 키로 실패한 조회를 다시 불러온다. 기다리지 않는다
  public init(
    store: AccessKeyStore, verifier: any AccessKeyVerifier, onSaved: @escaping () -> Void = {}
  ) {
    _model = State(initialValue: AccessKeyModel(store: store, verifier: verifier, onSaved: onSaved))
  }

  public var body: some View {
    @Bindable var model = model
    Form {
      Section {
        Text("accessKey.guide")
        if isScanning {
          QrScannerView(onScanned: scanned, onUnavailable: scannerUnavailable)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityLabel(Text("accessKey.scannerLabel"))
          Button("common.cancel") { isScanning = false }
            .frame(maxWidth: .infinity)
        } else {
          Button("accessKey.scanQr", action: startScan)
            .frame(maxWidth: .infinity)
            .disabled(model.isSaving)
        }
        SecureField("accessKey.pastePlaceholder", text: $model.input)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .disabled(model.isSaving)
          .onSubmit(submit)
        Button(action: submit) {
          if model.isSaving {
            ProgressView().accessibilityLabel(Text("accessKey.verifying"))
          } else {
            Text("accessKey.submit")
          }
        }
        .frame(maxWidth: .infinity)
        .disabled(!model.canSubmit)
      }
      if let message = model.message {
        Text(message.key)
          .foregroundStyle(Theme.Colors.error)
          .frame(maxWidth: .infinity)
          .accessibilityAddTraits(.isStaticText)
      }
    }
    .titleBarSeparator()
    .navigationTitle(Text("settings.accessKey"))
    .navigationBarBackButtonHidden(!model.canGoBack)
    .onDisappear { model.leave() }
  }

  private func submit() {
    finish { await model.submit() }
  }

  private func startScan() {
    model.startScan()
    Task {
      if await QrScannerView.requestAccess() {
        isScanning = true
      } else {
        model.cameraUnavailable()
      }
    }
  }

  private func scanned(_ data: String) -> Bool {
    guard let key = model.scanned(data) else { return false }
    isScanning = false
    finish { await model.verifyAndSave(key) }
    return true
  }

  private func scannerUnavailable() {
    isScanning = false
    model.cameraUnavailable()
  }

  /// 저장하면 키가 생기므로 저장 전에 돌아갈 수 있었는지 본다
  private func finish(_ save: @escaping () async -> Bool) {
    let canGoBack = model.canGoBack
    Task {
      if await save(), canGoBack { dismiss() }
    }
  }
}

extension AccessKeyModel.Message {
  /// i18n 키. App/Resources/Localizable.xcstrings(RN 리소스에서 생성)에 있다
  var key: LocalizedStringKey {
    switch self {
    case .notice(let notice): LocalizedStringKey("accessKey.\(notice.rawValue)")
    case .rejected: "accessKey.rejected"
    case .error(let code): LocalizedStringKey("errors.\(code.rawValue)")
    }
  }
}
