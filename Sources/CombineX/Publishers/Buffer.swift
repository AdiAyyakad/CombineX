extension Publisher {
    
    public func buffer(size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Self.Failure>) -> Publishers.Buffer<Self> {
        return .init(upstream: self, size: size, prefetch: prefetch, whenFull: whenFull)
    }
}

extension Publishers {
    
    public enum PrefetchStrategy {
        
        case keepFull
        
        case byRequest
        
        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (a: Publishers.PrefetchStrategy, b: Publishers.PrefetchStrategy) -> Bool {
            switch (a, b) {
            case (.keepFull, .keepFull):
                return true
            case (.byRequest, .byRequest):
                return true
            default:
                return false
            }
        }
        
        /// The hash value.
        ///
        /// Hash values are not guaranteed to be equal across different executions of
        /// your program. Do not save hash values to use during a future execution.
        ///
        /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
        ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
//        public var hashValue: Int { get }
        
        /// Hashes the essential components of this value by feeding them into the
        /// given hasher.
        ///
        /// Implement this method to conform to the `Hashable` protocol. The
        /// components used for hashing must be the same as the components compared
        /// in your type's `==` operator implementation. Call `hasher.combine(_:)`
        /// with each of these components.
        ///
        /// - Important: Never call `finalize()` on `hasher`. Doing so may become a
        ///   compile-time error in the future.
        ///
        /// - Parameter hasher: The hasher to use when combining the components
        ///   of this instance.
        public func hash(into hasher: inout Hasher) {
            switch self {
            case .keepFull:
                hasher.combine(0)
            case .byRequest:
                hasher.combine(1)
            }
        }
    }
    
    public enum BufferingStrategy<Failure> where Failure : Error {
        
        case dropNewest
        
        case dropOldest
        
        case customError(() -> Failure)
    }
    
    public struct Buffer<Upstream> : Publisher where Upstream : Publisher {
        
        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure
        
        public let upstream: Upstream
        
        public let size: Int
        
        public let prefetch: Publishers.PrefetchStrategy
        
        public let whenFull: Publishers.BufferingStrategy<Upstream.Failure>
        
        public init(upstream: Upstream, size: Int, prefetch: Publishers.PrefetchStrategy, whenFull: Publishers.BufferingStrategy<Publishers.Buffer<Upstream>.Failure>) {
            self.upstream = upstream
            self.size = size
            self.prefetch = prefetch
            self.whenFull = whenFull
        }
        
        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            Global.RequiresImplementation()
//            switch self.prefetch {
//            case .keepFull:
//                let subscription = KeeyFullInner(pub: self, sub: subscriber)
//                self.upstream.subscribe(subscription)
//            case .byRequest:
//                let subscription = ByRequestInner(pub: self, sub: subscriber)
//                self.upstream.subscribe(subscription)
//            }
        }
    }
}

