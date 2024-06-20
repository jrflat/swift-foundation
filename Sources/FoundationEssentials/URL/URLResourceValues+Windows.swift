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
#if os(Windows)
import CRT
import WinSDK

internal final class _URLResourceValuesProvider: _URLResourceValuesProviderProtocol {
    let handle: HANDLE
    let url: URL

    init(url: URL) throws {
        self.handle = try url.fileSystemPath.withNTPathRepresentation { pwszPath in
            guard let handle = CreateFileW(pwszPath, 0, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nil),
                handle != INVALID_HANDLE_VALUE else {
                throw CocoaError.errorWithFilePath(url.fileSystemPath, win32: GetLastError(), reading: true)
            }
            return handle
        }
        self.url = url
    }

    deinit {
        CloseHandle(handle)
    }

    var lastReadError: CocoaError {
        return CocoaError.errorWithFilePath(url.fileSystemPath, win32: GetLastError(), reading: true)
    }

    var lastWriteError: CocoaError {
        return CocoaError.errorWithFilePath(url.fileSystemPath, win32: GetLastError(), reading: false)
    }

    private var _basicInfo: FILE_BASIC_INFO?
    private func basicInfo() throws -> FILE_BASIC_INFO {
        if let _basicInfo { return _basicInfo }
        var info = FILE_BASIC_INFO()
        guard GetFileInformationByHandleEx(handle, FileBasicInfo, &info, DWORD(MemoryLayout.size(ofValue: info))) else {
            throw lastReadError
        }
        _basicInfo = info
        return info
    }

    private func fileContainsAttribute(_ attribute: DWORD) throws -> Bool {
        return try basicInfo().FileAttributes & attribute != 0
    }

    private var _reparseTag: DWORD?
    private func reparseTag() throws -> DWORD {
        if let _reparseTag { return _reparseTag }
        var info = FILE_ATTRIBUTE_TAG_INFO()
        guard GetFileInformationByHandleEx(handle, FileAttributeTagInfo, &info, DWORD(MemoryLayout.size(ofValue: info))) else {
            throw lastReadError
        }
        _reparseTag = info.ReparseTag
        return info.ReparseTag
    }

    private var _standardInfo: FILE_STANDARD_INFO?
    private func standardInfo() throws -> FILE_STANDARD_INFO {
        if let _standardInfo { return _standardInfo }
        var info = FILE_STANDARD_INFO()
        guard GetFileInformationByHandleEx(handle, FileStandardInfo, &info, DWORD(MemoryLayout.size(ofValue: info))) else {
            throw lastReadError
        }
        _standardInfo = info
        return info
    }

    private var _fileIDInfo: FILE_ID_INFO?
    private func fileIDInfo() throws -> FILE_ID_INFO {
        if let _fileIDInfo { return _fileIDInfo }
        var info = FILE_ID_INFO()
        guard GetFileInformationByHandleEx(handle, FileIdInfo, &info, DWORD(MemoryLayout.size(ofValue: info))) else {
            throw lastReadError
        }
        _fileIDInfo = info
        return info
    }

    private struct VolumeInfo {
        let path: String
        let localizedName: String
        let serialNumber: UInt64
        let maxFileNameLengthW: Int // Length in WCHAR
        let fileSystemFlags: DWORD
        let fileSystemName: String
        let diskSpaceInfo: DISK_SPACE_INFORMATION

        init(handle: HANDLE, url: URL) throws {
            let fsPath = url.fileSystemPath
            let (volumePath, diskSpaceInfo) = try fsPath.withNTPathRepresentation { pwszPath in
                let dwPathLength = GetFullPathNameW(pwszPath, 0, nil, nil)
                guard dwPathLength > 0 else {
                    throw CocoaError.errorWithFilePath(fsPath, win32: GetLastError(), reading: true)
                }
                return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(dwPathLength)) { volumePathBuffer in
                    guard GetVolumePathNameW(pwszPath, volumePathBuffer.baseAddress, dwPathLength) else {
                        throw CocoaError.errorWithFilePath(fsPath, win32: GetLastError(), reading: true)
                    }

                    var diskSpaceInfo = DISK_SPACE_INFORMATION()
                    guard SUCCEEDED(GetDiskSpaceInformationW(volumePathBuffer.baseAddress, &diskSpaceInfo)) else {
                        throw CocoaError.errorWithFilePath(fsPath, win32: GetLastError(), reading: true)
                    }

                    return (
                        volumePath: String(decodingCString: volumePathBuffer.baseAddress!, as: UTF16.self),
                        diskSpaceInfo: diskSpaceInfo
                    )
                }
            }
            self.path = volumePath
            self.diskSpaceInfo = diskSpaceInfo

