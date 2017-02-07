//
//  CloudService.swift
//  CloudStore
//
//  Created by Tobias Kraentzer on 06.02.17.
//  Copyright © 2017 Tobias Kräntzer. All rights reserved.
//

import Foundation
import Dispatch

extension Notification.Name {
    public static let CloudServiceDidAddAccount = Notification.Name(rawValue: "CloudStore.CloudServiceDidAddAccount")
    public static let CloudServiceDidUdpateAccount = Notification.Name(rawValue: "CloudStore.CloudServiceDidUdpateAccount")
    public static let CloudServiceDidRemoveAccount = Notification.Name(rawValue: "CloudStore.CloudServiceDidRemoveAccount")
    public static let CloudServiceDidChangeAccounts = Notification.Name(rawValue: "CloudStore.CloudServiceDidChangeAccounts")
    public static let CloudServiceDidChangeResources = Notification.Name(rawValue: "CloudStore.CloudServiceDidChangeResources")
}

public let AccountKey = "CloudStore.AccountKey"
public let InsertedOrUpdatedResourcesKey = "CloudStore.InsertedOrUpdatedResourcesKey"
public let DeletedResourcesKey = "CloudStore.DeletedResourcesKey"

public protocol CloudServiceDelegate: class {
    func service(_ service: CloudService, needsPasswordFor account: CloudService.Account, completionHandler: @escaping (String?) -> Void) -> Void
}

public class CloudService {
    
    public typealias Store = FileStore
    public typealias Resource = Store.Resource
    public typealias Account = Store.Account
    
    public weak var delegate: CloudServiceDelegate?

    private let store: Store
    private let queue: DispatchQueue
    
    public init(directory: URL) {
        self.store = FileStore(directory: directory)
        self.queue = DispatchQueue(label: "CloudService")
    }
    
    public func start(completion: ((Error?)->Void)?) {
        queue.async {
            self.store.open(completion: completion)
        }
    }
    
    // MARK: - Account Management
    
    public var accounts: [Store.Account] {
        return store.accounts
    }
    
    public func addAccount(with url: URL, username: String) throws -> Account {
        let account = try store.addAccount(with: url, username: username)
        
        let center = NotificationCenter.default
        center.post(name: Notification.Name.CloudServiceDidAddAccount,
                    object: self,
                    userInfo: [AccountKey: account])
        center.post(name: Notification.Name.CloudServiceDidChangeAccounts,
                    object: self)
        
        return account
    }
    
    public func update(_ account: Account, with label: String?) throws -> Account {
        let account = try store.update(account, with: label)
        
        let center = NotificationCenter.default
        center.post(name: Notification.Name.CloudServiceDidUdpateAccount,
                    object: self,
                    userInfo: [AccountKey: account])
        center.post(name: Notification.Name.CloudServiceDidChangeAccounts,
                    object: self)
        
        return account
    }
    
    public func remove(_ account: Account) throws {
        try store.remove(account)
        
        let center = NotificationCenter.default
        center.post(name: Notification.Name.CloudServiceDidRemoveAccount,
                    object: self,
                    userInfo: [AccountKey: account])
        center.post(name: Notification.Name.CloudServiceDidChangeAccounts,
                    object: self)
    }
    
    // MARK: - Resource Management
    
    private var resourceManager: [Account:ResourceManager] = [:]
    
    private func resourceManager(for account: Account) -> ResourceManager {
        if let manager = resourceManager[account] {
            return manager
        } else {
            let manager = ResourceManager(store: store, account: account)
            manager.delegate = self
            resourceManager[account] = manager
            return manager
        }
    }
    
    public func resource(of account: Account, at path: [String]) throws -> Resource? {
        return try store.resource(of: account, at: path)
    }
    
    public func contents(of account: Account, at path: [String]) throws -> [Resource] {
        return try store.contents(of: account, at: path)
    }
    
    public func updateResource(at path: [String], of account: Account, completion: ((Error?) -> Void)?) {
        queue.async {
            let manager = self.resourceManager(for: account)
            manager.updateResource(at: path, completion: completion)
        }
    }
}

extension CloudService: ResourceManagerDelegate {
    
    func resourceManager(_ manager: ResourceManager, needsPasswordWith completionHandler: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            if let delegate = self.delegate {
                delegate.service(self,
                                 needsPasswordFor: manager.account,
                                 completionHandler: completionHandler)
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func resourceManager(_ manager: ResourceManager, didChange changeSet: Store.ChangeSet) {
        DispatchQueue.main.async {
            let center = NotificationCenter.default
            center.post(name: Notification.Name.CloudServiceDidChangeResources,
                        object: self,
                        userInfo: [InsertedOrUpdatedResourcesKey: changeSet.insertedOrUpdated,
                                   DeletedResourcesKey: changeSet.deleted])
        }
    }
}