/*
 
extension Publishers.Buffer {
    
    private final class KeeyFullInner<S>:
        Subscriber,
        Subscription,
        CustomStringConvertible,
        CustomDebugStringConvertible
    where
        S: Subscriber,
        S.Input == Output,
        S.Failure == Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        typealias Pub = Publishers.Buffer<Upstream>
        typealias Sub = S
        
        let lock = Lock()
        
        let sub: Sub
        let size: Int
        let whenFull: Publishers.BufferingStrategy<Upstream.Failure>
        
        var demand: Subscribers.Demand = .none
        var buffer: [Output] = []
        
        var state = RelayState.waiting
        
        init(pub: Pub, sub: Sub) {
            self.size = pub.size
            self.whenFull = pub.whenFull
            self.sub = sub
        }
        
        func request(_ demand: Subscribers.Demand) {
            self.lock.lock()
            guard let subscription = self.state.subscription else {
                self.lock.unlock()
                return
            }
            
            self.demand += demand
            self.lock.unlock()
            
            subscription.request(demand)
        }
        
        func cancel() {
            self.lock.withLockGet(self.state.finish())?.cancel()
            self.buffer = []
        }
        
        func receive(subscription: Subscription) {
            guard self.lock.withLockGet(self.state.relay(subscription)) else {
                subscription.cancel()
                return
            }
            
            subscription.request(.unlimited)
            self.sub.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            self.lock.lock()
            guard self.state.isRelaying else {
                self.lock.unlock()
                return .none
            }
            
            switch self.buffer.count {
            case ..<self.size:
                self.buffer.append(input)
                self.lock.unlock()
            case self.size:
                if self.demand > 0 {
                    self.demand -= 1
                    let first = self.buffer.removeFirst()
                    self.buffer.append(input)
                    self.lock.unlock()
                    
                    let more = self.sub.receive(first)
                    
                    self.lock.withLock {
                        self.demand += more
                    }
                } else {
                    switch self.whenFull {
                    case .dropNewest:
                        self.lock.unlock()
                    case .dropOldest:
                        if self.buffer.isNotEmpty {
                            _ = self.buffer.removeFirst()
                            self.buffer.append(input)
                        }
                        self.lock.unlock()
                    case .customError(let makeError):
                        let subscription = self.state.finish()
                        self.lock.unlock()
                        subscription?.cancel()
                        let error = makeError()
                        
                        self.buffer = []
                        self.sub.receive(completion: .failure(error))
                    }
                }
            default:
                self.lock.unlock()
            }
            
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard let subscription = self.lock.withLockGet(self.state.finish()) else {
                return
            }
            subscription.cancel()
            
            self.buffer = []
            self.sub.receive(completion: completion)
        }
        
        var description: String {
            return "Buffer"
        }
        
        var debugDescription: String {
            return "Buffer"
        }
    }
}

extension Publishers.Buffer {
    
    private final class ByRequestInner<S>:
        Subscriber,
        Subscription,
        CustomStringConvertible,
        CustomDebugStringConvertible
    where
        S: Subscriber,
        S.Input == Output,
        S.Failure == Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        typealias Pub = Publishers.Buffer<Upstream>
        typealias Sub = S
        
        let lock = Lock()
        
        let sub: Sub
        let size: Int
        let whenFull: Publishers.BufferingStrategy<Upstream.Failure>
        
        var demand: Subscribers.Demand = .none
        var buffer: [Output] = []
        
        var state = RelayState.waiting
        
        init(pub: Pub, sub: Sub) {
            self.size = pub.size
            self.whenFull = pub.whenFull
            self.sub = sub
        }
        
        func request(_ demand: Subscribers.Demand) {
            self.lock.lock()
            guard let subscription = self.state.subscription else {
                self.lock.unlock()
                return
            }
            
            let before = self.demand
            let after = before + demand
            self.demand = after
            
            var slice: [Output] = []
            if before == 0, after > 0 {
                slice = self.buffer[before..<after]
            }
            self.lock.unlock()
        
            if slice.isNotEmpty {
                let more = slice.reduce(0) { (demand, output) in
                    return demand + self.sub.receive(output)
                }
                self.lock.
            }
            
            subscription.request(demand)
        }
        
        func cancel() {
            self.lock.withLockGet(self.state.finish())?.cancel()
            self.buffer = []
        }
        
        func receive(subscription: Subscription) {
            guard self.lock.withLockGet(self.state.relay(subscription)) else {
                subscription.cancel()
                return
            }
            
            subscription.request(.unlimited)
            self.sub.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            self.lock.lock()
            guard self.state.isRelaying else {
                self.lock.unlock()
                return .none
            }
            
            if self.demand > 0 {
                self.demand -= 1
                self.lock.unlock()
                
                let more = self.sub.receive(input)
                
                self.lock.withLock {
                    self.demand += more
                }
            } else {
                switch self.buffer.count {
                case 0..<self.size:
                    self.buffer.append(input)
                    self.lock.unlock()
                case self.size:
                    switch self.whenFull {
                    case .dropOldest:
                        _ = self.buffer.removeFirst()
                        self.buffer.append(input)
                        self.lock.unlock()
                    case .dropNewest:
                        self.lock.unlock()
                    case .customError(let makeError):
                        guard let subscription = self.state.finish() else {
                            self.lock.unlock()
                            return
                        }
                        self.lock.unlock()
                        
                        subscription.cancel()
                        self.buffer = []
                        
                        self.sub.receive(completion: .failure(makeError()))
                    }
                }
            }
            
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            guard let subscription = self.lock.withLockGet(self.state.finish()) else {
                return
            }
            subscription.cancel()
            
            self.buffer = []
            self.sub.receive(completion: completion)
        }
        
        var description: String {
            return "Buffer"
        }
        
        var debugDescription: String {
            return "Buffer"
        }
    }
}

*/