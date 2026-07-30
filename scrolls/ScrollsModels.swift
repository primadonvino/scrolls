import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
typealias PlatformColor = NSColor
#else
typealias PlatformImage = Never
typealias PlatformColor = Never
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #else
        self.init(systemName: "photo")!
        #endif
    }
}

extension PlatformImage {
    func encodedDataRepresentation() -> Data? {
        #if canImport(UIKit)
        if let png = pngData() {
            return png
        }
        return jpegData(compressionQuality: 0.9)
        #elseif canImport(AppKit)
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    /// Center-crops to a square and scales to `side × side` pixels.
    /// Returns `self` unchanged if dimensions are already correct.
    func squareCropped(to side: Int = 1024) -> PlatformImage {
        let targetSize = CGSize(width: side, height: side)
        let w = size.width, h = size.height
        guard w > 0, h > 0 else { return self }
        // Already the right size — skip allocation
        if Int(w) == side, Int(h) == side { return self }

        let cropSide = min(w, h)
        let cropRect = CGRect(
            x: (w - cropSide) / 2,
            y: (h - cropSide) / 2,
            width: cropSide,
            height: cropSide
        )

        #if canImport(UIKit)
        let scale = self.scale
        let scaledCrop = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )
        guard let cgImg = self.cgImage?.cropping(to: scaledCrop) else { return self }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            UIImage(cgImage: cgImg).draw(in: CGRect(origin: .zero, size: targetSize))
        }
        #elseif canImport(AppKit)
        let result = NSImage(size: targetSize)
        result.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize),
             from: cropRect,
             operation: .copy,
             fraction: 1.0)
        result.unlockFocus()
        return result
        #else
        return self
        #endif
    }
}

struct PostComment: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let user: UserProfile
    let text: String
    let timestamp: Date
    var replies: [PostComment]
    var likedBy: [UUID]

    var likeCount: Int {
        likedBy.count
    }

    func isLiked(by profile: UserProfile) -> Bool {
        likedBy.contains(profile.id)
    }

    enum CodingKeys: String, CodingKey {
        case id, user, text, timestamp, replies, likedBy
    }

    init(id: UUID, user: UserProfile, text: String, timestamp: Date, replies: [PostComment] = [], likedBy: [UUID] = []) {
        self.id = id
        self.user = user
        self.text = text
        self.timestamp = timestamp
        self.replies = replies
        self.likedBy = likedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user = try container.decode(UserProfile.self, forKey: .user)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        replies = try container.decodeIfPresent([PostComment].self, forKey: .replies) ?? []
        likedBy = try container.decodeIfPresent([UUID].self, forKey: .likedBy) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(user, forKey: .user)
        try container.encode(text, forKey: .text)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(replies, forKey: .replies)
        try container.encode(likedBy, forKey: .likedBy)
    }
}

struct RescrollOrigin: Equatable, Codable, Sendable {
    let postID: UUID
    let user: UserProfile
    let caption: String?
    let websiteURL: String?
    let timestamp: Date
}

struct FeedPost: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let user: UserProfile
    var caption: String?
    let websiteURL: String?
    var locationCity: String? = nil
    let timestamp: Date
    let mediaPreview: MediaPreview
    var coverImageRef: String? = nil
    var coverProvider: String? = nil
    var coverBucket: String? = nil
    var coverObjectKey: String? = nil
    var assetProvider: String? = nil
    var assetBucket: String? = nil
    var assetObjectKey: String? = nil
    var comments: [PostComment]
    let rescrollOrigin: RescrollOrigin?
    var rescrollQuoteText: String? = nil

    static func == (lhs: FeedPost, rhs: FeedPost) -> Bool {
        lhs.id == rhs.id
    }
}

struct VideoFeaturedMusicLink: Codable, Equatable, Identifiable, Sendable {
    let postID: UUID
    let trackID: UUID?
    let releaseTitle: String
    let trackTitle: String?
    let artistDisplayName: String
    let artistUsername: String

    var id: String { "\(postID.uuidString)-\(trackID?.uuidString ?? "release")" }

    var displayTitle: String {
        let track = trackTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !track.isEmpty { return track }
        let release = releaseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return release.isEmpty ? "Featured music" : release
    }

    var displayArtist: String {
        let name = artistDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let username = artistUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? "Artist" : "@\(username)"
    }

    var displayLine: String {
        "\(displayArtist) · \(displayTitle)"
    }
}

enum MusicReleaseType: String, Codable, CaseIterable, Sendable, Identifiable {
    case album
    case singlesEPs

    var id: Self { self }

    var title: String {
        switch self {
        case .album:
            return "Album"
        case .singlesEPs:
            return "Singles/EPs"
        }
    }
}

enum MusicGenreOption: String, Codable, CaseIterable, Sendable, Identifiable {
    case pop = "Pop"
    case rock = "Rock"
    case dance = "Dance"
    case hipHopRap = "Hip-Hop / Rap"
    case electronic = "Electronic"
    case rnbSoul = "R&B / Soul"
    case country = "Country"
    case classical = "Classical"
    case jazz = "Jazz"
    case blues = "Blues"
    case folk = "Folk"
    case reggae = "Reggae"
    case worldGlobal = "World / Global"

    var id: String { rawValue }
    var title: String { rawValue }

    static func normalizedValue(from value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "" }
        if let exact = allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact.rawValue
        }

        let compact = trimmed
            .lowercased()
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch compact {
        case "hiphop", "hiphoprap", "rap":
            return hipHopRap.rawValue
        case "randb", "randbsoul", "rbsoul", "soul":
            return rnbSoul.rawValue
        case "world", "global", "worldglobal":
            return worldGlobal.rawValue
        default:
            return allCases.first { option in
                option.rawValue
                    .lowercased()
                    .replacingOccurrences(of: "&", with: "and")
                    .replacingOccurrences(of: "/", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: " ", with: "") == compact
            }?.rawValue ?? ""
        }
    }
}

enum VideoScrollCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case standard = "video"
    case shortFilm = "short_film"
    case musicVideo = "music_video"

    var id: Self { self }

    var title: String {
        switch self {
        case .standard:
            return "Video"
        case .shortFilm:
            return "Short Film"
        case .musicVideo:
            return "Music Video"
        }
    }

    var filterTitle: String {
        switch self {
        case .standard:
            return "All Video"
        case .shortFilm, .musicVideo:
            return title
        }
    }

    var helperText: String {
        switch self {
        case .standard:
            return "A regular video scroll."
        case .shortFilm:
            return "Narrative, documentary, or cinematic video work."
        case .musicVideo:
            return "A video made for a song, release, or artist."
        }
    }

    static func normalized(from value: String?) -> VideoScrollCategory? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        if let exact = allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact
        }
        let compact = trimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
        switch compact {
        case "video", "standard", "regular":
            return .standard
        case "shortfilm", "film", "short":
            return .shortFilm
        case "musicvideo", "musicvid", "mv":
            return .musicVideo
        default:
            return nil
        }
    }
}

struct MusicTrackArtistCredit: Codable, Equatable, Identifiable, Sendable {
    let userID: UUID
    let username: String
    let displayName: String

    var id: UUID { userID }

    init(userID: UUID, username: String, displayName: String) {
        self.userID = userID
        self.username = username
        self.displayName = displayName
    }

    init(profile: UserProfile) {
        self.init(userID: profile.id, username: profile.username, displayName: profile.displayName)
    }

    var displayLabel: String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUsername.isEmpty ? "Artist" : "@\(trimmedUsername)"
    }
}

struct MusicTrackMetadata: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let audioURL: URL?
    /// Duration of the audio track in seconds.  Captured at upload time by
    /// reading the local file's AVAsset duration before the file leaves the
    /// device.  Optional because (a) existing posts published before this
    /// field was introduced won't have it, and (b) some upload paths (e.g.
    /// placeholder slots not yet attached to a file) genuinely have no
    /// duration to record.  The release-metadata footer sums these to show
    /// total runtime ("12 songs, 39 minutes"); any nil values are excluded
    /// from the sum, and the footer falls back to just the song count if no
    /// durations are known.
    let durationSeconds: Double?
    /// Optional lyric sheet for this specific track.  Free-form text — the
    /// artist writes it in the create or edit flow, and viewers see it in
    /// the LyricsSheet shown by the action bar's lyrics button (which is
    /// visually the comment-bubble icon).  Nil means the artist hasn't
    /// supplied lyrics yet for this track; the sheet shows an
    /// "(no lyrics yet)" placeholder for it.
    let lyrics: String?
    /// Marks the track as containing explicit content.  Surfaced via the
    /// "E" badge on the track row in the now-playing sheet's track list,
    /// matching the Apple Music / Spotify convention.  Defaults to false
    /// for backward compatibility with posts uploaded before this flag
    /// existed; artists toggle it per-track in the create and edit flows.
    let isExplicit: Bool
    /// Featured artists for this individual track. The post author remains
    /// the lead artist and renders first; these collaborators render after.
    let collaboratorCredits: [MusicTrackArtistCredit]

    init(
        id: UUID = UUID(),
        title: String,
        audioURL: URL? = nil,
        durationSeconds: Double? = nil,
        lyrics: String? = nil,
        isExplicit: Bool = false,
        collaboratorCredits: [MusicTrackArtistCredit] = []
    ) {
        self.id = id
        self.title = title
        self.audioURL = audioURL
        self.durationSeconds = durationSeconds
        self.lyrics = lyrics
        self.isExplicit = isExplicit
        self.collaboratorCredits = collaboratorCredits
    }

    func artistLine(leadArtist: UserProfile) -> String? {
        guard !collaboratorCredits.isEmpty else { return nil }
        let lead = leadArtist.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadLabel = lead.isEmpty ? "@\(leadArtist.username)" : lead
        let names = [leadLabel] + collaboratorCredits.map(\.displayLabel)
        return Self.joinArtistNames(names)
    }

    private static func joinArtistNames(_ names: [String]) -> String {
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        switch cleaned.count {
        case 0: return ""
        case 1: return cleaned[0]
        case 2: return "\(cleaned[0]) & \(cleaned[1])"
        default:
            return cleaned.dropLast().joined(separator: ", ") + " & " + (cleaned.last ?? "")
        }
    }

    // MARK: - Codable
    // Custom decoder so older posts (published before durationSeconds/lyrics/
    // isExplicit existed) continue to decode cleanly — missing fields are
    // treated as nil/false.

    private enum CodingKeys: String, CodingKey {
        case id, title, audioURL, durationSeconds, lyrics, isExplicit, collaboratorCredits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        self.durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        self.lyrics = try container.decodeIfPresent(String.self, forKey: .lyrics)
        self.isExplicit = try container.decodeIfPresent(Bool.self, forKey: .isExplicit) ?? false
        self.collaboratorCredits = try container.decodeIfPresent([MusicTrackArtistCredit].self, forKey: .collaboratorCredits) ?? []
    }
}

