import Foundation

public class ProgressObserver: NSObject {
  @objc var progressToObserve: Progress
  var observation: NSKeyValueObservation?
  var lastTimeUpdated = Date.now

  public init(_ progress: Progress) {
    progressToObserve = progress
  }

  func log() {
    print(ProgressObserver.lineToRender(progressToObserve))
    observation = observe(\.progressToObserve.fractionCompleted) { progress, _ in
      let currentTime = Date.now
      if self.progressToObserve.isFinished || currentTime.timeIntervalSince(self.lastTimeUpdated) >= 1.0 {
        self.lastTimeUpdated = currentTime
        print(ProgressObserver.lineToRender(self.progressToObserve))
      }
    }
  }

  private static func lineToRender(_ progress: Progress) -> String {
    String(Int(100 * progress.fractionCompleted)) + "%"
  }
}
