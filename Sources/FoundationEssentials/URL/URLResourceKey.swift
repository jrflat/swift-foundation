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

#if !FOUNDATION_FRAMEWORK
public struct URLResourceKey: Hashable, RawRepresentable, Sendable {
    public typealias RawValue = String
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let nameKey = Self(rawValue: "NSURLNameKey")
    public static let localizedNameKey = Self(rawValue: "NSURLLocalizedNameKey")
    public static let isRegularFileKey = Self(rawValue: "NSURLIsRegularFileKey")
    public static let isDirectoryKey = Self(rawValue: "NSURLIsDirectoryKey")
    public static let isSymbolicLinkKey = Self(rawValue: "NSURLIsSymbolicLinkKey")
    public static let isVolumeKey = Self(rawValue: "NSURLIsVolumeKey")
    public static let isPackageKey = Self(rawValue: "NSURLIsPackageKey")
    public static let isApplicationKey = Self(rawValue: "NSURLIsApplicationKey")

    #if os(macOS)
    public static let applicationIsScriptableKey = Self(rawValue: "NSURLApplicationIsScriptableKey")
    #endif

    public static let isSystemImmutableKey = Self(rawValue: "NSURLIsSystemImmutableKey")
    public static let isUserImmutableKey = Self(rawValue: "NSURLIsUserImmutableKey")
    public static let isHiddenKey = Self(rawValue: "NSURLIsHiddenKey")
    public static let hasHiddenExtensionKey = Self(rawValue: "NSURLHasHiddenExtensionKey")
    public static let creationDateKey = Self(rawValue: "NSURLCreationDateKey")
    public static let contentAccessDateKey = Self(rawValue: "NSURLContentAccessDateKey")
    public static let contentModificationDateKey = Self(rawValue: "NSURLContentModificationDateKey")
    public static let attributeModificationDateKey = Self(rawValue: "NSURLAttributeModificationDateKey")
    public static let linkCountKey = Self(rawValue: "NSURLLinkCountKey")
    public static let parentDirectoryURLKey = Self(rawValue: "NSURLParentDirectoryURLKey")
    public static let volumeURLKey = Self(rawValue: "NSURLVolumeURLKey")
    public static let contentTypeKey = Self(rawValue: "NSURLContentTypeKey")
    public static let localizedTypeDescriptionKey = Self(rawValue: "NSURLLocalizedTypeDescriptionKey")
    public static let labelNumberKey = Self(rawValue: "NSURLLabelNumberKey")
    public static let labelColorKey = Self(rawValue: "NSURLLabelColorKey")
    public static let localizedLabelKey = Self(rawValue: "NSURLLocalizedLabelKey")
    public static let fileResourceIdentifierKey = Self(rawValue: "NSURLFileResourceIdentifierKey")
    public static let volumeIdentifierKey = Self(rawValue: "NSURLVolumeIdentifierKey")
    public static let fileIdentifierKey = Self(rawValue: "NSURLFileIdentifierKey")
    public static let fileContentIdentifierKey = Self(rawValue: "NSURLFileContentIdentifierKey")
    public static let preferredIOBlockSizeKey = Self(rawValue: "NSURLPreferredIOBlockSizeKey")
    public static let isReadableKey = Self(rawValue: "NSURLIsReadableKey")
    public static let isWritableKey = Self(rawValue: "NSURLIsWritableKey")
    public static let isExecutableKey = Self(rawValue: "NSURLIsExecutableKey")
    public static let fileSecurityKey = Self(rawValue: "NSURLFileSecurityKey")
    public static let isExcludedFromBackupKey = Self(rawValue: "NSURLIsExcludedFromBackupKey")

    #if os(macOS)
    public static let tagNamesKey = Self(rawValue: "NSURLTagNamesKey")
    #endif

    public static let pathKey = Self(rawValue: "NSURLPathKey")
    public static let canonicalPathKey = Self(rawValue: "NSURLCanonicalPathKey")
    public static let isMountTriggerKey = Self(rawValue: "NSURLIsMountTriggerKey")
    public static let generationIdentifierKey = Self(rawValue: "NSURLGenerationIdentifierKey")
    public static let documentIdentifierKey = Self(rawValue: "NSURLDocumentIdentifierKey")
    public static let addedToDirectoryDateKey = Self(rawValue: "NSURLAddedToDirectoryDateKey")

    #if os(macOS)
    public static let quarantinePropertiesKey = Self(rawValue: "NSURLQuarantinePropertiesKey")
    #endif

    public static let mayHaveExtendedAttributesKey = Self(rawValue: "NSURLMayHaveExtendedAttributesKey")
    public static let isPurgeableKey = Self(rawValue: "NSURLIsPurgeableKey")
    public static let isSparseKey = Self(rawValue: "NSURLIsSparseKey")
    public static let mayShareFileContentKey = Self(rawValue: "NSURLMayShareFileContentKey")
    public static let fileResourceTypeKey = Self(rawValue: "NSURLFileResourceTypeKey")
    public static let directoryEntryCountKey = Self(rawValue: "NSURLDirectoryEntryCountKey")

