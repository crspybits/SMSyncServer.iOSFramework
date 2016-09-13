//
//  SMDownloadWrapup.swift
//  
//
//  Created by Christopher Prince on 9/4/16.
//
//

import Foundation
import CoreData
import SMCoreLib

class SMDownloadWrapup: SMDownloadOperation {
    enum WrapupStage : String {
        case FetchFileIndex
    }
    
    // Don't access internalWrapupStage directly.
    var startupStage : WrapupStage {
        get {
            return WrapupStage(rawValue: self.internalWrapupStage!)!
        }
        set {
            self.internalWrapupStage = newValue.rawValue
            CoreData.sessionNamed(SMCoreData.name).saveContext()
        }
    }
    
    class func entityName() -> String {
        return "SMDownloadWrapup"
    }

    class func newObject() -> NSManagedObject {
        let wrapup = CoreData.sessionNamed(
            SMCoreData.name).newObjectWithEntityName(self.entityName()) as! SMDownloadWrapup
        wrapup.startupStage = .FetchFileIndex
        
        CoreData.sessionNamed(SMCoreData.name).saveContext()

        return wrapup
    }
}
