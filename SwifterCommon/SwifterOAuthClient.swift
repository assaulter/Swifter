//
//  SwifterOAuthClient.swift
//  Swifter
//
//  Copyright (c) 2014 Matt Donnelly.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Accounts

class SwifterOAuthClient: SwifterClientProtocol  {

    struct OAuth {
        static let version = "1.0"
        static let signatureMethod = "HMAC-SHA1"
    }

    var consumerKey: String
    var consumerSecret: String

    var account: SwifterAccount?

    var stringEncoding: NSStringEncoding

    init(consumerKey: String, consumerSecret: String) {
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.stringEncoding = NSUTF8StringEncoding
    }

    func requestWithPath(path: String, baseURL: NSURL, method: String, parameters: Dictionary<String, AnyObject>, progress: SwifterHTTPRequest.DownloadProgressHandler?, success: SwifterHTTPRequest.RequestSuccessHandler?, failure: SwifterHTTPRequest.RequestFailureHandler?) {
        let url = NSURL(string: path, relativeToURL: baseURL)
        let request = SwifterHTTPRequest(URL: url, method: method, parameters: parameters)
        request.headers = ["Authorization": self.authorizationHeaderForMethod(method, url: url, parameters: parameters)]
        request.downloadRequestProgressHandler = progress
        request.requestSuccessHandler = success
        request.requestFailureHandler = failure
        request.dataEncoding = self.stringEncoding

        request.start()
    }

    func dataRequestWithPath(path: String, baseURL: NSURL, method: String, parameters: Dictionary<String, AnyObject>, progress: SwifterHTTPRequest.DownloadProgressHandler?, success: SwifterHTTPRequest.DataRequestSuccessHandler?, failure: SwifterHTTPRequest.RequestFailureHandler?) {
        let url = NSURL(string: path, relativeToURL: baseURL)
        let request = SwifterHTTPRequest(URL: url, method: method, parameters: parameters)
        request.headers = ["Authorization": self.authorizationHeaderForMethod(method, url: url, parameters: parameters)]
        request.downloadRequestProgressHandler = progress
        request.dataRequestSuccessHandler = success
        request.requestFailureHandler = failure
        request.dataEncoding = self.stringEncoding

        request.start()
    }

    func get(path: String, baseURL: NSURL, parameters: Dictionary<String, AnyObject>, progress: SwifterHTTPRequest.DownloadProgressHandler?, success: SwifterHTTPRequest.DataRequestSuccessHandler?, failure: SwifterHTTPRequest.RequestFailureHandler?) {
        self.dataRequestWithPath(path, baseURL: baseURL, method: "GET", parameters: parameters, progress: progress, success: success, failure: failure)
    }

    func post(path: String, baseURL: NSURL, parameters: Dictionary<String, AnyObject>, progress: SwifterHTTPRequest.DownloadProgressHandler?, success: SwifterHTTPRequest.DataRequestSuccessHandler?, failure: SwifterHTTPRequest.RequestFailureHandler?) {
        self.dataRequestWithPath(path, baseURL: baseURL, method: "POST", parameters: parameters, progress: progress, success: success, failure: failure)
    }

    func authorizationHeaderForMethod(method: String, url: NSURL, parameters: Dictionary<String, AnyObject>) -> String {
        var authorizationParameters = Dictionary<String, AnyObject>()
        authorizationParameters["oauth_version"] = OAuth.version
        authorizationParameters["oauth_signature_method"] =  OAuth.signatureMethod
        authorizationParameters["oauth_consumer_key"] = self.consumerKey
        authorizationParameters["oauth_timestamp"] = String(Int(NSDate().timeIntervalSince1970))
        authorizationParameters["oauth_nonce"] = NSUUID().UUIDString.bridgeToObjectiveC()

        if self.account?.accessToken {
            authorizationParameters["oauth_token"] = self.account!.accessToken!.key
        }

        for (key, value: AnyObject) in parameters {
            if key.hasPrefix("oauth_") {
                authorizationParameters.updateValue(value, forKey: key)
            }
        }

        let combinedParameters = authorizationParameters.join(parameters)

        authorizationParameters["oauth_signature"] = self.oauthSignatureForMethod(method, url: url, parameters: combinedParameters, accessToken: self.account?.accessToken)

        let authorizationParameterComponents = authorizationParameters.urlEncodedQueryStringWithEncoding(self.stringEncoding).componentsSeparatedByString("&") as String[]
        authorizationParameterComponents.sort { $0 < $1 }

        var headerComponents = String[]()
        for component in authorizationParameterComponents {
            let subcomponent = component.componentsSeparatedByString("=") as String[]
            if subcomponent.count == 2 {
                headerComponents.append("\(subcomponent[0])=\"\(subcomponent[1])\"")
            }
        }

        return "OAuth " + headerComponents.bridgeToObjectiveC().componentsJoinedByString(", ")
    }

    func oauthSignatureForMethod(method: String, url: NSURL, parameters: Dictionary<String, AnyObject>, accessToken token: SwifterAccount.OAuthAccessToken?) -> String {
        var tokenSecret: NSString = ""
        if token {
            tokenSecret = token!.secret.urlEncodedStringWithEncoding(self.stringEncoding)
        }

        let encodedConsumerSecret = self.consumerSecret.urlEncodedStringWithEncoding(self.stringEncoding)

        let signingKey = "\(encodedConsumerSecret)&\(tokenSecret)"
        let signingKeyData = signingKey.bridgeToObjectiveC().dataUsingEncoding(self.stringEncoding)

        let parameterComponents = parameters.urlEncodedQueryStringWithEncoding(self.stringEncoding).componentsSeparatedByString("&") as String[]
        parameterComponents.sort { $0 < $1 }

        let parameterString = parameterComponents.bridgeToObjectiveC().componentsJoinedByString("&")
        let encodedParameterString = parameterString.urlEncodedStringWithEncoding(self.stringEncoding)

        let encodedURL = url.absoluteString.urlEncodedStringWithEncoding(self.stringEncoding)

        let signatureBaseString = "\(method)&\(encodedURL)&\(encodedParameterString)"
        let signatureBaseStringData = signatureBaseString.dataUsingEncoding(self.stringEncoding)
        
        return HMACSHA1Signature.signatureForKey(signingKeyData, data: signatureBaseStringData).base64EncodedStringWithOptions(nil)
    }
    
}