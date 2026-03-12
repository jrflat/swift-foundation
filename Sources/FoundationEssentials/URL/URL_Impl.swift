//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
@preconcurrency import Android
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif os(Windows)
import WinSDK
#elseif os(WASI)
@preconcurrency import WASILibc
#endif

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import Synchronization
#endif

/// `_URL` provides the newer, faster Swift implementation for `URL`.
///
/// Outside of `FOUNDATION_FRAMEWORK`, `_URL` will provide the sole implementation
/// for `URL`. In `FOUNDATION_FRAMEWORK`, there is an additional class to handle `NSURL`
/// subclassing and bridging from ObjC.
///
/// - Note: For functions returning `URL?`, a `nil` return value allows `struct URL` to return `self` without creating a new struct.
internal final class _URL: Sendable, Hashable, Equatable {
    private let _info: _URLInfo
    private let _baseURL: (any _URLProtocol & AnyObject)?

    #if FOUNDATION_FRAMEWORK
    // Note: We use a lock instead of a lazy var to ensure that we always
    // bridge to the same NSURL even if the URL was copied across threads.
    private let _nsurlLock = Mutex<NSURL?>(nil)
    private var _nsurl: NSURL {
        return _nsurlLock.withLock {
            if let nsurl = $0 { return nsurl }
            let nsurl = _swiftCFURL() as NSURL
            $0 = nsurl
            return nsurl
        }
    }
    #endif

    @inline(__always)
    private var flags: _URLFlags {
        _info.flags
    }

    @inline(__always)
    private var url: URL {
        URL(self)
    }

    @inline(__always)
    private init(_info: _URLInfo, _baseURL: (any _URLProtocol & AnyObject)?) {
        // We shouldn't be passing a base URL if we have a scheme
        assert(_baseURL == nil || !_info.hasScheme)
        self._info = _info
        self._baseURL = _baseURL
    }

    @inline(__always)
    private func replacing(info: _URLInfo) -> _URL {
        _URL(_info: info, _baseURL: _baseURL)
    }

    @inline(__always)
    private init(info: _URLInfo, relativeTo base: URL?) {
        _baseURL = info.hasScheme ? nil : base?.absoluteURL._url
        if let _baseURL, _baseURL.isFileURL {
            _info = info.inserting(flags: .isFileURL)
        } else {
            _info = info
        }
    }

    @inline(__always)
    private init(url: _URL) {
        _info = url._info
        _baseURL = url._baseURL
    }

    convenience init?(_ string: String, relativeTo base: URL? = nil, encodingInvalidCharacters: Bool = true) {
        guard let parseInfo = _URLInfo.parse(
            string: string,
            encodingInvalidCharacters: encodingInvalidCharacters
        ) else {
            return nil
        }
        self.init(info: parseInfo, relativeTo: base)
    }

    convenience init?(string: String) {
        guard !string.isEmpty else { return nil }
        self.init(string)
    }
    
    convenience init?(string: String, relativeTo base: URL?) {
        guard !string.isEmpty else { return nil }
        self.init(string, relativeTo: base)
    }
    
    convenience init?(string: String, encodingInvalidCharacters: Bool) {
        guard !string.isEmpty else { return nil }
        self.init(string, encodingInvalidCharacters: encodingInvalidCharacters)
    }

    convenience init?(stringOrEmpty: String, relativeTo base: URL?) {
        self.init(stringOrEmpty, relativeTo: base)
    }

