import Foundation
import Quick
import Nimble

#if USE_COMBINE
import Combine
#elseif SWIFT_PACKAGE
import CombineX
#else
import Specs
#endif

class DemandSpec: QuickSpec {
    
    typealias Demand = Subscribers.Demand
    
    override func spec() {
        
        // MARK: - Create
        describe("Create") {
            
            #if !SWIFT_PACKAGE
            // MARK: 1.1 should fatal error when create with negative number
            it("should fatal error when create with negative number") {
                expect {
                    _ = Demand.max(-1)
                }.to(throwAssertion())
            }
            #endif
        }
        
        // MARK: - Calculate
        describe("Calculate") {
            
            // MARK: 2.1 should add as expected
            it("should add as expected") {
                expect(Demand.max(1) + Demand.max(1)).to(equal(.max(2)))
                expect(Demand.max(1) + 1).to(equal(.max(2)))
                expect(Demand.max(1) + Demand.max(.max)).to(equal(.unlimited))
                expect(Demand.max(1) + Demand.unlimited).to(equal(.unlimited))
                
                var d = Demand.max(1)
                d += .max(2)
                expect(d).to(equal(.max(3)))
                
                expect(Demand.max(1) + (-1)).to(equal(.max(0)))
            }
            
            // MARK: 2.2 should sub as expected
            it("should sub as expected") {
                expect(Demand.max(2) - Demand.max(1)).to(equal(.max(1)))
                expect(Demand.max(2) - 1).to(equal(.max(1)))
                expect(Demand.unlimited - Demand.max(1)).to(equal(.unlimited))
                expect(Demand.max(1) - Demand.unlimited).to(equal(.max(0)))
                
                var d = Demand.max(2)
                d -= .max(1)
                expect(d).to(equal(.max(1)))
                
                expect(Demand.max(1) - 1).to(equal(.max(0)))
                
                #if !SWIFT_PACKAGE
                
                #if USE_COMBINE
                // FIXME: In combine, This behaves differently than the doc, doc says "any operation that would result in a negative value is clamped to .max(0)", but it will actually crash.
                expect {
                    _ = Demand.max(1) - .max(2)
                }.to(throwAssertion())
                #else
                expect(Demand.max(1) - .max(2)).to(equal(.max(0)))
                #endif
                
                #endif
            }
            
            // MARK: 2.3 should multiply as expected
            it("should multiply as expected") {
                expect(Demand.max(1) * 7).to(equal(.max(7)))
                expect(Demand.max(.max) * 2).to(equal(.unlimited))
                
                expect(Demand.unlimited * 2).to(equal(.unlimited))
                expect(Demand.unlimited * Int.max).to(equal(.unlimited))
                
                #if !SWIFT_PACKAGE
                expect {
                    _ = Demand.max(1) * -1
                }.to(throwAssertion())
                #endif
            }
        }
        
        // MARK: - Compare
        describe("Compare") {
            
            // MARK: 3.1 should compare as expecte
            it("should compare as expected") {
                expect(Demand.max(1)).to(beGreaterThan(.max(0)))
                expect(Demand.max(1)).to(beGreaterThanOrEqualTo(.max(1)))
                
                expect(Demand.max(1) < 2).to(beTrue())
                expect(Demand.max(1) <= 1).to(beTrue())
                
                expect(Demand.unlimited).to(beGreaterThan(.max(Int.max)))
                expect(Demand.max(Int.max)).to(beLessThan(.unlimited))
                expect(Demand.unlimited).to(equal(.unlimited))
                
                expect(Demand.unlimited).toNot(beLessThan(.unlimited))
                expect(Demand.unlimited).toNot(beGreaterThan(.unlimited))
                
                expect(Demand.max(1) > -1).to(beTrue())
                expect(Demand.max(1) < -1).to(beFalse())
            }
        }
        
        // MARK: - Codable
        describe("Codable") {
            
            // MARK: 4.1 should be codable
            it("should be codable") {
                let a = Demand.unlimited
                let b = Demand.max(10)
                
                expect {
                    let encoder = JSONEncoder()
                    let dataA = try encoder.encode(a)
                    let dataB = try encoder.encode(b)
                    
                    expect(String(data: dataA, encoding: .utf8)).to(equal("{\"rawValue\":9223372036854775808}"))
                    
                    let decoder = JSONDecoder()
                    let x = try decoder.decode(Demand.self, from: dataA)
                    let y = try decoder.decode(Demand.self, from: dataB)
                    
                    expect(x).to(equal(a))
                    expect(y).to(equal(b))
                    return ()
                }.toNot(throwError())
            }
        }
    }
}