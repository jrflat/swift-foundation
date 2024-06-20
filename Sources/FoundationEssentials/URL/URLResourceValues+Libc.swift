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
#if !canImport(Darwin) && !os(Windows)
#if canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
internal import _FoundationCShims
#elseif canImport(Musl)
import Musl
#elseif os(WASI)
import WASILibc
#endif

private struct FileSystemSupportEntry {
    let maximumFileSize: Int?
    let compression: Bool?
    let symbolicLinks: Bool?
    let journaling: Bool?
    let caseSensitiveNames: Bool?
    let casePreservedNames: Bool?
    let extendedSecurity: Bool? // ACLs
    let hardLinks: Bool?
    let sparseFiles: Bool?
    let fileCloning: Bool?
    let accessPermissions: Bool?
}

private enum FileSystemType: Hashable {
    case btrfs
    case ext3
    case ext4
    case f2fs
    case fat
    case hfsplus
    case jfs
    case ntfs
    case reiser4
    case ufs
    case xfs
    case zfs
    case unknown(String)

    init(_ fsType: String) {
        self = switch Array(fsType.lowercased().utf8) {
        case Array("btrfs".utf8): .btrfs
        case Array("ext3".utf8): .ext3
        case Array("ext4".utf8): .ext4
        case Array("f2fs".utf8): .f2fs
        case Array("fat".utf8): .fat
        case Array("hfsplus".utf8): .hfsplus
        case Array("jfs".utf8): .jfs
        case Array("ntfs".utf8): .ntfs
        case Array("reiser4".utf8): .reiser4
        case Array("ufs".utf8): .ufs
        case Array("xfs".utf8): .xfs
        case Array("zfs".utf8): .zfs
        default: .unknown(fsType)
        }
    }

    var stringValue: String {
        switch self {
        case .btrfs: return "btrfs"
        case .ext3: return "ext3"
        case .ext4: return "ext4"
        case .f2fs: return "f2fs"
        case .fat: return "fat"
        case .hfsplus: return "hfsplus"
        case .jfs: return "jfs"
        case .ntfs: return "ntfs"
        case .reiser4: return "reiser4"
        case .ufs: return "ufs"
        case .xfs: return "xfs"
        case .zfs: return "zfs"
        case .unknown(let name): return name
        }
    }
}