    convenience init(fileURLWithPath path: String, isDirectory: Bool, relativeTo base: URL?) {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint, relativeTo: base)
    }
    
    convenience init(fileURLWithPath path: String, relativeTo base: URL?) {
        let directoryHint: URL.DirectoryHint = path.utf8.last == ._slash ? .isDirectory : .checkFileSystem
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint, relativeTo: base)
    }
    
    convenience init(fileURLWithPath path: String, isDirectory: Bool) {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint)
    }
    
    convenience init(fileURLWithPath path: String) {
        let directoryHint: URL.DirectoryHint = path.utf8.last == ._slash ? .isDirectory : .checkFileSystem
        self.init(filePath: path.isEmpty ? "." : path, directoryHint: directoryHint)
    }

    convenience init(filePath path: String, directoryHint: URL.DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        self.init(filePath: path, pathStyle: URL.defaultPathStyle, directoryHint: directoryHint, relativeTo: base)
    }

    convenience init(filePath path: String, pathStyle: URL.PathStyle, directoryHint: URL.DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        var directoryHint = directoryHint
        if directoryHint == .checkFileSystem {
            #if NO_FILESYSTEM
            directoryHint = .inferFromPath
            #else
            // Don't check the file system using a path
            // style that doesn't match the current OS.
            if pathStyle != URL.defaultPathStyle {
                directoryHint = .inferFromPath
            }
            #endif
        }

        @inline(__always)
        func hasDirectorySlash(_ path: String) -> Bool {
            path.utf8.last == ._slash || (pathStyle == .windows && path.utf8.last == ._backslash)
        }

        let isDirectory: Bool? = switch directoryHint {
        case .isDirectory: true
        case .notDirectory: false
        case .checkFileSystem: nil
        case .inferFromPath: hasDirectorySlash(path)
        }

        var (info, base) = _URLInfo.parse(
            filePath: path,
            pathStyle: pathStyle,
            // Strip the trailing slash if we're checking the file system
            isDirectory: isDirectory ?? false,
            relativeTo: base
        )

        if isDirectory != nil || path.isEmpty {
            self.init(info: info, relativeTo: base)
            return
        }

        // Now we must check the file system
        let url = _URL(info: info, relativeTo: base)
        let resourceIsDirectory = url.checkResourceIsDirectory()
        if resourceIsDirectory == false || (resourceIsDirectory == nil && !hasDirectorySlash(path)) {
            self.init(url: url)
            return
        }

        // Append a directory slash
        info.string += "/"
        info.flags.insert(.hasDirectoryPath)
        info.pathRange = info.pathRange.startIndex..<(info.pathRange.endIndex + 1)
        self.init(info: info, relativeTo: base)
    }

    convenience init?(dataRepresentation: Data, relativeTo base: URL?, isAbsolute: Bool) {
        guard !dataRepresentation.isEmpty else { return nil }
        var info: _URLInfo?
        if let string = String(data: dataRepresentation, encoding: .utf8) {
            info = _URLInfo.parse(string: string, encodingInvalidCharacters: true)
        }
        if info == nil, let string = String(data: dataRepresentation, encoding: .isoLatin1) {
            info = _URLInfo.parse(string: string, encodingInvalidCharacters: true)
        }
        guard let info else {
            return nil
        }
        guard base != nil && isAbsolute else {
            self.init(info: info, relativeTo: base)
            return
        }
        let absolute = _URL(info: info, relativeTo: base)._absoluteURL
        self.init(url: absolute)
    }
    
    convenience init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo base: URL?) {
        let (info, base) = _URLInfo.parse(
            fileSystemRepresentation: path,
            isDirectory: isDirectory,
            relativeTo: base
        )
        self.init(info: info, relativeTo: base)
    }

    // MARK: - Strings, Data, and URLs

    var dataRepresentation: Data {
        guard let result = _info.originalString.data(using: .utf8) else {
            fatalError("Could not convert URL.relativeString to data using UTF8 encoding")
        }
        return result
    }

    var relativeString: String {
        _info.string
    }

    var absoluteString: String {
        guard let _baseURL else {
            return relativeString
        }
        guard let base = _baseURL as? _URL ?? _URL(_baseURL.relativeString) else {
            return relativeString
        }
        let relativeInfo = _info
        let baseInfo = base._info
        return relativeInfo.withSpan { relativeSpan in
            return baseInfo.withSpan { baseSpan in
                // We may need to prepend a "/" to a relative path
                let maxLength = baseSpan.count + 1 + relativeSpan.count
                return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength) { absoluteBuffer in
                    let length = resolveURLBuffers(
                        relativeSpan: relativeSpan,
                        relativeHeader: relativeInfo,
                        baseSpan: baseSpan,
                        baseHeader: baseInfo,
                        into: absoluteBuffer,
                        useRFC1808: false
                    )
                    return String(decoding: absoluteBuffer[..<length], as: UTF8.self)
                }
            }
        }
    }

    var baseURL: URL? {
        _baseURL.map(URL.init)
    }

    private var _absoluteURL: _URL {
        guard _baseURL != nil else { return self }
        return _URL(absoluteString) ?? self
    }

    var absoluteURL: URL? {
        guard _baseURL != nil else { return nil }
        return _absoluteURL.url
    }

    // MARK: - Components

    var scheme: String? {
        _info.scheme.map(String.init) ?? _baseURL?.scheme
    }

    var isFileURL: Bool {
        flags.contains(.isFileURL)
    }

    // True for an absolute file URL created via a file path initializer
    private var isCanonicalFileURL: Bool {
        flags.intersection([.implTypeMask, .hasScheme]) == [_URLFlags(type: .file), .hasScheme]
    }

    var hasAuthority: Bool {
        flags.contains(.hasHost)
    }

    var user: String? {
        user(percentEncoded: false)
    }

    func user(percentEncoded: Bool) -> String? {
        guard hasAuthority else {
            return _baseURL?.user(percentEncoded: percentEncoded)
        }
        guard let user = _info.user.map(String.init) else {
            return nil
        }
        return percentEncoded ? user : URLEncoder.percentDecode(string: user)
    }
    
    var password: String? {
        password(percentEncoded: true)
    }

    func password(percentEncoded: Bool) -> String? {
        guard hasAuthority else  {
            return _baseURL?.password(percentEncoded: percentEncoded)
        }
        guard let password = _info.password.map(String.init) else {
            return nil
        }
        return percentEncoded ? password : URLEncoder.percentDecode(string: password)
    }

    var host: String? {
        host(percentEncoded: false)
    }

    func host(percentEncoded: Bool) -> String? {
        guard hasAuthority else {
            return _baseURL?.host(percentEncoded: percentEncoded)
        }

        // According to RFC 3986, a host always exists if there is an authority
        // component, it just might be empty. However, the old implementation
        // of URL.host() returned nil for URLs like "https:///", and apps rely
        // on this behavior, so keep it for bincompat.
        guard flags.contains(.hasOldNetLocation) else {
            return nil
        }

        guard let encodedHost = _info.host.map(String.init) else {
            return nil
        }

        @inline(__always)
        func requestedHost() -> String? {
            let idnaEncoded = (
                flags.contains([.didEncodeHost, .hasSpecialScheme]) &&
                !flags.contains(.isIPLiteral)
            )
            if percentEncoded {
                if !idnaEncoded {
                    return encodedHost
                }
                // Now we need to IDNA-decode, then percent-encode
                guard let decoded = RFC3986Parser.IDNADecodeHost(encodedHost) else {
                    return encodedHost
                }
                // The decoded host does not contain percent-escapes or
                // else the initial IDNA-encoding would have failed.
                return URLEncoder.percentEncode(
                    string: decoded,
                    component: .host,
                    skipAlreadyEncoded: false
                )
            } else if idnaEncoded {
                // Return IDNA-encoded host, which is technically not percent-encoded
                return encodedHost
            } else {
                return URLEncoder.percentDecode(string: encodedHost)
            }
        }

        guard let requestedHost = requestedHost() else {
            return nil
        }

        if flags.contains(.isIPLiteral) {
            // Strip square brackets to be compatible with old URL.host behavior
            let start = requestedHost.utf8.index(after: requestedHost.startIndex)
            let end = requestedHost.utf8.index(before: requestedHost.endIndex)
            return String(requestedHost[start..<end])
        } else {
            return requestedHost
        }
    }

    var port: Int? {
        hasAuthority ? _info.port : _baseURL?.port
    }

    @inline(__always)
    private var pathIsEmpty: Bool {
        _info.pathRange.isEmpty
    }

    @inline(__always)
    private var pathIsRelative: Bool {
        _info.path.utf8.first != UInt8(ascii: "/")
    }

    @inline(__always)
    private static func fileSystemPath(
        for urlPath: borrowing Span<UInt8>,
        isKnownUnencoded: Bool = false,
        stripTrailingSlashes: Bool = true
    ) -> String {
        #if os(Windows)
        windowsFilePath(for: urlPath, isKnownUnencoded: isKnownUnencoded, stripTrailingSlashes: stripTrailingSlashes)
        #else
        posixFilePath(for: urlPath, isKnownUnencoded: isKnownUnencoded, stripTrailingSlashes: stripTrailingSlashes)
        #endif
    }

