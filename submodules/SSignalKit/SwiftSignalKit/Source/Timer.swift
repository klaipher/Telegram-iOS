import Foundation

public final class Timer {
    private let timer = Atomic<DispatchSourceTimer?>(value: nil)
    private let timeout: Double
    private let `repeat`: Bool
    private let completion: (Timer) -> Void
    private let queue: Queue
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping () -> Void, queue: Queue) {
        self.timeout = timeout
        self.`repeat` = `repeat`
        self.completion = { _ in
            completion()
        }
        self.queue = queue
    }
    
    public init(timeout: Double, `repeat`: Bool, completion: @escaping (Timer) -> Void, queue: Queue) {
        self.timeout = timeout
        self.`repeat` = `repeat`
        self.completion = completion
        self.queue = queue
    }
    
    deinit {
        self.invalidate()
    }
    
    public func start() {
        let timer = DispatchSource.makeTimerSource(queue: self.queue.queue)
        timer.setEventHandler(handler: { [weak self] in
            if let strongSelf = self {
                strongSelf.completion(strongSelf)
                if !strongSelf.`repeat` {
                    strongSelf.invalidate()
                }
            }
        })
        let _ = self.timer.modify { _ in
            return timer
        }
        
        // MARK: Swiftgram: give every timer a small leeway (10 % of its period, capped) so the
        // kernel can coalesce wakeups instead of firing each timer at its own exact instant.
        // Repeating timers may drift by up to 1 s per tick; one-shot timers are often deadlines
        // (media end, animation steps), so they get at most 20 ms.
        let leewayMilliseconds = Int(max(1.0, min(self.`repeat` ? 1000.0 : 20.0, self.timeout * 100.0)))
        if self.`repeat` {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.schedule(deadline: time, repeating: self.timeout, leeway: .milliseconds(leewayMilliseconds))
        } else {
            let time: DispatchTime = DispatchTime.now() + self.timeout
            timer.schedule(deadline: time, leeway: .milliseconds(leewayMilliseconds))
        }
        
        timer.resume()
    }
    
    public func invalidate() {
        let _ = self.timer.modify { timer in
            timer?.cancel()
            return nil
        }
    }
}