private let GiB = 1024 * 1024 * 1024
private let TiB = 1024 * GiB
private let PiB = 1024 * TiB
private let knownFileSystems: [FileSystemType: FileSystemSupportEntry] = [
    .btrfs: FileSystemSupportEntry(
        maximumFileSize: Int(Int64.max), // Actually 16 EiB (UInt64.max)
        compression: true,
        symbolicLinks: true,
        journaling: true, // Transactional
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: true,
        accessPermissions: true
    ),
    .ext3: FileSystemSupportEntry(
        maximumFileSize: nil, // Depends on block size
        compression: false,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: false,
        accessPermissions: true
    ),
    .ext4: FileSystemSupportEntry(
        maximumFileSize: nil, // Depends on block size
        compression: false,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: false,
        accessPermissions: true
    ),
    .f2fs: FileSystemSupportEntry(
        maximumFileSize: 4 * TiB,
        compression: true,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: nil,
        accessPermissions: true
    ),
    .fat: FileSystemSupportEntry(
        maximumFileSize: nil, // Depends on 12, 16, or 32 bit entries
        compression: false,
        symbolicLinks: false,
        journaling: false,
        caseSensitiveNames: false,
        casePreservedNames: nil,
        extendedSecurity: false,
        hardLinks: false,
        sparseFiles: false, // Only with certain compressed volumes
        fileCloning: nil,
        accessPermissions: false
    ),
    .hfsplus: FileSystemSupportEntry(
        maximumFileSize: Int(Int64.max), // 8 EiB
        compression: false,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: nil, // Optional
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: false,
        fileCloning: false,
        accessPermissions: true
    ),
    .jfs: FileSystemSupportEntry(
        maximumFileSize: 4 * PiB,
        compression: false,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: nil,
        accessPermissions: true
    ),
    .ntfs: FileSystemSupportEntry(
        maximumFileSize: nil, // Depends on block size
        compression: true,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: false,
        accessPermissions: true
    ),
    .reiser4: FileSystemSupportEntry(
        maximumFileSize: 8 * TiB,
        compression: true,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: false,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: nil,
        accessPermissions: true
    ),
    .ufs: FileSystemSupportEntry(
        maximumFileSize: nil, // Depends on block size
        compression: false,
        symbolicLinks: true,
        journaling: true, // Assuming UFS2
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: nil,
        accessPermissions: true
    ),
    .xfs: FileSystemSupportEntry(
        maximumFileSize: Int(Int64.max), // 8 EiB
        compression: false,
        symbolicLinks: true,
        journaling: true,
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: true,
        accessPermissions: true
    ),
    .zfs: FileSystemSupportEntry(
        maximumFileSize: Int(Int64.max), // Actually 16 EiB (UInt64.max)
        compression: true,
        symbolicLinks: true,
        journaling: true, // Transactional
        caseSensitiveNames: true,
        casePreservedNames: true,
        extendedSecurity: true,
        hardLinks: true,
        sparseFiles: true,
        fileCloning: nil,
        accessPermissions: true
    ),
]

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

    private var _statvfsInfo: statvfs?
    private func statvfsInfo() throws -> statvfs {
        if let _statvfsInfo {
            return _statvfsInfo
        }
        var s = statvfs()
        try fsPath.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, fsPath)
            }
            guard statvfs(fsRep, &s) == 0 else {
                throw CocoaError.errorWithFilePath(fsPath, errno: errno, reading: true)
            }
        }
        _statvfsInfo = s
        return s
    }

    // e.g. ("/dev/sda1", "/boot", .ext4)
    private typealias MountInfo = (device: String, mountPoint: String, fsType: FileSystemType)
    private var _mountInfoList: [MountInfo]?
    private func mountInfoList() throws -> [MountInfo]? {
        if let _mountInfoList {
            return _mountInfoList
        }
        let mountsURL = URL(filePath: "/proc/self/mounts", directoryHint: .notDirectory)
        guard let mounts = try? String(contentsOf: mountsURL, encoding: .utf8) else {
            return nil
        }
        let lines = mounts.utf8.split(separator: ._newline)
        var info = [MountInfo]()
        for line in lines {
            let columns = line.split(separator: ._space, omittingEmptySubsequences: true)
            guard columns.count >= 3,
                  let device = String(columns[0]),
                  let mountPoint = String(columns[1]),
                  let fileSystemType = String(columns[2]) else {
                continue
            }
            info.append((device, mountPoint, .init(fileSystemType)))
        }
        _mountInfoList = info
        return info
    }

    private var _mountInfo: MountInfo?
    private func mountInfo() throws -> MountInfo? {
        if let _mountInfo {
            return _mountInfo
        }
        guard let mountInfoList = try mountInfoList(), !mountInfoList.isEmpty else {
            return nil
        }
        for entry in mountInfoList {
            let mountPoint = entry.mountPoint
            var mountStat = stat()
            let success = mountPoint.withFileSystemRepresentation { fsRep in
                guard let fsRep else {
                    return false
                }
                return lstat(fsRep, &mountStat) == 0
            }
            guard success else {
                continue
            }
            if try statInfo().st_dev == mountStat.st_dev {
                _mountInfo = entry
                return entry
            }
        }
        return nil
    }

    private func volumeFlagsContain(_ flag: Int32) throws -> Bool {
        try UInt32(statvfsInfo().f_flag) & UInt32(flag) != 0
    }

    func isDirectory() throws -> Bool? {
        try fileResourceType() == .directory
    }

    func name() throws -> String? {
        fsPath.lastPathComponent
    }

    func isHidden() throws -> Bool? {
        try name()?.utf8.first == ._dot
    }

    func isUserImmutable() throws -> Bool? {
        nil
    }

    func isSystemImmutable() throws -> Bool? {
        nil
    }

    func linkCount() throws -> Int? {
        try Int(statInfo().st_nlink)
    }

    func addedToDirectoryDate() throws -> Date? {
        nil
    }

    func fileSize() throws -> Int? {
        guard try fileResourceType() == .regular || fileResourceType() == .symbolicLink else {
            return nil
        }
        return try Int(statInfo().st_size)
    }

    func isRegularFile() throws -> Bool? {
        try fileResourceType() == .regular
    }

    func isSymbolicLink() throws -> Bool? {
        try fileResourceType() == .symbolicLink
    }

    func isAliasFile() throws -> Bool? {
        try fileResourceType() == .symbolicLink
    }

    func isVolume() throws -> Bool? {
        if fsPath == "/" {
            return true
        }
        if let mountInfoList = try mountInfoList(), !mountInfoList.isEmpty {
            return mountInfoList.contains { $0.mountPoint == fsPath }
        }
        // Fall back to checking if st_dev differs for the parent
        let parentDirectoryPath = fsPath.standardizingPath.deletingLastPathComponent()
        var parentStat = stat()
        try parentDirectoryPath.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                throw CocoaError.errorWithFilePath(.fileReadUnknown, fsPath)
            }
            guard lstat(fsRep, &parentStat) == 0 else {
                throw CocoaError.errorWithFilePath(parentDirectoryPath, errno: errno, reading: true)
            }
        }
        return try statInfo().st_dev != parentStat.st_dev
    }

    func fileAllocatedSize() throws -> Int? {
        try Int(statInfo().st_blocks) * 512 // 512B blocks, see man lstat(2)
    }

    func contentModificationDate() throws -> Date? {
        let seconds = try TimeInterval(statInfo().st_mtim.tv_sec)
        let nanoSeconds = try TimeInterval(statInfo().st_mtim.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func attributeModificationDate() throws -> Date? {
        let seconds = try TimeInterval(statInfo().st_ctim.tv_sec)
        let nanoSeconds = try TimeInterval(statInfo().st_ctim.tv_nsec)
        return Date(seconds: seconds, nanoSeconds: nanoSeconds)
    }

    func creationDate() throws -> Date? {
        nil
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
        let seconds = TimeInterval(try statInfo().st_atim.tv_sec)
        let nanoSeconds = TimeInterval(try statInfo().st_atim.tv_nsec)
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
        nil
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
        return fsPath.withFileSystemRepresentation { fsRep in
            guard let fsRep else {
                return nil
            }
            return listxattr(fsRep, nil, 0) > 0
        }
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
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return URL(filePath: mountInfo.mountPoint, directoryHint: .isDirectory)
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
        try mountInfo()?.mountPoint.lastPathComponent
    }

    func volumeLocalizedFormatDescription() throws -> String? {
        nil
    }

    func volumeURLForRemounting() throws -> URL? {
        nil
    }

    func volumeIsLocal() throws -> Bool? {
        nil
    }

    func volumeIsAutomounted() throws -> Bool? {
        nil
    }

    func volumeIsBrowsable() throws -> Bool? {
        nil
    }

    func volumeIsReadOnly() throws -> Bool? {
        try volumeFlagsContain(Int32(ST_RDONLY))
    }

    func volumeIsEjectable() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        if mountInfo.mountPoint.utf8.starts(with: "/media/".utf8) {
            return true
        }
        let dev = mountInfo.device
        guard dev.utf8.starts(with: "/dev/".utf8) else {
            return nil
        }
        let devName = dev[dev.utf8.index(dev.startIndex, offsetBy: "/dev/".utf8.count)...]
        let removablePath = "/sys/block/\(devName)/removable"
        guard let result = try? String(contentsOfFile: removablePath, encoding: .ascii) else {
            return nil
        }
        if result == "1" {
            return true
        }
        return false
    }

    func volumeIsRootFileSystem() throws -> Bool? {
        if fsPath == "/" {
            return true
        }
        return nil
    }

    func volumeSupportsCompression() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.compression
    }

    func volumeSupportsPersistentIDs() throws -> Bool? {
        nil
    }

    func volumeSupportsSymbolicLinks() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.symbolicLinks
    }

    func volumeSupportsJournaling() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.journaling
    }

    func volumeSupportsRenaming() throws -> Bool? {
        true
    }

    func volumeSupportsCaseSensitiveNames() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.caseSensitiveNames
    }

    func volumeSupportsCasePreservedNames() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.casePreservedNames
    }

    func volumeSupportsAdvisoryFileLocking() throws -> Bool? {
        nil
    }

    func volumeSupportsRootDirectoryDates() throws -> Bool? {
        true
    }

    // (Volume supports ACLs)
    func volumeSupportsExtendedSecurity() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.extendedSecurity
    }

    func volumeSupportsHardLinks() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.hardLinks
    }

    func volumeIsJournaling() throws -> Bool? {
        nil
    }

    func volumeSupportsSparseFiles() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.sparseFiles
    }

    func volumeSupportsZeroRuns() throws -> Bool? {
        nil
    }

    func volumeSupportsVolumeSizes() throws -> Bool? {
        true
    }

    func volumeSupportsFileCloning() throws -> Bool? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.fileCloning
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
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.accessPermissions
    }

    func volumeIsInternal() throws -> Bool? {
        nil
    }

    func volumeMaximumFileSize() throws -> Int? {
        guard let mountInfo = try mountInfo() else {
            return nil
        }
        return knownFileSystems[mountInfo.fsType]?.maximumFileSize
    }

    func volumeCreationDate() throws -> Date? {
        nil
    }

    func volumeUUIDString() throws -> String? {
        nil
    }

    func volumeIdentifier() throws -> Data? {
        let deviceID = try UInt32(statInfo().st_dev)
        let volumeID = if deviceID != 0 {
            deviceID
        } else {
            try UInt32(statvfsInfo().f_fsid)
        }
        return withUnsafeBytes(of: volumeID) { Data($0) }
    }

    private func blockSize() throws -> Int {
        let frSize = try statvfsInfo().f_frsize
        if frSize != 0 {
            return Int(frSize)
        }
        return try Int(statvfsInfo().f_bsize)
    }

    func volumeTotalCapacity() throws -> Int? {
        try Int(statvfsInfo().f_blocks) * blockSize()
    }

    func volumeAvailableCapacity() throws -> Int? {
        // Under Linux, f_favail is always the same as f_ffree (man statvfs(3))
        try Int(statvfsInfo().f_bavail) * blockSize()
    }

    func volumeTypeName() throws -> String? {
        try mountInfo()?.fsType.stringValue
    }

    func volumeSubtype() throws -> Int? {
        nil
    }

    func volumeMountFromLocation() throws -> String? {
        try mountInfo()?.device
    }

    func isPackage() throws -> Bool? {
        if try isDirectory() ?? false, !fsPath.pathExtension.isEmpty {
            return true
        }
        return nil
    }

    func isApplication() throws -> Bool? {
        nil
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
        // Keys we support:
        // .contentAccessDateKey
        // .contentModificationDateKey
        // .nameKey

        // Return a dictionary of verified-Sendable values that were written
        var writtenValues = [URLResourceKey: Sendable]()
        var unsuccessfulKeys = Set(values.keys)

        func finalError(_ error: CocoaError) -> CocoaError {
            let unsetValuesKey = URLResourceKey.keysOfUnsetValuesKey.rawValue
            var userInfo = error.userInfo
            userInfo[unsetValuesKey] = Array(unsuccessfulKeys)
            return CocoaError(error.code, userInfo: userInfo)
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

            try fsPath.withFileSystemRepresentation { fsRep in
                guard let fsRep else {
                    throw CocoaError.errorWithFilePath(.fileReadUnknown, fsPath)
                }
                try withUnsafePointer(to: timevals) {
                    try $0.withMemoryRebound(to: timeval.self, capacity: 2) {
                        guard utimes(fsRep, $0) == 0 else {
                            throw CocoaError.errorWithFilePath(fsPath, errno: errno, reading: false)
                        }
                    }
                }
            }
            unsuccessfulKeys.remove(.contentAccessDateKey)
            unsuccessfulKeys.remove(.contentModificationDateKey)
        }

        try updateAccessAndModificationTimes()

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
        
        return writtenValues
    }
}
#endif // !canImport(Darwin) && !os(Windows)
#endif // !NO_FILESYSTEM