struct MusicTrackUploadDraft: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    /// `nil` means this is a placeholder slot — no audio file attached yet.
    let localURL: URL?
    var title: String
    /// Optional lyrics the artist types into the create flow.  Persists onto
    /// the published MusicTrackMetadata.lyrics so the LyricsSheet can show
    /// the song's words.  Default empty string keeps the binding simple in
    /// SwiftUI's TextEditor.
    var lyrics: String
    /// True when the track contains explicit content.  Mirrors
    /// MusicTrackMetadata.isExplicit so the toggle the artist sets in the
    /// create flow flows through publish unchanged.
    var isExplicit: Bool
    /// Featured artists for this individual track.
    var collaboratorCredits: [MusicTrackArtistCredit]

    var isPlaceholder: Bool { localURL == nil }

    init(
        id: UUID = UUID(),
        localURL: URL?,
        title: String,
        lyrics: String = "",
        isExplicit: Bool = false,
        collaboratorCredits: [MusicTrackArtistCredit] = []
    ) {
        self.id = id
        self.localURL = localURL
        self.title = title
        self.lyrics = lyrics
        self.isExplicit = isExplicit
        self.collaboratorCredits = collaboratorCredits
    }

    /// Convenience init for a real audio file whose title is derived from the filename.
    init(localURL: URL) {
        self.init(
            localURL: localURL,
            title: localURL.deletingPathExtension().lastPathComponent
        )
    }

    /// Creates a named placeholder slot with no audio file.
    init(placeholderTitle: String) {
        self.init(localURL: nil, title: placeholderTitle)
    }

    // MARK: - Codable backward compat
    // Older serialized drafts (e.g. autosaved local state) don't have the
    // `lyrics` or `isExplicit` fields; treat missing cases as empty/false.
    private enum CodingKeys: String, CodingKey {
        case id, localURL, title, lyrics, isExplicit, collaboratorCredits
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.localURL = try c.decodeIfPresent(URL.self, forKey: .localURL)
        self.title = try c.decode(String.self, forKey: .title)
        self.lyrics = try c.decodeIfPresent(String.self, forKey: .lyrics) ?? ""
        self.isExplicit = try c.decodeIfPresent(Bool.self, forKey: .isExplicit) ?? false
        self.collaboratorCredits = try c.decodeIfPresent([MusicTrackArtistCredit].self, forKey: .collaboratorCredits) ?? []
    }
}

struct MusicTrackEditDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var existingAudioURL: URL?
    var replacementLocalURL: URL?
    var replacementFilename: String?
    /// Editable lyrics seeded from the existing track and written back
    /// through updateMusicPost.  Empty string represents "no lyrics" so
    /// the binding stays simple.
    var lyrics: String
    /// Editable explicit flag seeded from MusicTrackMetadata.isExplicit
    /// and written back through updateMusicPost.
    var isExplicit: Bool
    /// Editable featured artists for this track.
    var collaboratorCredits: [MusicTrackArtistCredit]

    init(
        id: UUID,
        title: String,
        existingAudioURL: URL? = nil,
        replacementLocalURL: URL? = nil,
        replacementFilename: String? = nil,
        lyrics: String = "",
        isExplicit: Bool = false,
        collaboratorCredits: [MusicTrackArtistCredit] = []
    ) {
        self.id = id
        self.title = title
        self.existingAudioURL = existingAudioURL
        self.replacementLocalURL = replacementLocalURL
        self.replacementFilename = replacementFilename
        self.lyrics = lyrics
        self.isExplicit = isExplicit
        self.collaboratorCredits = collaboratorCredits
    }

    init(metadata: MusicTrackMetadata) {
        self.init(
            id: metadata.id,
            title: metadata.title,
            existingAudioURL: metadata.audioURL,
            lyrics: metadata.lyrics ?? "",
            isExplicit: metadata.isExplicit,
            collaboratorCredits: metadata.collaboratorCredits
        )
    }
}

private enum FeedPostKindMarker {
    static let podcastPrefix = "[PODCAST]"
    static let musicPrefix = "[MUSIC]"
    static let articlePrefix = "[ARTICLE]"
    // Kept for backward compatibility with already-published music posts.
    static let musicLoopVideoPrefix = "[MUSIC_LOOP_VIDEO]"
    static let audioLoopVideoPrefix = "[AUDIO_LOOP_VIDEO]"
    static let musicReleaseTypePrefix = "[MUSIC_RELEASE_TYPE]"
    static let musicTracksPrefix = "[MUSIC_TRACKS_BASE64]"
    // Release-info markers (added when the release-metadata footer feature
    // shipped).  Stored as ISO-8601 date string and free-form text
    // respectively.  Optional — older posts simply omit the lines.
    static let musicReleaseDatePrefix = "[MUSIC_RELEASE_DATE]"
    static let musicRecordLabelPrefix = "[MUSIC_RECORD_LABEL]"
    /// Free-form genre for the release (e.g. "Hip-Hop", "R&B/Soul").
    /// Optional — older posts simply omit the line.
    static let musicGenrePrefix = "[MUSIC_GENRE]"
    /// Album-level liner notes — companion piece written by the artist.
    /// Base64-encoded so embedded newlines/quotes survive the line-by-line
    /// caption parser (per-track lyrics live inside the existing
    /// [MUSIC_TRACKS_BASE64] payload via MusicTrackMetadata.lyrics).
    static let musicLinerNotesPrefix = "[MUSIC_LINER_NOTES_BASE64]"
    /// Linked music-video posts for this release.  Stores a base64-encoded
    /// JSON array of FeedPost UUIDs (post IDs of video posts the artist
    /// has already published to the app).  Surfaces under the release-
    /// metadata footer as a horizontally-scrolling "Music Videos" row.
    /// Applies to both Single/EP and Album releases.
    static let musicVideoLinksPrefix = "[MUSIC_VIDEO_LINKS_BASE64]"
    /// Playlist posts created from saved music tracks.  Encodes a
    /// MusicPlaylistPostPayload snapshot so the playlist appears in feeds
    /// and profile filters even before track detail is fetched.
    static let musicPlaylistPrefix = "[MUSIC_PLAYLIST_BASE64]"
    /// Category marker for normal video scrolls.  Missing marker means the
    /// legacy/default `.standard` category, so old posts remain "Video".
    static let videoCategoryPrefix = "[VIDEO_CATEGORY]"
    /// Featured music on a photo or video post.  Stores a base64-encoded
    /// VideoFeaturedMusicLink snapshot so promotional posts can render an
    /// Instagram-style music line without requiring a follow-up fetch.
    static let featuredMusicPrefix = "[FEATURED_MUSIC_BASE64]"
    /// Legacy featured-music marker used by video posts before photo posts
    /// gained the same capability.  Kept readable so already-published
    /// video posts continue to show their linked song/album.
    static let videoFeaturedMusicPrefix = "[VIDEO_FEATURED_MUSIC_BASE64]"
    /// Additional photos in a multi-photo carousel post (verified/gold).
    /// Stored as a base64-encoded JSON array of remote URLs.  The PRIMARY
    /// photo lives in the post's regular asset (mediaPreview.photo); slides
    /// 2-N (up to 4 total) live in this marker.  Older clients that don't
    /// recognize the marker just render the primary photo, keeping the
    /// post functional cross-version.
    static let photoCarouselPrefix = "[PHOTO_CAROUSEL_BASE64]"
    /// Collaborator user IDs tagged on the post.  Base64-encoded JSON
    /// array of UUID strings — the broadcaster picks mutual followers
    /// in the create flow and the published post surfaces them via a
    /// chip in the header that opens a sheet listing each collaborator
    /// (avatar + follow button).
    static let scrollCollaboratorsPrefix = "[SCROLL_COLLABORATORS_BASE64]"
}

struct MusicPlaylistPostPayload: Codable, Equatable, Sendable {
    let playlistID: UUID
    let postID: UUID?
    let title: String
    let coverRef: String?
    let coverProvider: String?
    let coverBucket: String?
    let coverObjectKey: String?
    let trackCount: Int

    var resolvedCoverURL: URL? {
        MediaURLResolver.resolve(
            provider: coverProvider,
            bucket: coverBucket,
            objectKey: coverObjectKey,
            legacyURL: coverRef
        )
    }
}

extension FeedPost {
    private struct ParsedAudioCaptionMetadata {
        let displayCaption: String?
        let loopVideoURL: URL?
        let musicReleaseType: MusicReleaseType?
        let musicTracks: [MusicTrackMetadata]
        let musicReleaseDate: Date?
        let musicRecordLabel: String?
        let musicGenre: String?
        let musicLinerNotes: String?
        let musicVideoLinkIDs: [UUID]
    }

    /// ISO-8601 date formatter for serializing/deserializing release dates in
    /// the caption marker payload.  Lives at file scope so we don't pay the
    /// instantiation cost on every parse — release-date lookups happen for
    /// every music post in the feed.
    private static let musicReleaseDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static func parseAudioCaptionMetadata(from caption: String) -> ParsedAudioCaptionMetadata {
        let lines = caption
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var displayLines: [String] = []
        var loopURL: URL?
        var musicReleaseType: MusicReleaseType?
        var musicTracks: [MusicTrackMetadata] = []
        var musicReleaseDate: Date?
        var musicRecordLabel: String?
        var musicGenre: String?
        var musicLinerNotes: String?
        var musicVideoLinkIDs: [UUID] = []

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix(FeedPostKindMarker.musicLoopVideoPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicLoopVideoPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = URL(string: suffix), !suffix.isEmpty {
                    loopURL = parsed
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.audioLoopVideoPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.audioLoopVideoPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = URL(string: suffix), !suffix.isEmpty {
                    loopURL = parsed
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicReleaseTypePrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicReleaseTypePrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if suffix == MusicReleaseType.album.rawValue {
                    musicReleaseType = .album
                } else if suffix == MusicReleaseType.singlesEPs.rawValue.lowercased() {
                    musicReleaseType = .singlesEPs
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicTracksPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicTracksPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let decodedData = Data(base64Encoded: suffix),
                   let decodedTracks = try? JSONDecoder().decode([MusicTrackMetadata].self, from: decodedData) {
                    musicTracks = decodedTracks
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicReleaseDatePrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicReleaseDatePrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !suffix.isEmpty, let parsed = musicReleaseDateFormatter.date(from: suffix) {
                    musicReleaseDate = parsed
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicRecordLabelPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicRecordLabelPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !suffix.isEmpty {
                    musicRecordLabel = suffix
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicGenrePrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicGenrePrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedGenre = MusicGenreOption.normalizedValue(from: suffix)
                if !normalizedGenre.isEmpty {
                    musicGenre = normalizedGenre
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicLinerNotesPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicLinerNotesPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let data = Data(base64Encoded: suffix),
                   let decoded = String(data: data, encoding: .utf8),
                   !decoded.isEmpty {
                    musicLinerNotes = decoded
                }
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.musicVideoLinksPrefix) {
                let suffix = line.dropFirst(FeedPostKindMarker.musicVideoLinksPrefix.count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !suffix.isEmpty,
                   let data = Data(base64Encoded: suffix),
                   let stringIDs = try? JSONDecoder().decode([String].self, from: data) {
                    musicVideoLinkIDs = stringIDs.compactMap { UUID(uuidString: $0) }
                }
                continue
            }
            // Non-music structured markers that can still appear on a
            // music post (collaborator tagging, photo carousel attachment
            // for releases with a multi-photo cover, etc.).  These are
            // consumed by their own accessors elsewhere on FeedPost; we
            // just need to make sure the raw marker text doesn't bleed
            // into the display caption.
            if upper.hasPrefix(FeedPostKindMarker.scrollCollaboratorsPrefix) {
                continue
            }
            if upper.hasPrefix(FeedPostKindMarker.photoCarouselPrefix) {
                continue
            }
            displayLines.append(line)
        }

        let displayCaption = displayLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedAudioCaptionMetadata(
            displayCaption: displayCaption.isEmpty ? nil : displayCaption,
            loopVideoURL: loopURL,
            musicReleaseType: musicReleaseType,
            musicTracks: musicTracks,
            musicReleaseDate: musicReleaseDate,
            musicRecordLabel: musicRecordLabel,
            musicGenre: musicGenre,
            musicLinerNotes: musicLinerNotes,
            musicVideoLinkIDs: musicVideoLinkIDs
        )
    }

    private static func encodedMusicTracksPayload(_ tracks: [MusicTrackMetadata]) -> String? {
        guard !tracks.isEmpty,
              let encoded = try? JSONEncoder().encode(tracks) else {
            return nil
        }
        return encoded.base64EncodedString()
    }

    var isPodcast: Bool {
        guard let caption else { return false }
        return caption.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix(FeedPostKindMarker.podcastPrefix)
    }

    var isMusic: Bool {
        guard let caption else { return false }
        return caption.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix(FeedPostKindMarker.musicPrefix)
    }

    var isMusicPlaylist: Bool {
        musicPlaylistPayload != nil
    }

    var musicPlaylistPayload: MusicPlaylistPostPayload? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPlaylistPrefix) else { return nil }
        let suffix = trimmed.dropFirst(FeedPostKindMarker.musicPlaylistPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: suffix),
              let payload = try? JSONDecoder().decode(MusicPlaylistPostPayload.self, from: data) else {
            return nil
        }
        return payload
    }

    var isAudioPost: Bool {
        isPodcast || isMusic
    }

    var musicLoopVideoURL: URL? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).loopVideoURL
    }

    var podcastLoopVideoURL: URL? {
        guard isPodcast, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.podcastPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.podcastPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).loopVideoURL
    }

    var musicReleaseType: MusicReleaseType? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicReleaseType
    }

    var musicTracks: [MusicTrackMetadata] {
        guard isMusic, let caption else { return [] }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return [] }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicTracks
    }