    public static let volumeLocalizedFormatDescriptionKey = Self(rawValue: "NSURLVolumeLocalizedFormatDescriptionKey")
    public static let volumeTotalCapacityKey = Self(rawValue: "NSURLVolumeTotalCapacityKey")
    public static let volumeAvailableCapacityKey = Self(rawValue: "NSURLVolumeAvailableCapacityKey")

    #if os(macOS) || os(iOS)
    public static let volumeAvailableCapacityForImportantUsageKey = Self(rawValue: "NSURLVolumeAvailableCapacityForImportantUsageKey")
    public static let volumeAvailableCapacityForOpportunisticUsageKey = Self(rawValue: "NSURLVolumeAvailableCapacityForOpportunisticUsageKey")
    #endif

    public static let volumeResourceCountKey = Self(rawValue: "NSURLVolumeResourceCountKey")
    public static let volumeSupportsPersistentIDsKey = Self(rawValue: "NSURLVolumeSupportsPersistentIDsKey")
    public static let volumeSupportsSymbolicLinksKey = Self(rawValue: "NSURLVolumeSupportsSymbolicLinksKey")
    public static let volumeSupportsHardLinksKey = Self(rawValue: "NSURLVolumeSupportsHardLinksKey")
    public static let volumeSupportsJournalingKey = Self(rawValue: "NSURLVolumeSupportsJournalingKey")
    public static let volumeIsJournalingKey = Self(rawValue: "NSURLVolumeIsJournalingKey")
    public static let volumeSupportsSparseFilesKey = Self(rawValue: "NSURLVolumeSupportsSparseFilesKey")
    public static let volumeSupportsZeroRunsKey = Self(rawValue: "NSURLVolumeSupportsZeroRunsKey")
    public static let volumeSupportsCaseSensitiveNamesKey = Self(rawValue: "NSURLVolumeSupportsCaseSensitiveNamesKey")
    public static let volumeSupportsCasePreservedNamesKey = Self(rawValue: "NSURLVolumeSupportsCasePreservedNamesKey")
    public static let volumeSupportsRootDirectoryDatesKey = Self(rawValue: "NSURLVolumeSupportsRootDirectoryDatesKey")
    public static let volumeSupportsVolumeSizesKey = Self(rawValue: "NSURLVolumeSupportsVolumeSizesKey")
    public static let volumeSupportsRenamingKey = Self(rawValue: "NSURLVolumeSupportsRenamingKey")
    public static let volumeSupportsAdvisoryFileLockingKey = Self(rawValue: "NSURLVolumeSupportsAdvisoryFileLockingKey")
    public static let volumeSupportsExtendedSecurityKey = Self(rawValue: "NSURLVolumeSupportsExtendedSecurityKey")
    public static let volumeIsBrowsableKey = Self(rawValue: "NSURLVolumeIsBrowsableKey")
    public static let volumeMaximumFileSizeKey = Self(rawValue: "NSURLVolumeMaximumFileSizeKey")
    public static let volumeIsEjectableKey = Self(rawValue: "NSURLVolumeIsEjectableKey")
    public static let volumeIsRemovableKey = Self(rawValue: "NSURLVolumeIsRemovableKey")
    public static let volumeIsInternalKey = Self(rawValue: "NSURLVolumeIsInternalKey")
    public static let volumeIsAutomountedKey = Self(rawValue: "NSURLVolumeIsAutomountedKey")
    public static let volumeIsLocalKey = Self(rawValue: "NSURLVolumeIsLocalKey")
    public static let volumeIsReadOnlyKey = Self(rawValue: "NSURLVolumeIsReadOnlyKey")
    public static let volumeCreationDateKey = Self(rawValue: "NSURLVolumeCreationDateKey")
    public static let volumeURLForRemountingKey = Self(rawValue: "NSURLVolumeURLForRemountingKey")
    public static let volumeUUIDStringKey = Self(rawValue: "NSURLVolumeUUIDStringKey")
    public static let volumeNameKey = Self(rawValue: "NSURLVolumeNameKey")
    public static let volumeLocalizedNameKey = Self(rawValue: "NSURLVolumeLocalizedNameKey")
    public static let volumeIsEncryptedKey = Self(rawValue: "NSURLVolumeIsEncryptedKey")
    public static let volumeIsRootFileSystemKey = Self(rawValue: "NSURLVolumeIsRootFileSystemKey")
    public static let volumeSupportsCompressionKey = Self(rawValue: "NSURLVolumeSupportsCompressionKey")
    public static let volumeSupportsFileCloningKey = Self(rawValue: "NSURLVolumeSupportsFileCloningKey")
    public static let volumeSupportsSwapRenamingKey = Self(rawValue: "NSURLVolumeSupportsSwapRenamingKey")
    public static let volumeSupportsExclusiveRenamingKey = Self(rawValue: "NSURLVolumeSupportsExclusiveRenamingKey")
    public static let volumeSupportsImmutableFilesKey = Self(rawValue: "NSURLVolumeSupportsImmutableFilesKey")
    public static let volumeSupportsAccessPermissionsKey = Self(rawValue: "NSURLVolumeSupportsAccessPermissionsKey")
    public static let volumeSupportsFileProtectionKey = Self(rawValue: "NSURLVolumeSupportsFileProtectionKey")
    public static let volumeTypeNameKey = Self(rawValue: "NSURLVolumeTypeNameKey")
    public static let volumeSubtypeKey = Self(rawValue: "NSURLVolumeSubtypeKey")
    public static let volumeMountFromLocationKey = Self(rawValue: "NSURLVolumeMountFromLocationKey")

