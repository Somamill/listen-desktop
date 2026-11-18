import UIKit
import BackgroundTasks

@MainActor final class ConversionActivity {
  static let shared = ConversionActivity()
  private let identifier = "io.github.somamill.listen.mobile.conversion"
  private var cancel: (() -> Void)?
  private var background = UIBackgroundTaskIdentifier.invalid
  private var previousIdleSetting = false
  #if !targetEnvironment(macCatalyst)
  @available(iOS 26.0, *) private var continued: BGContinuedProcessingTask? {
    get { taskStorage as? BGContinuedProcessingTask }
    set { taskStorage = newValue }
  }
  private var taskStorage: AnyObject?
  #endif
  private init() {
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 26.0, *) {
      BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { [weak self] task in
        guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
        Task { @MainActor in
          guard let self, self.cancel != nil else { task.setTaskCompleted(success: false); return }
          self.continued = task
          self.endTemporaryBackgroundTask()
          task.progress.totalUnitCount = 1000
          task.expirationHandler = { [weak self] in Task { @MainActor in self?.cancel?() } }
        }
      }
    }
    #endif
  }
  func begin(title: String, cancel: @escaping () -> Void) async {
    self.cancel = cancel
    previousIdleSetting = UIApplication.shared.isIdleTimerDisabled
    UIApplication.shared.isIdleTimerDisabled = true
    background = UIApplication.shared.beginBackgroundTask(withName: "Finish audiobook import") { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 26.0, *), self.continued != nil { self.endTemporaryBackgroundTask(); return }
        #endif
        self.endTemporaryBackgroundTask()
        self.cancel?()
      }
    }
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 26.0, *), UIApplication.shared.applicationState == .active {
      let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Creating your audiobook", subtitle: title)
      request.strategy = .fail
      // Foreground conversion still works when the system cannot grant continued processing.
      if #available(iOS 27.0, *) { try? await BGTaskScheduler.shared.submitTaskRequest(request) }
      else { try? BGTaskScheduler.shared.submit(request) }
    }
    #endif
  }
  func update(_ value: Double) {
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 26.0, *) { continued?.progress.completedUnitCount = Int64(min(0.99, max(0, value)) * 1000) }
    #endif
  }
  func finish(success: Bool) {
    guard cancel != nil else { return }
    cancel = nil
    UIApplication.shared.isIdleTimerDisabled = previousIdleSetting
    endTemporaryBackgroundTask()
    #if !targetEnvironment(macCatalyst)
    if #available(iOS 26.0, *) {
      if success { continued?.progress.completedUnitCount = 1000 }
      continued?.setTaskCompleted(success: success); continued = nil
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }
    #endif
  }
  private func endTemporaryBackgroundTask() {
    if background != .invalid { UIApplication.shared.endBackgroundTask(background); background = .invalid }
  }
}