    /// Release date for this music post, if the broadcaster supplied one in
    /// the create flow or via the edit sheet.  Optional — older posts and
    /// drafts without an explicit date return nil and the metadata footer
    /// hides the line.
    var musicReleaseDate: Date? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicReleaseDate
    }

    /// Record label this release is published under (free-form text).
    var musicRecordLabel: String? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicRecordLabel
    }

    /// Genre this release is categorized under from the fixed upload/edit options.
    var musicGenre: String? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicGenre
    }

    /// Total runtime of all tracks with known durations, in seconds.  Returns
    /// nil if no tracks have a duration recorded (e.g. older posts uploaded
    /// before auto-duration capture shipped).  The footer view formats this
    /// into "N minutes" / "1 hr 23 min" as appropriate.
    var musicTotalDurationSeconds: TimeInterval? {
        let durations = musicTracks.compactMap { $0.durationSeconds }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    /// Album-level liner notes — companion piece the artist writes alongside
    /// the release.  Surfaced via the action bar's record-symbol button in
    /// LinerNotesSheet.  Nil when the artist hasn't supplied any.
    var musicLinerNotes: String? {
        guard isMusic, let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return nil }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicLinerNotes
    }

    /// Post IDs of video posts the artist has linked as "music videos"
    /// for this release.  Surfaced under the release metadata footer as
    /// a horizontally-scrolling row of thumbnails.  Applies to both
    /// Single/EP and Album releases.  Returns an empty array when the
    /// artist hasn't linked any, so callers can branch on `.isEmpty`.
    var musicVideoLinkIDs: [UUID] {
        guard isMusic, let caption else { return [] }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let upper = trimmed.uppercased()
        guard upper.hasPrefix(FeedPostKindMarker.musicPrefix) else { return [] }
        let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
        let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.parseAudioCaptionMetadata(from: remainder).musicVideoLinkIDs
    }

    var audioLoopVideoURL: URL? {
        if let podcast = podcastLoopVideoURL { return podcast }
        return musicLoopVideoURL
    }

    var podcastCoverImageURL: URL? {
        MediaURLResolver.resolve(
            provider: coverProvider,
            bucket: coverBucket,
            objectKey: coverObjectKey,
            legacyURL: nil
        )
    }

    var isArticle: Bool {
        guard let caption else { return false }
        return caption.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().hasPrefix(FeedPostKindMarker.articlePrefix)
    }

    var videoCategory: VideoScrollCategory {
        guard case .video = mediaPreview else { return .standard }
        return Self.videoCategory(from: caption)
    }

    var featuredMusicLink: VideoFeaturedMusicLink? {
        switch mediaPreview {
        case .photo, .video:
            break
        case .text:
            return nil
        }
        return Self.featuredMusicLink(from: caption)
    }

    static func videoCategory(from caption: String?) -> VideoScrollCategory {
        guard let caption else { return .standard }
        for line in caption.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = normalized.uppercased()
            guard upper.hasPrefix(FeedPostKindMarker.videoCategoryPrefix) else { continue }
            let suffix = String(normalized.dropFirst(FeedPostKindMarker.videoCategoryPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return VideoScrollCategory.normalized(from: suffix) ?? .standard
        }
        return .standard
    }

    static func featuredMusicLink(from caption: String?) -> VideoFeaturedMusicLink? {
        guard let caption else { return nil }
        for line in caption.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = normalized.uppercased()
            let prefix: String
            if upper.hasPrefix(FeedPostKindMarker.featuredMusicPrefix) {
                prefix = FeedPostKindMarker.featuredMusicPrefix
            } else if upper.hasPrefix(FeedPostKindMarker.videoFeaturedMusicPrefix) {
                prefix = FeedPostKindMarker.videoFeaturedMusicPrefix
            } else {
                continue
            }
            let suffix = String(normalized.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = Data(base64Encoded: suffix),
                  let link = try? JSONDecoder().decode(VideoFeaturedMusicLink.self, from: data) else {
                continue
            }
            return link
        }
        return nil
    }

    private static func encodedFeaturedMusicPayload(_ link: VideoFeaturedMusicLink?) -> String? {
        guard let link,
              let encoded = try? JSONEncoder().encode(link) else {
            return nil
        }
        return encoded.base64EncodedString()
    }

    static func captionWithFeaturedMusic(
        from caption: String?,
        featuredMusic: VideoFeaturedMusicLink? = nil
    ) -> String? {
        let cleanBody = strippingFeaturedMusicMarker(from: caption)
        var lines: [String] = []
        if let encodedFeaturedMusic = encodedFeaturedMusicPayload(featuredMusic) {
            lines.append("\(FeedPostKindMarker.featuredMusicPrefix) \(encodedFeaturedMusic)")
        }
        if !cleanBody.isEmpty {
            lines.append(cleanBody)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func videoCaption(
        from caption: String?,
        category: VideoScrollCategory,
        featuredMusic: VideoFeaturedMusicLink? = nil
    ) -> String? {
        let cleanBody = strippingVideoCategoryMarker(from: caption)
        var lines: [String] = []
        if category != .standard {
            lines.append("\(FeedPostKindMarker.videoCategoryPrefix) \(category.rawValue)")
        }
        if let encodedFeaturedMusic = encodedFeaturedMusicPayload(featuredMusic) {
            lines.append("\(FeedPostKindMarker.featuredMusicPrefix) \(encodedFeaturedMusic)")
        }
        if !cleanBody.isEmpty {
            lines.append(cleanBody)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func strippingFeaturedMusicMarker(from caption: String?) -> String {
        let body = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !body.isEmpty else { return "" }
        return body
            .components(separatedBy: .newlines)
            .filter { line in
                let upper = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return !upper.hasPrefix(FeedPostKindMarker.featuredMusicPrefix)
                    && !upper.hasPrefix(FeedPostKindMarker.videoFeaturedMusicPrefix)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func strippingVideoCategoryMarker(from caption: String?) -> String {
        let body = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !body.isEmpty else { return "" }
        return body
            .components(separatedBy: .newlines)
            .filter { line in
                let upper = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return !upper.hasPrefix(FeedPostKindMarker.videoCategoryPrefix)
                    && !upper.hasPrefix(FeedPostKindMarker.featuredMusicPrefix)
                    && !upper.hasPrefix(FeedPostKindMarker.videoFeaturedMusicPrefix)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayCaption: String? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let upper = trimmed.uppercased()
        if upper.hasPrefix(FeedPostKindMarker.podcastPrefix) {
            let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.podcastPrefix.count)
            let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.parseAudioCaptionMetadata(from: remainder).displayCaption
        }
        if upper.hasPrefix(FeedPostKindMarker.musicPrefix) {
            let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.musicPrefix.count)
            let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return Self.parseAudioCaptionMetadata(from: remainder).displayCaption
        }
        if upper.hasPrefix(FeedPostKindMarker.musicPlaylistPrefix) {
            return nil
        }
        if upper.hasPrefix(FeedPostKindMarker.articlePrefix) {
            let start = trimmed.index(trimmed.startIndex, offsetBy: FeedPostKindMarker.articlePrefix.count)
            let remainder = String(trimmed[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Same defensive strip as the plain-caption branch — an
            // article can also carry a collaborator or carousel marker.
            let stripped = Self.strippedPlainCaption(from: remainder)
            return stripped.isEmpty ? nil : stripped
        }
        // Plain caption (photo / video / text post).  Strip any
        // [PHOTO_CAROUSEL_BASE64] marker line so it doesn't show up as
        // garbage text under the post.  Other markers don't appear on
        // these post types so we only need to handle this one.
        let stripped = Self.strippedPlainCaption(from: trimmed)
        return stripped.isEmpty ? nil : stripped
    }

    /// Removes the photo carousel and collaborator markers (if any)
    /// from a plain caption.  Used by displayCaption for post types
    /// that don't carry a kind prefix — photo, video, text.
    private static func strippedPlainCaption(from caption: String) -> String {
        let lines = caption.components(separatedBy: .newlines)
        let kept = lines.filter { line in
            let upper = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return !upper.hasPrefix(FeedPostKindMarker.photoCarouselPrefix)
                && !upper.hasPrefix(FeedPostKindMarker.scrollCollaboratorsPrefix)
                && !upper.hasPrefix(FeedPostKindMarker.videoCategoryPrefix)
                && !upper.hasPrefix(FeedPostKindMarker.featuredMusicPrefix)
                && !upper.hasPrefix(FeedPostKindMarker.videoFeaturedMusicPrefix)
                && !upper.hasPrefix(FeedPostKindMarker.musicPlaylistPrefix)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Appends the collaborators marker to an existing caption.  Pass
    /// an empty array to leave the caption unchanged (existing markers
    /// are stripped first to avoid duplicates).  Used by the create
    /// flow when the user tags one or more mutual followers.
    static func appendingCollaboratorsMarker(to caption: String?, collaboratorIDs: [UUID]) -> String {
        let body = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Strip any pre-existing collaborator marker so callers can
        // safely call this twice without producing duplicates.
        let cleanBody = body
            .components(separatedBy: .newlines)
            .filter { line in
                !line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased()
                    .hasPrefix(FeedPostKindMarker.scrollCollaboratorsPrefix)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIDs = collaboratorIDs.map { $0.uuidString }
        guard !normalizedIDs.isEmpty,
              let encoded = (try? JSONEncoder().encode(normalizedIDs))?.base64EncodedString() else {
            return cleanBody
        }
        let markerLine = "\(FeedPostKindMarker.scrollCollaboratorsPrefix) \(encoded)"
        if cleanBody.isEmpty {
            return markerLine
        }
        return "\(cleanBody)\n\(markerLine)"
    }

    /// Collaborator user IDs the broadcaster tagged on this post.
    /// Returns an empty array for posts that don't include the marker
    /// (i.e. the majority of posts), so callers can `if !isEmpty` to
    /// branch on collaborator display.  UUIDs are not validated here
    /// against the local profile registry — that resolution happens
    /// at the call site so the dict-lookup runs in the view-model
    /// context.
    var scrollCollaboratorIDs: [UUID] {
        guard let caption else { return [] }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        for line in trimmed.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = normalized.uppercased()
            guard upper.hasPrefix(FeedPostKindMarker.scrollCollaboratorsPrefix) else { continue }
            let suffix = String(normalized.dropFirst(FeedPostKindMarker.scrollCollaboratorsPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !suffix.isEmpty,
                  let data = Data(base64Encoded: suffix),
                  let stringIDs = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return stringIDs.compactMap { UUID(uuidString: $0) }
        }
        return []
    }

    /// Extra photo URLs in a carousel post — slides 2..N (up to 3 extras
    /// for a 4-photo max).  The PRIMARY photo (slide 1) lives in the
    /// post's regular asset, not in this list.  Returns an empty array
    /// for non-carousel posts (which is most posts), so feed renderers
    /// can branch on `isEmpty` to fall back to the single-photo display.
    var photoCarouselExtraURLs: [URL] {
        guard let caption else { return [] }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        for line in trimmed.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = normalized.uppercased()
            guard upper.hasPrefix(FeedPostKindMarker.photoCarouselPrefix) else { continue }
            let suffix = String(normalized.dropFirst(FeedPostKindMarker.photoCarouselPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !suffix.isEmpty,
                  let data = Data(base64Encoded: suffix),
                  let urls = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return urls.compactMap { URL(string: $0) }
        }
        return []
    }

    static func podcastCaption(from caption: String?, loopVideoURL: URL? = nil) -> String {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var payload: [String] = []
        if !trimmed.isEmpty {
            payload.append(trimmed)
        }
        if let loopVideoURL {
            payload.append("\(FeedPostKindMarker.audioLoopVideoPrefix) \(loopVideoURL.absoluteString)")
        }
        if payload.isEmpty {
            return FeedPostKindMarker.podcastPrefix
        }
        return "\(FeedPostKindMarker.podcastPrefix) \(payload.joined(separator: "\n"))"
    }

    static func musicCaption(
        from caption: String?,
        loopVideoURL: URL? = nil,
        releaseType: MusicReleaseType? = nil,
        tracks: [MusicTrackMetadata] = [],
        releaseDate: Date? = nil,
        recordLabel: String? = nil,
        genre: String? = nil,
        linerNotes: String? = nil,
        musicVideoLinkIDs: [UUID] = []
    ) -> String {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var payload: [String] = []
        if !trimmed.isEmpty {
            payload.append(trimmed)
        }
        if let releaseType {
            payload.append("\(FeedPostKindMarker.musicReleaseTypePrefix) \(releaseType.rawValue)")
        }
        if let loopVideoURL {
            payload.append("\(FeedPostKindMarker.audioLoopVideoPrefix) \(loopVideoURL.absoluteString)")
        }
        if let encodedTracks = encodedMusicTracksPayload(tracks) {
            payload.append("\(FeedPostKindMarker.musicTracksPrefix) \(encodedTracks)")
        }
        if let releaseDate {
            let iso = musicReleaseDateFormatter.string(from: releaseDate)
            payload.append("\(FeedPostKindMarker.musicReleaseDatePrefix) \(iso)")
        }
        if let recordLabel {
            let trimmedLabel = recordLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLabel.isEmpty {
                payload.append("\(FeedPostKindMarker.musicRecordLabelPrefix) \(trimmedLabel)")
            }
        }
        if let genre {
            let trimmedGenre = MusicGenreOption.normalizedValue(from: genre)
            if !trimmedGenre.isEmpty {
                payload.append("\(FeedPostKindMarker.musicGenrePrefix) \(trimmedGenre)")
            }
        }
        if let linerNotes {
            let trimmedNotes = linerNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty,
               let encoded = trimmedNotes.data(using: .utf8)?.base64EncodedString() {
                payload.append("\(FeedPostKindMarker.musicLinerNotesPrefix) \(encoded)")
            }
        }
        if !musicVideoLinkIDs.isEmpty {
            let stringIDs = musicVideoLinkIDs.map { $0.uuidString }
            if let encoded = (try? JSONEncoder().encode(stringIDs))?.base64EncodedString() {
                payload.append("\(FeedPostKindMarker.musicVideoLinksPrefix) \(encoded)")
            }
        }
        if payload.isEmpty {
            return FeedPostKindMarker.musicPrefix
        }
        return "\(FeedPostKindMarker.musicPrefix) \(payload.joined(separator: "\n"))"
    }

    /// Builds a photo-post caption with an optional carousel marker.  The
    /// primary photo lives in the post's regular asset; the extras are
    /// stored as a JSON array of remote URLs in the marker, base64-encoded
    /// to survive the line-based caption parser.  Pass an empty array to
    /// leave the caption marker-less (single-photo posts).
    static func photoCarouselCaption(from caption: String?, extraPhotoURLs: [URL]) -> String {
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // First strip any existing carousel marker from the input so we
        // don't accumulate duplicates when an edit replaces the carousel.
        let cleanBody = strippedPlainCaption(from: trimmed)
        let validURLs = extraPhotoURLs.filter { !$0.absoluteString.isEmpty }
        guard !validURLs.isEmpty else {
            return cleanBody
        }
        let urlStrings = validURLs.map { $0.absoluteString }
        guard let encoded = (try? JSONEncoder().encode(urlStrings))?.base64EncodedString() else {
            return cleanBody
        }
        let markerLine = "\(FeedPostKindMarker.photoCarouselPrefix) \(encoded)"
        if cleanBody.isEmpty {
            return markerLine
        }
        return "\(cleanBody)\n\(markerLine)"
    }

    static func articleCaption(from title: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return FeedPostKindMarker.articlePrefix
        }
        if trimmed.uppercased().hasPrefix(FeedPostKindMarker.articlePrefix) {
            return trimmed
        }
        return "\(FeedPostKindMarker.articlePrefix) \(trimmed)"
    }
}

struct ScrollArticlePayload: Codable, Equatable, Sendable {
    enum BlockKind: String, Codable, CaseIterable, Sendable {
        case paragraph
        case subheadline
        case sectionHeading
    }

    struct Block: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let kind: BlockKind
        let text: String

        private enum CodingKeys: String, CodingKey {
            case id
            case kind
            case text
        }

        init(id: UUID = UUID(), kind: BlockKind, text: String) {
            self.id = id
            self.kind = kind
            self.text = text
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            kind = try container.decode(BlockKind.self, forKey: .kind)
            text = try container.decode(String.self, forKey: .text)
        }
    }

    let headline: String
    let blocks: [Block]
    let coverImageRef: String?
    let coverImageAspectRatio: Double?

    private static let wirePrefix = "[ARTICLE_JSON]"

    private enum CodingKeys: String, CodingKey {
        case headline
        case blocks
        case coverImageRef
        case cover_image_ref
        case coverImageAspectRatio
        case cover_image_aspect_ratio
        case subheadline
        case sectionHeading
        case section_heading
        case body
    }

    var coverImageURL: URL? {
        normalizedRemoteAssetURL(from: coverImageRef, preferredWidth: 1400)
    }

    var combinedBodyText: String {
        blocks
            .map { $0.text }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    var hasLongBody: Bool {
        combinedBodyText.count > 260 || blocks.count > 4
    }

    init(
        headline: String,
        blocks: [Block],
        coverImageRef: String?,
        coverImageAspectRatio: Double?
    ) {
        self.headline = headline
        self.blocks = blocks
        self.coverImageRef = coverImageRef
        self.coverImageAspectRatio = coverImageAspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedHeadline = (try container.decode(String.self, forKey: .headline)).trimmingCharacters(in: .whitespacesAndNewlines)

        let decodedBlocks = try container.decodeIfPresent([Block].self, forKey: .blocks) ?? []

        let legacySubheadline = try container.decodeIfPresent(String.self, forKey: .subheadline)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let legacySectionHeading = (try container.decodeIfPresent(String.self, forKey: .sectionHeading)
            ?? container.decodeIfPresent(String.self, forKey: .section_heading))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let legacyBody = (try container.decodeIfPresent(String.self, forKey: .body) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedBlocks: [Block] = {
            let sanitizedNew = decodedBlocks.compactMap { block -> Block? in
                let trimmedText = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else { return nil }
                return Block(id: block.id, kind: block.kind, text: trimmedText)
            }
            if !sanitizedNew.isEmpty { return sanitizedNew }

            var legacy: [Block] = []
            if let legacySubheadline, !legacySubheadline.isEmpty {
                legacy.append(Block(kind: .subheadline, text: legacySubheadline))
            }
            if let legacySectionHeading, !legacySectionHeading.isEmpty {
                legacy.append(Block(kind: .sectionHeading, text: legacySectionHeading))
            }
            if !legacyBody.isEmpty {
                legacy.append(Block(kind: .paragraph, text: legacyBody))
            }
            return legacy
        }()

        let normalizedCoverRef = (try container.decodeIfPresent(String.self, forKey: .coverImageRef)
            ?? container.decodeIfPresent(String.self, forKey: .cover_image_ref))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let decodedAspectRatio = try container.decodeIfPresent(Double.self, forKey: .coverImageAspectRatio)
            ?? container.decodeIfPresent(Double.self, forKey: .cover_image_aspect_ratio)

        self.headline = decodedHeadline
        self.blocks = normalizedBlocks
        self.coverImageRef = (normalizedCoverRef?.isEmpty ?? true) ? nil : normalizedCoverRef
        self.coverImageAspectRatio = decodedAspectRatio
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(headline, forKey: .headline)
        try container.encode(blocks, forKey: .blocks)
        try container.encodeIfPresent(coverImageRef, forKey: .coverImageRef)
        try container.encodeIfPresent(coverImageAspectRatio, forKey: .coverImageAspectRatio)
    }

    static func encodeToText(
        headline: String,
        blocks: [Block],
        coverImageRef: String? = nil,
        coverImageAspectRatio: Double? = nil
    ) -> String? {
        let normalizedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBlocks = blocks.compactMap { block -> Block? in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Block(id: block.id, kind: block.kind, text: trimmed)
        }
        guard !normalizedHeadline.isEmpty, !normalizedBlocks.isEmpty else { return nil }

        let normalizedCoverRef = coverImageRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ScrollArticlePayload(
            headline: normalizedHeadline,
            blocks: normalizedBlocks,
            coverImageRef: (normalizedCoverRef?.isEmpty ?? true) ? nil : normalizedCoverRef,
            coverImageAspectRatio: coverImageAspectRatio
        )
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return wirePrefix + json
    }

    static func decodeFromText(_ raw: String) -> ScrollArticlePayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(wirePrefix) else { return nil }
        let json = String(trimmed.dropFirst(wirePrefix.count))
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ScrollArticlePayload.self, from: data) else {
            return nil
        }
        guard !payload.headline.isEmpty, !payload.blocks.isEmpty else { return nil }
        return payload
    }
}


struct Moment: Identifiable, Equatable, Codable, Sendable {
    enum MediaType: String, Codable, Sendable {
        case image
        case video
    }

    enum SourceApp: String, Codable, Sendable {
        case scrolls
        case circles
    }

    struct LiveBroadcast: Equatable, Codable, Sendable {
        enum Mode: String, Codable, Sendable {
            case mobile
            case obs
        }

        let id: UUID
        let ownerUserID: UUID
        let playbackURL: String
        let iframePlaybackURL: String?
        let title: String?
        let tipGoal: Decimal?
        let startedAt: Date
        let mode: Mode
        /// Plaintext password — may be nil even for protected streams when the
        /// backend intentionally omits it from viewer-facing responses.
        let viewerPassword: String?
        /// True when the stream requires a viewer password.  Derived from
        /// `has_viewer_password` returned by the backend, or from
        /// `viewerPassword != nil` when that field is available.
        let hasViewerPassword: Bool

        private enum CodingKeys: String, CodingKey {
            case id
            case ownerUserID
            case playbackURL
            case iframePlaybackURL
            case title
            case tipGoal
            case startedAt
            case mode
            case viewerPassword
            case hasViewerPassword
        }

        init(
            id: UUID,
            ownerUserID: UUID,
            playbackURL: String,
            iframePlaybackURL: String? = nil,
            title: String?,
            tipGoal: Decimal? = nil,
            startedAt: Date,
            mode: Mode,
            viewerPassword: String? = nil,
            hasViewerPassword: Bool = false
        ) {
            self.id = id
            self.ownerUserID = ownerUserID
            self.playbackURL = playbackURL
            self.iframePlaybackURL = iframePlaybackURL
            self.title = title
            self.tipGoal = tipGoal
            self.startedAt = startedAt
            self.mode = mode
            self.viewerPassword = viewerPassword
            self.hasViewerPassword = hasViewerPassword || (viewerPassword.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false)
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            ownerUserID = try c.decode(UUID.self, forKey: .ownerUserID)
            playbackURL = try c.decode(String.self, forKey: .playbackURL)
            iframePlaybackURL = try c.decodeIfPresent(String.self, forKey: .iframePlaybackURL)
            title = try c.decodeIfPresent(String.self, forKey: .title)
            tipGoal = try? c.decodeIfPresent(Decimal.self, forKey: .tipGoal)
            startedAt = try c.decode(Date.self, forKey: .startedAt)
            mode = (try? c.decode(Mode.self, forKey: .mode)) ?? .mobile
            viewerPassword = try? c.decodeIfPresent(String.self, forKey: .viewerPassword)
            let explicitBool = try? c.decodeIfPresent(Bool.self, forKey: .hasViewerPassword)
            hasViewerPassword = explicitBool ?? (viewerPassword.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false)
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(ownerUserID, forKey: .ownerUserID)
            try c.encode(playbackURL, forKey: .playbackURL)
            try c.encodeIfPresent(iframePlaybackURL, forKey: .iframePlaybackURL)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(tipGoal, forKey: .tipGoal)
            try c.encode(startedAt, forKey: .startedAt)
            try c.encode(mode, forKey: .mode)
            try c.encodeIfPresent(viewerPassword, forKey: .viewerPassword)
            try c.encode(hasViewerPassword, forKey: .hasViewerPassword)
        }
    }

    let id: UUID
    let userID: UUID
    let username: String
    let displayName: String
    let avatarRef: String?
    let videoRef: String
    var mediaType: MediaType = .video
    var sourceApp: SourceApp = .scrolls
    var circleMomentID: UUID? = nil
    let createdAt: Date
    let expiresAt: Date
    let liveBroadcast: LiveBroadcast?
    var viewCount: Int = 0
    var viewedBy: [UUID]? = nil
    var hasViewed: Bool = false

    var isExpired: Bool { expiresAt <= Date() }

    var isLive: Bool {
        guard let liveBroadcast else { return false }
        let playback = liveBroadcast.playbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let iframe = (liveBroadcast.iframePlaybackURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !playback.isEmpty || !iframe.isEmpty
    }

    var livePlaybackURL: URL? {
        guard let liveBroadcast else { return nil }
        let raw = liveBroadcast.playbackURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var liveIframePlaybackURL: URL? {
        guard let liveBroadcast else { return nil }
        let raw = (liveBroadcast.iframePlaybackURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var resolvedAvatarURL: URL? {
        normalizedRemoteAssetURL(from: avatarRef, preferredWidth: 120)
    }
}

struct PhotoPreview: Codable, Equatable, Sendable {
    let fileURL: URL
    let aspectRatio: CGFloat
    let assetIdentifier: String?

    var platformImage: PlatformImage? {
        // Keep this accessor local-only so it never performs synchronous network I/O on the main thread.
        guard fileURL.isFileURL else { return nil }
        #if canImport(UIKit) || canImport(AppKit)
        return PlatformImage(contentsOfFile: fileURL.path)
        #else
        return nil
        #endif
    }
}

struct VideoPreview: Codable, Equatable, Sendable {
    let url: URL
    let aspectRatio: CGFloat
    let assetIdentifier: String?
}

enum ScrollPostFontStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case silverGarden
    case modak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .silverGarden:
            return "Signature"
        case .modak:
            return "Modak"
        }
    }

    var fontName: String? {
        switch self {
        case .original:
            return nil
        case .silverGarden:
            return "SilverGarden-Regular"
        case .modak:
            return "Modak-Regular"
        }
    }
}

struct TextPreview: Codable, Equatable, Sendable {
    let fileURL: URL?
    let cachedText: String
    let fontStyle: ScrollPostFontStyle

    var text: String {
        if let url = fileURL,
           let stored = try? String(contentsOf: url, encoding: .utf8),
           !stored.isEmpty {
            return stored
        }
        return cachedText
    }

    enum CodingKeys: String, CodingKey {
        case fileURL
        case cachedText
        case fontStyle
    }

    init(fileURL: URL?, cachedText: String, fontStyle: ScrollPostFontStyle = .original) {
        self.fileURL = fileURL
        self.cachedText = cachedText
        self.fontStyle = fontStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        cachedText = try container.decode(String.self, forKey: .cachedText)
        fontStyle = try container.decodeIfPresent(ScrollPostFontStyle.self, forKey: .fontStyle) ?? .original
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fileURL, forKey: .fileURL)
        try container.encode(cachedText, forKey: .cachedText)
        try container.encode(fontStyle, forKey: .fontStyle)
    }
}

enum MediaPreview: Codable, Equatable, Sendable {
    case photo(PhotoPreview)
    case video(VideoPreview)
    case text(TextPreview)

    private enum CodingKeys: String, CodingKey {
        case type
        case photo
        case video
        case text
    }

    private enum MediaType: String, Codable {
        case photo
        case video
        case text
    }

    var aspectRatio: CGFloat {
        switch self {
        case let .photo(photo):
            return photo.aspectRatio
        case let .video(video):
            return video.aspectRatio
        case .text:
            return 1
        }
    }

    var photoPreview: PhotoPreview? {
        if case let .photo(photo) = self {
            return photo
        }
        return nil
    }

    var videoPreview: VideoPreview? {
        if case let .video(video) = self {
            return video
        }
        return nil
    }

    var textPreview: TextPreview? {
        if case let .text(preview) = self {
            return preview
        }
        return nil
    }

    static func photo(from url: URL, aspectRatio: CGFloat, assetIdentifier: String? = nil) -> MediaPreview {
        .photo(PhotoPreview(fileURL: url, aspectRatio: max(aspectRatio, 0.1), assetIdentifier: assetIdentifier))
    }

    static func video(url: URL, aspectRatio: CGFloat, assetIdentifier: String? = nil) -> MediaPreview {
        .video(VideoPreview(url: url, aspectRatio: max(aspectRatio, 0.1), assetIdentifier: assetIdentifier))
    }

    static func text(_ text: String, fontStyle: ScrollPostFontStyle = .original) -> MediaPreview {
        let fileURL = try? TextStorage.saveText(text)
        return .text(TextPreview(fileURL: fileURL, cachedText: text, fontStyle: fontStyle))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MediaType.self, forKey: .type)
        switch type {
        case .photo:
            let photo = try container.decode(PhotoPreview.self, forKey: .photo)
            self = .photo(photo)
        case .video:
            let video = try container.decode(VideoPreview.self, forKey: .video)
            self = .video(video)
        case .text:
            let text = try container.decode(TextPreview.self, forKey: .text)
            self = .text(text)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .photo(let photo):
            try container.encode(MediaType.photo, forKey: .type)
            try container.encode(photo, forKey: .photo)
        case .video(let video):
            try container.encode(MediaType.video, forKey: .type)
            try container.encode(video, forKey: .video)
        case .text(let text):
            try container.encode(MediaType.text, forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}

enum ScrollsInterfaceStyle: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case cheetah

    var id: Self { self }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .cheetah: return "Cheetah"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        case .cheetah:
            return .dark
        }
    }

    var usesCheetahBackground: Bool {
        self == .cheetah
    }
}

struct ColorComponents: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

struct GradientSpec: Codable, Equatable, Sendable {
    let colors: [ColorComponents]
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    init(colors: [ColorComponents], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }
}

extension GradientSpec {
    func linearGradient() -> LinearGradient {
        let swiftUIColor = colors.compactMap { components in
            Color(platformColor: PlatformColor.from(components))
        }
        guard !swiftUIColor.isEmpty else {
            return LinearGradient(colors: [.gray], startPoint: startPoint, endPoint: endPoint)
        }
        return LinearGradient(colors: swiftUIColor, startPoint: startPoint, endPoint: endPoint)
    }
}

extension PlatformColor {
    static func from(_ components: ColorComponents) -> PlatformColor {
        #if canImport(UIKit)
        return PlatformColor(
            red: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: CGFloat(components.alpha)
        )
        #elseif canImport(AppKit)
        return PlatformColor(
            calibratedRed: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: CGFloat(components.alpha)
        )
        #endif
    }

    func toComponents() -> ColorComponents? {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        #elseif canImport(AppKit)
        guard let deviceColor = self.usingColorSpace(.deviceRGB) else { return nil }
        let red = deviceColor.redComponent
        let green = deviceColor.greenComponent
        let blue = deviceColor.blueComponent
        let alpha = deviceColor.alphaComponent
        #else
        return nil
        #endif
        return ColorComponents(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}

extension Color {
    init(platformColor: PlatformColor) {
        #if canImport(UIKit)
        self.init(platformColor)
        #elseif canImport(AppKit)
        self.init(platformColor)
        #else
        self = .clear
        #endif
    }
}

extension PlatformImage {
    static func gradient(with colors: [PlatformColor], size: CGSize = CGSize(width: 800, height: 1200)) -> PlatformImage {
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: nil
            ) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        #elseif canImport(AppKit)
        let image = PlatformImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        guard let context = NSGraphicsContext.current?.cgContext else { return image }
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: colors.map { $0.cgColor } as CFArray,
            locations: nil
        ) else {
            return image
        }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: size.height),
            options: []
        )
        return image
        #endif
    }
}

struct UserProfile: Identifiable, Equatable, Hashable, Codable, Sendable {
    struct ParentalControls: Codable, Hashable, Sendable {
        var isEnabled: Bool
        var canUseCirclesMessaging: Bool
        var canTagLocations: Bool
        var hidesSensitiveContent: Bool

        static let none = ParentalControls(
            isEnabled: false,
            canUseCirclesMessaging: true,
            canTagLocations: true,
            hidesSensitiveContent: false
        )

        static func defaults(forAge age: Int) -> ParentalControls {
            guard age < 18 else { return .none }
            return ParentalControls(
                isEnabled: true,
                canUseCirclesMessaging: age >= 16,
                canTagLocations: age >= 16,
                hidesSensitiveContent: true
            )
        }
    }

    enum AccountType: String, Codable, Sendable, CaseIterable {
        case personal
        case business
    }

    let id: UUID
    let username: String
    let displayName: String
    let bio: String
    let keywords: [String]
    let gradientSpec: GradientSpec
    let avatarImageData: Data?
    let avatarRef: String?
    let avatarProvider: String?
    let avatarBucket: String?
    let avatarObjectKey: String?
    let isVerified: Bool
    let isFounder: Bool
    let isPrivateAccount: Bool
    let accountType: AccountType
    let subscriptionPlan: String?
    let pinnedPostID: UUID?
    let signatureRef: String?
    let avatarVideoRef: String?
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
    let parentalControls: ParentalControls

    var accentGradient: LinearGradient {
        gradientSpec.linearGradient()
    }

    var avatarImage: PlatformImage? {
        guard let data = avatarImageData else { return nil }
        return PlatformImage(data: data)
    }

    var remoteAvatarURL: URL? {
        MediaURLResolver.resolve(
            provider: avatarProvider, bucket: avatarBucket, objectKey: avatarObjectKey, legacyURL: nil
        )
    }

    /// Best available avatar URL: structured R2 ref first, then legacy `avatarRef` string.
    var resolvedAvatarURL: URL? {
        if let structured = remoteAvatarURL { return structured }
        return normalizedRemoteAssetURL(from: avatarRef, preferredWidth: 120)
    }


    var avatarVideoURL: URL? {
        if let remote = normalizedRemoteAssetURL(from: avatarVideoRef) {
            return remote
        }
        let trimmed = avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed)
    }

    var initials: String {
        let components = displayName.split(separator: " ")
        let initials = components.prefix(2).compactMap { $0.first }
        return initials.map { String($0) }.joined()
    }

    /// Returns a copy of this profile with the given avatar image data substituted in.
    /// Used to persist a freshly-downloaded avatar without recreating all other fields.
    func withAvatarImageData(_ data: Data?) -> UserProfile {
        UserProfile(
            id: id, username: username, displayName: displayName, bio: bio,
            keywords: keywords, gradientSpec: gradientSpec,
            avatarImageData: data,
            avatarRef: avatarRef, avatarProvider: avatarProvider,
            avatarBucket: avatarBucket, avatarObjectKey: avatarObjectKey,
            isVerified: isVerified, isFounder: isFounder,
            isPrivateAccount: isPrivateAccount, accountType: accountType,
            subscriptionPlan: subscriptionPlan, pinnedPostID: pinnedPostID,
            signatureRef: signatureRef,
            avatarVideoRef: avatarVideoRef, websiteURL: websiteURL,
            venmoURL: venmoURL, cashAppURL: cashAppURL,
            spotifyURL: spotifyURL, appleMusicURL: appleMusicURL,
            businessLocation: businessLocation, businessPhone: businessPhone,
            homeCity: homeCity, dateOfBirth: dateOfBirth,
            ageAssuranceCompletedAt: ageAssuranceCompletedAt,
            parentalControls: parentalControls
        )
    }

    var ageYears: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    var isMinor: Bool {
        guard let ageYears else { return false }
        return ageYears < 18
    }

    private static let crossBadgeTokens: [String] = [
        "✝️",
        "✝",
        "✞",
        "✟",
        "☩",
        "☦️",
        "☦",
        "✠",
        "✙",
        "✚"
    ]

    private static let starBadgeTokens: [String] = [
        "✡️",
        "✡",
        "🔯",
        "✡︎"
    ]

    private static let founderBadgeUsernames: Set<String> = [
        "primadonvino",
        "scrolls",
        "gelanella",
        "ovispictures",
        "amerigomagazine",
        "provostodaro"
    ]

    var isFounderBadgeAccount: Bool {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return Self.founderBadgeUsernames.contains(normalized)
    }

    var hasFounderAccess: Bool {
        isFounder || isFounderBadgeAccount
    }

    var showsFounderScrollBadge: Bool {
        hasFounderAccess
    }

    var showsBlueCheckBadge: Bool {
        isVerified || isFounderBadgeAccount
    }

    var showsGoldBadge: Bool {
        isGoldTier || isFounderBadgeAccount
    }

    var isGoldTier: Bool {
        let normalized = (subscriptionPlan ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "02" || normalized == "scrolls.gold.monthly"
    }

    var hasCrossBadge: Bool {
        let text = bio
        return Self.crossBadgeTokens.contains { text.contains($0) }
    }

    var hasStarBadge: Bool {
        let text = bio
        return Self.starBadgeTokens.contains { text.contains($0) }
    }

    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
        case bio
        case keywords
        case gradientSpec
        case avatarImageData
        case avatarRef
        case avatarProvider
        case avatarBucket
        case avatarObjectKey
        case isVerified
        case isFounder
        case isPrivateAccount
        case accountType
        case subscriptionPlan
        case pinnedPostID
        case signatureRef
        case avatarVideoRef
        case websiteURL
        case venmoURL
        case cashAppURL
        case spotifyURL
        case appleMusicURL
        case businessLocation
        case businessPhone
        case homeCity
        case dateOfBirth
        case ageAssuranceCompletedAt
        case parentalControls
    }

    init(
        id: UUID,
        username: String,
        displayName: String,
        bio: String,
        keywords: [String],
        gradientSpec: GradientSpec,
        avatarImageData: Data?,
        avatarRef: String? = nil,
        avatarProvider: String? = nil,
        avatarBucket: String? = nil,
        avatarObjectKey: String? = nil,
        isVerified: Bool,
        isFounder: Bool,
        isPrivateAccount: Bool = false,
        accountType: AccountType = .personal,
        subscriptionPlan: String? = nil,
        pinnedPostID: UUID? = nil,
        signatureRef: String? = nil,
        avatarVideoRef: String? = nil,
        websiteURL: String? = nil,
        venmoURL: String? = nil,
        cashAppURL: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil,
        businessLocation: String? = nil,
        businessPhone: String? = nil,
        homeCity: String? = nil,
        dateOfBirth: Date? = nil,
        ageAssuranceCompletedAt: Date? = nil,
        parentalControls: ParentalControls = .none
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.keywords = keywords
        self.gradientSpec = gradientSpec
        self.avatarImageData = avatarImageData
        self.avatarRef = avatarRef
        self.avatarProvider = avatarProvider
        self.avatarBucket = avatarBucket
        self.avatarObjectKey = avatarObjectKey
        self.isVerified = isVerified
        self.isFounder = isFounder
        self.isPrivateAccount = isPrivateAccount
        self.accountType = accountType
        self.subscriptionPlan = subscriptionPlan
        self.pinnedPostID = pinnedPostID
        self.signatureRef = signatureRef
        self.avatarVideoRef = avatarVideoRef
        self.websiteURL = websiteURL
        self.venmoURL = venmoURL
        self.cashAppURL = cashAppURL
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
        self.businessLocation = businessLocation
        self.businessPhone = businessPhone
        self.homeCity = homeCity
        self.dateOfBirth = dateOfBirth
        self.ageAssuranceCompletedAt = ageAssuranceCompletedAt
        self.parentalControls = parentalControls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decode(String.self, forKey: .displayName)
        bio = try container.decode(String.self, forKey: .bio)
        keywords = try container.decode([String].self, forKey: .keywords)
        gradientSpec = try container.decode(GradientSpec.self, forKey: .gradientSpec)
        avatarImageData = try container.decodeIfPresent(Data.self, forKey: .avatarImageData)
        avatarRef = try container.decodeIfPresent(String.self, forKey: .avatarRef)
        avatarProvider = try container.decodeIfPresent(String.self, forKey: .avatarProvider)
        avatarBucket = try container.decodeIfPresent(String.self, forKey: .avatarBucket)
        avatarObjectKey = try container.decodeIfPresent(String.self, forKey: .avatarObjectKey)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isFounder = try container.decodeIfPresent(Bool.self, forKey: .isFounder) ?? false
        isPrivateAccount = try container.decodeIfPresent(Bool.self, forKey: .isPrivateAccount) ?? false
        accountType = try container.decodeIfPresent(AccountType.self, forKey: .accountType) ?? .personal
        subscriptionPlan = try container.decodeIfPresent(String.self, forKey: .subscriptionPlan)
        pinnedPostID = try container.decodeIfPresent(UUID.self, forKey: .pinnedPostID)
        signatureRef = try container.decodeIfPresent(String.self, forKey: .signatureRef)
        avatarVideoRef = try container.decodeIfPresent(String.self, forKey: .avatarVideoRef)
        websiteURL = try container.decodeIfPresent(String.self, forKey: .websiteURL)
        venmoURL = try container.decodeIfPresent(String.self, forKey: .venmoURL)
        cashAppURL = try container.decodeIfPresent(String.self, forKey: .cashAppURL)
        spotifyURL = try container.decodeIfPresent(String.self, forKey: .spotifyURL)
        appleMusicURL = try container.decodeIfPresent(String.self, forKey: .appleMusicURL)
        businessLocation = try container.decodeIfPresent(String.self, forKey: .businessLocation)
        businessPhone = try container.decodeIfPresent(String.self, forKey: .businessPhone)
        homeCity = try container.decodeIfPresent(String.self, forKey: .homeCity)
        dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        ageAssuranceCompletedAt = try container.decodeIfPresent(Date.self, forKey: .ageAssuranceCompletedAt)
        parentalControls = try container.decodeIfPresent(ParentalControls.self, forKey: .parentalControls) ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(bio, forKey: .bio)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(gradientSpec, forKey: .gradientSpec)
        try container.encodeIfPresent(avatarImageData, forKey: .avatarImageData)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(avatarProvider, forKey: .avatarProvider)
        try container.encodeIfPresent(avatarBucket, forKey: .avatarBucket)
        try container.encodeIfPresent(avatarObjectKey, forKey: .avatarObjectKey)
        try container.encode(isVerified, forKey: .isVerified)
        try container.encode(isFounder, forKey: .isFounder)
        try container.encode(isPrivateAccount, forKey: .isPrivateAccount)
        try container.encode(accountType, forKey: .accountType)
        try container.encodeIfPresent(subscriptionPlan, forKey: .subscriptionPlan)
        try container.encodeIfPresent(pinnedPostID, forKey: .pinnedPostID)
        try container.encodeIfPresent(signatureRef, forKey: .signatureRef)
        try container.encodeIfPresent(avatarVideoRef, forKey: .avatarVideoRef)
        try container.encodeIfPresent(websiteURL, forKey: .websiteURL)
        try container.encodeIfPresent(venmoURL, forKey: .venmoURL)
        try container.encodeIfPresent(cashAppURL, forKey: .cashAppURL)
        try container.encodeIfPresent(spotifyURL, forKey: .spotifyURL)
        try container.encodeIfPresent(appleMusicURL, forKey: .appleMusicURL)
        try container.encodeIfPresent(businessLocation, forKey: .businessLocation)
        try container.encodeIfPresent(businessPhone, forKey: .businessPhone)
        try container.encodeIfPresent(homeCity, forKey: .homeCity)
        try container.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try container.encodeIfPresent(ageAssuranceCompletedAt, forKey: .ageAssuranceCompletedAt)
        try container.encode(parentalControls, forKey: .parentalControls)
    }

    func with(
        id: UUID? = nil,
        username: String? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        keywords: [String]? = nil,
        avatarImage: PlatformImage? = nil,
        avatarRef: String? = nil,
        isVerified: Bool? = nil,
        isFounder: Bool? = nil,
        isPrivateAccount: Bool? = nil,
        accountType: AccountType? = nil,
        subscriptionPlan: String? = nil,
        pinnedPostID: UUID? = nil,
        signatureRef: String? = nil,
        avatarVideoRef: String? = nil,
        websiteURL: String? = nil,
        venmoURL: String? = nil,
        cashAppURL: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil,
        businessLocation: String? = nil,
        businessPhone: String? = nil,
        homeCity: String? = nil,
        dateOfBirth: Date? = nil,
        ageAssuranceCompletedAt: Date? = nil,
        parentalControls: ParentalControls? = nil
    ) -> UserProfile {
        UserProfile(
            id: id ?? self.id,
            username: username ?? self.username,
            displayName: displayName ?? self.displayName,
            bio: bio ?? self.bio,
            keywords: keywords ?? self.keywords,
            gradientSpec: gradientSpec,
            avatarImageData: avatarImage.map { MediaStorage.compressedAvatarData(from: $0) } ?? avatarImageData,
            avatarRef: avatarRef ?? self.avatarRef,
            avatarProvider: self.avatarProvider,
            avatarBucket: self.avatarBucket,
            avatarObjectKey: self.avatarObjectKey,
            isVerified: isVerified ?? self.isVerified,
            isFounder: isFounder ?? self.isFounder,
            isPrivateAccount: isPrivateAccount ?? self.isPrivateAccount,
            accountType: accountType ?? self.accountType,
            subscriptionPlan: subscriptionPlan ?? self.subscriptionPlan,
            pinnedPostID: pinnedPostID ?? self.pinnedPostID,
            signatureRef: signatureRef ?? self.signatureRef,
            avatarVideoRef: avatarVideoRef ?? self.avatarVideoRef,
            websiteURL: websiteURL ?? self.websiteURL,
            venmoURL: venmoURL ?? self.venmoURL,
            cashAppURL: cashAppURL ?? self.cashAppURL,
            spotifyURL: spotifyURL ?? self.spotifyURL,
            appleMusicURL: appleMusicURL ?? self.appleMusicURL,
            businessLocation: businessLocation ?? self.businessLocation,
            businessPhone: businessPhone ?? self.businessPhone,
            homeCity: homeCity ?? self.homeCity,
            dateOfBirth: dateOfBirth ?? self.dateOfBirth,
            ageAssuranceCompletedAt: ageAssuranceCompletedAt ?? self.ageAssuranceCompletedAt,
            parentalControls: parentalControls ?? self.parentalControls
        )
    }
}

private func normalizedRemoteAssetURL(from rawValue: String?, preferredWidth: Int? = nil) -> URL? {
    let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !trimmed.isEmpty else { return nil }
    if let url = URL(string: trimmed), url.scheme != nil {
        return preferredRemoteAssetURL(from: url, preferredWidth: preferredWidth)
    }
    let supabaseBase = UserDefaults.standard.string(forKey: "scrolls.supabase.url")?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let backendBase = UserDefaults.standard.string(forKey: "scrolls.backend.baseURL")?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let base = (supabaseBase?.isEmpty == false ? supabaseBase : backendBase)?
        .trimmingCharacters(in: CharacterSet(charactersIn: "/")) else {
        return nil
    }
    let prefix = trimmed.hasPrefix("/") ? "" : "/"
    guard let resolved = URL(string: "\(base)\(prefix)\(trimmed)") else {
        return nil
    }
    return preferredRemoteAssetURL(from: resolved, preferredWidth: preferredWidth)
}

private func preferredRemoteAssetURL(from sourceURL: URL, preferredWidth: Int?) -> URL {
    _ = preferredWidth
    if let legacySupabase = legacySupabaseStorageLocation(from: sourceURL) {
        return MediaURLResolver.resolve(
            provider: MediaProvider.r2.rawValue,
            bucket: legacySupabase.bucket,
            objectKey: legacySupabase.objectKey
        ) ?? sourceURL
    }
    return sourceURL
}

private func legacySupabaseStorageLocation(from sourceURL: URL) -> (bucket: String, objectKey: String)? {
    let path = sourceURL.path
    // Match both direct-object and image-render Supabase storage paths:
    //   /storage/v1/object/public/<bucket>/<key>
    //   /storage/v1/render/image/public/<bucket>/<key>
    let markers = ["/storage/v1/object/public/", "/storage/v1/render/image/public/"]
    guard let markerRange = markers.lazy.compactMap({ path.range(of: $0) }).first else {
        return nil
    }

    let suffix = String(path[markerRange.upperBound...])
    guard !suffix.isEmpty, let slashIndex = suffix.firstIndex(of: "/") else { return nil }
    let bucket = String(suffix[..<slashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    // Strip any query parameters that Supabase image transforms may append
    // (e.g. ?width=400&resize=cover) — the R2 CDN serves the original asset.
    let rawKey = String(suffix[suffix.index(after: slashIndex)...])
    let objectKey = rawKey
        .components(separatedBy: "?").first?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !bucket.isEmpty, !objectKey.isEmpty else { return nil }
    return (bucket, objectKey)
}

struct ScrollsState: Codable, Sendable {
    let posts: [FeedPost]
    let following: [UserProfile]
    let currentUser: UserProfile
    let notifications: [AppNotification]
    let unreadCircleMessageIDs: [UUID]
    let circles: [CircleGroup]
    let followers: [UserProfile]
    let followRelations: [UUID: [UUID]]
    let pinnedPostIDs: [UUID: UUID]
    let postDrafts: [PostDraft]
    let adSubmissionPostIDs: [UUID]
    /// Cached profiles of users seen but not in following/followers/post-authors.
    /// Used to warm-start the profile registry on resume so returning users don't
    /// see loading states on profiles they've already viewed.
    let profileCache: [UserProfile]
    /// Persisted cursor for the users-delta sync endpoint.  Surviving restarts
    /// means the expensive full-directory seed only runs once per device, not on
    /// every cold start.  Keyed by account UUID so multi-account setups each
    /// track their own version.
    let profileDeltaVersionByUserID: [UUID: String]

    enum CodingKeys: String, CodingKey {
        case posts
        case following
        case currentUser
        case notifications
        case unreadCircleMessageIDs
        case circles
        case followers
        case followRelations
        case pinnedPostIDs
        case postDrafts
        case adSubmissionPostIDs
        case profileCache
        case profileDeltaVersionByUserID
    }

    init(posts: [FeedPost], following: [UserProfile], currentUser: UserProfile, notifications: [AppNotification] = [], unreadCircleMessageIDs: [UUID] = [], circles: [CircleGroup] = [], followers: [UserProfile] = [], followRelations: [UUID: [UUID]] = [:], pinnedPostIDs: [UUID: UUID] = [:], postDrafts: [PostDraft] = [], adSubmissionPostIDs: [UUID] = [], profileCache: [UserProfile] = [], profileDeltaVersionByUserID: [UUID: String] = [:]) {
        self.posts = posts
        self.following = following
        self.currentUser = currentUser
        self.notifications = notifications
        self.unreadCircleMessageIDs = unreadCircleMessageIDs
        self.circles = circles
        self.followers = followers
        self.followRelations = followRelations
        self.pinnedPostIDs = pinnedPostIDs
        self.postDrafts = postDrafts
        self.adSubmissionPostIDs = adSubmissionPostIDs
        self.profileCache = profileCache
        self.profileDeltaVersionByUserID = profileDeltaVersionByUserID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posts = try container.decode([FeedPost].self, forKey: .posts)
        following = try container.decode([UserProfile].self, forKey: .following)
        currentUser = try container.decode(UserProfile.self, forKey: .currentUser)
        notifications = try container.decodeIfPresent([AppNotification].self, forKey: .notifications) ?? []
        unreadCircleMessageIDs = try container.decodeIfPresent([UUID].self, forKey: .unreadCircleMessageIDs) ?? []
        circles = try container.decodeIfPresent([CircleGroup].self, forKey: .circles) ?? []
        followers = try container.decodeIfPresent([UserProfile].self, forKey: .followers) ?? []
        let followData = try container.decodeIfPresent([String: [UUID]].self, forKey: .followRelations) ?? [:]
        followRelations = Dictionary(uniqueKeysWithValues: followData.compactMap { key, value in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
        let pinnedData = try container.decodeIfPresent([String: UUID].self, forKey: .pinnedPostIDs) ?? [:]
        pinnedPostIDs = Dictionary(uniqueKeysWithValues: pinnedData.compactMap { key, value in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
        postDrafts = try container.decodeIfPresent([PostDraft].self, forKey: .postDrafts) ?? []
        adSubmissionPostIDs = try container.decodeIfPresent([UUID].self, forKey: .adSubmissionPostIDs) ?? []
        profileCache = try container.decodeIfPresent([UserProfile].self, forKey: .profileCache) ?? []
        let deltaData = try container.decodeIfPresent([String: String].self, forKey: .profileDeltaVersionByUserID) ?? [:]
        profileDeltaVersionByUserID = Dictionary(uniqueKeysWithValues: deltaData.compactMap { key, value in
            guard let uuid = UUID(uuidString: key) else { return nil }
            return (uuid, value)
        })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(posts, forKey: .posts)
        try container.encode(following, forKey: .following)
        try container.encode(currentUser, forKey: .currentUser)
        try container.encode(notifications, forKey: .notifications)
        try container.encode(unreadCircleMessageIDs, forKey: .unreadCircleMessageIDs)
        try container.encode(circles, forKey: .circles)
        try container.encode(followers, forKey: .followers)
        let followData = Dictionary(uniqueKeysWithValues: followRelations.map { (key, value) in (key.uuidString, value) })
        try container.encode(followData, forKey: .followRelations)
        let pinnedData = Dictionary(uniqueKeysWithValues: pinnedPostIDs.map { (key, value) in (key.uuidString, value) })
        try container.encode(pinnedData, forKey: .pinnedPostIDs)
        try container.encode(postDrafts, forKey: .postDrafts)
        try container.encode(adSubmissionPostIDs, forKey: .adSubmissionPostIDs)
        try container.encode(profileCache, forKey: .profileCache)
        let deltaData = Dictionary(uniqueKeysWithValues: profileDeltaVersionByUserID.map { (key, value) in (key.uuidString, value) })
        try container.encode(deltaData, forKey: .profileDeltaVersionByUserID)
    }
}

struct PostDraft: Identifiable, Codable, Equatable, Sendable {
    struct ArticleDraft: Codable, Equatable, Sendable {
        let headline: String
        let blocks: [ScrollArticlePayload.Block]
        let coverPhoto: PhotoPreview?
        let locationCity: String?
    }

    enum Payload: Codable, Equatable, Sendable {
        case media(MediaPreview)
        case text(String)
        case article(ArticleDraft)

        enum CodingKeys: String, CodingKey {
            case type
            case media
            case text
            case article
        }

        enum Kind: String, Codable {
            case media
            case text
            case article
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(Kind.self, forKey: .type)
            switch kind {
            case .media:
                self = .media(try container.decode(MediaPreview.self, forKey: .media))
            case .text:
                self = .text(try container.decode(String.self, forKey: .text))
            case .article:
                self = .article(try container.decode(ArticleDraft.self, forKey: .article))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .media(let media):
                try container.encode(Kind.media, forKey: .type)
                try container.encode(media, forKey: .media)
            case .text(let text):
                try container.encode(Kind.text, forKey: .type)
                try container.encode(text, forKey: .text)
            case .article(let article):
                try container.encode(Kind.article, forKey: .type)
                try container.encode(article, forKey: .article)
            }
        }
    }

    let id: UUID
    let payload: Payload
    let caption: String?
    let locationCity: String?
    let textFontStyle: ScrollPostFontStyle?
    var ownerUserID: UUID?
    let createdAt: Date
    let scheduledAt: Date?

    var isScheduled: Bool { scheduledAt != nil }
}

struct AppNotification: Identifiable, Codable, Hashable, Sendable {
    enum NotificationType: String, Codable {
        case commentLiked
        case commentReplied
        case rescrolled
        case followed
        case general
        case mention
        case circleMessage = "circle_message"
        case circleVoiceMessage = "circle_voice_message"
        case circleSharedPost = "circle_shared_post"
        /// Fired when another user tags this user as a collaborator on
        /// a post they just published.  The actorID is the post author,
        /// the objectID is the post.
        case collaborated
    }

    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let recipientUserID: UUID?
    let actorID: UUID?
    let objectID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case message
        case timestamp
        case isRead
        case recipientUserID
        case actorID
        case objectID
    }

    init(
        id: UUID,
        type: NotificationType,
        title: String,
        message: String,
        timestamp: Date,
        isRead: Bool,
        recipientUserID: UUID? = nil,
        actorID: UUID? = nil,
        objectID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.recipientUserID = recipientUserID
        self.actorID = actorID
        self.objectID = objectID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(NotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        recipientUserID = try container.decodeIfPresent(UUID.self, forKey: .recipientUserID)
        actorID = try container.decodeIfPresent(UUID.self, forKey: .actorID)
        objectID = try container.decodeIfPresent(UUID.self, forKey: .objectID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isRead, forKey: .isRead)
        try container.encodeIfPresent(recipientUserID, forKey: .recipientUserID)
        try container.encodeIfPresent(actorID, forKey: .actorID)
        try container.encodeIfPresent(objectID, forKey: .objectID)
    }
}

struct CircleMember: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let profileID: UUID
    var status: CircleMemberStatus

    var isActiveMember: Bool {
        status == .member
    }
}

enum CircleMemberStatus: String, Codable, Sendable {
    case member
    case invited
    case pending
    case declined
}

enum MessageSendStatus: String, Codable, Sendable, Equatable {
    case sending
    case sent
    case failed
}

struct CircleVoiceMessagePayload: Codable, Equatable, Sendable {
    let url: String?
    let provider: String?
    let bucket: String?
    let objectKey: String?
    let durationSeconds: Int?
    let expiresAt: Date?
}

struct CircleMessage: Identifiable, Equatable, Codable, Sendable {
    static let voicePayloadPrefix = "[CIRCLE_VOICE_BASE64]"
    static let photoPayloadPrefix = "[CIRCLE_PHOTO]"

    let id: UUID
    let userID: UUID
    let encryptedText: String
    let timestamp: Date
    let sharedPostID: UUID?
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
    let photoPreviewData: Data?
    let expiresAt: Date?
    var sendStatus: MessageSendStatus?

    enum CodingKeys: String, CodingKey {
        case id
        case userID
        case encryptedText
        case timestamp
        case sharedPostID
        case voiceProvider
        case voiceBucket
        case voiceObjectKey
        case voiceDurationSeconds
        case photoProvider
        case photoBucket
        case photoObjectKey
        case photoContentType
        case photoWidth
        case photoHeight
        case photoPreviewData
        case expiresAt
        case sendStatus
    }

    init(
        id: UUID,
        userID: UUID,
        plainText: String,
        timestamp: Date,
        sharedPostID: UUID? = nil,
        voiceProvider: String? = nil,
        voiceBucket: String? = nil,
        voiceObjectKey: String? = nil,
        voiceDurationSeconds: Int? = nil,
        photoProvider: String? = nil,
        photoBucket: String? = nil,
        photoObjectKey: String? = nil,
        photoContentType: String? = nil,
        photoWidth: Int? = nil,
        photoHeight: Int? = nil,
        photoPreviewData: Data? = nil,
        expiresAt: Date? = nil,
        circleID: UUID? = nil,
        sendStatus: MessageSendStatus? = nil
    ) {
        self.id = id
        self.userID = userID
        if plainText.isEmpty {
            encryptedText = ""
        } else if let encrypted = try? CircleEncryption.shared.encrypt(plainText, circleID: circleID) {
            encryptedText = encrypted
        } else {
            encryptedText = ""
        }
        self.timestamp = timestamp
        self.sharedPostID = sharedPostID
        self.voiceProvider = voiceProvider
        self.voiceBucket = voiceBucket
        self.voiceObjectKey = voiceObjectKey
        self.voiceDurationSeconds = voiceDurationSeconds
        self.photoProvider = photoProvider
        self.photoBucket = photoBucket
        self.photoObjectKey = photoObjectKey
        self.photoContentType = photoContentType
        self.photoWidth = photoWidth
        self.photoHeight = photoHeight
        self.photoPreviewData = photoPreviewData
        self.expiresAt = expiresAt
        self.sendStatus = sendStatus
    }

    init(
        id: UUID,
        userID: UUID,
        encryptedText: String,
        timestamp: Date,
        sharedPostID: UUID? = nil,
        voiceProvider: String? = nil,
        voiceBucket: String? = nil,
        voiceObjectKey: String? = nil,
        voiceDurationSeconds: Int? = nil,
        photoProvider: String? = nil,
        photoBucket: String? = nil,
        photoObjectKey: String? = nil,
        photoContentType: String? = nil,
        photoWidth: Int? = nil,
        photoHeight: Int? = nil,
        photoPreviewData: Data? = nil,
        expiresAt: Date? = nil,
        sendStatus: MessageSendStatus? = nil
    ) {
        self.id = id
        self.userID = userID
        self.encryptedText = encryptedText
        self.timestamp = timestamp
        self.sharedPostID = sharedPostID
        self.voiceProvider = voiceProvider
        self.voiceBucket = voiceBucket
        self.voiceObjectKey = voiceObjectKey
        self.voiceDurationSeconds = voiceDurationSeconds
        self.photoProvider = photoProvider
        self.photoBucket = photoBucket
        self.photoObjectKey = photoObjectKey
        self.photoContentType = photoContentType
        self.photoWidth = photoWidth
        self.photoHeight = photoHeight
        self.photoPreviewData = photoPreviewData
        self.expiresAt = expiresAt
        self.sendStatus = sendStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(UUID.self, forKey: .userID)
        encryptedText = try container.decode(String.self, forKey: .encryptedText)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sharedPostID = try container.decodeIfPresent(UUID.self, forKey: .sharedPostID)
        voiceProvider = try container.decodeIfPresent(String.self, forKey: .voiceProvider)
        voiceBucket = try container.decodeIfPresent(String.self, forKey: .voiceBucket)
        voiceObjectKey = try container.decodeIfPresent(String.self, forKey: .voiceObjectKey)
        voiceDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .voiceDurationSeconds)
        photoProvider = try container.decodeIfPresent(String.self, forKey: .photoProvider)
        photoBucket = try container.decodeIfPresent(String.self, forKey: .photoBucket)
        photoObjectKey = try container.decodeIfPresent(String.self, forKey: .photoObjectKey)
        photoContentType = try container.decodeIfPresent(String.self, forKey: .photoContentType)
        photoWidth = try container.decodeIfPresent(Int.self, forKey: .photoWidth)
        photoHeight = try container.decodeIfPresent(Int.self, forKey: .photoHeight)
        photoPreviewData = try container.decodeIfPresent(Data.self, forKey: .photoPreviewData)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        sendStatus = try container.decodeIfPresent(MessageSendStatus.self, forKey: .sendStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(encryptedText, forKey: .encryptedText)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(sharedPostID, forKey: .sharedPostID)
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
        try container.encodeIfPresent(photoPreviewData, forKey: .photoPreviewData)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(sendStatus, forKey: .sendStatus)
    }

    var text: String {
        CircleEncryption.shared.decrypt(encryptedText, circleID: nil)
    }

    func text(for circleID: UUID) -> String {
        CircleEncryption.shared.decrypt(encryptedText, circleID: circleID)
    }

    var isVoiceMessage: Bool {
        if voiceObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        return voicePayload()?.url?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || voicePayload()?.objectKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var hasVoiceAttachment: Bool {
        isVoiceMessage || voiceDurationSeconds != nil
    }

    var isPhotoMessage: Bool {
        guard let key = photoObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key.lowercased() != "uploading" else {
            return false
        }
        return true
    }

    var hasPhotoAttachment: Bool {
        isPhotoMessage
            || photoPreviewData != nil
            || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(Self.photoPayloadPrefix)
    }

    func photoURL() -> URL? {
        guard let key = photoObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key.lowercased() != "uploading" else {
            return nil
        }
        if key.hasPrefix("http://") || key.hasPrefix("https://") {
            return URL(string: key)
        }
        return URL(string: "\(MediaURLResolver.r2CDNBase)/\(key)")
    }

    var voiceURL: URL? {
        voiceURL(for: nil)
    }

    func voiceURL(for circleID: UUID?) -> URL? {
        guard let key = voiceObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            guard let payload = voicePayload(for: circleID) else { return nil }
            if let url = payload.url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
                return URL(string: url)
            }
            if let objectKey = payload.objectKey?.trimmingCharacters(in: .whitespacesAndNewlines), !objectKey.isEmpty {
                return URL(string: "\(MediaURLResolver.r2CDNBase)/\(objectKey)")
            }
            return nil
        }
        return URL(string: "\(MediaURLResolver.r2CDNBase)/\(key)")
    }

    func voiceDurationSeconds(for circleID: UUID?) -> Int? {
        voiceDurationSeconds ?? voicePayload(for: circleID)?.durationSeconds
    }

    func voicePayload(for circleID: UUID? = nil) -> CircleVoiceMessagePayload? {
        let renderedText: String
        if let circleID {
            renderedText = text(for: circleID)
        } else if encryptedText.hasPrefix("plain:") {
            renderedText = String(encryptedText.dropFirst("plain:".count))
        } else {
            renderedText = text
        }
        let trimmed = renderedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(Self.voicePayloadPrefix) else { return nil }
        let encoded = trimmed.dropFirst(Self.voicePayloadPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return try? JSONDecoder().decode(CircleVoiceMessagePayload.self, from: data)
    }

    static func voicePayloadText(
        url: String?,
        provider: String?,
        bucket: String?,
        objectKey: String?,
        durationSeconds: Int?,
        expiresAt: Date?
    ) -> String {
        let payload = CircleVoiceMessagePayload(
            url: url,
            provider: provider,
            bucket: bucket,
            objectKey: objectKey,
            durationSeconds: durationSeconds,
            expiresAt: expiresAt
        )
        guard let data = try? JSONEncoder().encode(payload) else {
            return Self.voicePayloadPrefix
        }
        return "\(Self.voicePayloadPrefix) \(data.base64EncodedString())"
    }
}

struct TypingParticipant: Identifiable, Equatable, Codable, Hashable, Sendable {
    let id: UUID
    var username: String
    var displayName: String
    var avatarRef: String?
    var updatedAt: Date

    var displayLabel: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !username.isEmpty { return username }
        return "Someone"
    }
}


struct CircleGroup: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var avatarImageData: Data? = nil
    var avatarRef: String? = nil
    var members: [CircleMember]
    var messages: [CircleMessage]
    let createdAt: Date

    var avatarImage: PlatformImage? {
        guard let data = avatarImageData else { return nil }
        return PlatformImage(data: data)
    }

    var memberCount: Int {
        members.filter { $0.status == .member }.count
    }

    func containsMember(_ profile: UserProfile) -> Bool {
        members.contains(where: { $0.profileID == profile.id && $0.status == .member })
    }

    func status(for profile: UserProfile) -> CircleMemberStatus? {
        members.first(where: { $0.profileID == profile.id })?.status
    }
}

struct PublicCircleSearchResult: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var summary: String?
    var category: String?
    var tags: [String]
    var avatarRef: String?
    var memberCount: Int
    var creator: UserProfile?
    var createdAt: Date?

    var subtitle: String {
        let categoryText = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        let members = memberCount == 1 ? "1 member" : "\(memberCount) members"
        if let categoryText, !categoryText.isEmpty {
            return "\(categoryText) · \(members)"
        }
        return members
    }
}

extension CircleGroup {
    private var nonDeclinedMemberIDs: Set<UUID> {
        Set(
            members
                .filter { $0.status != .declined }
                .map(\.profileID)
        )
    }

    func isDirectConversation(between first: UUID, and second: UUID) -> Bool {
        let memberIDs = nonDeclinedMemberIDs
        let targetIDs = Set([first, second])
        let activeCount = members.filter { $0.status == .member }.count
        return memberIDs == targetIDs && activeCount == 2
    }

    var isOneOnOneConversation: Bool {
        nonDeclinedMemberIDs.count == 2 &&
        members.filter { $0.status == .member }.count == 2
    }
}
