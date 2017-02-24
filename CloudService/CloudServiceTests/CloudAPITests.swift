//
//  CloudAPITests.swift
//  CloudServiceTests
//
//  Created by Tobias Kräntzer on 04.02.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import XCTest
import OHHTTPStubs
@testable import CloudService

class CloudAPITests: XCTestCase, CloudAPIDelegate {
    
    override func tearDown() {
        OHHTTPStubs.removeAllStubs()
        super.tearDown()
    }
    
    // MARK: Tests
    
    func testRetrieveProperties() {
        let api = CloudAPI(identifier: "CloudAPITests.testRetrieveProperties", delegate: self)
        
        defer {
            api.invalidateAndCancel()
        }
        
        stub(condition: isHost("example.com") && isPath("/webdav")) { _ in
            let stubPath = OHPathForFile("propfind.xml", type(of: self))
            return fixture(filePath: stubPath!, status: 207, headers: ["Content-Type": "application/xml"])
        }
        
        let expectation = self.expectation(description: "Response")
        api.retrieveProperties(of: URL(string: "https://example.com/webdav/")!) { response, error in
            XCTAssertNil(error)
            XCTAssertEqual(response?.resources.count, 6)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0, handler: nil)
    }

    // MARK: - CloudAPIDelegate
    
    func cloudAPI(_: CloudAPI, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "cloud.example.org" {
            completionHandler(.useCredential, URLCredential(user: "username", password: "password", persistence: .forSession))
        } else {
            completionHandler(.rejectProtectionSpace, nil)
        }
    }
    
    func cloudAPI(_: CloudAPI, didFailDownloading url: URL, error: Error) {
        let center = NotificationCenter.default
        let userInfo: [AnyHashable: Any] = ["url": url, "error": error]
        center.post(
            name: Notification.Name(rawValue: "CloudAPITests.cloudAPI(_:didFailDownloading:error:)"),
            object: self,
            userInfo: userInfo
        )
    }
    
    func cloudAPI(_: CloudAPI, didProgressDownloading url: URL, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let center = NotificationCenter.default
        let userInfo: [AnyHashable: Any] = ["url": url, "totalBytesWritten": totalBytesWritten, "totalBytesExpectedToWrite": totalBytesExpectedToWrite]
        center.post(
            name: Notification.Name(rawValue: "CloudAPITests.cloudAPI(_:didProgressDownloading:totalBytesWritten:totalBytesExpectedToWrite:)"),
            object: self,
            userInfo: userInfo
        )
    }
    
    func cloudAPI(_: CloudAPI, didFinishDownloading url: URL, etag: String, to location: URL) {
        let center = NotificationCenter.default
        let userInfo: [AnyHashable: Any] = ["url": url, "etag": etag, "location": location]
        center.post(
            name: Notification.Name(rawValue: "CloudAPITests.cloudAPI(_:didFinishDownloading:etag:to:)"),
            object: self,
            userInfo: userInfo
        )
    }
}
