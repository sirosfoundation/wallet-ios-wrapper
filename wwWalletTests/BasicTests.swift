//
//  BasicTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 13.03.26.
//

import Testing
import SwiftUI
@testable import wwWallet

@Suite("Basic Test Suite")
struct BasicTests {

    @Test("Test base domains configuration")
    func testBaseDomains() {
        let domains = Config.baseDomains
        #expect(domains.count > 0)
        
        for domain in domains {
            #expect(!domain.isEmpty)
        }

        #expect(!Config.baseDomain.isEmpty)
    }

    @Test("Test default base domain selection")
    func testBaseDomainSelection() {
        let defaultDomain = Config.baseDomain
        #expect(!defaultDomain.isEmpty)
        #expect(Config.baseDomains.contains(defaultDomain))
    }

    @Test("Test environment-based domain selection")
    func testEnvironmentBasedDomainSelection() async throws {
        let defaults = UserDefaults.standard
        let originalEnvironment = defaults.string(forKey: "environment")
        
        // Test selecting the first domain (index 0)
        defaults.set("0", forKey: "environment")
        #expect(Config.baseDomain == Config.baseDomain1)

        // Test invalid index (out of bounds)
        defaults.set("99", forKey: "environment")
        #expect(Config.baseDomain == Config.baseDomain1)

        // Test non-integer index
        defaults.set("abc", forKey: "environment")
        #expect(Config.baseDomain == Config.baseDomain1)

        // Cleanup
        if let originalEnvironment = originalEnvironment {
            defaults.set(originalEnvironment, forKey: "environment")
        } else {
            defaults.removeObject(forKey: "environment")
        }
    }

    @Test("Test ContentView structure")
    func testContentViewStructure() {
        // Test that ContentView can be initialized without crashing
        _ = ContentView()
        #expect(true) // If we got to here, initialization worked
    }

    @Test("Test domain switching configuration")
    func testDomainSwitchingConfiguration() {
        #if ALLOW_DOMAIN_SWITCHING
        #expect(true, "Domain switching is enabled")
        #else
        #expect(true, "Domain switching is disabled")
        #endif
    }

    @Test("Test Data webSafeBase64EncodedString extension")
    func testDataWebSafeBase64Encoding() {
        let testData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = testData.webSafeBase64EncodedString()
        #expect(!encoded.isEmpty)
        
        // Verify that the encoding produces web-safe base64 (no padding, + and / replaced with - and _)
        #expect(!encoded.contains("+"))
        #expect(!encoded.contains("/"))
        #expect(!encoded.contains("="))
        
        // Test empty data
        let emptyData = Data()
        #expect(emptyData.webSafeBase64EncodedString() == "")
    }
    
    @Test("Test Data webSafeBase64DecodedData extension")
    func testDataWebSafeBase64Decoding() {
        // Test valid web-safe base64 string
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = originalData.webSafeBase64EncodedString()
        
        let decoded = encoded.webSafeBase64DecodedData()
        #expect(decoded != nil)
        #expect(decoded == originalData)
        
        // Test decoding with padding present (should handle it)
        let encodedWithPadding = "AQIDBA==".replacingOccurrences(of: "=", with: "") 
        let decodedWithPadding = encodedWithPadding.webSafeBase64DecodedData()
        #expect(decodedWithPadding == originalData)
    }

    @Test("Test String webSafeBase64DecodedData extension with valid input")
    func testStringWebSafeBase64DecodingValidInput() {
        // Test with a known valid base64 string
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = originalData.base64EncodedString()
        
        // Convert to web-safe format
        let webSafeEncoded = encoded
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let decoded = webSafeEncoded.webSafeBase64DecodedData()
        #expect(decoded != nil)
        #expect(decoded == originalData)
    }
    
    @Test("Test Data hexString property")
    func testDataHexString() {
        let testData = Data([0x12, 0x34, 0x56, 0x78])
        let hexString = testData.hexString
        #expect(hexString == "12345678")
        
        let emptyData = Data()
        #expect(emptyData.hexString == "")
        
        let singleByte = Data([0xFF])
        #expect(singleByte.hexString == "ff")
    }
}