//    // Note: Doesn't work due to lifetime issues
//    private var pathSpan: Span<UInt8> {
//        @_lifetime(borrow self)
//        borrowing get {
//            let span = _info.pathSpan
//            return _overrideLifetime(span, borrowing: self)
//        }
//    }

    func withPathSpan<R>(_ block: (borrowing Span<UInt8>) -> R) -> R {
        var s = _info.string
        return s.withUTF8 { buffer in
            block(buffer.span.extracting(_info.pathRange))
        }
    }

    @inline(__always)
    private var hasEncodedPath: Bool {
        flags.contains(.hasEncodedPath)
    }

    // Behaves like `var path` but without resolving against the base
    var relativePath: String {
        withPathSpan { pathSpan in
            if isFileURL {
                return Self.fileSystemPath(for: pathSpan, isKnownUnencoded: !hasEncodedPath)
            }
            let path = pathSpan
            return String(unsafeUninitializedCapacity: path.count) { buffer in
                guard var pathLength = URLEncoder.percentDecodeUnchecked(
                    input: path,
                    output: buffer
                ) else {
                    return 0
                }
                // Don't check root length for non-file URLs
                while pathLength > 1 && buffer[pathLength - 1] == ._slash {
                    pathLength -= 1
                }
                return pathLength
            }
        }
    }

    func relativePath(percentEncoded: Bool) -> String {
        let path = String(_info.path)
        return percentEncoded ? path : URLEncoder.percentDecode(string: path) ?? ""
    }

    func absolutePath(percentEncoded: Bool) -> String {
        if _baseURL == nil {
            return relativePath(percentEncoded: percentEncoded)
        }
        return _absoluteURL.relativePath(percentEncoded: percentEncoded)
    }

    // Closure since we may depend on the lifetime of the absolute URL created
    func withAbsolutePathSpan<R>(_ block: (borrowing Span<UInt8>) -> R) -> R {
        if _baseURL == nil {
            return withPathSpan(block)
        }
        return _absoluteURL.withPathSpan(block)
    }

    var path: String {
        if isFileURL {
            return fileSystemPath
        }
        return withAbsolutePathSpan { absolutePath in
            String(unsafeUninitializedCapacity: absolutePath.count) { buffer in
                guard var pathLength = URLEncoder.percentDecodeUnchecked(
                    input: absolutePath,
                    output: buffer
                ) else {
                    return 0
                }
                while pathLength > 1 && buffer[pathLength - 1] == ._slash {
                    pathLength -= 1
                }
                return pathLength
            }
        }
    }

    func path(percentEncoded: Bool) -> String {
        absolutePath(percentEncoded: percentEncoded)
    }

    var query: String? {
        query(percentEncoded: true)
    }

    func query(percentEncoded: Bool) -> String? {
        guard let query = _info.query.map(String.init) else {
            if !hasAuthority && pathIsEmpty {
                return _baseURL?.query(percentEncoded: percentEncoded)
            }
            return nil
        }
        return percentEncoded ? query : URLEncoder.percentDecode(string: query)
    }
    
    var fragment: String? {
        fragment(percentEncoded: true)
    }

    func fragment(percentEncoded: Bool) -> String? {
        guard let fragment = _info.fragment.map(String.init) else {
            return nil
        }
        return percentEncoded ? fragment : URLEncoder.percentDecode(string: fragment)
    }

    // MARK: - File Paths

    private static func posixFilePath(
        for urlPath: borrowing Span<UInt8>,
        isKnownUnencoded: Bool = false,
        stripTrailingSlashes: Bool = true
    ) -> String {
        guard !urlPath.isEmpty else {
            return ""
        }
        return String(unsafeUninitializedCapacity: urlPath.count) { outBuffer in
            var pathLength = if isKnownUnencoded {
                outBuffer.initialize(fromSpan: urlPath)
            } else {
                URLEncoder.percentDecodeUnchecked(
                    input: urlPath,
                    output: outBuffer,
                    excludingASCII: .posixPath // Don't decode "%00" or "%2F"
                ) ?? 0
            }

            if stripTrailingSlashes {
                // Strip trailing slashes up to the root prefix
                let rootLength = rootLength(pathBuffer: UnsafeBufferPointer(outBuffer), length: pathLength)
                while pathLength > rootLength && outBuffer[pathLength - 1] == ._slash {
                    pathLength -= 1
                }
            }
            return pathLength
        }
    }

    private static func windowsFilePath(
        for urlPath: borrowing Span<UInt8>,
        isKnownUnencoded: Bool = false,
        stripTrailingSlashes: Bool = true
    ) -> String {
        guard !urlPath.isEmpty else {
            return ""
        }
        return String(unsafeUninitializedCapacity: urlPath.count) { outBuffer in
            var rootLength = 0
            var inputStart = 0

            // "C:\" is standardized to "/C:/" on initialization.
            // Strip the leading slash to recover the drive letter root.
            if urlPath.count >= 4,
               urlPath[0] == ._slash,
               urlPath[1].isAlpha,
               urlPath[2] == ._colon,
               urlPath[3] == ._slash {
                rootLength = outBuffer[0...2].initialize(fromSpan: urlPath.extracting(1...3))
                inputStart = 4
            }

            var pathLength: Int
            if isKnownUnencoded {
                pathLength = outBuffer[rootLength...].initialize(
                    fromSpan: urlPath.extracting(inputStart...)
                )
            } else {
                // Percent-decode, excluding "%00", "%2F", and "%5C"
                guard let decodedLength = URLEncoder.percentDecodeUnchecked(
                    input: urlPath.extracting(inputStart...),
                    output: .init(rebasing: outBuffer[rootLength...]),
                    excludingASCII: .windowsPath
                ) else {
                    return 0
                }
                pathLength = rootLength + decodedLength
            }

            // Convert forward slashes to backslashes
            for i in 0..<pathLength {
                if outBuffer[i] == ._slash {
                    outBuffer[i] = ._backslash
                }
            }

            // Strip trailing backslashes if requested
            guard stripTrailingSlashes, outBuffer[pathLength - 1] == ._backslash else {
                return pathLength
            }
            if rootLength == 0, outBuffer[0] == ._backslash {
                #if os(Windows)
                // Use PathCchSkipRoot to find where the root ends
                rootLength = String(
                    decoding: outBuffer[..<pathLength], as: UTF8.self
                ).withCString(encodedAs: UTF16.self) { pwszPath -> Int in
                    var pRootEnd: PCWSTR?
                    guard PathCchSkipRoot(pwszPath, &pRootEnd) == S_OK, let pRootEnd else {
                        return pathLength
                    }
                    return pRootEnd - pwszPath
                }
                #else
                // Don't strip any trailing slashes since we
                // might accidentally strip a root backslash.
                return pathLength
                #endif
            }
            while pathLength > rootLength, outBuffer[pathLength - 1] == ._backslash {
                pathLength -= 1
            }
            return pathLength
        }
    }

    internal var fileSystemPath: String {
        fileSystemPath()
    }

    internal func fileSystemPath(style: URL.PathStyle = URL.defaultPathStyle) -> String {
        let isKnownUnencoded = _baseURL == nil && !hasEncodedPath
        return withAbsolutePathSpan { absolutePath in
            switch style {
            case .posix: Self.posixFilePath(for: absolutePath, isKnownUnencoded: isKnownUnencoded)
            case .windows: Self.windowsFilePath(for: absolutePath, isKnownUnencoded: isKnownUnencoded)
            }
        }
    }

    func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        #if !os(Windows)
        if isCanonicalFileURL {
            return try fileSystemPath.withCString { try block($0) }
        }
        #endif
        return try fileSystemPath.withFileSystemRepresentation { try block($0) }
    }
    
    var hasDirectoryPath: Bool {
        if !flags.contains(.hasOldPath), let _baseURL {
            return _baseURL.hasDirectoryPath
        }
        return flags.contains(.hasDirectoryPath)
    }

    var pathComponents: [String] {
        withAbsolutePathSpan { absolutePath in
            absolutePath.mapPathComponents(
                root: { _ in "/" },
                component: { span in
                    String(unsafeUninitializedCapacity: span.count) {
                        URLEncoder.percentDecodeUnchecked(input: span, output: $0) ?? 0
                    }
                }
            )
        }
    }

    var lastPathComponent: String {
        withAbsolutePathSpan { path in
            guard !path.isEmpty else {
                return ""
            }
            // Find the last component before decoding to
            // prevent "%2F" from acting as a delimiter.
            let componentRange = path.urlLastPathComponentRange
            guard !componentRange.isEmpty else {
                return "/"
            }
            let component = path.extracting(componentRange)
            #if os(Windows)
            let mask: PercentDecodingASCIIExclusionMask = isFileURL ? .windowsPath : .none
            #else
            let mask: PercentDecodingASCIIExclusionMask = isFileURL ? .posixPath : .none
            #endif
            return String(unsafeUninitializedCapacity: component.count) { buffer in
                URLEncoder.percentDecodeUnchecked(
                    input: component,
                    output: buffer,
                    excludingASCII: mask
                ) ?? 0
            }
        }
    }

    var pathExtension: String {
        var s = path
        return s.withUTF8 {
            let path = $0.span
            guard !path.isEmpty else {
                return ""
            }
            let componentRange = path.urlLastPathComponentRange
            guard !componentRange.isEmpty else {
                return ""
            }
            let component = path.extracting(componentRange)
            guard let dotIndex = component.pathExtensionDotIndex else {
                return ""
            }
            let ext = component.extracting((dotIndex + 1)...)
            return String(unsafeUninitializedCapacity: ext.count) { $0.initialize(fromSpan: ext) }
        }
    }

    // MARK: - Helpers for Path Manipulation

    @inline(__always)
    private func replacing(
        path: StaticString,
        isDirectory: Bool,
        encodingState: _URLInfo.PathEncodingState = .unknown
    ) -> URL {
        let span = Span(_unsafeStart: path.utf8Start, count: path.utf8CodeUnitCount)
        return replacing(path: span, isDirectory: isDirectory, encodingState: encodingState)
    }

    @inline(__always)
    private func replacing(
        path: borrowing Span<UInt8>,
        encodingState: _URLInfo.PathEncodingState = .unknown
    ) -> URL {
        let info = _info.replacing(path: path, encodingState: encodingState)
        return replacing(info: info).url
    }

    @inline(__always)
    private func replacing(
        path: borrowing Span<UInt8>,
        isDirectory: Bool,
        encodingState: _URLInfo.PathEncodingState = .unknown
    ) -> URL {
        let info = _info.replacing(
            path: path,
            isDirectory: isDirectory,
            encodingState: encodingState
        )
        return replacing(info: info).url
    }

    func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL? {
        let directoryHint: URL.DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        return appending(path: pathComponent, directoryHint: directoryHint)
    }
    
    func appendingPathComponent(_ pathComponent: String) -> URL? {
        appending(path: pathComponent, directoryHint: .checkFileSystem)
    }

    func appending<S>(path: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        appending(path: path, directoryHint: directoryHint, encodingSlashes: false)
    }

    func appending<S>(component: S, directoryHint: URL.DirectoryHint) -> URL? where S : StringProtocol {
        // The old .appending(component:) implementation did not actually percent-encode
        // "/" for file URLs as the documentation suggests. Many apps accidentally use
        // .appending(component: "path/with/slashes") instead of using .appending(path:),
        // so changing this behavior would cause breakage.
        if isFileURL {
            return appending(path: component, directoryHint: directoryHint, encodingSlashes: false)
        }
        return appending(path: component, directoryHint: directoryHint, encodingSlashes: true)
    }

    private static func withEncodedURLPath<R>(
        for path: borrowing Span<UInt8>,
        encodingSlashes: Bool,
        isFileURL: Bool,
        block: (borrowing Span<UInt8>) -> R
    ) -> R {
        @inline(__always)
        func withPercentEncoded(_ input: UnsafeBufferPointer<UInt8>) -> R {
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 3 * input.count) {
                let length = URLEncoder.percentEncodeUnchecked(
                    input: input,
                    output: $0,
                    component: encodingSlashes ? .pathNoSlash : .path,
                    skipAlreadyEncoded: false
                )
                return block($0.span.extracting(first: length))
            }
        }

        #if FOUNDATION_FRAMEWORK
        if isFileURL {
            let maxFSRSize = 3 * path.count
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxFSRSize) { fsrBuffer in
                return path.withUnsafeBufferPointer {
                    guard let length = try? $0._decomposed(.hfsPlus, as: UTF8.self, into: fsrBuffer) else {
                        // Decomposition failed, just use the original buffer
                        return withPercentEncoded($0)
                    }
                    return withPercentEncoded(.init(rebasing: fsrBuffer[..<length]))
                }
            }
        }
        #endif

        #if os(Windows)
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: path.count) { buffer in
            _ = buffer.initialize(fromSpan: path)
            for i in 0..<buffer.count {
                if buffer[i] == ._backslash {
                    buffer[i] = ._slash
                }
            }
            return withPercentEncoded(buffer)
        }
        #else
        return path.withUnsafeBufferPointer { withPercentEncoded($0) }
        #endif
    }

    internal func appending<S: StringProtocol>(path toAppend: S, directoryHint: URL.DirectoryHint, encodingSlashes: Bool) -> URL? {
        // Appending "" to "http://example.com" returns "http://example.com/"
        guard !toAppend.isEmpty || flags.contains(.hasOldPath) else {
            return nil
        }

        var directoryHint = directoryHint
        if directoryHint == .checkFileSystem {
            #if NO_FILESYSTEM
            directoryHint = .inferFromPath
            #else
            if !isFileURL {
                directoryHint = .inferFromPath
            }
            #endif
        }

        var s = String(toAppend)
        return s.withUTF8 {
            let spanToAppend = $0.span

            let isDirectory: Bool? = switch directoryHint {
            case .isDirectory: true
            case .notDirectory: false
            case .checkFileSystem: nil
            case .inferFromPath:
                #if os(Windows)
                spanToAppend.count > 0 && (
                    spanToAppend[spanToAppend.count - 1] == ._backslash ||
                    spanToAppend[spanToAppend.count - 1] == ._slash
                )
                #else
                spanToAppend.count > 0 && spanToAppend[spanToAppend.count - 1] == ._slash
                #endif
            }

            if !encodingSlashes && strictValidate(path: spanToAppend) {
                // If we're not encoding slashes and the appended component is
                // valid, the resulting path keeps the current encoding state.
                return appending(
                    span: spanToAppend,
                    isDirectory: isDirectory,
                    encodingState: hasEncodedPath ? .encoded : .notEncoded
                )
            }

            return Self.withEncodedURLPath(for: spanToAppend, encodingSlashes: encodingSlashes, isFileURL: isFileURL) {
                // If encodingSlashes is false, we know validation failed
                // above, so we must have encoded the appended path.
                return appending(
                    span: $0,
                    isDirectory: isDirectory,
                    encodingState: encodingSlashes ? .unknown : .encoded
                )
            }
        }
    }

    private func appending(span: borrowing Span<UInt8>, isDirectory: Bool?, encodingState: _URLInfo.PathEncodingState) -> URL {
        return withPathSpan { path in
            // Max size occurs for "" with directory: "." + "/" + span + "/"
            let maxLength = 1 + path.count + 1 + span.count + 1
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: maxLength) { buffer in
                @inline(__always)
                func isSeparator(_ byte: UInt8) -> Bool {
                    #if os(Windows)
                    byte == ._backslash || byte == ._slash
                    #else
                    byte == ._slash
                    #endif
                }

                @inline(__always)
                func initialize() -> Int {
                    var writeIndex = 0

                    if !path.isEmpty {
                        writeIndex = buffer.initialize(fromSpan: path)
                        guard !span.isEmpty else {
                            return writeIndex
                        }
                        let twoSlashes = (path.last == ._slash && isSeparator(span[0]))
                        let noSlash = (path.last != ._slash && !isSeparator(span[0]))
                        if noSlash {
                            buffer[writeIndex] = ._slash
                            writeIndex += 1
                        }
                        // Compiler complains if we try to ternary this
                        if twoSlashes {
                            writeIndex = buffer[writeIndex...].initialize(
                                fromSpan: span.extracting(droppingFirst: 1)
                            )
                        } else {
                            writeIndex = buffer[writeIndex...].initialize(
                                fromSpan: span
                            )
                        }
                    } else if hasAuthority {
                        if span.isEmpty || !isSeparator(span[0]) {
                            // Prepend a slash to separate the relative path from
                            // the authority component, e.g. "http://example.com"
                            buffer[writeIndex] = ._slash
                            writeIndex += 1
                        }
                        writeIndex = buffer[writeIndex...].initialize(fromSpan: span)
                    } else if span.isEmpty {
                        // Current path and path to append are both empty
                        return 0
                    } else if isSeparator(span[0]) || !_info.hasScheme {
                        // Treat the empty path as "."
                        buffer[writeIndex] = ._dot
                        writeIndex += 1
                        if !isSeparator(span[0]) {
                            buffer[writeIndex] = ._slash
                            writeIndex += 1
                        }
                        writeIndex = buffer[writeIndex...].initialize(fromSpan: span)
                    } else {
                        // Scheme only, append directly to the empty path, e.g.
                        // URL("scheme:").appending("path") == "scheme:path"
                        writeIndex = buffer.initialize(fromSpan: span)
                    }

                    #if os(Windows)
                    // Only replace backslashes in the appended portion
                    for i in path.count..<writeIndex where buffer[i] == ._backslash {
                        buffer[i] = ._slash
                    }
                    #endif

                    return writeIndex
                }

                var pathLength = initialize()
                if isDirectory != true {
                    let rootLength = isFileURL ? rootLength(pathBuffer: .init(buffer), length: pathLength) : 1
                    while pathLength > rootLength && buffer[pathLength - 1] == ._slash {
                        pathLength -= 1
                    }
                } else if pathLength > 0 && buffer[pathLength - 1] != ._slash {
                    buffer[pathLength] = ._slash
                    pathLength += 1
                }

                let newInfo = _info.replacing(
                    path: buffer.span.extracting(first: pathLength),
                    encodingState: encodingState
                )
                let url = replacing(info: newInfo)
                if isDirectory != nil {
                    return url.url
                }

                let resourceIsDirectory = url.checkResourceIsDirectory()
                if resourceIsDirectory == false || (resourceIsDirectory == nil && (span.isEmpty || !isSeparator(span.last!))) {
                    return url.url
                }

                // Checked the file system and path points to a directory, or
                // it's non-existent and we're honoring the trailing slash.
                buffer[pathLength] = ._slash
                pathLength += 1
                return replacing(
                    path: buffer.span.extracting(first: pathLength),
                    isDirectory: true,
                    encodingState: encodingState
                )
            }
        }
    }

