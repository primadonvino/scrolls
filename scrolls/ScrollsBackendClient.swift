import Foundation
import AVFoundation
import Security
#if canImport(UIKit)
import UIKit
#endif

struct BackendUser: Codable, Sendable, Equatable {
    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let isVerified: Bool
    let isFounder: Bool
    let isPrivate: Bool?
    let accountType: String?
    let websiteURL: String?
    let venmoURL: String?
    let cashAppURL: String?
    let spotifyURL: String?
    let appleMusicURL: String?
    let businessLocation: String?
    let businessPhone: String?
    let homeCity: String?
    let avatarRef: String?
    let avatarProvider: String?
    let avatarBucket: String?
    let avatarObjectKey: String?
    let signatureRef: String?
    let avatarVideoRef: String?
    let subscriptionPlan: String?
    let subscriptionExpiresAt: Date?
    let pinnedPostID: UUID?
    let dateOfBirth: Date?
    let ageAssuranceCompletedAt: Date?
    let parentalControls: UserProfile.ParentalControls
    let writeVersion: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case display_name
        case bio
        case isVerified
        case is_verified
        case isFounder
        case is_founder
        case isPrivate
        case is_private
        case accountType
        case account_type
        case websiteURL
        case website_url
        case venmoURL
        case venmo_url
        case cashAppURL
        case cash_app_url
        case cashapp_url
        case spotifyURL
        case spotify_url
        case appleMusicURL
        case apple_music_url
        case businessLocation
        case business_location
        case businessPhone
        case business_phone
        case homeCity
        case home_city
        case avatarRef
        case avatar_ref
        case avatarProvider
        case avatar_provider
        case avatarBucket
        case avatar_bucket
        case avatarObjectKey
        case avatar_object_key
        case signatureRef
        case signature_ref
        case avatarVideoRef
        case avatar_video_ref
        case subscriptionPlan
        case subscription_plan
        case subscriptionExpiresAt
        case subscription_expires_at
        case pinnedPostID
        case pinnedPostId
        case pinned_post_id
        case dateOfBirth
        case date_of_birth
        case ageAssuranceCompletedAt
        case age_assurance_completed_at
        case parentalControls
        case parental_controls
        case writeVersion
        case write_version
        case updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

func decodeString(_ keys: [CodingKeys], default defaultValue: String = "") -> String {
    for key in keys {
        if let decoded = try? container.decode(String.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decodeIfPresent(String.self, forKey: key) {
            return decoded
        }
    }
    return defaultValue
}

func decodeBool(_ keys: [CodingKeys], default defaultValue: Bool = false) -> Bool {
    for key in keys {
        if let decoded = try? container.decode(Bool.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return decoded
        }
    }
    return defaultValue
}

func decodeOptionalBool(_ keys: [CodingKeys]) -> Bool? {
    for key in keys {
        if let decoded = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decode(Bool.self, forKey: key) {
            return decoded
        }
    }
    return nil
}

func decodeOptionalString(_ keys: [CodingKeys]) -> String? {
    for key in keys {
        if let decoded = try? container.decodeIfPresent(String.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decode(String.self, forKey: key) {
            return decoded
        }
    }
    return nil
}

func decodeOptionalDate(_ keys: [CodingKeys]) -> Date? {
    let iso = ISO8601DateFormatter()
    let day = DateFormatter()
    day.calendar = Calendar(identifier: .gregorian)
    day.locale = Locale(identifier: "en_US_POSIX")
    day.timeZone = TimeZone(secondsFromGMT: 0)
    day.dateFormat = "yyyy-MM-dd"
    for key in keys {
        if let decoded = try? container.decodeIfPresent(Date.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decode(Date.self, forKey: key) {
            return decoded
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key) {
            if let parsed = iso.date(from: raw) {
                return parsed
            }
            if let parsed = day.date(from: raw) {
                return parsed
            }
        }
            }
            return nil
        }

func decodeParentalControls(_ keys: [CodingKeys]) -> UserProfile.ParentalControls {
    for key in keys {
        if let decoded = try? container.decodeIfPresent(UserProfile.ParentalControls.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decode(UserProfile.ParentalControls.self, forKey: key) {
            return decoded
        }
    }
    return .none
}

func decodeOptionalUUID(_ keys: [CodingKeys]) -> UUID? {
    for key in keys {
        if let decoded = try? container.decodeIfPresent(UUID.self, forKey: key) {
            return decoded
        }
        if let decoded = try? container.decode(UUID.self, forKey: key) {
            return decoded
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key),
           let parsed = UUID(uuidString: raw) {
            return parsed
        }
    }
    return nil
}

        id = try container.decode(UUID.self, forKey: .id)
        username = decodeString([.username])
        displayName = decodeString([.displayName, .display_name])
        bio = decodeString([.bio])
        isVerified = decodeBool([.isVerified, .is_verified], default: false)
        isFounder = decodeBool([.isFounder, .is_founder], default: false)
        isPrivate = decodeOptionalBool([.isPrivate, .is_private])
        accountType = decodeOptionalString([.accountType, .account_type])
        websiteURL = decodeOptionalString([.websiteURL, .website_url])
        venmoURL = decodeOptionalString([.venmoURL, .venmo_url])
        cashAppURL = decodeOptionalString([.cashAppURL, .cash_app_url, .cashapp_url])
        spotifyURL = decodeOptionalString([.spotifyURL, .spotify_url])
        appleMusicURL = decodeOptionalString([.appleMusicURL, .apple_music_url])
        businessLocation = decodeOptionalString([.businessLocation, .business_location])
        businessPhone = decodeOptionalString([.businessPhone, .business_phone])
        homeCity = decodeOptionalString([.homeCity, .home_city])
        avatarRef = decodeOptionalString([.avatarRef, .avatar_ref])
        avatarProvider = decodeOptionalString([.avatarProvider, .avatar_provider])
        avatarBucket = decodeOptionalString([.avatarBucket, .avatar_bucket])
        avatarObjectKey = decodeOptionalString([.avatarObjectKey, .avatar_object_key])
        signatureRef = decodeOptionalString([.signatureRef, .signature_ref])
        avatarVideoRef = decodeOptionalString([.avatarVideoRef, .avatar_video_ref])
        subscriptionPlan = decodeOptionalString([.subscriptionPlan, .subscription_plan])
        subscriptionExpiresAt = decodeOptionalDate([.subscriptionExpiresAt, .subscription_expires_at])
        pinnedPostID = decodeOptionalUUID([.pinnedPostID, .pinnedPostId, .pinned_post_id])
        dateOfBirth = decodeOptionalDate([.dateOfBirth, .date_of_birth])
        ageAssuranceCompletedAt = decodeOptionalDate([.ageAssuranceCompletedAt, .age_assurance_completed_at])
        parentalControls = decodeParentalControls([.parentalControls, .parental_controls])
        writeVersion = decodeOptionalString([.writeVersion, .write_version, .updated_at])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(bio, forKey: .bio)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(isFounder, forKey: .isFounder)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try container.encodeIfPresent(accountType, forKey: .accountType)
        try container.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try container.encodeIfPresent(venmoURL, forKey: .venmoURL)
        try container.encodeIfPresent(cashAppURL, forKey: .cashAppURL)
        try container.encodeIfPresent(spotifyURL, forKey: .spotifyURL)
        try container.encodeIfPresent(appleMusicURL, forKey: .appleMusicURL)
        try container.encodeIfPresent(businessLocation, forKey: .businessLocation)
        try container.encodeIfPresent(businessPhone, forKey: .businessPhone)
        try container.encodeIfPresent(homeCity, forKey: .homeCity)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(avatarProvider, forKey: .avatarProvider)
        try container.encodeIfPresent(avatarBucket, forKey: .avatarBucket)
        try container.encodeIfPresent(avatarObjectKey, forKey: .avatarObjectKey)
        try container.encodeIfPresent(signatureRef, forKey: .signatureRef)
        try container.encodeIfPresent(avatarVideoRef, forKey: .avatarVideoRef)
        try container.encodeIfPresent(subscriptionPlan, forKey: .subscriptionPlan)
        try container.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try container.encodeIfPresent(pinnedPostID, forKey: .pinnedPostID)
        try container.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try container.encodeIfPresent(ageAssuranceCompletedAt, forKey: .ageAssuranceCompletedAt)
        try container.encode(parentalControls, forKey: .parentalControls)
        try container.encodeIfPresent(writeVersion, forKey: .writeVersion)
    }
}

struct BackendPost: Codable, Sendable, Equatable {
    enum PostType: String, Codable, Sendable {
        case text
        case photo
        case video
    }

    struct RescrollOrigin: Codable, Sendable, Equatable {
        let postID: UUID
        let user: BackendUser
        let caption: String?
        let websiteURL: String?
        let timestamp: Date
    }

    let id: UUID
    let author: BackendUser
    let rescrollOrigin: RescrollOrigin?
    let type: PostType
    let caption: String?
    let websiteURL: String?
    let locationCity: String?
    let textBody: String?
    let assetRef: String?
    let assetProvider: String?
    let assetBucket: String?
    let assetObjectKey: String?
    let coverImageRef: String?
    let coverProvider: String?
    let coverBucket: String?
    let coverObjectKey: String?
    let aspectRatio: Double?
    let createdAt: Date
    let quoteText: String?
}

struct BackendFeedPage: Codable, Sendable, Equatable {
    let posts: [BackendPost]
    let nextCursor: String?
    /// Optional list of post IDs the backend has deleted since the last sync.
    /// When present, clients must purge these IDs from every local feed array.
    /// Nil when the server hasn't been updated yet (backwards compatible).
    let deletedPostIDs: [UUID]?
}

struct BackendPostSearchPage: Codable, Sendable, Equatable {
    let relevant: [BackendPost]
    let recent: [BackendPost]
}

struct BackendUsersDirectoryPage: Codable, Sendable, Equatable {
    let users: [BackendUser]
    let nextCursor: String?
}

struct BackendUsersDeltaPage: Codable, Sendable, Equatable {
    let users: [BackendUser]
    let latestVersion: String?
}

struct BackendComment: Codable, Sendable, Equatable {
    let id: UUID
    let author: BackendUser
    let body: String
    let createdAt: Date
    let likedBy: [UUID]
    let replies: [BackendComment]

    private enum CodingKeys: String, CodingKey {
        case id
        case author
        case body
        case createdAt
        case created_at
        case likedBy
        case liked_by
        case replies
    }

    init(
        id: UUID,
        author: BackendUser,
        body: String,
        createdAt: Date,
        likedBy: [UUID],
        replies: [BackendComment]
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.createdAt = createdAt
        self.likedBy = likedBy
        self.replies = replies
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        author = try container.decode(BackendUser.self, forKey: .author)
        body = try container.decode(String.self, forKey: .body)

        if let camelCreatedAt = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = camelCreatedAt
        } else if let snakeCreatedAt = try? container.decode(Date.self, forKey: .created_at) {
            createdAt = snakeCreatedAt
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.createdAt,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Missing createdAt/created_at for BackendComment."
                )
            )
        }

        func decodeUUIDArray(for key: CodingKeys) -> [UUID]? {
            guard container.contains(key) else { return nil }
            if let decodedUUIDs = try? container.decodeIfPresent([UUID].self, forKey: key) {
                return decodedUUIDs
            }
            if let decodedStrings = try? container.decodeIfPresent([String].self, forKey: key) {
                return decodedStrings.compactMap { raw in
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    return UUID(uuidString: trimmed)
                }
            }
            return []
        }

        if let camelLikedBy = decodeUUIDArray(for: .likedBy) {
            likedBy = camelLikedBy
        } else if let snakeLikedBy = decodeUUIDArray(for: .liked_by) {
            likedBy = snakeLikedBy
        } else {
            likedBy = []
        }

        if let decodedReplies = try? container.decodeIfPresent([BackendComment].self, forKey: .replies) {
            replies = decodedReplies
        } else {
            replies = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(author, forKey: .author)
        try container.encode(body, forKey: .body)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(likedBy, forKey: .likedBy)
        try container.encode(replies, forKey: .replies)
    }
}

struct BackendNotification: Codable, Sendable, Equatable {
    let id: UUID
    let userID: UUID?
    let type: String
    let title: String
    let message: String
    let createdAt: Date
    let isRead: Bool
    let actorID: UUID?
    let objectID: UUID?
}

struct BackendNotificationsPage: Codable, Sendable, Equatable {
    let items: [BackendNotification]
    let nextCursor: String?
}

struct BackendCircleMember: Codable, Sendable, Equatable {
    let id: UUID
    let user: BackendUser
    let status: String
}

struct BackendCircleMessage: Codable, Sendable, Equatable {
    let id: UUID
    let user: BackendUser
    let encryptedText: String
    let createdAt: Date
    let sharedPostID: UUID?
    let sharedPost: BackendPost?
    let voiceProvider: String?
    let voiceBucket: String?
    let voiceObjectKey: String?
    let voiceDurationSeconds: Int?
    let photoProvider: String?
    let photoBucket: String?
    let photoObjectKey: String?
    let photoContentType: String?
    let photoWidth: Int?
    let photoHeight: Int?
    let expiresAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case user
        case encryptedText
        case encrypted_text
        case createdAt
        case created_at
        case sharedPostID
        case shared_post_id
        case sharedPost
        case shared_post
        case voiceProvider
        case voice_provider
        case voiceBucket
        case voice_bucket
        case voiceObjectKey
        case voice_object_key
        case voiceDurationSeconds
        case voice_duration_seconds
        case photoProvider
        case photo_provider
        case photoBucket
        case photo_bucket
        case photoObjectKey
        case photo_object_key
        case photoContentType
        case photo_content_type
        case photoWidth
        case photo_width
        case photoHeight
        case photo_height
        case expiresAt
        case expires_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user = try container.decode(BackendUser.self, forKey: .user)

        if let camel = try? container.decode(String.self, forKey: .encryptedText) {
            encryptedText = camel
        } else if let snake = try? container.decode(String.self, forKey: .encrypted_text) {
            encryptedText = snake
        } else {
            encryptedText = ""
        }

        if let camel = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = camel
        } else if let snake = try? container.decode(Date.self, forKey: .created_at) {
            createdAt = snake
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.createdAt,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing createdAt/created_at for BackendCircleMessage.")
            )
        }

        if let camel = try? container.decodeIfPresent(UUID.self, forKey: .sharedPostID) {
            sharedPostID = camel
        } else if let snake = try? container.decodeIfPresent(UUID.self, forKey: .shared_post_id) {
            sharedPostID = snake
        } else {
            sharedPostID = nil
        }

        if let camel = try? container.decodeIfPresent(BackendPost.self, forKey: .sharedPost) {
            sharedPost = camel
        } else if let snake = try? container.decodeIfPresent(BackendPost.self, forKey: .shared_post) {
            sharedPost = snake
        } else {
            sharedPost = nil
        }

        voiceProvider = (try? container.decodeIfPresent(String.self, forKey: .voiceProvider))
            ?? (try? container.decodeIfPresent(String.self, forKey: .voice_provider))
        voiceBucket = (try? container.decodeIfPresent(String.self, forKey: .voiceBucket))
            ?? (try? container.decodeIfPresent(String.self, forKey: .voice_bucket))
        voiceObjectKey = (try? container.decodeIfPresent(String.self, forKey: .voiceObjectKey))
            ?? (try? container.decodeIfPresent(String.self, forKey: .voice_object_key))
        voiceDurationSeconds = (try? container.decodeIfPresent(Int.self, forKey: .voiceDurationSeconds))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .voice_duration_seconds))
        photoProvider = (try? container.decodeIfPresent(String.self, forKey: .photoProvider))
            ?? (try? container.decodeIfPresent(String.self, forKey: .photo_provider))
        photoBucket = (try? container.decodeIfPresent(String.self, forKey: .photoBucket))
            ?? (try? container.decodeIfPresent(String.self, forKey: .photo_bucket))
        photoObjectKey = (try? container.decodeIfPresent(String.self, forKey: .photoObjectKey))
            ?? (try? container.decodeIfPresent(String.self, forKey: .photo_object_key))
        photoContentType = (try? container.decodeIfPresent(String.self, forKey: .photoContentType))
            ?? (try? container.decodeIfPresent(String.self, forKey: .photo_content_type))
        photoWidth = (try? container.decodeIfPresent(Int.self, forKey: .photoWidth))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .photo_width))
        photoHeight = (try? container.decodeIfPresent(Int.self, forKey: .photoHeight))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .photo_height))
        expiresAt = (try? container.decodeIfPresent(Date.self, forKey: .expiresAt))
            ?? (try? container.decodeIfPresent(Date.self, forKey: .expires_at))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user, forKey: .user)
        try container.encode(encryptedText, forKey: .encryptedText)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(sharedPostID, forKey: .sharedPostID)
        try container.encodeIfPresent(sharedPost, forKey: .sharedPost)
        try container.encodeIfPresent(voiceProvider, forKey: .voiceProvider)
        try container.encodeIfPresent(voiceBucket, forKey: .voiceBucket)
        try container.encodeIfPresent(voiceObjectKey, forKey: .voiceObjectKey)
        try container.encodeIfPresent(voiceDurationSeconds, forKey: .voiceDurationSeconds)
        try container.encodeIfPresent(photoProvider, forKey: .photoProvider)
        try container.encodeIfPresent(photoBucket, forKey: .photoBucket)
        try container.encodeIfPresent(photoObjectKey, forKey: .photoObjectKey)
        try container.encodeIfPresent(photoContentType, forKey: .photoContentType)
        try container.encodeIfPresent(photoWidth, forKey: .photoWidth)
        try container.encodeIfPresent(photoHeight, forKey: .photoHeight)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}

struct BackendCircle: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let avatarRef: String?
    let members: [BackendCircleMember]
    let messages: [BackendCircleMessage]
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarRef
        case avatar_ref
        case members
        case messages
        case createdAt
        case created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        if let camelAvatar = try? container.decodeIfPresent(String.self, forKey: .avatarRef) {
            avatarRef = camelAvatar
        } else if let snakeAvatar = try? container.decodeIfPresent(String.self, forKey: .avatar_ref) {
            avatarRef = snakeAvatar
        } else {
            avatarRef = nil
        }
        members = (try? container.decodeIfPresent([BackendCircleMember].self, forKey: .members)) ?? []
        messages = (try? container.decodeIfPresent([BackendCircleMessage].self, forKey: .messages)) ?? []

        if let camel = try? container.decode(Date.self, forKey: .createdAt) {
            createdAt = camel
        } else if let snake = try? container.decode(Date.self, forKey: .created_at) {
            createdAt = snake
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.createdAt,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "Missing createdAt/created_at for BackendCircle.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encode(members, forKey: .members)
        try container.encode(messages, forKey: .messages)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

private struct BackendTypingParticipantPayload: Decodable, Sendable, Equatable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarRef: String?
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case display_name
        case avatarRef
        case avatar_ref
        case updatedAt
        case updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = (try? container.decode(String.self, forKey: .username)) ?? ""
        displayName = (try? container.decode(String.self, forKey: .displayName))
            ?? (try? container.decode(String.self, forKey: .display_name))
            ?? username
        avatarRef = (try? container.decodeIfPresent(String.self, forKey: .avatarRef))
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatar_ref))
        if let camel = try? container.decode(Date.self, forKey: .updatedAt) {
            updatedAt = camel
        } else if let snake = try? container.decode(Date.self, forKey: .updated_at) {
            updatedAt = snake
        } else {
            updatedAt = Date()
        }
    }

    var typingParticipant: TypingParticipant {
        TypingParticipant(
            id: id,
            username: username,
            displayName: displayName,
            avatarRef: avatarRef,
            updatedAt: updatedAt
        )
    }
}

private struct BackendTypingParticipantsResponse: Decodable, Sendable, Equatable {
    let items: [BackendTypingParticipantPayload]
}

struct BackendPublicCircleSearchResult: Codable, Sendable, Equatable {
    let id: UUID
    let name: String
    let summary: String?
    let category: String?
    let tags: [String]
    let avatarRef: String?
    let memberCount: Int
    let creatorID: UUID?
    let creator: BackendUser?
    let createdAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case summary
        case category
        case tags
        case avatarRef
        case avatar_ref
        case memberCount
        case member_count
        case creatorID
        case creatorId
        case creator_id
        case creator
        case createdAt
        case created_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? "Public circle"
        summary = try? container.decodeIfPresent(String.self, forKey: .summary)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        tags = (try? container.decodeIfPresent([String].self, forKey: .tags)) ?? []
        avatarRef = (try? container.decodeIfPresent(String.self, forKey: .avatarRef))
            ?? (try? container.decodeIfPresent(String.self, forKey: .avatar_ref))
        memberCount = (try? container.decode(Int.self, forKey: .memberCount))
            ?? (try? container.decode(Int.self, forKey: .member_count))
            ?? 0
        creatorID = (try? container.decodeIfPresent(UUID.self, forKey: .creatorID))
            ?? (try? container.decodeIfPresent(UUID.self, forKey: .creatorId))
            ?? (try? container.decodeIfPresent(UUID.self, forKey: .creator_id))
        creator = try? container.decodeIfPresent(BackendUser.self, forKey: .creator)
        createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt))
            ?? (try? container.decodeIfPresent(Date.self, forKey: .created_at))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(creatorID, forKey: .creatorID)
        try container.encodeIfPresent(creator, forKey: .creator)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct BackendAdSubmissionPost: Codable, Sendable, Equatable {
    let id: UUID
    let type: BackendPost.PostType
    let caption: String?
    let websiteURL: String?
    let textBody: String?
    let locationCity: String?
    let assetRef: String?
    let assetProvider: String?
    let assetBucket: String?
    let assetObjectKey: String?
    let coverImageRef: String?
    let coverProvider: String?
    let coverBucket: String?
    let coverObjectKey: String?
    let aspectRatio: Double?
    let reportCount: Int
    let createdAt: Date
}

struct BackendAdSubmission: Codable, Sendable, Equatable {
    enum CampaignType: String, Codable, Sendable, CaseIterable {
        case gainFollowers = "gain_followers"
        case rescrolls = "rescroll_ads"
        case websiteLink = "website_link_ads"

        var title: String {
            switch self {
            case .gainFollowers:
                return "Gain followers"
            case .rescrolls:
                return "Rescroll ads"
            case .websiteLink:
                return "Website link ads"
            }
        }
    }

    let id: UUID
    let postID: UUID
    let businessUserID: UUID
    let targetCity: String
    let campaignType: CampaignType?
    let websiteURL: String?
    let status: String
    let moderationState: String
    let moderationNotes: String?
    let reviewNotes: String?
    let reviewedBy: UUID?
    let reviewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let post: BackendAdSubmissionPost?
    let businessUser: BackendUser?
    let reviewer: BackendUser?
}

struct BackendAdReviewEvent: Codable, Sendable, Equatable {
    let id: UUID
    let submissionID: UUID
    let action: String
    let fromStatus: String?
    let toStatus: String?
    let notes: String?
    let actorID: UUID?
    let createdAt: Date
}

struct BackendMomentLiveSession: Codable, Sendable, Equatable {
    enum Mode: String, Codable, Sendable {
        case mobile
        case obs
    }

    let id: UUID
    let ownerUserID: UUID
    let playbackURL: String
    let iframePlaybackURL: String?
    let startedAt: Date
    let title: String?
    let tipGoal: Decimal?
    let mode: Mode
    /// Plaintext password, if the backend returns it (owner-only). May be nil
    /// even for password-protected streams when the viewer endpoint omits it.
    let viewerPassword: String?
    /// True when the backend signals the stream is password-protected.
    /// Decoded from `has_viewer_password` / `hasViewerPassword`; also derived
    /// from `viewerPassword != nil` so owner-facing payloads work too.
    let hasViewerPassword: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID, owner_user_id
        case playbackURL, playback_url
        case iframePlaybackURL, iframe_playback_url
        case startedAt, started_at
        case title
        case tipGoal, tip_goal
        case mode
        case viewerPassword, viewer_password
        case hasViewerPassword, has_viewer_password
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        if let camel = try? c.decode(UUID.self, forKey: .ownerUserID) {
            ownerUserID = camel
        } else {
            ownerUserID = try c.decode(UUID.self, forKey: .owner_user_id)
        }
        if let camel = try? c.decode(String.self, forKey: .playbackURL) {
            playbackURL = camel
        } else {
            playbackURL = try c.decode(String.self, forKey: .playback_url)
        }
        if let camel = try? c.decodeIfPresent(String.self, forKey: .iframePlaybackURL) {
            iframePlaybackURL = camel
        } else {
            iframePlaybackURL = try? c.decodeIfPresent(String.self, forKey: .iframe_playback_url)
        }
        if let camel = try? c.decode(Date.self, forKey: .startedAt) {
            startedAt = camel
        } else {
            startedAt = try c.decode(Date.self, forKey: .started_at)
        }
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        if let camel = try? c.decodeIfPresent(Decimal.self, forKey: .tipGoal) {
            tipGoal = camel
        } else {
            tipGoal = try? c.decodeIfPresent(Decimal.self, forKey: .tip_goal)
        }
        mode = (try? c.decode(Mode.self, forKey: .mode)) ?? .mobile
        if let camel = try? c.decodeIfPresent(String.self, forKey: .viewerPassword) {
            viewerPassword = camel
        } else {
            viewerPassword = try? c.decodeIfPresent(String.self, forKey: .viewer_password)
        }
        // Derive hasViewerPassword from the explicit boolean field if present,
        // otherwise fall back to checking whether viewerPassword is non-empty.
        if let camelBool = try? c.decodeIfPresent(Bool.self, forKey: .hasViewerPassword) {
            hasViewerPassword = camelBool
        } else if let snakeBool = try? c.decodeIfPresent(Bool.self, forKey: .has_viewer_password) {
            hasViewerPassword = snakeBool
        } else {
            hasViewerPassword = viewerPassword.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(ownerUserID, forKey: .ownerUserID)
        try c.encode(playbackURL, forKey: .playbackURL)
        try c.encodeIfPresent(iframePlaybackURL, forKey: .iframePlaybackURL)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(tipGoal, forKey: .tipGoal)
        try c.encode(mode, forKey: .mode)
        try c.encodeIfPresent(viewerPassword, forKey: .viewerPassword)
        try c.encode(hasViewerPassword, forKey: .hasViewerPassword)
    }
}

struct BackendMoment: Codable, Sendable, Equatable {
    enum MediaType: String, Codable, Sendable {
        case image
        case video
    }

    enum SourceApp: String, Codable, Sendable {
        case scrolls
        case circles
    }

    let id: UUID
    let user: BackendUser
    let videoRef: String
    let mediaType: MediaType
    let sourceApp: SourceApp
    let circleMomentID: UUID?
    let createdAt: Date
    let expiresAt: Date
    let liveSession: BackendMomentLiveSession?
    /// Number of people who have viewed this moment.  Populated only for
    /// the author's own moments (the backend withholds it from others so
    /// the who-watched-what graph doesn't leak); 0 otherwise.
    let viewCount: Int
    /// Viewer ids — author-only, drives the "Seen by" sheet.
    let viewedBy: [String]
    /// Whether the requesting user has already viewed this moment.
    let hasViewed: Bool

