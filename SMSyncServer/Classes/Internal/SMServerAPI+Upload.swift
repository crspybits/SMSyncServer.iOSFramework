//
//  SMServerAPI+Upload.swift
//  Pods
//
//  Created by Christopher Prince on 9/4/16.
//
//

import Foundation
import SMCoreLib

internal extension SMServerAPI {

    // fileToUpload must have a localURL.
    internal func uploadFile(fileToUpload: SMServerFile, completion:((apiResult:SMServerAPIResult)->(Void))?) {
    
        let serverOpURL = NSURL(string: self.serverURLString + "/" + SMServerConstants.operationUploadFile)!
        
        let userParams = self.userDelegate.userCredentialParams
        Assert.If(nil == userParams, thenPrintThisString: "No user server params!")
        
        var parameters = userParams!
        parameters += fileToUpload.dictionary
        
        if fileToUpload.undeleteServerFile != nil {
            Assert.If(fileToUpload.undeleteServerFile! == false, thenPrintThisString: "Yikes: Must give undeleteServerFile as true or nil")
            parameters[SMServerConstants.undeleteFileKey] = true
        }
        
        SMServerNetworking.session.uploadFileTo(serverOpURL, fileToUpload: fileToUpload.localURL!, withParameters: parameters) { serverResponse, error in
            let result = self.initialServerResponseProcessing(serverResponse, error: error)
            completion?(apiResult: result)
        }
    }
    
    // Recursive multiple file upload implementation. If there are no files in the filesToUpload parameter array, this doesn't call the server, and has no effect but calling the completion handler with nil parameters.
    internal func uploadFiles(filesToUpload: [SMServerFile]?, completion:((apiResult:SMServerAPIResult)->(Void))?) {
        if filesToUpload != nil && filesToUpload!.count >= 1 {
            self.uploadFilesAux(filesToUpload!, completion: completion)
        }
        else {
            Log.warning("No files to upload")
            completion?(apiResult: SMServerAPIResult(returnCode: nil, error: nil))
        }
    }
    
    // Assumes we've already validated that there is at least one file to upload.
    // TODO: If we get a failure uploading an individual file, retry some MAX number of times.
    private func uploadFilesAux(filesToUpload: [SMServerFile], completion:((apiResult:SMServerAPIResult)->(Void))?) {
        if filesToUpload.count >= 1 {
            let serverFile = filesToUpload[0]
            Log.msg("Uploading file: \(serverFile.localURL)")
            self.uploadFile(serverFile) { apiResult in
                if (nil == apiResult.error) {
                    self.uploadDelegate?.smServerAPIFileUploaded(serverFile)
                    let remainingFiles = Array(filesToUpload[1..<filesToUpload.count])
                    self.uploadFilesAux(remainingFiles, completion: completion)
                }
                else {
                    completion?(apiResult: apiResult)
                }
            }
        }
        else {
            // The base-case of the recursion: All has completed normally, will have nil parameters for completion.
            completion?(apiResult: SMServerAPIResult(returnCode: nil, error: nil))
        }
    }
 
    // Indicates that a group of files in the cloud should be deleted.
    // You must have a lock beforehand. This does nothing, but calls the callback if filesToDelete is nil or is empty.
    internal func deleteFiles(filesToDelete: [SMServerFile]?, completion:((apiResult:SMServerAPIResult)->(Void))?) {
    
        if filesToDelete == nil || filesToDelete!.count == 0 {
            completion?(apiResult: SMServerAPIResult(returnCode: nil, error: nil))
            return
        }
        
        let serverOpURL = NSURL(string: self.serverURLString +
                        "/" + SMServerConstants.operationDeleteFiles)!
        
        let userParams = self.userDelegate.userCredentialParams
        Assert.If(nil == userParams, thenPrintThisString: "No user server params!")

        var serverParams = userParams!
        var deletionServerParam = [AnyObject]()
        
        for serverFile in filesToDelete! {
            let serverFileDict = serverFile.dictionary
            deletionServerParam.append(serverFileDict)
        }
        
        serverParams[SMServerConstants.filesToDeleteKey] = deletionServerParam

        SMServerNetworking.session.sendServerRequestTo(toURL: serverOpURL, withParameters: serverParams) { (serverResponse:[String:AnyObject]?, error:NSError?) in
        
            let result = self.initialServerResponseProcessing(serverResponse, error: error)
            completion?(apiResult: result)
        }
    }
    
    internal func finishUploads(fileIndexVersion fileIndexVersion:Int, completion:((apiResult:SMServerAPIResult)->(Void))?) {
        
        let serverOpURL = NSURL(string: self.serverURLString +
                        "/" + SMServerConstants.operationFinishUploads)!
        
        var serverParams = self.userDelegate.userCredentialParams
        Assert.If(nil == serverParams, thenPrintThisString: "No user server params!")

        serverParams![SMServerConstants.fileIndexVersionKey] = fileIndexVersion

        SMServerNetworking.session.sendServerRequestTo(toURL: serverOpURL, withParameters: serverParams!) { (serverResponse:[String:AnyObject]?, error:NSError?) in
        
            let result = self.initialServerResponseProcessing(serverResponse, error: error)
            completion?(apiResult: result)
        }
    }
    
    // You must have obtained a lock beforehand, and uploaded/deleted one file after that.
    internal func startOutboundTransfer(completion:((serverOperationId:String?, apiResult:SMServerAPIResult)->(Void))?) {
        let userParams = self.userDelegate.userCredentialParams
        Assert.If(nil == userParams, thenPrintThisString: "No user server params!")

        let serverOpURL = NSURL(string: self.serverURLString +
                        "/" + SMServerConstants.operationStartOutboundTransfer)!
        
        SMServerNetworking.session.sendServerRequestTo(toURL: serverOpURL, withParameters: userParams!) { (serverResponse:[String:AnyObject]?, error:NSError?) in
        
            var result = self.initialServerResponseProcessing(serverResponse, error: error)
            
            let serverOperationId:String? = serverResponse?[SMServerConstants.resultOperationIdKey] as? String
            Log.msg("\(serverOpURL); OperationId: \(serverOperationId)")
            if (nil == result.error && nil == serverOperationId) {
                result.error = Error.Create("No server operationId obtained")
            }
            
            completion?(serverOperationId: serverOperationId, apiResult:result)
        }
    }
}
