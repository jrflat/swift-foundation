//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !NO_FILESYSTEM
#if canImport(Darwin)
import Darwin

// This should eventually be refactored to use getattrlist
internal final class _URLResourceValuesProvider: _URLResourceValuesProviderProtocol {
    private let fsPath: String
    init(url: URL) {
        self.fsPath = url.fileSystemPath
    }

    private var _statInfo: stat?
    private func statInfo() throws -> stat {
        if let _statInfo {
            return _statInfo
        }
        var s = stat()
        try fsPath.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, fsPath)
            }
            guard lstat(fsRep, &s) == 0 else {
                throw CocoaError.errorWithFilePath(fsPath, errno: errno, reading: true)
            }
        }
        _statInfo = s
        return s
    }

    private func fileFlagsContain(_ flag: Int32) throws -> Bool {
        try statInfo().st_flags & UInt32(flag) != 0
    }

    private var _statfsInfo: statfs?
    private func statfsInfo() throws -> statfs {
        if let _statfsInfo {
            return _statfsInfo
        }
        var s = statfs()
        try fsPath.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, fsPath)
            }
            guard statfs(fsRep, &s) == 0 else {
                throw CocoaError.errorWithFilePath(fsPath, errno: errno, reading: true)
            }
        }
        _statfsInfo = s
        return s
    }

    private func volumeFlagsContain(_ flag: Int32) throws -> Bool {
        try statfsInfo().f_flags & UInt32(flag) != 0
    }

    private var _mountedOnName: String?
    private func mountedOnName() throws -> String {
        if let _mountedOnName {
            return _mountedOnName
        }
        return try withUnsafeBytes(of: statfsInfo().f_mntonname) { nameBuffer in
            String(cString: nameBuffer.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
    }

    private var _quotaInfo: dqblk?
    private func quotaInfo() throws -> dqblk? {
        if let _quotaInfo {
            return _quotaInfo
        }
        return try FileManager._withQuotaInfo(statfsInfo()) { quotaInfo in
            _quotaInfo = quotaInfo
            return quotaInfo
        }
    }

    func isDirectory() throws -> Bool? {
        try fileResourceType() == .directory
    }

    func name() throws -> String? {
        fsPath.lastPathComponent
    }

    func isHidden() throws -> Bool? {
        try fileFlagsContain(UF_HIDDEN)
    }

    func isUserImmutable() throws -> Bool? {
        try fileFlagsContain(UF_IMMUTABLE)
    }

    func isSystemImmutable() throws -> Bool? {
        try fileFlagsContain(SF_IMMUTABLE)
    }

    func linkCount() throws -> Int? {
        try Int(statInfo().st_nlink)
    }

    func addedToDirectoryDate() throws -> Date? {
        nil
    }

    func fileSize() throws -> Int? {
        try Int(statInfo().st_size)
    }

    func isRegularFile() throws -> Bool? {
        try fileResourceType() == .regular
    }

    func isSymbolicLink() throws -> Bool? {
        try fileResourceType() == .symbolicLink
    }

    func isAliasFile() throws -> Bool? {
        // Should also account for Finder alias files
        return try fileResourceType() == .symbolicLink
    }

    func isVolume() throws -> Bool? {
        if fsPath == "/" {
            return true
        }
        return try mountedOnName() == fsPath
    }

    func fileAllocatedSize() throws -> Int? {
        try Int(statInfo().st_blocks) * 512 // 512B blocks, see man lstat(2)
    }

    func contentModificationDate() throws -> Date? {
        let seconds = try TimeInterval(statInfo().st_mtimespec.tv_sec)
        let nanoSeconds = try TimeInterval(statInfo().st_mtimespec.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func attributeModificationDate() throws -> Date? {
        let seconds = try TimeInterval(statInfo().st_ctimespec.tv_sec)
        let nanoSeconds = try TimeInterval(statInfo().st_ctimespec.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func creationDate() throws -> Date? {
        let seconds = try TimeInterval(statInfo().st_birthtimespec.tv_sec)
        let nanoSeconds = try TimeInterval(statInfo().st_birthtimespec.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func hasHiddenExtension() throws -> Bool? {
        nil
    }

    func isReadable() throws -> Bool? {
        FileManager.default.isReadableFile(atPath: fsPath)
    }

    func isWritable() throws -> Bool? {
        FileManager.default.isWritableFile(atPath: fsPath)
    }

    func isExecutable() throws -> Bool? {
        FileManager.default.isExecutableFile(atPath: fsPath)
    }

    func labelNumber() throws -> Int? {
        nil
    }

    func contentAccessDate() throws -> Date? {
        let seconds = TimeInterval(try statInfo().st_atimespec.tv_sec)
        let nanoSeconds = TimeInterval(try statInfo().st_atimespec.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func totalFileSize() throws -> Int? {
        // This should, but does not, account for inode size
        try fileSize()
    }

    func totalFileAllocatedSize() throws -> Int? {
        // This should, but does not, account for inode size
        try fileAllocatedSize()
    }

    func fileResourceIdentifier() throws -> Data? {
        guard let fileID = try fileIdentifier(),
              let volumeID = try volumeIdentifier() else {
            return nil
        }
        var resourceID = fileID
        resourceID.append(volumeID)
        return resourceID
    }

    func generationIdentifier() throws -> Data? {
        let genID = try statInfo().st_gen
        return withUnsafeBytes(of: genID) { Data($0) }
    }

    func documentIdentifier() throws -> Int? {
        nil
    }

    func fileResourceType() throws -> URLFileResourceType? {
        switch try statInfo().st_mode & S_IFMT {
        case S_IFCHR: .characterSpecial
        case S_IFDIR: .directory
        case S_IFBLK: .blockSpecial
        case S_IFREG: .regular
        case S_IFLNK: .symbolicLink
        case S_IFSOCK: .socket
        default: .unknown
        }
    }

    func preferredIOBlockSize() throws -> Int? {
        try Int(statInfo().st_blksize)
    }

    func isMountTrigger() throws -> Bool? {
        nil
    }

    func canonicalPath() throws -> String? {
        fsPath.standardizingPath
    }

    func fileIdentifier() throws -> Data? {
        return try withUnsafeBytes(of: UInt64(statInfo().st_ino)) { Data($0) }
    }

    func mayShareFileContent() throws -> Bool? {
        nil
    }

    func mayHaveExtendedAttributes() throws -> Bool? {
        try !volumeFlagsContain(MNT_NOUSERXATTR)
    }

    func isPurgeable() throws -> Bool? {
        nil
    }

    func isSparse() throws -> Bool? {
        guard let fileSize = try fileSize(),
              let fileAllocatedSize = try fileAllocatedSize() else {
            return nil
        }
        return fileSize > fileAllocatedSize
    }

    func directoryEntryCount() throws -> Int? {
        guard try isDirectory() ?? false else {
            return nil
        }
        return try FileManager.default.contentsOfDirectory(atPath: fsPath).count
    }

    func volumeURL() throws -> URL? {
        if fsPath == "/" {
            return URL(filePath: "/", directoryHint: .isDirectory)
        }
        return try URL(filePath: mountedOnName(), directoryHint: .isDirectory)
    }

    func parentDirectoryURL() throws -> URL? {
        let parentDirectoryPath = fsPath.standardizingPath.deletingLastPathComponent()
        return URL(filePath: parentDirectoryPath, directoryHint: .isDirectory)
    }

    func isExcludedFromBackup() throws -> Bool? {
        nil
    }

    func path() throws -> String? {
        fsPath
    }

    func volumeName() throws -> String? {
        try mountedOnName().lastPathComponent
    }

    func volumeLocalizedFormatDescription() throws -> String? {
        nil
    }

    func volumeURLForRemounting() throws -> URL? {
        nil
    }

    func volumeIsLocal() throws -> Bool? {
        try volumeFlagsContain(MNT_LOCAL)
    }

    func volumeIsAutomounted() throws -> Bool? {
        try volumeFlagsContain(MNT_AUTOMOUNTED)
    }

    func volumeIsBrowsable() throws -> Bool? {
        try !volumeFlagsContain(MNT_DONTBROWSE)
    }

    func volumeIsReadOnly() throws -> Bool? {
        try volumeFlagsContain(MNT_RDONLY)
    }

    func volumeIsEjectable() throws -> Bool? {
        try volumeFlagsContain(MNT_REMOVABLE)
    }

    func volumeIsRootFileSystem() throws -> Bool? {
        try volumeFlagsContain(MNT_ROOTFS)
    }

    func volumeSupportsCompression() throws -> Bool? {
        nil
    }

    func volumeSupportsPersistentIDs() throws -> Bool? {
        nil
    }

    func volumeSupportsSymbolicLinks() throws -> Bool? {
        true
    }

    func volumeSupportsJournaling() throws -> Bool? {
        try volumeFlagsContain(MNT_JOURNALED)
    }

    func volumeSupportsRenaming() throws -> Bool? {
        true
    }

    func volumeSupportsCaseSensitiveNames() throws -> Bool? {
        nil
    }

    func volumeSupportsCasePreservedNames() throws -> Bool? {
        nil
    }

    func volumeSupportsAdvisoryFileLocking() throws -> Bool? {
        nil
    }

    func volumeSupportsRootDirectoryDates() throws -> Bool? {
        true
    }

    // (Volume supports ACLs)
    func volumeSupportsExtendedSecurity() throws -> Bool? {
        true
    }

    func volumeSupportsHardLinks() throws -> Bool? {
        true
    }

    func volumeIsJournaling() throws -> Bool? {
        nil
    }

    func volumeSupportsSparseFiles() throws -> Bool? {
        nil
    }

    func volumeSupportsZeroRuns() throws -> Bool? {
        nil
    }

    func volumeSupportsVolumeSizes() throws -> Bool? {
        true
    }

    func volumeSupportsFileCloning() throws -> Bool? {
        nil
    }

    func volumeSupportsSwapRenaming() throws -> Bool? {
        nil
    }

    func volumeSupportsExclusiveRenaming() throws -> Bool? {
        nil
    }

    func volumeSupportsImmutableFiles() throws -> Bool? {
        nil
    }

    // POSIX access permissions
    func volumeSupportsAccessPermissions() throws -> Bool? {
        true
    }

    func volumeIsInternal() throws -> Bool? {
        nil
    }

    func volumeMaximumFileSize() throws -> Int? {
        nil
    }

    func volumeCreationDate() throws -> Date? {
        guard let volumeURL = try volumeURL() else {
            return nil
        }
        return try _URLResourceValuesProvider(url: volumeURL).creationDate()
    }

    func volumeUUIDString() throws -> String? {
        nil
    }

    func volumeIdentifier() throws -> Data? {
        let deviceID = try UInt32(statInfo().st_dev)
        let volumeID: (UInt32, UInt32) = if deviceID != 0 {
            (deviceID, 0)
        } else {
            try (UInt32(statfsInfo().f_fsid.val.0), UInt32(statfsInfo().f_fsid.val.1))
        }
        return withUnsafeBytes(of: volumeID) { Data($0) }
    }

    private func blockSize() throws -> Int {
        return try Int(statfsInfo().f_bsize)
    }

    func volumeTotalCapacity() throws -> Int? {
        guard let quotaInfo = try quotaInfo(),
              quotaInfo.dqb_bhardlimit > 0 else {
            return try volumeTotalCapacityNoQuota()
        }
        return try min(Int(quotaInfo.dqb_bhardlimit), volumeTotalCapacityNoQuota())
    }

    private func volumeTotalCapacityNoQuota() throws -> Int {
        try Int(statfsInfo().f_blocks) * blockSize()
    }

    func volumeAvailableCapacity() throws -> Int? {
        guard let quotaInfo = try quotaInfo(),
              quotaInfo.dqb_bhardlimit > 0 else {
            return try volumeAvailableCapacityNoQuota()
        }
        return try min(Int(quotaInfo.dqb_bhardlimit - quotaInfo.dqb_curbytes), volumeAvailableCapacityNoQuota())
    }

    private func volumeAvailableCapacityNoQuota() throws -> Int {
        try Int(statfsInfo().f_bavail) * blockSize()
    }

    func volumeTypeName() throws -> String? {
        return try withUnsafeBytes(of: statfsInfo().f_fstypename) { nameBuffer in
            String(cString: nameBuffer.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
    }

    func volumeSubtype() throws -> Int? {
        try Int(statfsInfo().f_fssubtype)
    }

    func volumeMountFromLocation() throws -> String? {
        return try withUnsafeBytes(of: statfsInfo().f_mntfromname) { nameBuffer in
            String(cString: nameBuffer.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
    }

    func isPackage() throws -> Bool? {
        if try isDirectory() ?? false, !fsPath.pathExtension.isEmpty {
            return true
        }
        return nil
    }

    func isApplication() throws -> Bool? {
        guard let isDirectory = try isDirectory(), isDirectory else {
            return false
        }
        return fsPath.pathExtension == "app"
    }

    func localizedName() throws -> String? {
        nil
    }

    func localizedLabel() throws -> String? {
        nil
    }

    func volumeLocalizedName() throws -> String? {
        nil
    }

    func write(_ values: [URLResourceKey : Any]) throws -> [URLResourceKey : any Sendable] {
        // Keys we don't yet support:
        // .hasHiddenExtensionKey
        // .labelNumberKey
        // .fileSecurityKey
        // .isExcludedFromBackupKey
        // .isPackageKey
        // .quarantinePropertiesKey
        // .volumeNameKey

        // Keys we do support:
        // .isSystemImmutableKey
        // .isUserImmutableKey
        // .isHiddenKey
        // .creationDateKey
        // .contentAccessDateKey
        // .contentModificationDateKey
        // .nameKey

        // Return a dictionary of verified-Sendable values that were written
        var writtenValues = [URLResourceKey: Sendable]()

        try fsPath.withFileSystemRepresentation { fsRep in
            var unsuccessfulKeys = Set(values.keys)

            func finalError(_ error: CocoaError) -> CocoaError {
                let unsetValuesKey = URLResourceKey.keysOfUnsetValuesKey.rawValue
                var userInfo = error.userInfo
                userInfo[unsetValuesKey] = Array(unsuccessfulKeys)
                return CocoaError(error.code, userInfo: userInfo)
            }

            guard let fsRep else {
                throw finalError(CocoaError.errorWithFilePath(.fileReadUnknown, fsPath))
            }

            // Flags set via chflags
            var systemImmutable = values[.isSystemImmutableKey] as? Bool
            writtenValues[.isSystemImmutableKey] = systemImmutable

            var userImmutable = values[.isUserImmutableKey] as? Bool
            writtenValues[.isUserImmutableKey] = userImmutable

            var isHidden = values[.isHiddenKey] as? Bool
            writtenValues[.isHiddenKey] = isHidden

            var flags = try statInfo().st_flags

            let currentSystemImmutable = (flags & UInt32(SF_IMMUTABLE) != 0)
            if systemImmutable == currentSystemImmutable {
                unsuccessfulKeys.remove(.isSystemImmutableKey)
                systemImmutable = nil
            }
            let currentUserImmutable = (flags & UInt32(UF_IMMUTABLE) != 0)
            if userImmutable == currentUserImmutable {
                unsuccessfulKeys.remove(.isUserImmutableKey)
                userImmutable = nil
            }
            let currentIsHidden = (flags & UInt32(UF_HIDDEN) != 0)
            if isHidden == currentIsHidden {
                unsuccessfulKeys.remove(.isHiddenKey)
                isHidden = nil
            }
            // Any non-nil flags now require a bit flip, so we can XOR

            var pendingFlagKeys = Set<URLResourceKey>()

            // First, unset any immutable flags requested
            if systemImmutable != nil && currentSystemImmutable {
                flags ^= UInt32(SF_IMMUTABLE)
                systemImmutable = nil
                pendingFlagKeys.insert(.isSystemImmutableKey)
            }
            if userImmutable != nil && currentUserImmutable {
                flags ^= UInt32(UF_IMMUTABLE)
                userImmutable = nil
                pendingFlagKeys.insert(.isUserImmutableKey)
            }
            if !pendingFlagKeys.isEmpty, isHidden != nil {
                // If we're already setting flags, set UF_HIDDEN now, too
                flags ^= UInt32(UF_HIDDEN)
                isHidden = nil
                pendingFlagKeys.insert(.isHiddenKey)
            }

            if !pendingFlagKeys.isEmpty {
                guard chflags(fsRep, flags) == 0 else {
                    throw finalError(CocoaError.errorWithFilePath(fsPath, errno: errno, reading: false))
                }
                unsuccessfulKeys.subtract(pendingFlagKeys)
                pendingFlagKeys = []
            }

            // Creation dates are only available on Darwin
            let creationDate = values[.creationDateKey] as? Date
            if let creationDate {
                writtenValues[.creationDateKey] = creationDate
                var ts = timespec()
                let (isecs, fsecs) = modf(creationDate.timeIntervalSince1970)
                guard let tv_sec = time_t(exactly: isecs),
                      let tv_nsec = suseconds_t(exactly: round(fsecs * 1_000_000_000.0)) else {
                    throw finalError(CocoaError.errorWithFilePath(.fileWriteUnknown, fsPath))
                }
                ts.tv_sec = tv_sec
                ts.tv_nsec = Int(tv_nsec)

                var attrList = attrlist()
                attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
                attrList.commonattr = attrgroup_t(ATTR_CMN_CRTIME)
                var attributesBuffer = ts
                let result = withUnsafeMutableBytes(of: &attributesBuffer) { buffer in
                    setattrlist(fsRep, &attrList, buffer.baseAddress!, buffer.count, .init(FSOPT_NOFOLLOW))
                }
                guard result == 0 else {
                    throw finalError(CocoaError.errorWithFilePath(.fileWriteUnknown, fsPath))
                }
                unsuccessfulKeys.remove(.creationDateKey)
            }

            func updateAccessAndModificationTimes() throws {
                let accessDate = values[.contentAccessDateKey] as? Date
                let modificationDate = values[.contentModificationDateKey] as? Date
                guard accessDate != nil || modificationDate != nil else {
                    return
                }
                var timevals = (timeval(), timeval())

                if let accessDate {
                    writtenValues[.contentAccessDateKey] = accessDate
                    let (isecs, fsecs) = modf(accessDate.timeIntervalSince1970)
                    guard let tv_sec = time_t(exactly: isecs),
                          let tv_usec = suseconds_t(exactly: round(fsecs * 1_000_000.0)) else {
                        throw finalError(CocoaError.errorWithFilePath(.fileWriteUnknown, fsPath))
                    }
                    timevals.0.tv_sec = tv_sec
                    timevals.0.tv_usec = tv_usec
                }

                if let modificationDate {
                    writtenValues[.contentModificationDateKey] = modificationDate
                    let (isecs, fsecs) = modf(modificationDate.timeIntervalSince1970)
                    guard let tv_sec = time_t(exactly: isecs),
                          let tv_usec = suseconds_t(exactly: round(fsecs * 1_000_000.0)) else {
                        throw finalError(CocoaError.errorWithFilePath(.fileWriteUnknown, fsPath))
                    }
                    timevals.1.tv_sec = tv_sec
                    timevals.1.tv_usec = tv_usec
                }

                try withUnsafePointer(to: timevals) {
                    try $0.withMemoryRebound(to: timeval.self, capacity: 2) {
                        guard utimes(fsRep, $0) == 0 else {
                            throw CocoaError.errorWithFilePath(fsPath, errno: errno, reading: false)
                        }
                    }
                }
                unsuccessfulKeys.remove(.contentAccessDateKey)
                unsuccessfulKeys.remove(.contentModificationDateKey)
            }

            try updateAccessAndModificationTimes()

            // Finally, set any immutable flags requested
            if systemImmutable != nil {
                flags ^= UInt32(SF_IMMUTABLE)
                pendingFlagKeys.insert(.isSystemImmutableKey)
            }
            if userImmutable != nil {
                flags ^= UInt32(UF_IMMUTABLE)
                pendingFlagKeys.insert(.isUserImmutableKey)
            }
            if !pendingFlagKeys.isEmpty {
                guard chflags(fsRep, flags) == 0 else {
                    throw finalError(CocoaError.errorWithFilePath(fsPath, errno: errno, reading: false))
                }
                unsuccessfulKeys.subtract(pendingFlagKeys)
                pendingFlagKeys = []
            }

            // The name must be set last
            if values.keys.contains(.nameKey) {
                guard let value = values[.nameKey] as? String else {
                    throw finalError(CocoaError(.fileWriteInvalidFileName))
                }
                writtenValues[.nameKey] = value
                let newPath = fsPath.deletingLastPathComponent().appendingPathComponent(value)
                do {
                    try FileManager.default.moveItem(atPath: fsPath, toPath: newPath)
                } catch let error as CocoaError {
                    throw finalError(error)
                } catch {
                    throw error
                }
                unsuccessfulKeys.remove(.nameKey)
            }
        }
        
        return writtenValues
    }
}
#endif // canImport(Darwin)
#endif // !NO_FILESYSTEM