#if !NO_FILESYSTEM

    private func checkResourceIsDirectory() -> Bool? {
        guard isFileURL else {
            return nil
        }
        #if os(Windows)
        let path = fileSystemPath
        guard !path.isEmpty else { return nil }
        return (try? path.withNTPathRepresentation { pwszPath in
            // If path points to a symlink (reparse point), get a handle to
            // the symlink itself using FILE_FLAG_OPEN_REPARSE_POINT.
            let handle = CreateFileW(pwszPath, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nil)
            guard handle != INVALID_HANDLE_VALUE else { return nil }
            defer { CloseHandle(handle) }
            var info: BY_HANDLE_FILE_INFORMATION = BY_HANDLE_FILE_INFORMATION()
            guard GetFileInformationByHandle(handle, &info) else { return nil }
            if (info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) == FILE_ATTRIBUTE_REPARSE_POINT { return false }
            return (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == FILE_ATTRIBUTE_DIRECTORY
        }) ?? nil
        #else
        // FileManager uses stat() to check if the file exists.
        // URL historically won't follow a symlink at the end
        // of the path, so use lstat() here instead.
        return withUnsafeFileSystemRepresentation { fsRep in
            guard let fsRep else { return nil }
            var fileInfo = stat()
            guard lstat(fsRep, &fileInfo) == 0 else { return nil }
            return (mode_t(fileInfo.st_mode) & S_IFMT) == S_IFDIR
        }
        #endif
    }

#endif // !NO_FILESYSTEM

    func deletingLastPathComponent() -> URL? {
        @inline(__always)
        func result(path: borrowing Span<UInt8>) -> URL? {
            // We'll always generate a path ending in "/", and if the
            // path is currently unencoded, it will remain unencoded.
            // If it was encoded in the past, we can't be sure if we
            // just deleted the only percent-encoded component.
            assert(path.count > 0 && path[path.count - 1] == ._slash)
            return replacing(
                path: path,
                isDirectory: true,
                encodingState: hasEncodedPath ? .unknown : .notEncoded
            )
        }

        @inline(__always)
        func result(path: StaticString) -> URL? {
            return replacing(path: path, isDirectory: true, encodingState: .notEncoded)
        }

        guard !pathIsEmpty else {
            guard flags.isDisjoint(with: [.hasScheme, .hasHost]) else {
                // Don't delete the component, return the original URL
                return nil
            }
            return result(path: "../")
        }

        return withPathSpan { path in
            let componentRange = path.urlLastPathComponentRange

            if componentRange.count > 2 {
                // Not a special case like ".." or "." or "/"
                guard componentRange.startIndex > 0 else {
                    if !_info.hasScheme {
                        // Replace a single component like "path" with "./"
                        return result(path: "./")
                    }
                    // Don't append dot/dot dot to a lone "scheme:"
                    return replacing(path: "", isDirectory: false, encodingState: .notEncoded)
                }
                return result(path: path.extracting(first: componentRange.startIndex))
            }

            if componentRange.isEmpty {
                if path.count == 1 {
                    // Path is a root "/"
                    #if FOUNDATION_FRAMEWORK
                    if URL.compatibility1 {
                        // Compatibility path for apps that loop on:
                        // while !url.path.isEmpty {
                        //     url = url.deletingPathComponent().standardized
                        // }
                        //
                        // This used to work due to a combination of bugs where:
                        // URL("/").deletingLastPathComponent == URL("/../")
                        // URL("/../").standardized == URL("")
                        return result(path: "/../")
                    }
                    #endif
                    return nil // Return the original URL with "/"
                } else {
                    // Path is all separators, so compress e.g. "///" to "/"
                    return result(path: "/")
                }
            }

            let component = path.extracting(componentRange)

            if component.count == 2, component[0] == ._dot, component[1] == ._dot {
                // Append "/../" after the ".."
                let newPathLength = componentRange.endIndex + 4
                return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: newPathLength) { buffer in
                    var writeIndex = buffer.initialize(
                        fromSpan: path.extracting(..<componentRange.endIndex)
                    )
                    writeIndex = buffer[writeIndex...].initialize(
                        fromContentsOf: [._slash, ._dot, ._dot, ._slash]
                    )
                    assert(writeIndex == buffer.count)
                    return result(path: buffer.span)
                }
            }

            if component.count == 1, component[0] == ._dot {
                // Replace "." with "../" by appending "./"
                let newPathLength = componentRange.endIndex + 2
                return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: newPathLength) { buffer in
                    var writeIndex = buffer.initialize(
                        fromSpan: path.extracting(..<componentRange.endIndex)
                    )
                    writeIndex = buffer[writeIndex...].initialize(
                        fromContentsOf: [._dot, ._slash]
                    )
                    assert(writeIndex == buffer.count)
                    return result(path: buffer.span)
                }
            }

            // Non-dot component of size 1 or 2
            guard componentRange.startIndex > 0 else {
                if !_info.hasScheme {
                    // Replace a single component like "a" or "ab/ with "./"
                    return result(path: "./")
                }
                // Don't append dot/dot dot to a lone "scheme:"
                return replacing(path: "", isDirectory: false, encodingState: .notEncoded)
            }
            return result(path: path.extracting(first: componentRange.startIndex))
        }
    }

    func appendingPathExtension(_ pathExtension: String) -> URL? {
        guard !pathExtension.isEmpty && !pathIsEmpty else {
            return nil
        }

        return withPathSpan { path in
            let componentRange = path.urlLastPathComponentRange
            guard !componentRange.isEmpty else {
                // Don't append an extension to "/" or "///"
                return nil
            }

            var s = pathExtension
            return s.withUTF8 {
                let pathExtension = $0.span
                guard pathExtension.isValidPathExtension else {
                    return nil
                }

                let isDirectory = (path.last == ._slash)

                @inline(__always)
                func append(_ ext: borrowing Span<UInt8>, encodingState: _URLInfo.PathEncodingState) -> URL {
                    // Append ".\(pathExtension)" with a potential trailing slash
                    let newPathLength = componentRange.endIndex + 1 + ext.count + 1
                    return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: newPathLength) { buffer in
                        var writeIndex = buffer.initialize(
                            fromSpan: path.extracting(first: componentRange.endIndex)
                        )
                        buffer[writeIndex] = ._dot
                        writeIndex += 1
                        writeIndex = buffer[writeIndex...].initialize(
                            fromSpan: ext
                        )
                        if isDirectory {
                            buffer[writeIndex] = ._slash
                            writeIndex += 1
                        }
                        return replacing(
                            path: buffer.span.extracting(first: writeIndex),
                            isDirectory: isDirectory,
                            encodingState: encodingState
                        )
                    }
                }

                // Fast path for the common case that doesn't require encoding
                if strictValidate(path: pathExtension) {
                    return append(
                        pathExtension,
                        encodingState: hasEncodedPath ? .encoded : .notEncoded
                    )
                }

                return Self.withEncodedURLPath(for: pathExtension, encodingSlashes: false, isFileURL: isFileURL) { encoded in
                    return append(encoded, encodingState: .encoded)
                }
            }
        }
    }

    func deletingPathExtension() -> URL? {
        guard !pathIsEmpty else {
            return nil
        }
        return withPathSpan { path in
            guard let dotIndex = path.pathExtensionDotIndex else {
                return nil
            }
            let isDirectory = (path.last == ._slash)
            let newPathLength = dotIndex + (isDirectory ? 1 : 0)
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: newPathLength) { buffer in
                var writeIndex = buffer.initialize(
                    fromSpan: path.extracting(first: dotIndex)
                )
                if isDirectory {
                    buffer[writeIndex] = ._slash
                    writeIndex += 1
                }
                return replacing(
                    path: buffer.span.extracting(first: writeIndex),
                    isDirectory: isDirectory,
                    encodingState: hasEncodedPath ? .unknown : .notEncoded
                )
            }
        }
    }

    var standardized: URL? {
        guard flags.contains(.isDecomposable) else {
            return nil
        }
        return withPathSpan { path in
            #if FOUNDATION_FRAMEWORK
            // Compatibility path for apps that loop on:
            // while !url.path.isEmpty {
            //     url = url.deletingPathComponent().standardized
            // }
            //
            // This used to work due to a combination of bugs where:
            // URL("/").deletingLastPathComponent == URL("/../")
            // URL("/../").standardized == URL("")
            if URL.compatibility1, path.count == 4, path.starts(with: "/../") {
                return replacing(path: Span())
            }
            #endif
            guard !path.isEmpty else {
                if flags.contains([.hasScheme, .hasHost]) && !flags.contains(.hasOldNetLocation) {
                    // Standardize "scheme://" to "scheme:///"
                    return replacing(path: "/", isDirectory: true, encodingState: .notEncoded)
                }
                return nil
            }
            // TODO: Standardize "scheme:/path" to "scheme:///path"
            return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: path.count) { buffer in
                _ = buffer.initialize(fromSpan: path)
                let pathLength = resolveDotSegmentsInPlace(buffer: buffer, useRFC1808: true)
                let span = buffer.span.extracting(first: pathLength)
                return replacing(
                    path: span,
                    isDirectory: span.last == ._slash,
                    encodingState: hasEncodedPath ? .unknown : .notEncoded
                )
            }
        }
    }