    public static let isUbiquitousItemKey = Self(rawValue: "NSURLIsUbiquitousItemKey")
    public static let ubiquitousItemHasUnresolvedConflictsKey = Self(rawValue: "NSURLUbiquitousItemHasUnresolvedConflictsKey")
    public static let ubiquitousItemIsDownloadingKey = Self(rawValue: "NSURLUbiquitousItemIsDownloadingKey")
    public static let ubiquitousItemIsUploadedKey = Self(rawValue: "NSURLUbiquitousItemIsUploadedKey")
    public static let ubiquitousItemIsUploadingKey = Self(rawValue: "NSURLUbiquitousItemIsUploadingKey")
    public static let ubiquitousItemDownloadingStatusKey = Self(rawValue: "NSURLUbiquitousItemDownloadingStatusKey")
    public static let ubiquitousItemDownloadingErrorKey = Self(rawValue: "NSURLUbiquitousItemDownloadingErrorKey")
    public static let ubiquitousItemUploadingErrorKey = Self(rawValue: "NSURLUbiquitousItemUploadingErrorKey")
    public static let ubiquitousItemDownloadRequestedKey = Self(rawValue: "NSURLUbiquitousItemDownloadRequestedKey")
    public static let ubiquitousItemContainerDisplayNameKey = Self(rawValue: "NSURLUbiquitousItemContainerDisplayNameKey")
    public static let ubiquitousItemIsExcludedFromSyncKey = Self(rawValue: "NSURLUbiquitousItemIsExcludedFromSyncKey")

    #if os(macOS) || os(iOS)
    public static let ubiquitousItemIsSharedKey = Self(rawValue: "NSURLUbiquitousItemIsSharedKey")
    public static let ubiquitousSharedItemCurrentUserRoleKey = Self(rawValue: "NSURLUbiquitousSharedItemCurrentUserRoleKey")
    public static let ubiquitousSharedItemCurrentUserPermissionsKey = Self(rawValue: "NSURLUbiquitousSharedItemCurrentUserPermissionsKey")
    public static let ubiquitousSharedItemOwnerNameComponentsKey = Self(rawValue: "NSURLUbiquitousSharedItemOwnerNameComponentsKey")
    public static let ubiquitousSharedItemMostRecentEditorNameComponentsKey = Self(rawValue: "NSURLUbiquitousSharedItemMostRecentEditorNameComponentsKey")
    #endif // os(macOS) || os(iOS)

    public static let fileProtectionKey = Self(rawValue: "NSURLFileProtectionKey")
    public static let fileSizeKey = Self(rawValue: "NSURLFileSizeKey")
    public static let fileAllocatedSizeKey = Self(rawValue: "NSURLFileAllocatedSizeKey")
    public static let totalFileSizeKey = Self(rawValue: "NSURLTotalFileSizeKey")
    public static let totalFileAllocatedSizeKey = Self(rawValue: "NSURLTotalFileAllocatedSizeKey")
    public static let isAliasFileKey = Self(rawValue: "NSURLIsAliasFileKey")

    public static let keysOfUnsetValuesKey = Self(rawValue: "NSURLKeysOfUnsetValuesKey")
}

public struct URLFileResourceType: Hashable, RawRepresentable, Sendable {
    public typealias RawValue = String
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    public static let namedPipe = Self(rawValue: "NSURLFileResourceTypeNamedPipe")
    public static let characterSpecial = Self(rawValue: "NSURLFileResourceTypeCharacterSpecial")
    public static let directory = Self(rawValue: "NSURLFileResourceTypeDirectory")
    public static let blockSpecial = Self(rawValue: "NSURLFileResourceTypeBlockSpecial")
    public static let regular = Self(rawValue: "NSURLFileResourceTypeRegular")
    public static let symbolicLink = Self(rawValue: "NSURLFileResourceTypeSymbolicLink")
    public static let socket = Self(rawValue: "NSURLFileResourceTypeSocket")
    public static let unknown = Self(rawValue: "NSURLFileResourceTypeUnknown")
}

#endif // !FOUNDATION_FRAMEWORK
