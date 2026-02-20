import Foundation

class SecureUnarchiver {

    /// Securely unarchives data with explicitly defined allowed classes
    /// - Parameters:
    ///   - data: The data to unarchive
    ///   - allowedClasses: Array of classes that should be allowed for unarchiving
    /// - Returns: The unarchived object, or nil if unarchiving fails
    static func unarchiveObject<T>(from data: Data, allowedClasses: [AnyClass]) -> T? {
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true

            // Set the allowed classes
            let allowedClassesForDecoding: [AnyClass] = allowedClasses

            // Decode the object with the allowed classes
            guard let object = try unarchiver.decodeTopLevelObject(of: allowedClassesForDecoding)
            else {
                print("Failed to decode object: no object found")
                return nil
            }

            return object as? T
        } catch {
            print("Failed to unarchive object: \(error)")
            return nil
        }
    }

    /// Example method for unarchiving common Foundation types
    static func unarchiveFoundationObject(from data: Data) -> Any? {
        let allowedClasses: [AnyClass] = [
            NSString.self,
            NSNumber.self,
            NSArray.self,
            NSDictionary.self,
            NSDate.self,
            NSData.self,
            NSURL.self,
            NSUUID.self,
        ]

        return unarchiveObject(from: data, allowedClasses: allowedClasses)
    }

    /// Example method for unarchiving with custom object class
    static func unarchiveCustomObject<T: NSCoding & NSObjectProtocol>(
        from data: Data, customClass: T.Type
    ) -> T? {
        let allowedClasses: [AnyClass] = [
            NSString.self,
            NSNumber.self,
            NSArray.self,
            NSDictionary.self,
            customClass,
        ]

        return unarchiveObject(from: data, allowedClasses: allowedClasses)
    }
}