    private enum CodingKeys: String, CodingKey {
        case id, user
        case videoRef, video_ref
        case mediaType, media_type
        case sourceApp, source_app
        case circleMomentID, circle_moment_id
        case createdAt, created_at
        case expiresAt, expires_at
        case liveSession, live_session
        case viewCount, view_count
        case viewedBy, viewed_by
        case hasViewed, has_viewed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        user = try c.decode(BackendUser.self, forKey: .user)
        if let camel = try? c.decode(String.self, forKey: .videoRef) {
            videoRef = camel
        } else {
            videoRef = try c.decode(String.self, forKey: .video_ref)
        }
        mediaType = (try? c.decodeIfPresent(MediaType.self, forKey: .mediaType))
            ?? (try? c.decodeIfPresent(MediaType.self, forKey: .media_type))
            ?? .video
        sourceApp = (try? c.decodeIfPresent(SourceApp.self, forKey: .sourceApp))
            ?? (try? c.decodeIfPresent(SourceApp.self, forKey: .source_app))
            ?? .scrolls
        circleMomentID = (try? c.decodeIfPresent(UUID.self, forKey: .circleMomentID))
            ?? (try? c.decodeIfPresent(UUID.self, forKey: .circle_moment_id))
        if let camel = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = camel
        } else {
            createdAt = try c.decode(Date.self, forKey: .created_at)
        }
        if let camel = try? c.decode(Date.self, forKey: .expiresAt) {
            expiresAt = camel
        } else {
            expiresAt = try c.decode(Date.self, forKey: .expires_at)
        }
        if let camel = try? c.decodeIfPresent(BackendMomentLiveSession.self, forKey: .liveSession) {
            liveSession = camel
        } else {
            liveSession = try? c.decodeIfPresent(BackendMomentLiveSession.self, forKey: .live_session)
        }
        viewCount = (try? c.decodeIfPresent(Int.self, forKey: .viewCount))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .view_count))
            ?? 0
        viewedBy = (try? c.decodeIfPresent([String].self, forKey: .viewedBy))
            ?? (try? c.decodeIfPresent([String].self, forKey: .viewed_by))
            ?? []
        hasViewed = (try? c.decodeIfPresent(Bool.self, forKey: .hasViewed))
            ?? (try? c.decodeIfPresent(Bool.self, forKey: .has_viewed))
            ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(user, forKey: .user)
        try c.encode(videoRef, forKey: .videoRef)
        try c.encode(mediaType, forKey: .mediaType)
        try c.encode(sourceApp, forKey: .sourceApp)
        try c.encodeIfPresent(circleMomentID, forKey: .circleMomentID)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(expiresAt, forKey: .expiresAt)
        try c.encodeIfPresent(liveSession, forKey: .liveSession)
        try c.encode(viewCount, forKey: .viewCount)
        try c.encode(viewedBy, forKey: .viewedBy)
        try c.encode(hasViewed, forKey: .hasViewed)
    }
}

/// One viewer row from `GET /moments/viewers` — the user plus when they
/// first opened the moment.
struct BackendMomentViewer: Codable, Sendable, Equatable {
    let user: BackendUser
    let viewedAt: Date

    private enum CodingKeys: String, CodingKey {
        case user
        case viewedAt, viewed_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = try c.decode(BackendUser.self, forKey: .user)
        if let camel = try? c.decode(Date.self, forKey: .viewedAt) {
            viewedAt = camel
        } else {
            viewedAt = (try? c.decode(Date.self, forKey: .viewed_at)) ?? Date()
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(user, forKey: .user)
        try c.encode(viewedAt, forKey: .viewedAt)
    }
}

struct BackendAdDeliveryItem: Codable, Sendable, Equatable {
    let submission: BackendAdSubmission
    let post: BackendAdSubmissionPost
    let businessUser: BackendUser?
}

struct BackendSplashAd: Codable, Sendable, Equatable {
    let assetRef: String?
    let headline: String?
    let body: String?
    let websiteURL: String?
    let ctaLabel: String?
    let updatedAt: Date?
}

struct BackendLiveStreamSession: Decodable, Sendable, Equatable {
    enum Mode: String, Codable, Sendable {
        case mobile
        case obs
    }

    let id: UUID
    let ownerUserID: UUID
    let mode: Mode
    let title: String?
    let description: String?
    let tipGoal: Decimal?
    let streamKey: String
    let ingestURL: String
    let playbackURL: String
    let iframePlaybackURL: String?
    let status: String
    let startedAt: Date
    let endedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    /// Plaintext viewer password. May be nil even for protected streams when
    /// the backend omits it from viewer-facing responses.
    let viewerPassword: String?
    /// True when the stream is password-protected. Decoded from
    /// `has_viewer_password` / `hasViewerPassword`; derived from
    /// `viewerPassword != nil` when neither explicit boolean is present.
    let hasViewerPassword: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID
        case owner_user_id
        case mode
        case title
        case description
        case tipGoal
        case tip_goal
        case streamKey
        case stream_key
        case ingestURL
        case ingest_url
        case playbackURL
        case playback_url
        case iframePlaybackURL
        case iframe_playback_url
        case status
        case startedAt
        case started_at
        case endedAt
        case ended_at
        case createdAt
        case created_at
        case updatedAt
        case updated_at
        case viewerPassword
        case viewer_password
        case hasViewerPassword
        case has_viewer_password
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        if let camel = try? c.decode(UUID.self, forKey: .ownerUserID) {
            ownerUserID = camel
        } else {
            ownerUserID = try c.decode(UUID.self, forKey: .owner_user_id)
        }
        mode = (try? c.decode(Mode.self, forKey: .mode)) ?? .mobile
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        if let camel = try? c.decodeIfPresent(Decimal.self, forKey: .tipGoal) {
            tipGoal = camel
        } else {
            tipGoal = try? c.decodeIfPresent(Decimal.self, forKey: .tip_goal)
        }
        if let camel = try? c.decode(String.self, forKey: .streamKey) {
            streamKey = camel
        } else {
            streamKey = try c.decode(String.self, forKey: .stream_key)
        }
        if let camel = try? c.decode(String.self, forKey: .ingestURL) {
            ingestURL = camel
        } else {
            ingestURL = try c.decode(String.self, forKey: .ingest_url)
        }
        if let camel = try? c.decode(String.self, forKey: .playbackURL) {
            playbackURL = camel
        } else {
            playbackURL = try c.decode(String.self, forKey: .playback_url)
        }
        if let camel = try? c.decodeIfPresent(String.self, forKey: .iframePlaybackURL) {
            iframePlaybackURL = camel
        } else {
            iframePlaybackURL = try? c.decodeIfPresent(String.self, forKey: .iframe_playback_url)
        }
        status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        if let camel = try? c.decode(Date.self, forKey: .startedAt) {
            startedAt = camel
        } else {
            startedAt = try c.decode(Date.self, forKey: .started_at)
        }
        if let camel = try? c.decodeIfPresent(Date.self, forKey: .endedAt) {
            endedAt = camel
        } else {
            endedAt = try? c.decodeIfPresent(Date.self, forKey: .ended_at)
        }
        if let camel = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = camel
        } else {
            createdAt = try c.decode(Date.self, forKey: .created_at)
        }
        if let camel = try? c.decode(Date.self, forKey: .updatedAt) {
            updatedAt = camel
        } else {
            updatedAt = try c.decode(Date.self, forKey: .updated_at)
        }
        if let camel = try? c.decodeIfPresent(String.self, forKey: .viewerPassword) {
            viewerPassword = camel
        } else {
            viewerPassword = try? c.decodeIfPresent(String.self, forKey: .viewer_password)
        }
        if let camelBool = try? c.decodeIfPresent(Bool.self, forKey: .hasViewerPassword) {
            hasViewerPassword = camelBool
        } else if let snakeBool = try? c.decodeIfPresent(Bool.self, forKey: .has_viewer_password) {
            hasViewerPassword = snakeBool
        } else {
            hasViewerPassword = viewerPassword.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        }
    }
}

struct BackendPostReportPost: Codable, Sendable, Equatable {
    let id: UUID
    let caption: String?
    let textBody: String?
    let createdAt: Date?
}

struct BackendMusicPlaylist: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let ownerID: UUID
    let postID: UUID?
    let title: String
    let visibility: String
    let coverRef: String?
    let coverProvider: String?
    let coverBucket: String?
    let coverObjectKey: String?
    let trackCount: Int
    let createdAt: Date
    let updatedAt: Date
}

extension BackendMusicPlaylist {
    var resolvedCoverURL: URL? {
        MediaURLResolver.resolve(
            provider: coverProvider,
            bucket: coverBucket,
            objectKey: coverObjectKey,
            legacyURL: coverRef
        )
    }
}

struct BackendMusicPlaylistTrack: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let playlistID: UUID
    let ownerID: UUID
    let sourcePostID: UUID
    let trackID: UUID
    let trackTitle: String
    let artistCreditsSnapshot: [MusicTrackArtistCredit]
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date
}

struct BackendMusicPlaylistPage: Codable, Sendable, Equatable {
    let playlists: [BackendMusicPlaylist]
}

struct BackendMusicPlaylistDetail: Codable, Sendable, Equatable {
    let playlist: BackendMusicPlaylist
    let tracks: [BackendMusicPlaylistTrack]
    let sourcePosts: [BackendPost]?
}

struct BackendLiveStreamComment: Decodable, Sendable, Equatable {
    let id: UUID
    let sessionID: UUID
    let author: BackendUser
    let body: String
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case sessionID
        case session_id
        case author
        case body
        case createdAt
        case created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        if let camel = try? c.decode(UUID.self, forKey: .sessionID) {
            sessionID = camel
        } else {
            sessionID = try c.decode(UUID.self, forKey: .session_id)
        }
        author = try c.decode(BackendUser.self, forKey: .author)
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        if let camel = try? c.decode(Date.self, forKey: .createdAt) {
            createdAt = camel
        } else {
            createdAt = try c.decode(Date.self, forKey: .created_at)
        }
    }
}

/// Lightweight typed wrapper for the generic content-report endpoint
/// (`POST /me/content-report`).  Reuses `BackendPostReport.Reason` for
/// the reason enum so reviewers see the same options no matter what
/// kind of content they're flagging.
enum BackendContentReport {
    enum TargetType: String, Codable, Sendable, CaseIterable {
        case comment
        case musicTrack = "music_track"
        case voiceMessage = "voice_message"
        case circleMessage = "circle_message"
        case avatar

        var humanLabel: String {
            switch self {
            case .comment: return "comment"
            case .musicTrack: return "track"
            case .voiceMessage: return "voice message"
            case .circleMessage: return "message"
            case .avatar: return "profile picture"
            }
        }
    }
}

struct BackendPostReport: Codable, Sendable, Equatable {
    enum Reason: String, Codable, Sendable, CaseIterable {
        case drugs
        case violence
        case nuditySexualThemes = "nudity_sexual_themes"
        case spam
        case harassmentBullying = "harassment_bullying"
        case hateSpeechDiscrimination = "hate_speech_discrimination"
        case misinformation
        case copyrightViolation = "copyright_violation"
        case impersonation

        var title: String {
            switch self {
            case .drugs: return "Drugs"
            case .violence: return "Violence"
            case .nuditySexualThemes: return "Nudity / Sexual Themes"
            case .spam: return "Spam"
            case .harassmentBullying: return "Harassment / Bullying"
            case .hateSpeechDiscrimination: return "Hate Speech / Discrimination"
            case .misinformation: return "Misinformation"
            case .copyrightViolation: return "Copyright Violation"
            case .impersonation: return "Impersonation"
            }
        }
    }

    enum Status: String, Codable, Sendable {
        case pending
        case confirmed
        case dismissed
    }

    let id: UUID
    let postID: UUID
    let reporterID: UUID
    let reporter: BackendUser?
    let reason: Reason
    let notes: String?
    let status: Status
    let reviewedBy: UUID?
    let reviewer: BackendUser?
    let reviewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let post: BackendPostReportPost?
    let postAuthor: BackendUser?
}

/// Founder/admin moderation queue entry for a single profile report.
/// Shape mirrors what `GET /users/profile-reports` returns.
struct BackendProfileReport: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let targetUserID: UUID
    let target: BackendUser?
    let reporterID: UUID
    let reporter: BackendUser?
    let reason: BackendPostReport.Reason
    let notes: String?
    let status: BackendPostReport.Status
    let reviewedBy: UUID?
    let reviewer: BackendUser?
    let reviewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

/// Founder/admin moderation queue entry for a live-stream report.
struct BackendLiveStreamReport: Codable, Sendable, Identifiable, Equatable {
    struct Session: Codable, Sendable, Equatable {
        let id: UUID
        let title: String?
        let status: String
        let createdAt: Date?
        let endedAt: Date?
    }
    let id: UUID
    let sessionID: UUID?
    let ownerUserID: UUID
    let owner: BackendUser?
    let reporterID: UUID
    let reporter: BackendUser?
    let reason: BackendPostReport.Reason
    let notes: String?
    let status: BackendPostReport.Status
    let reviewedAt: Date?
    let createdAt: Date
    let session: Session?
}

/// Founder/admin moderation queue entry for a non-post UGC report — a
/// comment, music track, voice message, circle message, or avatar.
struct BackendContentReportRecord: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let targetType: BackendContentReport.TargetType
    let targetID: UUID
    let targetOwnerID: UUID?
    let targetOwner: BackendUser?
    let reporterID: UUID
    let reporter: BackendUser?
    let reason: BackendPostReport.Reason
    let notes: String?
    let status: BackendPostReport.Status
    let reviewedAt: Date?
    let createdAt: Date
}

struct BackendAuthSession: Decodable, Sendable {
    let token: String
    let refreshToken: String?
    /// Non-nil for login/signup responses. May be nil for refresh responses when the
    /// server successfully rotated the session token but the profile lookup failed.
    /// Callers in the login/signup path must guard against nil (treat as an error).
    let user: BackendUser?

    private enum CodingKeys: String, CodingKey {
        case token
        case accessToken
        case refreshToken
        case user
        case session
        case data
    }

    private enum SnakeCodingKeys: String, CodingKey {
        case access_token
        case refresh_token
    }

    private struct NestedSession: Codable {
        let token: String?
        let accessToken: String?
        let refreshToken: String?
        let access_token: String?
        let refresh_token: String?
    }

    private struct NestedData: Codable {
        let token: String?
        let accessToken: String?
        let refreshToken: String?
        let access_token: String?
        let refresh_token: String?
        let user: BackendUser?
        let session: NestedSession?
    }

    init(token: String, refreshToken: String?, user: BackendUser) {
        self.token = token
        self.refreshToken = refreshToken
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCodingKeys.self)

        let nestedSession = try container.decodeIfPresent(NestedSession.self, forKey: .session)
        let nestedData = try container.decodeIfPresent(NestedData.self, forKey: .data)
        let nestedDataSession = nestedData?.session

        let tokenCandidates: [String?] = [
            try container.decodeIfPresent(String.self, forKey: .token),
            try container.decodeIfPresent(String.self, forKey: .accessToken),
            try snakeContainer.decodeIfPresent(String.self, forKey: .access_token),
            nestedData?.token,
            nestedData?.accessToken,
            nestedData?.access_token,
            nestedSession?.token,
            nestedSession?.accessToken,
            nestedSession?.access_token,
            nestedDataSession?.token,
            nestedDataSession?.accessToken,
            nestedDataSession?.access_token
        ]
        guard let resolvedToken = tokenCandidates
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw DecodingError.keyNotFound(
                CodingKeys.token,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing auth token in BackendAuthSession payload."
                )
            )
        }

        let refreshCandidates: [String?] = [
            try container.decodeIfPresent(String.self, forKey: .refreshToken),
            try snakeContainer.decodeIfPresent(String.self, forKey: .refresh_token),
            nestedSession?.refreshToken,
            nestedSession?.refresh_token,
            nestedData?.refreshToken,
            nestedData?.refresh_token,
            nestedDataSession?.refreshToken,
            nestedDataSession?.refresh_token
        ]
        let resolvedRefresh = refreshCandidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

#if DEBUG
        if resolvedRefresh == nil {
            let keyList = container.allKeys.map(\.stringValue).sorted().joined(separator: ",")
            let snakeKeyList = snakeContainer.allKeys.map(\.stringValue).sorted().joined(separator: ",")
            print("[BackendAuthSession] Missing refresh token in auth payload. keys=[\(keyList)] snake=[\(snakeKeyList)] has_data=\(nestedData != nil) has_session=\(nestedSession != nil || nestedDataSession != nil)")
        }
#endif

        token = resolvedToken
        refreshToken = resolvedRefresh
        if let directUser = try container.decodeIfPresent(BackendUser.self, forKey: .user) {
            user = directUser
        } else if let dataUser = nestedData?.user {
            user = dataUser
        } else {
            // `user` is optional in BackendAuthSession to support refresh responses where
            // the server rotated the tokens but the profile DB lookup failed.  Login and
            // signup callers must check for nil and treat it as a failure.  The refresh
            // path (refreshTokenSession) only consumes .token and .refreshToken, so nil
            // is acceptable there.
            user = nil
        }
    }
}

struct BackendTokenRefreshResult: Decodable, Sendable {
    let token: String
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case token
        case accessToken
        case refreshToken
        case data
    }

    private enum SnakeCodingKeys: String, CodingKey {
        case access_token
        case refresh_token
    }

    private struct NestedData: Codable {
        let token: String?
        let accessToken: String?
        let refreshToken: String?
        let access_token: String?
        let refresh_token: String?
    }

    init(token: String, refreshToken: String?) {
        self.token = token
        self.refreshToken = refreshToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let snakeContainer = try decoder.container(keyedBy: SnakeCodingKeys.self)
        let nestedData = try container.decodeIfPresent(NestedData.self, forKey: .data)

        let tokenCandidates: [String?] = [
            try container.decodeIfPresent(String.self, forKey: .token),
            try container.decodeIfPresent(String.self, forKey: .accessToken),
            try snakeContainer.decodeIfPresent(String.self, forKey: .access_token),
            nestedData?.token,
            nestedData?.accessToken,
            nestedData?.access_token
        ]
        guard let resolvedToken = tokenCandidates
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            throw DecodingError.keyNotFound(
                CodingKeys.token,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Missing token in BackendTokenRefreshResult payload."
                )
            )
        }

        let refreshCandidates: [String?] = [
            try container.decodeIfPresent(String.self, forKey: .refreshToken),
            try snakeContainer.decodeIfPresent(String.self, forKey: .refresh_token),
            nestedData?.refreshToken,
            nestedData?.refresh_token
        ]
        let resolvedRefresh = refreshCandidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })

#if DEBUG
        if resolvedRefresh == nil {
            let keyList = container.allKeys.map(\.stringValue).sorted().joined(separator: ",")
            let snakeKeyList = snakeContainer.allKeys.map(\.stringValue).sorted().joined(separator: ",")
            print("[BackendTokenRefreshResult] Missing refresh token in refresh payload. keys=[\(keyList)] snake=[\(snakeKeyList)] has_data=\(nestedData != nil)")
        }
#endif

        token = resolvedToken
        refreshToken = resolvedRefresh
    }
}

struct BackendMessageResponse: Codable, Sendable {
    let message: String?
}

struct BackendFollowResponse: Codable, Sendable {
    let ok: Bool?
    let status: String?
    let requested: Bool?
    let following: Bool?
}

struct BackendAuthTokenDiagnostics: Sendable {
    let tokenPresent: Bool
    let refreshTokenPresent: Bool
    let tokenAlgorithm: String?
    let issuer: String?
    let subject: String?
    let expiresAt: Date?
    let projectHost: String?
    let issuerHostMatchesProject: Bool?
}

struct BackendAuthSessionMutationDiagnostics: Sendable, Equatable {
    var accessTokenSetCount: Int = 0
    var accessTokenClearCount: Int = 0
    var refreshTokenSetCount: Int = 0
    var refreshTokenClearCount: Int = 0
    var hardSessionClearCount: Int = 0
    var lastHardSessionClearSource: String = "Not run yet"
    var lastHardSessionClearAt: Date?
    var lastMutation: String = "Not run yet"
    var lastMutationAt: Date?
}

struct BackendAuthRefreshDiagnostics: Sendable, Equatable {
    var refreshAttemptCount: Int = 0
    var refreshSuccessCount: Int = 0
    var refreshFailureCount: Int = 0
    var lastRefreshFailureReason: String = "None"
    var lastRefreshFailureCode: String = "None"
    var lastRefreshFailureTerminal: Bool?
    var lastRefreshFailureSessionRevoked: Bool?
    var lastRefreshAttemptSource: String = "Not run yet"
    var lastRefreshTokenAgeMS: Int?
    var lastRefreshAttemptAt: Date?
    var lastRefreshSuccessAt: Date?
    var lastRefreshFailureAt: Date?
}

struct BackendRateLimitDiagnostics: Sendable, Equatable {
    var endpointPath: String = "Not available"
    var httpMethod: String = "Not available"
    var statusCode: Int?
    var retryAfter: String = "Not available"
    var limit: String = "Not available"
    var remaining: String = "Not available"
    var reset: String = "Not available"
    var requestID: String = "Not available"
    var errorCode: String = "Not available"
    var message: String = "Not available"
    var observedAt: Date?
}

struct BackendCreatePostResult: Sendable {
    let type: BackendPost.PostType
    let remoteAssetRef: String?
    let aspectRatio: Double?
    let assetProvider: String?
    let assetBucket: String?
    let assetObjectKey: String?
}

struct UploadTokenResponse: Decodable {
    let uploadURL: String
    let objectKey: String
    let bucket: String
    let provider: String
    let maxBytes: Int
    let expiresInSeconds: Int
    // No custom CodingKeys — Edge Function returns camelCase JSON that matches
    // these property names directly (uploadURL, objectKey, maxBytes, expiresInSeconds).
}

struct MediaUploadResult: Sendable {
    let legacyRef: String
    let provider: String?
    let bucket: String?
    let objectKey: String?
}

enum BackendRealtimeEvent: Sendable {
    case postsChanged(postID: UUID?, authorID: UUID?)
    case commentsChanged(postID: UUID?)
    case usersChanged(userID: UUID?)
    case followsChanged(followerID: UUID?, followeeID: UUID?)
    case notificationsChanged(userID: UUID?, objectID: UUID?)
    case rescrollsChanged(originalPostID: UUID?, userID: UUID?)
    case commentLikesChanged(commentID: UUID?, userID: UUID?)
    case circlesChanged(circleID: UUID?, createdByID: UUID?)
    case circleMembersChanged(circleID: UUID?, userID: UUID?)
    case circleMessagesChanged(circleID: UUID?, messageID: UUID?, userID: UUID?)
}

enum BackendClientError: LocalizedError {
    case invalidBaseURL
    case requestFailed
    case httpStatus(Int, String?)
    case decodingFailed
    case missingUploadedAssetReference

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid backend URL."
        case .requestFailed:
            return "Backend request failed."
        case .httpStatus(let code, let message):
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            return "Backend returned HTTP \(code)."
        case .decodingFailed:
            return "Failed to decode backend response."
        case .missingUploadedAssetReference:
            return "Upload completed without a backend asset reference."
        }
    }
}

struct BackendRefreshFailure: LocalizedError, Sendable {
    let statusCode: Int
    let message: String?
    let code: String?
    let terminal: Bool?
    let sessionRevoked: Bool?

    var errorDescription: String? {
        if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }
        if let code, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return code
        }
        return "Auth refresh failed with HTTP \(statusCode)."
    }
}

