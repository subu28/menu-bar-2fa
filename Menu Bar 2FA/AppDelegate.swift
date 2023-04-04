//
//  AppDelegate.swift
//  Menu Bar 2FA
//
//  Created by Scott Mangiapane on 4/17/20.
//  Copyright © 2020 Scott Mangiapane. All rights reserved.
//

import Cocoa
import KeychainAccess
import SwiftOTP
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var keychain = Keychain(service: "org.sanyaas.2fa")
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var count: Int!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu();
        
        count = Int(keychain["count"] ?? "") ?? 0;
        
        if (count != 0) {
            menu.addItem(
                withTitle: "Refreshing in 30s",
                action: #selector(AppDelegate.updateTimer),
                keyEquivalent: "")
            menu.addItem(.separator())
        }
        
        var i = 0;
        while (i < count) {
            menu.addItem(
                withTitle: getSecretName(index: i) + " : " + getTOTP(index: i),
                action: #selector(AppDelegate.copyToken(withSender:)),
                keyEquivalent: ""
            )
            menu.addItem(
                withTitle: "Edit/Delete",
                action: #selector(AppDelegate.editSecret(withSender:)),
                keyEquivalent: "")
            menu.addItem(.separator())
            i += 1;
        }

        menu.addItem(
            withTitle: "Add Secret",
            action: #selector(AppDelegate.promptSecret),
            keyEquivalent: "")

        menu.addItem(
            withTitle: "Quit",
            action: #selector(AppDelegate.quitApp),
            keyEquivalent: "")
        
        return menu;
    }

    func setupStatusBar() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.image = NSImage(named: NSImage.Name("lock"))
        let statusBarMenu = buildMenu()
        statusBarItem.menu = statusBarMenu

        let timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(AppDelegate.updateTimer),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc func updateTimer()
    {
        if (count == 0) {
            return;
        }
        let calendar = NSCalendar.current
        let components = calendar.dateComponents([.second], from: Date())
        let remaining = 30 - components.second! % 30
        if (remaining == 30) {
            updateCodes()
        }
        statusBarItem.menu?.item(at: 0)?.title = "Refreshing in " + String(remaining) + "s"
        statusBarItem.menu?.item(at: 0)?.isEnabled = false
    }
    
    @objc func updateCodes() {
        var i = 0;
        while (i < count) {
            statusBarItem.menu?.item(at: ((i+1)*3)-1 )?.title = getSecretName(index: i) + " : " + getTOTP(index: i)
            i += 1;
        }
    }
    
    @objc func updateMenu()
    {
        statusBarItem.menu = buildMenu()
    }
    
    @objc func addSecret(name: String, code: String, count: Int) {
        let oldCode = keychain["base32"] ?? "";
        let oldName = keychain["name"] ?? "";
        keychain["base32"] = oldCode + code + " | ";
        keychain["name"] = oldName + name + " | ";
        keychain["count"] = String(count);
    }
    
    @objc func getSecretCode(index: Int) -> String {
        let code = (keychain["base32"] ?? "").components(separatedBy: " | ");
        return code[index];
    }
    
    @objc func getSecretName(index: Int) -> String{
        let name = (keychain["name"] ?? "").components(separatedBy: " | ");
        return name[index];
    }
    
    @objc func deleteSecret(index: Int) {
        let code = (keychain["base32"] ?? "").components(separatedBy: " | ");
        let name = (keychain["name"] ?? "").components(separatedBy: " | ");
        
        var newCode = "";
        var newName = "";
        
        var i = 0;
        while (i < count) {
            if (i != index) {
                newCode = newCode + code[i] + " | ";
                newName = newName + name[i] + " | ";
            }
            i += 1;
        }
        if (count - 1 == 0) {
            do {
                try keychain.removeAll()
            } catch (_) {

            }
        } else {
            keychain["base32"] = newCode;
            keychain["name"] = newName;
            keychain["count"] = String(count - 1);
        }
    }
    
    @objc func changeSecret(index: Int, code: String, name: String) {
        let codeArray = (keychain["base32"] ?? "").components(separatedBy: " | ");
        let nameArray = (keychain["name"] ?? "").components(separatedBy: " | ");
        
        var newCode = "";
        var newName = "";
        
        var i = 0;
        while (i < count) {
            if (i != index) {
                newCode = newCode + codeArray[i] + " | ";
                newName = newName + nameArray[i] + " | ";
            } else {
                newCode = newCode + code + " | ";
                newName = newName + name + " | ";
            }
            i += 1;
        }

        keychain["base32"] = newCode;
        keychain["name"] = newName;
    }
    
    @objc func getTOTP(index: Int) -> String {
        let secret = getSecretCode(index: index)
        guard let data = base32DecodeToData(secret) else { return "ERR" }
        if let totp = TOTP(secret: data) {
            return totp.generate(time: Date()) ?? "ERR"
        }
        return "ERR"
    }

    @objc func copyToken(withSender sender: NSMenuItem) {
        let index = (statusBarItem.menu?.index(of: sender) ?? 0)/3
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(getTOTP(index: index), forType: .string)
    }

    @objc func promptSecret() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Add new 2FA"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let nameLabel = NSTextField(labelWithString: "Title")
        let codeLabel = NSTextField(labelWithString: "Code")
        let labelView = NSStackView(views: [nameLabel, codeLabel])
        labelView.orientation = .vertical
        
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        let code = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        let inputView = NSStackView(views: [name, code])
        inputView.orientation = .vertical
        
        let accessoryView = NSStackView(views: [labelView, inputView]);
        accessoryView.setFrameSize(NSSize(width: 200, height: 48))
        accessoryView.translatesAutoresizingMaskIntoConstraints = true
        
        alert.accessoryView = accessoryView;
        
        let response: NSApplication.ModalResponse = alert.runModal()

        if (response == .alertFirstButtonReturn) {
            addSecret(name: name.stringValue, code: code.stringValue, count: count + 1)
            updateMenu()
            return true
        }
        return false
    }
    
    @objc func editSecret(withSender sender: NSMenuItem) -> Bool {
        let alert = NSAlert()
        let index = ((statusBarItem.menu?.index(of: sender) ?? 0)/3) - 1
        alert.messageText = "Edit " + getSecretName(index: index);
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let nameLabel = NSTextField(labelWithString: "Title")
        let codeLabel = NSTextField(labelWithString: "Code")
        let labelView = NSStackView(views: [nameLabel, codeLabel])
        labelView.orientation = .vertical
        
        
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        let code = NSTextField(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        let inputView = NSStackView(views: [name, code])
        inputView.orientation = .vertical
        
        name.stringValue = getSecretName(index: index);
        code.stringValue = "*************";
        
        let accessoryView = NSStackView(views: [labelView, inputView]);
        accessoryView.setFrameSize(NSSize(width: 200, height: 48))
        accessoryView.translatesAutoresizingMaskIntoConstraints = true
        
        alert.accessoryView = accessoryView;
        
        let response: NSApplication.ModalResponse = alert.runModal()

        if (response == .alertFirstButtonReturn) {
            changeSecret(index: index, code: code.stringValue, name: name.stringValue)
            updateMenu()
            return true
        }
        if (response == .alertSecondButtonReturn) {
            deleteSecret(index: index);
            updateMenu()
            return true
        }
        return false
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {}
}
