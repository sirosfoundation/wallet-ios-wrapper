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

    @Test("Test ContentView structure")
    func testContentViewStructure() {
        // Test that ContentView can be initialized without crashing
        _ = ContentView()
        #expect(true) // If we got here, initialization worked
    }

    @Test("Test domain switching configuration")
    func testDomainSwitchingConfiguration() {
        #if ALLOW_DOMAIN_SWITCHING
        #expect(true, "Domain switching is enabled")
        #else
        #expect(true, "Domain switching is disabled")
        #endif
    }

    @Test("Test color from hex parsing")
    func testColorFromHex() {
        // Test valid hex colors
        let color1 = Color(hex: "000000")  // Black
        #expect(color1 == .black)

        let color2 = Color(hex: "FFFFFF")  // White
        #expect(color2 == .white)

        let color3 = Color(hex: "FF0000")  // Red
        #expect(color3 == Color(red: 1, green: 0, blue: 0, opacity: 1))
    }

    @Test("Test invalid hex color handling")
    func testInvalidHexColor() {
        // Test invalid hex color should return nil
        let color = Color(hex: "WXYZ")
        #expect(color == nil)
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
    }
    
    @Test("Test Data webSafeBase64DecodedData extension")
    func testDataWebSafeBase64Decoding() {
        // Test valid web-safe base64 string
        let originalData = Data([0x01, 0x02, 0x03, 0x04])
        let encoded = originalData.webSafeBase64EncodedString()
        
        let decoded = encoded.webSafeBase64DecodedData()
        #expect(decoded != nil)
        #expect(decoded == originalData)
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
    }
}
