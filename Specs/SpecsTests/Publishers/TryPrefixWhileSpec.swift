import Quick
import Nimble

#if USE_COMBINE
import Combine
#elseif SWIFT_PACKAGE
import CombineX
#else
import Specs
#endif

class TryPrefixWhileSpec: QuickSpec {
    
    override func spec() {
        
        // MARK: - Relay
        describe("Relay") {
            
            // MARK: 1.1 should relay until predicate return false
            it("should relay until predicate return false") {
                let subject = PassthroughSubject<Int, Never>()
                let pub = subject.tryPrefix(while: { $0 < 50 })
                let sub = makeCustomSubscriber(Int.self, Error.self, .unlimited)
                pub.subscribe(sub)
                
                100.times {
                    subject.send($0)
                }
                subject.send(completion: .finished)
                
                let got = sub.events.map {
                    $0.mapError { $0 as! CustomError }
                }
                
                let valueEvents = (0..<50).map {
                    CustomEvent<Int, CustomError>.value($0)
                }
                let expected = valueEvents + [.completion(.finished)]
                
                expect(got).to(equal(expected))
            }
            
            // MARK: 1.2 should finish immediately if the first element predicate failure
            it("should finish immediately if the first element predicate failure") {
                let subject = PassthroughSubject<Int, CustomError>()
                let pub = subject.tryPrefix(while: { $0 > 50 })
                let sub = makeCustomSubscriber(Int.self, Error.self, .unlimited)
                pub.subscribe(sub)
                
                100.times {
                    subject.send($0)
                }
                subject.send(completion: .failure(.e0))
                
                let got = sub.events.map {
                    $0.mapError { $0 as! CustomError }
                }
                expect(got).to(equal([.completion(.finished)]))
            }
            
            // MARK: 1.3 should send as many values as demand
            it("should send as many values as demand") {
                let pub = PassthroughSubject<Int, Never>()
                let sub = makeCustomSubscriber(Int.self, Error.self, .max(10))
                pub.tryPrefix { $0 < 50 }.subscribe(sub)
                
                for i in 0..<100 {
                    pub.send(i)
                }
                
                expect(sub.events.count).to(equal(10))
            }
            
            // MARK: 1.4 should fail if predicate throws error
            it("should fail if predicate throws error") {
                let pub = PassthroughSubject<Int, CustomError>()
                let sub = makeCustomSubscriber(Int.self, Error.self, .unlimited)
                pub.tryPrefix { _ in
                    throw CustomError.e0
                }.subscribe(sub)
                
                for i in 0..<100 {
                    pub.send(i)
                }
                
                pub.send(completion: .finished)
                
                let got = sub.events.map {
                    $0.mapError { $0 as! CustomError }
                }
                expect(got).to(equal([.completion(.failure(.e0))]))
            }
        }
    }
}