struct ScrollsBackendClient {
    private static let founderScopedSubjectIDs: Set<String> = [
        "cbc29d93-94c3-4cb8-9f22-cfc53d60c330",
        "283dbe7a-fc81-46ce-91c8-297f75bfd6d1",
        "cb6f0aa1-2a39-4ede-90b0-af5a63da5a5d",
    ]
    private static let realtimeInvalidationService = BackendRealtimeInvalidationService()
    private static let authRefreshLock = NSLock()
    private static var activeAuthRefreshTasksByRefreshToken: [String: (id: UUID, task: Task<BackendTokenRefreshResult, Error>)] = [:]
    private static let authTokenRecoveryFailureLock = NSLock()
    private static var lastAuthTokenRecoveryFailure: BackendClientError?
    private static let authSessionMutationLock = NSLock()
    private static var authSessionMutationDiagnostics = BackendAuthSessionMutationDiagnostics()
    private static let authRefreshDiagnosticsLock = NSLock()
    private static var authRefreshDiagnostics = BackendAuthRefreshDiagnostics()
    private static let rateLimitDiagnosticsLock = NSLock()
    private static var rateLimitDiagnostics = BackendRateLimitDiagnostics()
    private static let edgeTokenValidationLock = NSLock()
    private static var edgeTokenValidationCache: [String: (isUsable: Bool, observedAt: Date)] = [:]
    private static let apiSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpMaximumConnectionsPerHost = 10
        config.httpShouldUsePipelining = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    private static let mediaUploadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.httpMaximumConnectionsPerHost = 6
        config.httpShouldUsePipelining = true
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 360
        return URLSession(configuration: config)
    }()

    private enum Constants {
        static let baseURLKey = "scrolls.backend.baseURL"
        static let supabaseURLKey = "scrolls.supabase.url"
        static let supabaseAnonKeyKey = "scrolls.supabase.anonKey"
        static let useSupabaseFunctionsKey = "scrolls.supabase.useFunctions"
        static let infoSupabaseURLKey = "SCROLLS_SUPABASE_URL"
        static let infoSupabaseAnonKeyKey = "SCROLLS_SUPABASE_ANON_KEY"
        static let infoBackendBaseURLKey = "SCROLLS_BACKEND_BASE_URL"
        // Publishable key is safe client-side; keep as final fallback for fresh installs.
        static let defaultSupabaseURL = "https://xmtmjpjdxfsprubshsbu.supabase.co"
        static let defaultSupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtdG1qcGpkeGZzcHJ1YnNoc2J1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5NDAwNzIsImV4cCI6MjA4OTUxNjA3Mn0.ToUFGd5xYBEgmjyx8bbJEp7QL1lVnDVDZjNbnGsM74o"
        static let authTokenKey = "scrolls.backend.authToken"
        static let refreshTokenKey = "scrolls.backend.refreshToken"
        static let authTokenKeychainService = "com.scrolls.backend.auth.tokens"
        static let authTokenKeychainAccount = "authToken"
        static let refreshTokenKeychainAccount = "refreshToken"
        static let authDeviceIDKeychainAccount = "authDeviceID"
        static let supportedJWTAlgorithms: Set<String> = ["HS256", "RS256", "ES256"]
        static let edgeTokenValidationCacheTTL: TimeInterval = 300
        static let authValidationRateLimitFallbackSeconds: TimeInterval = 8
    }

    var isEnabled: Bool {
        baseURL != nil
    }

    private var baseURL: URL? {
        if let rawSupabaseURL = normalizedConfigString(UserDefaults.standard.string(forKey: Constants.supabaseURLKey)),
           !rawSupabaseURL.isEmpty {
            return URL(string: rawSupabaseURL)
        }
        if let bundledSupabaseURL = normalizedConfigString(bundledInfoString(Constants.infoSupabaseURLKey))
            ?? normalizedConfigString(Constants.defaultSupabaseURL),
           !bundledSupabaseURL.isEmpty {
            return URL(string: bundledSupabaseURL)
        }
        if let raw = normalizedConfigString(UserDefaults.standard.string(forKey: Constants.baseURLKey)),
           !raw.isEmpty {
            return URL(string: raw)
        }
        if let bundledBaseURL = normalizedConfigString(bundledInfoString(Constants.infoBackendBaseURLKey)),
           !bundledBaseURL.isEmpty {
            return URL(string: bundledBaseURL)
        }
        return nil
    }

    private var supabaseAnonKey: String? {
        let raw = normalizedConfigString(UserDefaults.standard.string(forKey: Constants.supabaseAnonKeyKey))
            ?? normalizedConfigString(bundledInfoString(Constants.infoSupabaseAnonKeyKey))
            ?? normalizedConfigString(Constants.defaultSupabaseAnonKey)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private var useSupabaseFunctions: Bool {
        // Bundled credentials are ground truth. A stale UserDefaults `false` written
        // by a prior base-URL build must not suppress Supabase functions when the
        // current bundle already ships valid credentials.
        let hasBundledSupabaseURL = (normalizedConfigString(bundledInfoString(Constants.infoSupabaseURLKey))
            ?? normalizedConfigString(Constants.defaultSupabaseURL))?.isEmpty == false
        let hasBundledAnonKey = (normalizedConfigString(bundledInfoString(Constants.infoSupabaseAnonKeyKey))
            ?? normalizedConfigString(Constants.defaultSupabaseAnonKey))?.isEmpty == false
        if hasBundledSupabaseURL && hasBundledAnonKey { return true }

        // No bundled credentials — respect whatever the explicit runtime config set.
        return UserDefaults.standard.bool(forKey: Constants.useSupabaseFunctionsKey)
    }

    private var authToken: String? {
        currentAuthToken()
    }

    private var refreshToken: String? {
        currentRefreshToken()
    }

    func configure(baseURL: String) {
        UserDefaults.standard.set(baseURL, forKey: Constants.baseURLKey)
        UserDefaults.standard.removeObject(forKey: Constants.supabaseURLKey)
        UserDefaults.standard.removeObject(forKey: Constants.supabaseAnonKeyKey)
        UserDefaults.standard.set(false, forKey: Constants.useSupabaseFunctionsKey)
    }

    func configureSupabase(url: String, anonKey: String) {
        UserDefaults.standard.set(url, forKey: Constants.supabaseURLKey)
        UserDefaults.standard.set(anonKey, forKey: Constants.supabaseAnonKeyKey)
        UserDefaults.standard.set(true, forKey: Constants.useSupabaseFunctionsKey)
    }

    func setAuthToken(_ token: String?, source: String = "setAuthToken") {
        migrateLegacyAuthStorageIfNeeded()
        let previousToken = normalizedJWT(loadAuthValueFromKeychain(account: Constants.authTokenKeychainAccount))
        let previousRefresh = normalizedAuthorizationCredential(loadAuthValueFromKeychain(account: Constants.refreshTokenKeychainAccount))
        let cleanedToken = normalizedJWT(token)
        ScrollsBackendClient.realtimeInvalidationService.updateAccessToken(cleanedToken)
        if let cleanedToken, !cleanedToken.isEmpty {
            storeAuthValueInKeychain(cleanedToken, account: Constants.authTokenKeychainAccount)
        } else {
            removeAuthValueFromKeychain(account: Constants.authTokenKeychainAccount)
        }
        Self.recordAuthSessionMutation(
            previousToken: previousToken,
            previousRefreshToken: previousRefresh,
            newToken: cleanedToken,
            newRefreshToken: previousRefresh,
            source: source
        )
        Self.clearEdgeTokenValidationCache()
        UserDefaults.standard.removeObject(forKey: Constants.authTokenKey)
    }

    func setAuthSession(token: String?, refreshToken: String?, source: String = "setAuthSession") {
        migrateLegacyAuthStorageIfNeeded()
        // SYNC DOUBLE-READ for transient keychain misses.  iOS keychain reads
        // can return nil for a value that's actually present when another
        // thread just released a SecItem write lock — common during heavy
        // session activity (refresh rotation, account switch, login).  If we
        // observe nil here when there's actually a valid value on disk, the
        // sticky-preserve logic below can't help (it falls back to
        // `previousRefresh`, which is what we're reading right now), and the
        // caller's `refreshToken: nil` would slip through as a real wipe.
        //
        // A back-to-back second read catches essentially all transient
        // misses (the lock release window is microseconds).  No sleep
        // needed — even if the first read fails, the second read happens so
        // soon after that the lock has almost certainly cleared.  We only
        // do the second read when the first returned nil, so the steady-
        // state cost is zero.
        let previousToken = Self.keychainReadWithRetry { [self] in
            normalizedJWT(loadAuthValueFromKeychain(account: Constants.authTokenKeychainAccount))
        }
        let previousRefresh = Self.keychainReadWithRetry { [self] in
            normalizedAuthorizationCredential(loadAuthValueFromKeychain(account: Constants.refreshTokenKeychainAccount))
        }
        let cleanedToken = normalizedJWT(token)
        let cleanedRefreshToken = normalizedAuthorizationCredential(refreshToken)

        // STICKY REFRESH: a `nil`/empty refresh token argument is honored
        // only when it comes from an explicit user-driven path (Log Out,
        // Delete Account, etc.).  Automatic refresh-handling paths can
        // pass nil as a side-effect of error classification, and that's
        // what was wiping users overnight.  When the caller has a non-
        // explicit source AND a refresh token is already on file, we
        // preserve the existing refresh.  This ensures the user can
        // always recover via the existing refresh on next foreground —
        // worst case is one extra re-auth attempt, never silent logout.
        let isExplicitUserClear = Self.isExplicitUserAuthClearSource(source)
        let effectiveRefreshToken: String? = {
            if let cleanedRefreshToken, !cleanedRefreshToken.isEmpty {
                return cleanedRefreshToken
            }
            // Caller wants to clear refresh.  Only honor if explicit.
            if isExplicitUserClear {
                return nil
            }
            // Non-explicit clear attempt — keep whatever's on file.
            return previousRefresh
        }()
        let effectiveToken: String? = {
            if let cleanedToken, !cleanedToken.isEmpty {
                return cleanedToken
            }
            // Non-explicit automatic paths (401 recovery, stale-access drop,
            // transient refresh failure) must never turn "we saw an access
            // token a moment ago" into "both credentials are gone". That exact
            // state showed up in production as:
            // lastClear=resolvedAuthorizationToken.drop_stale_access,
            // token=no, refresh=no. If the refresh read is genuinely empty or
            // transiently missed, preserve the old access token and let the
            // next recovery pass make a better-informed decision instead of
            // creating an irreversible hard clear.
            if !isExplicitUserClear,
               effectiveRefreshToken?.isEmpty != false,
               let previousToken,
               !previousToken.isEmpty {
                return previousToken
            }
            return nil
        }()

        ScrollsBackendClient.realtimeInvalidationService.updateAccessToken(effectiveToken)
        if let effectiveToken, !effectiveToken.isEmpty {
            if effectiveToken != previousToken {
                storeAuthValueInKeychain(effectiveToken, account: Constants.authTokenKeychainAccount)
            }
        } else {
            // Only remove if there's actually something to remove.  Calling
            // SecItemDelete on an empty entry is a no-op but going through
            // the keychain syscall has shown up under load.
            if previousToken != nil {
                removeAuthValueFromKeychain(account: Constants.authTokenKeychainAccount)
            }
        }
        // Refresh-token write protection: when our sticky logic preserved
        // the existing value (effectiveRefreshToken == previousRefresh), we
        // MUST NOT re-write it.  `storeAuthValueInKeychain` does
        // SecItemDelete + SecItemAdd, which exposes a brief window where
        // concurrent readers see an empty keychain — and any reader that
        // observes nil mid-write can cascade into a "session dead" path
        // elsewhere in the app.  Skip the write whenever the value would
        // be unchanged.
        if let effectiveRefreshToken, !effectiveRefreshToken.isEmpty {
            if effectiveRefreshToken != previousRefresh {
                storeAuthValueInKeychain(effectiveRefreshToken, account: Constants.refreshTokenKeychainAccount)
            }
        } else {
            if previousRefresh != nil {
                removeAuthValueFromKeychain(account: Constants.refreshTokenKeychainAccount)
            }
        }
        Self.recordAuthSessionMutation(
            previousToken: previousToken,
            previousRefreshToken: previousRefresh,
            newToken: effectiveToken,
            newRefreshToken: effectiveRefreshToken,
            source: source
        )
        Self.clearEdgeTokenValidationCache()
        UserDefaults.standard.removeObject(forKey: Constants.authTokenKey)
        UserDefaults.standard.removeObject(forKey: Constants.refreshTokenKey)
    }

    /// Classifies a setAuthSession `source` string as an explicit
    /// user-initiated clear (which legitimately wipes the refresh token) vs
    /// an automatic flow (which must NOT silently strip the refresh).
    ///
    /// The list is conservative — anything not on this list is treated as
    /// automatic and the refresh is preserved.  This is the architectural
    /// guard that makes the session sticky against the long tail of
    /// "transient failure misclassified as terminal" bugs.
    private static func isExplicitUserAuthClearSource(_ source: String) -> Bool {
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return false }
        // Explicit user actions that should fully wipe the session:
        //   • Log Out button in profile menu
        //   • Delete-account flow
        //   • Adding a new account (which atomically replaces the old one)
        //   • Founder cluster repair (debug-button only)
        //   • Account-switch wipe between independent (non-cluster) accounts
        //   • Initial session install at login/sign-up
        let explicitFragments = [
            "logout",
            "log_out",
            "explicit_logout",
            "deletecurrentuseraccount",
            "delete_current_user_account",
            "beginaddaccountflow",
            "begin_add_account_flow",
            "repairsessionforcurrentaccount",
            "repair_session_for_current_account",
            "forcereauthentication",
            "force_reauthentication",
            "switchtoaccount",
            "switch_to_account",
            "session_install_after_login",
            "session_install_after_signup",
            "missing_refresh_abort",
        ]
        return explicitFragments.contains(where: { normalized.contains($0) })
    }

    func currentAuthSessionMutationDiagnostics() -> BackendAuthSessionMutationDiagnostics {
        Self.authSessionMutationLock.lock()
        defer { Self.authSessionMutationLock.unlock() }
        return Self.authSessionMutationDiagnostics
    }

    func currentAuthRefreshDiagnostics() -> BackendAuthRefreshDiagnostics {
        Self.authRefreshDiagnosticsLock.lock()
        defer { Self.authRefreshDiagnosticsLock.unlock() }
        return Self.authRefreshDiagnostics
    }

    func consumeLastAuthTokenRecoveryFailureForDebug() -> BackendClientError? {
        Self.consumeLastAuthTokenRecoveryFailure()
    }

    private func stableAuthDeviceID() -> String {
        if let stored = loadAuthValueFromKeychain(account: Constants.authDeviceIDKeychainAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        let created = UUID().uuidString.lowercased()
        storeAuthValueInKeychain(created, account: Constants.authDeviceIDKeychainAccount)
        return created
    }

    func currentRateLimitDiagnostics() -> BackendRateLimitDiagnostics {
        Self.rateLimitDiagnosticsLock.lock()
        defer { Self.rateLimitDiagnosticsLock.unlock() }
        return Self.rateLimitDiagnostics
    }

    func currentAuthToken() -> String? {
        migrateLegacyAuthStorageIfNeeded()
        let stored = loadAuthValueFromKeychain(account: Constants.authTokenKeychainAccount)
        let normalized = normalizedJWT(stored)
        if let normalized, normalized != stored {
            storeAuthValueInKeychain(normalized, account: Constants.authTokenKeychainAccount)
        }
        return normalized
    }

    func currentRefreshToken() -> String? {
        migrateLegacyAuthStorageIfNeeded()
        let stored = loadAuthValueFromKeychain(account: Constants.refreshTokenKeychainAccount)
        let normalized = normalizedAuthorizationCredential(stored)
        if let normalized, normalized != stored {
            storeAuthValueInKeychain(normalized, account: Constants.refreshTokenKeychainAccount)
        }
        return normalized
    }

    /// Reads the refresh token from keychain with one micro-retry on a nil result.
    /// iOS keychain reads can transiently fail (especially shortly after a write
    /// from another thread, or immediately after first-unlock).  When we are
    /// about to perform a destructive operation that depends on the *absence*
    /// of a refresh token, we MUST be confident the absence is real and not a
    /// transient race — otherwise we'd hard-wipe a still-valid session.
    ///
    /// Read pattern: read once, and if nil, await 50 ms and read again before
    /// declaring the keychain empty.  Returns the first non-nil value found.
    /// Uses `Task.sleep` so it yields the underlying thread instead of blocking.
    func currentRefreshTokenWithReadRetry() async -> String? {
        if let first = currentRefreshToken(), !first.isEmpty {
            return first
        }
        // 50 ms is short enough that callers don't notice; long enough that
        // an in-flight write from another thread typically completes.
        try? await Task.sleep(nanoseconds: 50_000_000)
        if let second = currentRefreshToken(), !second.isEmpty {
            return second
        }
        return nil
    }

    private func migrateLegacyAuthStorageIfNeeded() {
        let legacyToken = UserDefaults.standard.string(forKey: Constants.authTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyRefresh = UserDefaults.standard.string(forKey: Constants.refreshTokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasKeychainToken = loadAuthValueFromKeychain(account: Constants.authTokenKeychainAccount) != nil
        let hasKeychainRefresh = loadAuthValueFromKeychain(account: Constants.refreshTokenKeychainAccount) != nil
        if !hasKeychainToken, let legacyToken, !legacyToken.isEmpty {
            storeAuthValueInKeychain(legacyToken, account: Constants.authTokenKeychainAccount)
        }
        if !hasKeychainRefresh, let legacyRefresh, !legacyRefresh.isEmpty {
            storeAuthValueInKeychain(legacyRefresh, account: Constants.refreshTokenKeychainAccount)
        }
        UserDefaults.standard.removeObject(forKey: Constants.authTokenKey)
        UserDefaults.standard.removeObject(forKey: Constants.refreshTokenKey)
    }

    /// Runs a keychain-read closure, and if it returns nil/empty, immediately
    /// runs it again.  The second read is back-to-back (no sleep) because
    /// transient keychain misses are almost always caused by another thread
    /// holding a brief SecItemAdd/SecItemDelete lock that has already
    /// released by the time control returns to us.  This is the synchronous
    /// equivalent of the async `currentRefreshTokenWithReadRetry` — usable
    /// from non-async code paths like `setAuthSession` itself.
    ///
    /// Steady-state cost is zero (the second read only fires when the first
    /// returned nil), so this is safe to wrap around every keychain read in
    /// a hot path.
    private static func keychainReadWithRetry(_ read: () -> String?) -> String? {
        if let first = read(), !first.isEmpty {
            return first
        }
        return read()
    }

    private func loadAuthValueFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.authTokenKeychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func storeAuthValueInKeychain(_ value: String, account: String) {
        let data = Data(value.utf8)
        let service = Constants.authTokenKeychainService
        // kSecAttrAccessibleAfterFirstUnlock: readable after first device unlock (survives
        // lock/sleep and encrypted local backups). ThisDeviceOnly was previously used here but
        // prevented session tokens from being restored via encrypted backup/device migration,
        // forcing unnecessary re-logins whenever the user gets a new device.
        let accessibility = kSecAttrAccessibleAfterFirstUnlock
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Update in place first. Delete-then-add creates a brief empty-keychain
        // window; under refresh rotation a concurrent reader can observe that
        // gap and cascade into a false "session dead" hard clear. Existing
        // entries already use the desired accessibility class after prior
        // migrations; new entries below still get the explicit accessibility.
        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            // The update failed for some reason OTHER than "no entry exists".
            // Differentiate between two very different cases:
            //
            // 1. CORRUPTED ENTRY (e.g. wrong accessibility class from a legacy
            //    install, missing attributes, decode failure).  These are real
            //    errors that warrant a delete-then-add repair.  Identified by
            //    errSecDecode (-26275) or errSecParam (-50).
            //
            // 2. TRANSIENT WRITE-DENIAL (device locked before first unlock
            //    since reboot, auth context missing, allocation failure).
            //    Identified by errSecInteractionNotAllowed (-25308),
            //    errSecAuthFailed (-25293), errSecUserCanceled (-128),
            //    errSecAllocate (-108), and similar.  These are NOT corruption —
            //    the existing entry is fine, we just can't write to it right
            //    now.  Deleting in this case destroys a perfectly valid token
            //    and is the most likely cause of "auth broke overnight"
            //    reports: device locked → background refresh fires →
            //    SecItemUpdate fails with -25308 → old code wiped the entry →
            //    user wakes up logged out.
            //
            // The conservative fix: only perform the delete-then-add repair
            // for the small set of statuses that genuinely indicate
            // corruption.  Everything else: log and bail — the next
            // foreground write will retry from a known-good keychain state.
            let isCorruption = (updateStatus == errSecDecode || updateStatus == errSecParam)
            if !isCorruption {
                LocalAuthStore.appendAuthPersistenceDebug(
                    "keychain_update_failed_preserving_existing status=\(updateStatus) account=\(account)"
                )
                return
            }
            SecItemDelete(query as CFDictionary)
        }
        var create = query
        create[kSecValueData as String] = data
        create[kSecAttrAccessible as String] = accessibility
        let addStatus = SecItemAdd(create as CFDictionary, nil)
        if addStatus != errSecSuccess {
            // Surface add failures too so the diagnostics trail shows the
            // chain (update_failed → add_failed) when the keychain is
            // genuinely unavailable for the whole operation.
            LocalAuthStore.appendAuthPersistenceDebug(
                "keychain_add_failed status=\(addStatus) account=\(account)"
            )
        }
    }

    private func removeAuthValueFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.authTokenKeychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    func currentAuthTokenDiagnostics() -> BackendAuthTokenDiagnostics {
        let token = currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let refresh = currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let header = decodedJWTHeader(token)
        let tokenAlgorithm = normalizedJWTAlgorithm(header?["alg"] as? String)
        let payload = decodedJWTPayload(token)
        let issuer = payload?["iss"] as? String
        let subject = payload?["sub"] as? String
        let exp = payload?["exp"] as? TimeInterval
        let expiresAt = exp.map { Date(timeIntervalSince1970: $0) }
        let projectHost = baseURL?.host?.lowercased()
        let issuerHost: String? = {
            guard let issuer, let url = URL(string: issuer) else { return nil }
            return url.host?.lowercased()
        }()
        let hostMatches: Bool? = {
            guard let projectHost else { return nil }
            guard let issuerHost else { return nil }
            return issuerHost == projectHost
        }()
        return BackendAuthTokenDiagnostics(
            tokenPresent: !token.isEmpty,
            refreshTokenPresent: !refresh.isEmpty,
            tokenAlgorithm: tokenAlgorithm,
            issuer: issuer,
            subject: subject,
            expiresAt: expiresAt,
            projectHost: projectHost,
            issuerHostMatchesProject: hostMatches
        )
    }

    func currentAuthTokenPassesServerValidation() async -> Bool {
        let validated = await serverValidatedAuthorizationTokenForEdgeRequests()
        return validated != nil
    }

    func serverValidatedAuthorizationTokenForEdgeRequests(expectedSubjectUserID: UUID? = nil) async -> String? {
        // Validate and prune stale access tokens before edge requests so downstream
        // calls cannot accidentally reuse a JWT the gateway already rejects.
        func matchesExpectedSubject(_ token: String, expectedUserID: UUID?) -> Bool {
            guard let expectedUserID else { return true }
            let tokenSubject = decodedJWTPayload(token)?["sub"] as? String
            let normalizedSubject = tokenSubject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let normalizedExpected = expectedUserID.uuidString.lowercased()
            if normalizedSubject.lowercased() == normalizedExpected {
                return true
            }
            // Founder-managed accounts can legitimately issue alias subjects.
            if Self.founderScopedSubjectIDs.contains(normalizedSubject.lowercased())
                && Self.founderScopedSubjectIDs.contains(normalizedExpected) {
                return true
            }
            return false
        }

        var validatedToken: String?
        if let current = currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
           let token = normalizedJWT(current),
           !token.isEmpty {
            if let unsupportedAlgorithm = unsupportedJWTAlgorithm(from: token) {
                quarantineSessionForUnsupportedJWTAlgorithm(
                    algorithm: unsupportedAlgorithm,
                    source: "serverValidatedAuthorizationTokenForEdgeRequests.unsupported_algorithm"
                )
            } else if !isJWTExpiredOrNearExpiry(token),
               tokenIssuerMatchesConfiguredProject(token) {
                // In-memory tokens that are locally valid and issuer-scoped should
                // flow through immediately. Deep edge probing can stall writes.
                validatedToken = token
            } else {
                // We are about to clear the access token because it is expired
                // or untrusted.  Before we do that we MUST be sure we've read
                // the refresh token reliably — a transient keychain read miss
                // here would cause a hard wipe of both tokens and force a
                // logout.  See `currentRefreshTokenWithReadRetry()`.
                let preservedRefresh = await currentRefreshTokenWithReadRetry()?.trimmingCharacters(in: .whitespacesAndNewlines)
                setAuthSession(
                    token: nil,
                    refreshToken: (preservedRefresh?.isEmpty == false ? preservedRefresh : nil),
                    source: "serverValidatedAuthorizationTokenForEdgeRequests.invalid_or_expired"
                )
            }
        }

        if validatedToken == nil {
            validatedToken = await resolvedAuthorizationToken()
        }

        guard let token = validatedToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return nil
        }

        guard matchesExpectedSubject(token, expectedUserID: expectedSubjectUserID) else {
            Self.setLastAuthTokenRecoveryFailure(
                .httpStatus(401, "Token subject mismatch for active account.")
            )
            // Read with retry: the final setAuthSession() below uses
            // preservedRefresh as the refresh-to-keep, so a transient nil read
            // here would cause a hard wipe further down.
            let preservedRefresh = await currentRefreshTokenWithReadRetry()?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let refresh = preservedRefresh, !refresh.isEmpty {
                // A token-subject mismatch can happen after account switching or founder-managed
                // alias resolution drift. Prefer one refresh-driven reconciliation before we
                // discard the persisted access token entirely.
                setAuthSession(
                    token: nil,
                    refreshToken: refresh,
                    source: "serverValidatedAuthorizationTokenForEdgeRequests.subject_mismatch_refresh_retry"
                )
            }

            if let refreshed = await resolvedAuthorizationToken(forceRefresh: preservedRefresh?.isEmpty == false),
               matchesExpectedSubject(refreshed, expectedUserID: expectedSubjectUserID) {
                return refreshed
            }
            // Only clear the mismatched token after a refresh-based recovery attempt has failed.
            // Preserve refresh when it still looks attemptable so future heals can keep working.
            setAuthSession(
                token: nil,
                refreshToken: (preservedRefresh?.isEmpty == false ? preservedRefresh : nil),
                source: "serverValidatedAuthorizationTokenForEdgeRequests.subject_mismatch_unresolved"
            )
            return nil
        }

        return token
    }

    func setupRealtimeInvalidation(onEvent: @escaping (BackendRealtimeEvent) -> Void) {
        guard let anonKey = supabaseAnonKey,
              let websocketURL = realtimeWebSocketURL(anonKey: anonKey) else {
            return
        }
        let token = currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        ScrollsBackendClient.realtimeInvalidationService.start(
            websocketURL: websocketURL,
            accessToken: token,
            onEvent: onEvent
        )
    }

    func teardownRealtimeInvalidation() {
        ScrollsBackendClient.realtimeInvalidationService.stop()
    }

    func fetchFeed(
        userID: UUID? = nil,
        cursor: String? = nil,
        limit: Int = 20,
        allowAuthContextFallbackOnEmpty: Bool = false,
        allowAuthContextFallbackOnAuthFailure: Bool = false,
        includeAuthorization: Bool = true,
        timeoutInterval: TimeInterval = 12,
        authTokenOverride: String? = nil
    ) async throws -> BackendFeedPage {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let userID {
            queryItems.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        let shouldIncludeAuthorization = includeAuthorization && (overrideToken?.isEmpty != false)
        do {
            let page: BackendFeedPage = try await request(
                path: "/feed",
                method: "GET",
                queryItems: queryItems,
                body: Optional<Data>.none,
                includeAuthorization: shouldIncludeAuthorization,
                allowAuthRetry: shouldIncludeAuthorization,
                timeoutInterval: timeoutInterval,
                additionalHeaders: additionalHeaders
            )
            if allowAuthContextFallbackOnEmpty,
               page.posts.isEmpty,
               cursor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                let fallbackItems = [URLQueryItem(name: "limit", value: String(limit))]
                return try await request(
                    path: "/feed",
                    method: "GET",
                    queryItems: fallbackItems,
                    body: Optional<Data>.none,
                    includeAuthorization: shouldIncludeAuthorization,
                    allowAuthRetry: shouldIncludeAuthorization,
                    timeoutInterval: timeoutInterval,
                    additionalHeaders: additionalHeaders
                )
            }
            return page
        } catch BackendClientError.httpStatus(let code, _) where allowAuthContextFallbackOnAuthFailure && (code == 400 || code == 401 || code == 403) {
            var fallbackItems = [URLQueryItem(name: "limit", value: String(limit))]
            if let cursor, !cursor.isEmpty {
                fallbackItems.append(URLQueryItem(name: "cursor", value: cursor))
            }
            return try await request(
                path: "/feed",
                method: "GET",
                queryItems: fallbackItems,
                body: Optional<Data>.none,
                includeAuthorization: shouldIncludeAuthorization,
                allowAuthRetry: shouldIncludeAuthorization,
                timeoutInterval: timeoutInterval,
                additionalHeaders: additionalHeaders
            )
        }
    }

    func fetchFollowing(
        userID: UUID? = nil,
        allowAuthContextFallbackOnEmpty: Bool = false,
        includeAuthorization: Bool = true
    ) async throws -> [BackendUser] {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let users: [BackendUser] = try await request(
            path: "/me/following",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
        if allowAuthContextFallbackOnEmpty, userID != nil, users.isEmpty {
            return try await request(
                path: "/me/following",
                method: "GET",
                queryItems: [],
                body: Optional<Data>.none,
                includeAuthorization: includeAuthorization
            )
        }
        return users
    }

    func fetchFollowers(
        userID: UUID? = nil,
        allowAuthContextFallbackOnEmpty: Bool = false,
        includeAuthorization: Bool = true
    ) async throws -> [BackendUser] {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let users: [BackendUser] = try await request(
            path: "/me/followers",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
        if allowAuthContextFallbackOnEmpty, userID != nil, users.isEmpty {
            return try await request(
                path: "/me/followers",
                method: "GET",
                queryItems: [],
                body: Optional<Data>.none,
                includeAuthorization: includeAuthorization
            )
        }
        return users
    }

    func fetchFollowRequests(
        userID: UUID? = nil,
        includeAuthorization: Bool = true
    ) async throws -> [BackendUser] {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        return try await request(
            path: "/me/follow-requests",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func searchUsers(
        query: String,
        limit: Int = 40,
        includeAuthorization: Bool = true
    ) async throws -> [BackendUser] {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(
            path: "/search/users",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func searchCities(query: String, limit: Int = 40) async throws -> [String] {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(path: "/search/cities", method: "GET", queryItems: items)
    }

    func searchPublicCircles(
        query: String,
        limit: Int = 20,
        includeAuthorization: Bool = true
    ) async throws -> [BackendPublicCircleSearchResult] {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(
            path: "/search/circles",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func searchPosts(
        query: String,
        limit: Int = 20,
        includeAuthorization: Bool = true
    ) async throws -> BackendPostSearchPage {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(
            path: "/search/posts",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func fetchCityPosts(city: String, limit: Int = 60) async throws -> BackendFeedPage {
        let items = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(path: "/search/city-posts", method: "GET", queryItems: items)
    }

    func fetchPostsByAuthor(
        authorID: UUID,
        limit: Int = 50,
        cursor: String? = nil
    ) async throws -> BackendFeedPage {
        var items = [
            URLQueryItem(name: "author_id", value: authorID.uuidString.lowercased()),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await request(
            path: "/posts/by-author",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: true
        )
    }

    func fetchComments(
        postID: UUID,
        includeAuthorization: Bool = true,
        allowAuthRetry: Bool = true,
        authTokenOverride: String? = nil
    ) async throws -> [BackendComment] {
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await request(
            path: "/posts/\(postID.uuidString)/comments",
            method: "GET",
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization,
            allowAuthRetry: allowAuthRetry,
            authorizationTokenOverride: overrideToken
        )
    }

    func fetchNotifications(
        userID: UUID? = nil,
        allowAuthContextFallbackOnEmpty: Bool = false,
        limit: Int = 60,
        before: String? = nil
    ) async throws -> BackendNotificationsPage {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        items.append(URLQueryItem(name: "limit", value: String(max(1, min(limit, 200)))))
        if let before, !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(URLQueryItem(name: "before", value: before))
        }
        let page: BackendNotificationsPage = try await request(path: "/me/notifications", method: "GET", queryItems: items)
        if allowAuthContextFallbackOnEmpty, userID != nil, page.items.isEmpty {
            return try await request(path: "/me/notifications", method: "GET", queryItems: items.filter { $0.name != "user_id" })
        }
        return page
    }

    func registerDevicePushToken(
        token: String,
        userID: UUID? = nil,
        platform: String = "ios",
        environment: String,
        localeIdentifier: String? = nil,
        appVersion: String? = nil,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let token: String
            let platform: String
            let environment: String
            let localeIdentifier: String?
            let appVersion: String?

            enum CodingKeys: String, CodingKey {
                case token
                case platform
                case environment
                case localeIdentifier = "locale_identifier"
                case appVersion = "app_version"
            }
        }

        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/me/device-token",
            method: "POST",
            queryItems: items,
            body: Body(
                token: token,
                platform: platform,
                environment: environment,
                localeIdentifier: localeIdentifier,
                appVersion: appVersion
            ),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func unregisterDevicePushToken(
        token: String,
        userID: UUID? = nil,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let token: String
        }

        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/me/device-token",
            method: "DELETE",
            queryItems: items,
            body: Body(token: token),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func markAllNotificationsRead(userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/me/notifications/read-all",
            method: "POST",
            queryItems: items,
            body: EmptyBody(),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func setNotificationRead(
        notificationID: UUID,
        read: Bool,
        userID: UUID? = nil,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let id: UUID
            let is_read: Bool
        }
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/me/notifications/mark",
            method: "POST",
            queryItems: items,
            body: Body(id: notificationID, is_read: read),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func deleteReadNotifications(userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/me/notifications/read",
            method: "DELETE",
            queryItems: items,
            body: EmptyBody(),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func fetchCircles(
        userID: UUID? = nil,
        since: Date? = nil,
        includeAuthorization: Bool = true,
        allowAuthRetry: Bool = true,
        authTokenOverride: String? = nil
    ) async throws -> [BackendCircle] {
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        if let since {
            // Use millisecond-precision ISO 8601 to avoid rounding that could re-deliver
            // or drop messages at second boundaries.
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            items.append(URLQueryItem(name: "since", value: formatter.string(from: since)))
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await request(
            path: "/me/circles",
            method: "GET",
            queryItems: items,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization,
            allowAuthRetry: allowAuthRetry,
            authorizationTokenOverride: overrideToken
        )
    }

    func signUp(
        username: String,
        email: String,
        password: String,
        accountType: UserProfile.AccountType = .personal,
        isSubscriber: Bool = false,
        dateOfBirth: Date? = nil,
        parentalControls: UserProfile.ParentalControls
    ) async throws -> BackendAuthSession {
        struct Body: Codable {
            let username: String
            let email: String
            let password: String
            let accountType: String
            let isSubscriber: Bool
            let dateOfBirth: Date?
            let parentalControls: UserProfile.ParentalControls
        }
        return try await request(
            path: "/auth/signup",
            method: "POST",
            body: Body(
                username: username,
                email: email,
                password: password,
                accountType: accountType.rawValue,
                isSubscriber: isSubscriber,
                dateOfBirth: dateOfBirth,
                parentalControls: parentalControls
            ),
            includeAuthorization: false,
            includeAnonAuthorizationFallback: true
        )
    }

    func logIn(identifier: String, password: String) async throws -> BackendAuthSession {
        struct Body: Codable {
            let identifier: String
            let password: String
        }
        return try await request(
            path: "/auth/login",
            method: "POST",
            body: Body(identifier: identifier, password: password),
            includeAuthorization: false,
            includeAnonAuthorizationFallback: true
        )
    }

    func refreshAuthSession(
        refreshToken: String,
        timeoutInterval: TimeInterval = 8
    ) async throws -> BackendAuthSession {
        struct Body: Codable {
            let refreshToken: String
            let deviceID: String

            enum CodingKeys: String, CodingKey {
                case refreshToken
                case deviceID = "device_id"
            }
        }
        guard let url = resolvedURL(for: "/auth/refresh") else {
            throw BackendClientError.invalidBaseURL
        }
        let deviceID = stableAuthDeviceID()

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeoutInterval
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios.refreshAuthSession", forHTTPHeaderField: "x-scrolls-auth-refresh-source")
        req.setValue(deviceID, forHTTPHeaderField: "x-scrolls-device-id")
        if let anonKey = supabaseAnonKey {
            req.setValue(anonKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONEncoder.scrolls.encode(Body(refreshToken: refreshToken, deviceID: deviceID))

        let (data, response) = try await Self.apiSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.requestFailed
        }
        guard (200...299).contains(http.statusCode) else {
            let details = backendErrorDetails(from: data)
            throw BackendRefreshFailure(
                statusCode: http.statusCode,
                message: details.message,
                code: details.code,
                terminal: details.terminal,
                sessionRevoked: details.sessionRevoked
            )
        }
        guard let decoded = try? JSONDecoder.scrolls.decode(BackendAuthSession.self, from: data) else {
            throw BackendClientError.decodingFailed
        }
        return decoded
    }

    func requestPasswordReset(identifier: String, redirectTo: String? = nil) async throws -> String? {
        struct Body: Codable {
            let email: String
            let identifier: String
            let redirectTo: String?
        }
        let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: BackendMessageResponse = try await request(
            path: "/auth/password-reset",
            method: "POST",
            body: Body(
                email: normalizedIdentifier,
                identifier: normalizedIdentifier,
                redirectTo: redirectTo
            ),
            includeAuthorization: false,
            includeAnonAuthorizationFallback: true
        )
        return response.message
    }

    func updatePassword(
        newPassword: String,
        recoveryAccessToken: String
    ) async throws -> String? {
        struct Body: Codable {
            let password: String
        }
        let trimmedToken = recoveryAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: BackendMessageResponse = try await request(
            path: "/auth/update-password",
            method: "POST",
            body: Body(password: newPassword),
            includeAuthorization: false,
            includeAnonAuthorizationFallback: true,
            additionalHeaders: [
                "Authorization": "Bearer \(trimmedToken)"
            ],
            authorizationTokenOverride: trimmedToken
        )
        return response.message
    }

    func exchangeRecoveryTokenHash(
        _ tokenHash: String,
        type: String = "recovery"
    ) async throws -> String {
        struct Body: Codable {
            let type: String
            let token_hash: String
        }
        struct ResponseBody: Decodable {
            let access_token: String
        }

        guard useSupabaseFunctions, let baseURL, let anonKey = supabaseAnonKey else {
            throw BackendClientError.invalidBaseURL
        }
        guard let verifyURL = URL(string: "auth/v1/verify", relativeTo: baseURL) else {
            throw BackendClientError.invalidBaseURL
        }

        var req = URLRequest(url: verifyURL)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONEncoder.scrolls.encode(
            Body(type: type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "recovery" : type,
                 token_hash: tokenHash.trimmingCharacters(in: .whitespacesAndNewlines))
        )

        let (data, response) = try await Self.apiSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.requestFailed
        }
        guard (200...299).contains(http.statusCode) else {
            let message = backendErrorMessage(from: data) ?? "Recovery link is invalid or has expired."
            throw BackendClientError.httpStatus(http.statusCode, message)
        }
        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            throw BackendClientError.decodingFailed
        }
        let token = decoded.access_token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw BackendClientError.httpStatus(401, "Recovery link did not return a usable session.")
        }
        return token
    }

    func resendSignupEmail(email: String, redirectTo: String? = nil) async throws -> String? {
        struct Body: Codable {
            let email: String
            let redirectTo: String?
        }
        let response: BackendMessageResponse = try await request(
            path: "/auth/resend-signup",
            method: "POST",
            body: Body(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                redirectTo: redirectTo
            ),
            includeAuthorization: false,
            includeAnonAuthorizationFallback: true
        )
        return response.message
    }

    /// Public refresh entry point.  Wraps `performRefreshTokenSessionAttempt` with a
    /// short retry budget for the narrow class of errors where we can prove the
    /// refresh token was *never* submitted to any server (pre-flight URLErrors
    /// like DNS failure or "not connected to internet").
    ///
    /// Crucially, we DO NOT retry any error where the server may have processed
    /// the request — including timeouts, mid-flight connection drops, or HTTP
    /// status errors.  A second submission of an already-consumed refresh token
    /// triggers Supabase reuse-detection and revokes the entire session.
    ///
    /// Backoff schedule: 1 s, 4 s (3 attempts total).  Chosen to ride out
    /// momentary captive-portal / cell-handoff glitches without making the
    /// foreground heal feel sluggish.
    func refreshTokenSession(refreshToken: String) async throws -> BackendTokenRefreshResult {
        let backoffSchedule: [TimeInterval] = [1.0, 4.0]
        var lastError: Error?
        for attempt in 0...backoffSchedule.count {
            do {
                return try await performRefreshTokenSessionAttempt(refreshToken: refreshToken)
            } catch {
                lastError = error
                guard attempt < backoffSchedule.count,
                      Self.isPreFlightTransientRefreshError(error) else {
                    throw error
                }
                let delay = backoffSchedule[attempt]
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? BackendClientError.requestFailed
    }

    /// Strict classifier for "safe to retry with the same refresh token".
    /// Only URLError codes where we are *certain* the network layer never
    /// transmitted the request qualify.  Everything else — timeouts, dropped
    /// connections, HTTP status codes, decoding failures — must be treated as
    /// "token may already be consumed" and propagated immediately.
    private static func isPreFlightTransientRefreshError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        let safeRetryCodes: Set<URLError.Code> = [
            .notConnectedToInternet,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
        ]
        return safeRetryCodes.contains(urlError.code)
    }

    private func performRefreshTokenSessionAttempt(refreshToken: String) async throws -> BackendTokenRefreshResult {
        let refreshSource = "refreshTokenSession"
        let refreshAgeMS = refreshTokenAgeMilliseconds(refreshToken)
        Self.recordAuthRefreshAttemptStarted(source: refreshSource, refreshTokenAgeMS: refreshAgeMS)
        var refreshSucceeded = false
        var refreshFailureReason: String?
        var refreshFailureCode: String?
        var refreshFailureTerminal: Bool?
        var refreshFailureSessionRevoked: Bool?
        defer {
            if refreshSucceeded {
                Self.recordAuthRefreshAttemptSucceeded(source: refreshSource, refreshTokenAgeMS: refreshAgeMS)
            } else if let refreshFailureReason, !refreshFailureReason.isEmpty {
                Self.recordAuthRefreshAttemptFailed(
                    reason: refreshFailureReason,
                    code: refreshFailureCode,
                    terminal: refreshFailureTerminal,
                    sessionRevoked: refreshFailureSessionRevoked,
                    source: refreshSource,
                    refreshTokenAgeMS: refreshAgeMS
                )
            } else {
                Self.recordAuthRefreshAttemptFailed(
                    reason: "unknown_refresh_failure",
                    code: refreshFailureCode,
                    terminal: refreshFailureTerminal,
                    sessionRevoked: refreshFailureSessionRevoked,
                    source: refreshSource,
                    refreshTokenAgeMS: refreshAgeMS
                )
            }
        }

        do {
            // --- Primary endpoint: custom /auth/refresh ---
            // Use an explicit do/catch instead of `try?` so we can distinguish between
            // errors where the server *definitely did not process* the request (safe to
            // fall back to the direct Supabase endpoint) vs errors where the server *may
            // have already consumed* the refresh token (e.g. timeout, network lost
            // mid-flight).  Falling back with an already-consumed token triggers Supabase's
            // reuse-detection, which revokes the entire session and forces a full re-login.
            var primaryEndpointServerReachable = false  // true once we got any HTTP response
            do {
                let refreshed = try await refreshAuthSession(
                    refreshToken: refreshToken,
                    timeoutInterval: 15  // increased from 8s to survive Deno cold starts
                )
                // Server responded — from this point on the original refresh token
                // has been consumed by Supabase.  Do NOT fall through to the direct
                // Supabase endpoint with the old token regardless of what happens next.
                primaryEndpointServerReachable = true
                let refreshedFallback = refreshed.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
                let candidate = BackendTokenRefreshResult(
                    token: refreshed.token,
                    refreshToken: (refreshedFallback?.isEmpty == false ? refreshed.refreshToken : refreshToken)
                )
                if isTokenLocallyUsableForSession(candidate.token) {
                    let isUsable: Bool
                    if Self.isWithinRateLimitCooldown() {
                        isUsable = true
                    } else {
                        isUsable = await isRefreshedSessionTokenUsable(candidate.token)
                    }
                    if isUsable {
                        refreshSucceeded = true
                        return candidate
                    }
                    // Soft probe failure — the primary endpoint already handed us a locally
                    // valid access token.  Keep it instead of discarding a good session.
                    refreshSucceeded = true
                    return candidate
                }
                // Server responded but returned a locally-unusable access token.
                // The old refresh token is consumed; the new refresh token (if any) is in
                // candidate.  Persist it so we at least preserve the ability to recover,
                // then throw — do NOT fall through to the direct Supabase endpoint.
                let newRefresh = candidate.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let newRefresh, !newRefresh.isEmpty, newRefresh != refreshToken {
                    setAuthSession(
                        token: nil,
                        refreshToken: newRefresh,
                        source: "refreshTokenSession.primary_unusable_token_preserve_refresh"
                    )
                }
                refreshFailureReason = "primary_endpoint_returned_unusable_access_token"
                throw BackendClientError.httpStatus(401, "Primary refresh endpoint returned unusable access token.")
            } catch let urlError as URLError {
                // Classify network errors:
                //   • Cannot reach the server at all → safe to try the direct Supabase endpoint
                //     because the request never arrived; the refresh token is still intact.
                //   • Timeout or mid-flight network loss → the request *may* have been processed
                //     on the server; using the same token again would trigger reuse detection.
                let serverNotReached: Set<URLError.Code> = [
                    .notConnectedToInternet,
                    .cannotConnectToHost,
                    .cannotFindHost,
                    .dnsLookupFailed,
                ]
                if serverNotReached.contains(urlError.code) && !primaryEndpointServerReachable {
                    // Fall through to the direct Supabase endpoint below.
                } else {
                    // Timeout or connection loss mid-flight — the token may be consumed.
                    refreshFailureReason = "primary_endpoint_network_error_\(urlError.code.rawValue)"
                    throw urlError
                }
            } catch {
                if let failure = error as? BackendRefreshFailure {
                    refreshFailureCode = failure.code
                    refreshFailureTerminal = failure.terminal
                    refreshFailureSessionRevoked = failure.sessionRevoked
                    refreshFailureReason = "http_\(failure.statusCode)_\((failure.code ?? failure.errorDescription ?? "auth_refresh_failed").lowercased())"
                }
                if primaryEndpointServerReachable {
                    // Server was reached; token may be consumed.  Do not retry with same token.
                    throw error
                }
                // If we received any HTTP-level response (even 4xx/5xx), the server processed
                // the request.  Our custom /auth/refresh endpoint calls Supabase Auth
                // server-side *before* it can return any HTTP status, so the refresh token
                // may have been consumed before the error response was generated.
                // Never fall through to the direct Supabase endpoint with the same token —
                // doing so with an already-consumed token triggers Supabase's reuse-detection
                // and revokes the entire session.
                if let backendError = error as? BackendClientError,
                   case .httpStatus = backendError {
                    refreshFailureReason = "primary_endpoint_http_error_no_fallback"
                    throw backendError
                }
                if let refreshFailure = error as? BackendRefreshFailure {
                    refreshFailureReason = "primary_endpoint_http_error_no_fallback"
                    refreshFailureCode = refreshFailure.code
                    refreshFailureTerminal = refreshFailure.terminal
                    refreshFailureSessionRevoked = refreshFailure.sessionRevoked
                    throw refreshFailure
                }
                // True pre-flight errors (decoding, invalid URL, etc.) where no HTTP
                // response was received at all.  Fall through only when we are certain
                // the server never saw the request.
                let isDefinitiveTokenRejection: Bool = {
                    guard let backendError = error as? BackendClientError,
                          case let .httpStatus(code, _) = backendError,
                          code == 400 || code == 401 else { return false }
                    return true
                }()
                if !isDefinitiveTokenRejection {
                    // Uncertain whether the token was consumed.  Preserve it and throw.
                    refreshFailureReason = "primary_endpoint_uncertain_error"
                    throw error
                }
                // (Unreachable in practice — .httpStatus errors are caught above.
                //  Preserved as a safety net for any future non-HTTP 400/401 path.)
                // Fall through to the direct Supabase endpoint.
            }
            guard let baseURL else {
                refreshFailureReason = "invalid_base_url"
                throw BackendClientError.invalidBaseURL
            }
            guard let authURL = URL(string: "auth/v1/token?grant_type=refresh_token", relativeTo: baseURL) else {
                refreshFailureReason = "invalid_base_url"
                throw BackendClientError.invalidBaseURL
            }
            struct RequestBody: Codable {
                let refresh_token: String
            }
            struct ResponseBody: Decodable {
                let access_token: String
                let refresh_token: String?
            }
            var req = URLRequest(url: authURL)
            req.httpMethod = "POST"
            req.timeoutInterval = 8
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let anonKey = supabaseAnonKey {
                req.setValue(anonKey, forHTTPHeaderField: "apikey")
            }
            req.httpBody = try JSONEncoder.scrolls.encode(RequestBody(refresh_token: refreshToken))
            let (data, response) = try await Self.apiSession.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                refreshFailureReason = "request_failed_non_http_response"
                throw BackendClientError.requestFailed
            }
            guard (200...299).contains(http.statusCode) else {
                let backendMessage = backendErrorMessage(from: data) ?? "Auth refresh failed"
                refreshFailureReason = "http_\(http.statusCode)_\(backendMessage.lowercased())"
                throw BackendClientError.httpStatus(http.statusCode, backendMessage)
            }
            guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
                refreshFailureReason = "refresh_decoding_failed"
                throw BackendClientError.decodingFailed
            }
            let fallbackRefresh = decoded.refresh_token?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = BackendTokenRefreshResult(
                token: decoded.access_token,
                refreshToken: (fallbackRefresh?.isEmpty == false ? decoded.refresh_token : refreshToken)
            )
            let fallbackUsable: Bool
            if Self.isWithinRateLimitCooldown() {
                fallbackUsable = true
            } else {
                fallbackUsable = await isRefreshedSessionTokenUsable(fallback.token)
            }
            guard isTokenLocallyUsableForSession(fallback.token), fallbackUsable else {
                refreshFailureReason = "refresh_returned_unusable_access_token"
                throw BackendClientError.httpStatus(401, "Refresh returned unusable access token.")
            }
            refreshSucceeded = true
            return fallback
        } catch {
            if refreshFailureReason == nil {
                if let refreshFailure = error as? BackendRefreshFailure {
                    refreshFailureCode = refreshFailure.code
                    refreshFailureTerminal = refreshFailure.terminal
                    refreshFailureSessionRevoked = refreshFailure.sessionRevoked
                    let normalized = (refreshFailure.code ?? refreshFailure.errorDescription ?? "auth_refresh_failed")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    refreshFailureReason = "http_\(refreshFailure.statusCode)_\(normalized)"
                } else if let backend = error as? BackendClientError,
                   case let .httpStatus(code, message) = backend {
                    let normalized = (message ?? "auth_refresh_failed").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    refreshFailureReason = "http_\(code)_\(normalized)"
                } else {
                    refreshFailureReason = "\(error)"
                }
            }
            throw error
        }
    }

    func upsertProfile(_ profile: UserProfile, expectedWriteVersion: String? = nil) async throws -> BackendUser {
        struct Body: Codable {
            let id: UUID
            let username: String
            let displayName: String
            let bio: String
            let isPrivate: Bool
            let accountType: String
            let websiteURL: String?
            let venmoURL: String?
            let cashAppURL: String?
            let spotifyURL: String?
            let appleMusicURL: String?
            let businessLocation: String?
            let businessPhone: String?
            let homeCity: String?
            let dateOfBirth: Date?
            let ageAssuranceCompletedAt: Date?
            let parentalControls: UserProfile.ParentalControls
            let avatarProvider: String?
            let avatarBucket: String?
            let avatarObjectKey: String?
            let signatureRef: String?
            let avatarVideoRef: String?
            let expectedWriteVersion: String?
        }

        // R2 upload failure must not abort the profile save — fall back to preserving
        // existing structured fields (or letting the server keep whatever it already has).
        let avatarWrite: MediaUploadResult
        do {
            avatarWrite = try await resolveAvatarWriteForProfile(profile)
        } catch {
            avatarWrite = MediaUploadResult(legacyRef: "", provider: nil, bucket: nil, objectKey: nil)
        }

        let body = Body(
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName,
            bio: profile.bio,
            isPrivate: profile.isPrivateAccount,
            accountType: profile.accountType.rawValue,
            websiteURL: profile.websiteURL,
            venmoURL: profile.venmoURL,
            cashAppURL: profile.cashAppURL,
            spotifyURL: profile.spotifyURL,
            appleMusicURL: profile.appleMusicURL,
            businessLocation: profile.businessLocation,
            businessPhone: profile.businessPhone,
            homeCity: profile.homeCity,
            dateOfBirth: profile.dateOfBirth,
            ageAssuranceCompletedAt: profile.ageAssuranceCompletedAt,
            parentalControls: profile.parentalControls,
            avatarProvider: avatarWrite.provider,
            avatarBucket: avatarWrite.bucket,
            avatarObjectKey: avatarWrite.objectKey,
            signatureRef: profile.signatureRef,
            avatarVideoRef: profile.avatarVideoRef,
            expectedWriteVersion: expectedWriteVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return try await request(
            path: "/users/upsert",
            method: "POST",
            body: body,
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "user-upsert", identifier: profile.id.uuidString)]
        )
    }

    private func resolveAvatarWriteForProfile(_ profile: UserProfile) async throws -> MediaUploadResult {
        if let rawAvatarData = profile.avatarImageData, !rawAvatarData.isEmpty {
            return try await uploadProfileAvatarImageDataToR2(
                rawAvatarData,
                userID: profile.id
            )
        }

        if let provider = profile.avatarProvider,
           let bucket = profile.avatarBucket,
           let objectKey = profile.avatarObjectKey,
           !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !objectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return MediaUploadResult(legacyRef: "", provider: provider, bucket: bucket, objectKey: objectKey)
        }

        // Keep legacy-inline avatars untouched server-side when no structured ref exists yet.
        return MediaUploadResult(legacyRef: "", provider: nil, bucket: nil, objectKey: nil)
    }

    private func uploadProfileAvatarImageDataToR2(
        _ rawAvatarData: Data,
        userID: UUID
    ) async throws -> MediaUploadResult {
        guard useSupabaseFunctions else { throw BackendClientError.invalidBaseURL }
        guard let preparedAvatarData = preparedAvatarUploadJPEGData(from: rawAvatarData) else {
            throw BackendClientError.requestFailed
        }

        let tempObjectID = UUID().uuidString.lowercased()
        let objectKey = mediaObjectKey(
            ownerID: userID,
            kind: .avatarImage,
            fileName: "avatar-\(tempObjectID).jpg"
        )
        let token = try await requestUploadToken(contentType: "image/jpeg", objectKey: objectKey)
        guard let putURL = URL(string: token.uploadURL) else {
            throw BackendClientError.invalidBaseURL
        }
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scrolls-avatar-\(tempObjectID)")
            .appendingPathExtension("jpg")
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
        try preparedAvatarData.write(to: tempFileURL, options: .atomic)
        try await uploadFileToR2(
            presignedURL: putURL,
            fromFile: tempFileURL,
            contentType: "image/jpeg",
            timeoutInterval: 60
        )

        let legacyRef = "\(MediaURLResolver.r2CDNBase)/\(token.objectKey)"
        return MediaUploadResult(
            legacyRef: legacyRef,
            provider: token.provider,
            bucket: token.bucket,
            objectKey: token.objectKey
        )
    }


    func uploadProfileAvatarVideo(
        localURL: URL,
        userID: UUID,
        timeoutInterval: TimeInterval = 180
    ) async throws -> String? {
        do {
            let ext = localURL.pathExtension.isEmpty ? "mp4" : localURL.pathExtension.lowercased()
            let contentType = ext == "mov" ? "video/quicktime" : "video/mp4"
            let objectID = UUID().uuidString.lowercased()
            let objectKey = mediaObjectKey(
                ownerID: userID,
                kind: .avatarVideo,
                fileName: "avatar-\(objectID).\(ext)"
            )
            let result = try await uploadOwnedMediaFile(
                localURL: localURL,
                contentType: contentType,
                objectKey: objectKey,
                timeoutInterval: timeoutInterval
            )
            return result.legacyRef
        } catch {
            // Surface original error details to drive actionable upload errors in UI.
            throw error
        }
    }

    func fetchUser(id: UUID, includeAuthorization: Bool = true) async throws -> BackendUser {
        try await request(
            path: "/users/\(id.uuidString)",
            method: "GET",
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func fetchUsers(ids: [UUID], includeAuthorization: Bool = true) async throws -> [BackendUser] {
        let uniqueIDs = Array(Set(ids)).prefix(240)
        guard !uniqueIDs.isEmpty else { return [] }
        let chunkSize = 80
        var merged: [BackendUser] = []
        var seen = Set<UUID>()

        let idArray = Array(uniqueIDs)
        var index = 0
        while index < idArray.count {
            let end = min(index + chunkSize, idArray.count)
            let chunk = idArray[index..<end]
            let idsValue = chunk.map(\.uuidString).joined(separator: ",")
            let queryItems = [URLQueryItem(name: "ids", value: idsValue)]
            let users: [BackendUser] = try await request(
                path: "/users/batch",
                method: "GET",
                queryItems: queryItems,
                body: Optional<Data>.none,
                includeAuthorization: includeAuthorization
            )
            for user in users where seen.insert(user.id).inserted {
                merged.append(user)
            }
            index = end
        }
        return merged
    }

    func fetchUsersDirectory(
        cursor: String? = nil,
        limit: Int = 120,
        includeAuthorization: Bool = true
    ) async throws -> BackendUsersDirectoryPage {
        let resolvedLimit = max(1, min(limit, 200))
        var queryItems = [URLQueryItem(name: "limit", value: String(resolvedLimit))]
        if let cursor, !cursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await request(
            path: "/users/directory",
            method: "GET",
            queryItems: queryItems,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func fetchUsersDelta(
        sinceVersion: String? = nil,
        limit: Int = 200,
        includeAuthorization: Bool = true
    ) async throws -> BackendUsersDeltaPage {
        let resolvedLimit = max(1, min(limit, 400))
        var queryItems = [URLQueryItem(name: "limit", value: String(resolvedLimit))]
        let normalizedSince = sinceVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedSince.isEmpty {
            queryItems.append(URLQueryItem(name: "since_version", value: normalizedSince))
        }
        return try await request(
            path: "/users/delta",
            method: "GET",
            queryItems: queryItems,
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func fetchUserByUsername(_ username: String, includeAuthorization: Bool = true) async throws -> BackendUser {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        return try await request(
            path: "/users/by-username/\(encoded)",
            method: "GET",
            body: Optional<Data>.none,
            includeAuthorization: includeAuthorization
        )
    }

    func updateSubscriptionState(
        userID: UUID,
        isSubscriber: Bool,
        planID: String?,
        expiresAt: Date?,
        originalTransactionID: String?
    ) async throws {
        struct Body: Codable {
            let userID: UUID
            let isSubscriber: Bool
            let planID: String?
            let expiresAt: Date?
            let originalTransactionID: String?
        }
        _ = try await request(
            path: "/users/subscription",
            method: "PATCH",
            body: Body(
                userID: userID,
                isSubscriber: isSubscriber,
                planID: planID,
                expiresAt: expiresAt,
                originalTransactionID: originalTransactionID
            )
        ) as EmptyResponse
    }

    func updatePinnedPost(userID: UUID, postID: UUID?) async throws -> BackendUser {
        struct Body: Codable {
            let userID: UUID
            let postID: UUID?
        }
        return try await request(
            path: "/users/pinned-post",
            method: "PATCH",
            body: Body(userID: userID, postID: postID),
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "user-pinned-post", identifier: "\(userID.uuidString)-\(postID?.uuidString ?? "none")")]
        )
    }

    func setFollow(
        followerID: UUID,
        followeeID: UUID,
        isFollowing: Bool,
        authTokenOverride: String? = nil
    ) async throws -> BackendFollowResponse {
        struct Body: Codable {
            let followerID: UUID
            let followeeID: UUID
        }
        let path = isFollowing ? "/follows" : "/follows/delete"
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        if isFollowing {
            return try await request(
                path: path,
                method: "POST",
                body: Body(followerID: followerID, followeeID: followeeID),
                includeAuthorization: overrideToken?.isEmpty != false,
                allowAuthRetry: overrideToken?.isEmpty != false,
                additionalHeaders: additionalHeaders
            )
        }
        _ = try await request(
            path: path,
            method: "DELETE",
            body: Body(followerID: followerID, followeeID: followeeID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
        return BackendFollowResponse(ok: true, status: "deleted", requested: false, following: false)
    }

    func respondToFollowRequest(
        followerID: UUID,
        followeeID: UUID,
        accept: Bool,
        authTokenOverride: String? = nil
    ) async throws -> BackendFollowResponse {
        struct Body: Codable {
            let followerID: UUID
            let followeeID: UUID
            let accept: Bool
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        return try await request(
            path: "/follows/respond",
            method: "POST",
            body: Body(followerID: followerID, followeeID: followeeID, accept: accept),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        )
    }

    func deleteUserAsFounder(targetUserID: UUID) async throws {
        struct Body: Codable {
            let targetUserID: UUID
        }
        _ = try await request(
            path: "/users/delete",
            method: "DELETE",
            body: Body(targetUserID: targetUserID)
        ) as EmptyResponse
    }

    func deleteCurrentUserAccount() async throws {
        _ = try await request(
            path: "/users/me",
            method: "DELETE",
            body: EmptyBody()
        ) as EmptyResponse
    }

    func createPost(
        _ post: FeedPost,
        timeoutInterval: TimeInterval = 60,
        authorizationTokenOverride: String? = nil
    ) async throws -> BackendCreatePostResult {
        struct Body: Codable {
            let id: UUID
            let authorID: UUID
            let type: BackendPost.PostType
            let caption: String?
            let websiteURL: String?
            let locationCity: String?
            let textBody: String?
            let assetProvider: String?
            let assetBucket: String?
            let assetObjectKey: String?
            let coverProvider: String?
            let coverBucket: String?
            let coverObjectKey: String?
            let aspectRatio: Double?
            let createdAt: Date
            let user_id: UUID?
        }
        let descriptor = try await mediaDescriptor(
            from: post.mediaPreview,
            postID: post.id,
            authorID: post.user.id,
            timeoutInterval: timeoutInterval
        )
        let body = Body(
            id: post.id,
            authorID: post.user.id,
            type: descriptor.type,
            caption: post.caption,
            websiteURL: post.websiteURL,
            locationCity: post.locationCity,
            textBody: descriptor.textBody,
            assetProvider: descriptor.uploadResult?.provider,
            assetBucket: descriptor.uploadResult?.bucket,
            assetObjectKey: descriptor.uploadResult?.objectKey,
            coverProvider: post.coverProvider,
            coverBucket: post.coverBucket,
            coverObjectKey: post.coverObjectKey,
            aspectRatio: descriptor.aspectRatio,
            createdAt: post.timestamp,
            user_id: post.user.id
        )
        var confirmedRemoteAssetRef: String?
        if descriptor.type == .photo || descriptor.type == .video {
            guard let remoteURL = resolvedRemoteMediaURL(from: descriptor.assetRef) else {
                throw BackendClientError.missingUploadedAssetReference
            }
            confirmedRemoteAssetRef = remoteURL.absoluteString
            guard !(confirmedRemoteAssetRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
                throw BackendClientError.missingUploadedAssetReference
            }
        }
        _ = try await request(
            path: "/posts",
            method: "POST",
            body: body,
            includeAuthorization: true,
            allowAuthRetry: true,
            timeoutInterval: timeoutInterval,
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "post-create", identifier: post.id.uuidString)],
            authorizationTokenOverride: authorizationTokenOverride
        ) as EmptyResponse
        return BackendCreatePostResult(
            type: descriptor.type,
            remoteAssetRef: confirmedRemoteAssetRef,
            aspectRatio: descriptor.aspectRatio,
            assetProvider: descriptor.uploadResult?.provider,
            assetBucket: descriptor.uploadResult?.bucket,
            assetObjectKey: descriptor.uploadResult?.objectKey
        )
    }

    func uploadPostMediaAsset(
        postID: UUID,
        authorID: UUID,
        media: MediaPreview,
        timeoutInterval: TimeInterval = 120
    ) async throws -> BackendCreatePostResult {
        let descriptor = try await mediaDescriptor(
            from: media,
            postID: postID,
            authorID: authorID,
            timeoutInterval: timeoutInterval
        )
        var confirmedRemoteAssetRef: String?
        if descriptor.type == .photo || descriptor.type == .video {
            guard let remoteURL = resolvedRemoteMediaURL(from: descriptor.assetRef) else {
                throw BackendClientError.missingUploadedAssetReference
            }
            confirmedRemoteAssetRef = remoteURL.absoluteString
            guard !(confirmedRemoteAssetRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else {
                throw BackendClientError.missingUploadedAssetReference
            }
        }
        return BackendCreatePostResult(
            type: descriptor.type,
            remoteAssetRef: confirmedRemoteAssetRef,
            aspectRatio: descriptor.aspectRatio,
            assetProvider: descriptor.uploadResult?.provider,
            assetBucket: descriptor.uploadResult?.bucket,
            assetObjectKey: descriptor.uploadResult?.objectKey
        )
    }

    // MARK: – Block / Unblock

    func fetchBlockedUserIDs() async throws -> [UUID] {
        struct Response: Decodable {
            let blockedUserIDs: [String]
        }
        let result: Response = try await request(path: "/me/blocks", method: "GET")
        return result.blockedUserIDs.compactMap { UUID(uuidString: $0) }
    }

    func fetchDeletedPostIDs(postIDs: [UUID]) async throws -> [UUID] {
        struct Response: Decodable {
            let deletedPostIDs: [UUID]
        }
        let uniqueIDs = Array(Set(postIDs)).prefix(200)
        guard !uniqueIDs.isEmpty else { return [] }
        let query = uniqueIDs
            .map { $0.uuidString.lowercased() }
            .joined(separator: ",")
        let result: Response = try await request(
            path: "/me/tombstones",
            method: "GET",
            queryItems: [URLQueryItem(name: "post_ids", value: query)]
        )
        return result.deletedPostIDs
    }

    func blockUser(targetUserID: UUID) async throws {
        struct Body: Codable { let targetUserID: String }
        _ = try await request(
            path: "/me/block",
            method: "POST",
            body: Body(targetUserID: targetUserID.uuidString.lowercased())
        ) as EmptyResponse
    }

    func unblockUser(targetUserID: UUID) async throws {
        struct Body: Codable { let targetUserID: String }
        _ = try await request(
            path: "/me/block",
            method: "DELETE",
            body: Body(targetUserID: targetUserID.uuidString.lowercased())
        ) as EmptyResponse
    }

    /// Report a piece of UGC that isn't a top-level post.  Used for
    /// comments, music tracks, voice messages, circle messages, and
    /// avatar/profile media to satisfy Apple's "report on every UGC
    /// type" requirement.  Posts use `reportPost`; profiles use
    /// `reportProfile`; live streams use `reportLiveStream`.
    func reportContent(
        targetType: BackendContentReport.TargetType,
        targetID: UUID,
        targetOwnerID: UUID?,
        reason: BackendPostReport.Reason,
        notes: String? = nil
    ) async throws {
        struct Body: Codable {
            let targetType: String
            let targetID: String
            let targetOwnerID: String?
            let reason: String
            let notes: String?
        }
        _ = try await request(
            path: "/me/content-report",
            method: "POST",
            body: Body(
                targetType: targetType.rawValue,
                targetID: targetID.uuidString.lowercased(),
                targetOwnerID: targetOwnerID?.uuidString.lowercased(),
                reason: reason.rawValue,
                notes: notes
            )
        ) as EmptyResponse
    }

    func reportPost(postID: UUID, reason: BackendPostReport.Reason, notes: String? = nil) async throws {
        struct Body: Codable {
            let postID: UUID
            let reason: String
            let notes: String?
        }
        _ = try await request(
            path: "/posts/report",
            method: "POST",
            body: Body(postID: postID, reason: reason.rawValue, notes: notes)
        ) as EmptyResponse
    }

    func reportProfile(targetUserID: UUID, reason: BackendPostReport.Reason, notes: String? = nil) async throws {
        struct Body: Codable {
            let targetUserID: UUID
            let reason: String
            let notes: String?
        }
        _ = try await request(
            path: "/users/report",
            method: "POST",
            body: Body(targetUserID: targetUserID, reason: reason.rawValue, notes: notes)
        ) as EmptyResponse
    }

    func reportLiveStream(sessionID: UUID?, ownerUserID: UUID, reason: BackendPostReport.Reason, notes: String? = nil) async throws {
        struct Body: Codable {
            let session_id: UUID?
            let owner_user_id: UUID
            let reason: String
            let notes: String?
        }
        _ = try await request(
            path: "/live/session/report",
            method: "POST",
            body: Body(session_id: sessionID, owner_user_id: ownerUserID, reason: reason.rawValue, notes: notes)
        ) as EmptyResponse
    }

    func fetchPostReports(status: BackendPostReport.Status = .pending, limit: Int = 100) async throws -> [BackendPostReport] {
        let items = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        return try await request(path: "/posts/reports", method: "GET", queryItems: items)
    }

    func reviewPostReport(reportID: UUID, status: BackendPostReport.Status) async throws {
        struct Body: Codable {
            let status: String
        }
        _ = try await request(
            path: "/posts/\(reportID.uuidString)/review",
            method: "PATCH",
            body: Body(status: status.rawValue)
        ) as EmptyResponse
    }

    // MARK: Profile reports (founder/admin moderation queue)

    func fetchProfileReports(
        status: BackendPostReport.Status = .pending,
        limit: Int = 100
    ) async throws -> [BackendProfileReport] {
        let items = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        return try await request(path: "/users/profile-reports", method: "GET", queryItems: items)
    }

    func reviewProfileReport(reportID: UUID, status: BackendPostReport.Status) async throws {
        struct Body: Codable { let status: String }
        _ = try await request(
            path: "/users/profile-reports/\(reportID.uuidString)/review",
            method: "PATCH",
            body: Body(status: status.rawValue)
        ) as EmptyResponse
    }

    // MARK: Live-stream reports (founder/admin moderation queue)

    func fetchLiveStreamReports(
        status: BackendPostReport.Status = .pending,
        limit: Int = 100
    ) async throws -> [BackendLiveStreamReport] {
        let items = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        return try await request(path: "/live/session/reports", method: "GET", queryItems: items)
    }

    func reviewLiveStreamReport(reportID: UUID, status: BackendPostReport.Status) async throws {
        struct Body: Codable { let status: String }
        _ = try await request(
            path: "/live/session/reports/\(reportID.uuidString)",
            method: "PATCH",
            body: Body(status: status.rawValue)
        ) as EmptyResponse
    }

    // MARK: Content reports (comments / music / voice / circle / avatar)

    func fetchContentReports(
        status: BackendPostReport.Status = .pending,
        limit: Int = 100
    ) async throws -> [BackendContentReportRecord] {
        let items = [
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "limit",  value: String(limit)),
        ]
        return try await request(path: "/me/content-reports", method: "GET", queryItems: items)
    }

    func reviewContentReport(reportID: UUID, status: BackendPostReport.Status) async throws {
        struct Body: Codable { let status: String }
        _ = try await request(
            path: "/me/content-reports/\(reportID.uuidString)/review",
            method: "PATCH",
            body: Body(status: status.rawValue)
        ) as EmptyResponse
    }

    func deletePost(
        postID: UUID,
        authorID: UUID,
        assetProvider: String? = nil,
        assetBucket: String? = nil,
        assetObjectKey: String? = nil,
        coverProvider: String? = nil,
        coverBucket: String? = nil,
        coverObjectKey: String? = nil
    ) async throws {
        struct Body: Codable {
            let postID: UUID
            let authorID: UUID
            // Optional media/cover references — when present the backend should
            // delete the associated R2/Cloudflare objects during this request.
            let assetProvider: String?
            let assetBucket: String?
            let assetObjectKey: String?
            let coverProvider: String?
            let coverBucket: String?
            let coverObjectKey: String?
        }
        _ = try await request(
            path: "/posts/delete",
            method: "DELETE",
            body: Body(
                postID: postID,
                authorID: authorID,
                assetProvider: assetProvider,
                assetBucket: assetBucket,
                assetObjectKey: assetObjectKey,
                coverProvider: coverProvider,
                coverBucket: coverBucket,
                coverObjectKey: coverObjectKey
            ),
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "post-delete", identifier: postID.uuidString)]
        ) as EmptyResponse
    }

    func updatePostCaption(
        postID: UUID,
        authorID: UUID,
        caption: String?,
        locationCity: String?
    ) async throws {
        struct Body: Codable {
            let postID: UUID
            let authorID: UUID
            let caption: String?
            let locationCity: String?
        }
        _ = try await request(
            path: "/posts/caption",
            method: "PATCH",
            body: Body(postID: postID, authorID: authorID, caption: caption, locationCity: locationCity)
        ) as EmptyResponse
    }

    func updatePostMedia(
        postID: UUID,
        authorID: UUID,
        assetProvider: String,
        assetBucket: String,
        assetObjectKey: String,
        aspectRatio: Double?
    ) async throws {
        struct Body: Codable {
            let postID: UUID
            let authorID: UUID
            let assetProvider: String
            let assetBucket: String
            let assetObjectKey: String
            let aspectRatio: Double?
        }
        _ = try await request(
            path: "/posts/media",
            method: "PATCH",
            body: Body(
                postID: postID,
                authorID: authorID,
                assetProvider: assetProvider,
                assetBucket: assetBucket,
                assetObjectKey: assetObjectKey,
                aspectRatio: aspectRatio
            )
        ) as EmptyResponse
    }

    func updatePostCoverImageRef(
        postID: UUID,
        authorID: UUID,
        coverProvider: String,
        coverBucket: String,
        coverObjectKey: String
    ) async throws {
        struct Body: Codable {
            let postID: UUID
            let authorID: UUID
            let coverProvider: String
            let coverBucket: String
            let coverObjectKey: String
        }
        _ = try await request(
            path: "/posts/cover-image",
            method: "PATCH",
            body: Body(
                postID: postID,
                authorID: authorID,
                coverProvider: coverProvider,
                coverBucket: coverBucket,
                coverObjectKey: coverObjectKey
            )
        ) as EmptyResponse
    }


    func createComment(
        postID: UUID,
        authorID: UUID,
        body: String,
        parentCommentID: UUID? = nil,
        commentID: UUID? = nil,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let id: UUID
            let postID: UUID
            let authorID: UUID
            let body: String
            let parentCommentID: UUID?
        }
        let resolvedCommentID = commentID ?? UUID()
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let additionalHeaders: [String: String]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders = [
                "Authorization": "Bearer \(overrideToken)",
                "X-Idempotency-Key": idempotencyKey(scope: "comment-create", identifier: resolvedCommentID.uuidString)
            ]
        } else {
            additionalHeaders = [
                "X-Idempotency-Key": idempotencyKey(scope: "comment-create", identifier: resolvedCommentID.uuidString)
            ]
        }
        _ = try await request(
            path: "/comments",
            method: "POST",
            body: Body(
                id: resolvedCommentID,
                postID: postID,
                authorID: authorID,
                body: body,
                parentCommentID: parentCommentID
            ),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func deleteComment(
        commentID: UUID,
        authorID: UUID,
        requestedByID: UUID,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let commentID: UUID
            let authorID: UUID
            let requestedByID: UUID
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let additionalHeaders: [String: String]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders = [
                "Authorization": "Bearer \(overrideToken)",
                "X-Idempotency-Key": idempotencyKey(scope: "comment-delete", identifier: commentID.uuidString)
            ]
        } else {
            additionalHeaders = [
                "X-Idempotency-Key": idempotencyKey(scope: "comment-delete", identifier: commentID.uuidString)
            ]
        }
        _ = try await request(
            path: "/comments/delete",
            method: "DELETE",
            body: Body(commentID: commentID, authorID: authorID, requestedByID: requestedByID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func createCommentLike(
        commentID: UUID,
        userID: UUID,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let commentID: UUID
            let userID: UUID
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(
                scope: "comment-like-create",
                identifier: "\(userID.uuidString):\(commentID.uuidString)"
            )
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/comments/like",
            method: "POST",
            body: Body(commentID: commentID, userID: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func deleteCommentLike(
        commentID: UUID,
        userID: UUID,
        authTokenOverride: String? = nil
    ) async throws {
        struct Body: Codable {
            let commentID: UUID
            let userID: UUID
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(
                scope: "comment-like-delete",
                identifier: "\(userID.uuidString):\(commentID.uuidString)"
            )
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/comments/unlike",
            method: "POST",
            body: Body(commentID: commentID, userID: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func createRescroll(userID: UUID, originalPostID: UUID, quoteText: String? = nil, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let userID: UUID
            let originalPostID: UUID
            let quoteText: String?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "rescroll-create", identifier: "\(userID.uuidString):\(originalPostID.uuidString)")
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/rescrolls",
            method: "POST",
            body: Body(userID: userID, originalPostID: originalPostID, quoteText: quoteText),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func deleteRescroll(userID: UUID, rescrollPostID: UUID, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let userID: UUID
            let rescrollPostID: UUID
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "rescroll-delete", identifier: "\(userID.uuidString):\(rescrollPostID.uuidString)")
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/rescrolls/delete",
            method: "DELETE",
            body: Body(userID: userID, rescrollPostID: rescrollPostID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func upsertCircle(_ circle: CircleGroup) async throws {
        struct Body: Codable {
            struct Member: Codable {
                let id: UUID
                let userID: UUID
                let status: String
            }

            let id: UUID
            let name: String
            let avatarRef: String?
            let members: [Member]
            let createdAt: Date
            let user_id: UUID?
        }

        let members = circle.members.map { member in
            Body.Member(
                id: member.id,
                userID: member.profileID,
                status: member.status.rawValue
            )
        }
        let actingUserID: UUID? = circle.members.first(where: { $0.status == .member })?.profileID
            ?? circle.members.first?.profileID

        _ = try await request(
            path: "/circles/upsert",
            method: "POST",
            body: Body(
                id: circle.id,
                name: circle.name,
                avatarRef: encodedAvatarReference(from: circle.avatarImageData)
                    ?? circle.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines),
                members: members,
                createdAt: circle.createdAt,
                user_id: actingUserID
            ),
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "circle-upsert", identifier: circle.id.uuidString)]
        ) as EmptyResponse
    }

    func clearCircleMessages(circleID: UUID, userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let user_id: UUID?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "circle-clear", identifier: circleID.uuidString)
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/circles/clear",
            method: "POST",
            body: Body(circle_id: circleID, user_id: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func deleteCircle(circleID: UUID, userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let user_id: UUID?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "circle-delete", identifier: circleID.uuidString)
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/circles/delete",
            method: "DELETE",
            body: Body(circle_id: circleID, user_id: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func sendCircleMessage(circleID: UUID, message: CircleMessage, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let user_id: UUID
            let id: UUID
            let encrypted_text: String
            let created_at: Date
            let shared_post_id: UUID?
            let voice_provider: String?
            let voice_bucket: String?
            let voice_object_key: String?
            let voice_duration_seconds: Int?
            let photo_provider: String?
            let photo_bucket: String?
            let photo_object_key: String?
            let photo_content_type: String?
            let photo_width: Int?
            let photo_height: Int?
            let expires_at: Date?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "circle-message", identifier: message.id.uuidString)
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }

        _ = try await request(
            path: "/circles/message",
            method: "POST",
            body: Body(
                circle_id: circleID,
                user_id: message.userID,
                id: message.id,
                encrypted_text: message.encryptedText,
                created_at: message.timestamp,
                shared_post_id: message.sharedPostID,
                voice_provider: message.voiceProvider,
                voice_bucket: message.voiceBucket,
                voice_object_key: message.voiceObjectKey,
                voice_duration_seconds: message.voiceDurationSeconds,
                photo_provider: message.photoProvider,
                photo_bucket: message.photoBucket,
                photo_object_key: message.photoObjectKey,
                photo_content_type: message.photoContentType,
                photo_width: message.photoWidth,
                photo_height: message.photoHeight,
                expires_at: message.expiresAt
            ),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func markCircleVoiceMessageListened(circleID: UUID, messageID: UUID, userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let message_id: UUID
            let user_id: UUID?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "circle-voice-listened", identifier: messageID.uuidString)
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/circles/voice-listened",
            method: "POST",
            body: Body(circle_id: circleID, message_id: messageID, user_id: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func markCirclePhotoMessageViewed(circleID: UUID, messageID: UUID, userID: UUID? = nil, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let message_id: UUID
            let user_id: UUID?
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [
            "X-Idempotency-Key": idempotencyKey(scope: "circle-photo-viewed", identifier: messageID.uuidString)
        ]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/circles/photo-viewed",
            method: "POST",
            body: Body(circle_id: circleID, message_id: messageID, user_id: userID),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func updateTypingStatus(circleID: UUID, userID: UUID, isTyping: Bool, authTokenOverride: String? = nil) async throws {
        struct Body: Codable {
            let circle_id: UUID
            let user_id: UUID
            let is_typing: Bool
        }
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        _ = try await request(
            path: "/circles/typing",
            method: "POST",
            body: Body(circle_id: circleID, user_id: userID, is_typing: isTyping),
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            timeoutInterval: 8,
            additionalHeaders: additionalHeaders
        ) as EmptyResponse
    }

    func fetchTypingParticipants(circleID: UUID, userID: UUID, authTokenOverride: String? = nil) async throws -> [TypingParticipant] {
        let overrideToken = authTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        var additionalHeaders: [String: String] = [:]
        if let overrideToken, !overrideToken.isEmpty {
            additionalHeaders["Authorization"] = "Bearer \(overrideToken)"
        }
        let response: BackendTypingParticipantsResponse = try await request(
            path: "/circles/typing",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "circle_id", value: circleID.uuidString),
                URLQueryItem(name: "user_id", value: userID.uuidString)
            ],
            body: Optional<Data>.none,
            includeAuthorization: overrideToken?.isEmpty != false,
            allowAuthRetry: overrideToken?.isEmpty != false,
            timeoutInterval: 8,
            additionalHeaders: additionalHeaders
        )
        return response.items.map(\.typingParticipant)
    }

    func submitAdSubmission(
        postID: UUID,
        targetCity: String? = nil,
        campaignType: BackendAdSubmission.CampaignType? = nil,
        websiteURL: String? = nil,
        durationDays: Int? = nil,
        dailyBudgetCents: Int? = nil,
        totalBudgetCents: Int? = nil
    ) async throws -> BackendAdSubmission {
        struct Body: Codable {
            let postID: UUID
            let targetCity: String?
            let campaignType: String?
            let websiteURL: String?
            let durationDays: Int?
            let dailyBudgetCents: Int?
            let totalBudgetCents: Int?
        }
        return try await request(
            path: "/ads/submissions",
            method: "POST",
            body: Body(
                postID: postID,
                targetCity: targetCity,
                campaignType: campaignType?.rawValue,
                websiteURL: websiteURL,
                durationDays: durationDays,
                dailyBudgetCents: dailyBudgetCents,
                totalBudgetCents: totalBudgetCents
            ),
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "ad-submit", identifier: postID.uuidString)]
        )
    }

    func fetchAdSubmissions(
        status: String? = nil,
        city: String? = nil,
        businessUserID: UUID? = nil,
        minReportCount: Int? = nil,
        limit: Int = 120
    ) async throws -> [BackendAdSubmission] {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let status, !status.isEmpty {
            items.append(URLQueryItem(name: "status", value: status))
        }
        if let city, !city.isEmpty {
            items.append(URLQueryItem(name: "city", value: city))
        }
        if let businessUserID {
            items.append(URLQueryItem(name: "business_user_id", value: businessUserID.uuidString))
        }
        if let minReportCount, minReportCount > 0 {
            items.append(URLQueryItem(name: "min_report_count", value: String(minReportCount)))
        }
        return try await request(path: "/ads/submissions", method: "GET", queryItems: items)
    }

    func reviewAdSubmission(
        submissionID: UUID,
        status: String,
        reviewNotes: String?,
        startsAt: Date? = nil,
        endsAt: Date? = nil,
        dailyBudgetCents: Int? = nil,
        totalBudgetCents: Int? = nil
    ) async throws -> BackendAdSubmission {
        struct Body: Codable {
            let status: String
            let reviewNotes: String?
            let startsAt: Date?
            let endsAt: Date?
            let dailyBudgetCents: Int?
            let totalBudgetCents: Int?
        }
        return try await request(
            path: "/ads/\(submissionID.uuidString)/review",
            method: "PATCH",
            body: Body(
                status: status,
                reviewNotes: reviewNotes,
                startsAt: startsAt,
                endsAt: endsAt,
                dailyBudgetCents: dailyBudgetCents,
                totalBudgetCents: totalBudgetCents
            ),
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "ad-review", identifier: submissionID.uuidString)]
        )
    }

    func fetchAdDelivery(city: String?, limit: Int = 8) async throws -> [BackendAdDeliveryItem] {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let city, !city.isEmpty {
            items.append(URLQueryItem(name: "city", value: city))
        }
        return try await request(path: "/ads/delivery", method: "GET", queryItems: items)
    }

    func fetchAdReviewEvents(submissionID: UUID? = nil, limit: Int = 100) async throws -> [BackendAdReviewEvent] {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let submissionID {
            items.append(URLQueryItem(name: "submission_id", value: submissionID.uuidString))
        }
        return try await request(path: "/ads/events", method: "GET", queryItems: items)
    }

    func fetchCuratedAdSlots() async throws -> [UUID?] {
        struct CuratedSlot: Codable {
            let slotIndex: Int
            let postID: UUID?
        }
        let slots: [CuratedSlot] = try await request(path: "/ads/curated-slots", method: "GET")
        var results: [UUID?] = [nil, nil, nil]
        for slot in slots where slot.slotIndex >= 0 && slot.slotIndex < 3 {
            results[slot.slotIndex] = slot.postID
        }
        return results
    }

    func fetchMusicPlaylists(ownerID: UUID? = nil) async throws -> [BackendMusicPlaylist] {
        let queryItems = ownerID.map { [URLQueryItem(name: "user_id", value: $0.uuidString)] } ?? []
        let page: BackendMusicPlaylistPage = try await request(
            path: "/music-playlists",
            method: "GET",
            queryItems: queryItems
        )
        return page.playlists
    }

    func fetchMusicPlaylistDetail(playlistID: UUID) async throws -> BackendMusicPlaylistDetail {
        try await request(
            path: "/music-playlists/detail",
            method: "GET",
            queryItems: [URLQueryItem(name: "playlist_id", value: playlistID.uuidString)]
        )
    }

    func createMusicPlaylist(
        ownerID: UUID,
        title: String,
        visibility: String = "private",
        coverUploadResult: MediaUploadResult? = nil
    ) async throws -> BackendMusicPlaylist {
        struct Body: Encodable {
            let ownerID: UUID
            let title: String
            let visibility: String
            let coverRef: String?
            let coverProvider: String?
            let coverBucket: String?
            let coverObjectKey: String?
        }
        struct Response: Decodable {
            let playlist: BackendMusicPlaylist
        }
        let response: Response = try await request(
            path: "/music-playlists",
            method: "POST",
            body: Body(
                ownerID: ownerID,
                title: title,
                visibility: visibility,
                coverRef: coverUploadResult?.legacyRef,
                coverProvider: coverUploadResult?.provider,
                coverBucket: coverUploadResult?.bucket,
                coverObjectKey: coverUploadResult?.objectKey
            )
        )
        return response.playlist
    }

    func deleteMusicPlaylist(ownerID: UUID, playlistID: UUID) async throws {
        struct Body: Encodable {
            let ownerID: UUID
            let playlistID: UUID
        }
        _ = try await request(
            path: "/music-playlists",
            method: "DELETE",
            body: Body(ownerID: ownerID, playlistID: playlistID)
        ) as EmptyResponse
    }

    @discardableResult
    func addMusicTrackToPlaylist(
        playlistID: UUID,
        ownerID: UUID,
        sourcePostID: UUID,
        trackID: UUID,
        trackTitle: String,
        artistCreditsSnapshot: [MusicTrackArtistCredit]
    ) async throws -> BackendMusicPlaylistTrack {
        struct Body: Encodable {
            let playlistID: UUID
            let ownerID: UUID
            let sourcePostID: UUID
            let trackID: UUID
            let trackTitle: String
            let artistCreditsSnapshot: [MusicTrackArtistCredit]
        }
        struct Response: Decodable {
            let track: BackendMusicPlaylistTrack
        }
        let response: Response = try await request(
            path: "/music-playlists/tracks",
            method: "POST",
            body: Body(
                playlistID: playlistID,
                ownerID: ownerID,
                sourcePostID: sourcePostID,
                trackID: trackID,
                trackTitle: trackTitle,
                artistCreditsSnapshot: artistCreditsSnapshot
            )
        )
        return response.track
    }

    func updateCuratedAdSlots(postIDs: [UUID?]) async throws -> [UUID?] {
        struct SlotUpdate: Codable {
            let slotIndex: Int
            let postID: UUID?
        }
        struct Body: Codable {
            let slots: [SlotUpdate]
        }
        let slots = postIDs.enumerated().map { SlotUpdate(slotIndex: $0.offset, postID: $0.element) }
        let response: [SlotUpdate] = try await request(
            path: "/ads/curated-slots",
            method: "POST",
            body: Body(slots: slots),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "ad-curated-slots",
                    identifier: slots.map { "\($0.slotIndex):\($0.postID?.uuidString ?? "nil")" }.joined(separator: "|")
                )
            ]
        )
        var results: [UUID?] = [nil, nil, nil]
        for slot in response where slot.slotIndex >= 0 && slot.slotIndex < 3 {
            results[slot.slotIndex] = slot.postID
        }
        return results
    }

    func uploadSplashAdVideo(
        fileName: String,
        localURL: URL,
        headline: String? = nil,
        body: String? = nil,
        websiteURL: String? = nil,
        ctaLabel: String? = nil,
        timeoutInterval: TimeInterval = 300
    ) async throws -> BackendSplashAd {
        guard localURL.isFileURL, FileManager.default.fileExists(atPath: localURL.path) else {
            throw BackendClientError.requestFailed
        }

        // Step 1: Ask the edge function (service role) for a pre-signed upload URL.
        // This bypasses Storage RLS entirely — the signed URL is the auth credential.
        let fileExt = String(fileName.split(separator: ".").last ?? "mp4")
        struct SignedURLRequest: Encodable { let ext: String }
        struct SignedURLResponse: Decodable {
            let signedUrl: String
            let storagePath: String
            let publicURL: String
        }
        let signedResponse: SignedURLResponse = try await request(
            path: "/ads/splash/upload-url",
            method: "POST",
            body: SignedURLRequest(ext: fileExt),
            timeoutInterval: 30
        )
        let signedURL: URL
        if let absolute = URL(string: signedResponse.signedUrl), absolute.scheme != nil {
            signedURL = absolute
        } else if let projectBase = baseURL,
                  let combined = URL(string: signedResponse.signedUrl, relativeTo: projectBase)?.absoluteURL {
            signedURL = combined
        } else {
            throw BackendClientError.requestFailed
        }

        // Step 2: Upload the file directly to the signed URL — no Authorization header needed.
        let ext = localURL.pathExtension.lowercased()
        let contentType = ext == "mov" ? "video/quicktime" : "video/mp4"
        var uploadRequest = URLRequest(url: signedURL)
        uploadRequest.httpMethod = "PUT"
        uploadRequest.timeoutInterval = timeoutInterval
        uploadRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (uploadData, uploadResponse) = try await Self.mediaUploadSession.upload(for: uploadRequest, fromFile: localURL)
        guard let http = uploadResponse as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let statusCode = (uploadResponse as? HTTPURLResponse)?.statusCode ?? 0
            let message = backendErrorMessage(from: uploadData) ?? "Storage upload failed."
            throw BackendClientError.httpStatus(statusCode, message)
        }

        // Step 3: Tell the edge function to finalize config with the public URL.
        struct ConfigBody: Codable {
            let assetRef: String
            let headline: String?
            let body: String?
            let websiteURL: String?
            let ctaLabel: String?
        }
        let assetRef = signedResponse.publicURL
        return try await request(
            path: "/ads/splash/config",
            method: "POST",
            body: ConfigBody(
                assetRef: assetRef,
                headline: headline,
                body: body,
                websiteURL: websiteURL,
                ctaLabel: ctaLabel
            ),
            timeoutInterval: 30,
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(scope: "splash-config", identifier: assetRef)
            ]
        )
    }

    func fetchSplashAdVideo() async throws -> BackendSplashAd {
        try await request(path: "/ads/splash", method: "GET")
    }

    func deleteSplashAdVideo() async throws {
        _ = try await request(
            path: "/ads/splash",
            method: "DELETE",
            additionalHeaders: ["X-Idempotency-Key": idempotencyKey(scope: "splash-delete", identifier: "singleton")]
        ) as EmptyResponse
    }

    func fetchLiveStreamSession(userID: UUID? = nil) async throws -> BackendLiveStreamSession? {
        struct Response: Decodable {
            let session: BackendLiveStreamSession?
        }
        var items: [URLQueryItem] = []
        if let userID {
            items.append(URLQueryItem(name: "user_id", value: userID.uuidString))
        }
        let response: Response = try await request(path: "/live/session", method: "GET", queryItems: items)
        return response.session
    }


    func fetchViewerLiveStreamSession(ownerUserID: UUID) async throws -> BackendLiveStreamSession? {
        struct Response: Decodable {
            let session: BackendLiveStreamSession?
        }
        let response: Response = try await request(
            path: "/live/session/viewer",
            method: "GET",
            queryItems: [URLQueryItem(name: "owner_user_id", value: ownerUserID.uuidString)]
        )
        return response.session
    }

    /// Submits a password guess for a password-protected live stream to the
    /// backend for server-side verification.  Returns `true` when the password
    /// is correct.  Throws on network/server errors.
    func verifyLiveViewerPassword(ownerUserID: UUID, password: String) async throws -> Bool {
        struct Body: Encodable {
            let owner_user_id: String
            let password: String
        }
        struct Response: Decodable {
            let verified: Bool
        }
        let response: Response = try await request(
            path: "/live/session/verify-password",
            method: "POST",
            body: Body(owner_user_id: ownerUserID.uuidString, password: password)
        )
        return response.verified
    }

    func createLiveStreamSession(
        mode: BackendLiveStreamSession.Mode,
        title: String?,
        description: String?,
        tipGoal: Decimal? = nil,
        viewerPassword: String? = nil,
        userID: UUID? = nil
    ) async throws -> BackendLiveStreamSession {
        struct Body: Encodable {
            let mode: String
            let title: String?
            let description: String?
            let tip_goal: Decimal?
            let viewer_password: String?
            let user_id: UUID?
        }
        struct Response: Decodable {
            let session: BackendLiveStreamSession
        }

        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = viewerPassword?.trimmingCharacters(in: .whitespacesAndNewlines)
        let createIdempotencyID = UUID().uuidString
        let response: Response = try await request(
            path: "/live/session",
            method: "POST",
            body: Body(
                mode: mode.rawValue,
                title: normalizedTitle?.isEmpty == true ? nil : normalizedTitle,
                description: normalizedDescription?.isEmpty == true ? nil : normalizedDescription,
                tip_goal: (tipGoal ?? 0) > 0 ? tipGoal : nil,
                viewer_password: normalizedPassword?.isEmpty == true ? nil : normalizedPassword,
                user_id: userID
            ),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(scope: "live-session-create", identifier: createIdempotencyID)
            ]
        )
        return response.session
    }

    func sendLiveStreamHeartbeat(sessionID: UUID, userID: UUID? = nil) async throws -> BackendLiveStreamSession? {
        struct Body: Encodable {
            let session_id: UUID
            let user_id: UUID?
        }
        struct Response: Decodable {
            let ok: Bool?
            let session: BackendLiveStreamSession?
            let ended: Bool?
        }

        let response: Response = try await request(
            path: "/live/session/heartbeat",
            method: "POST",
            body: Body(session_id: sessionID, user_id: userID),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "live-session-heartbeat",
                    identifier: sessionID.uuidString
                )
            ]
        )
        return response.session
    }

    func endLiveStreamSession(sessionID: UUID? = nil, userID: UUID? = nil) async throws {
        struct Body: Encodable {
            let session_id: UUID?
            let user_id: UUID?
        }
        struct Response: Decodable {
            let ok: Bool?
        }
        _ = try await request(
            path: "/live/session/end",
            method: "POST",
            body: Body(session_id: sessionID, user_id: userID),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "live-session-end",
                    identifier: sessionID?.uuidString ?? userID?.uuidString ?? "active"
                )
            ]
        ) as Response
    }

    func rotateLiveStreamSessionKey(sessionID: UUID? = nil, userID: UUID? = nil) async throws -> BackendLiveStreamSession {
        struct Body: Encodable {
            let session_id: UUID?
            let user_id: UUID?
        }
        struct Response: Decodable {
            let session: BackendLiveStreamSession
        }
        let response: Response = try await request(
            path: "/live/session/rotate-key",
            method: "POST",
            body: Body(session_id: sessionID, user_id: userID),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "live-session-rotate",
                    identifier: sessionID?.uuidString ?? userID?.uuidString ?? "active"
                )
            ]
        )
        return response.session
    }

    func fetchLiveStreamComments(sessionID: UUID, limit: Int = 40) async throws -> [BackendLiveStreamComment] {
        struct Response: Decodable {
            let comments: [BackendLiveStreamComment]
        }
        let safeLimit = max(1, min(limit, 120))
        let response: Response = try await request(
            path: "/live/session/comments",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "session_id", value: sessionID.uuidString),
                URLQueryItem(name: "limit", value: String(safeLimit))
            ]
        )
        return response.comments
    }

    func createLiveStreamComment(
        sessionID: UUID,
        body: String,
        authorID: UUID? = nil,
        idempotencyID: UUID = UUID()
    ) async throws -> BackendLiveStreamComment {
        struct Body: Encodable {
            let id: UUID
            let session_id: UUID
            let body: String
            let user_id: UUID?
        }
        struct Response: Decodable {
            let comment: BackendLiveStreamComment
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BackendClientError.requestFailed
        }

        let response: Response = try await request(
            path: "/live/session/comments",
            method: "POST",
            body: Body(id: idempotencyID, session_id: sessionID, body: trimmed, user_id: authorID),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(scope: "live-comment", identifier: idempotencyID.uuidString.lowercased())
            ]
        )
        return response.comment
    }

    func resolvePendingLiveTip(
        sessionID: UUID,
        commentID: UUID,
        accepted: Bool,
        ownerUserID: UUID? = nil
    ) async throws -> BackendLiveStreamComment? {
        struct Body: Encodable {
            let session_id: UUID
            let comment_id: UUID
            let accepted: Bool
            let user_id: UUID?
        }
        struct Response: Decodable {
            let comment: BackendLiveStreamComment?
        }

        let response: Response = try await request(
            path: "/live/session/tips/resolve",
            method: "POST",
            body: Body(
                session_id: sessionID,
                comment_id: commentID,
                accepted: accepted,
                user_id: ownerUserID
            ),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "live-tip-resolve",
                    identifier: "\(commentID.uuidString.lowercased())-\(accepted)"
                )
            ]
        )
        return response.comment
    }


    func kickLiveStreamViewer(
        sessionID: UUID,
        targetUserID: UUID,
        ownerUserID: UUID? = nil,
        reason: String? = nil
    ) async throws {
        struct Body: Encodable {
            let session_id: UUID
            let target_user_id: UUID
            let user_id: UUID?
            let reason: String?
        }
        struct Response: Decodable {
            let ok: Bool?
        }

        let normalizedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await request(
            path: "/live/session/kick",
            method: "POST",
            body: Body(
                session_id: sessionID,
                target_user_id: targetUserID,
                user_id: ownerUserID,
                reason: (normalizedReason?.isEmpty == false ? normalizedReason : nil)
            ),
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(
                    scope: "live-session-kick",
                    identifier: "\(sessionID.uuidString.lowercased()):\(targetUserID.uuidString.lowercased())"
                )
            ]
        ) as Response
    }
    func requestUploadToken(contentType: String, objectKey: String) async throws -> UploadTokenResponse {
        struct Body: Encodable {
            // Edge Function reads payload.contentType and payload.objectKey (camelCase).
            let contentType: String
            let objectKey: String
        }
        return try await request(
            path: "/upload-token",
            method: "POST",
            body: Body(contentType: contentType, objectKey: objectKey)
        )
    }

    private func uploadFileToR2(
        presignedURL: URL,
        fromFile localURL: URL,
        contentType: String,
        timeoutInterval: TimeInterval
    ) async throws {
        #if canImport(UIKit)
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "scrolls-r2-upload") {
            UIApplication.shared.endBackgroundTask(bgTaskID)
            bgTaskID = .invalid
        }
        defer {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }
        #endif
        var req = URLRequest(url: presignedURL)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        // Must match CacheControl signed into the presigned URL — Cloudflare CDN
        // and device URLCache will then treat these objects as immutable for 1 year.
        req.setValue("public, max-age=31536000, immutable", forHTTPHeaderField: "Cache-Control")
        req.timeoutInterval = timeoutInterval
        let (_, response) = try await Self.mediaUploadSession.upload(for: req, fromFile: localURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendClientError.requestFailed
        }
    }

    func uploadArticleCoverImage(
        articleID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 18
    ) async throws -> MediaUploadResult {
        try await uploadMediaAsset(
            postID: articleID,
            authorID: authorID,
            type: .photo,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .postCover
        )
    }


    func uploadPodcastCoverImage(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        // Use a unique filename for cover re-edits so URL-based image caches
        // (device + CDN) are naturally busted after each successful save.
        let ext = localURL.pathExtension.isEmpty ? "jpg" : localURL.pathExtension
        let uniqueFileName = "cover-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .photo,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .podcastCover,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadMusicCoverImage(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "jpg" : localURL.pathExtension
        let uniqueFileName = "cover-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .photo,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .musicCover,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadMusicPlaylistCoverImage(
        playlistDraftID: UUID,
        ownerID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "jpg" : localURL.pathExtension
        let uniqueFileName = "cover-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: playlistDraftID,
            authorID: ownerID,
            type: .photo,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .musicPlaylistCover,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadPodcastLoopVideo(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "mp4" : localURL.pathExtension
        let uniqueFileName = "podcast-loop-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .video,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .podcastLoop,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadMusicLoopVideo(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "mp4" : localURL.pathExtension
        let uniqueFileName = "music-loop-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .video,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .musicLoop,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadMusicTrack(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        trackNumber: Int,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "m4a" : localURL.pathExtension
        let uniqueFileName = String(format: "track-%02d-%@.%@", trackNumber, UUID().uuidString, ext)
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .video,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .musicTrack,
            fileNameOverride: uniqueFileName
        )
    }

    /// Uploads an extra photo for a multi-photo carousel post.  Slides 2..N
    /// are uploaded via this method; the primary photo (slide 1) takes the
    /// regular postAsset path and is referenced by the post's asset_ref.
    /// Each carousel extra gets a unique filename so concurrent uploads
    /// don't collide and the CDN cache doesn't serve stale bytes.
    func uploadPostCarouselPhoto(
        postID: UUID,
        authorID: UUID,
        localURL: URL,
        slideNumber: Int,
        timeoutInterval: TimeInterval = 60
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "jpg" : localURL.pathExtension
        let uniqueFileName = String(format: "carousel-%02d-%@.%@", slideNumber, UUID().uuidString, ext)
        return try await uploadMediaAsset(
            postID: postID,
            authorID: authorID,
            type: .photo,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .postAsset,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadCircleVoiceMessage(
        messageID: UUID,
        authorID: UUID,
        localURL: URL,
        timeoutInterval: TimeInterval = 45
    ) async throws -> MediaUploadResult {
        let ext = localURL.pathExtension.isEmpty ? "m4a" : localURL.pathExtension.lowercased()
        let uniqueFileName = "voice-\(UUID().uuidString).\(ext)"
        return try await uploadMediaAsset(
            postID: messageID,
            authorID: authorID,
            type: .video,
            localURL: localURL,
            timeoutInterval: timeoutInterval,
            storagePathKind: .circleVoice,
            fileNameOverride: uniqueFileName
        )
    }

    func uploadCirclePhotoMessage(
        messageID: UUID,
        authorID: UUID,
        data: Data,
        timeoutInterval: TimeInterval = 45
    ) async throws -> MediaUploadResult {
        guard !data.isEmpty else {
            throw BackendClientError.requestFailed
        }
        let uniqueFileName = "photo-\(UUID().uuidString).jpg"
        let objectKey = mediaObjectKey(
            ownerID: authorID,
            kind: .circlePhoto,
            entityID: messageID,
            fileName: uniqueFileName
        )
        return try await uploadOwnedMediaData(
            data: data,
            contentType: "image/jpeg",
            objectKey: objectKey,
            timeoutInterval: timeoutInterval,
            cacheControl: "no-store, max-age=0"
        )
    }

    private func mediaDescriptor(
        from media: MediaPreview,
        postID: UUID,
        authorID: UUID,
        timeoutInterval: TimeInterval
    ) async throws -> (type: BackendPost.PostType, textBody: String?, assetRef: String?, aspectRatio: Double?, uploadResult: MediaUploadResult?) {
        switch media {
        case .text(let textPreview):
            return (.text, textPreview.text, nil, nil, nil)
        case .photo(let photo):
            let result = try await uploadMediaAsset(
                postID: postID,
                authorID: authorID,
                type: .photo,
                localURL: photo.fileURL,
                timeoutInterval: timeoutInterval
            )
            return (.photo, nil, result.legacyRef, Double(photo.aspectRatio), result)
        case .video(let video):
            let result = try await uploadMediaAsset(
                postID: postID,
                authorID: authorID,
                type: .video,
                localURL: video.url,
                timeoutInterval: timeoutInterval
            )
            return (.video, nil, result.legacyRef, Double(video.aspectRatio), result)
        }
    }

    private enum UploadMediaType: String, Codable {
        case photo
        case video
    }

    private enum MediaStoragePathKind {
        case postAsset
        case postCover
        case podcastCover
        case podcastLoop
        case musicCover
        case musicPlaylistCover
        case musicLoop
        case musicTrack
        case avatarImage
        case avatarVideo
        case momentAsset
        case circleVoice
        case circlePhoto
    }

    private struct UploadResult {
        let data: Data
        let statusCode: Int
    }

    private func uploadMediaAsset(
        postID: UUID,
        authorID: UUID,
        type: UploadMediaType,
        localURL: URL,
        timeoutInterval: TimeInterval,
        storagePathKind: MediaStoragePathKind = .postAsset,
        fileNameOverride: String? = nil
    ) async throws -> MediaUploadResult {
        guard localURL.isFileURL else {
            throw BackendClientError.requestFailed
        }
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw BackendClientError.requestFailed
        }
        let ext = localURL.pathExtension.isEmpty ? (type == .photo ? "jpg" : "mp4") : localURL.pathExtension
        let defaultFileName = "\(postID.uuidString).\(ext)"
        let trimmedOverride = fileNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = ((trimmedOverride?.isEmpty == false) ? trimmedOverride : nil) ?? defaultFileName

        // Determine content type for token request
        let fileExtension = ext.lowercased()
        let contentType: String
        switch type {
        case .photo:
            contentType = fileExtension == "png" ? "image/png" : "image/jpeg"
        case .video:
            contentType = (fileExtension == "mov") ? "video/quicktime"
                : (fileExtension == "aac" ? "audio/aac" : ((fileExtension == "m4a") ? "audio/mp4" : "video/mp4"))
        }

        guard useSupabaseFunctions else {
            throw BackendClientError.httpStatus(
                503,
                "Direct Supabase Storage uploads are disabled. Configure Supabase Functions so uploads can use R2 upload tokens."
            )
        }

        let objectKey = mediaObjectKey(
            ownerID: authorID,
            kind: storagePathKind,
            entityID: postID,
            fileName: fileName
        )
        return try await uploadOwnedMediaFile(
            localURL: localURL,
            contentType: contentType,
            objectKey: objectKey,
            timeoutInterval: timeoutInterval
        )
    }

    private func uploadOwnedMediaFile(
        localURL: URL,
        contentType: String,
        objectKey: String,
        timeoutInterval: TimeInterval
    ) async throws -> MediaUploadResult {
        let token = try await requestUploadToken(contentType: contentType, objectKey: objectKey)
        guard let putURL = URL(string: token.uploadURL) else {
            throw BackendClientError.invalidBaseURL
        }
        try await uploadFileToR2(
            presignedURL: putURL,
            fromFile: localURL,
            contentType: contentType,
            timeoutInterval: timeoutInterval
        )
        let legacyRef = "\(MediaURLResolver.r2CDNBase)/\(token.objectKey)"
        return MediaUploadResult(
            legacyRef: legacyRef,
            provider: token.provider,
            bucket: token.bucket,
            objectKey: token.objectKey
        )
    }

    private func uploadOwnedMediaData(
        data: Data,
        contentType: String,
        objectKey: String,
        timeoutInterval: TimeInterval,
        cacheControl: String
    ) async throws -> MediaUploadResult {
        let token = try await requestUploadToken(contentType: contentType, objectKey: objectKey)
        guard let putURL = URL(string: token.uploadURL) else {
            throw BackendClientError.invalidBaseURL
        }
        var request = URLRequest(url: putURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(cacheControl, forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = timeoutInterval
        let (_, response) = try await Self.mediaUploadSession.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendClientError.requestFailed
        }
        let legacyRef = "\(MediaURLResolver.r2CDNBase)/\(token.objectKey)"
        return MediaUploadResult(
            legacyRef: legacyRef,
            provider: token.provider,
            bucket: token.bucket,
            objectKey: token.objectKey
        )
    }

    private func mediaObjectKey(
        ownerID: UUID,
        kind: MediaStoragePathKind,
        entityID: UUID? = nil,
        fileName: String
    ) -> String {
        let owner = ownerID.uuidString.lowercased()
        let normalizedFileName = sanitizeMediaFileName(fileName)
        switch kind {
        case .postAsset:
            return "posts/\(owner)/\(requiredEntityID(entityID))/asset/\(normalizedFileName)"
        case .postCover:
            return "posts/\(owner)/\(requiredEntityID(entityID))/cover/\(normalizedFileName)"
        case .podcastCover:
            return "podcasts/\(owner)/\(requiredEntityID(entityID))/cover/\(normalizedFileName)"
        case .podcastLoop:
            return "podcasts/\(owner)/\(requiredEntityID(entityID))/loop/\(normalizedFileName)"
        case .musicCover:
            return "music/\(owner)/\(requiredEntityID(entityID))/cover/\(normalizedFileName)"
        case .musicPlaylistCover:
            return "music/\(owner)/playlists/\(requiredEntityID(entityID))/cover/\(normalizedFileName)"
        case .musicLoop:
            return "music/\(owner)/\(requiredEntityID(entityID))/loop/\(normalizedFileName)"
        case .musicTrack:
            return "music/\(owner)/\(requiredEntityID(entityID))/tracks/\(normalizedFileName)"
        case .avatarImage:
            return "avatars/\(owner)/image/\(normalizedFileName)"
        case .avatarVideo:
            return "avatars/\(owner)/video/\(normalizedFileName)"
        case .momentAsset:
            return "moments/\(owner)/\(requiredEntityID(entityID))/asset/\(normalizedFileName)"
        case .circleVoice:
            return "circles-audio/\(owner)/messages/\(requiredEntityID(entityID))/voice/\(normalizedFileName)"
        case .circlePhoto:
            return "circles-photos/\(owner)/messages/\(requiredEntityID(entityID))/photo/\(normalizedFileName)"
        }
    }

    private func requiredEntityID(_ entityID: UUID?) -> String {
        entityID?.uuidString.lowercased() ?? UUID().uuidString.lowercased()
    }

    private func sanitizeMediaFileName(_ fileName: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UUID().uuidString.lowercased() }
        let cleaned = trimmed
            .replacingOccurrences(of: "\\", with: "/")
            .components(separatedBy: "/")
            .last ?? trimmed
        let normalized = cleaned.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "-",
            options: .regularExpression
        )
        return normalized.isEmpty ? UUID().uuidString.lowercased() : normalized
    }

    private func idempotencyKey(scope: String, identifier: String) -> String {
        let raw = identifier
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9:-]", with: "-", options: .regularExpression)
        let compact = raw.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let key = "scrolls-\(scope)-\(compact)"
        if key.count <= 180 { return key }
        return String(key.prefix(180))
    }


    private func backendErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = payload["error"] as? String, !error.isEmpty {
                return error
            }
            if let message = payload["message"] as? String, !message.isEmpty {
                return message
            }
        }
        if let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return message
        }
        return nil
    }

    private struct BackendErrorDetails {
        let message: String?
        let code: String?
        let terminal: Bool?
        let sessionRevoked: Bool?
    }

    private func backendErrorDetails(from data: Data) -> BackendErrorDetails {
        guard !data.isEmpty,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return BackendErrorDetails(
                message: backendErrorMessage(from: data),
                code: nil,
                terminal: nil,
                sessionRevoked: nil
            )
        }
        let message: String? = {
            if let error = payload["error"] as? String, !error.isEmpty { return error }
            if let message = payload["message"] as? String, !message.isEmpty { return message }
            return nil
        }()
        let code = (payload["code"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let terminal = payload["terminal"] as? Bool
        let sessionRevoked = (payload["session_revoked"] as? Bool)
            ?? (payload["sessionRevoked"] as? Bool)
        return BackendErrorDetails(
            message: message,
            code: code?.isEmpty == false ? code : nil,
            terminal: terminal,
            sessionRevoked: sessionRevoked
        )
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body?,
        includeAuthorization: Bool = true,
        includeAnonAuthorizationFallback: Bool = false,
        allowAuthRetry: Bool = true,
        timeoutInterval: TimeInterval = 60,
        additionalHeaders: [String: String] = [:],
        authorizationTokenOverride: String? = nil
    ) async throws -> T {
        guard let resolvedURL = resolvedURL(for: path) else {
            throw BackendClientError.invalidBaseURL
        }
        guard var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
            throw BackendClientError.invalidBaseURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw BackendClientError.invalidBaseURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let anonKey = supabaseAnonKey {
            urlRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        if includeAuthorization {
            let overrideToken = normalizedJWT(authorizationTokenOverride)
            let token: String?
            if let overrideToken,
               !overrideToken.isEmpty,
               !isJWTExpiredOrNearExpiry(overrideToken),
               tokenIssuerMatchesConfiguredProject(overrideToken) {
                token = overrideToken
            } else {
                token = await resolvedAuthorizationToken()
            }
            guard let token, !token.isEmpty else {
                if let recoveryFailure = Self.consumeLastAuthTokenRecoveryFailure() {
                    throw recoveryFailure
                }
                throw BackendClientError.httpStatus(401, "Missing authorization header")
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if includeAnonAuthorizationFallback, useSupabaseFunctions, let anonKey = supabaseAnonKey {
            // Some Supabase Edge Functions require Authorization even for unauthenticated endpoints.
            urlRequest.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        for (header, value) in additionalHeaders where !value.isEmpty {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }
        if let body {
            urlRequest.httpBody = try JSONEncoder.scrolls.encode(body)
        }

        let (data, response) = try await Self.apiSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw BackendClientError.requestFailed }
        let responseHeaders = Self.normalizedHeaderMap(http.allHeaderFields)
        if Self.shouldRecordRateLimitDiagnostics(statusCode: http.statusCode, headers: responseHeaders) {
            Self.recordRateLimitDiagnostics(
                path: path,
                method: method,
                statusCode: http.statusCode,
                headers: responseHeaders,
                bodyData: data
            )
        }
        guard (200...299).contains(http.statusCode) else {
            let backendMessage: String? = {
                guard !data.isEmpty else { return nil }
                if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = payload["error"] as? String, !error.isEmpty {
                        return error
                    }
                    if let message = payload["message"] as? String, !message.isEmpty {
                        return message
                    }
                }
                if let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !text.isEmpty {
                    return text
                }
                return nil
            }()
            let responseRequestID = Self.headerValue(
                responseHeaders,
                candidates: ["x-request-id", "request-id", "cf-ray"]
            )
            let responseEdgeRegion = Self.headerValue(
                responseHeaders,
                candidates: ["x-sb-edge-region", "x-edge-region"]
            )
            let responseContextParts: [String] = [
                "route=\(method.uppercased()) \(path)",
                responseRequestID.map { requestID in "request_id=\(requestID)" },
                responseEdgeRegion.map { region in "edge_region=\(region)" }
            ].compactMap { $0 }
            let responseContext = responseContextParts.joined(separator: ", ")
            let surfacedBackendMessage: String? = {
                let trimmed = backendMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !responseContext.isEmpty else { return trimmed }
                if let trimmed, !trimmed.isEmpty {
                    return "\(trimmed) [\(responseContext)]"
                }
                return responseContext
            }()
            if http.statusCode == 429 {
                Self.recordRateLimitDiagnostics(
                    path: path,
                    method: method,
                    statusCode: http.statusCode,
                    headers: responseHeaders,
                    bodyData: data,
                    fallbackMessage: backendMessage
                )
            }
            let normalizedBackendMessage = (backendMessage ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let indicatesUnsupportedJWTAlgorithm = normalizedBackendMessage.contains("unsupported jwt algorithm")
            let indicatesInvalidJWT =
                normalizedBackendMessage.contains("invalid jwt") ||
                normalizedBackendMessage.contains("jwt malformed") ||
                normalizedBackendMessage.contains("jwt invalid")
            let indicatesMissingAuthorization =
                normalizedBackendMessage.contains("missing authorization")
            if includeAuthorization, indicatesUnsupportedJWTAlgorithm {
                let tokenAlgorithm = currentAuthTokenDiagnostics().tokenAlgorithm
                let label = tokenAlgorithm ?? "unknown"
                let reason = (surfacedBackendMessage ?? "Unsupported JWT algorithm \(label)")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                Self.setLastAuthTokenRecoveryFailure(
                    .httpStatus(http.statusCode, reason)
                )
                quarantineSessionForUnsupportedJWTAlgorithm(
                    algorithm: label,
                    source: "request.unsupported_jwt_algorithm"
                )
            }
            if http.statusCode == 401, includeAuthorization,
               indicatesInvalidJWT || indicatesMissingAuthorization {
                Self.setLastAuthTokenRecoveryFailure(
                    .httpStatus(http.statusCode, surfacedBackendMessage)
                )
                // Ensure we do not keep resending a stale/bad access token on the next request.
                // Preserve refresh token so the retry path can recover the session.
                // Read with retry: a transient keychain nil here would cause a
                // hard wipe of both tokens and force a logout.
                let preservedRefresh = await currentRefreshTokenWithReadRetry()?.trimmingCharacters(in: .whitespacesAndNewlines)
                setAuthSession(
                    token: nil,
                    refreshToken: (preservedRefresh?.isEmpty == false ? preservedRefresh : nil),
                    source: "request.401_invalid_or_missing_auth"
                )
            }
            if http.statusCode == 401, allowAuthRetry, includeAuthorization,
               !indicatesUnsupportedJWTAlgorithm,
               let recoveredToken = await resolvedAuthorizationToken(),
               !recoveredToken.isEmpty {
                return try await request(
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    body: body,
                    includeAuthorization: includeAuthorization,
                    allowAuthRetry: false,
                    timeoutInterval: timeoutInterval,
                    additionalHeaders: additionalHeaders,
                    authorizationTokenOverride: recoveredToken
                )
            }
            throw BackendClientError.httpStatus(http.statusCode, surfacedBackendMessage)
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        guard let decoded = try? JSONDecoder.scrolls.decode(T.self, from: data) else {
            throw BackendClientError.decodingFailed
        }
        return decoded
    }

    private func resolvedAuthorizationToken(forceRefresh: Bool = false) async -> String? {
        Self.setLastAuthTokenRecoveryFailure(nil)
        if !forceRefresh, let token = normalizedJWT(authToken), !token.isEmpty {
            let tokenUsable = !isJWTExpiredOrNearExpiry(token) && tokenIssuerMatchesConfiguredProject(token)
            if tokenUsable {
                return token
            }
            // Clear stale/untrusted access token but preserve refresh token so we can recover.
            //
            // Use the read-retry helper instead of the property accessor.  The
            // property does a single keychain read; if that read transiently
            // misses (which can happen shortly after another thread wrote to
            // the same keychain entry), we'd pass `refreshToken: nil` here.
            // The sticky-preserve logic in `setAuthSession` then falls back to
            // ITS OWN keychain read — which might also miss in the same window.
            // Result: hardClears telemetry increments and the user sees
            // `token=no, refresh=no` even when the keychain still holds a
            // valid refresh.  The retry helper eliminates this false-clear by
            // taking a second read after a 50 ms async sleep.
            let preservedRefresh = await currentRefreshTokenWithReadRetry()
            setAuthSession(
                token: nil,
                refreshToken: preservedRefresh,
                source: "resolvedAuthorizationToken.drop_stale_access"
            )
        }
        guard let refresh = refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !refresh.isEmpty else {
            return nil
        }
        guard isAttemptableRefreshCredential(refresh) else {
            let refreshLength = refresh.count
            Self.setLastAuthTokenRecoveryFailure(
                .httpStatus(401, "Invalid refresh token format (len=\(refreshLength)).")
            )
            // Short/truncated refresh tokens should not be retained for repeated retries.
            setAuthSession(
                token: nil,
                refreshToken: nil,
                source: "resolvedAuthorizationToken.refresh_not_attemptable"
            )
            return nil
        }
        let refreshTaskEntry = sharedAuthRefreshTask(refreshToken: refresh)
        defer { clearSharedAuthRefreshTaskIfNeeded(refreshTaskEntry.id, refreshToken: refresh) }
        let refreshed: BackendTokenRefreshResult
        do {
            refreshed = try await refreshTaskEntry.task.value
        } catch {
            if let refreshFailure = error as? BackendRefreshFailure {
                Self.setLastAuthTokenRecoveryFailure(
                    .httpStatus(refreshFailure.statusCode, refreshFailure.errorDescription)
                )
            } else if let backendError = error as? BackendClientError {
                Self.setLastAuthTokenRecoveryFailure(backendError)
            } else {
                Self.setLastAuthTokenRecoveryFailure(.requestFailed)
            }
            // For definitive "token is dead" errors from Supabase (already used, not found,
            // invalid grant), clear the stored refresh token so we stop retrying with a
            // credential that will never work. For transient failures (network, timeout,
            // server error), preserve the refresh token so we can retry later.
            let shouldClearRefresh = isTerminalRefreshTokenFailure(error)
            setAuthSession(
                token: nil,
                refreshToken: shouldClearRefresh ? nil : refresh,
                source: shouldClearRefresh
                    ? "resolvedAuthorizationToken.refresh_invalid_cleared"
                    : "resolvedAuthorizationToken.refresh_failed"
            )
            return nil
        }
        let refreshedRefresh = refreshed.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistedRefreshToken: String? = {
            if refreshedRefresh?.isEmpty == false {
                return refreshed.refreshToken
            }
            return refresh
        }()
        setAuthSession(
            token: refreshed.token,
            refreshToken: persistedRefreshToken,
            source: "resolvedAuthorizationToken.refresh_succeeded"
        )
        guard let normalizedRefreshed = normalizedJWT(refreshed.token),
              !isJWTExpiredOrNearExpiry(normalizedRefreshed),
              tokenIssuerMatchesConfiguredProject(normalizedRefreshed) else {
            if let unsupportedAlgorithm = unsupportedJWTAlgorithm(from: refreshed.token) {
                let message = "Refresh returned unsupported JWT algorithm \(unsupportedAlgorithm)."
                Self.setLastAuthTokenRecoveryFailure(.httpStatus(401, message))
                quarantineSessionForUnsupportedJWTAlgorithm(
                    algorithm: unsupportedAlgorithm,
                    source: "resolvedAuthorizationToken.refreshed_access_unsupported_alg"
                )
                return nil
            }
            // Do not retain a freshly refreshed token if it is still unusable.
            Self.setLastAuthTokenRecoveryFailure(
                .httpStatus(401, "Refresh returned unusable access token.")
            )
            setAuthSession(
                token: nil,
                refreshToken: persistedRefreshToken,
                source: "resolvedAuthorizationToken.refreshed_access_unusable"
            )
            return nil
        }
        Self.setLastAuthTokenRecoveryFailure(nil)
        return normalizedRefreshed
    }

    private func sharedAuthRefreshTask(refreshToken: String) -> (id: UUID, task: Task<BackendTokenRefreshResult, Error>) {
        ScrollsBackendClient.authRefreshLock.lock()
        defer { ScrollsBackendClient.authRefreshLock.unlock() }
        let key = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if let active = ScrollsBackendClient.activeAuthRefreshTasksByRefreshToken[key] {
            return active
        }
        let taskID = UUID()
        let task = Task { try await self.refreshTokenSession(refreshToken: refreshToken) }
        let entry = (id: taskID, task: task)
        ScrollsBackendClient.activeAuthRefreshTasksByRefreshToken[key] = entry
        return entry
    }

    private func clearSharedAuthRefreshTaskIfNeeded(_ id: UUID, refreshToken: String) {
        ScrollsBackendClient.authRefreshLock.lock()
        defer { ScrollsBackendClient.authRefreshLock.unlock() }
        let key = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if ScrollsBackendClient.activeAuthRefreshTasksByRefreshToken[key]?.id == id {
            ScrollsBackendClient.activeAuthRefreshTasksByRefreshToken.removeValue(forKey: key)
        }
    }

    private static func recordAuthSessionMutation(
        previousToken: String?,
        previousRefreshToken: String?,
        newToken: String?,
        newRefreshToken: String?,
        source: String
    ) {
        let hadToken = previousToken?.isEmpty == false
        let hasToken = newToken?.isEmpty == false
        let hadRefresh = previousRefreshToken?.isEmpty == false
        let hasRefresh = newRefreshToken?.isEmpty == false
        guard hadToken != hasToken || hadRefresh != hasRefresh else { return }

        authSessionMutationLock.lock()
        defer { authSessionMutationLock.unlock() }

        if !hadToken, hasToken {
            authSessionMutationDiagnostics.accessTokenSetCount += 1
        } else if hadToken, !hasToken {
            authSessionMutationDiagnostics.accessTokenClearCount += 1
        }
        if !hadRefresh, hasRefresh {
            authSessionMutationDiagnostics.refreshTokenSetCount += 1
        } else if hadRefresh, !hasRefresh {
            authSessionMutationDiagnostics.refreshTokenClearCount += 1
        }

        var parts: [String] = []
        if hadToken != hasToken {
            parts.append("access=\(hasToken ? "set" : "cleared")")
        }
        if hadRefresh != hasRefresh {
            parts.append("refresh=\(hasRefresh ? "set" : "cleared")")
        }
        parts.append("source=\(source)")
        authSessionMutationDiagnostics.lastMutation = parts.joined(separator: ", ")
        authSessionMutationDiagnostics.lastMutationAt = Date()

        let isHardClear = (hadToken || hadRefresh) && !hasToken && !hasRefresh
        if isHardClear {
            authSessionMutationDiagnostics.hardSessionClearCount += 1
            authSessionMutationDiagnostics.lastHardSessionClearSource = source
            authSessionMutationDiagnostics.lastHardSessionClearAt = Date()
        }

        // Persist a copy of every keychain mutation into the auth-persistence
        // trail.  The trail is the user-visible debug surface for "why did
        // my auth break overnight" — without this line, the trail only
        // captures LocalAuthStore writes (record upserts) and misses the
        // ACTUAL keychain mutations.  Format is parseable by humans reading
        // the debug panel: each event has the source string + transition.
        //
        // We log EVERY mutation that actually changed state, including the
        // hard-clear case which gets a `HARD_CLEAR` prefix so it stands
        // out at a glance.
        let prefix = isHardClear ? "auth_keychain_HARD_CLEAR" : "auth_keychain_change"
        let accessDescriptor: String
        if hadToken && hasToken {
            accessDescriptor = "access=kept"
        } else if !hadToken && hasToken {
            accessDescriptor = "access=set"
        } else if hadToken && !hasToken {
            accessDescriptor = "access=cleared"
        } else {
            accessDescriptor = "access=none"
        }
        let refreshDescriptor: String
        if hadRefresh && hasRefresh {
            refreshDescriptor = "refresh=kept"
        } else if !hadRefresh && hasRefresh {
            refreshDescriptor = "refresh=set"
        } else if hadRefresh && !hasRefresh {
            refreshDescriptor = "refresh=cleared"
        } else {
            refreshDescriptor = "refresh=none"
        }
        LocalAuthStore.appendAuthPersistenceDebug(
            "\(prefix) \(accessDescriptor), \(refreshDescriptor), source=\(source)"
        )
    }

    private static func recordAuthRefreshAttemptStarted(source: String, refreshTokenAgeMS: Int?) {
        authRefreshDiagnosticsLock.lock()
        defer { authRefreshDiagnosticsLock.unlock() }
        authRefreshDiagnostics.refreshAttemptCount += 1
        authRefreshDiagnostics.lastRefreshAttemptSource = source
        authRefreshDiagnostics.lastRefreshTokenAgeMS = refreshTokenAgeMS
        authRefreshDiagnostics.lastRefreshAttemptAt = Date()
    }

    private static func recordAuthRefreshAttemptSucceeded(source: String, refreshTokenAgeMS: Int?) {
        authRefreshDiagnosticsLock.lock()
        defer { authRefreshDiagnosticsLock.unlock() }
        authRefreshDiagnostics.refreshSuccessCount += 1
        authRefreshDiagnostics.lastRefreshAttemptSource = source
        authRefreshDiagnostics.lastRefreshTokenAgeMS = refreshTokenAgeMS
        authRefreshDiagnostics.lastRefreshSuccessAt = Date()
        LocalAuthStore.appendAuthPersistenceDebug(
            "auth_refresh_attempt outcome=success code=none age_of_refresh_ms=\(refreshTokenAgeMS.map(String.init) ?? "unknown") source=\(source)"
        )
    }

    private static func recordAuthRefreshAttemptFailed(
        reason: String,
        code: String? = nil,
        terminal: Bool? = nil,
        sessionRevoked: Bool? = nil,
        source: String,
        refreshTokenAgeMS: Int?
    ) {
        authRefreshDiagnosticsLock.lock()
        defer { authRefreshDiagnosticsLock.unlock() }
        authRefreshDiagnostics.refreshFailureCount += 1
        authRefreshDiagnostics.lastRefreshFailureReason = reason
        authRefreshDiagnostics.lastRefreshFailureCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? code! : "None"
        authRefreshDiagnostics.lastRefreshFailureTerminal = terminal
        authRefreshDiagnostics.lastRefreshFailureSessionRevoked = sessionRevoked
        authRefreshDiagnostics.lastRefreshAttemptSource = source
        authRefreshDiagnostics.lastRefreshTokenAgeMS = refreshTokenAgeMS
        authRefreshDiagnostics.lastRefreshFailureAt = Date()
        LocalAuthStore.appendAuthPersistenceDebug(
            "auth_refresh_attempt outcome=failure code=\(authRefreshDiagnostics.lastRefreshFailureCode) age_of_refresh_ms=\(refreshTokenAgeMS.map(String.init) ?? "unknown") source=\(source) terminal=\(terminal.map { $0 ? "yes" : "no" } ?? "unknown") session_revoked=\(sessionRevoked.map { $0 ? "yes" : "no" } ?? "unknown") reason=\(reason)"
        )
    }

    private static func normalizedHeaderMap(_ headers: [AnyHashable: Any]) -> [String: String] {
        var map: [String: String] = [:]
        for (rawKey, rawValue) in headers {
            let key = String(describing: rawKey).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            let value = String(describing: rawValue).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty { continue }
            if map[key] == nil {
                map[key] = value
            }
        }
        return map
    }

    private static func headerValue(_ headers: [String: String], candidates: [String]) -> String? {
        for candidate in candidates {
            if let value = headers[candidate.lowercased()], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func shouldRecordRateLimitDiagnostics(statusCode: Int, headers: [String: String]) -> Bool {
        if statusCode == 429 {
            return true
        }
        return headerValue(
            headers,
            candidates: [
                "retry-after",
                "x-ratelimit-limit",
                "ratelimit-limit",
                "x-ratelimit-remaining",
                "ratelimit-remaining",
                "x-ratelimit-reset",
                "ratelimit-reset"
            ]
        ) != nil
    }

    private static func parsedRateLimitErrorDetails(
        bodyData: Data,
        fallbackMessage: String?
    ) -> (errorCode: String?, message: String?) {
        if !bodyData.isEmpty,
           let payload = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            let errorCode = (payload["error_code"] as? String)
                ?? (payload["code"] as? String)
                ?? (payload["errorCode"] as? String)
            let message = (payload["msg"] as? String)
                ?? (payload["message"] as? String)
                ?? (payload["error"] as? String)
            if errorCode != nil || message != nil {
                return (errorCode, message)
            }
        }
        if let fallbackMessage,
           let data = fallbackMessage.data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorCode = (payload["error_code"] as? String)
                ?? (payload["code"] as? String)
                ?? (payload["errorCode"] as? String)
            let message = (payload["msg"] as? String)
                ?? (payload["message"] as? String)
                ?? (payload["error"] as? String)
            if errorCode != nil || message != nil {
                return (errorCode, message)
            }
        }
        return (nil, fallbackMessage)
    }

    private static func recordRateLimitDiagnostics(
        path: String,
        method: String,
        statusCode: Int,
        headers: [String: String],
        bodyData: Data,
        fallbackMessage: String? = nil
    ) {
        let details = parsedRateLimitErrorDetails(bodyData: bodyData, fallbackMessage: fallbackMessage)
        let retryAfter = headerValue(headers, candidates: ["retry-after"]) ?? "Not available"
        let limit = headerValue(headers, candidates: ["x-ratelimit-limit", "ratelimit-limit"]) ?? "Not available"
        let remaining = headerValue(headers, candidates: ["x-ratelimit-remaining", "ratelimit-remaining"]) ?? "Not available"
        let reset = headerValue(headers, candidates: ["x-ratelimit-reset", "ratelimit-reset"]) ?? "Not available"
        let requestID = headerValue(headers, candidates: ["x-request-id", "request-id", "cf-ray"]) ?? "Not available"
        let errorCode = details.errorCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = details.message?.trimmingCharacters(in: .whitespacesAndNewlines)

        rateLimitDiagnosticsLock.lock()
        defer { rateLimitDiagnosticsLock.unlock() }
        rateLimitDiagnostics.endpointPath = path
        rateLimitDiagnostics.httpMethod = method.uppercased()
        rateLimitDiagnostics.statusCode = statusCode
        rateLimitDiagnostics.retryAfter = retryAfter
        rateLimitDiagnostics.limit = limit
        rateLimitDiagnostics.remaining = remaining
        rateLimitDiagnostics.reset = reset
        rateLimitDiagnostics.requestID = requestID
        rateLimitDiagnostics.errorCode = (errorCode?.isEmpty == false ? errorCode! : "Not available")
        rateLimitDiagnostics.message = (message?.isEmpty == false ? message! : "Not available")
        rateLimitDiagnostics.observedAt = Date()
    }

    private static func parsedRetryAfterSeconds(_ rawValue: String?) -> TimeInterval? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let directSeconds = TimeInterval(trimmed), directSeconds > 0 {
            return directSeconds
        }
        // Retry-After can also be an HTTP-date.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        if let targetDate = formatter.date(from: trimmed) {
            return max(0, targetDate.timeIntervalSinceNow)
        }
        return nil
    }

    private static func isWithinRateLimitCooldown() -> Bool {
        rateLimitDiagnosticsLock.lock()
        let diagnostics = rateLimitDiagnostics
        rateLimitDiagnosticsLock.unlock()

        guard diagnostics.statusCode == 429 else { return false }
        guard let observedAt = diagnostics.observedAt else { return false }
        let retryAfter = parsedRetryAfterSeconds(diagnostics.retryAfter)
            ?? Constants.authValidationRateLimitFallbackSeconds
        let elapsed = Date().timeIntervalSince(observedAt)
        return elapsed < max(1, retryAfter)
    }

    private static func setLastAuthTokenRecoveryFailure(_ failure: BackendClientError?) {
        authTokenRecoveryFailureLock.lock()
        defer { authTokenRecoveryFailureLock.unlock() }
        lastAuthTokenRecoveryFailure = failure
    }

    private static func consumeLastAuthTokenRecoveryFailure() -> BackendClientError? {
        authTokenRecoveryFailureLock.lock()
        defer { authTokenRecoveryFailureLock.unlock() }
        let failure = lastAuthTokenRecoveryFailure
        lastAuthTokenRecoveryFailure = nil
        return failure
    }

    private func isTerminalRefreshFailure(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else { return false }
        guard case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        guard code == 400 || code == 401 || code == 403 else { return false }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if reason.isEmpty {
            return code == 401 || code == 403
        }
        let terminalSignals = [
            "invalid jwt",
            "jwt invalid",
            "jwt malformed",
            "refresh token",
            "invalid refresh",
            "invalid_grant",
            "invalid grant",
            "auth refresh failed",
            "unauthorized",
            "refresh returned unusable access token",
            "unsupported jwt algorithm"
        ]
        return terminalSignals.contains(where: { reason.contains($0) })
    }

    private func isTerminalRefreshTokenFailure(_ error: Error) -> Bool {
        if let refreshFailure = error as? BackendRefreshFailure {
            let normalizedCode = refreshFailure.code?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if [
                "refresh_token_expired",
                "refresh_token_reused",
                "refresh_token_unknown",
            ].contains(normalizedCode) {
                return true
            }
            if refreshFailure.terminal == true {
                return refreshFailure.statusCode == 400 || refreshFailure.statusCode == 401
            }
            return legacyMessageIndicatesTerminalRefreshFailure(
                statusCode: refreshFailure.statusCode,
                message: refreshFailure.message
            )
        }
        guard let backendError = error as? BackendClientError,
              case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        return legacyMessageIndicatesTerminalRefreshFailure(statusCode: code, message: message)
    }

    private func legacyMessageIndicatesTerminalRefreshFailure(statusCode: Int, message: String?) -> Bool {
        guard statusCode == 400 || statusCode == 401 else { return false }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !reason.isEmpty else { return false }
        return reason.contains("refresh_token_already_used")
            || reason.contains("invalid refresh token: already used")
            || reason.contains("refresh_token_not_found")
            || reason.contains("refresh token not found")
            || reason.contains("invalid_grant")
            || reason.contains("invalid grant")
            || reason.contains("refresh token has expired")
            || reason.contains("token has expired")
            || reason.contains("already used")
    }

    private func tokenIssuerMatchesConfiguredProject(_ token: String) -> Bool {
        if unsupportedJWTAlgorithm(from: token) != nil {
            return false
        }
        guard let payload = decodedJWTPayload(token),
              let issuer = payload["iss"] as? String,
              let issuerURL = URL(string: issuer),
              let issuerHost = issuerURL.host?.lowercased(),
              let projectHost = baseURL?.host?.lowercased() else {
            // If issuer metadata cannot be parsed locally, defer final JWT validation
            // to backend auth rather than rejecting token client-side.
            return true
        }
        return issuerHost == projectHost
    }

    private func isTokenLocallyUsableForSession(_ token: String?) -> Bool {
        guard let normalized = normalizedJWT(token), !normalized.isEmpty else { return false }
        guard !isJWTExpiredOrNearExpiry(normalized) else { return false }
        guard tokenIssuerMatchesConfiguredProject(normalized) else { return false }
        return true
    }

    private func isRefreshedSessionTokenUsable(_ token: String?) async -> Bool {
        guard let normalized = normalizedJWT(token), !normalized.isEmpty else { return false }
        guard !isJWTExpiredOrNearExpiry(normalized) else { return false }
        if let unsupportedAlgorithm = unsupportedJWTAlgorithm(from: normalized) {
            quarantineSessionForUnsupportedJWTAlgorithm(
                algorithm: unsupportedAlgorithm,
                source: "isRefreshedSessionTokenUsable.unsupported_algorithm"
            )
            return false
        }
        guard tokenIssuerMatchesConfiguredProject(normalized) else { return false }
        if Self.isWithinRateLimitCooldown() {
            // When we are actively rate-limited, avoid treating verification throttling
            // as token invalidity. Defer final acceptance to real API calls.
            return true
        }
        guard let baseURL, let anonKey = supabaseAnonKey else { return false }
        guard let userURL = URL(string: "auth/v1/user", relativeTo: baseURL) else { return false }
        var request = URLRequest(url: userURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(normalized)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await Self.apiSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            if http.statusCode == 429 {
                // 429 is transport/rate pressure, not definitive token invalidity.
                return true
            }
            guard (200...299).contains(http.statusCode) else { return false }
            return await isTokenAcceptedByEdgeGateway(normalized)
        } catch {
            // Network/transient failures during preflight should not force a synthetic
            // terminal auth failure. Let the actual protected request decide.
            return true
        }
    }

    private static func clearEdgeTokenValidationCache() {
        edgeTokenValidationLock.lock()
        defer { edgeTokenValidationLock.unlock() }
        edgeTokenValidationCache.removeAll(keepingCapacity: false)
    }

    private static func cachedEdgeTokenValidation(for token: String) -> Bool? {
        edgeTokenValidationLock.lock()
        defer { edgeTokenValidationLock.unlock() }
        let now = Date()
        edgeTokenValidationCache = edgeTokenValidationCache.filter {
            now.timeIntervalSince($0.value.observedAt) <= Constants.edgeTokenValidationCacheTTL
        }
        return edgeTokenValidationCache[token]?.isUsable
    }

    private static func storeEdgeTokenValidation(_ isUsable: Bool, for token: String) {
        edgeTokenValidationLock.lock()
        defer { edgeTokenValidationLock.unlock() }
        edgeTokenValidationCache[token] = (isUsable: isUsable, observedAt: Date())
    }

    private func isTokenAcceptedByEdgeGateway(_ token: String) async -> Bool {
        if let cached = Self.cachedEdgeTokenValidation(for: token) {
            return cached
        }
        guard let feedURL = resolvedURL(for: "/feed"),
              var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false) else {
            Self.storeEdgeTokenValidation(false, for: token)
            return false
        }
        components.queryItems = [URLQueryItem(name: "limit", value: "1")]
        guard let probeURL = components.url else {
            Self.storeEdgeTokenValidation(false, for: token)
            return false
        }
        var request = URLRequest(url: probeURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let anonKey = supabaseAnonKey {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await Self.apiSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                // Non-HTTP response is a transport anomaly — don't cache and let the real
                // protected request decide.
                return true
            }
            if (200...299).contains(http.statusCode) {
                Self.storeEdgeTokenValidation(true, for: token)
                return true
            }
            let message = backendErrorMessage(from: data)
            if messageIndicatesUnsupportedJWTAlgorithm(message) {
                quarantineSessionForUnsupportedJWTAlgorithm(
                    algorithm: normalizedJWTAlgorithm(decodedJWTHeader(token)?["alg"] as? String) ?? "unknown",
                    source: "isTokenAcceptedByEdgeGateway.unsupported_algorithm"
                )
                Self.setLastAuthTokenRecoveryFailure(.httpStatus(http.statusCode, message))
                Self.storeEdgeTokenValidation(false, for: token)
                return false
            }
            if http.statusCode == 429 {
                // Rate limiting should not cause token quarantine.
                Self.storeEdgeTokenValidation(true, for: token)
                return true
            }
            Self.storeEdgeTokenValidation(false, for: token)
            return false
        } catch {
            // Network/timeout failure during the edge probe — do not cache and treat as
            // acceptable. A 0.8s probe on a cold-starting edge function will frequently
            // time out even when the token is perfectly valid. The first real protected
            // request will surface a genuine 401 if the token is actually rejected.
            return true
        }
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        timeoutInterval: TimeInterval = 60,
        additionalHeaders: [String: String] = [:]
    ) async throws -> T {
        try await request(
            path: path,
            method: method,
            queryItems: queryItems,
            body: Optional<Data>.none,
            includeAuthorization: true,
            allowAuthRetry: true,
            timeoutInterval: timeoutInterval,
            additionalHeaders: additionalHeaders,
            authorizationTokenOverride: nil
        )
    }

    private func resolvedURL(for path: String) -> URL? {
        guard let baseURL else { return nil }
        let sanitized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        if useSupabaseFunctions {
            return baseURL
                .appendingPathComponent("functions")
                .appendingPathComponent("v1")
                .appendingPathComponent(sanitized)
        }
        return baseURL.appendingPathComponent(sanitized)
    }

    private func realtimeWebSocketURL(anonKey: String) -> URL? {
        guard let baseURL else { return nil }
        var components = URLComponents()
        components.scheme = (baseURL.scheme?.lowercased() == "https") ? "wss" : "ws"
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = "/realtime/v1/websocket"
        components.queryItems = [
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        return components.url
    }

    private func normalizedJWT(_ token: String?) -> String? {
        let trimmed = normalizedAuthorizationCredential(token) ?? ""
        guard !trimmed.isEmpty else { return nil }
        // Keep storage validation permissive so valid backend-issued tokens are not dropped client-side.
        let segments = trimmed.split(separator: ".")
        guard segments.count == 3 else { return nil }
        return trimmed
    }

    private func normalizedAuthorizationCredential(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.count >= 7, trimmed.prefix(7).lowercased() == "bearer " {
            trimmed = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isPlausibleRefreshCredential(_ value: String?) -> Bool {
        let trimmed = normalizedAuthorizationCredential(value) ?? ""
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count >= 8, trimmed.count <= 4096 else { return false }
        guard !trimmed.contains(where: { $0.isWhitespace }) else { return false }
        return true
    }

    private func isAttemptableRefreshCredential(_ value: String?) -> Bool {
        let trimmed = normalizedAuthorizationCredential(value) ?? ""
        guard isPlausibleRefreshCredential(trimmed) else { return false }
        return trimmed.count >= 8
    }

    private func bundledInfoString(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    private func normalizedConfigString(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        trimmed = trimmed.replacingOccurrences(of: "\\/", with: "/")
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isJWTExpiredOrNearExpiry(_ token: String, leewaySeconds: TimeInterval = 300) -> Bool {
        guard let payload = decodedJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        let expiryDate = Date(timeIntervalSince1970: exp)
        // Treat the token as expired when within leewaySeconds of actual expiry.
        // Default leeway is 300 s (5 min) so the app proactively refreshes well before the
        // token goes stale — avoiding last-second races when the network is slow.
        return expiryDate <= Date().addingTimeInterval(leewaySeconds)
    }

    /// Returns `true` when the current stored access token will expire within `withinSeconds`.
    /// Used by the pre-background refresh to decide whether a proactive refresh is needed
    /// before the app is suspended for an overnight sleep.
    func isCurrentAccessTokenExpiringSoon(withinSeconds: TimeInterval) -> Bool {
        guard let token = normalizedJWT(currentAuthToken()), !token.isEmpty else {
            // No token at all — consider it "expiring soon" so a refresh is attempted.
            return true
        }
        return isJWTExpiredOrNearExpiry(token, leewaySeconds: withinSeconds)
    }

    private func decodedJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3,
              let payloadData = decodeJWTBase64URL(String(segments[1])),
              let payload = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any] else {
            return nil
        }
        return payload
    }

    private func refreshTokenAgeMilliseconds(_ token: String) -> Int? {
        guard let issuedAtNumber = decodedJWTPayload(token)?["iat"] as? NSNumber else {
            return nil
        }
        let issuedAt = issuedAtNumber.doubleValue
        let ageSeconds = max(0, Date().timeIntervalSince1970 - issuedAt)
        return Int(ageSeconds * 1000)
    }

    private func decodedJWTHeader(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3,
              let headerData = decodeJWTBase64URL(String(segments[0])),
              let header = (try? JSONSerialization.jsonObject(with: headerData)) as? [String: Any] else {
            return nil
        }
        return header
    }

    private func normalizedJWTAlgorithm(_ algorithm: String?) -> String? {
        let normalized = algorithm?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func unsupportedJWTAlgorithm(from token: String?) -> String? {
        guard let token, let normalized = normalizedJWT(token), !normalized.isEmpty else { return nil }
        guard let algorithm = normalizedJWTAlgorithm(decodedJWTHeader(normalized)?["alg"] as? String) else {
            return nil
        }
        return Constants.supportedJWTAlgorithms.contains(algorithm) ? nil : algorithm
    }

    private func messageIndicatesUnsupportedJWTAlgorithm(_ message: String?) -> Bool {
        let normalized = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return normalized.contains("unsupported jwt algorithm")
    }

    private func quarantineSessionForUnsupportedJWTAlgorithm(
        algorithm: String,
        source: String
    ) {
        let message = "Unsupported JWT algorithm \(algorithm). Reauthentication required."
        Self.setLastAuthTokenRecoveryFailure(.httpStatus(401, message))
        setAuthSession(
            token: nil,
            refreshToken: nil,
            source: source
        )
    }

    private func decodeJWTBase64URL(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    private func encodedAvatarReference(from rawData: Data?) -> String? {
        guard let rawData, !rawData.isEmpty else { return nil }
        if let prepared = preparedAvatarUploadJPEGData(from: rawData) {
            return prepared.base64EncodedString()
        }
        return rawData.base64EncodedString()
    }

    private func preparedAvatarUploadJPEGData(from rawData: Data) -> Data? {
        #if canImport(UIKit)
        guard let sourceImage = PlatformImage(data: rawData) else {
            return nil
        }
        let maxDimension: CGFloat = 1600
        let sourceSize = sourceImage.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }
        let longest = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxDimension / longest)
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let rendered = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return compactJPEGData(for: rendered, maxBytes: 500_000)
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private func compactJPEGData(for image: PlatformImage, maxBytes: Int) -> Data? {
        let qualities: [CGFloat] = [0.9, 0.84, 0.78, 0.72, 0.64, 0.56]
        for quality in qualities {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        return image.jpegData(compressionQuality: 0.5)
    }
    #endif

    // MARK: - Moments

    func fetchMoments(userID: UUID? = nil) async throws -> [BackendMoment] {
        let path = userID.map { "/moments?user_id=\($0.uuidString)" } ?? "/moments"
        return try await request(
            path: path,
            method: "GET",
            body: Optional<EmptyBody>.none,
            includeAuthorization: true,
            allowAuthRetry: true
        )
    }

    func createMoment(id: UUID, authorID: UUID, videoLocalURL: URL) async throws -> BackendMoment {
        struct Body: Encodable {
            let id: UUID
            let authorID: UUID
            let videoRef: String
        }
        let videoRef = try await uploadMomentVideo(momentID: id, authorID: authorID, localURL: videoLocalURL)
        return try await request(
            path: "/moments",
            method: "POST",
            body: Body(id: id, authorID: authorID, videoRef: videoRef),
            includeAuthorization: true,
            allowAuthRetry: true,
            additionalHeaders: [
                "X-Idempotency-Key": idempotencyKey(scope: "moment-create", identifier: id.uuidString)
            ]
        )
    }

    func deleteMoment(id: UUID) async throws {
        _ = try await request(
            path: "/moments/\(id.uuidString)",
            method: "DELETE",
            body: Optional<EmptyBody>.none,
            includeAuthorization: true,
            allowAuthRetry: true
        ) as EmptyResponse
    }

    /// Record that the current user viewed a moment. Idempotent + a
    /// self-view is a backend no-op, so it's safe to call every time a
    /// moment opens.
    func recordMomentView(momentID: UUID, userID: UUID? = nil) async throws {
        struct Body: Encodable {
            let momentId: UUID
            let userId: UUID?
        }
        _ = try await request(
            path: "/moments/view",
            method: "POST",
            body: Body(momentId: momentID, userId: userID),
            includeAuthorization: true,
            allowAuthRetry: true
        ) as EmptyResponse
    }

    /// Author-only: list everyone who has viewed a moment, newest first.
    func fetchMomentViewers(momentID: UUID, userID: UUID? = nil) async throws -> [BackendMomentViewer] {
        let path = userID.map {
            "/moments/viewers?moment_id=\(momentID.uuidString)&user_id=\($0.uuidString)"
        } ?? "/moments/viewers?moment_id=\(momentID.uuidString)"
        return try await request(
            path: path,
            method: "GET",
            body: Optional<EmptyBody>.none,
            includeAuthorization: true,
            allowAuthRetry: true
        )
    }

    private func uploadMomentVideo(momentID: UUID, authorID: UUID, localURL: URL) async throws -> String {
        guard useSupabaseFunctions else {
            throw BackendClientError.httpStatus(
                503,
                "Direct Supabase Storage uploads are disabled. Configure Supabase Functions so uploads can use R2 upload tokens."
            )
        }
        guard localURL.isFileURL, FileManager.default.fileExists(atPath: localURL.path) else {
            throw BackendClientError.requestFailed
        }

        let ext = localURL.pathExtension.isEmpty ? "mp4" : localURL.pathExtension
        let fileExt = ext.lowercased()
        let contentType = fileExt == "mov" ? "video/quicktime" : "video/mp4"

        let objectKey = mediaObjectKey(
            ownerID: authorID,
            kind: .momentAsset,
            entityID: momentID,
            fileName: "original.\(fileExt)"
        )
        let result = try await uploadOwnedMediaFile(
            localURL: localURL,
            contentType: contentType,
            objectKey: objectKey,
            timeoutInterval: 60
        )

        return result.legacyRef
    }

}

private struct EmptyResponse: Decodable {}
private struct EmptyBody: Encodable {}

private final class BackendRealtimeInvalidationService {
    private let queue = DispatchQueue(label: "scrolls.realtime.invalidation")
    private var websocketURL: URL?
    private var accessToken: String?
    private var socketTask: URLSessionWebSocketTask?
    private var heartbeatTimer: DispatchSourceTimer?
    private var reconnectWorkItem: DispatchWorkItem?
    private var isRunning = false
    private var reconnectAttempt = 0
    private var nextRef = 1
    private var listener: ((BackendRealtimeEvent) -> Void)?
    private let subscribedTables = [
        "posts",
        "comments",
        "users",
        "follows",
        "notifications",
        "rescrolls",
        "comment_likes",
        "circles",
        "circle_members",
        "circle_messages"
    ]

    func start(
        websocketURL: URL,
        accessToken: String?,
        onEvent: @escaping (BackendRealtimeEvent) -> Void
    ) {
        queue.async {
            self.stopLocked()
            self.websocketURL = websocketURL
            self.accessToken = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.listener = onEvent
            self.isRunning = true
            self.connectLocked()
        }
    }

    func stop() {
        queue.async {
            self.stopLocked()
        }
    }

    func updateAccessToken(_ token: String?) {
        queue.async {
            self.accessToken = token?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard self.isRunning else { return }
            for table in self.subscribedTables {
                self.sendLocked([
                    "topic": "realtime:public:\(table)",
                    "event": "access_token",
                    "payload": [
                        "access_token": self.accessToken ?? ""
                    ],
                    "ref": self.nextRefStringLocked()
                ])
            }
        }
    }

    private func connectLocked() {
        guard isRunning, let websocketURL else { return }
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = URLSession.shared.webSocketTask(with: websocketURL)
        socketTask?.resume()
        reconnectAttempt = 0
        startHeartbeatLocked()
        for table in subscribedTables {
            joinTableLocked(table)
        }
        receiveNextLocked()
    }

    private func stopLocked() {
        isRunning = false
        reconnectAttempt = 0
        listener = nil
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
    }

    private func startHeartbeatLocked() {
        heartbeatTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            guard let self, self.isRunning else { return }
            self.sendLocked([
                "topic": "phoenix",
                "event": "heartbeat",
                "payload": [:],
                "ref": self.nextRefStringLocked()
            ])
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func joinTableLocked(_ table: String) {
        var payload: [String: Any] = [
            "config": [
                "broadcast": [
                    "ack": false,
                    "self": false
                ],
                "presence": [
                    "key": ""
                ],
                "postgres_changes": [[
                    "event": "*",
                    "schema": "public",
                    "table": table
                ]]
            ]
        ]
        if let token = accessToken, !token.isEmpty {
            payload["access_token"] = token
        }
        sendLocked([
            "topic": "realtime:public:\(table)",
            "event": "phx_join",
            "payload": payload,
            "ref": nextRefStringLocked()
        ])
    }

    private func receiveNextLocked() {
        guard isRunning, let socketTask else { return }
        socketTask.receive { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard self.isRunning else { return }
                switch result {
                case .success(let message):
                    self.handleMessageLocked(message)
                    self.receiveNextLocked()
                case .failure:
                    self.scheduleReconnectLocked()
                }
            }
        }
    }

    private func scheduleReconnectLocked() {
        guard isRunning, websocketURL != nil else { return }
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        reconnectWorkItem?.cancel()
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(min(reconnectAttempt, 5))), 25)
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isRunning else { return }
            self.connectLocked()
        }
        reconnectWorkItem = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func handleMessageLocked(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .data(let payload):
            data = payload
        case .string(let text):
            data = text.data(using: .utf8)
        @unknown default:
            data = nil
        }
        guard let data,
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        guard let topic = payload["topic"] as? String,
              let event = payload["event"] as? String else {
            return
        }

        if event != "postgres_changes" { return }
        guard let table = topic.split(separator: ":").last.map(String.init) else { return }
        let messagePayload = payload["payload"] as? [String: Any]
        let dataPayload = messagePayload?["data"] as? [String: Any]
        let newRecord = (dataPayload?["new"] as? [String: Any]) ?? (dataPayload?["record"] as? [String: Any]) ?? [:]
        let oldRecord = (dataPayload?["old"] as? [String: Any]) ?? (dataPayload?["old_record"] as? [String: Any]) ?? [:]

        let realtimeEvent: BackendRealtimeEvent?
        switch table {
        case "posts":
            realtimeEvent = .postsChanged(
                postID: uuidFromRecord(["id"], primary: newRecord, fallback: oldRecord),
                authorID: uuidFromRecord(["author_id"], primary: newRecord, fallback: oldRecord)
            )
        case "comments":
            realtimeEvent = .commentsChanged(
                postID: uuidFromRecord(["post_id"], primary: newRecord, fallback: oldRecord)
            )
        case "users":
            realtimeEvent = .usersChanged(
                userID: uuidFromRecord(["id"], primary: newRecord, fallback: oldRecord)
            )
        case "follows":
            realtimeEvent = .followsChanged(
                followerID: uuidFromRecord(["follower_id"], primary: newRecord, fallback: oldRecord),
                followeeID: uuidFromRecord(["followee_id"], primary: newRecord, fallback: oldRecord)
            )
        case "notifications":
            realtimeEvent = .notificationsChanged(
                userID: uuidFromRecord(["user_id"], primary: newRecord, fallback: oldRecord),
                objectID: uuidFromRecord(["object_id"], primary: newRecord, fallback: oldRecord)
            )
        case "rescrolls":
            realtimeEvent = .rescrollsChanged(
                originalPostID: uuidFromRecord(["original_post_id"], primary: newRecord, fallback: oldRecord),
                userID: uuidFromRecord(["user_id"], primary: newRecord, fallback: oldRecord)
            )
        case "comment_likes":
            realtimeEvent = .commentLikesChanged(
                commentID: uuidFromRecord(["comment_id"], primary: newRecord, fallback: oldRecord),
                userID: uuidFromRecord(["user_id"], primary: newRecord, fallback: oldRecord)
            )
        case "circles":
            realtimeEvent = .circlesChanged(
                circleID: uuidFromRecord(["id"], primary: newRecord, fallback: oldRecord),
                createdByID: uuidFromRecord(["created_by"], primary: newRecord, fallback: oldRecord)
            )
        case "circle_members":
            realtimeEvent = .circleMembersChanged(
                circleID: uuidFromRecord(["circle_id"], primary: newRecord, fallback: oldRecord),
                userID: uuidFromRecord(["user_id"], primary: newRecord, fallback: oldRecord)
            )
        case "circle_messages":
            realtimeEvent = .circleMessagesChanged(
                circleID: uuidFromRecord(["circle_id"], primary: newRecord, fallback: oldRecord),
                messageID: uuidFromRecord(["id"], primary: newRecord, fallback: oldRecord),
                userID: uuidFromRecord(["user_id"], primary: newRecord, fallback: oldRecord)
            )
        default:
            realtimeEvent = nil
        }

        guard let realtimeEvent, let listener else { return }
        DispatchQueue.main.async {
            listener(realtimeEvent)
        }
    }

    private func sendLocked(_ object: [String: Any]) {
        guard isRunning, let socketTask,
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        socketTask.send(.string(text)) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.queue.async {
                    self.scheduleReconnectLocked()
                }
            }
        }
    }

    private func nextRefStringLocked() -> String {
        let value = nextRef
        nextRef += 1
        return String(value)
    }

    private func uuidFromRecord(
        _ keys: [String],
        primary: [String: Any],
        fallback: [String: Any]
    ) -> UUID? {
        for key in keys {
            if let value = primary[key] as? String, let id = UUID(uuidString: value) {
                return id
            }
        }
        for key in keys {
            if let value = fallback[key] as? String, let id = UUID(uuidString: value) {
                return id
            }
        }
        return nil
    }
}

private extension JSONDecoder {
    static var scrolls: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var scrolls: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension BackendUser {
    var asUserProfile: UserProfile {
        let remoteAvatarData = avatarRef.flatMap { Data(base64Encoded: $0) }
        return UserProfile(
            id: id,
            username: username,
            displayName: displayName,
            bio: bio,
            keywords: [],
            gradientSpec: remoteGradientSpec(seed: username),
            avatarImageData: remoteAvatarData,
            avatarRef: remoteAvatarData == nil ? avatarRef : nil,
            avatarProvider: avatarProvider,
            avatarBucket: avatarBucket,
            avatarObjectKey: avatarObjectKey,
            isVerified: isVerified,
            isFounder: isFounder,
            isPrivateAccount: isPrivate ?? false,
            accountType: UserProfile.AccountType(rawValue: accountType ?? "") ?? .personal,
            subscriptionPlan: subscriptionPlan,
            pinnedPostID: pinnedPostID,
            signatureRef: signatureRef,
            avatarVideoRef: avatarVideoRef,
            websiteURL: websiteURL,
            venmoURL: venmoURL,
            cashAppURL: cashAppURL,
            spotifyURL: spotifyURL,
            appleMusicURL: appleMusicURL,
            businessLocation: businessLocation,
            businessPhone: businessPhone,
            homeCity: homeCity,
            dateOfBirth: dateOfBirth,
            ageAssuranceCompletedAt: ageAssuranceCompletedAt,
            parentalControls: parentalControls
        )
    }
}

extension BackendPost {
    var resolvedAssetURL: URL? {
        MediaURLResolver.resolve(
            provider: assetProvider, bucket: assetBucket, objectKey: assetObjectKey, legacyURL: nil
        )
    }

    var asMediaPreview: MediaPreview {
        switch type {
        case .text:
            return .text(textBody ?? caption ?? "")
        case .photo:
            let photoURL = MediaURLResolver.resolve(
                provider: assetProvider, bucket: assetBucket, objectKey: assetObjectKey, legacyURL: nil
            )
            if let remoteURL = photoURL {
                return .photo(PhotoPreview(fileURL: remoteURL, aspectRatio: CGFloat(aspectRatio ?? 1), assetIdentifier: assetRef))
            }
            #if canImport(UIKit) || canImport(AppKit)
            let placeholder = PlatformImage.gradient(with: remotePalette(seed: assetRef ?? id.uuidString))
            if let preview = MediaStorage.photoPreview(from: placeholder, assetIdentifier: assetRef) {
                return preview
            }
            #endif
            let fallback = caption ?? "Photo post"
            return .text(fallback)
        case .video:
            let videoURL = MediaURLResolver.resolve(
                provider: assetProvider, bucket: assetBucket, objectKey: assetObjectKey, legacyURL: nil
            )
            if let remoteURL = videoURL {
                return .video(url: remoteURL, aspectRatio: CGFloat(aspectRatio ?? 1), assetIdentifier: assetRef)
            }
            #if canImport(UIKit) || canImport(AppKit)
            let placeholder = PlatformImage.gradient(with: remotePalette(seed: assetRef ?? id.uuidString))
            if let preview = MediaStorage.photoPreview(from: placeholder, assetIdentifier: assetRef) {
                return preview
            }
            #endif
            let fallback = caption ?? "Video post"
            return .text(fallback)
        }
    }
}

extension BackendAdSubmissionPost {
    var asMediaPreview: MediaPreview {
        switch type {
        case .text:
            return .text(textBody ?? caption ?? "")
        case .photo:
            let remoteURL = MediaURLResolver.resolve(provider: assetProvider, bucket: assetBucket, objectKey: assetObjectKey)
                ?? resolvedRemoteMediaURL(from: assetRef, imageWidth: 1440)
            if let remoteURL {
                return .photo(PhotoPreview(fileURL: remoteURL, aspectRatio: CGFloat(aspectRatio ?? 1), assetIdentifier: assetRef))
            }
            #if canImport(UIKit) || canImport(AppKit)
            let placeholder = PlatformImage.gradient(with: remotePalette(seed: assetRef ?? id.uuidString))
            if let preview = MediaStorage.photoPreview(from: placeholder, assetIdentifier: assetRef) {
                return preview
            }
            #endif
            return .text(caption ?? "Photo ad")
        case .video:
            let remoteURL = MediaURLResolver.resolve(provider: assetProvider, bucket: assetBucket, objectKey: assetObjectKey)
                ?? resolvedRemoteMediaURL(from: assetRef)
            if let remoteURL {
                return .video(url: remoteURL, aspectRatio: CGFloat(aspectRatio ?? 1), assetIdentifier: assetRef)
            }
            #if canImport(UIKit) || canImport(AppKit)
            let placeholder = PlatformImage.gradient(with: remotePalette(seed: assetRef ?? id.uuidString))
            if let preview = MediaStorage.photoPreview(from: placeholder, assetIdentifier: assetRef) {
                return preview
            }
            #endif
            return .text(caption ?? "Video ad")
        }
    }
}

private func remoteGradientSpec(seed: String) -> GradientSpec {
    let colors = remotePalette(seed: seed).compactMap { $0.toComponents() }
    let fallback = ColorComponents(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    return GradientSpec(colors: colors.isEmpty ? [fallback] : colors)
}

private func resolvedRemoteMediaURL(from rawValue: String?, imageWidth: Int? = nil) -> URL? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
        return nil
    }

    guard let remoteURL = URL(string: rawValue) else { return nil }
    guard let scheme = remoteURL.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
    _ = imageWidth
    return remoteURL
}

private func remotePalette(seed: String) -> [PlatformColor] {
    let value = abs(seed.hashValue)
    switch value % 4 {
    case 0:
        return [PlatformColor.systemBlue, PlatformColor.systemTeal]
    case 1:
        return [PlatformColor.systemPurple, PlatformColor.systemPink]
    case 2:
        return [PlatformColor.systemOrange, PlatformColor.systemYellow]
    default:
        return [PlatformColor.systemIndigo, PlatformColor.systemMint]
    }
}
