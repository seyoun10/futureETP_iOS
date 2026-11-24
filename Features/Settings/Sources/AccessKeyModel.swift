import Core
import Foundation
import Observation

/// B-b 접근 키 화면 Model (screens.md B-b, D-044). 서버가 받은 키만 저장한다
@Observable
final class AccessKeyModel {
  /// 서버에 묻기 전에 앱이 거른 경우의 안내
  enum Notice: String {
    case badFormat, notKeyQr, cameraUnavailable
  }

  /// 화면 아래 오류 줄. 문구는 View가 i18n 키로 고른다
  enum Message: Equatable {
    case notice(Notice)
    /// 서버가 키를 거절함(`accessKey.rejected`)
    case rejected
    /// 그 밖의 실패(`errors.<CODE>`)
    case error(AppError.Code)
  }

  var input = ""
  private(set) var notice: Notice?
  private(set) var isSaving = false
  private(set) var saveError: AppError.Code?

  @ObservationIgnored private let store: AccessKeyStore
  @ObservationIgnored private let verifier: any AccessKeyVerifier
  @ObservationIgnored private let onSaved: () -> Void

  /// - Parameter onSaved: 저장 뒤 옛 키로 실패한 조회를 다시 불러온다. 기다리지 않는다
  init(store: AccessKeyStore, verifier: any AccessKeyVerifier, onSaved: @escaping () -> Void = {}) {
    self.store = store
    self.verifier = verifier
    self.onSaved = onSaved
  }

  /// 키가 없으면 B-b가 첫 화면이라 [←]가 없다
  var canGoBack: Bool { store.hasKey }

  var canSubmit: Bool {
    !isSaving && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 거절돼서 왔으면 새 키를 확인하기 전까지 거절 줄을 보인다
  var message: Message? {
    if let notice { return .notice(notice) }
    if let saveError { return saveError == .unauthorized ? .rejected : .error(saveError) }
    return store.isRejected && !isSaving ? .rejected : nil
  }

  /// 붙여넣은 키를 확인하고 저장한다. 저장했으면 true
  func submit() async -> Bool {
    guard canSubmit else { return false }
    saveError = nil
    guard let key = AccessKey.parse(input) else {
      notice = .badFormat
      return false
    }
    notice = nil
    return await verifyAndSave(key)
  }

  /// QR 스캔 전. 이전 안내와 오류를 지운다
  func startScan() {
    notice = nil
    saveError = nil
  }

  /// 스캔한 QR 값. 접근 키 QR이 아니면 nil을 돌려 스캔을 이어 간다
  func scanned(_ data: String) -> String? {
    guard let key = AccessKey.parse(data, requirePrefix: true) else {
      notice = .notKeyQr
      return nil
    }
    notice = nil
    return key
  }

  /// 카메라 권한 거부·카메라 없음(시뮬레이터)
  func cameraUnavailable() {
    notice = .cameraUnavailable
  }

  /// 거절돼서 왔다가 새 키 없이 떠나면 표시를 지운다
  func leave() {
    store.clearRejected()
  }

  /// 서버 확인 → Keychain 저장. 어느 쪽이 실패해도 저장하지 않는다
  func verifyAndSave(_ key: String) async -> Bool {
    guard !isSaving else { return false }
    isSaving = true
    saveError = nil
    defer { isSaving = false }
    do {
      try await verifier.verify(key)
      try store.save(key)
    } catch is CancellationError {
      return false
    } catch {
      // Keychain 실패처럼 AppError가 아닌 것은 INTERNAL로 보인다
      saveError = (error as? AppError)?.code ?? .internal
      return false
    }
    onSaved()
    return true
  }
}
