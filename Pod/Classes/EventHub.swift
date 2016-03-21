public protocol EventType {}

public enum Thread {
    case Main
    case Background
    case Custom(queue: dispatch_queue_t)

    private var queue: dispatch_queue_t {
        switch self {
        case .Main:
            return dispatch_get_main_queue()
        case .Background:
            return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
        case .Custom(let queue):
            return queue
        }
    }
}

private class EventHubManager {
    static let shared = EventHubManager()
    
    var observations = [Observation]()
    let queue = dispatch_queue_create("EventHubManager.queue", nil)
    
    func addObserver(observer: AnyObject, thread: Thread?, block: Any) {
        dispatch_sync(queue) {
            let observation = Observation(observer: observer, thread: thread, block: block)
            self.observations.append(observation)
        }
    }
    
    func removeObserver(observer: AnyObject) {
        dispatch_sync(queue) {
            self.observations = self.observations.filter { $0.observer! !== observer }
        }
    }
    
    func post<T: EventType>(event: T) {
        dispatch_sync(queue) {
            self.observations = self.observations.filter { $0.observer != nil } // Remove nil observers
            self.observations.forEach {
                guard let block = $0.block as? T -> () else {
                    return
                }
                
                if let queue = $0.thread?.queue {
                    dispatch_async(queue) {
                        block(event)
                    }
                } else {
                    block(event)
                }
            }
        }
    }
}

private struct Observation {
    weak var observer: AnyObject?
    let thread: Thread?
    let block: Any
}

public func addObserver<T: EventType>(observer: AnyObject, thread: Thread? = nil, block: T -> ()) {
    EventHubManager.shared.addObserver(observer, thread: thread, block: block)
}

public func removeObserver(observer: AnyObject) {
    EventHubManager.shared.removeObserver(observer)
}

public func post<T: EventType>(event: T) {
    EventHubManager.shared.post(event)
}
