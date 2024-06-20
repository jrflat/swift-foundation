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
protocol _URLResourceValuesProviderProtocol {

    init(url: URL) throws
    func write(_ values: [URLResourceKey: Any]) throws -> [URLResourceKey: Sendable]

    // MARK: - Core properties

    /// True for directories.
    func isDirectory() throws -> Bool?

    /// The resource name provided by the file system.
    func name() throws -> String?

    /// True for resources normally not displayed to users.
    func isHidden() throws -> Bool?

    /// True for user-immutable resources.
    func isUserImmutable() throws -> Bool?

    /// True for system-immutable resources.
    func isSystemImmutable() throws -> Bool?

    /// Number of hard links to the resource.
    func linkCount() throws -> Int?

    /// The date the resource was created, or renamed into or within its parent directory. Note that inconsistent behavior may be observed when this attribute is requested on hard-linked items. This property is not supported by all volumes.
    func addedToDirectoryDate() throws -> Date?

    /// Total file size in bytes
    ///
    /// - note: Only applicable to regular files.
    func fileSize() throws -> Int?

    /// True for regular files.
    func isRegularFile() throws -> Bool?

    /// True for symlinks.
    func isSymbolicLink() throws -> Bool?

    /// True if the resource is a Finder alias file or a symlink, false otherwise
    ///
    /// - note: Only applicable to regular files.
    func isAliasFile() throws -> Bool?

    /// True for the root directory of a volume.
    func isVolume() throws -> Bool?

    /// Total size allocated on disk for the file in bytes (number of blocks times block size)
    ///
    /// - note: Only applicable to regular files.
    func fileAllocatedSize() throws -> Int?

    /// The time the resource content was last modified.
    func contentModificationDate() throws -> Date?

    /// The time the resource's attributes were last modified.
    func attributeModificationDate() throws -> Date?

    /// The date the resource was created.
    func creationDate() throws -> Date?

    /// True for resources whose filename extension is removed from the localized name property.
    func hasHiddenExtension() throws -> Bool?

    /// True if this process (as determined by EUID) can read the resource.
    func isReadable() throws -> Bool?

    /// True if this process (as determined by EUID) can write to the resource.
    func isWritable() throws -> Bool?

    /// True if this process (as determined by EUID) can execute a file resource or search a directory resource.
    func isExecutable() throws -> Bool?

    /// The label number assigned to the resource.
    func labelNumber() throws -> Int?

    // .fileSecurity
    // .fileProtection

    /// The date the resource was last accessed.
    func contentAccessDate() throws -> Date?

    /// Total displayable size of the file in bytes (this may include space used by metadata), or nil if not available.
    ///
    /// - note: Only applicable to regular files.
    func totalFileSize() throws -> Int?

    /// Total allocated size of the file in bytes (this may include space used by metadata), or nil if not available. This can be less than the value returned by `totalFileSize` if the resource is compressed.
    ///
    /// - note: Only applicable to regular files.
    func totalFileAllocatedSize() throws -> Int?

    /// An identifier which can be used to compare two file system objects for equality.
    ///
    /// Two object identifiers are equal if they have the same file system path or if the paths are linked to same inode on the same file system. This identifier is not persistent across system restarts.
    func fileResourceIdentifier() throws -> Data?

    /// An opaque generation identifier which can be compared using `==` to determine if the data in a document has been modified.
    ///
    /// For URLs which refer to the same file inode, the generation identifier will change when the data in the file's data fork is changed (changes to extended attributes or other file system metadata do not change the generation identifier). For URLs which refer to the same directory inode, the generation identifier will change when direct children of that directory are added, removed or renamed (changes to the data of the direct children of that directory will not change the generation identifier). The generation identifier is persistent across system restarts. The generation identifier is tied to a specific document on a specific volume and is not transferred when the document is copied to another volume. This property is not supported by all volumes.
    func generationIdentifier() throws -> Data?

    /// The document identifier -- a value assigned by the kernel to a document (which can be either a file or directory) and is used to identify the document regardless of where it gets moved on a volume.
    ///
    /// The document identifier survives "safe save" operations; i.e it is sticky to the path it was assigned to. (`replaceItem(at:withItemAt:backupItemName:options:resultingItem:) throws` is the preferred safe-save API.) The document identifier is persistent across system restarts. The document identifier is not transferred when the file is copied. Document identifiers are only unique within a single volume. This property is not supported by all volumes.
    func documentIdentifier() throws -> Int?

