import CombineX
import Foundation

extension CXWrappers {
    
    open class JSONDecoder: CXWrapper {
        
        public typealias Base = Foundation.JSONDecoder
        
        public var base: Base
        
        public required init(_ base: Base) {
            self.base = base
        }
    }
}

extension JSONDecoder: CXWrappable {
    
    public typealias CX = CXWrappers.JSONDecoder
}

extension JSONDecoder.CX: CombineX.TopLevelDecoder {
        
    public typealias Input = Data
    
    public func decode<T>(_ type: T.Type, from: Input) throws -> T where T : Decodable {
        return try self.base.decode(type, from: from)
    }
}