#if !NO_FILESYSTEM
    var standardizedFileURL: URL? {
        guard isFileURL, !fileSystemPath.isEmpty else { return nil }
        return URL(filePath: fileSystemPath.standardizingPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }

    func resolvingSymlinksInPath() -> URL? {
        guard isFileURL, !fileSystemPath.isEmpty else { return nil }
        return URL(filePath: fileSystemPath.resolvingSymlinksInPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }
#endif

    private var isDataURL: Bool {
        guard var scheme, scheme.utf8.count == 4 else { return false }
        return scheme.withUTF8 {
            ($0[0] | 0x20) == UInt8(ascii: "d") &&
            ($0[1] | 0x20) == UInt8(ascii: "a") &&
            ($0[2] | 0x20) == UInt8(ascii: "t") &&
            ($0[3] | 0x20) == UInt8(ascii: "a")
        }
    }

    var description: String {
        var urlString = relativeString
        if isDataURL && urlString.utf8.count > 128 {
            let prefix = urlString.utf8.prefix(120)
            let suffix = urlString.utf8.suffix(8)
            urlString = "\(prefix) ... \(suffix)"
        }
        if let _baseURL {
            return "\(urlString) -- \(_baseURL.description)"
        }
        return urlString
    }

    var debugDescription: String {
        return description
    }

#if FOUNDATION_FRAMEWORK

    func bridgeToNSURL() -> NSURL {
        return _nsurl
    }

    private func isFileReferenceURL() -> Bool {
        #if NO_FILESYSTEM
        return false
        #else
        return flags.contains(.isFileReferenceURL)
        #endif
    }

    internal func convertingFileReference() -> any _URLProtocol & AnyObject {
        #if NO_FILESYSTEM
        return self
        #else
        guard isFileReferenceURL() else { return self }
        guard let url = _nsurl.filePathURL else {
            return _URL(string: "com-apple-unresolvable-file-reference-url:")!
        }
        return url._url
        #endif
    }

#else

    internal func convertingFileReference() -> _URL {
        return self
    }

#endif // FOUNDATION_FRAMEWORK

    static func == (lhs: _URL, rhs: _URL) -> Bool {
        return lhs.relativeString == rhs.relativeString && lhs.baseURL == rhs.baseURL
    }

    func hash(into hasher: inout Hasher) {
        // Historically, the CF/NSURL hash only includes the relative string
        hasher.combine(relativeString)
    }
}

#if FOUNDATION_FRAMEWORK
internal import CoreFoundation_Private.CFURL

/// This conformance is only needed in `FOUNDATION_FRAMEWORK`,
/// where `URL` can be implemented by a few different classes.
extension _URL: _URLProtocol {}

extension _URL {
    private func _swiftCFURL() -> CFURL {
        let string = _info.string
        if isCanonicalFileURL {
            return _CFURLCreateWithCanonicalFileURLString(string as CFString, flags.rawValue)
        }
        var flags = flags
        flags.remove(.implTypeMask)
        if string.utf8.count <= __CFSmallURLImpl.maxStringLength {
            flags.insert(__CFURLFlags(type: .small))
            var impl = __CFSmallURLImpl()
            fillCFURLImpl(&impl)
            impl._header._flags = flags
            impl._header._string = Unmanaged.passRetained(string as CFString)
            if let base = baseURL as CFURL? {
                impl._header._base = Unmanaged.passRetained(base)
            }
            return withUnsafePointer(to: impl) { smallImpl in
                return _CFURLCreateWithSmallImpl(smallImpl)
            }
        } else {
            flags.insert(__CFURLFlags(type: .big))
            var impl = __CFBigURLImpl()
            fillCFURLImpl(&impl)
            impl._header._flags = flags
            impl._header._string = Unmanaged.passRetained(string as CFString)
            if let base = baseURL as CFURL? {
                impl._header._base = Unmanaged.passRetained(base)
            }
            return withUnsafePointer(to: impl) { bigImpl in
                return _CFURLCreateWithBigImpl(bigImpl)
            }
        }
    }

    @inline(__always)
    private func fillCFURLImpl<Impl: _URLParseable>(_ impl: inout Impl) {
        impl.schemeRange = _info.schemeRange
        impl.hostRange = _info.hostRange
        impl.portRange = _info.portRange
        impl.pathRange = _info.pathRange
        impl.queryRange = _info.queryRange
        impl.fragmentRange = _info.fragmentRange
        impl.userRange = _info.userRange
        impl.passwordRange = _info.passwordRange
    }
}
#endif