    /// Returns the file system object type.
    func fileResourceType() throws -> URLFileResourceType?

    /// The optimal block size when reading or writing this file's data, or nil if not available.
    func preferredIOBlockSize() throws -> Int?

    /// True if this URL is a file system trigger directory. Traversing or opening a file system trigger will cause an attempt to mount a file system on the trigger directory.
    func isMountTrigger() throws -> Bool?

    /// The URL's path as a canonical absolute file system path.
    func canonicalPath() throws -> String?

    /// The file system's internal identifier for the item. This value is not stable for all file systems or
    /// across all mounts, so it should be used sparingly and not persisted.
    /// File identifiers on Windows require 128 bits, so we return a serialized `Data` object, similar to `.volumeIdentifier`.
    func fileIdentifier() throws -> Data?

    /// True for cloned files and their originals that may share all, some, or no data blocks.
    func mayShareFileContent() throws -> Bool?

    /// True if the file may have extended attributes. False guarantees there are none.
    func mayHaveExtendedAttributes() throws -> Bool?

    /// True if the file can be deleted by the file system when asked to free space.
    func isPurgeable() throws -> Bool?

    /// True if the file has sparse regions.
    func isSparse() throws -> Bool?

    /// Returns the count of file system objects contained in the directory. If the URL is not a directory or the file system cannot cheaply compute the value, `nil` is returned.
    func directoryEntryCount() throws -> Int?

    // MARK: - Path properties

    /// URL of the volume on which the resource is stored.
    func volumeURL() throws -> URL?

    /// The resource's parent directory, if any.
    func parentDirectoryURL() throws -> URL?

    /// True if resource should be excluded from backups, false otherwise.
    ///
    /// This property is only useful for excluding cache and other application support files which are not needed in a backup. Some operations commonly made to user documents will cause this property to be reset to false and so this property should not be used on user documents.
    func isExcludedFromBackup() throws -> Bool?

    /// The URL's path as a file system path.
    func path() throws -> String?

    // MARK: - Volume properties

    /// The name of the volume
    func volumeName() throws -> String?

    /// The user-visible volume format.
    func volumeLocalizedFormatDescription() throws -> String?

    /// The `URL` needed to remount a network volume, or `nil` if not available.
    func volumeURLForRemounting() throws -> URL?

    /// True if the volume is stored on a local device.
    func volumeIsLocal() throws -> Bool?

    /// True if the volume is automounted. Note: do not mistake this with the functionality provided by `volumeIsBrowsable()`.
    func volumeIsAutomounted() throws -> Bool?

    /// True if the volume should be visible via the GUI (i.e., appear on the Desktop as a separate volume).
    func volumeIsBrowsable() throws -> Bool?

    /// True if the volume is read-only.
    func volumeIsReadOnly() throws -> Bool?

    /// True if the volume's media is ejectable from the drive mechanism under software control.
    func volumeIsEjectable() throws -> Bool?

    // .volumeSupportsFileProtectionKey

    /// True if the volume is the root filesystem.
    func volumeIsRootFileSystem() throws -> Bool?

    /// True if the volume supports transparent decompression of compressed files using decmpfs.
    func volumeSupportsCompression() throws -> Bool?

    /// True if the volume format supports persistent object identifiers and can look up file system objects by their IDs.
    func volumeSupportsPersistentIDs() throws -> Bool?

    /// True if the volume format supports symbolic links.
    func volumeSupportsSymbolicLinks() throws -> Bool?

    /// True if the volume format supports a journal used to speed recovery in case of unplanned restart (such as a power outage or crash). This does not necessarily mean the volume is actively using a journal.
    func volumeSupportsJournaling() throws -> Bool?

    /// True if the volume can be renamed.
    func volumeSupportsRenaming() throws -> Bool?

    /// True if the volume format treats upper and lower case characters in file and directory names as different. Otherwise an upper case character is equivalent to a lower case character, and you can't have two names that differ solely in the case of the characters.
    func volumeSupportsCaseSensitiveNames() throws -> Bool?

    /// True if the volume format preserves the case of file and directory names.  Otherwise the volume may change the case of some characters (typically making them all upper or all lower case).
    func volumeSupportsCasePreservedNames() throws -> Bool?