            let bufferSize = MAX_PATH + 1
            let properties = try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(bufferSize)) { volumeNameBuffer in
                return try withUnsafeTemporaryAllocation(of: WCHAR.self, capacity: Int(bufferSize)) { fileSystemNameBuffer in
                    var serialNumber = DWORD()
                    var maxComponentLength = DWORD()
                    var fileSystemFlags = DWORD()
                    guard GetVolumeInformationByHandleW(
                        handle,
                        volumeNameBuffer.baseAddress,
                        UInt32(bufferSize),
                        &serialNumber,
                        &maxComponentLength,
                        &fileSystemFlags,
                        fileSystemNameBuffer.baseAddress,
                        UInt32(bufferSize)
                    ) else {
                        throw CocoaError.errorWithFilePath(fsPath, win32: GetLastError(), reading: true)
                    }

                    return (
                        localizedName: String(decodingCString: volumeNameBuffer.baseAddress!, as: UTF16.self),
                        serialNumber: UInt64(serialNumber),
                        maxFileNameLengthW: Int(maxComponentLength),
                        fileSystemFlags: fileSystemFlags,
                        fileSystemName: String(decodingCString: fileSystemNameBuffer.baseAddress!, as: UTF16.self)
                    )
                }
            }

            self.localizedName = properties.localizedName
            self.serialNumber = properties.serialNumber
            self.maxFileNameLengthW = properties.maxFileNameLengthW
            self.fileSystemFlags = properties.fileSystemFlags
            self.fileSystemName = properties.fileSystemName
        }
    }

    private var _volumeInfo: VolumeInfo?
    private func volumeInfo() throws -> VolumeInfo {
        if let _volumeInfo {
            return _volumeInfo
        }
        let volumeInfo = try VolumeInfo(handle: handle, url: url)
        _volumeInfo = volumeInfo
        return volumeInfo
    }

    private func volumeContainsFlag(_ flag: Int32) throws -> Bool {
        try volumeInfo().fileSystemFlags & UInt32(flag) != 0
    }

    private func diskSpaceInfo() throws -> DISK_SPACE_INFORMATION {
        let volumeInfo = try volumeInfo()
        return volumeInfo.diskSpaceInfo
    }

    private func bytesPerAllocationUnit() throws -> Int {
        try Int(diskSpaceInfo().BytesPerSector * diskSpaceInfo().SectorsPerAllocationUnit)
    }

    func isDirectory() throws -> Bool? {
        try fileContainsAttribute(FILE_ATTRIBUTE_DIRECTORY)
    }

    func name() throws -> String? {
        url.lastPathComponent
    }

    func isHidden() throws -> Bool? {
        try fileContainsAttribute(UInt32(FILE_ATTRIBUTE_HIDDEN))
    }

    func isUserImmutable() throws -> Bool? {
        try fileContainsAttribute(FILE_ATTRIBUTE_READONLY)
    }

    func isSystemImmutable() throws -> Bool? {
        nil
    }

    func linkCount() throws -> Int? {
        try Int(standardInfo().NumberOfLinks)
    }

    func addedToDirectoryDate() throws -> Date? {
        nil
    }

    func fileSize() throws -> Int? {
        var liSize = LARGE_INTEGER()
        if GetFileSizeEx(handle, &liSize) {
            return Int(liSize.QuadPart)
        }
        return nil
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
        try volumeURL()?.fileSystemPath == url.fileSystemPath
    }

    func fileAllocatedSize() throws -> Int? {
        try Int(standardInfo().AllocationSize.QuadPart)
    }

    func contentModificationDate() throws -> Date? {
        let modificationTime = try basicInfo().LastWriteTime.QuadPart
        return Date(filetime: UInt64(modificationTime))
    }

    func attributeModificationDate() throws -> Date? {
        let changeTime = try basicInfo().ChangeTime.QuadPart
        return Date(filetime: UInt64(changeTime))
    }

    func creationDate() throws -> Date? {
        let creationTime = try basicInfo().CreationTime.QuadPart
        return Date(filetime: UInt64(creationTime))
    }

    func hasHiddenExtension() throws -> Bool? {
        nil
    }

    func isReadable() throws -> Bool? {
        FileManager.default.isReadableFile(atPath: url.fileSystemPath)
    }

    func isWritable() throws -> Bool? {
        FileManager.default.isWritableFile(atPath: url.fileSystemPath)
    }

    func isExecutable() throws -> Bool? {
        FileManager.default.isExecutableFile(atPath: url.fileSystemPath)
    }

    func labelNumber() throws -> Int? {
        nil
    }

    func contentAccessDate() throws -> Date? {
        let accessTime = try basicInfo().LastAccessTime.QuadPart
        return Date(filetime: UInt64(accessTime))
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
        if try fileContainsAttribute(FILE_ATTRIBUTE_REPARSE_POINT),
           try reparseTag() & IO_REPARSE_TAG_SYMLINK != 0 {
            return .symbolicLink
        }
        if try isDirectory() ?? false {
            return .directory
        }
        return .regular
    }

    func preferredIOBlockSize() throws -> Int? {
        try bytesPerAllocationUnit()
    }

    func isMountTrigger() throws -> Bool? {
        nil
    }

    func canonicalPath() throws -> String? {
        url.fileSystemPath.standardizingPath
    }

    func fileIdentifier() throws -> Data? {
        return try withUnsafeBytes(of: fileIDInfo().FileId) { Data($0) }
    }

    func mayShareFileContent() throws -> Bool? {
        nil
    }

    func mayHaveExtendedAttributes() throws -> Bool? {
        try !volumeContainsFlag(FILE_SUPPORTS_EXTENDED_ATTRIBUTES)
    }

    func isPurgeable() throws -> Bool? {
        if try standardInfo().DeletePending != 0 {
            return true
        }
        return nil
    }

    func isSparse() throws -> Bool? {
        try fileContainsAttribute(UInt32(FILE_ATTRIBUTE_SPARSE_FILE))
    }

    func directoryEntryCount() throws -> Int? {
        guard try isDirectory() ?? false else {
            return nil
        }
        return try FileManager.default.contentsOfDirectory(atPath: url.fileSystemPath).count
    }

    func volumeURL() throws -> URL? {
        return try URL(filePath: volumeInfo().path, directoryHint: .isDirectory)
    }

    func parentDirectoryURL() throws -> URL? {
        url.standardizedFileURL.deletingLastPathComponent()
    }

    func isExcludedFromBackup() throws -> Bool? {
        nil
    }

    func path() throws -> String? {
        url.fileSystemPath
    }

    func volumeName() throws -> String? {
        try volumeInfo().localizedName
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
        try volumeContainsFlag(FILE_READ_ONLY_VOLUME)
    }

    func volumeIsEjectable() throws -> Bool? {
        nil // SetupDiGetDeviceRegistryPropertyW?
    }

    func volumeIsRootFileSystem() throws -> Bool? {
        nil
    }

    func volumeSupportsCompression() throws -> Bool? {
        try volumeContainsFlag(FILE_FILE_COMPRESSION)
    }

    func volumeSupportsPersistentIDs() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_OBJECT_IDS)
    }

    func volumeSupportsSymbolicLinks() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_REPARSE_POINTS)
    }

    func volumeSupportsJournaling() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_USN_JOURNAL)
    }

    func volumeSupportsRenaming() throws -> Bool? {
        true
    }

    func volumeSupportsCaseSensitiveNames() throws -> Bool? {
        try volumeContainsFlag(FILE_CASE_SENSITIVE_SEARCH)
    }

    func volumeSupportsCasePreservedNames() throws -> Bool? {
        try volumeContainsFlag(FILE_CASE_PRESERVED_NAMES)
    }

    func volumeSupportsAdvisoryFileLocking() throws -> Bool? {
        nil
    }

    func volumeSupportsRootDirectoryDates() throws -> Bool? {
        true
    }

    // (Volume supports ACLs)
    func volumeSupportsExtendedSecurity() throws -> Bool? {
        try volumeContainsFlag(FILE_PERSISTENT_ACLS)
    }

    func volumeSupportsHardLinks() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_HARD_LINKS)
    }

    func volumeIsJournaling() throws -> Bool? {
        nil
    }

    func volumeSupportsSparseFiles() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_SPARSE_FILES)
    }

    func volumeSupportsZeroRuns() throws -> Bool? {
        nil
    }

    func volumeSupportsVolumeSizes() throws -> Bool? {
        true
    }

    func volumeSupportsFileCloning() throws -> Bool? {
        try volumeContainsFlag(FILE_SUPPORTS_BLOCK_REFCOUNTING)
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

    func volumeSupportsAccessPermissions() throws -> Bool? {
        nil
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
        nil // GUID from GetVolumeNameForVolumeMountPointW?
    }

    func volumeIdentifier() throws -> Data? {
        try withUnsafeBytes(of: fileIDInfo().VolumeSerialNumber) { Data($0) }
    }

    func volumeTotalCapacity() throws -> Int? {
        try Int(diskSpaceInfo().CallerTotalAllocationUnits) * bytesPerAllocationUnit()
    }

    private func volumeTotalCapacityNoQuota() throws -> Int {
        try Int(diskSpaceInfo().ActualTotalAllocationUnits) * bytesPerAllocationUnit()
    }

    func volumeAvailableCapacity() throws -> Int? {
        try Int(diskSpaceInfo().CallerAvailableAllocationUnits) * bytesPerAllocationUnit()
    }

    private func volumeAvailableCapacityNoQuota() throws -> Int {
        try Int(diskSpaceInfo().ActualAvailableAllocationUnits) * bytesPerAllocationUnit()
    }

    func volumeTypeName() throws -> String? {
        try volumeInfo().fileSystemName
    }

    func volumeSubtype() throws -> Int? {
        nil
    }

    func volumeMountFromLocation() throws -> String? {
        nil // GetVolumeNameForVolumeMountPointW?
    }

    func isPackage() throws -> Bool? {
        if try isDirectory() ?? false, !url.pathExtension.isEmpty {
            return true
        }
        return nil
    }

    func isApplication() throws -> Bool? {
        url.pathExtension == "exe"
    }

    func localizedName() throws -> String? {
        nil
    }

    func localizedLabel() throws -> String? {
        nil
    }

    func volumeLocalizedName() throws -> String? {
        try volumeName()
    }

    func write(_ values: [URLResourceKey: Any]) throws -> [URLResourceKey: Sendable] {
        // Keys we support:
        // .creationDateKey
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

        func updateTimes() throws {
            let creationDate = values[.creationDateKey] as? Date
            let accessDate = values[.contentAccessDateKey] as? Date
            let modificationDate = values[.contentModificationDateKey] as? Date
            guard creationDate != nil || accessDate != nil || modificationDate != nil else {
                return
            }

            writtenValues[.creationDateKey] = creationDate
            writtenValues[.contentAccessDateKey] = accessDate
            writtenValues[.contentModificationDateKey] = modificationDate

            func convert(_ date: Date?, into filetime: inout FILETIME?) throws {
                guard let date else {
                    return
                }
                let seconds = date.timeIntervalSince1601
                guard let filetimeValue = UInt64(exactly: seconds * 10_000_000.0) else {
                    throw finalError(CocoaError.errorWithFilePath(.fileWriteUnknown, url))
                }
                var uiTime = ULARGE_INTEGER()
                uiTime.QuadPart = filetimeValue

                filetime = FILETIME()
                filetime?.dwLowDateTime = uiTime.LowPart
                filetime?.dwHighDateTime = uiTime.HighPart
            }

            var creationTime: FILETIME?
            try convert(creationDate, into: &creationTime)
            unsuccessfulKeys.remove(.creationDateKey)

            var accessTime: FILETIME?
            try convert(accessDate, into: &accessTime)
            unsuccessfulKeys.remove(.contentAccessDateKey)

            var modificationTime: FILETIME?
            try convert(modificationDate, into: &modificationTime)
            unsuccessfulKeys.remove(.contentModificationDateKey)

            func withUnsafePointerOrNil<T, R>(to value: T?, body: (UnsafePointer<T>?) throws -> R) rethrows -> R {
                if let value {
                    return try withUnsafePointer(to: value) {
                        try body($0)
                    }
                } else {
                    return try body(nil)
                }
            }

            try url.fileSystemPath.withNTPathRepresentation { pwszPath in
                let writeHandle = CreateFileW(pwszPath, GENERIC_WRITE, FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, nil)
                guard writeHandle != INVALID_HANDLE_VALUE else {
                    throw lastReadError
                }
                defer { CloseHandle(writeHandle) }

                try withUnsafePointerOrNil(to: creationTime) { cTimePtr in
                    try withUnsafePointerOrNil(to: accessTime) { aTimePtr in
                        try withUnsafePointerOrNil(to: modificationTime) { mTimePtr in
                            guard SetFileTime(writeHandle, cTimePtr, aTimePtr, mTimePtr) else {
                                throw lastWriteError
                            }
                        }
                    }
                }
            }
        }

        try updateTimes()

        // The name must be set last
        if values.keys.contains(.nameKey) {
            guard let value = values[.nameKey] as? String else {
                throw finalError(CocoaError(.fileWriteInvalidFileName))
            }
            writtenValues[.nameKey] = value
            let fsPath = url.fileSystemPath
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
#endif // os(Windows)
#endif // !NO_FILESYSTEM