    /// True if the volume implements whole-file `flock(2)` style advisory locks, and the `O_EXLOCK` and `O_SHLOCK` flags of the `open(2)` call.
    func volumeSupportsAdvisoryFileLocking() throws -> Bool?

    /// True if the volume supports reliable storage of times for the root directory.
    func volumeSupportsRootDirectoryDates() throws -> Bool?

    /// True if the volume implements extended security (ACLs).
    func volumeSupportsExtendedSecurity() throws -> Bool?

    /// True if the volume format supports hard links.
    func volumeSupportsHardLinks() throws -> Bool?

    /// True if the volume is currently using a journal for speedy recovery after an unplanned restart.
    func volumeIsJournaling() throws -> Bool?

    /// True if the volume format supports sparse files, that is, files which can have 'holes' that have never been written to, and thus do not consume space on disk. A sparse file may have an allocated size on disk that is less than its logical length.
    func volumeSupportsSparseFiles() throws -> Bool?

    /// For security reasons, parts of a file (runs) that have never been written to must appear to contain zeroes. True if the volume keeps track of allocated but unwritten runs of a file so that it can substitute zeroes without actually writing zeroes to the media.
    func volumeSupportsZeroRuns() throws -> Bool?

    /// True if the volume supports returning volume size values (`volumeTotalCapacity` and `volumeAvailableCapacity`).
    func volumeSupportsVolumeSizes() throws -> Bool?

    /// True if the volume supports clonefile(2).
    func volumeSupportsFileCloning() throws -> Bool?

    /// True if the volume supports renamex_np(2)'s RENAME_SWAP option.
    func volumeSupportsSwapRenaming() throws -> Bool?

    /// True if the volume supports renamex_np(2)'s RENAME_EXCL option.
    func volumeSupportsExclusiveRenaming() throws -> Bool?

    /// True if the volume supports making files immutable with isUserImmutable or isSystemImmutable.
    func volumeSupportsImmutableFiles() throws -> Bool?

    /// True if the volume supports setting POSIX access permissions with fileSecurity.
    func volumeSupportsAccessPermissions() throws -> Bool?

    /// True if the volume's device is connected to an internal bus, false if connected to an external bus, or nil if not available.
    func volumeIsInternal() throws -> Bool?

    /// The largest file size (in bytes) supported by this file system, or nil if this cannot be determined.
    func volumeMaximumFileSize() throws -> Int?

    /// The volume's creation date, or nil if this cannot be determined.
    func volumeCreationDate() throws -> Date?

    /// The volume's persistent `UUID` as a string, or `nil` if a persistent `UUID` is not available for the volume.
    func volumeUUIDString() throws -> String?

    /// An identifier that can be used to identify the volume the file system object is on.
    ///
    /// Other objects on the same volume will have the same volume identifier and can be compared for equality. This identifier is not persistent across system restarts.
    func volumeIdentifier() throws -> Data?

    /// Total volume capacity in bytes.
    func volumeTotalCapacity() throws -> Int?

    /// Total free space in bytes.
    func volumeAvailableCapacity() throws -> Int?

    /// Returns the name of the file system type.
    func volumeTypeName() throws -> String?

    /// Returns the file system subtype.
    func volumeSubtype() throws -> Int?

    /// Returns the file system device location.
    func volumeMountFromLocation() throws -> String?

    // MARK: - LaunchServices properties

    /// True for packaged directories.
    func isPackage() throws -> Bool?

    /// True if resource is an application.
    func isApplication() throws -> Bool?

    /// Localized or extension-hidden name as displayed to users.
    func localizedName() throws -> String?

    /// The user-visible label text.
    func localizedLabel() throws -> String?

    /// The user-presentable name of the volume
    func volumeLocalizedName() throws -> String?
}

extension _URLResourceValuesProviderProtocol {
    func read(_ keys: Set<URLResourceKey>) throws -> [URLResourceKey : any Sendable] {
        // Note: Implementations of this protocol cache filesystem info such
        // as stat and statfs, so looping through the keys does not require a
        // filesystem operation each time.
        var result = [URLResourceKey: Sendable]()
        for key in keys {
            result[key] = switch key {

                // MARK: Core properties

            case .isDirectoryKey: try isDirectory()
            case .nameKey: try name()
            case .isHiddenKey: try isHidden()
            case .isUserImmutableKey: try isUserImmutable()
            case .isSystemImmutableKey: try isSystemImmutable()
            case .linkCountKey: try linkCount()
            case .addedToDirectoryDateKey: try addedToDirectoryDate()
            case .fileSizeKey: try fileSize()
            case .isRegularFileKey: try isRegularFile()
            case .isSymbolicLinkKey: try isSymbolicLink()
            case .isAliasFileKey: try isAliasFile()
            case .isVolumeKey: try isVolume()
            case .fileAllocatedSizeKey: try fileAllocatedSize()
            case .contentModificationDateKey: try contentModificationDate()
            case .attributeModificationDateKey: try attributeModificationDate()
            case .creationDateKey: try creationDate()
            case .hasHiddenExtensionKey: try hasHiddenExtension()
            case .isReadableKey: try isReadable()
            case .isWritableKey: try isWritable()
            case .isExecutableKey: try isExecutable()
            case .labelNumberKey: try labelNumber()
            case .contentAccessDateKey: try contentAccessDate()
            case .totalFileSizeKey: try totalFileSize()
            case .totalFileAllocatedSizeKey: try totalFileAllocatedSize()
            case .fileResourceIdentifierKey: try fileResourceIdentifier()
            case .generationIdentifierKey: try generationIdentifier()
            case .documentIdentifierKey: try documentIdentifier()
            case .fileResourceTypeKey: try fileResourceType()
            case .preferredIOBlockSizeKey: try preferredIOBlockSize()
            case .isMountTriggerKey: try isMountTrigger()
            case .canonicalPathKey: try canonicalPath()
            case .fileIdentifierKey: try fileIdentifier()
            case .mayShareFileContentKey: try mayShareFileContent()
            case .mayHaveExtendedAttributesKey: try mayHaveExtendedAttributes()
            case .isPurgeableKey: try isPurgeable()
            case .isSparseKey: try isSparse()
            case .directoryEntryCountKey: try directoryEntryCount()

                // MARK: Path properties

            case .volumeURLKey: try volumeURL()
            case .parentDirectoryURLKey: try parentDirectoryURL()
            case .isExcludedFromBackupKey: try isExcludedFromBackup()
            case .pathKey: try path()

                // MARK: Volume properties

            case .volumeNameKey: try volumeName()
            case .volumeLocalizedFormatDescriptionKey: try volumeLocalizedFormatDescription()
            case .volumeURLForRemountingKey: try volumeURLForRemounting()
            case .volumeIsLocalKey: try volumeIsLocal()
            case .volumeIsAutomountedKey: try volumeIsAutomounted()
            case .volumeIsBrowsableKey: try volumeIsBrowsable()
            case .volumeIsReadOnlyKey: try volumeIsReadOnly()
            case .volumeIsEjectableKey: try volumeIsEjectable()
            case .volumeIsRootFileSystemKey: try volumeIsRootFileSystem()
            case .volumeSupportsCompressionKey: try volumeSupportsCompression()
            case .volumeSupportsPersistentIDsKey: try volumeSupportsPersistentIDs()
            case .volumeSupportsSymbolicLinksKey: try volumeSupportsSymbolicLinks()
            case .volumeSupportsJournalingKey: try volumeSupportsJournaling()
            case .volumeSupportsRenamingKey: try volumeSupportsRenaming()
            case .volumeSupportsCaseSensitiveNamesKey: try volumeSupportsCaseSensitiveNames()
            case .volumeSupportsCasePreservedNamesKey: try volumeSupportsCasePreservedNames()
            case .volumeSupportsAdvisoryFileLockingKey: try volumeSupportsAdvisoryFileLocking()
            case .volumeSupportsRootDirectoryDatesKey: try volumeSupportsRootDirectoryDates()
            case .volumeSupportsExtendedSecurityKey: try volumeSupportsExtendedSecurity()
            case .volumeSupportsHardLinksKey: try volumeSupportsHardLinks()
            case .volumeIsJournalingKey: try volumeIsJournaling()
            case .volumeSupportsSparseFilesKey: try volumeSupportsSparseFiles()
            case .volumeSupportsZeroRunsKey: try volumeSupportsZeroRuns()
            case .volumeSupportsVolumeSizesKey: try volumeSupportsVolumeSizes()
            case .volumeSupportsFileCloningKey: try volumeSupportsFileCloning()
            case .volumeSupportsSwapRenamingKey: try volumeSupportsSwapRenaming()
            case .volumeSupportsExclusiveRenamingKey: try volumeSupportsExclusiveRenaming()
            case .volumeSupportsImmutableFilesKey: try volumeSupportsImmutableFiles()
            case .volumeSupportsAccessPermissionsKey: try volumeSupportsAccessPermissions()
            case .volumeIsInternalKey: try volumeIsInternal()
            case .volumeMaximumFileSizeKey: try volumeMaximumFileSize()
            case .volumeCreationDateKey: try volumeCreationDate()
            case .volumeUUIDStringKey: try volumeUUIDString()
            case .volumeIdentifierKey: try volumeIdentifier()
            case .volumeTotalCapacityKey: try volumeTotalCapacity()
            case .volumeAvailableCapacityKey: try volumeAvailableCapacity()
            case .volumeTypeNameKey: try volumeTypeName()
            case .volumeSubtypeKey: try volumeSubtype()
            case .volumeMountFromLocationKey: try volumeMountFromLocation()

                // MARK: LaunchServices properties

            case .isPackageKey: try isPackage()
            case .isApplicationKey: try isApplication()
            case .localizedNameKey: try localizedName()
            case .localizedLabelKey: try localizedLabel()
            case .volumeLocalizedNameKey: try volumeLocalizedName()

            default: nil
            }
        }
        return result
    }
}

internal final class URLResourceValuesStorage: Sendable {
    private let useCache = false
    private let cacheLock: LockedState<[URLResourceKey: Sendable]>
    private let tempLock: LockedState<[URLResourceKey: Sendable]>

    init() {
        cacheLock = LockedState(initialState: [:])
        tempLock = LockedState(initialState: [:])
    }

    func removeAllCachedResourceValues() {
        cacheLock.withLock { $0 = [:] }
        tempLock.withLock { $0 = [:] }
    }

    func removeCachedResourceValue(forKey key: URLResourceKey) {
        cacheLock.withLock { $0[key] = nil }
        tempLock.withLock { $0[key] = nil }
    }

    private func removeCachedResourceValues() {
        cacheLock.withLock { $0 = [:] }
    }

    func setTemporaryResourceValue(_ value: Sendable?, forKey key: URLResourceKey) {
        tempLock.withLock { $0[key] = value }
    }

    func resourceValues(forKeys keys: Set<URLResourceKey>, url: URL) throws -> [URLResourceKey: Any] {
        let tempValues = tempLock.withLock {
            var values = [URLResourceKey: Sendable]()
            for key in keys {
                if let value = $0[key] {
                    values[key] = value
                }
            }
            return values
        }
        let cacheKeys = keys.subtracting(tempValues.keys)
        let cacheValues = try cacheLock.withLock {
            var values = [URLResourceKey: Sendable]()
            var keysToFetch = Set<URLResourceKey>()
            for key in cacheKeys {
                if let value = $0[key] {
                    values[key] = value
                } else {
                    keysToFetch.insert(key)
                }
            }

            if keysToFetch.isEmpty {
                return values
            }

            #if os(Windows)
            let provider = try _URLResourceValuesProvider(url: url)
            #else
            let provider = _URLResourceValuesProvider(url: url)
            #endif
            
            let found = try provider.read(keysToFetch)
            if useCache {
                $0.merge(found, uniquingKeysWith: { $1 })
            }
            values.merge(found, uniquingKeysWith: { $1 })
            return values
        }
        return cacheValues.merging(tempValues, uniquingKeysWith: { $1 })
    }

    func setResourceValues(_ values: [URLResourceKey: Any], url: URL) throws {
        try cacheLock.withLockUnchecked {
            #if os(Windows)
            let provider = try _URLResourceValuesProvider(url: url)
            #else
            let provider = _URLResourceValuesProvider(url: url)
            #endif

            // We must only store values that are verified to be Sendable in write(_:for:)
            let writtenValues = try provider.write(values)
            guard useCache else {
                return
            }

            if writtenValues.keys.contains(.nameKey) || writtenValues.keys.contains(.volumeNameKey) {
                // One of these key writes succeeded, all values are now invalid
                $0 = [:]
            } else {
                $0.merge(writtenValues, uniquingKeysWith: { $1 })
            }
        }
    }
}
#endif // !NO_FILESYSTEM
