#if canImport(UIKit)
import UIKit
import UserNotifications
#endif
import AVFoundation
import Combine
import Foundation
import Photos
import PhotosUI
import Security
import SwiftUI
import UniformTypeIdentifiers


private struct GlobalFeedCache: Codable, Sendable {
    let posts: [FeedPost]
    let savedAt: Date
}

private struct PendingDeletionRequest: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case post
        case rescroll
    }

    let kind: Kind
    let postID: UUID
    let authorID: UUID
    let createdAt: Date
    // Optional media/cover object keys forwarded to the backend so it can
    // clean up R2/Cloudflare assets even after the DB row is gone.
    var assetProvider: String? = nil
    var assetBucket: String? = nil
    var assetObjectKey: String? = nil
    var coverProvider: String? = nil
    var coverBucket: String? = nil
    var coverObjectKey: String? = nil

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(postID)
        hasher.combine(authorID)
    }

    static func == (lhs: PendingDeletionRequest, rhs: PendingDeletionRequest) -> Bool {
        lhs.kind == rhs.kind && lhs.postID == rhs.postID && lhs.authorID == rhs.authorID
    }
}

private struct PendingDeletionQueue: Codable, Sendable {
    let deletions: [PendingDeletionRequest]
    let savedAt: Date
}

private struct PendingMediaPostCache: Codable, Sendable {
    let posts: [FeedPost]
    let savedAt: Date
}

private struct PendingFollowSyncOperation: Codable, Sendable, Equatable {
    let followerID: UUID
    let followeeID: UUID
    let isFollowing: Bool
    let createdAt: Date
    let retryCount: Int
}

private struct PendingFollowSyncQueue: Codable, Sendable {
    let operations: [PendingFollowSyncOperation]
    let savedAt: Date
}

private struct PendingBackendWriteOperation: Codable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable {
        case commentCreate
        case commentDelete
        case commentLikeCreate
        case commentLikeDelete
        case rescrollCreate
        case rescrollDelete
        case circleMessage
        case circleClear
        case circleDelete
        case adCuratedPostPublish
        case adCuratedSlotUpdate
        case notificationsMarkAllRead
        case notificationsDeleteRead
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    let retryCount: Int
    let userID: UUID
    let postID: UUID?
    let authorID: UUID?
    let commentID: UUID?
    let body: String?
    let parentCommentID: UUID?
    let originalPostID: UUID?
    let rescrollPostID: UUID?
    let circleID: UUID?
    let messageID: UUID?
    let encryptedText: String?
    let messageTimestamp: Date?
}

private struct PendingBackendWriteQueue: Codable, Sendable {
    let operations: [PendingBackendWriteOperation]
    let savedAt: Date
}

private enum BackendWritePreflightError: LocalizedError {
    case missingSessionToken(operationName: String)

    var errorDescription: String? {
        switch self {
        case .missingSessionToken(let operationName):
            return "No active session token is available for \(operationName)."
        }
    }
}

private enum CommentRefreshResult {
    case refreshed
    case skippedCached
    case skippedUnavailable
    case failed(Error?)
}

struct FeedDebugStatus: Equatable {
    struct PublishStep: Identifiable, Equatable {
        let id: UUID
        let recordedAt: Date
        let postID: String
        let stage: String
        let status: String
        let detail: String
        let error: String?
        let authPreflight: String?
        let recovery: String?
        let retry: String?
    }
    struct FeedStep: Identifiable, Equatable {
        let id: UUID
        let recordedAt: Date
        let stage: String
        let status: String
        let detail: String
        let error: String?
        let authPreflight: String?
    }
    struct SyncStep: Identifiable, Equatable {
        let id: UUID
        let recordedAt: Date
        let targetID: String
        let stage: String
        let status: String
        let detail: String
        let error: String?
        let authPreflight: String?
    }

    var backendResolvedUserID: UUID?
    var authTokenPresent: Bool = false
    var refreshTokenPresent: Bool = false
    var tokenIssuer: String = "Unknown"
    var tokenIssuerHost: String = "Unknown"
    var tokenProjectHost: String = "Unknown"
    var tokenAlgorithm: String = "Unknown"
    var tokenSubject: String = "Unknown"
    var tokenSubjectScope: String = "Unknown"
    var tokenExpiry: String = "Unknown"
    var tokenHostMatch: String = "Unknown"
    var resolvedSessionUsername: String = "Unknown"
    var lastAuthFailure: String = "None"
    var lastAuthFailureContext: String = "Not run yet"
    var lastAuthRecoveryAction: String = "Not run yet"
    var lastAuthFailureAt: Date?
    var authTokenSetCount: Int = 0
    var authTokenClearCount: Int = 0
    var refreshTokenSetCount: Int = 0
    var refreshTokenClearCount: Int = 0
    var hardSessionClearCount: Int = 0
    var lastHardSessionClearSource: String = "Not run yet"
    var lastHardSessionClearAt: Date?
    var refreshAttemptCount: Int = 0
    var refreshSuccessCount: Int = 0
    var refreshFailureCount: Int = 0
    var refreshLastFailureReason: String = "None"
    var refreshLastFailureCode: String = "None"
    var refreshLastFailureTerminal: String = "Unknown"
    var refreshLastFailureSessionRevoked: String = "Unknown"
    var refreshLastAttemptSource: String = "Not run yet"
    var refreshLastTokenAgeMS: String = "Unknown"
    var refreshLastAttemptAt: Date?
    var refreshLastSuccessAt: Date?
    var refreshLastFailureAt: Date?
    var authSelfHealStartupTriggerCount: Int = 0
    var authSelfHealForegroundTriggerCount: Int = 0
    var authSelfHealSuccessCount: Int = 0
    var authSelfHealFailureCount: Int = 0
    var authMutationRatePerMinute: String = "Not run yet"
    var lastAuthSessionMutation: String = "Not run yet"
    var lastAuthSessionMutationAt: Date?
    var authGateWaitMS: String = "Not run yet"
    var refreshTokenFingerprint: String = "Not available"
    var refreshOutcome: String = "Not run yet"
    var sessionRecordSource: String = "Not run yet"
    var bootstrapCandidateCount: String = "Not run yet"
    var bootstrapExpectedUserID: String = "Not available"
    var bootstrapFallbackUsed: String = "Not run yet"
    var authPersistenceTrail: String = "No auth persistence events yet."
    var lastIdentityResolveStatus: String = "Not run yet"
    var lastFeedStage: String = "Not run yet"
    var lastFeedFetchStatus: String = "Not run yet"
    var lastFeedDetail: String = "Not available"
    var lastFeedError: String = "None"
    var lastFeedAuthPreflight: String = "Not run yet"
    var lastFeedMergeSummary: String = "Not run yet"
    var lastFeedVisibilitySummary: String = "Not run yet"
    var lastFeedFetchAt: Date?
    var lastFeedRequestDurationMS: String = "Not run yet"
    var lastFeedMergeDurationMS: String = "Not run yet"
    var feedPageRequestCount: Int = 0
    var feedShortPageCount: Int = 0
    var feedShortPageRate: String = "0/0 (0%)"
    var lastFeedRenderHitchCount: Int = 0
    var lastFeedRenderHitchMS: String = "Not observed"
    var lastFeedRenderHitchAt: Date?
    var rateLimitEndpoint: String = "Not available"
    var rateLimitMethod: String = "Not available"
    var rateLimitStatusCode: String = "Not available"
    var rateLimitRetryAfter: String = "Not available"
    var rateLimitLimit: String = "Not available"
    var rateLimitRemaining: String = "Not available"
    var rateLimitReset: String = "Not available"
    var rateLimitRequestID: String = "Not available"
    var rateLimitErrorCode: String = "Not available"
    var rateLimitMessage: String = "Not available"
    var rateLimitObservedAt: Date?
    var rateLimitClientCooldownActive: Bool = false
    var rateLimitClientCooldownRemaining: String = "0s"
    var rateLimitClientBackoffUntil: Date?
    var rateLimitClientConsecutive429Count: Int = 0
    var lastCommentSyncTargetID: String = "Not available"
    var lastCommentSyncStage: String = "Not run yet"
    var lastCommentSyncStatus: String = "Not run yet"
    var lastCommentSyncDetail: String = "Not available"
    var lastCommentSyncError: String = "None"
    var lastCommentSyncAuthPreflight: String = "Not run yet"
    var lastCommentSyncAt: Date?
    var lastCommentLikeSyncTargetID: String = "Not available"
    var lastCommentLikeSyncStage: String = "Not run yet"
    var lastCommentLikeSyncStatus: String = "Not run yet"
    var lastCommentLikeSyncDetail: String = "Not available"
    var lastCommentLikeSyncError: String = "None"
    var lastCommentLikeSyncAuthPreflight: String = "Not run yet"
    var lastCommentLikeSyncAt: Date?
    var lastAdSyncTargetID: String = "Not available"
    var lastAdSyncStage: String = "Not run yet"
    var lastAdSyncStatus: String = "Not run yet"
    var lastAdSyncDetail: String = "Not available"
    var lastAdSyncError: String = "None"
    var lastAdSyncAuthPreflight: String = "Not run yet"
    var lastAdSyncAt: Date?
    var lastRescrollSyncTargetID: String = "Not available"
    var lastRescrollSyncStage: String = "Not run yet"
    var lastRescrollSyncStatus: String = "Not run yet"
    var lastRescrollSyncDetail: String = "Not available"
    var lastRescrollSyncError: String = "None"
    var lastRescrollSyncAuthPreflight: String = "Not run yet"
    var lastRescrollSyncAt: Date?
    var lastProfileSyncTargetID: String = "Not available"
    var lastProfileSyncStage: String = "Not run yet"
    var lastProfileSyncStatus: String = "Not run yet"
    var lastProfileSyncDetail: String = "Not available"
    var lastProfileSyncError: String = "None"
    var lastProfileSyncAuthPreflight: String = "Not run yet"
    var lastProfileSyncAt: Date?
    var lastCircleMessageSyncTargetID: String = "Not available"
    var lastCircleMessageSyncStage: String = "Not run yet"
    var lastCircleMessageSyncStatus: String = "Not run yet"
    var lastCircleMessageSyncDetail: String = "Not available"
    var lastCircleMessageSyncError: String = "None"
    var lastCircleMessageSyncAuthPreflight: String = "Not run yet"
    var lastCircleMessageSyncAt: Date?
    var pushRegistrationStatus: String = "Not run yet"
    var pushRegistrationDetail: String = "Not available"
    var pushRegistrationUpdatedAt: Date?
    var lastPublishPostID: String = "Not available"
    var lastPublishStage: String = "Not run yet"
    var lastPublishStatus: String = "Not run yet"
    var lastPublishDetail: String = "Not available"
    var lastPublishError: String = "None"
    var lastPublishAuthPreflight: String = "Not run yet"
    var lastPublishRecovery: String = "Not attempted"
    var lastPublishRetry: String = "Not scheduled"
    var lastPublishAt: Date?
    var publishSteps: [PublishStep] = []
    var feedSteps: [FeedStep] = []
    var commentSteps: [SyncStep] = []
    var commentLikeSteps: [SyncStep] = []
    var adSteps: [SyncStep] = []
    var rescrollSteps: [SyncStep] = []
    var profileSteps: [SyncStep] = []
    var circleMessageSteps: [SyncStep] = []
}

@MainActor
final class ScrollsFeedViewModel: ObservableObject {
    private struct SpamTextRecord {
        let text: String
        let at: Date
    }
    private struct CommentDeliveryTrace {
        var localAt: Date?
        var backendAckAt: Date?
        var remoteSeenAt: Date?
        var lastError: String?
    }
    private struct CommentLikeOverride {
        var isLiked: Bool
        var localUpdatedAt: Date
        var backendAckAt: Date?
        var lastMismatchLoggedAt: Date?
    }
    private struct PostPublishDeliveryState {
        var pendingAt: Date
        var failedMessage: String?
    }
    private struct AuthMutationRateSample {
        let at: Date
        let accessSet: Int
        let accessClear: Int
        let refreshSet: Int
        let refreshClear: Int
    }
    enum PostPublishSyncStatus: Equatable {
        case syncing
        case failed
        case synced
    }
    enum PostSyncIndicatorState: Equatable {
        case ready
        case recovering
        case blocked
    }
    struct PostSyncIndicator: Equatable {
        var state: PostSyncIndicatorState
        var summary: String
        var detail: String
        var updatedAt: Date
    }
    enum MediaPreparationError: LocalizedError {
        case unsupportedType
        case unableToLoadVideo
        case unableToLoadImage
        case unableToCreatePreview
        case videoUploadsRequireSubscription
        case videoDurationExceeded(maxSeconds: Int, tierLabel: String)
        case videoTooLarge(maxMB: Int, tierLabel: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedType:
                return "That media type is not supported yet."
            case .unableToLoadVideo:
                return "We couldn't load that video. Try selecting it again."
            case .unableToLoadImage:
                return "We couldn't load that photo. Try selecting it again."
            case .unableToCreatePreview:
                return "We couldn't prepare that media for posting."
            case .videoUploadsRequireSubscription:
                return "Video uploads are available on Blue and Gold subscriptions."
            case .videoDurationExceeded(let maxSeconds, let tierLabel):
                return "\(tierLabel) uploads support videos up to \(maxSeconds)s. Please trim your clip."
            case .videoTooLarge(let maxMB, let tierLabel):
                return "\(tierLabel) upload limit is \(maxMB)MB. Please compress or trim this video."
            }
        }
    }

    enum CuratedAdUploadError: LocalizedError {
        case videoTooLarge(maxMB: Int)
        case photoTooLarge(maxMB: Int)
        case uploadTimedOut(seconds: Int)

        var errorDescription: String? {
            switch self {
            case .videoTooLarge(let maxMB):
                return "Video is too large for curated ads. Please keep it under \(maxMB)MB."
            case .photoTooLarge(let maxMB):
                return "Photo is too large for curated ads. Please keep it under \(maxMB)MB."
            case .uploadTimedOut(let seconds):
                return "Upload timed out after \(seconds)s. Please try a shorter/smaller clip."
            }
        }
    }

    enum SplashAdUploadError: LocalizedError {
        case invalidMedia
        case missingWebsiteURL
        case videoTooLarge(maxMB: Int)
        case missingAuthorization
        case uploadFailed

        var errorDescription: String? {
            switch self {
            case .invalidMedia:
                return "Splash ads must be uploaded from a video."
            case .missingWebsiteURL:
                return "Add a website link to publish this splash ad."
            case .videoTooLarge(let maxMB):
                return "Video is too large for splash ads. Please keep it under \(maxMB)MB."
            case .missingAuthorization:
                return "Missing authorization. Please log out and back in, then retry."
            case .uploadFailed:
                return "Could not publish splash ad right now."
            }
        }
    }

    enum ProfileHeroMediaPreference: String, Codable {
        case photo
        case video
    }

    private enum PostPublishError: LocalizedError {
        case timeout(seconds: Int)

        var errorDescription: String? {
            switch self {
            case .timeout(let seconds):
                return "Post upload timed out after \(seconds)s."
            }
        }
    }

    enum CuratedSlotSaveState: Equatable, Sendable {
        case idle
        case syncing
        case succeeded
        case failed(String)
    }

    enum CuratedSlotDraftValidationResult: Equatable, Sendable {
        case valid
        case invalid(message: String)
    }


    enum LiveStreamMode: String, CaseIterable, Sendable, Identifiable {
        case mobile
        case obs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mobile: return "Go Live From Phone"
            case .obs: return "Connect OBS"
            }
        }

        var subtitle: String {
            switch self {
            case .mobile: return "Start from your phone and share your live playback URL."
            case .obs: return "Use ingest URL + stream key in OBS for desktop livestreaming."
            }
        }

        var backendMode: BackendLiveStreamSession.Mode {
            switch self {
            case .mobile: return .mobile
            case .obs: return .obs
            }
        }
    }

    struct LiveStreamSessionState: Equatable, Sendable, Identifiable {
        let id: UUID
        let ownerUserID: UUID
        let mode: LiveStreamMode
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
        /// Plaintext password — may be nil for protected streams when the
        /// backend intentionally omits it from viewer-facing responses.
        let viewerPassword: String?
        /// True when the stream requires a viewer password (derived from
        /// backend `has_viewer_password` flag or `viewerPassword != nil`).
        let hasViewerPassword: Bool

        var isActive: Bool {
            status.lowercased() == "active" && endedAt == nil
        }
    }

    struct LiveStreamCommentState: Equatable, Sendable, Identifiable {
        let id: UUID
        let sessionID: UUID
        let user: UserProfile
        let body: String
        let createdAt: Date
    }

    enum LiveStartDebugStep: String, CaseIterable, Sendable, Identifiable {
        case sessionRequest = "session_request"
        case sessionCreated = "session_created"
        case sessionMapped = "session_mapped"
        case publisherPrepare = "publisher_prepare"
        case publisherConnect = "publisher_connect"
        case publisherPublishing = "publisher_publishing"
        case ready = "ready"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sessionRequest: return "Create live session"
            case .sessionCreated: return "Session response"
            case .sessionMapped: return "Apply session locally"
            case .publisherPrepare: return "Prepare phone publisher"
            case .publisherConnect: return "Connect ingest"
            case .publisherPublishing: return "RTMP publishing"
            case .ready: return "Live ready"
            }
        }
    }

    enum LiveStartDebugStatus: String, Sendable {
        case pending
        case running
        case succeeded
        case failed
        case skipped
    }

    struct LiveStartDebugEntry: Identifiable, Sendable {
        let step: LiveStartDebugStep
        var status: LiveStartDebugStatus
        var detail: String
        var updatedAt: Date

        var id: String { step.rawValue }
    }

    @Published private(set) var liveStreamCommentsBySessionID: [UUID: [LiveStreamCommentState]] = [:]
    @Published private(set) var activeLiveStreamSession: LiveStreamSessionState?
    @Published private(set) var isPhoneLiveBroadcasting = false
    /// The Metal preview view wired to the live broadcaster's mixer pipeline.
    /// Non-nil only while the mixer is running.  Typed as UIView so callers
    /// don't need to import HaishinKit.
    var phoneBroadcasterPreviewView: UIView? {
        #if canImport(HaishinKit) && canImport(RTMPHaishinKit)
        return livePhoneBroadcaster.mixerPreviewView
        #else
        return nil
        #endif
    }

    /// Toggles between front and back camera while the phone live stream is active.
    func flipLiveCamera() async {
        await livePhoneBroadcaster.flipCamera()
    }
    @Published private(set) var liveBroadcastDebugState = "idle"
    @Published private(set) var liveBroadcastDebugDetail = "Publisher idle"
    @Published private(set) var liveBroadcastEncoderDebugLine = "encoder=idle"
    @Published private(set) var liveStartDebugTimeline: [LiveStartDebugEntry] = []
    @Published var liveStreamErrorMessage: String?
    /// Posts the current user has chosen to hide locally — the
    /// lightweight escape hatch when they don't want to block the
    /// author outright.  Stored in UserDefaults so the choice survives
    /// app restarts.  Filtered out of every feed render.  Apple's UGC
    /// guideline (1.2) lists "hide/mute" as one of the four expected
    /// safety affordances alongside report, block, and clear
    /// turnaround.
    @Published private(set) var hiddenPostIDs: Set<UUID> = {
        let stored = UserDefaults.standard.array(forKey: "scrolls.moderation.hiddenPostIDs") as? [String] ?? []
        return Set(stored.compactMap { UUID(uuidString: $0) })
    }()
    /// True when iOS reports `.notDetermined` for notification
    /// authorization and we haven't yet shown the user a contextual
    /// pre-prompt.  When the view layer sees this flip to true, it
    /// presents an in-app alert explaining what notifications they'll
    /// get; only after the user taps "Enable" do we hit the real iOS
    /// auth API.  Apple's review notes have started flagging apps that
    /// call `requestAuthorization` cold without context.
    @Published var shouldShowPushPrePrompt: Bool = false
    @Published private(set) var liveStreamKickedSessionIDs: Set<UUID> = []
    @Published private(set) var posts: [FeedPost]
    @Published private(set) var following: [UserProfile]
    @Published var currentUser: UserProfile
    @Published var notifications: [AppNotification] {
        didSet { scheduleAppIconBadgeRefresh() }
    }
    @Published private(set) var isLoadingMoreNotifications = false
    @Published var circles: [CircleGroup]
    @Published private(set) var moments: [Moment] = []
    @Published private(set) var isLoadingMoments = false
    @Published var isMomentCapturePresented = false
    @Published var momentPostError: String?
    @Published private(set) var postDrafts: [PostDraft]
    @Published private(set) var adSubmissionPostIDs: Set<UUID>
    @Published private(set) var adSubmissionsByPostID: [UUID: BackendAdSubmission]
    @Published private(set) var deliveredAdPosts: [FeedPost]
    @Published private(set) var curatedAdSlotIDs: [UUID?] = [nil, nil, nil]
    @Published private(set) var curatedAdSlotSaveState: CuratedSlotSaveState = .idle
    @Published private(set) var adReviewQueue: [BackendAdSubmission]
    @Published private(set) var isLoadingAdReviewQueue = false
    @Published private(set) var postReportQueue: [BackendPostReport]
    @Published private(set) var isLoadingPostReportQueue = false
    /// Founder/admin queues for the three other report tables.  Populated
    /// from the unified moderation hub view; never touched in normal user
    /// flows.  isPostReportReviewAdmin gates all writes.
    @Published private(set) var profileReportQueue: [BackendProfileReport] = []
    @Published private(set) var isLoadingProfileReportQueue = false
    @Published private(set) var liveStreamReportQueue: [BackendLiveStreamReport] = []
    @Published private(set) var isLoadingLiveStreamReportQueue = false
    @Published private(set) var contentReportQueue: [BackendContentReportRecord] = []
    @Published private(set) var isLoadingContentReportQueue = false
    /// User IDs the current user has blocked. Posts from these users are hidden
    /// from all feeds and their profiles show a "blocked" state.
    @Published private(set) var blockedUserIDs: Set<UUID> = []
    @Published private(set) var pendingFeedPostCount = 0
    @Published private(set) var isFeedTimelineLazyLoading = false
    @Published private(set) var lastFeedTimelineLazyLoadErrorAt: Date?
    /// True while at least one post is being uploaded to the backend.
    @Published private(set) var isUploadingPost: Bool = false
    /// Brief success message shown in the feed after a post upload completes. Clears automatically.
    @Published private(set) var postUploadSuccessBanner: String? = nil
    @Published private(set) var followers: [UserProfile]
    @Published private(set) var pendingFollowRequests: [UserProfile]
    @Published private(set) var unreadCircleMessageIDs: Set<UUID> {
        didSet { scheduleAppIconBadgeRefresh() }
    }
    @Published private(set) var typingParticipantsByCircleID: [UUID: [TypingParticipant]] = [:]
    @Published private(set) var debugStatus = FeedDebugStatus()
    @Published private(set) var isSwitchingAccounts = false
    @Published private(set) var accountSwitchDebugLine = "idle"
    @Published private(set) var postSyncIndicator = PostSyncIndicator(
        state: .recovering,
        summary: "Checking sync readiness",
        detail: "Startup checks in progress.",
        updatedAt: Date()
    )
    @Published private(set) var startupProfileFetchDebugLine = "startup_profile_fetch=idle"
    @Published var moderationErrorMessage: String?
    @Published var postLimitPromptMessage: String?
    private var followRelations: [UUID: Set<UUID>]
    private var pinnedPostIDs: [UUID: UUID]
    private var profileRegistry: [UUID: UserProfile]
    private var profileWriteVersionsByID: [UUID: Date] = [:]
    private var profileLastRefreshedAtByID: [UUID: Date] = [:]
    private var signatureImageCache: [UUID: PlatformImage] = [:]
    private var circleMessageSendHistory: [UUID: [Date]] = [:]
    private var dirtyCircleIDs: Set<UUID> = []
    private var pendingCircleSaveTask: Task<Void, Never>?
    private var pendingCircleBackendSyncTask: Task<Void, Never>?
    private var typingPresenceTasks: [UUID: Task<Void, Never>] = [:]
    private var typingClearTasks: [UUID: Task<Void, Never>] = [:]
    private var currentlyTypingCircleIDs: Set<UUID> = []
    private var lastTypingSignalAtByCircleID: [UUID: Date] = [:]
    private var pendingStateSaveTask: Task<Void, Never>?
    private var pendingPublishRetryTasks: [UUID: Task<Void, Never>] = [:]
    private var inFlightBackendPublishPostIDs: Set<UUID> = []
    private var followSyncFlushTask: Task<Void, Never>?
    private var backendWriteFlushTask: Task<Void, Never>?
    private var backendPollingTask: Task<Void, Never>?
    private var realtimeFeedSyncTask: Task<Void, Never>?
    private var realtimeSocialSyncTask: Task<Void, Never>?
    private var realtimeCommentRefreshTask: Task<Void, Never>?
    private var realtimeCircleRefreshTask: Task<Void, Never>?
    private var realtimeCommentRefreshPostIDs: Set<UUID> = []
    private var realtimeFeedSyncNeedsAnotherPass = false
    private var realtimeSocialSyncNeedsAnotherPass = false
    private var realtimeCircleRefreshNeedsAnotherPass = false
    private var backendSyncTick = 0
    private var lastLiveMomentsSnapshotRefreshAt: Date = .distantPast
    private var backendSyncInFlight = false
    private var queuedBackendSyncRequest: PendingBackendSyncRequest?
    /// Set to true while an alternate app icon is being applied.
    /// saveState() checks this flag and skips debounced writes during the window,
    /// preventing continuous filesystem pressure (realtime sync + polling every
    /// 450ms–3s) from holding SpringBoard's icon-file write in POSIX 35 EAGAIN.
    /// Immediate saves are always honoured regardless of this flag.
    var iconChangePending: Bool = false
    private var scheduledPublishingTask: Task<Void, Never>?
    private var isRealtimeSyncPaused = false
    private let backendClient = ScrollsBackendClient()
    private let livePhoneBroadcaster = LivePhoneBroadcaster()
    private var broadcasterStateCancellable: AnyCancellable?
    private var broadcasterEncoderCancellable: AnyCancellable?
    private var broadcasterRetryTask: Task<Void, Never>?
    private var liveHeartbeatTask: Task<Void, Never>?
    private var broadcasterRetryCount = 0
    private var isStoppingPhoneLivePublisherIntentionally = false
    private var notificationDigestIndex: [String: UUID] = [:]
    private var deferredNotifications: [DeferredNotificationItem] = []
    private var notificationActorHistory: [String: [Date]] = [:]
    private var liveStreamCommentFetchInFlightSessionIDs: Set<UUID> = []
    private var invalidPushTokens: Set<String> = []
    private var pendingRemotePosts: [FeedPost] = []
    private var pendingDeletedPostIDs: Set<UUID> = []
    private var listenedCircleVoiceMessageIDs: Set<UUID> = []
    private var lastDeletedPostTombstoneSweepAt: Date = .distantPast
    private var trustedTimelinePostIDs: Set<UUID> = []
    private var trustedTimelinePostOrder: [UUID] = []
    private var pendingDeletionQueue: [PendingDeletionRequest] = []
    /// Diagnostic ring-buffer of recent delete-RPC outcomes.  Captures
    /// whether the backend actually accepted each delete, what error came
    /// back if it didn't, and when the attempt happened.  Surfaced in the
    /// debug panel so we can tell — without server logs — whether a "this
    /// should be deleted" post got a successful response or kept failing.
    /// Kept at 24 entries so we have visibility across multiple deletion
    /// rounds without growing unbounded.
    @Published private(set) var deletionAttemptLog: [DeletionAttemptRecord] = []
    private static let deletionAttemptLogMaxEntries = 24

    struct DeletionAttemptRecord: Identifiable, Equatable {
        let id = UUID()
        let postID: UUID
        let attemptedAt: Date
        let outcome: Outcome
        let detail: String

        enum Outcome: String, Equatable {
            case success
            case failure
        }
    }

    private func recordDeletionAttempt(postID: UUID, outcome: DeletionAttemptRecord.Outcome, detail: String) {
        let record = DeletionAttemptRecord(
            postID: postID,
            attemptedAt: Date(),
            outcome: outcome,
            detail: detail
        )
        deletionAttemptLog.append(record)
        if deletionAttemptLog.count > Self.deletionAttemptLogMaxEntries {
            deletionAttemptLog.removeFirst(deletionAttemptLog.count - Self.deletionAttemptLogMaxEntries)
        }
    }

    /// Human-readable rollup of the pending deletion queue for the debug
    /// panel.  Includes count, oldest age, and per-entry detail.
    func pendingDeletionQueueDebugSnapshot() -> String {
        guard !pendingDeletionQueue.isEmpty else {
            return "Queue empty — all deletions drained successfully."
        }
        let now = Date()
        let header = "Queue length: \(pendingDeletionQueue.count). Each line: <post-id-prefix> <kind> queued <age>:"
        let lines = pendingDeletionQueue.map { request -> String in
            let age = max(0, Int(now.timeIntervalSince(request.createdAt)))
            let ageStr: String
            if age < 60 { ageStr = "\(age)s ago" }
            else if age < 3600 { ageStr = "\(age / 60)m ago" }
            else { ageStr = "\(age / 3600)h ago" }
            let prefix = request.postID.uuidString.prefix(8)
            return "  • \(prefix) \(request.kind) queued \(ageStr)"
        }
        return ([header] + lines).joined(separator: "\n")
    }

    /// Human-readable rollup of the deletion attempt log for the debug
    /// panel.  Tells us at a glance whether the backend has been accepting
    /// our delete RPCs or rejecting them.
    func deletionAttemptDebugSnapshot() -> String {
        guard !deletionAttemptLog.isEmpty else {
            return "No deletion attempts since launch."
        }
        let now = Date()
        let lines = deletionAttemptLog.suffix(12).reversed().map { record -> String in
            let age = max(0, Int(now.timeIntervalSince(record.attemptedAt)))
            let ageStr: String
            if age < 60 { ageStr = "\(age)s" }
            else if age < 3600 { ageStr = "\(age / 60)m" }
            else { ageStr = "\(age / 3600)h" }
            let prefix = record.postID.uuidString.prefix(8)
            return "  • \(prefix) \(record.outcome.rawValue.uppercased()) \(ageStr) ago — \(record.detail)"
        }
        return lines.joined(separator: "\n")
    }

    /// Force-fires a delete RPC for the given post, bypassing the local
    /// "already marked deleted" cache.  Use from the debug panel or a
    /// retry affordance when a post you previously deleted still appears
    /// on someone else's feed (proof the backend never actually deleted
    /// it).  Idempotent — the backend's deletePost handler handles
    /// "row already gone" by writing a tombstone and cleaning related
    /// rows so even repeated forced retries are safe.
    func forceBackendRedelete(postID: UUID, authorID: UUID) {
        let request = PendingDeletionRequest(
            kind: .post,
            postID: postID,
            authorID: authorID,
            createdAt: Date()
        )
        // Don't dedup against the queue — we WANT this to fire even if a
        // previous identical entry is still in the queue (it might be
        // stuck for an auth reason that's since cleared).
        if !pendingDeletionQueue.contains(request) {
            pendingDeletionQueue.append(request)
            savePendingDeletionQueue()
        }
        pendingDeletedPostIDs.insert(postID)
        saveUserDeletedPostIDs()
        Task { [weak self] in
            await self?.flushPendingDeletions()
        }
    }
    private var pendingFollowSyncQueue: [PendingFollowSyncOperation] = []
    private var pendingBackendWriteQueue: [PendingBackendWriteOperation] = []
    private var isSyncingCuratedSlots = false
    private var feedShortPageSamples: [Bool] = []
    private var lastMainFeedRowAppearAt: Date?
    private var lastCityFeedRowAppearAt: Date?
    private var pendingOutgoingFollowRequestIDs: Set<UUID> = []
    private var shouldBufferIncomingPosts = false
    private var lastLoadMoreAt: Date = .distantPast
    private var feedTimelineLazyLoadFailureCount = 0
    private var feedTimelineNextCursor: String?
    private var isFeedTimelineLazyLoadInFlight = false
    private var isFeedFastTopUpInFlight = false
    private var profilePostsNextCursorByUserID: [UUID: String?] = [:]
    private var profilePostsExhaustedUserIDs: Set<UUID> = []
    private var profilePostsLoadInFlightUserIDs: Set<UUID> = []
    private var cityDiscoveryFetchTimestamps: [String: Date] = [:]
    private var spamActionHistory: [String: [Date]] = [:]
    private var spamTextHistory: [String: [SpamTextRecord]] = [:]
    private var pendingProfilePushSnapshot: UserProfile?
    private var pendingProfilePushStartedAt: Date?
    private var profilePushGeneration: Int = 0
    private var profileSyncInFlightGenerations: Set<Int> = []
    private var profileAutoRetrySuspendedGeneration: Int?
    private var lastProfileAutoRetryAt: Date = .distantPast
    private var currentUserWriteVersion: String?
    private var cachedFollowingUsers: SyncCacheEntry<[BackendUser]>?
    private var cachedFollowerUsers: SyncCacheEntry<[BackendUser]>?
    private var cachedCircles: SyncCacheEntry<[BackendCircle]>?
    private var cachedNotifications: SyncCacheEntry<[BackendNotification]>?
    private var notificationNextCursorByUserID: [UUID: String?] = [:]
    private var cachedAdSubmissions: SyncCacheEntry<[BackendAdSubmission]>?
    private var cachedAdDeliveryItems: SyncCacheEntry<[BackendAdDeliveryItem]>?
    private var cachedCuratedSlots: SyncCacheEntry<[UUID?]>?
    private var cachedFeedFirstPage: SyncCacheEntry<BackendFeedPage>?
    private var splashFirstPaintPrimeInFlight = false
    private var cachedDirectoryProfiles: SyncCacheEntry<[BackendUser]>?
    private var profileDeltaVersionByUserID: [UUID: String] = [:]
    private var cachedCommentsFetchedAt: [UUID: Date] = [:]
    private var commentsCacheOwnerUserID: UUID?
    private var lastCommentRefreshUsername: String = ""
    private var commentDeliveryTraces: [UUID: CommentDeliveryTrace] = [:]
    private var commentLikeOverrides: [UUID: CommentLikeOverride] = [:]
    private var postPublishDeliveryStates: [UUID: PostPublishDeliveryState] = [:]
    private var postPublishSuccessAcks: [UUID: Date] = [:]
    private var postPublishSuccessClearTasks: [UUID: Task<Void, Never>] = [:]
    private var cachedUserSearchResults: [String: SyncCacheEntry<[UserProfile]>] = [:]
    private var cachedCitySearchResults: [String: (results: [String], fetchedAt: Date)] = [:]
    private var cachedPublicCircleSearchResults: [String: SyncCacheEntry<[PublicCircleSearchResult]>] = [:]
    private var inFlightUserSearchRefreshKeys: Set<String> = []
    private var inFlightCitySearchRefreshKeys: Set<String> = []
    private var inFlightPublicCircleSearchRefreshKeys: Set<String> = []
    private var feedRateLimitBackoffUntil: Date?
    private var lastFeedRateLimitSkipLogAt: Date = .distantPast
    private var lastBackendWriteNoSessionPauseLogAt: Date = .distantPast
    private var lastBackendWriteRateLimitPauseLogAt: Date = .distantPast
    private var lastTerminalAuthFailureAt: Date?
    private var lastPostSyncIndicatorUpdateAt: Date = .distantPast
    private var tokenOnlyBridgeSeedAttemptedUserID: UUID?
    private var authMutationRateSamples: [AuthMutationRateSample] = []
    private var lastAuthMutationSnapshot: BackendAuthSessionMutationDiagnostics?
    private var authSelfHealStartupTriggerCount = 0
    private var authSelfHealForegroundTriggerCount = 0
    private var authSelfHealSuccessCount = 0
    private var authSelfHealFailureCount = 0
    private var consecutiveFeedRateLimitCount = 0
    private var lastEnsureSessionStartedAt: Date = .distantPast
    private var founderClaimMismatchSignalAt: Date?
    private var founderClaimMismatchPromptShown = false
    private static let founderManagedBusinessAccounts: [(id: UUID, username: String, displayName: String)] = [
        (UUID(uuidString: "4B80EA39-95A4-4389-A55A-6A042294D82F")!, "scrolls", "Scrolls"),
        (UUID(uuidString: "22B5CF34-2285-4E72-B1E8-8FA95A25D3C0")!, "gelanella", "Gelanella"),
        (UUID(uuidString: "ED2E1318-D186-4CC9-B4E9-7E43C5B87A8D")!, "ovispictures", "Ovis Pictures"),
        (UUID(uuidString: "DB4251BA-E3D4-4489-A51A-37E2E5A71FCC")!, "amerigomagazine", "Amerigo Magazine"),
        (UUID(uuidString: "AEC0DCD5-2046-4753-9244-0B5293834E11")!, "provostodaro", "Provostodaro")
    ]
    private static let founderCanonicalAccount: (id: UUID, username: String, displayName: String) = (
        UUID(uuidString: "CBC29D93-94C3-4CB8-9F22-CFC53D60C330")!,
        "primadonvino",
        "Toni Todaro"
    )
    private static let founderCanonicalAccounts: [(id: UUID, username: String)] = [
        (UUID(uuidString: "CBC29D93-94C3-4CB8-9F22-CFC53D60C330")!, "primadonvino")
    ]
    private static let founderAuthAliasIDs: Set<UUID> = [
        UUID(uuidString: "283DBE7A-FC81-46CE-91C8-297F75BFD6D1")!,
        UUID(uuidString: "CB6F0AA1-2A39-4EDE-90B0-AF5A63DA5A5D")!,
    ]
    private static let founderAuthSubjectIDs: Set<UUID> = {
        var ids = Set(founderAuthAliasIDs)
        ids.insert(founderCanonicalAccount.id)
        return ids
    }()
    private static let founderAuthAliasUsernames: Set<String> = [
        "primadonvino",
        "tonitodaro.mm",
    ]
    private static let protectedFounderBlockAccountIDs: Set<UUID> = {
        var ids = Set(founderAuthSubjectIDs)
        ids.formUnion(founderManagedBusinessAccounts.map(\.id))
        return ids
    }()
    private static let protectedFounderBlockUsernames: Set<String> = {
        var usernames = Set(founderAuthAliasUsernames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        usernames.insert(founderCanonicalAccount.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        usernames.formUnion(founderManagedBusinessAccounts.map { $0.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return usernames
    }()
    private static let publishSuccessIndicatorDuration: TimeInterval = 6
    private static let feedTimelineDefaultPageSize: Int = 20
    private static let feedTimelineFastStartPageSize: Int = 6
    private static let feedTimelineLazyLoadPageSize: Int = 20   // fetch a full default page per lazy-load trigger
    private static let profilePostsPageSize: Int = 50
    private static let deletedPostTombstoneSweepInterval: TimeInterval = 30 * 60
    private static let trustedTimelinePostLimit: Int = 2000     // large ring so deep-scroll posts stay trusted & non-evictable
    private static let feedTimelineEvictionGraceWindow: TimeInterval = 60
    private static let feedRateLimitBackoffWindow: TimeInterval = 30
    private static let feedRateLimitSkipLogInterval: TimeInterval = 8
    private static let backendWriteNoSessionLogInterval: TimeInterval = 8
    private static let backendWriteRateLimitLogInterval: TimeInterval = 8
    private static let backendWriteAuthBlockedRetryDelayNanos: UInt64 = 20_000_000_000
    private static let backendWriteTerminalAuthRetryDelayNanos: UInt64 = 30_000_000_000
    private static let founderClaimMismatchSignalTTL: TimeInterval = 15 * 60
    private static let commentLikeMismatchLogInterval: TimeInterval = 8
    private static let authMutationRateWindow: TimeInterval = 60
    private static let ensureSessionCooldownFastLane: TimeInterval = 0.35
    private static let localAuthTokenUsabilityLeewaySeconds: TimeInterval = 60
    private static let profileAutoRetryMinimumInterval: TimeInterval = 20
    private static let feedShortPageTelemetryWindowSize = 40
    private static let feedRenderHitchThresholdMS: Double = 220
    private static let writeVersionFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let writeVersionFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let blockedLinkTokens: [String] = [
        "onlyfans.com",
        "onlyfans"
    ]
    private static let blockedAIGenerationTokens: [String] = [
        "generated by ai",
        "ai-generated",
        "ai generated",
        "made with ai",
        "made in chatgpt",
        "made with chatgpt",
        "made with midjourney",
        "generated with midjourney",
        "generated with stable diffusion",
        "made with dall-e",
        "generated with dall-e",
        "generated with dalle",
        "created with runway"
    ]
    private static let blockedNudityTokens: [String] = [
        "nude",
        "nudes",
        "nudity",
        "nsfw",
        "explicit",
        "porn",
        "onlyfans"
    ]
    private static let blockedChildNudityTokens: [String] = [
        "child nude",
        "children nude",
        "kid nude",
        "minor nude",
        "underage nude",
        "teen nude"
    ]
    private static let blockedGenitalTokens: [String] = [
        "genital",
        "genitals",
        "penis",
        "vagina",
        "vulva",
        "labia",
        "testicles",
        "testicle",
        "scrotum"
    ]
    private static let shirtlessAllowedContextTokens: [String] = [
        "shirtless",
        "no shirt",
        "tank top",
        "by the pool",
        "at the pool",
        "swim trunks",
        "beach day",
        "gym session",
        "workout"
    ]
    private static let profileSnapshotKeyPrefix = "scrolls.profile.snapshot."
    private static let profileSnapshotKeychainService = "com.scrolls.profile.snapshot"
    private static let maxUserDefaultsBlobBytes = 3_500_000
    private static let profileSignatureKeyPrefix = "scrolls.profile.signature."
    private static let profileSignatureImageKeyPrefix = "scrolls.profile.signature.image."
    private static let profileHeroMediaPreferenceKeyPrefix = "scrolls.profile.hero.media."
    private static let notificationPermissionRequestedKey = "scrolls.notifications.permissionRequested"
    private static let remoteNotificationRegistrationRequestedKey = "scrolls.notifications.remoteRegistrationRequested"
    private static let lastBackgroundInboxAlertAtKey = "scrolls.notifications.lastBackgroundInboxAlertAt"
    private static let notificationCacheCleanupVersionKey = "scrolls.notifications.cacheCleanup.version"
    private static let notificationCacheCleanupVersion = 1
    private static let pendingPushTokenKey = "scrolls.notifications.pendingPushToken"
    private static let lastRegisteredPushTokenKey = "scrolls.notifications.lastRegisteredPushToken"

    static let verificationFee: Double = 6.99
    private enum FreePostCatalogLimit {
        // Safety switch: never silently delete user content in production.
        // Keep this disabled unless we ship an explicit, user-visible quota UX.
        static let autoRotateOldestEnabled = false
        static let totalScrolls = 25
    }
    private enum CostSaverMode {
        // Keep server payloads and storage lightweight for Circles.
        static let maxMessageCharacters = 320
        static let maxMessagesStoredPerCircle = 300
        static let messageRetentionHours = 24
        static let maxMessagesPerMinutePerCircle = 30
        static let batchedCircleSaveDelay: UInt64 = 700_000_000 // 0.7s
    }
    private enum NotificationCostSaverMode {
        static let retentionHours = 48
        static let digestWindow: TimeInterval = 15 * 60
        static let actorWindow: TimeInterval = 60 * 60
        static let maxEventsPerActorWindow = 8
        static let quietHourStart = 22
        static let quietHourEnd = 7
    }
    private enum ProfileSyncCostSaverMode {
        // Keep local edits stable only briefly while backend write catches up.
        static let localEditProtectionWindow: TimeInterval = 180
    }
    private enum SpamProtectionMode {
        static let postWindow: TimeInterval = 30
        static let postLimit = 1
        static let commentWindow: TimeInterval = 30
        static let commentLimit = 3
        static let replyWindow: TimeInterval = 30
        static let replyLimit = 3
        static let followWindow: TimeInterval = 20 * 60
        static let followLimit = 100
        static let unfollowWindow: TimeInterval = 24 * 60 * 60
        static let unfollowLimit = 20
        static let circlesWindow: TimeInterval = 30
        static let circlesLimit = 3
        static let duplicateTextWindow: TimeInterval = 45
        static let duplicateTextLimit = Int.max
    }
    private enum PersistenceCostSaverMode {
        static let saveDebounceNanos: UInt64 = 500_000_000
    }
    private enum BackendPollingCostSaverMode {
        static let pollIntervalNanos: UInt64 = 3_000_000_000
        static let socialSnapshotEveryTicks = 10
        static let circleInboxEveryTicks = 10   // ~30 s; runs independently of feed rate limits
        static let adSnapshotEveryTicks = 20
        // Proactively refresh the access token in the polling loop so it never
        // expires mid-session.  20 ticks × 3 s = ~60 s cadence.
        static let proactiveTokenRefreshEveryTicks = 20
        static let followingFollowersTTL: TimeInterval = 300
        static let circlesTTL: TimeInterval = 25
        static let notificationsTTL: TimeInterval = 45
        static let adDeliveryTTL: TimeInterval = 120
        static let adSubmissionsTTL: TimeInterval = 120
        static let curatedSlotsTTL: TimeInterval = 120
        static let feedFirstPageTTL: TimeInterval = 60
        static let profileDirectoryTTL: TimeInterval = 120
        static let momentsLiveSnapshotMinInterval: TimeInterval = 30
        static let profileStaleSweepMaxAge: TimeInterval = 24 * 60 * 60
        static let commentsTTL: TimeInterval = 120
        static let commentsBackfillVisiblePostLimit = 6
        static let commentsBackfillInterRequestDelayNanos: UInt64 = 200_000_000
        static let backendWriteQueueMaxOperationAge: TimeInterval = 24 * 60 * 60
        static let backendWriteQueueMaxRetryCount = 20
        static let searchResultsFreshTTL: TimeInterval = 6
        static let searchResultsTTL: TimeInterval = 60
    }
    private enum CommentSyncCostSaverMode {
        // Keep locally-created comments visible while backend sync retries.
        static let pendingPreservationWindow: TimeInterval = 20 * 60
    }
    private enum ProductionSearchGuardrails {
        static let minimumRemoteSearchCharacters = 2
        static let maximumRemoteSearchCharacters = 48
    }
    private enum BackendSyncLane {
        case feedFast
        case splashPrefetch
        case socialSnapshot
        case adSnapshot
        case publishFollowUp
        case manualRefresh

        var debugLabel: String {
            switch self {
            case .feedFast:
                return "feed_fast"
            case .splashPrefetch:
                return "splash_prefetch"
            case .socialSnapshot:
                return "social_snapshot"
            case .adSnapshot:
                return "ad_snapshot"
            case .publishFollowUp:
                return "publish_follow_up"
            case .manualRefresh:
                return "manual_refresh"
            }
        }
    }
    private enum RemotePostMergeSource {
        case feedTimeline
        case feedTimelineAppend
        case cityDiscovery
        case profileFetch
        case circleSharedPost

        var debugLabel: String {
            switch self {
            case .feedTimeline:
                return "feed_timeline"
            case .feedTimelineAppend:
                return "feed_timeline_append"
            case .cityDiscovery:
                return "city_discovery"
            case .profileFetch:
                return "profile_fetch"
            case .circleSharedPost:
                return "circle_shared_post"
            }
        }
    }
    private enum MainFeedEligibilityReason: String {
        case excludedAd = "excluded_ad_designated"
        case includedOwnPost = "included_own_post"
        case includedFounder = "included_founder_cluster"
        case includedTrustedTimeline = "included_trusted_timeline"
        case includedFollowing = "included_following"
        case includedFollowingID = "included_following_id_match"
        case includedFollowingUsername = "included_following_username_match"
        case includedFollowGraphHydrationFallback = "included_follow_graph_fallback"
        case excludedNotFollowed = "excluded_not_followed"

        var isIncluded: Bool {
            switch self {
            case .excludedAd, .excludedNotFollowed:
                return false
            default:
                return true
            }
        }
    }
    private enum SyncDebugDomain {
        case comment
        case commentLike
        case ad
        case rescroll
        case profile
        case circleMessage
    }
    private struct BackendWriteDebugContext {
        let domain: SyncDebugDomain
        let targetID: String
        let action: String
    }
    private struct BackendSyncPlan {
        let lane: BackendSyncLane
        let reconcileIdentity: Bool
        let fetchRemoteUser: Bool
        let feedPages: Int
        let allowFeedFirstPageCache: Bool
        let forceSocialRefresh: Bool
        let forceAdRefresh: Bool
        let fetchFollowingFollowers: Bool
        let fetchCircles: Bool
        let fetchNotifications: Bool
        let fetchAdDelivery: Bool
        let fetchAdSubmissions: Bool
        let fetchCuratedSlots: Bool
        let fetchRecentCommentsBackfill: Bool
    }
    private struct PendingBackendSyncRequest {
        var lane: BackendSyncLane
        var skipIdentityReconcile: Bool
    }
    private struct SyncCacheEntry<Value> {
        let ownerUserID: UUID
        let value: Value
        let fetchedAt: Date
    }
    private struct DeferredNotificationItem {
        let type: AppNotification.NotificationType
        let title: String
        let message: String
        let digestKey: String
        let actorKey: String
        let actorID: UUID?
        let objectID: UUID?
    }
    private static let seededUsernames: Set<String> = [
        "lumen.waves",
        "echo.looms",
        "cadenza",
        "stereo.cast"
    ]

    // In production/TestFlight backend mode, local disk state is cache-only and
    // must never become the source of truth for social/feed data.
    private var useServerAuthoritativeState: Bool {
        backendClient.isEnabled || Self.shouldPreferServerProfileSeed()
    }

    var circleNotificationCount: Int {
        unreadCircleMessageIDs.count
    }

    func draftsForCurrentUser() -> [PostDraft] {
        postDrafts.filter { ($0.ownerUserID ?? currentUser.id) == currentUser.id }
    }

    var adSubmissionCandidates: [FeedPost] {
        posts
            .filter { $0.user.id == currentUser.id && $0.rescrollOrigin == nil }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func hasSubmittedPostForAd(_ post: FeedPost) -> Bool {
        adSubmissionPostIDs.contains(post.id)
    }

    func adSubmission(for post: FeedPost) -> BackendAdSubmission? {
        adSubmissionsByPostID[post.id]
    }

    func adSubmissionStatusLabel(for post: FeedPost) -> String? {
        guard let submission = adSubmissionsByPostID[post.id] else {
            return adSubmissionPostIDs.contains(post.id) ? "Submitted" : nil
        }
        switch submission.status.lowercased() {
        case "approved":
            return "Approved"
        case "rejected":
            return "Rejected"
        case "paused":
            return "Paused"
        case "pending":
            return "Pending Review"
        default:
            return "Submitted"
        }
    }

    func canSubmitPostForAd(_ post: FeedPost) -> Bool {
        // Ad submissions are currently disabled; founder uses direct curated uploads instead.
        _ = post
        return false
    }

    var isAdReviewAdmin: Bool {
        currentUser.isFounder
    }

    var isPostReportReviewAdmin: Bool {
        currentUser.isFounder
    }

    func adAudienceCityLabel() -> String? {
        let ownBusinessCity = currentUser.businessLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ownBusinessCity.isEmpty {
            return ownBusinessCity
        }
        let recentTaggedCity = posts
            .filter { $0.user.id == currentUser.id }
            .compactMap { $0.locationCity?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return recentTaggedCity
    }

    func isAdDesignatedPost(_ post: FeedPost) -> Bool {
        if adSubmissionPostIDs.contains(post.id) {
            return true
        }
        if deliveredAdPosts.contains(where: { $0.id == post.id }) {
            return true
        }
        if curatedAdSlotIDs.contains(where: { $0 == post.id }) {
            return true
        }
        return false
    }

    func isProfileOriginalPost(_ post: FeedPost) -> Bool {
        post.rescrollOrigin == nil || isMalformedSelfRescroll(post)
    }

    func adSponsoredPost(forSlot slot: Int) -> FeedPost? {
        let curated = curatedAdSlotIDs.compactMap { id in
            deliveredAdPosts.first(where: { $0.id == id })
        }
        if !curated.isEmpty {
            return curated[abs(slot) % curated.count]
        }
        if !deliveredAdPosts.isEmpty {
            return deliveredAdPosts[abs(slot) % deliveredAdPosts.count]
        }
        return nil
    }

    var verificationCostLabel: String {
        String(format: "$%.2f", Self.verificationFee)
    }

    private var loadIndex = 0
    private var initializationTask: Task<Void, Never>?
    private var accountSwitchWatchdogTask: Task<Void, Never>?
    private var postSyncAutoRecoveryTask: Task<Void, Never>?
    private var postSyncAutoRecoveryInFlight = false
    private var lastPostSyncAutoRecoveryAttemptAt: Date = .distantPast
    private var lastPostSyncAutoRecoveryNoCredentialLogAt: Date = .distantPast
#if canImport(UIKit)
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var pushTokenObserver: NSObjectProtocol?
    private var pushTokenFailureObserver: NSObjectProtocol?
#endif

    private func normalizedAdCity(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private var persistenceDirectory: URL {
        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documentDir.appendingPathComponent("Scrolls", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private var persistenceURL: URL {
        persistenceURL(for: currentUser.id)
    }

    private func persistenceURL(for profileID: UUID) -> URL {
        let fileName = "scrolls-state-\(profileID.uuidString.lowercased()).json"
        return persistenceDirectory.appendingPathComponent(fileName)
    }

    private var globalFeedCacheURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-feed-cache.json")
    }

    private var pendingDeletionsURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-pending-deletes.json")
    }

    /// Persistent set of post IDs the user has ever requested be deleted.
    /// Independent of `pendingDeletionsURL` (the retry queue), which drains
    /// on backend success — this file does NOT drain.  Used to detect when
    /// a previously-deleted post resurfaces in search/feed because the
    /// backend lost the deletion (silent server-side failure, or a successful
    /// 200 that never actually deleted the row).  When that happens we
    /// re-fire the delete RPC to self-heal.
    private var userDeletedPostIDsURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-user-deleted-post-ids.json")
    }

    private var listenedCircleVoiceMessageIDsURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-listened-circle-voice-message-ids.json")
    }

    private var pendingFollowsURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-pending-follows.json")
    }

    private var pendingBackendWritesURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-pending-backend-writes.json")
    }

    private var pendingMediaPostsURL: URL {
        pendingMediaPostsURL(for: currentUser.id)
    }

    private func pendingMediaPostsURL(for profileID: UUID) -> URL {
        let fileName = "scrolls-pending-media-\(profileID.uuidString.lowercased()).json"
        return persistenceDirectory.appendingPathComponent(fileName)
    }

    private func remappedPinnedPostIDs(from persisted: ScrollsState, targetUserID: UUID) -> [UUID: UUID] {
        var mapped = persisted.pinnedPostIDs
        if targetUserID != persisted.currentUser.id,
           let legacyPinned = mapped[persisted.currentUser.id],
           mapped[targetUserID] == nil {
            mapped[targetUserID] = legacyPinned
        }
        return mapped
    }

    private func restorePinnedPostsForCurrentUserFromPersistence() {
        let normalizedCurrent = normalizeUsername(currentUser.username)
        guard !normalizedCurrent.isEmpty else { return }

        func decodeState(at url: URL) -> ScrollsState? {
            guard let data = Persistence.loadData(from: url),
                  let persisted = try? JSONDecoder().decode(ScrollsState.self, from: data) else {
                return nil
            }
            guard normalizeUsername(persisted.currentUser.username) == normalizedCurrent else {
                return nil
            }
            return persisted
        }

        var candidates: [ScrollsState] = []
        let primaryURL = persistenceURL(for: currentUser.id)
        if let primary = decodeState(at: primaryURL) {
            candidates.append(primary)
        }

        if candidates.isEmpty,
           let files = try? FileManager.default.contentsOfDirectory(
            at: persistenceDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for file in files {
                let name = file.lastPathComponent.lowercased()
                guard name.hasPrefix("scrolls-state-") && name.hasSuffix(".json") else { continue }
                if let persisted = decodeState(at: file) {
                    candidates.append(persisted)
                }
            }
        }

        guard let selected = candidates.first(where: { !$0.pinnedPostIDs.isEmpty }) ?? candidates.first else {
            // No candidate state file had pins — try the dedicated sidecar
            // before giving up.  The sidecar is independently written every
            // time the user toggles a pin, so it survives main-snapshot
            // resets caused by account switching, repair, etc.
            pinnedPostIDs = loadPinnedPostIDSnapshot()
            return
        }
        let mappedPinned = remappedPinnedPostIDs(from: selected, targetUserID: currentUser.id)
        guard !mappedPinned.isEmpty else {
            // Same fallback: main snapshot exists but contains no pins for
            // this user.  Try the sidecar before declaring there are no
            // pins.
            pinnedPostIDs = loadPinnedPostIDSnapshot()
            return
        }
        pinnedPostIDs = mappedPinned
    }

    private static let globalFeedCacheLimit = 500  // restore up to 500 posts on cold launch
    private static let profileCacheLimit = 500
    private static let curatedAdSlotsDefaultsKey = "scrolls.curatedAd.slots"
    private static let curatedAdSlotEmptySentinel = "__empty__"
    private static let maxCuratedAdCount = 3
    private static let postSyncAutoRecoveryIntervalNanos: UInt64 = 12_000_000_000
    private static let postSyncAutoRecoveryMinAttemptGap: TimeInterval = 24
    private static let postSyncAutoRecoveryNoCredentialLogInterval: TimeInterval = 45

    init() {
        let user = Self.createCurrentUser()
        let serverAuthoritative = Self.shouldPreferServerProfileSeed()
        self.currentUser = user
        self.following = []
        self.followers = []
        self.posts = serverAuthoritative ? [] : Self.initialPosts
        self.notifications = Self.sampleNotifications
        self.circles = Self.sampleCircles
        self.postDrafts = []
        self.adSubmissionPostIDs = []
        self.adSubmissionsByPostID = [:]
        self.deliveredAdPosts = []
        self.adReviewQueue = []
        self.postReportQueue = []
        self.pendingFeedPostCount = 0
        let initialCuratedAdSlotIDs = Self.readCuratedAdSlots()
        self.curatedAdSlotIDs = initialCuratedAdSlotIDs
        let savedCuratedSlotIDs = initialCuratedAdSlotIDs.compactMap { $0 }
        self.pendingFollowRequests = []
        self.unreadCircleMessageIDs = Set(Self.sampleCircles.flatMap { $0.messages }.filter { $0.userID != user.id }.map { $0.id })
        self.followRelations = Self.defaultFollowRelations(currentUserID: user.id)
        self.pinnedPostIDs = [:]
        let knownProfiles = serverAuthoritative ? [user] : ([user] + Self.sampleProfiles)
        self.profileRegistry = Dictionary(uniqueKeysWithValues: knownProfiles.map { ($0.id, $0) })
        registerProfiles(from: knownProfiles)
        registerProfiles(from: posts.map { $0.user })
        startScheduledPublishingLoop()
        normalizeIdentityState()
        ensureFounderAccountExists()
        ensureFounderManagedBusinessAccountsExist()
        enforceMandatoryFounderFollows()
        removeSeedDataIfNeeded()
        syncFollowDirectories()
        performOneTimeNotificationCacheCleanupIfNeeded()
        initializationTask = Task {  [weak self] in
            await self?.completeSetup()
        }
        if backendClient.isEnabled,
           canCurrentUserPublishFounderAds(),
           !savedCuratedSlotIDs.isEmpty {
            Task { [weak self, savedCuratedSlotIDs] in
                await self?.hydrateDeliveredAdsForCuratedSlots(slotIDs: savedCuratedSlotIDs)
            }
        }
#if canImport(UIKit)
        registerForegroundObserver()
        registerBackgroundObserver()
        registerPushRegistrationObservers()
#endif
        refreshPostSyncIndicator(reason: "init", force: true)
        startPostSyncAutoRecoveryIfNeeded()
        observeBroadcasterState()
        scheduleAppIconBadgeRefresh()
    }

    func configureBackend(supabaseURL: String, anonKey: String) {
        backendClient.configureSupabase(url: supabaseURL, anonKey: anonKey)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        attemptPushTokenRegistrationIfPossible()
        refreshPostSyncIndicator(reason: "configure_backend_supabase", force: true)
    }

    func configureBackend(baseURL: String) {
        backendClient.configure(baseURL: baseURL)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        attemptPushTokenRegistrationIfPossible()
        refreshPostSyncIndicator(reason: "configure_backend_base_url", force: true)
    }

    func startupSessionReadinessDebugSnapshot() -> String {
        let hasUsableToken = hasLocallyUsableAuthToken() ? "yes" : "no"
        let hasRefresh = hasRefreshTokenForBackendSync() ? "yes" : "no"
        let hasRecoverableCandidate = hasRecoverableSessionCandidateForBackendSync(preferRefresh: true) ? "yes" : "no"
        let diagnostics = backendClient.currentAuthTokenDiagnostics()
        let subject = diagnostics.subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "none"
        let tokenPresent = diagnostics.tokenPresent ? "yes" : "no"
        let refreshPresent = diagnostics.refreshTokenPresent ? "yes" : "no"
        return "usable_token=\(hasUsableToken), refresh_path=\(hasRefresh), recoverable_candidate=\(hasRecoverableCandidate), token_present=\(tokenPresent), refresh_present=\(refreshPresent), subject=\(subject), session_username=\(resolvedBackendSessionUsername())"
    }

    @discardableResult
    func healSessionOnStartup(usernameHint: String? = nil) async -> Bool {
        let debugUsernameHint = usernameHint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? currentUser.username
        LocalAuthStore.appendAuthPersistenceDebug(
            "startup_heal_begin username=\(debugUsernameHint), \(startupSessionReadinessDebugSnapshot())"
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        await performAuthSessionSelfHealIfNeeded(trigger: "startup")
        attemptPushTokenRegistrationIfPossible()
        let readyForAppAccess =
            hasLocallyUsableAuthToken()
            || hasRefreshTokenForBackendSync()
            || hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        LocalAuthStore.appendAuthPersistenceDebug(
            "startup_heal_result username=\(debugUsernameHint), ready=\(readyForAppAccess ? "yes" : "no"), \(startupSessionReadinessDebugSnapshot())"
        )
        if pendingBackendWriteQueue.isEmpty == false {
            triggerPendingBackendWriteFlush(after: 0, force: true)
        }

        guard backendClient.isEnabled else {
            startupProfileFetchDebugLine = "startup_profile_fetch=skipped backend_disabled"
            return true
        }
        let startupUserID = currentUser.id
        // Prefer the caller-supplied hint so we don't race against handleActiveUsernameChange
        // setting currentUser.username on a different task.
        let _hintTrimmed = usernameHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let startupUsername = _hintTrimmed.isEmpty ? currentUser.username : _hintTrimmed
        // Sentinel UUID used when no session record exists yet (fresh install, first sign-in).
        let isFallbackID = startupUserID == Self.fallbackProfileID
        startupProfileFetchDebugLine = "startup_profile_fetch=started user=\(startupUsername) fallback_id=\(isFallbackID)"
        Task { [weak self] in
            guard let self else { return }
            do {
                // If the local UUID is the placeholder (session record not yet written when
                // createCurrentUser ran), fetch by username instead so we get the real profile.
                let remoteUser: BackendUser
                if isFallbackID, !startupUsername.isEmpty {
                    remoteUser = try await self.backendClient.fetchUserByUsername(startupUsername)
                } else {
                    remoteUser = try await self.backendClient.fetchUser(id: startupUserID)
                }
                await MainActor.run {
                    self.mergeRemoteCurrentUser(remoteUser)
                    self.startupProfileFetchDebugLine = "startup_profile_fetch=ok user=\(self.currentUser.username)"
                }
            } catch {
                let reason = String(describing: error)
                await MainActor.run {
                    self.startupProfileFetchDebugLine = "startup_profile_fetch=failed \(reason)"
                }
            }
        }
        return readyForAppAccess
    }

    /// Called every time the app transitions from background → active.
    /// Silently refreshes an expired or near-expired token so the user never
    /// hits a 401 mid-session and is never prompted to re-authenticate just
    /// because they left the app for an hour.
    func healSessionOnForeground() async {
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        await performAuthSessionSelfHealIfNeeded(trigger: "foreground")
        attemptPushTokenRegistrationIfPossible()
        updateDebugStatus { status in
            let outcome = status.refreshOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
            if !outcome.isEmpty, outcome != "Not run yet" {
                status.lastAuthRecoveryAction += " [outcome=\(outcome)]"
            }
        }
        if pendingBackendWriteQueue.isEmpty == false {
            triggerPendingBackendWriteFlush(after: 0, force: true)
        }
        // Resume any posts that were stuck while the app was suspended.
        // performAuthSessionSelfHealIfNeeded already does this on recovery; this
        // call also covers the path where the token was already valid (no heal
        // needed) so uploads aren't left in limbo after a background/foreground cycle.
        if postPublishDeliveryStates.isEmpty == false {
            resumePendingMediaPostUploadsIfNeeded()
        }
    }

    /// Called immediately when the app transitions to background, *before* the
    /// process is suspended.  Uses a ~30-second UIBackgroundTask window (already
    /// opened by the caller) to proactively refresh the access token if it would
    /// otherwise expire before the user returns to the app.
    ///
    /// By refreshing here — under guaranteed synchronous execution — we avoid the
    /// two failure modes that caused overnight logouts:
    ///   1. BGTask killed mid-refresh: the old refresh token was consumed on the
    ///      Supabase server but the new one was never written to Keychain.
    ///   2. Double-refresh race: the foreground heal and a background task both
    ///      tried to use the same (already rotated) refresh token simultaneously.
    ///
    /// We only refresh when the current token expires within `thresholdHours` so
    /// we don't burn a refresh on every background transition.
    func refreshSessionBeforeBackground(thresholdHours: TimeInterval = 8) async {
        guard backendClient.isEnabled else { return }
        guard hasRefreshTokenForBackendSync() else { return }

        // If the token is still fresh enough to survive the expected sleep window,
        // skip the refresh entirely — no need to rotate tokens unnecessarily.
        let tokenExpiresWithinThreshold = backendClient.isCurrentAccessTokenExpiringSoon(
            withinSeconds: thresholdHours * 3600
        )
        guard tokenExpiresWithinThreshold else {
            updateDebugStatus { status in
                status.lastAuthRecoveryAction = "Pre-background refresh skipped; token valid for > \(Int(thresholdHours))h"
            }
            return
        }

        updateDebugStatus { status in
            status.lastAuthRecoveryAction = "Pre-background refresh started (token expires within \(Int(thresholdHours))h)"
        }
        let recovered = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        // A truthy "recovered" from ensureBackendSessionForCurrentUser means the
        // network round-trip succeeded and new credentials were received; but we
        // must also verify they were seeded into the active client before we
        // declare the background refresh a real success.
        let authActuallyUsable = recovered && hasLocallyUsableAuthToken()
        updateDebugStatus { status in
            self.hydrateSessionRecoveryDebugSnapshot(&status)
            let outcome = status.refreshOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
            status.lastAuthRecoveryAction = authActuallyUsable
                ? "Pre-background refresh succeeded; usable token confirmed overnight"
                : (recovered
                    ? "Pre-background refresh completed but token not yet usable; foreground heal will verify"
                    : "Pre-background refresh failed; foreground heal will retry on next open")
            if !outcome.isEmpty, outcome != "Not run yet" {
                status.lastAuthRecoveryAction += " [outcome=\(outcome)]"
            }
        }
        LocalAuthStore.appendAuthPersistenceDebug(
            "pre_bg_refresh_result recovered=\(recovered ? "yes" : "no") usable=\(authActuallyUsable ? "yes" : "no") username=\(resolvedBackendSessionUsername())"
        )
        // Mirror what performAuthSessionSelfHealIfNeeded does on recovery: flush
        // any queued writes and nudge stuck uploads so they don't wait until the
        // next foreground open (which could be hours away).
        if authActuallyUsable {
            if pendingBackendWriteQueue.isEmpty == false {
                triggerPendingBackendWriteFlush(after: 0, force: true)
            }
            if postPublishDeliveryStates.isEmpty == false {
                resumePendingMediaPostUploadsIfNeeded()
            }
        }
    }

    func shouldAttemptLifecycleSessionHealing() -> Bool {
        guard backendClient.isEnabled else { return false }
        if hasLocallyUsableAuthToken() || hasRefreshTokenForBackendSync() {
            return true
        }
        return BackendTruthSyncCore.hasRecoverableSessionCandidate(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            preferRefresh: true
        )
    }

    func shouldRunSignedInBackgroundWork() -> Bool {
        UserDefaults.standard.bool(forKey: "scrolls.auth.isAuthenticated")
            || shouldAttemptLifecycleSessionHealing()
    }

    func handleActiveUsernameChange(_ newValue: String) {
        let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        resetFounderClaimMismatchTracking()

        let seededUser = roleAdjustedProfile(Self.createCurrentUser())
        currentUser = seededUser
        registerProfile(currentUser)
        ensureFounderAccountExists()
        ensureFounderManagedBusinessAccountsExist()
        enforceMandatoryFounderFollows()
        syncFollowDirectories()
        restorePinnedPostsForCurrentUserFromPersistence()
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        noteAccountSwitchDebug("local_seed:\(currentUser.username)")
        refreshPostSyncIndicator(reason: "active_username_changed_local_seed", force: true)
    }

    func restoreStateAfterActiveUsernameChange() async {
        noteAccountSwitchDebug("restore_state:start")
        initializationTask?.cancel()
        await completeSetup()
        noteAccountSwitchDebug("restore_state:done")
        if isSwitchingAccounts {
            endAccountSwitchUI(reason: "local_state_restored")
        }
    }

    func beginAccountSwitchUI() {
        isSwitchingAccounts = true
        accountSwitchDebugLine = "begin_ui"
        scheduleAccountSwitchWatchdog()
    }

    func noteAccountSwitchDebug(_ line: String) {
        guard isSwitchingAccounts else { return }
        accountSwitchDebugLine = line
    }

    func prepareForAccountSwitch() {
        isSwitchingAccounts = true
        resetFounderClaimMismatchTracking()
        accountSwitchDebugLine = "prepare_state"
        backendPollingTask?.cancel()
        backendPollingTask = nil
        followSyncFlushTask?.cancel()
        followSyncFlushTask = nil
        backendWriteFlushTask?.cancel()
        backendWriteFlushTask = nil
        pendingCircleSaveTask?.cancel()
        pendingCircleSaveTask = nil
        pendingCircleBackendSyncTask?.cancel()
        pendingCircleBackendSyncTask = nil
        clearTypingPresenceState(sendStopSignals: true)
        stopRealtimeInvalidation()

        pendingPublishRetryTasks.values.forEach { $0.cancel() }
        pendingPublishRetryTasks.removeAll()
        inFlightBackendPublishPostIDs.removeAll()

        posts = []
        following = []
        followers = []
        pendingFollowRequests = []
        notifications = []
        circles = []
        moments = []
        activeLiveStreamSession = nil
        isPhoneLiveBroadcasting = false
        liveBroadcastDebugState = "idle"
        liveBroadcastDebugDetail = "Publisher idle"
        liveBroadcastEncoderDebugLine = "encoder=idle"
        liveStartDebugTimeline = []
        broadcasterRetryTask?.cancel()
        broadcasterRetryTask = nil
        liveHeartbeatTask?.cancel()
        liveHeartbeatTask = nil
        broadcasterRetryCount = 0
        Task {  [weak self] in
            await self?.livePhoneBroadcaster.stopPublishing()
        }
        liveStreamErrorMessage = nil
        pendingFeedPostCount = 0
        lastFeedTimelineLazyLoadErrorAt = nil
        feedTimelineLazyLoadFailureCount = 0
        unreadCircleMessageIDs = []
        curatedAdSlotIDs = [nil, nil, nil]
        isSyncingCuratedSlots = false
        curatedAdSlotSaveState = .idle

        pendingRemotePosts.removeAll()
        trustedTimelinePostIDs.removeAll()
        trustedTimelinePostOrder.removeAll()
        postPublishDeliveryStates.removeAll()
        postPublishSuccessAcks.removeAll()
        postPublishSuccessClearTasks.values.forEach { $0.cancel() }
        postPublishSuccessClearTasks.removeAll()
        clearCommentCache()
        invalidateCachesForAccountTransition()
        refreshPostSyncIndicator(reason: "prepare_account_switch", force: true)
    }

    private func endAccountSwitchUI(reason: String) {
        accountSwitchWatchdogTask?.cancel()
        accountSwitchWatchdogTask = nil
        if isSwitchingAccounts {
            isSwitchingAccounts = false
            accountSwitchDebugLine = "end:\(reason)"
            refreshPostSyncIndicator(reason: "end_account_switch_\(reason)", force: true)
        }
    }

    private func scheduleAccountSwitchWatchdog() {
        accountSwitchWatchdogTask?.cancel()
        accountSwitchWatchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.endAccountSwitchUI(reason: "watchdog_timeout")
            }
        }
    }


    private func startPostSyncAutoRecoveryIfNeeded() {
        guard postSyncAutoRecoveryTask == nil else { return }
        postSyncAutoRecoveryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runPostSyncAutoRecoveryTick()
                try? await Task.sleep(nanoseconds: Self.postSyncAutoRecoveryIntervalNanos)
            }
        }
    }


    private func runPostSyncAutoRecoveryTick() async {
        guard backendClient.isEnabled else { return }
        guard !isSwitchingAccounts else { return }
        // Fire both when post-sync is visibly blocked *and* when the token is
        // about to expire — so recovery happens proactively rather than only
        // after a 401 has already caused a sync failure.
        let isBlocked = postSyncIndicator.state == .blocked
        let isTokenExpiringSoon = hasRefreshTokenForBackendSync()
            && backendClient.isCurrentAccessTokenExpiringSoon(withinSeconds: 300)
        guard isBlocked || isTokenExpiringSoon else { return }
        guard !postSyncAutoRecoveryInFlight else { return }

        let now = Date()
        if now.timeIntervalSince(lastPostSyncAutoRecoveryAttemptAt) < Self.postSyncAutoRecoveryMinAttemptGap {
            return
        }

        restoreBackendAuthTokenForCurrentUserIfNeeded()
        let hasRecoveryPath = hasRefreshTokenForBackendSync()
            || hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        guard hasRecoveryPath else {
            if now.timeIntervalSince(lastPostSyncAutoRecoveryNoCredentialLogAt) >= Self.postSyncAutoRecoveryNoCredentialLogInterval {
                lastPostSyncAutoRecoveryNoCredentialLogAt = now
                updateDebugStatus { status in
                    status.lastAuthRecoveryAction = "Background recovery blocked; no refresh/recoverable credentials"
                    status.lastAuthFailureAt = Date()
                }
            }
            refreshPostSyncIndicator(reason: "auto_recovery_no_credentials", force: true)
            return
        }

        postSyncAutoRecoveryInFlight = true
        defer { postSyncAutoRecoveryInFlight = false }

        lastPostSyncAutoRecoveryAttemptAt = now
        updateDebugStatus { status in
            status.lastAuthRecoveryAction = "Background recovery attempt started"
        }

        let recovered = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        if recovered {
            authSelfHealSuccessCount += 1
        } else {
            authSelfHealFailureCount += 1
        }
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        if recovered {
            lastTerminalAuthFailureAt = nil
            if pendingBackendWriteQueue.isEmpty == false {
                triggerPendingBackendWriteFlush(after: 0, force: true)
            }
            refreshPostSyncIndicator(reason: "auto_recovery_success", force: true)
            updateDebugStatus { status in
                status.lastAuthRecoveryAction = "Background recovery succeeded"
            }
        } else {
            refreshPostSyncIndicator(reason: "auto_recovery_failed", force: true)
            updateDebugStatus { status in
                status.lastAuthRecoveryAction = "Background recovery attempt failed"
                status.lastAuthFailureAt = Date()
            }
        }
    }

    /// Proactively refreshes the access token in the background polling loop so
    /// that it never expires during an active session.  Called every
    /// `proactiveTokenRefreshEveryTicks` ticks (~30 s).  Skips silently when:
    ///   • the token still has more than 10 minutes of life, or
    ///   • no refresh token is available (nothing we can do without user action).
    private func proactiveTokenRefreshIfNeeded() async {
        guard backendClient.isEnabled else { return }
        guard !isSwitchingAccounts else { return }
        guard hasRefreshTokenForBackendSync() else { return }
        // Only act when the window is short enough to matter (≤ 10 min remaining).
        guard backendClient.isCurrentAccessTokenExpiringSoon(withinSeconds: 600) else { return }

        updateDebugStatus { status in
            status.lastAuthRecoveryAction = "Proactive token refresh started (token expiring within 10 min)"
        }
        let recovered = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        if recovered {
            authSelfHealSuccessCount += 1
            lastTerminalAuthFailureAt = nil
            updateDebugStatus { status in
                self.hydrateSessionRecoveryDebugSnapshot(&status)
                status.lastAuthRecoveryAction = "Proactive token refresh succeeded"
            }
            if pendingBackendWriteQueue.isEmpty == false {
                triggerPendingBackendWriteFlush(after: 0, force: true)
            }
            if postPublishDeliveryStates.isEmpty == false {
                resumePendingMediaPostUploadsIfNeeded()
            }
        } else {
            authSelfHealFailureCount += 1
            updateDebugStatus { status in
                self.hydrateSessionRecoveryDebugSnapshot(&status)
                status.lastAuthRecoveryAction = "Proactive token refresh failed; will retry next tick"
                status.lastAuthFailureAt = Date()
            }
        }
    }

    func bootstrapFeedFirstPaintIfNeeded() {
        guard backendClient.isEnabled else { return }
        guard mainFeedPosts.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.syncFromBackendIfAvailable(lane: .feedFast, skipIdentityReconcile: true)
        }
    }

    func warmFeedCacheDuringSplash() async {
        guard backendClient.isEnabled else { return }

        var warmPage: BackendFeedPage?
        if let token = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
            expectedSubjectUserID: currentUser.id
        ), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warmPage = try? await backendClient.fetchFeed(
                userID: currentUser.id,
                limit: Self.feedTimelineFastStartPageSize,
                timeoutInterval: 4,
                authTokenOverride: token
            )
        }

        if warmPage == nil {
            warmPage = try? await backendClient.fetchFeed(
                userID: nil,
                cursor: nil,
                limit: Self.feedTimelineFastStartPageSize,
                allowAuthContextFallbackOnEmpty: false,
                includeAuthorization: false,
                timeoutInterval: 4
            )
        }

        guard let page = warmPage else { return }
        await MainActor.run {
            cachedFeedFirstPage = SyncCacheEntry(ownerUserID: currentUser.id, value: page, fetchedAt: Date())
            // If local feed is still empty during splash, hydrate immediately
            // so first post appears right after splash/ad dismissal.
            if posts.isEmpty && pendingRemotePosts.isEmpty {
                feedTimelineNextCursor = normalizedFeedCursor(page.nextCursor)
                mergeRemotePosts(
                    page.posts,
                    source: .feedTimeline,
                    timelineCursorExhausted: normalizedFeedCursor(page.nextCursor) == nil
                )
            }
            // Apply server-pushed tombstones even during the splash warm path.
            if let tombstones = page.deletedPostIDs, !tombstones.isEmpty {
                for id in tombstones { markPostDeleted(id) }
            }
        }

        await prewarmMainFeedMediaCache(limit: 8)
    }

    /// Fetches one full default-size feed page (using the cursor left by the fast-start fetch)
    /// and pre-warms media for all loaded posts. Designed to run in the background while
    /// the startup animation or splash ad is occupying the screen so the feed is deep
    /// and media-warm the moment the user first sees it. Safe to call concurrently —
    /// backendSyncInFlight serialises the page fetch automatically.
    func prefetchFeedBehindSplash() async {
        guard backendClient.isEnabled else { return }
        guard !Task.isCancelled else { return }
        // Feed-only full-page sync for startup prefetch: fresh page 1/2, no identity/social/ad work.
        await syncFromBackendIfAvailable(lane: .splashPrefetch, skipIdentityReconcile: true)
        guard !Task.isCancelled else { return }
        // Pre-warm decoded images for every post that is now loaded.
        await prewarmMainFeedMediaCache(limit: Self.feedTimelineDefaultPageSize)
    }

    func ensureFirstPostVisibleAfterSplash(deadlineSeconds: TimeInterval = 2.8) {
        guard backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }

            let shouldFetchQuickPage = await MainActor.run { () -> Bool in
                guard self.mainFeedPosts.isEmpty else { return false }

                if let cached = self.cachedValue(
                    from: self.cachedFeedFirstPage,
                    for: self.currentUser.id,
                    ttl: BackendPollingCostSaverMode.feedFirstPageTTL
                ), !cached.posts.isEmpty {
                    self.feedTimelineNextCursor = self.normalizedFeedCursor(cached.nextCursor)
                    self.mergeRemotePosts(
                        cached.posts,
                        source: .feedTimeline,
                        timelineCursorExhausted: self.normalizedFeedCursor(cached.nextCursor) == nil
                    )
                    self.updateFeedDebug(
                        stage: "splash_exit_cache_prime",
                        status: "Primed first post from splash cache",
                        detail: "posts=\(cached.posts.count), next_cursor=\(self.normalizedFeedCursor(cached.nextCursor) ?? "none")"
                    )
                }

                if self.mainFeedPosts.isEmpty {
                    self.hydrateFeedFromGlobalCacheFallbackIfNeeded()
                    if !self.mainFeedPosts.isEmpty {
                        self.updateFeedDebug(
                            stage: "splash_exit_global_cache_prime",
                            status: "Primed first post from disk cache",
                            detail: "posts=\(self.mainFeedPosts.count)"
                        )
                    }
                }

                if !self.mainFeedPosts.isEmpty {
                    self.bootstrapFeedFirstPaintIfNeeded()
                    return false
                }

                guard !self.splashFirstPaintPrimeInFlight else { return false }
                self.splashFirstPaintPrimeInFlight = true
                return true
            }

            guard shouldFetchQuickPage else { return }

            let quickTimeout = max(1.5, min(deadlineSeconds, 3.0))
            let quickPage = try? await self.backendClient.fetchFeed(
                userID: nil,
                cursor: nil,
                limit: Self.feedTimelineFastStartPageSize,
                allowAuthContextFallbackOnEmpty: false,
                includeAuthorization: false,
                timeoutInterval: quickTimeout
            )

            await MainActor.run {
                self.splashFirstPaintPrimeInFlight = false
                defer { self.bootstrapFeedFirstPaintIfNeeded() }

                guard self.mainFeedPosts.isEmpty else { return }
                guard let quickPage, !quickPage.posts.isEmpty else {
                    self.updateFeedDebug(
                        stage: "splash_exit_quick_prime_failed",
                        status: "Quick first-post prime did not return posts",
                        detail: "timeout=\(String(format: "%.1f", quickTimeout))s"
                    )
                    return
                }

                self.feedTimelineNextCursor = self.normalizedFeedCursor(quickPage.nextCursor)
                self.mergeRemotePosts(
                    quickPage.posts,
                    source: .feedTimeline,
                    timelineCursorExhausted: self.normalizedFeedCursor(quickPage.nextCursor) == nil
                )
                self.updateFeedDebug(
                    stage: "splash_exit_quick_prime_success",
                    status: "Primed first post after splash",
                    detail: "posts=\(quickPage.posts.count), next_cursor=\(self.normalizedFeedCursor(quickPage.nextCursor) ?? "none")"
                )
                self.scheduleFeedFastTopUpIfNeeded()
            }
        }
    }

    func fetchSplashAdForLaunch() async -> BackendSplashAd? {
        guard backendClient.isEnabled,
              let remote = try? await backendClient.fetchSplashAdVideo(),
              let assetRef = remote.assetRef,
              !assetRef.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              URL(string: assetRef) != nil else {
            return nil
        }
        return remote
    }
    private static func readCuratedAdSlots() -> [UUID?] {
        let stored = UserDefaults.standard.array(forKey: Self.curatedAdSlotsDefaultsKey) as? [String] ?? []
        var slots: [UUID?] = [nil, nil, nil]

        // New format: always exactly 3 entries, preserving nil slot positions.
        if stored.count >= 3 {
            for index in 0..<3 {
                let raw = stored[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.isEmpty || raw == Self.curatedAdSlotEmptySentinel {
                    slots[index] = nil
                } else {
                    slots[index] = UUID(uuidString: raw)
                }
            }
            return slots
        }

        // Legacy fallback: compact format (lost nil positions). Keep backward compatibility.
        let ids = stored.compactMap { UUID(uuidString: $0) }
        for (idx, id) in ids.prefix(3).enumerated() {
            slots[idx] = id
        }
        return slots
    }

    private func loadCuratedAdSlots() {
        curatedAdSlotIDs = Self.readCuratedAdSlots()
    }

    private func saveCuratedAdSlots() {
        var normalizedSlots = Array(curatedAdSlotIDs.prefix(3))
        while normalizedSlots.count < 3 {
            normalizedSlots.append(nil)
        }
        let stored = normalizedSlots.map { slotID in
            slotID?.uuidString ?? Self.curatedAdSlotEmptySentinel
        }
        UserDefaults.standard.set(stored, forKey: Self.curatedAdSlotsDefaultsKey)
    }

    private func hasPendingCuratedSlotUpdateForCurrentUser() -> Bool {
        pendingBackendWriteQueue.contains { operation in
            operation.kind == .adCuratedSlotUpdate && operation.userID == currentUser.id
        }
    }

    func setCuratedAdSlot(_ slot: Int, postID: UUID?) {
        guard slot >= 0 && slot < 3 else { return }
        var updated = normalizedCuratedAdSlots(curatedAdSlotIDs)
        updated[slot] = postID
        setCuratedAdSlots(updated)
    }

    func setCuratedAdSlots(_ slots: [UUID?]) {
        let normalized = normalizedCuratedAdSlots(slots)
        curatedAdSlotIDs = normalized
        saveCuratedAdSlots()
        if backendClient.isEnabled, canCurrentUserPublishFounderAds() {
            syncCuratedAdSlotsSnapshot(normalized, queuedPostID: normalized.compactMap { value in value }.first)
        } else {
            curatedAdSlotSaveState = .succeeded
        }
    }

    private func normalizedCuratedAdSlots(_ slots: [UUID?]) -> [UUID?] {
        var normalized = Array(slots.prefix(3))
        while normalized.count < 3 {
            normalized.append(nil)
        }
        return normalized
    }

    func validateCuratedSlotDraft(_ slots: [UUID?]) -> CuratedSlotDraftValidationResult {
        let normalized = normalizedCuratedAdSlots(slots)
        let selectedPostIDs = Set(normalized.compactMap { value in value })
        for postID in selectedPostIDs {
            guard let submission = adSubmissionsByPostID[postID] else { continue }
            if submission.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "approved" {
                return .invalid(message: "One or more selected ads are no longer approved. Please re-select and save again.")
            }
        }
        return .valid
    }

    private func syncCuratedAdSlotsSnapshot(_ slotsSnapshot: [UUID?], queuedPostID: UUID?) {
        guard backendClient.isEnabled, canCurrentUserPublishFounderAds() else { return }
        let targetID = queuedPostID?.uuidString ?? "curated_slots"

        Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.isSyncingCuratedSlots = true
                self.curatedAdSlotSaveState = .syncing
            }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "ad_curated_slot_update_manual",
                    debugContext: BackendWriteDebugContext(
                        domain: .ad,
                        targetID: targetID,
                        action: "ad_curated_slot_update_manual"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 20
                ) { _ in
                    let updatedSlots = try await self.backendClient.updateCuratedAdSlots(postIDs: slotsSnapshot)
                    await MainActor.run {
                        self.curatedAdSlotIDs = updatedSlots
                        self.saveCuratedAdSlots()
                        self.isSyncingCuratedSlots = false
                        self.curatedAdSlotSaveState = .succeeded
                        Task { @MainActor [weak self] in
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            guard let self else { return }
                            if case .succeeded = self.curatedAdSlotSaveState {
                                self.curatedAdSlotSaveState = .idle
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSyncingCuratedSlots = false
                    if self.isFounderPermissionDeniedError(error) {
                        self.curatedAdSlotSaveState = .failed("Founder permission required. Log out and back in to refresh credentials.")
                        self.updateAdDebug(
                            targetID: targetID,
                            stage: "slot_manual_sync_failed_permission_denied",
                            status: "Curated slot save failed: Founder permission required",
                            detail: "Log out and back in to refresh Founder credentials.",
                            error: error
                        )
                        return
                    }
                    if self.isCuratedSlotDataError(error) {
                        self.curatedAdSlotSaveState = .failed("Selected ad data is not ready on backend yet. Please refresh and retry.")
                        self.updateAdDebug(
                            targetID: targetID,
                            stage: "slot_manual_sync_failed_data_error",
                            status: "Curated slot save failed: data not ready",
                            detail: "Submission/post not ready on backend. Keeping local slot selection.",
                            error: error
                        )
                        return
                    }
                    self.curatedAdSlotSaveState = .failed("Saved locally. Slot sync queued for retry.")
                    self.updateAdDebug(
                        targetID: targetID,
                        stage: "slot_manual_sync_failed_queued",
                        status: "Curated slot save queued for retry",
                        detail: "Will retry when auth/network recovers.",
                        error: error
                    )
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .adCuratedSlotUpdate,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: self.currentUser.id,
                            postID: queuedPostID,
                            authorID: nil,
                            commentID: nil,
                            body: nil,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                }
            }
        }
    }

    func refreshCuratedAdSlots() {
        guard backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            if let slots = try? await self.backendClient.fetchCuratedAdSlots() {
                let effectiveSlots = await MainActor.run { () -> [UUID?] in
                    let localSlots = self.curatedAdSlotIDs
                    let hasPending = self.hasPendingCuratedSlotUpdateForCurrentUser()
                    let isSyncing = self.isSyncingCuratedSlots
                    if (hasPending || isSyncing), localSlots != slots {
                        let stage = isSyncing ? "slot_refresh_preserved_local_syncing" : "slot_refresh_preserved_local_pending"
                        let status = isSyncing
                            ? "Preserving local curated slots while save is syncing"
                            : "Preserving local curated slots while pending sync exists"
                        let detail = isSyncing
                            ? "Remote slots differ but local save is still in-flight."
                            : "Remote slots differ but local pending write is queued."
                        self.updateAdDebug(
                            targetID: "curated_slots",
                            stage: stage,
                            status: status,
                            detail: detail
                        )
                        return localSlots
                    }
                    let localHasSelection = localSlots.contains(where: { $0 != nil })
                    let remoteHasSelection = slots.contains(where: { $0 != nil })
                    if localHasSelection, !remoteHasSelection {
                        self.updateAdDebug(
                            targetID: "curated_slots",
                            stage: "slot_refresh_preserved_local_remote_empty",
                            status: "Preserving local curated slots while remote is empty",
                            detail: "Keeping local slots to avoid losing founder selections before backend state catches up."
                        )
                        return localSlots
                    }
                    self.curatedAdSlotIDs = slots
                    self.saveCuratedAdSlots()
                    return slots
                }
                await self.hydrateDeliveredAdsForCuratedSlots(slotIDs: effectiveSlots.compactMap { $0 })
            }
        }
    }

    private func hydrateDeliveredAdsForCuratedSlots(slotIDs: [UUID]) async {
        guard backendClient.isEnabled else { return }
        guard !slotIDs.isEmpty else { return }

        let existingIDs = Set(deliveredAdPosts.map(\.id))
        let missingIDs = slotIDs.filter { !existingIDs.contains($0) }
        guard !missingIDs.isEmpty else { return }

        do {
            let delivery = try await backendClient.fetchAdDelivery(city: nil, limit: max(20, slotIDs.count))
            let slotIDSet = Set(slotIDs)
            let matched = delivery.filter { slotIDSet.contains($0.post.id) }
            guard !matched.isEmpty else { return }

            let mappedMatched = matched.compactMap(mapDeliveredAdPost)
            guard !mappedMatched.isEmpty else { return }

            var mergedByID: [UUID: FeedPost] = [:]
            for post in deliveredAdPosts where mergedByID[post.id] == nil {
                mergedByID[post.id] = post
            }
            for post in mappedMatched {
                mergedByID[post.id] = post
                adSubmissionPostIDs.insert(post.id)
            }

            var ordered: [FeedPost] = []
            for id in slotIDs {
                if let post = mergedByID[id] {
                    ordered.append(post)
                    mergedByID.removeValue(forKey: id)
                }
            }
            ordered.append(contentsOf: mergedByID.values.sorted { $0.timestamp > $1.timestamp })
            deliveredAdPosts = Array(ordered.prefix(Self.maxCuratedAdCount))
        } catch {
            return
        }
    }

    func circle(named name: String) -> CircleGroup? {
        circles.first(where: { $0.name == name })
    }


    func followingProfiles(for profile: UserProfile) -> [UserProfile] {
        var ids = followRelations[profile.id] ?? []
        for requiredID in mandatoryFollowIDs() where requiredID != profile.id {
            ids.insert(requiredID)
        }
        guard !ids.isEmpty else { return [] }
        var byUsername: [String: UserProfile] = [:]
        for id in ids {
            guard let resolved = canonicalDirectoryProfile(for: id) else { continue }
            let key = normalizeUsername(resolved.username)
            if let existing = byUsername[key] {
                byUsername[key] = preferredProfile(existing, resolved)
            } else {
                byUsername[key] = resolved
            }
        }
        return Array(byUsername.values).sorted(by: { $0.displayName < $1.displayName })
    }

    func followerProfiles(for profile: UserProfile) -> [UserProfile] {
        let followerIDs = followRelations.compactMap { userID, following in
            following.contains(profile.id) ? userID : nil
        }
        guard !followerIDs.isEmpty else { return [] }
        var byUsername: [String: UserProfile] = [:]
        for id in followerIDs {
            guard let resolved = canonicalDirectoryProfile(for: id) else { continue }
            let key = normalizeUsername(resolved.username)
            if let existing = byUsername[key] {
                byUsername[key] = preferredProfile(existing, resolved)
            } else {
                byUsername[key] = resolved
            }
        }
        return Array(byUsername.values).sorted(by: { $0.displayName < $1.displayName })
    }

    func pendingFollowRequestProfiles(for profile: UserProfile) -> [UserProfile] {
        guard profile.id == currentUser.id else { return [] }
        return pendingFollowRequests.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func hasPendingOutgoingFollowRequest(to profile: UserProfile) -> Bool {
        guard normalizeUsername(profile.username) != normalizeUsername(currentUser.username) else { return false }
        guard let canonical = canonicalProfile(matching: profile) else { return false }
        return pendingOutgoingFollowRequestIDs.contains(canonical.id)
    }

    /// Called by the view layer just before an icon change begins.
    /// Sets iconChangePending and immediately cancels any in-flight debounced
    /// save task.  Without the cancellation, a task that was already sleeping
    /// in the queue (created by the profile save a fraction of a second earlier)
    /// would wake up and call persistStateSnapshot() right through the icon-change
    /// window — recreating the POSIX 35 write-pressure the flag is meant to stop.
    ///
    /// ALSO pauses realtime sync.  The `iconChangePending` flag only gates the
    /// JSON snapshot save — it does NOT stop realtime Postgres-changes events
    /// from firing, and each event still triggers `syncFromBackendIfAvailable`
    /// which writes HTTP response bodies to URLCache, runs JSON decoders, and
    /// produces in-memory mutations.  For founder accounts this is the dominant
    /// disk-pressure source (5+ managed accounts × follower graph × constant
    /// activity), and it's what causes `setAlternateIconName` to return
    /// EAGAIN through all 6 retry attempts.  `setRealtimeSyncPaused(true)`
    /// tears down the realtime subscription itself, so no new events arrive
    /// during the icon-change window.
    func beginIconChangePause() {
        iconChangePending = true
        pendingStateSaveTask?.cancel()
        pendingStateSaveTask = nil
        setRealtimeSyncPaused(true)
    }

    /// Called by the view layer after an icon change completes to flush any state
    /// changes that were suppressed while iconChangePending was true.  Also
    /// resumes realtime sync so the founder's inbox / feed / chat updates
    /// continue flowing once SpringBoard is done writing the icon asset.
    func saveStateAfterIconChange() {
        iconChangePending = false
        setRealtimeSyncPaused(false)
        saveState()
    }

    private func saveState(immediate: Bool = false) {
        // While an alternate app icon is being applied, skip all debounced saves.
        // Realtime sync (every 450ms) and polling (every 3s) both trigger saveState,
        // keeping the app sandbox under constant filesystem write pressure that
        // causes SpringBoard to return POSIX 35 (EAGAIN) on setAlternateIconName.
        // Pausing debounced writes for the ~2-10s icon-change window lets
        // SpringBoard write icon assets without contention. Immediate saves are
        // always honoured — they indicate important data that cannot be deferred.
        guard !iconChangePending || immediate else { return }
        pendingStateSaveTask?.cancel()
        pendingStateSaveTask = Task {  [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: Self.PersistenceCostSaverMode.saveDebounceNanos)
                guard !Task.isCancelled else { return }
                // Re-check after sleeping: iconChangePending may have been set while
                // this task was already sleeping in the queue (i.e. saveState() was
                // called before the flag was raised, so the early-return guard at the
                // top of saveState() never fired for this particular task).  Without
                // this second check the task would call persistStateSnapshot() right
                // through the icon-change window, recreating the POSIX 35 pressure
                // that the flag is designed to eliminate.
                guard !self.iconChangePending else { return }
            }
            self.persistStateSnapshot()
        }
    }

    private func scopedNotifications(_ source: [AppNotification], recipientID: UUID) -> [AppNotification] {
        source.filter { $0.recipientUserID == recipientID }
    }

    private func sampleNotificationsForCurrentUser() -> [AppNotification] {
        Self.sampleNotifications.map { sample in
            AppNotification(
                id: sample.id,
                type: sample.type,
                title: sample.title,
                message: sample.message,
                timestamp: sample.timestamp,
                isRead: sample.isRead,
                recipientUserID: currentUser.id,
                actorID: sample.actorID,
                objectID: sample.objectID
            )
        }
    }

    private func performOneTimeNotificationCacheCleanupIfNeeded() {
        let defaults = UserDefaults.standard
        let appliedVersion = defaults.integer(forKey: Self.notificationCacheCleanupVersionKey)
        guard appliedVersion < Self.notificationCacheCleanupVersion else { return }

        let stateFiles = (try? FileManager.default.contentsOfDirectory(
            at: persistenceDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for fileURL in stateFiles where fileURL.lastPathComponent.hasPrefix("scrolls-state-") && fileURL.pathExtension == "json" {
            guard let data = Persistence.loadData(from: fileURL),
                  let persisted = try? JSONDecoder().decode(ScrollsState.self, from: data) else {
                continue
            }
            let filteredNotifications = scopedNotifications(persisted.notifications, recipientID: persisted.currentUser.id)
            guard filteredNotifications.count != persisted.notifications.count else { continue }
            let cleanedState = ScrollsState(
                posts: persisted.posts,
                following: persisted.following,
                currentUser: persisted.currentUser,
                notifications: filteredNotifications,
                unreadCircleMessageIDs: persisted.unreadCircleMessageIDs,
                circles: persisted.circles,
                followers: persisted.followers,
                followRelations: persisted.followRelations,
                pinnedPostIDs: persisted.pinnedPostIDs,
                postDrafts: persisted.postDrafts,
                adSubmissionPostIDs: persisted.adSubmissionPostIDs
            )
            guard let encoded = try? JSONEncoder().encode(cleanedState) else { continue }
            try? encoded.write(to: fileURL, options: .atomic)
        }

        defaults.set(Self.notificationCacheCleanupVersion, forKey: Self.notificationCacheCleanupVersionKey)
    }

    private func stripCommentLikesFromComments(_ comments: [PostComment]) -> [PostComment] {
        comments.map { comment in
            PostComment(
                id: comment.id,
                user: comment.user,
                text: comment.text,
                timestamp: comment.timestamp,
                replies: stripCommentLikesFromComments(comment.replies),
                likedBy: []
            )
        }
    }

    private func stripCommentLikesFromPost(_ post: FeedPost) -> FeedPost {
        FeedPost(
            id: post.id,
            user: post.user,
            caption: post.caption,
            websiteURL: post.websiteURL,
            locationCity: post.locationCity,
            timestamp: post.timestamp,
            mediaPreview: post.mediaPreview,
            coverImageRef: post.coverImageRef,
            coverProvider: post.coverProvider,
            coverBucket: post.coverBucket,
            coverObjectKey: post.coverObjectKey,
            comments: stripCommentLikesFromComments(post.comments),
            rescrollOrigin: post.rescrollOrigin
        )
    }

    private func stripCommentLikesFromPosts(_ posts: [FeedPost]) -> [FeedPost] {
        posts.map { stripCommentLikesFromPost($0) }
    }

    private func persistStateSnapshot() {
        let followSnapshot = Dictionary(uniqueKeysWithValues: followRelations.map { ($0.key, Array($0.value)) })
        let validPosts = posts.filter { shouldPersistPostInSnapshot($0) }
        let persistedPosts = stripCommentLikesFromPosts(validPosts)
        let pendingMediaPosts = stripCommentLikesFromPosts(posts.filter { shouldPersistPostInPendingMediaCache($0) })
        let validPostIDs = Set(persistedPosts.map(\.id))
        let pinnedSnapshot: [UUID: UUID]
        if validPostIDs.isEmpty {
            // Preserve pins when feed snapshot is temporarily empty (for example
            // server-authoritative startup or post-logout/login transitions).
            pinnedSnapshot = pinnedPostIDs
        } else {
            pinnedSnapshot = pinnedPostIDs.filter { _, postID in validPostIDs.contains(postID) }
        }
        let cutoff = Date().addingTimeInterval(-TimeInterval(Self.NotificationCostSaverMode.retentionHours * 3600))
        let prunedNotifications = notifications.filter { $0.timestamp >= cutoff }
        // Build a profile cache of registry entries not already covered by
        // following/followers/post-authors. Sorted by most-recently-refreshed so
        // the profiles the user has visited latest are preserved under the cap.
        let alreadyCoveredProfileIDs: Set<UUID> = Set(
            [currentUser.id]
            + following.map(\.id)
            + followers.map(\.id)
            + persistedPosts.map(\.user.id)
        )
        let profileCache = Array(
            profileRegistry
                .filter { !alreadyCoveredProfileIDs.contains($0.key) }
                .sorted {
                    (profileLastRefreshedAtByID[$0.key] ?? .distantPast) >
                    (profileLastRefreshedAtByID[$1.key] ?? .distantPast)
                }
                .prefix(Self.profileCacheLimit)
                .map(\.value)
        )
        let state = ScrollsState(
            posts: persistedPosts,
            following: following,
            currentUser: currentUser,
            notifications: prunedNotifications,
            unreadCircleMessageIDs: Array(unreadCircleMessageIDs),
            circles: circles,
            followers: followers,
            followRelations: followSnapshot,
            pinnedPostIDs: pinnedSnapshot,
            postDrafts: postDrafts,
            adSubmissionPostIDs: Array(adSubmissionPostIDs),
            profileCache: profileCache,
            profileDeltaVersionByUserID: profileDeltaVersionByUserID
        )
        let url = persistenceURL
        guard let data = try? JSONEncoder().encode(state) else { return }
        let pendingMediaURL = pendingMediaPostsURL
        let pendingMediaPayload = PendingMediaPostCache(posts: pendingMediaPosts, savedAt: Date())
        let pendingMediaData = try? JSONEncoder().encode(pendingMediaPayload)
        Self.saveProfileSnapshot(currentUser)
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
            if let pendingMediaData {
                try? pendingMediaData.write(to: pendingMediaURL, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: pendingMediaURL)
            }
        }
        saveGlobalFeedCacheIfNeeded(persistedPosts)
    }


    private func saveGlobalFeedCacheIfNeeded(_ posts: [FeedPost]) {
        let cachePosts = Array(posts.prefix(Self.globalFeedCacheLimit))
        guard !cachePosts.isEmpty else { return }
        let cache = GlobalFeedCache(posts: cachePosts, savedAt: Date())
        guard let data = try? JSONEncoder().encode(cache) else { return }
        let url = globalFeedCacheURL
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func shouldPersistPostInSnapshot(_ post: FeedPost) -> Bool {
        switch post.mediaPreview {
        case .video(let preview):
            // Do not persist local-only video URLs as final state. They are transient
            // during upload and can disappear after app reinstall/new builds.
            return !preview.url.isFileURL
        default:
            return true
        }
    }

    private func shouldPersistPostInPendingMediaCache(_ post: FeedPost) -> Bool {
        guard post.user.id == currentUser.id else { return false }
        guard !pendingDeletedPostIDs.contains(post.id) else { return false }
        guard post.rescrollOrigin == nil else { return false }
        switch post.mediaPreview {
        case .video(let preview):
            return preview.url.isFileURL
        case .photo:
            return false
        case .text:
            return false
        }
    }

    private func loadGlobalFeedCache() -> [FeedPost] {
        let url = globalFeedCacheURL
        guard let data = Persistence.loadData(from: url),
              let cache = try? JSONDecoder().decode(GlobalFeedCache.self, from: data) else {
            return []
        }
        return cache.posts
    }

    private func hydrateFeedFromGlobalCacheIfNeeded(_ cachedPosts: [FeedPost]) {
        guard posts.isEmpty, !cachedPosts.isEmpty else { return }
        posts = cachedPosts
        registerProfiles(from: cachedPosts.map { $0.user })
        removePostsWithMissingMedia(checkAssetLibrary: false)
    }

    private func loadPendingDeletionQueue() -> [PendingDeletionRequest] {
        let url = pendingDeletionsURL
        guard let data = Persistence.loadData(from: url) else { return [] }
        if let queue = try? JSONDecoder().decode(PendingDeletionQueue.self, from: data) {
            return queue.deletions
        }
        if let deletions = try? JSONDecoder().decode([PendingDeletionRequest].self, from: data) {
            return deletions
        }
        return []
    }

    /// Persistent map of `postID → authorID` for every post the user has
    /// ever requested deleted.  Storing the authorID alongside lets us
    /// re-fire the delete RPC for stuck deletions without needing the post
    /// to still be present in any local cache.  Lives across app launches.
    /// In-memory mirror of the file content.
    private var userDeletedPostAuthorIDs: [UUID: UUID] = [:]

    /// Reads the persistent "ever-deleted post IDs" set from disk.  Called
    /// at startup to repopulate `pendingDeletedPostIDs` so the user's
    /// historical deletions remain filtered out of search/feed even if the
    /// retry queue has long since drained (whether correctly or in error).
    ///
    /// Schema evolution: older builds wrote a `[UUID]` (just post IDs).
    /// Newer builds write a `[String: String]` (postID → authorID).  We try
    /// the new schema first and fall back to the old one for users who
    /// haven't toggled a delete since the upgrade.  Either schema
    /// populates `pendingDeletedPostIDs`; the new schema also populates
    /// `userDeletedPostAuthorIDs` so we can re-fire deletes later.
    private func loadUserDeletedPostIDs() -> Set<UUID> {
        let url = userDeletedPostIDsURL
        guard let data = Persistence.loadData(from: url) else { return [] }
        if let mapPayload = try? JSONDecoder().decode([String: String].self, from: data) {
            var seenPostIDs: Set<UUID> = []
            var authorMap: [UUID: UUID] = [:]
            for (rawPost, rawAuthor) in mapPayload {
                guard let postID = UUID(uuidString: rawPost) else { continue }
                seenPostIDs.insert(postID)
                if let authorID = UUID(uuidString: rawAuthor) {
                    authorMap[postID] = authorID
                }
            }
            userDeletedPostAuthorIDs = authorMap
            return seenPostIDs
        }
        // Legacy schema: just an array of post IDs.  We still load them so
        // the user's filter set is preserved, but without the authorID we
        // can't auto-retry the backend delete until they encounter the
        // post in a remote response (which will repopulate the authorID).
        if let legacyIDs = try? JSONDecoder().decode([UUID].self, from: data) {
            return Set(legacyIDs)
        }
        return []
    }

    /// Persists the current "ever-deleted post IDs" set to disk.  Called
    /// every time a new post is added to `pendingDeletedPostIDs` via the
    /// deletion entry points.  Idempotent — writes the full set each time
    /// because the set is small (< 1 KB even for power users).
    private func saveUserDeletedPostIDs() {
        let url = userDeletedPostIDsURL
        guard !pendingDeletedPostIDs.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        // New schema: `[postID: authorID]` map.  Entries that don't have a
        // known author yet (loaded from a legacy file before this build, or
        // queued via a path that didn't capture the author) write an empty
        // string for the value — still decodable as a Set<UUID> for the
        // filter set, and we'll fill in the authorID the next time the
        // post is encountered in a remote response.
        let payload: [String: String] = pendingDeletedPostIDs.reduce(into: [String: String]()) { result, postID in
            let authorID = userDeletedPostAuthorIDs[postID]
            result[postID.uuidString] = authorID?.uuidString ?? ""
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadListenedCircleVoiceMessageIDs() -> Set<UUID> {
        guard let data = Persistence.loadData(from: listenedCircleVoiceMessageIDsURL),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(ids)
    }

    private func saveListenedCircleVoiceMessageIDs() {
        let url = listenedCircleVoiceMessageIDsURL
        guard !listenedCircleVoiceMessageIDs.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? JSONEncoder().encode(Array(listenedCircleVoiceMessageIDs)) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func filterListenedCircleVoiceMessages(in circles: [CircleGroup]) -> [CircleGroup] {
        guard !listenedCircleVoiceMessageIDs.isEmpty else { return circles }
        return circles.map { circle in
            var updated = circle
            updated.messages.removeAll { message in
                listenedCircleVoiceMessageIDs.contains(message.id) && message.hasVoiceAttachment
            }
            return updated
        }
    }

    private func savePendingDeletionQueue() {
        let url = pendingDeletionsURL
        guard !pendingDeletionQueue.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let payload = PendingDeletionQueue(deletions: pendingDeletionQueue, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadPendingFollowSyncQueue() -> [PendingFollowSyncOperation] {
        let url = pendingFollowsURL
        guard let data = Persistence.loadData(from: url) else { return [] }
        if let queue = try? JSONDecoder().decode(PendingFollowSyncQueue.self, from: data) {
            return queue.operations
        }
        if let operations = try? JSONDecoder().decode([PendingFollowSyncOperation].self, from: data) {
            return operations
        }
        return []
    }

    private func savePendingFollowSyncQueue() {
        let url = pendingFollowsURL
        guard !pendingFollowSyncQueue.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let payload = PendingFollowSyncQueue(operations: pendingFollowSyncQueue, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadPendingBackendWriteQueue() -> [PendingBackendWriteOperation] {
        let url = pendingBackendWritesURL
        guard let data = Persistence.loadData(from: url) else { return [] }
        if let queue = try? JSONDecoder().decode(PendingBackendWriteQueue.self, from: data) {
            return queue.operations
        }
        if let operations = try? JSONDecoder().decode([PendingBackendWriteOperation].self, from: data) {
            return operations
        }
        return []
    }

    private func savePendingBackendWriteQueue() {
        let url = pendingBackendWritesURL
        guard !pendingBackendWriteQueue.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let payload = PendingBackendWriteQueue(operations: pendingBackendWriteQueue, savedAt: Date())
        guard let data = try? JSONEncoder().encode(payload) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func backendWriteDedupKey(for operation: PendingBackendWriteOperation) -> String {
        switch operation.kind {
        case .commentCreate:
            let commentID = operation.commentID?.uuidString.lowercased() ?? "none"
            return "comment-create:\(operation.userID.uuidString.lowercased()):\(commentID)"
        case .commentDelete:
            let commentID = operation.commentID?.uuidString.lowercased() ?? "none"
            return "comment-delete:\(operation.userID.uuidString.lowercased()):\(commentID)"
        case .commentLikeCreate:
            let commentID = operation.commentID?.uuidString.lowercased() ?? "none"
            return "comment-like-create:\(operation.userID.uuidString.lowercased()):\(commentID)"
        case .commentLikeDelete:
            let commentID = operation.commentID?.uuidString.lowercased() ?? "none"
            return "comment-like-delete:\(operation.userID.uuidString.lowercased()):\(commentID)"
        case .rescrollCreate:
            let originalPostID = operation.originalPostID?.uuidString.lowercased() ?? "none"
            return "rescroll-create:\(operation.userID.uuidString.lowercased()):\(originalPostID)"
        case .rescrollDelete:
            let rescrollPostID = operation.rescrollPostID?.uuidString.lowercased() ?? "none"
            return "rescroll-delete:\(operation.userID.uuidString.lowercased()):\(rescrollPostID)"
        case .circleMessage:
            let messageID = operation.messageID?.uuidString.lowercased() ?? operation.id.uuidString.lowercased()
            return "circle-message:\(operation.userID.uuidString.lowercased()):\(messageID)"
        case .circleClear:
            let circleID = operation.circleID?.uuidString.lowercased() ?? "none"
            return "circle-clear:\(operation.userID.uuidString.lowercased()):\(circleID)"
        case .circleDelete:
            let circleID = operation.circleID?.uuidString.lowercased() ?? "none"
            return "circle-delete:\(operation.userID.uuidString.lowercased()):\(circleID)"
        case .adCuratedPostPublish:
            let postID = operation.postID?.uuidString.lowercased() ?? "none"
            return "ad-curated-post-publish:\(operation.userID.uuidString.lowercased()):\(postID)"
        case .adCuratedSlotUpdate:
            return "ad-curated-slot-update:\(operation.userID.uuidString.lowercased())"
        case .notificationsMarkAllRead:
            return "notifications-mark-all-read:\(operation.userID.uuidString.lowercased())"
        case .notificationsDeleteRead:
            return "notifications-delete-read:\(operation.userID.uuidString.lowercased())"
        }
    }

    private func enqueuePendingBackendWrite(_ operation: PendingBackendWriteOperation) {
        if let commentID = operation.commentID {
            switch operation.kind {
            case .commentLikeCreate:
                pendingBackendWriteQueue.removeAll {
                    $0.userID == operation.userID
                        && $0.commentID == commentID
                        && $0.kind == .commentLikeDelete
                }
            case .commentLikeDelete:
                pendingBackendWriteQueue.removeAll {
                    $0.userID == operation.userID
                        && $0.commentID == commentID
                        && $0.kind == .commentLikeCreate
                }
            default:
                break
            }
        }
        let dedupKey = backendWriteDedupKey(for: operation)
        pendingBackendWriteQueue.removeAll { backendWriteDedupKey(for: $0) == dedupKey }
        pendingBackendWriteQueue.append(operation)
        pendingBackendWriteQueue.sort { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
        savePendingBackendWriteQueue()
        refreshPostSyncIndicator(reason: "enqueue_backend_write", force: true)
    }

    private var isBackendWriteTerminalAuthBlocked: Bool {
        lastTerminalAuthFailureAt != nil && !hasLocallyUsableAuthToken()
    }

    private func triggerPendingBackendWriteFlush(after delayNanos: UInt64 = 0, force: Bool = false) {
        if force {
            backendWriteFlushTask?.cancel()
            backendWriteFlushTask = nil
        }
        guard backendWriteFlushTask == nil else { return }
        backendWriteFlushTask = Task {  [weak self] in
            guard let self else { return }
            if delayNanos > 0 {
                try? await Task.sleep(nanoseconds: delayNanos)
                guard !Task.isCancelled else { return }
            }
            let nextDelay = await self.flushPendingBackendWriteQueue()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.backendWriteFlushTask = nil
                guard !self.pendingBackendWriteQueue.isEmpty else { return }
                let fallbackDelay: UInt64 = self.isBackendWriteTerminalAuthBlocked
                    ? Self.backendWriteTerminalAuthRetryDelayNanos
                    : 500_000_000
                let scheduledDelay = nextDelay ?? fallbackDelay
                self.triggerPendingBackendWriteFlush(after: scheduledDelay)
            }
        }
    }

    private func executePendingBackendWrite(_ operation: PendingBackendWriteOperation) async throws {
        switch operation.kind {
        case .commentCreate:
            guard let postID = operation.postID,
                  let authorID = operation.authorID,
                  let body = operation.body,
                  let commentID = operation.commentID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "comment_create_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.createComment(
                    postID: postID,
                    authorID: authorID,
                    body: body,
                    parentCommentID: operation.parentCommentID,
                    commentID: commentID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .commentDelete:
            guard let commentID = operation.commentID,
                  let authorID = operation.authorID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "comment_delete_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.deleteComment(
                    commentID: commentID,
                    authorID: authorID,
                    requestedByID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .commentLikeCreate:
            guard let commentID = operation.commentID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "comment_like_create_queue",
                debugContext: BackendWriteDebugContext(
                    domain: .commentLike,
                    targetID: commentID.uuidString,
                    action: "comment_like_create_queue"
                ),
                maxAttempts: 2,
                timeoutPerAttempt: 15
            ) { authTokenOverride in
                try await self.backendClient.createCommentLike(
                    commentID: commentID,
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .commentLikeDelete:
            guard let commentID = operation.commentID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "comment_like_delete_queue",
                debugContext: BackendWriteDebugContext(
                    domain: .commentLike,
                    targetID: commentID.uuidString,
                    action: "comment_like_delete_queue"
                ),
                maxAttempts: 2,
                timeoutPerAttempt: 15
            ) { authTokenOverride in
                try await self.backendClient.deleteCommentLike(
                    commentID: commentID,
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .rescrollCreate:
            guard let originalPostID = operation.originalPostID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "rescroll_create_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.createRescroll(
                    userID: operation.userID,
                    originalPostID: originalPostID,
                    quoteText: self.normalizedRescrollQuoteText(operation.body),
                    authTokenOverride: authTokenOverride
                )
            }
        case .rescrollDelete:
            guard let rescrollPostID = operation.rescrollPostID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "rescroll_delete_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.deleteRescroll(
                    userID: operation.userID,
                    rescrollPostID: rescrollPostID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .circleMessage:
            guard let circleID = operation.circleID,
                  let messageID = operation.messageID,
                  let encryptedText = operation.encryptedText,
                  let messageTimestamp = operation.messageTimestamp else { return }
            let message = CircleMessage(
                id: messageID,
                userID: operation.userID,
                encryptedText: encryptedText,
                timestamp: messageTimestamp,
                sharedPostID: operation.postID
            )
            updateCircleMessageDebug(
                messageID: messageID,
                stage: "queue_dispatch_request",
                status: "Retry worker sending queued message",
                detail: "\(circleMessageDebugSummary(operation: operation, source: "queue_dispatch")), \(circleLocalMembershipDebugSummary(circleID: circleID))",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            updateMessageSendStatus(messageID, in: circleID, status: .sending)
            do {
                try await performAuthenticatedBackendWrite(
                    operationName: "circle_message_send_queue",
                    debugContext: BackendWriteDebugContext(
                        domain: .circleMessage,
                        targetID: messageID.uuidString,
                        action: "circle_message_send_queue"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.sendCircleMessage(
                        circleID: circleID,
                        message: message,
                        authTokenOverride: authTokenOverride
                    )
                }
                updateMessageSendStatus(messageID, in: circleID, status: .sent)
                updateCircleMessageDebug(
                    messageID: messageID,
                    stage: "sync_success_queue",
                    status: "Queued message synced",
                    detail: "\(circleMessageDebugSummary(operation: operation, source: "queue_success")), outcome=success",
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
            } catch {
                updateCircleMessageDebug(
                    messageID: messageID,
                    stage: "queue_dispatch_failed",
                    status: "Queued message send failed",
                    detail: "\(circleMessageDebugSummary(operation: operation, source: "queue_failure")), outcome=failure, terminal_auth=\(isTerminalAuthFailureForBackendWrite(error) ? "yes" : "no"), \(circleLocalMembershipDebugSummary(circleID: circleID))",
                    error: error,
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                throw error
            }
        case .circleClear:
            guard let circleID = operation.circleID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "circle_clear_queue",
                maxAttempts: 1,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.clearCircleMessages(
                    circleID: circleID,
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .circleDelete:
            guard let circleID = operation.circleID else { return }
            try await performAuthenticatedBackendWrite(
                operationName: "circle_delete_queue",
                maxAttempts: 1,
                timeoutPerAttempt: 20
            ) { authTokenOverride in
                try await self.backendClient.deleteCircle(
                    circleID: circleID,
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .adCuratedPostPublish:
            guard let postID = operation.postID else { return }
            updateAdDebug(
                targetID: postID.uuidString,
                stage: "ad_post_publish_queue_request",
                status: "Retrying curated ad publish from queue",
                detail: "retry=\(operation.retryCount + 1)",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            guard let localPost = posts.first(where: { $0.id == postID })
                ?? deliveredAdPosts.first(where: { $0.id == postID }) else {
                updateAdDebug(
                    targetID: postID.uuidString,
                    stage: "ad_post_publish_queue_evicted",
                    status: "Queued ad publish dropped",
                    detail: "Post not found in local state."
                )
                return
            }
            try await performAuthenticatedBackendWrite(
                operationName: "ad_post_publish_queue",
                debugContext: BackendWriteDebugContext(
                    domain: .ad,
                    targetID: postID.uuidString,
                    action: "ad_post_publish_queue"
                ),
                maxAttempts: 1,
                timeoutPerAttempt: 45
            ) { _ in
                try await self.publishPostToBackend(
                    localPost,
                    author: localPost.user,
                    maxAttempts: 1,
                    timeoutPerAttempt: 40
                )
            }
            updateAdDebug(
                targetID: postID.uuidString,
                stage: "ad_post_publish_queue_acknowledged",
                status: "Curated ad publish retry succeeded",
                detail: "Backend acknowledged curated ad publish from queue."
            )
        case .adCuratedSlotUpdate:
            let targetID = operation.postID?.uuidString ?? "curated_slots"
            let slotsSnapshot = curatedAdSlotIDs
            try await performAuthenticatedBackendWrite(
                operationName: "ad_curated_slot_update_queue",
                debugContext: BackendWriteDebugContext(
                    domain: .ad,
                    targetID: targetID,
                    action: "ad_curated_slot_update_queue"
                ),
                maxAttempts: 1,
                timeoutPerAttempt: 20
            ) { _ in
                let updated = try await self.backendClient.updateCuratedAdSlots(postIDs: slotsSnapshot)
                await MainActor.run {
                    self.curatedAdSlotIDs = updated
                    self.saveCuratedAdSlots()
                }
            }
            updateAdDebug(
                targetID: targetID,
                stage: "ad_slot_update_queue_acknowledged",
                status: "Curated ad slot retry succeeded",
                detail: "Backend confirmed curated slot assignment."
            )
        case .notificationsMarkAllRead:
            try await performAuthenticatedBackendWrite(
                operationName: "notifications_mark_all_read_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 15
            ) { authTokenOverride in
                try await self.backendClient.markAllNotificationsRead(
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        case .notificationsDeleteRead:
            try await performAuthenticatedBackendWrite(
                operationName: "notifications_delete_read_queue",
                maxAttempts: 2,
                timeoutPerAttempt: 15
            ) { authTokenOverride in
                try await self.backendClient.deleteReadNotifications(
                    userID: operation.userID,
                    authTokenOverride: authTokenOverride
                )
            }
        }
    }

    private func flushPendingBackendWriteQueue() async -> UInt64? {
        guard !pendingBackendWriteQueue.isEmpty else { return nil }
        let now = Date()
        var evictedForAge = 0
        var evictedForRetryCap = 0
        let trimmedQueue = pendingBackendWriteQueue.filter { operation in
            if now.timeIntervalSince(operation.createdAt) > BackendPollingCostSaverMode.backendWriteQueueMaxOperationAge {
                evictedForAge += 1
                return false
            }
            if operation.retryCount > BackendPollingCostSaverMode.backendWriteQueueMaxRetryCount {
                evictedForRetryCap += 1
                return false
            }
            return true
        }
        if trimmedQueue != pendingBackendWriteQueue {
            pendingBackendWriteQueue = trimmedQueue
            savePendingBackendWriteQueue()
            refreshPostSyncIndicator(reason: "queue_trimmed", force: true)
            updateFeedDebug(
                stage: "backend_write_queue_trimmed",
                status: "Trimmed stale backend sync operations",
                detail: "evicted_age=\(evictedForAge), evicted_retry_cap=\(evictedForRetryCap), remaining=\(trimmedQueue.count)"
            )
        }
        guard !pendingBackendWriteQueue.isEmpty else { return nil }

        let backendWriteCooldownSeconds = backendWriteRateLimitCooldownRemainingSeconds(now: now)
        if backendWriteCooldownSeconds > 0 {
            let shouldLog = now.timeIntervalSince(lastBackendWriteRateLimitPauseLogAt) >= Self.backendWriteRateLimitLogInterval
            if shouldLog {
                lastBackendWriteRateLimitPauseLogAt = now
                let authSnapshot = currentAuthSnapshotForSyncDebug()
                updateFeedDebug(
                    stage: "backend_write_queue_paused_rate_limited",
                    status: "Pending backend writes paused; backend is rate limited",
                    detail: "queue_state=paused_rate_limited, pending_total=\(pendingBackendWriteQueue.count), cooldown_remaining=\(backendWriteCooldownSeconds)s",
                    authPreflight: authSnapshot
                )
                if let pendingCircleMessage = pendingBackendWriteQueue.last(where: {
                    $0.userID == currentUser.id && $0.kind == .circleMessage && $0.messageID != nil
                }), let messageID = pendingCircleMessage.messageID {
                    updateCircleMessageDebug(
                        messageID: messageID,
                        stage: "queue_paused_rate_limited",
                        status: "Message queue paused; backend rate limited",
                        detail: "Retry deferred until rate-limit cooldown expires.",
                        authPreflight: authSnapshot
                    )
                }
            }
            let retryDelay = max(1, backendWriteCooldownSeconds + 1)
            return UInt64(retryDelay) * 1_000_000_000
        }

        let hasUsableToken = hasLocallyUsableAuthToken()
        let hasRefreshToken = hasRefreshTokenForBackendSync()
        let hasRecoverableCandidate = hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)

        if isBackendWriteTerminalAuthBlocked {
            refreshPostSyncIndicator(reason: "queue_paused_terminal_auth", force: true)
            let shouldLog = now.timeIntervalSince(lastBackendWriteNoSessionPauseLogAt) >= Self.backendWriteNoSessionLogInterval
            if shouldLog {
                lastBackendWriteNoSessionPauseLogAt = now
                let authSnapshot = currentAuthSnapshotForSyncDebug()
                updateFeedDebug(
                    stage: "backend_write_queue_paused_terminal_auth",
                    status: "Pending backend writes paused; terminal auth failure detected",
                    detail: "queue_state=paused_terminal_auth, pending_total=\(pendingBackendWriteQueue.count), worker_retry_delay=30s",
                    authPreflight: authSnapshot
                )
                if let pendingCircleMessage = pendingBackendWriteQueue.last(where: {
                    $0.userID == currentUser.id && $0.kind == .circleMessage && $0.messageID != nil
                }), let messageID = pendingCircleMessage.messageID {
                    updateCircleMessageDebug(
                        messageID: messageID,
                        stage: "queue_paused_terminal_auth",
                        status: "Message queue paused; terminal auth failure",
                        detail: "Waiting for session repair before retrying queued message.",
                        authPreflight: authSnapshot
                    )
                }
            }
            return Self.backendWriteTerminalAuthRetryDelayNanos
        }

        if !hasUsableToken && !hasRefreshToken && !hasRecoverableCandidate {
            refreshPostSyncIndicator(reason: "queue_paused_no_session", force: true)
            let shouldLog = now.timeIntervalSince(lastBackendWriteNoSessionPauseLogAt) >= Self.backendWriteNoSessionLogInterval
            let nextRetryDelay: UInt64 = Self.backendWriteAuthBlockedRetryDelayNanos
            if shouldLog {
                lastBackendWriteNoSessionPauseLogAt = now
                let authSnapshot = currentAuthSnapshotForSyncDebug()
                let pendingCurrentUserCount = pendingBackendWriteQueue.filter { $0.userID == currentUser.id }.count
                let pendingCircleCount = pendingBackendWriteQueue.filter {
                    $0.userID == currentUser.id
                        && ($0.kind == .circleMessage || $0.kind == .circleClear || $0.kind == .circleDelete)
                }.count
                let pendingAdCount = pendingBackendWriteQueue.filter {
                    $0.userID == currentUser.id
                        && ($0.kind == .adCuratedPostPublish || $0.kind == .adCuratedSlotUpdate)
                }.count
                let pendingCommentCount = pendingBackendWriteQueue.filter {
                    $0.userID == currentUser.id
                        && ($0.kind == .commentCreate
                            || $0.kind == .commentDelete
                            || $0.kind == .commentLikeCreate
                            || $0.kind == .commentLikeDelete)
                }.count
                let pendingRescrollCount = pendingBackendWriteQueue.filter { $0.userID == currentUser.id && ($0.kind == .rescrollCreate || $0.kind == .rescrollDelete) }.count
                updateFeedDebug(
                    stage: "backend_write_queue_paused_no_session",
                    status: "Pending backend writes paused; awaiting session recovery",
                    detail: "queue_state=paused_no_session, pending_total=\(pendingBackendWriteQueue.count), pending_current_user=\(pendingCurrentUserCount), pending_circle=\(pendingCircleCount), pending_comment=\(pendingCommentCount), pending_rescroll=\(pendingRescrollCount), pending_ad=\(pendingAdCount), worker_retry_delay=20s",
                    authPreflight: authSnapshot
                )
                if let pendingCircleMessage = pendingBackendWriteQueue.last(where: {
                    $0.userID == currentUser.id && $0.kind == .circleMessage && $0.messageID != nil
                }), let messageID = pendingCircleMessage.messageID {
                    updateCircleMessageDebug(
                        messageID: messageID,
                        stage: "queue_paused_no_session",
                        status: "Message queue paused; waiting for session recovery",
                        detail: "No token/refresh credentials available. Queue remains intact and retries are deferred.",
                        authPreflight: authSnapshot
                    )
                }
            }
            return nextRetryDelay
        }

        let queueSnapshot = pendingBackendWriteQueue
        var remaining: [PendingBackendWriteOperation] = []
        var authBlocked = false
        var rateLimited = false

        for operation in queueSnapshot {
            guard !Task.isCancelled else { return nil }
            if operation.userID != currentUser.id {
                remaining.append(operation)
                continue
            }
            do {
                try await executePendingBackendWrite(operation)
                lastTerminalAuthFailureAt = nil
                switch operation.kind {
                case .commentLikeCreate:
                    if let commentID = operation.commentID {
                        markCommentLikeBackendAcknowledged(commentID, isLiked: true)
                    }
                    if let postID = operation.postID {
                        cachedCommentsFetchedAt.removeValue(forKey: postID)
                        _ = await refreshCommentsFromBackendForCanonicalPostID(postID, forceRefresh: true)
                    }
                case .commentLikeDelete:
                    if let commentID = operation.commentID {
                        markCommentLikeBackendAcknowledged(commentID, isLiked: false)
                    }
                    if let postID = operation.postID {
                        cachedCommentsFetchedAt.removeValue(forKey: postID)
                        _ = await refreshCommentsFromBackendForCanonicalPostID(postID, forceRefresh: true)
                    }
                default:
                    break
                }
            } catch {
                let terminalAuthFailure = isTerminalAuthFailureForBackendWrite(error)
                let founderPermissionDenied = isFounderPermissionDeniedError(error)
                if founderPermissionDenied {
                    noteFounderClaimMismatchSignal(error)
                }
                if terminalAuthFailure {
                    lastTerminalAuthFailureAt = Date()
                }
                if (isAuthenticationFailureError(error) && founderPermissionDenied == false) || isBackendWritePreflightError(error) {
                    authBlocked = true
                }
                if isFeedRateLimitError(error) {
                    rateLimited = true
                }
                // Auth failures are recoverable once the session heals — don't count them
                // toward the retry cap so the post isn't evicted while waiting for re-auth.
                // Only real, non-auth failures should consume retry budget.
                let isAuthBlockedFailure = (isAuthenticationFailureError(error) && founderPermissionDenied == false)
                    || isBackendWritePreflightError(error)
                let nextRetryCount = isAuthBlockedFailure
                    ? operation.retryCount
                    : min(operation.retryCount + 1, 999)
                let retryOperation = PendingBackendWriteOperation(
                    id: operation.id,
                    kind: operation.kind,
                    createdAt: operation.createdAt,
                    retryCount: nextRetryCount,
                    userID: operation.userID,
                    postID: operation.postID,
                    authorID: operation.authorID,
                    commentID: operation.commentID,
                    body: operation.body,
                    parentCommentID: operation.parentCommentID,
                    originalPostID: operation.originalPostID,
                    rescrollPostID: operation.rescrollPostID,
                    circleID: operation.circleID,
                    messageID: operation.messageID,
                    encryptedText: operation.encryptedText,
                    messageTimestamp: operation.messageTimestamp
                )
                let isAdFounderPermissionDenied = (operation.kind == .adCuratedSlotUpdate || operation.kind == .adCuratedPostPublish)
                    && founderPermissionDenied
                let isAdCuratedDataError = operation.kind == .adCuratedSlotUpdate
                    && isCuratedSlotDataError(error)
                // Circle message/delete 401s that survive auth recovery are membership-scope
                // failures — a refreshed token won't fix them. Evict after 2 retries so the
                // queue doesn't loop until the 20-retry cap.
                let isCircleAuthDeadlock = (operation.kind == .circleMessage || operation.kind == .circleDelete)
                    && isAuthenticationFailureError(error)
                    && isCircleScopeDeniedError(error) == false
                    && operation.retryCount >= 2
                if isAdFounderPermissionDenied {
                    let targetID = operation.postID?.uuidString ?? "curated_slots"
                    updateAdDebug(
                        targetID: targetID,
                        stage: "queue_evicted_permission_denied",
                        status: "Queued founder ad sync evicted: permission denied",
                        detail: "Permission denied from backend for founder ad operation.",
                        error: error,
                        authPreflight: currentAuthSnapshotForSyncDebug()
                    )
                } else if isAdCuratedDataError {
                    let targetID = operation.postID?.uuidString ?? "curated_slots"
                    updateAdDebug(
                        targetID: targetID,
                        stage: "queue_evicted_data_error",
                        status: "Queued curated slot sync evicted: data not ready",
                        detail: "Submission/post missing or not approved. Not retrying until backend data is fixed.",
                        error: error,
                        authPreflight: currentAuthSnapshotForSyncDebug()
                    )
                } else if isCircleAuthDeadlock {
                    if let messageID = operation.messageID {
                        updateCircleMessageDebug(
                            messageID: messageID,
                            stage: "queue_evicted_auth_deadlock",
                            status: "Queued message evicted: repeated auth failure",
                            detail: "\(circleMessageDebugSummary(operation: operation, source: "queue_evicted")), outcome=evicted, retry_count=\(operation.retryCount), error=\(backendErrorDebugString(error))",
                            error: error,
                            authPreflight: currentAuthSnapshotForSyncDebug()
                        )
                        if let circleID = operation.circleID {
                            updateMessageSendStatus(messageID, in: circleID, status: .failed)
                        }
                    }
                } else {
                    if operation.kind == .circleMessage,
                       let messageID = operation.messageID {
                        let nextRetryCount = retryOperation.retryCount
                        updateCircleMessageDebug(
                            messageID: messageID,
                            stage: terminalAuthFailure ? "queue_requeued_terminal_auth" : "queue_requeued_retry",
                            status: terminalAuthFailure
                                ? "Queued message paused for terminal auth failure"
                                : "Queued message requeued for retry",
                            detail: "\(circleMessageDebugSummary(operation: retryOperation, source: "queue_requeued")), outcome=failure, terminal_auth=\(terminalAuthFailure ? "yes" : "no"), next_retry_count=\(nextRetryCount), error=\(backendErrorDebugString(error))",
                            error: error,
                            authPreflight: currentAuthSnapshotForSyncDebug()
                        )
                    }
                    remaining.append(retryOperation)
                }
            }
        }

        if remaining != pendingBackendWriteQueue {
            pendingBackendWriteQueue = remaining
            savePendingBackendWriteQueue()
            refreshPostSyncIndicator(reason: "queue_flushed", force: true)
        }
        guard !remaining.isEmpty else {
            refreshPostSyncIndicator(reason: "queue_drained", force: true)
            return nil
        }

        if rateLimited {
            let cooldownSeconds = backendWriteRateLimitCooldownRemainingSeconds()
            let retryDelaySeconds = max(8, cooldownSeconds + 1)
            return UInt64(retryDelaySeconds) * 1_000_000_000
        }
        if authBlocked {
            return isBackendWriteTerminalAuthBlocked
                ? Self.backendWriteTerminalAuthRetryDelayNanos
                : Self.backendWriteAuthBlockedRetryDelayNanos
        }
        return 4_000_000_000
    }

    private func enqueuePendingFollowSync(followerID: UUID, followeeID: UUID, isFollowing: Bool) {
        guard followerID != followeeID else {
            // Never queue invalid self-follow operations.
            pendingFollowSyncQueue.removeAll {
                $0.followerID == followerID && $0.followeeID == followeeID
            }
            savePendingFollowSyncQueue()
            return
        }
        if !isFollowing, mandatoryFollowIDs().contains(followeeID) {
            // Founder-required follows cannot be removed. Drop any stale unfollow op.
            pendingFollowSyncQueue.removeAll {
                $0.followerID == followerID && $0.followeeID == followeeID
            }
            savePendingFollowSyncQueue()
            return
        }
        pendingFollowSyncQueue.removeAll {
            $0.followerID == followerID && $0.followeeID == followeeID
        }
        let operation = PendingFollowSyncOperation(
            followerID: followerID,
            followeeID: followeeID,
            isFollowing: isFollowing,
            createdAt: Date(),
            retryCount: 0
        )
        pendingFollowSyncQueue.append(operation)
        savePendingFollowSyncQueue()
    }

    private func triggerPendingFollowSyncFlush(after delayNanos: UInt64 = 0, force: Bool = false) {
        if force {
            followSyncFlushTask?.cancel()
            followSyncFlushTask = nil
        }
        guard followSyncFlushTask == nil else { return }
        followSyncFlushTask = Task {  [weak self] in
            guard let self else { return }
            if delayNanos > 0 {
                try? await Task.sleep(nanoseconds: delayNanos)
                guard !Task.isCancelled else { return }
            }
            await self.flushPendingFollowSyncQueue()
            await MainActor.run {
                self.followSyncFlushTask = nil
                if !self.pendingFollowSyncQueue.isEmpty {
                    let maxRetry = self.pendingFollowSyncQueue.map(\.retryCount).max() ?? 0
                    let backoffNanos: UInt64 = maxRetry < 2 ? 2_000_000_000 : 10_000_000_000
                    self.triggerPendingFollowSyncFlush(after: backoffNanos)
                }
            }
        }
    }

    private func flushPendingFollowSyncQueue() async {
        guard backendClient.isEnabled, !pendingFollowSyncQueue.isEmpty else { return }
        var remaining: [PendingFollowSyncOperation] = []
        for operation in pendingFollowSyncQueue {
            guard !Task.isCancelled else {
                remaining.append(operation)
                continue
            }
            // Drop malformed/stale self-follow operations from older builds so they
            // stop retrying forever and tripping DB follow constraints.
            if operation.followerID == operation.followeeID {
                continue
            }
            if !isFollowOperationForCurrentUser(operation) {
                remaining.append(operation)
                continue
            }
            let resolvedFollowerID = currentUser.id
            if operation.followeeID == resolvedFollowerID {
                continue
            }
            if !operation.isFollowing, mandatoryFollowIDs().contains(operation.followeeID) {
                // Founder-required follows are immutable; discard stale unfollow ops.
                continue
            }
            do {
                var response: BackendFollowResponse?
                try await performAuthenticatedBackendWrite(
                    operationName: operation.isFollowing ? "follow_set" : "unfollow_set",
                    maxAttempts: 2,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    response = try await self.backendClient.setFollow(
                        followerID: resolvedFollowerID,
                        followeeID: operation.followeeID,
                        isFollowing: operation.isFollowing,
                        authTokenOverride: authTokenOverride
                    )
                }
                guard let response else {
                    throw BackendClientError.requestFailed
                }
                applyFollowSyncResult(operation: operation, response: response)
            } catch {
                recordAuthFailure(
                    error,
                    context: operation.isFollowing ? "Follow sync flush" : "Unfollow sync flush",
                    recovery: "Queued for retry"
                )
                remaining.append(
                    PendingFollowSyncOperation(
                        followerID: resolvedFollowerID,
                        followeeID: operation.followeeID,
                        isFollowing: operation.isFollowing,
                        createdAt: operation.createdAt,
                        retryCount: operation.retryCount + 1
                    )
                )
            }
        }
        if remaining != pendingFollowSyncQueue {
            pendingFollowSyncQueue = remaining
            savePendingFollowSyncQueue()
        }
    }

    private func applyFollowSyncResult(operation: PendingFollowSyncOperation, response: BackendFollowResponse) {
        if operation.isFollowing {
            let isPending = response.status?.lowercased() == "pending"
            if isPending {
                pendingOutgoingFollowRequestIDs.insert(operation.followeeID)
            } else {
                pendingOutgoingFollowRequestIDs.remove(operation.followeeID)
            }
        } else {
            pendingOutgoingFollowRequestIDs.remove(operation.followeeID)
        }
    }

    private func isFollowOperationForCurrentUser(_ operation: PendingFollowSyncOperation) -> Bool {
        if operation.followerID == currentUser.id {
            return true
        }
        let currentUsername = normalizeUsername(currentUser.username)
        if let profile = profileRegistry[operation.followerID] {
            return normalizeUsername(profile.username) == currentUsername
        }
        if let record = LocalAuthStore.sessionRecords().first(where: { $0.id == operation.followerID }) {
            return normalizeUsername(record.username) == currentUsername
        }
        return false
    }

    private func purgePendingDeletedPostsFromLocalState() {
        guard !pendingDeletedPostIDs.isEmpty else { return }
        posts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
        pendingRemotePosts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
        deliveredAdPosts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
    }

    private func enqueuePendingDeletion(
        kind: PendingDeletionRequest.Kind,
        postID: UUID,
        authorID: UUID,
        post: FeedPost? = nil
    ) {
        var request = PendingDeletionRequest(kind: kind, postID: postID, authorID: authorID, createdAt: Date())
        // Attach media/cover refs so the backend can purge R2 objects too.
        if let post {
            request.assetProvider   = post.assetProvider
            request.assetBucket     = post.assetBucket
            request.assetObjectKey  = post.assetObjectKey
            request.coverProvider   = post.coverProvider
            request.coverBucket     = post.coverBucket
            request.coverObjectKey  = post.coverObjectKey
        }
        if !pendingDeletionQueue.contains(request) {
            pendingDeletionQueue.append(request)
            savePendingDeletionQueue()
        }
        pendingDeletedPostIDs.insert(postID)
        // Remember which author this post was for — needed by
        // `retryAllStuckBackendDeletions` to re-fire the delete RPC after
        // the in-memory queue has drained but the post is still alive on
        // the backend.
        if kind == .post {
            userDeletedPostAuthorIDs[postID] = authorID
        }
        // Persist to the long-lived "ever-deleted" file so this ID survives
        // even after the retry queue drains.  Belt-and-suspenders against
        // backend deletions that return 200 but don't actually delete.
        saveUserDeletedPostIDs()
    }

    /// Iterates over every post the user has ever requested deleted and
    /// re-fires the backend delete RPC for it.  Use from the debug panel
    /// or any "force-redelete everything" affordance when followers report
    /// they're still seeing posts you've already deleted.  Idempotent on
    /// the backend (the deletePost handler writes a tombstone for already-
    /// missing rows and cleans related tables).
    func retryAllStuckBackendDeletions() {
        guard !pendingDeletedPostIDs.isEmpty else { return }
        var enqueued = 0
        for postID in pendingDeletedPostIDs {
            // We need the original author ID to re-fire the delete.  Prefer
            // the cached map (loaded from the new-schema persistent file).
            // Fall back to the current user — pre-upgrade users on the
            // legacy file format have no authorID stored, but most of their
            // stuck deletions will be their own posts, and the backend's
            // `canActAsAccount` check passes for that case.
            let authorID = userDeletedPostAuthorIDs[postID] ?? currentUser.id
            let request = PendingDeletionRequest(
                kind: .post,
                postID: postID,
                authorID: authorID,
                createdAt: Date()
            )
            if !pendingDeletionQueue.contains(request) {
                pendingDeletionQueue.append(request)
                enqueued += 1
            }
        }
        if enqueued > 0 {
            savePendingDeletionQueue()
        }
        Task { [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    private func flushPendingDeletions() async {
        guard backendClient.isEnabled, !pendingDeletionQueue.isEmpty else { return }
        var remaining: [PendingDeletionRequest] = []
        for request in pendingDeletionQueue {
            guard !Task.isCancelled else {
                remaining.append(request)
                continue
            }
            do {
                switch request.kind {
                case .post:
                    try await performAuthenticatedBackendWrite(
                        operationName: "post_delete_queue",
                        maxAttempts: 2,
                        timeoutPerAttempt: 20
                    ) { _ in
                        try await self.backendClient.deletePost(
                            postID: request.postID,
                            authorID: request.authorID,
                            assetProvider: request.assetProvider,
                            assetBucket: request.assetBucket,
                            assetObjectKey: request.assetObjectKey,
                            coverProvider: request.coverProvider,
                            coverBucket: request.coverBucket,
                            coverObjectKey: request.coverObjectKey
                        )
                    }
                case .rescroll:
                    try await performAuthenticatedBackendWrite(
                        operationName: "rescroll_delete_queue",
                        maxAttempts: 2,
                        timeoutPerAttempt: 20
                    ) { authTokenOverride in
                        try await self.backendClient.deleteRescroll(
                            userID: request.authorID,
                            rescrollPostID: request.postID,
                            authTokenOverride: authTokenOverride
                        )
                    }
                }
                // Backend accepted the delete.  Note: the iOS RPC returns
                // success on any 2xx — if the backend silently 200s without
                // actually deleting (e.g. an authorization issue that
                // returns ok=true without performing the row delete), we'd
                // log SUCCESS here even though the post still exists for
                // followers.  Cross-reference with the user's "I deleted
                // this but followers still see it" report to detect that
                // class of backend bug.
                recordDeletionAttempt(
                    postID: request.postID,
                    outcome: .success,
                    detail: "\(request.kind) — backend returned 2xx"
                )
            } catch {
                remaining.append(request)
                recordDeletionAttempt(
                    postID: request.postID,
                    outcome: .failure,
                    detail: "\(request.kind) — \((error as? LocalizedError)?.errorDescription ?? "\(error)")"
                )
            }
        }
        if remaining != pendingDeletionQueue {
            pendingDeletionQueue = remaining
            savePendingDeletionQueue()
        }
    }

    private func syncFollowDirectories() {
        ensureFounderAccountExists()
        ensureFounderManagedBusinessAccountsExist()
        enforceMandatoryFounderFollows()
        let followingIDs = (followRelations[currentUser.id] ?? []).union(mandatoryFollowIDs())
        following = followingIDs.compactMap { profileRegistry[$0] }.sorted(by: { $0.displayName < $1.displayName })
        let followerIDs = followRelations.compactMap { userID, following in
            following.contains(currentUser.id) ? userID : nil
        }
        followers = followerIDs.compactMap { profileRegistry[$0] }.sorted(by: { $0.displayName < $1.displayName })
    }

    private func startBackendPollingIfNeeded() {
        backendPollingTask?.cancel()
        guard backendClient.isEnabled, !isRealtimeSyncPaused else { return }
        backendSyncTick = 0
        triggerPendingFollowSyncFlush(force: true)
        backendPollingTask = Task {  [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.backendSyncTick += 1
                let readSyncRateLimited = self.feedRateLimitRemainingSeconds() > 0
                if !readSyncRateLimited {
                    await self.flushPendingFollowSyncQueue()
                    _ = await self.flushPendingBackendWriteQueue()
                }
                await self.syncFromBackendIfAvailable(lane: .feedFast)
                if !readSyncRateLimited,
                   self.backendSyncTick.isMultiple(of: BackendPollingCostSaverMode.socialSnapshotEveryTicks) {
                    await self.syncFromBackendIfAvailable(lane: .socialSnapshot)
                }
                if !readSyncRateLimited,
                   self.backendSyncTick.isMultiple(of: BackendPollingCostSaverMode.adSnapshotEveryTicks) {
                    await self.syncFromBackendIfAvailable(lane: .adSnapshot, skipIdentityReconcile: true)
                }
                // Circle inbox is polled on its own cadence, bypassing the feed rate limit so
                // that new messages update the badge and trigger notifications even when the
                // feed itself is rate-limited or the user is not on the circles tab.
                if self.backendSyncTick.isMultiple(of: BackendPollingCostSaverMode.circleInboxEveryTicks) {
                    await self.syncCircleInboxFromBackend(forceRefresh: false)
                }
                // Proactively rotate the access token before it expires so that
                // background polls and pending post retries never see a 401.
                if self.backendSyncTick.isMultiple(of: BackendPollingCostSaverMode.proactiveTokenRefreshEveryTicks) {
                    await self.proactiveTokenRefreshIfNeeded()
                }
                try? await Task.sleep(nanoseconds: BackendPollingCostSaverMode.pollIntervalNanos)
            }
        }
    }

    private func startRealtimeInvalidationIfNeeded() {
        guard backendClient.isEnabled, !isRealtimeSyncPaused else { return }
        backendClient.setupRealtimeInvalidation { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleRealtimeInvalidationEvent(event)
            }
        }
    }

    private func stopRealtimeInvalidation() {
        realtimeFeedSyncTask?.cancel()
        realtimeFeedSyncTask = nil
        realtimeSocialSyncTask?.cancel()
        realtimeSocialSyncTask = nil
        realtimeCommentRefreshTask?.cancel()
        realtimeCommentRefreshTask = nil
        realtimeCircleRefreshTask?.cancel()
        realtimeCircleRefreshTask = nil
        realtimeCommentRefreshPostIDs.removeAll()
        realtimeFeedSyncNeedsAnotherPass = false
        realtimeSocialSyncNeedsAnotherPass = false
        realtimeCircleRefreshNeedsAnotherPass = false
        backendClient.teardownRealtimeInvalidation()
    }

    private func handleRealtimeInvalidationEvent(_ event: BackendRealtimeEvent) {
        switch event {
        case .postsChanged(let postID, _):
            clearFeedCache()
            if let postID {
                cachedCommentsFetchedAt.removeValue(forKey: postID)
            }
            scheduleRealtimeFeedSync()
        case .commentsChanged(let postID):
            if let postID {
                cachedCommentsFetchedAt.removeValue(forKey: postID)
                scheduleRealtimeCommentRefresh(for: postID)
            }
            clearFeedCache()
            scheduleRealtimeFeedSync()
        case .usersChanged(let userID):
            clearSearchCache()
            clearSocialSnapshotCaches()
            if userID == currentUser.id {
                clearAdSnapshotCaches()
            }
            scheduleRealtimeSocialSync()
        case .followsChanged(let followerID, let followeeID):
            let relatesToCurrentUser = followerID == currentUser.id || followeeID == currentUser.id
            guard relatesToCurrentUser else { return }
            invalidateCachesForFollowGraphMutation()
            if followerID == currentUser.id {
                triggerPendingFollowSyncFlush(force: true)
            }
            scheduleRealtimeSocialSync()
        case .notificationsChanged(let userID, let objectID):
            guard userID == nil || userID == currentUser.id else { return }
            clearSocialSnapshotCaches()
            if let objectID {
                cachedCommentsFetchedAt.removeValue(forKey: objectID)
            }
            syncNotificationInbox(forceRefresh: true)
        case .rescrollsChanged(let originalPostID, _):
            clearFeedCache()
            if let originalPostID {
                cachedCommentsFetchedAt.removeValue(forKey: originalPostID)
            }
            scheduleRealtimeFeedSync()
        case .commentLikesChanged(let commentID, _):
            clearFeedCache()
            if let commentID, let postID = canonicalPostID(containingCommentID: commentID) {
                cachedCommentsFetchedAt.removeValue(forKey: postID)
                scheduleRealtimeCommentRefresh(for: postID)
            }
            scheduleRealtimeFeedSync()
        case .circlesChanged(let circleID, let createdByID):
            // Circle metadata edits (name/avatar/member management) should invalidate
            // local circle cache quickly so invites and membership changes feel instant.
            if createdByID == currentUser.id || (circleID != nil && circles.contains(where: { $0.id == circleID })) {
                cachedCircles = nil
                scheduleRealtimeCircleRefresh()
            }
        case .circleMembersChanged(let circleID, let userID):
            let affectsCurrentUser = userID == currentUser.id
                || (circleID != nil && circles.contains(where: { $0.id == circleID }))
            guard affectsCurrentUser else { return }
            cachedCircles = nil
            scheduleRealtimeCircleRefresh()
case .circleMessagesChanged(let circleID, let messageID, let userID):
    let hasPendingForMessage = messageID.map { messageID in
        pendingBackendWriteQueue.contains { operation in
            operation.kind == .circleMessage && operation.messageID == messageID
        }
    } ?? false
    let hasPendingForCircle = circleID.map { circleID in
        pendingBackendWriteQueue.contains { operation in
            operation.kind == .circleMessage
                && operation.circleID == circleID
                && operation.userID == currentUser.id
        }
    } ?? false
    let shouldSkipOwnEcho = userID == currentUser.id && (hasPendingForMessage || hasPendingForCircle)
    if shouldSkipOwnEcho {
        return
    }
    cachedCircles = nil
    scheduleRealtimeCircleRefresh()
        }
    }

    private func canonicalPostID(containingCommentID commentID: UUID) -> UUID? {
        for post in posts {
            let canonicalID = post.rescrollOrigin?.postID ?? post.id
            if postContainsCommentID(post.comments, targetID: commentID) {
                return canonicalID
            }
        }
        for post in pendingRemotePosts {
            let canonicalID = post.rescrollOrigin?.postID ?? post.id
            if postContainsCommentID(post.comments, targetID: commentID) {
                return canonicalID
            }
        }
        return nil
    }

    private func postContainsCommentID(_ comments: [PostComment], targetID: UUID) -> Bool {
        for comment in comments {
            if comment.id == targetID { return true }
            if postContainsCommentID(comment.replies, targetID: targetID) { return true }
        }
        return false
    }

    private func scheduleRealtimeFeedSync() {
        guard realtimeFeedSyncTask == nil else {
            realtimeFeedSyncNeedsAnotherPass = true
            return
        }
        realtimeFeedSyncNeedsAnotherPass = false
        realtimeFeedSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.realtimeFeedSyncTask = nil }
            repeat {
                self.realtimeFeedSyncNeedsAnotherPass = false
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard !Task.isCancelled else { return }
                await self.syncFromBackendIfAvailable(lane: .feedFast, skipIdentityReconcile: true)
            } while self.realtimeFeedSyncNeedsAnotherPass && !Task.isCancelled
        }
    }

    private func scheduleRealtimeSocialSync() {
        guard realtimeSocialSyncTask == nil else {
            realtimeSocialSyncNeedsAnotherPass = true
            return
        }
        realtimeSocialSyncNeedsAnotherPass = false
        realtimeSocialSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.realtimeSocialSyncTask = nil }
            repeat {
                self.realtimeSocialSyncNeedsAnotherPass = false
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                await self.syncFromBackendIfAvailable(lane: .socialSnapshot)
            } while self.realtimeSocialSyncNeedsAnotherPass && !Task.isCancelled
        }
    }

    private func scheduleRealtimeCommentRefresh(for canonicalPostID: UUID) {
        realtimeCommentRefreshPostIDs.insert(canonicalPostID)
        guard realtimeCommentRefreshTask == nil else { return }
        realtimeCommentRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.realtimeCommentRefreshTask = nil }
            while !Task.isCancelled {
                let pendingPostIDs = Array(self.realtimeCommentRefreshPostIDs)
                self.realtimeCommentRefreshPostIDs.removeAll()
                guard !pendingPostIDs.isEmpty else { break }
                for postID in pendingPostIDs {
                    await self.refreshCommentsFromBackendForCanonicalPostID(postID, forceRefresh: true)
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        }
    }

    private func scheduleRealtimeCircleRefresh() {
        guard realtimeCircleRefreshTask == nil else {
            realtimeCircleRefreshNeedsAnotherPass = true
            return
        }
        realtimeCircleRefreshNeedsAnotherPass = false
        realtimeCircleRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.realtimeCircleRefreshTask = nil }
            repeat {
                self.realtimeCircleRefreshNeedsAnotherPass = false
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                await self.syncCircleInboxFromBackend(forceRefresh: true)
            } while self.realtimeCircleRefreshNeedsAnotherPass && !Task.isCancelled
        }
    }

    func setRealtimeSyncPaused(_ paused: Bool) {
        guard isRealtimeSyncPaused != paused else { return }
        isRealtimeSyncPaused = paused
        if paused {
            backendPollingTask?.cancel()
            backendPollingTask = nil
            queuedBackendSyncRequest = nil
            stopRealtimeInvalidation()
        } else {
            startBackendPollingIfNeeded()
            startRealtimeInvalidationIfNeeded()
            triggerPendingFollowSyncFlush(force: true)
        }
    }

    private func completeSetup() async {
        let stateURL = persistenceURL
        let stateData = await Task.detached(priority: .background) {
            Persistence.loadData(from: stateURL)
        }.value
        let cacheURL = globalFeedCacheURL
        let cacheData = await Task.detached(priority: .background) {
            Persistence.loadData(from: cacheURL)
        }.value
        let cachedPosts: [FeedPost]
        let pendingDeletionURL = pendingDeletionsURL
        let pendingDeletionData = await Task.detached(priority: .background) {
            Persistence.loadData(from: pendingDeletionURL)
        }.value
        let pendingMediaURL = pendingMediaPostsURL(for: currentUser.id)
        let pendingMediaData = await Task.detached(priority: .background) {
            Persistence.loadData(from: pendingMediaURL)
        }.value
        let pendingFollowsFileURL = pendingFollowsURL
        let pendingFollowsData = await Task.detached(priority: .background) {
            Persistence.loadData(from: pendingFollowsFileURL)
        }.value
        let pendingBackendWritesFileURL = pendingBackendWritesURL
        let pendingBackendWritesData = await Task.detached(priority: .background) {
            Persistence.loadData(from: pendingBackendWritesFileURL)
        }.value
        if let data = cacheData,
           let cache = try? JSONDecoder().decode(GlobalFeedCache.self, from: data) {
            cachedPosts = cache.posts
        } else {
            cachedPosts = []
        }
        let pendingDeletions: [PendingDeletionRequest] = {
            if let data = pendingDeletionData,
               let queue = try? JSONDecoder().decode(PendingDeletionQueue.self, from: data) {
                return queue.deletions
            }
            if let data = pendingDeletionData,
               let deletions = try? JSONDecoder().decode([PendingDeletionRequest].self, from: data) {
                return deletions
            }
            return []
        }()
        let restoredPendingFollows: [PendingFollowSyncOperation] = {
            if let data = pendingFollowsData,
               let queue = try? JSONDecoder().decode(PendingFollowSyncQueue.self, from: data) {
                return queue.operations
            }
            if let data = pendingFollowsData,
               let operations = try? JSONDecoder().decode([PendingFollowSyncOperation].self, from: data) {
                return operations
            }
            return []
        }()
        let restoredPendingBackendWrites: [PendingBackendWriteOperation] = {
            if let data = pendingBackendWritesData,
               let queue = try? JSONDecoder().decode(PendingBackendWriteQueue.self, from: data) {
                return queue.operations
            }
            if let data = pendingBackendWritesData,
               let operations = try? JSONDecoder().decode([PendingBackendWriteOperation].self, from: data) {
                return operations
            }
            return []
        }()
        let restoredPendingMediaPosts: [FeedPost] = {
            if let data = pendingMediaData,
               let cache = try? JSONDecoder().decode(PendingMediaPostCache.self, from: data) {
                return cache.posts
            }
            if let data = pendingMediaData,
               let legacy = try? JSONDecoder().decode([FeedPost].self, from: data) {
                return legacy
            }
            return []
        }()
        let persistedState: ScrollsState? = {
            guard let data = stateData else { return nil }
            return try? JSONDecoder().decode(ScrollsState.self, from: data)
        }()
        let sessionUsername = normalizeUsername(currentUser.username)

        await MainActor.run {
            if !pendingDeletions.isEmpty {
                pendingDeletionQueue = pendingDeletions
                pendingDeletedPostIDs.formUnion(pendingDeletions.map(\.postID))
            }
            // Restore the persistent "ever-deleted" set.  This survives even
            // after the retry queue drains, so a post the user deleted weeks
            // ago — but which the backend silently failed to delete and is
            // now resurfaced in search/feed — still gets filtered locally
            // AND queued for re-deletion next time it arrives in a remote
            // response.
            pendingDeletedPostIDs.formUnion(loadUserDeletedPostIDs())
            listenedCircleVoiceMessageIDs.formUnion(loadListenedCircleVoiceMessageIDs())
            if !restoredPendingFollows.isEmpty {
                pendingFollowSyncQueue = restoredPendingFollows
            }
            if !restoredPendingBackendWrites.isEmpty {
                pendingBackendWriteQueue = restoredPendingBackendWrites
            }
            var restoredUnread: Set<UUID>? = nil
            let serverAuthoritative = self.useServerAuthoritativeState
            if let persisted = persistedState {
                let persistedCurrent = roleAdjustedProfile(persisted.currentUser)
                let isSameSessionUser = normalizeUsername(persistedCurrent.username) == sessionUsername
                if isSameSessionUser {
                    currentUser = persistedCurrent
                    registerProfile(currentUser)
                    let scopedPersistedNotifications = scopedNotifications(persisted.notifications, recipientID: currentUser.id)
                    notifications = scopedPersistedNotifications.isEmpty ? sampleNotificationsForCurrentUser() : scopedPersistedNotifications
                    circles = filterListenedCircleVoiceMessages(in: persisted.circles.isEmpty ? Self.sampleCircles : persisted.circles)
                    postDrafts = persisted.postDrafts
                    adSubmissionPostIDs = Set(persisted.adSubmissionPostIDs)
                    if serverAuthoritative {
                        // Backend is the source of truth for feed/follow graph.
                        posts = []
                        followRelations = [currentUser.id: []]
                        pinnedPostIDs = remappedPinnedPostIDs(from: persisted, targetUserID: currentUser.id)
                    } else {
                        posts = persisted.posts.isEmpty ? Self.initialPosts : stripCommentLikesFromPosts(persisted.posts)
                        registerProfiles(from: posts.map { $0.user })
                        removePostsWithMissingMedia()
                        registerProfiles(from: persisted.following + persisted.followers)
                        let decodedRelations = persisted.followRelations.mapValues { Set($0) }
                        followRelations = decodedRelations.isEmpty ? Self.defaultFollowRelations(currentUserID: currentUser.id) : decodedRelations
                        pinnedPostIDs = remappedPinnedPostIDs(from: persisted, targetUserID: currentUser.id)
                    }
                    restoredUnread = restoreUnreadCircleMessageIDs(from: circles, persistedIDs: persisted.unreadCircleMessageIDs)
                    // Restore the delta-sync cursor so the next cold-start skips the
                    // expensive full-directory seed and uses incremental fetch instead.
                    for (accountID, version) in persisted.profileDeltaVersionByUserID {
                        if profileDeltaVersionByUserID[accountID] == nil {
                            profileDeltaVersionByUserID[accountID] = version
                        }
                    }
                } else {
                    currentUser = roleAdjustedProfile(currentUser)
                    registerProfile(currentUser)
                    registerProfile(persistedCurrent)
                    if !serverAuthoritative, !persisted.posts.isEmpty {
                        posts = deduplicatedPosts(posts + stripCommentLikesFromPosts(persisted.posts))
                        registerProfiles(from: posts.map { $0.user })
                        removePostsWithMissingMedia(checkAssetLibrary: false)
                    }
                    if !serverAuthoritative, !persisted.circles.isEmpty {
                        circles = filterListenedCircleVoiceMessages(in: circles + persisted.circles)
                    }
                    if !serverAuthoritative, !persisted.followRelations.isEmpty {
                        let decodedRelations = persisted.followRelations.mapValues { Set($0) }
                        followRelations = decodedRelations
                    }
                    if !serverAuthoritative {
                        registerProfiles(from: persisted.following + persisted.followers)
                    }
                    if !serverAuthoritative, !persisted.pinnedPostIDs.isEmpty {
                        pinnedPostIDs = remappedPinnedPostIDs(from: persisted, targetUserID: currentUser.id)
                    }
                }
            }
            // Warm-start the profile registry from the persisted cache so returning
            // users don't see loading states on profiles they've already viewed.
            // registerProfile is idempotent — any overlap with following/followers
            // or post authors is safely overwritten by the more specific restore above.
            if let persisted = persistedState, !persisted.profileCache.isEmpty {
                let sanitizedProfileCache = sanitizedPersistedProfileCache(persisted.profileCache)
                if !sanitizedProfileCache.isEmpty {
                    registerProfiles(from: sanitizedProfileCache)
                }
            }
            if !restoredPendingMediaPosts.isEmpty {
                let currentUsername = normalizeUsername(currentUser.username)
                let validPendingPosts = restoredPendingMediaPosts.compactMap { pending -> FeedPost? in
                    guard shouldPersistPostInPendingMediaCache(pending) else { return nil }
                    let pendingUsername = normalizeUsername(pending.user.username)
                    let sameIdentity = pending.user.id == currentUser.id
                        || (!pendingUsername.isEmpty && pendingUsername == currentUsername)
                    guard sameIdentity else { return nil }
                    guard pending.user.id != currentUser.id else { return stripCommentLikesFromPost(pending) }
                    return FeedPost(
                        id: pending.id,
                        user: currentUser,
                        caption: pending.caption,
                        websiteURL: pending.websiteURL,
                        locationCity: pending.locationCity,
                        timestamp: pending.timestamp,
                        mediaPreview: pending.mediaPreview,
                        coverImageRef: pending.coverImageRef,
                        coverProvider: pending.coverProvider,
                        coverBucket: pending.coverBucket,
                        coverObjectKey: pending.coverObjectKey,
                        comments: stripCommentLikesFromComments(pending.comments),
                        rescrollOrigin: pending.rescrollOrigin
                    )
                }
                if !validPendingPosts.isEmpty {
                    posts = deduplicatedPosts(posts + validPendingPosts)
                    registerProfiles(from: validPendingPosts.map { $0.user })
                }
            }
            restoreBackendAuthTokenForCurrentUserIfNeeded()
            migrateDraftOwnershipIfNeeded()
            registerProfileSnapshotsForLocalSessions()
            publishDueScheduledDrafts()
            normalizeIdentityState()
            ensureFounderAccountExists()
            ensureFounderManagedBusinessAccountsExist()
            mergeFounderClusterPostsFromLocalCache()
            purgeLegacyLoserProfileDataIfNeeded()
            enforceMandatoryFounderFollows()
            removeSeedDataIfNeeded()
            hydrateFeedFromGlobalCacheIfNeeded(cachedPosts)
            purgePendingDeletedPostsFromLocalState()
            normalizePinnedPosts()
            pruneNotificationsForCost()
            if let unread = restoredUnread {
                unreadCircleMessageIDs = unread
            } else {
                unreadCircleMessageIDs = defaultUnreadCircleMessageIDs(from: circles)
            }
            invalidateCachesForAccountTransition()
            syncFollowDirectories()
            refreshCommentsAfterAccountSwitch()
            saveState(immediate: true)
            Task {  [weak self] in
                guard let self else { return }
                let sessionUsername = self.normalizeUsername(self.currentUser.username)
                // Cosmetic first-paint priority: fetch feed before slower startup sync work.
                await self.syncFeedFastIfAvailable(sessionUsername: sessionUsername)
                // Heal the session BEFORE resuming pending uploads so that retry
                // workers start with a valid token and don't immediately 401.
                await self.performAuthSessionSelfHealIfNeeded(trigger: "startup")
                // Always resume uploads after heal (the heal itself resumes them on
                // recovery; this call covers the case where the token was already
                // valid and no healing was needed).
                await self.syncCurrentUserPinnedPostToBackendIfNeeded()
                await MainActor.run { self.resumePendingMediaPostUploadsIfNeeded() }
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    await self?.syncFromBackendIfAvailable(lane: .socialSnapshot)
                }
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await self?.syncFromBackendIfAvailable(lane: .adSnapshot, skipIdentityReconcile: true)
                }
            }
            startBackendPollingIfNeeded()
            startRealtimeInvalidationIfNeeded()
            triggerPendingFollowSyncFlush(force: true)
            triggerPendingBackendWriteFlush(force: true)
            scheduleBatchedCircleBackendSync()
            refreshPostSyncIndicator(reason: "complete_setup", force: true)
        }
    }

    deinit {
        accountSwitchWatchdogTask?.cancel()
        postSyncAutoRecoveryTask?.cancel()
        scheduledPublishingTask?.cancel()
        pendingCircleSaveTask?.cancel()
        pendingCircleBackendSyncTask?.cancel()
        pendingStateSaveTask?.cancel()
        followSyncFlushTask?.cancel()
        backendWriteFlushTask?.cancel()
        backendPollingTask?.cancel()
        liveHeartbeatTask?.cancel()
        realtimeFeedSyncTask?.cancel()
        realtimeSocialSyncTask?.cancel()
        realtimeCommentRefreshTask?.cancel()
        realtimeCircleRefreshTask?.cancel()
        #if canImport(UIKit)
        let foreground = foregroundObserver
        let background = backgroundObserver
        let pushToken = pushTokenObserver
        let pushFailure = pushTokenFailureObserver
        Task { @MainActor in
            if let foreground {
                NotificationCenter.default.removeObserver(foreground)
            }
            if let background {
                NotificationCenter.default.removeObserver(background)
            }
            if let pushToken {
                NotificationCenter.default.removeObserver(pushToken)
            }
            if let pushFailure {
                NotificationCenter.default.removeObserver(pushFailure)
            }
        }
        #endif
    }

    private var searchableProfiles: [UserProfile] {
        Array(profileRegistry.values)
            .filter { !blockedUserIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func registerProfiles(from profiles: [UserProfile]) {
        for profile in profiles {
            registerProfile(profile)
        }
    }

    private func sanitizedPersistedProfileCache(_ profiles: [UserProfile]) -> [UserProfile] {
        guard !profiles.isEmpty else { return [] }
        var byUsername: [String: UserProfile] = [:]
        for profile in profiles {
            let normalized = normalizeUsername(profile.username)
            guard !normalized.isEmpty else { continue }
            if let existing = byUsername[normalized] {
                byUsername[normalized] = preferredProfile(existing, profile)
            } else {
                byUsername[normalized] = profile
            }
        }
        guard !byUsername.isEmpty else { return [] }
        let ordered = byUsername.values.sorted { lhs, rhs in
            (profileLastRefreshedAtByID[lhs.id] ?? .distantPast) >
            (profileLastRefreshedAtByID[rhs.id] ?? .distantPast)
        }
        return Array(ordered.prefix(Self.profileCacheLimit))
    }

    @discardableResult
    private func registerProfiles(from backendUsers: [BackendUser], applyRoleAdjustment: Bool = false) -> Bool {
        var changed = false
        for user in backendUsers {
            let mapped = applyRoleAdjustment ? roleAdjustedProfile(user.asUserProfile) : user.asUserProfile
            if registerProfile(mapped, writeVersion: user.writeVersion) {
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    private func registerProfile(_ profile: UserProfile, writeVersion: String? = nil) -> Bool {
        let incomingProfile = roleAdjustedProfile(profile)
        let now = Date()
        let existing = profileRegistry[incomingProfile.id]
        let existingWriteVersion = profileWriteVersionsByID[incomingProfile.id]
        let parsedIncomingWriteVersion = parsedWriteVersionDate(writeVersion)
        if let parsedWriteVersion = parsedWriteVersionDate(writeVersion) {
            if let existing = profileWriteVersionsByID[incomingProfile.id] {
                if parsedWriteVersion > existing {
                    profileWriteVersionsByID[incomingProfile.id] = parsedWriteVersion
                }
            } else {
                profileWriteVersionsByID[incomingProfile.id] = parsedWriteVersion
            }
            profileLastRefreshedAtByID[incomingProfile.id] = now
        } else if profileLastRefreshedAtByID[incomingProfile.id] == nil {
            profileLastRefreshedAtByID[incomingProfile.id] = now
        }
        let shouldTreatIncomingAsAuthoritativeForAvatarMedia: Bool = {
            guard let incoming = parsedIncomingWriteVersion else { return false }
            guard let existingWriteVersion else { return true }
            return incoming >= existingWriteVersion
        }()
        let resolved: UserProfile
        if let existing, (isFounderClusterProfile(existing) || isFounderClusterProfile(incomingProfile)) {
            resolved = mergedFounderProfile(
                existing: existing,
                incoming: incomingProfile,
                preferIncomingMediaFields: shouldTreatIncomingAsAuthoritativeForAvatarMedia
            )
        } else if let existing {
            resolved = mergedProfile(
                base: incomingProfile,
                other: existing,
                preferBaseValues: shouldTreatIncomingAsAuthoritativeForAvatarMedia
            )
        } else {
            resolved = incomingProfile
        }
        if existing != resolved {
            // Registry updates are not @Published; trigger view refresh for directory/search views.
            objectWillChange.send()
        }
        profileRegistry[resolved.id] = resolved
        if existing == nil {
            invalidateSearchCachesBecauseDirectoryChanged()
        }
        // Keep the pinned-post dictionary in sync with whatever the
        // backend says about every profile we register (current user,
        // visited profiles, profiles attached to posts in the feed,
        // etc.).  Without this, viewing someone else's profile shows
        // their old pinned post (or none) because we only had the
        // potentially-stale embedded `post.user.pinnedPostID`.  Pin
        // dictionary stays authoritative across cold launch, account
        // switch, and cross-device updates.
        if let remotePinned = resolved.pinnedPostID {
            if pinnedPostIDs[resolved.id] != remotePinned {
                pinnedPostIDs[resolved.id] = remotePinned
            }
        } else if pinnedPostIDs[resolved.id] != nil {
            pinnedPostIDs.removeValue(forKey: resolved.id)
        }
        guard existing != resolved else { return false }
        propagateProfileUpdate(resolved)
        return true
    }

    private func parsedWriteVersionDate(_ writeVersion: String?) -> Date? {
        guard let trimmed = writeVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        if let parsed = Self.writeVersionFormatterWithFractionalSeconds.date(from: trimmed) {
            return parsed
        }
        if let parsed = Self.writeVersionFormatter.date(from: trimmed) {
            return parsed
        }
        if let epochSeconds = TimeInterval(trimmed) {
            return Date(timeIntervalSince1970: epochSeconds)
        }
        return nil
    }

    private func normalizedWriteVersionString(_ writeVersion: String?) -> String? {
        guard let parsed = parsedWriteVersionDate(writeVersion) else { return nil }
        return Self.writeVersionFormatterWithFractionalSeconds.string(from: parsed)
    }

    private func mergedFounderProfile(
        existing: UserProfile,
        incoming: UserProfile,
        preferIncomingMediaFields: Bool
    ) -> UserProfile {
        func preferredOptionalText(_ existingValue: String?, _ incomingValue: String?) -> String? {
            let a = existingValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let b = incomingValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !b.isEmpty { return b }
            return a.isEmpty ? nil : a
        }

        func preferredText(_ existingValue: String, _ incomingValue: String) -> String {
            let a = existingValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = incomingValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !b.isEmpty { return b }
            return a
        }

        let mergedDisplayName = preferredFounderDisplayName(existing: existing, incoming: incoming)
        let mergedBio = preferredText(existing.bio, incoming.bio)
        let mergedKeywords = Array(Set(existing.keywords + incoming.keywords)).sorted()
        let existingAvatarKey = avatarSourceKey(for: existing)
        let incomingAvatarKey = avatarSourceKey(for: incoming)
        let avatarSourceChanged = !incomingAvatarKey.isEmpty && incomingAvatarKey != existingAvatarKey
        let normalizedIncomingAvatarRef = normalizedOptionalText(incoming.avatarRef)
        let normalizedIncomingAvatarProvider = normalizedOptionalText(incoming.avatarProvider)
        let normalizedIncomingAvatarBucket = normalizedOptionalText(incoming.avatarBucket)
        let normalizedIncomingAvatarObjectKey = normalizedOptionalText(incoming.avatarObjectKey)
        let normalizedIncomingAvatarVideoRef = normalizedOptionalText(incoming.avatarVideoRef)
        let avatarData: Data? = {
            if preferIncomingMediaFields {
                if avatarSourceChanged { return incoming.avatarImageData }
                if let incomingAvatarImageData = incoming.avatarImageData { return incomingAvatarImageData }
                if !incomingAvatarKey.isEmpty { return existing.avatarImageData }
                return nil
            }
            return avatarSourceChanged
                ? incoming.avatarImageData
                : (incoming.avatarImageData ?? existing.avatarImageData)
        }()

        return UserProfile(
            id: existing.id,
            username: existing.username,
            displayName: mergedDisplayName,
            bio: mergedBio,
            keywords: mergedKeywords,
            gradientSpec: existing.gradientSpec,
            avatarImageData: avatarData,
            avatarRef: preferIncomingMediaFields
                ? normalizedIncomingAvatarRef
                : (avatarSourceChanged ? incoming.avatarRef : preferredOptionalText(existing.avatarRef, incoming.avatarRef)),
            avatarProvider: preferIncomingMediaFields
                ? normalizedIncomingAvatarProvider
                : (avatarSourceChanged ? incoming.avatarProvider : preferredOptionalText(existing.avatarProvider, incoming.avatarProvider)),
            avatarBucket: preferIncomingMediaFields
                ? normalizedIncomingAvatarBucket
                : (avatarSourceChanged ? incoming.avatarBucket : preferredOptionalText(existing.avatarBucket, incoming.avatarBucket)),
            avatarObjectKey: preferIncomingMediaFields
                ? normalizedIncomingAvatarObjectKey
                : (avatarSourceChanged ? incoming.avatarObjectKey : preferredOptionalText(existing.avatarObjectKey, incoming.avatarObjectKey)),
            isVerified: existing.isVerified || incoming.isVerified,
            isFounder: existing.isFounder || incoming.isFounder,
            isPrivateAccount: incoming.isPrivateAccount,
            accountType: (existing.accountType == .business || incoming.accountType == .business) ? .business : existing.accountType,
            subscriptionPlan: preferredOptionalText(existing.subscriptionPlan, incoming.subscriptionPlan),
            pinnedPostID: incoming.pinnedPostID ?? existing.pinnedPostID,
            signatureRef: preferredOptionalText(existing.signatureRef, incoming.signatureRef),
            avatarVideoRef: preferIncomingMediaFields
                ? normalizedIncomingAvatarVideoRef
                : preferredOptionalText(existing.avatarVideoRef, incoming.avatarVideoRef),
            websiteURL: preferredOptionalText(existing.websiteURL, incoming.websiteURL),
            venmoURL: preferredOptionalText(existing.venmoURL, incoming.venmoURL),
            cashAppURL: preferredOptionalText(existing.cashAppURL, incoming.cashAppURL),
            spotifyURL: preferredOptionalText(existing.spotifyURL, incoming.spotifyURL),
            appleMusicURL: preferredOptionalText(existing.appleMusicURL, incoming.appleMusicURL),
            businessLocation: preferredOptionalText(existing.businessLocation, incoming.businessLocation),
            businessPhone: preferredOptionalText(existing.businessPhone, incoming.businessPhone),
            homeCity: preferredOptionalText(existing.homeCity, incoming.homeCity),
            dateOfBirth: existing.dateOfBirth ?? incoming.dateOfBirth,
            ageAssuranceCompletedAt: existing.ageAssuranceCompletedAt ?? incoming.ageAssuranceCompletedAt,
            parentalControls: existing.parentalControls
        )
    }

    private func preferredFounderDisplayName(existing: UserProfile, incoming: UserProfile) -> String {
        if let managed = founderManagedAccount(matching: incoming) ?? founderManagedAccount(matching: existing) {
            return managed.displayName
        }

        let existingDisplayName = existing.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingDisplayName = incoming.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingUsername = normalizeUsername(existing.username)
        let incomingUsername = normalizeUsername(incoming.username)
        let canonicalFounderUsername = normalizeUsername(Self.founderCanonicalAccount.username)

        func isPlaceholderDisplayName(_ value: String, username: String) -> Bool {
            let normalized = normalizeUsername(value)
            return normalized.isEmpty || normalized == username || normalized == canonicalFounderUsername
        }

        if isFounderClusterProfile(existing) || isFounderClusterProfile(incoming) {
            if !incomingDisplayName.isEmpty,
               !isPlaceholderDisplayName(incomingDisplayName, username: incomingUsername) {
                return incomingDisplayName
            }
            if !existingDisplayName.isEmpty,
               !isPlaceholderDisplayName(existingDisplayName, username: existingUsername) {
                return existingDisplayName
            }
            return Self.founderCanonicalAccount.displayName
        }

        return incomingDisplayName.isEmpty ? existingDisplayName : incomingDisplayName
    }

    private func propagateProfileUpdate(_ updatedProfile: UserProfile) {
        following = following.map { $0.id == updatedProfile.id ? updatedProfile : $0 }
        followers = followers.map { $0.id == updatedProfile.id ? updatedProfile : $0 }
        pendingFollowRequests = pendingFollowRequests.map { $0.id == updatedProfile.id ? updatedProfile : $0 }

        posts = posts.map { post in
            let mappedUser = post.user.id == updatedProfile.id ? updatedProfile : post.user
            let mappedOrigin: RescrollOrigin?
            if let origin = post.rescrollOrigin, origin.user.id == updatedProfile.id {
                mappedOrigin = RescrollOrigin(
                    postID: origin.postID,
                    user: updatedProfile,
                    caption: origin.caption,
                    websiteURL: origin.websiteURL,
                    timestamp: origin.timestamp
                )
            } else {
                mappedOrigin = post.rescrollOrigin
            }
            let mappedComments = remapCommentUsers(post.comments, with: updatedProfile)

            if mappedUser == post.user && mappedOrigin == post.rescrollOrigin && mappedComments == post.comments {
                return post
            }
            return FeedPost(
                id: post.id,
                user: mappedUser,
                caption: post.caption,
                websiteURL: post.websiteURL,
                locationCity: post.locationCity,
                timestamp: post.timestamp,
                mediaPreview: post.mediaPreview,
                comments: mappedComments,
                rescrollOrigin: mappedOrigin
            )
        }

        pendingRemotePosts = pendingRemotePosts.map { post in
            let mappedUser = post.user.id == updatedProfile.id ? updatedProfile : post.user
            let mappedOrigin: RescrollOrigin?
            if let origin = post.rescrollOrigin, origin.user.id == updatedProfile.id {
                mappedOrigin = RescrollOrigin(
                    postID: origin.postID,
                    user: updatedProfile,
                    caption: origin.caption,
                    websiteURL: origin.websiteURL,
                    timestamp: origin.timestamp
                )
            } else {
                mappedOrigin = post.rescrollOrigin
            }

            if mappedUser == post.user && mappedOrigin == post.rescrollOrigin {
                return post
            }
            return FeedPost(
                id: post.id,
                user: mappedUser,
                caption: post.caption,
                websiteURL: post.websiteURL,
                locationCity: post.locationCity,
                timestamp: post.timestamp,
                mediaPreview: post.mediaPreview,
                comments: post.comments,
                rescrollOrigin: mappedOrigin
            )
        }
    }

    private func remapCommentUsers(_ comments: [PostComment], with updatedProfile: UserProfile) -> [PostComment] {
        comments.map { comment in
            let mappedReplies = remapCommentUsers(comment.replies, with: updatedProfile)
            let mappedUser = comment.user.id == updatedProfile.id ? updatedProfile : comment.user
            if mappedUser == comment.user && mappedReplies == comment.replies {
                return comment
            }
            return PostComment(
                id: comment.id,
                user: mappedUser,
                text: comment.text,
                timestamp: comment.timestamp,
                replies: mappedReplies,
                likedBy: comment.likedBy
            )
        }
    }

    private func normalizeUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func founderClusterUsernames() -> Set<String> {
        var usernames = Set(Self.founderCanonicalAccounts.map { normalizeUsername($0.username) })
        usernames.formUnion(Self.founderManagedBusinessAccounts.map { normalizeUsername($0.username) })
        return usernames
    }

    private func isCanonicalFounderProfile(_ profile: UserProfile) -> Bool {
        normalizeUsername(profile.username) == normalizeUsername(Self.founderCanonicalAccount.username)
    }

    /// Public view for the icon picker (and similar UI gates) to confirm
    /// whether the currently-active profile is the canonical founder account.
    /// Founder-cluster members other than primadonvino are routed away from
    /// `setAlternateIconName` to avoid the sandbox-write-pressure contention
    /// that returns POSIX 35 (EAGAIN) when multiple managed accounts are
    /// active simultaneously.
    var isCurrentUserCanonicalFounder: Bool {
        isCanonicalFounderProfile(currentUser)
    }

    /// Public view for the icon picker — true when the active profile is in
    /// the founder cluster but NOT the canonical founder.  These accounts
    /// share the same physical app bundle as primadonvino, so changing the
    /// icon from any of them affects the same home-screen icon; we simply
    /// require the user to be on primadonvino to perform the change so the
    /// cluster's sync activity doesn't fight backboardd for the bundle.
    var isCurrentUserNonCanonicalFounderClusterMember: Bool {
        guard isFounderClusterProfile(currentUser) else { return false }
        return !isCanonicalFounderProfile(currentUser)
    }

    /// Canonical founder username, exposed for UI strings (e.g. "Switch to
    /// @primadonvino to change app icons").
    var canonicalFounderUsername: String {
        Self.founderCanonicalAccount.username
    }

    private func isFounderClusterProfile(_ profile: UserProfile) -> Bool {
        if profile.isFounder { return true }
        return founderClusterUsernames().contains(normalizeUsername(profile.username))
    }

    private func founderManagedAccount(matching profile: UserProfile) -> (id: UUID, username: String, displayName: String)? {
        Self.founderManagedBusinessAccounts.first { account in
            account.id == profile.id || normalizeUsername(account.username) == normalizeUsername(profile.username)
        }
    }

    private var founderProfile: UserProfile? {
        let founderUsername = normalizeUsername(Self.founderCanonicalAccount.username)
        return profileRegistry.values.first(where: { normalizeUsername($0.username) == founderUsername })
    }

    private func canonicalProfile(matching profile: UserProfile) -> UserProfile? {
        let key = normalizeUsername(profile.username)
        if let byUsername = self.profile(forUsername: key) {
            return byUsername
        }
        return profileRegistry[profile.id]
    }

    private func canonicalDirectoryProfile(for id: UUID) -> UserProfile? {
        guard let profile = profileRegistry[id] else { return nil }
        return self.profile(forUsername: profile.username) ?? profile
    }

    func isFounderAccount(_ profile: UserProfile) -> Bool {
        profile.isFounder
    }

    func canCurrentUserPublishFounderAds() -> Bool {
        let normalizedCurrent = normalizeUsername(currentUser.username)
        let founderUsername = normalizeUsername(Self.founderCanonicalAccount.username)
        return currentUser.isFounder && normalizedCurrent == founderUsername
    }

    func isMandatoryFollowAccount(_ profile: UserProfile) -> Bool {
        isFounderClusterProfile(profile)
    }

    func isProtectedFounderManagedAccount(_ profile: UserProfile) -> Bool {
        let normalized = normalizeUsername(profile.username)
        return Self.founderManagedBusinessAccounts.contains(where: { normalizeUsername($0.username) == normalized })
    }

    /// Returns `true` when the given username belongs to the founder cluster —
    /// either the canonical founder account or one of the founder-managed
    /// business accounts.  Used by account-switch logic to detect when the
    /// source and target share the same Supabase auth session (and therefore
    /// the keychain refresh token), so the wipe-and-seed dance can be skipped.
    func isFounderClusterUsername(_ username: String) -> Bool {
        let normalized = normalizeUsername(username)
        if normalized.isEmpty { return false }
        if Self.founderCanonicalAccounts.contains(where: { normalizeUsername($0.username) == normalized }) {
            return true
        }
        return Self.founderManagedBusinessAccounts.contains(where: { normalizeUsername($0.username) == normalized })
    }

    func isProtectedFounderBlockAccount(_ profile: UserProfile) -> Bool {
        if Self.protectedFounderBlockAccountIDs.contains(profile.id) {
            return true
        }
        return Self.protectedFounderBlockUsernames.contains(normalizeUsername(profile.username))
    }

    func canBlockProfile(_ profile: UserProfile) -> Bool {
        guard profile.id != currentUser.id else { return false }
        return !isProtectedFounderBlockAccount(profile)
    }

    func canFounderDeleteAccount(_ profile: UserProfile) -> Bool {
        guard currentUser.isFounder else { return false }
        guard profile.id != currentUser.id else { return false }
        return !isProtectedFounderManagedAccount(profile)
    }

    func canFounderDeleteAccount(username: String) -> Bool {
        guard currentUser.isFounder else { return false }
        let normalized = normalizeUsername(username)
        if normalized == normalizeUsername(currentUser.username) { return false }
        return !Self.founderManagedBusinessAccounts.contains { normalizeUsername($0.username) == normalized }
    }

    func canBypassCityPostingRules(for profile: UserProfile) -> Bool {
        false
    }

    func shouldAlwaysAppearInCityFeeds(_ profile: UserProfile) -> Bool {
        isMandatoryFollowAccount(profile)
    }

    func postAppearsInCityFeed(_ post: FeedPost, city: String) -> Bool {
        guard post.rescrollOrigin == nil else { return false }
        guard !blockedUserIDs.contains(post.user.id) else { return false }
        guard !hiddenPostIDs.contains(post.id) else { return false }
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let postCity = post.locationCity?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return !postCity.isEmpty && postCity == normalizedCity
    }

    func onboardingSuggestedProfiles() -> [UserProfile] {
        Self.suggestedFollowProfiles
    }

    func applyOnboardingFollows(profileIDs: Set<UUID>) {
        registerProfiles(from: Self.suggestedFollowProfiles)
        for id in profileIDs where id != currentUser.id {
            addFollowRelation(from: currentUser.id, to: id)
        }
        syncFollowDirectories()
        saveState()
    }

    private func preferredProfile(_ lhs: UserProfile, _ rhs: UserProfile) -> UserProfile {
        if lhs.id != currentUser.id, rhs.id != currentUser.id,
           let lhsVersion = profileWriteVersionsByID[lhs.id],
           let rhsVersion = profileWriteVersionsByID[rhs.id],
           lhsVersion != rhsVersion {
            let newer = lhsVersion > rhsVersion ? lhs : rhs
            let older = lhsVersion > rhsVersion ? rhs : lhs
            return mergedProfile(base: newer, other: older, preferBaseValues: true)
        }
        let base: UserProfile
        let other: UserProfile
        if lhs.id == currentUser.id {
            base = lhs
            other = rhs
        } else if rhs.id == currentUser.id {
            base = rhs
            other = lhs
        } else {
            base = lhs
            other = rhs
        }
        return mergedProfile(base: base, other: other, preferBaseValues: false)
    }

    private func mergedProfile(base: UserProfile, other: UserProfile, preferBaseValues: Bool) -> UserProfile {
        let mergedKeywords = Array(Set(base.keywords + other.keywords)).sorted()

        func preferredText(_ first: String, _ second: String) -> String {
            let a = first.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = second.trimmingCharacters(in: .whitespacesAndNewlines)
            if preferBaseValues {
                if !a.isEmpty { return a }
                return b
            }
            if a.isEmpty { return b }
            if b.isEmpty { return a }
            return a.count >= b.count ? a : b
        }

        func preferredOptionalText(_ first: String?, _ second: String?) -> String? {
            let a = first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let b = second?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if preferBaseValues {
                if !a.isEmpty { return a }
                return b.isEmpty ? nil : b
            }
            if a.isEmpty { return b.isEmpty ? nil : b }
            if b.isEmpty { return a }
            return a.count >= b.count ? a : b
        }

        let mergedDisplayName = preferredText(base.displayName, other.displayName)
        let mergedBio = preferredText(base.bio, other.bio)

        let baseAvatarKey = avatarSourceKey(for: base)
        let otherAvatarKey = avatarSourceKey(for: other)
        let avatarSourceChanged = !otherAvatarKey.isEmpty && otherAvatarKey != baseAvatarKey
        let mergedAvatarData: Data? = {
            if avatarSourceChanged { return other.avatarImageData }
            if preferBaseValues, let baseData = base.avatarImageData { return baseData }
            if let otherData = other.avatarImageData { return otherData }
            return base.avatarImageData
        }()

        return UserProfile(
            id: base.id,
            username: base.username,
            displayName: mergedDisplayName,
            bio: mergedBio,
            keywords: mergedKeywords,
            gradientSpec: base.gradientSpec,
            avatarImageData: mergedAvatarData,
            avatarRef: avatarSourceChanged ? other.avatarRef : preferredOptionalText(base.avatarRef, other.avatarRef),
            avatarProvider: avatarSourceChanged ? other.avatarProvider : preferredOptionalText(base.avatarProvider, other.avatarProvider),
            avatarBucket: avatarSourceChanged ? other.avatarBucket : preferredOptionalText(base.avatarBucket, other.avatarBucket),
            avatarObjectKey: avatarSourceChanged ? other.avatarObjectKey : preferredOptionalText(base.avatarObjectKey, other.avatarObjectKey),
            isVerified: base.isVerified || other.isVerified,
            isFounder: base.isFounder || other.isFounder,
            isPrivateAccount: base.id == currentUser.id
                ? base.isPrivateAccount
                : (preferBaseValues ? base.isPrivateAccount : other.isPrivateAccount),
            accountType: (base.accountType == .business || other.accountType == .business) ? .business : base.accountType,
            subscriptionPlan: preferredOptionalText(base.subscriptionPlan, other.subscriptionPlan),
            signatureRef: preferredOptionalText(base.signatureRef, other.signatureRef),
            avatarVideoRef: preferredOptionalText(base.avatarVideoRef, other.avatarVideoRef),
            websiteURL: preferredOptionalText(base.websiteURL, other.websiteURL),
            venmoURL: preferredOptionalText(base.venmoURL, other.venmoURL),
            cashAppURL: preferredOptionalText(base.cashAppURL, other.cashAppURL),
            spotifyURL: preferredOptionalText(base.spotifyURL, other.spotifyURL),
            appleMusicURL: preferredOptionalText(base.appleMusicURL, other.appleMusicURL),
            businessLocation: preferredOptionalText(base.businessLocation, other.businessLocation),
            businessPhone: preferredOptionalText(base.businessPhone, other.businessPhone),
            homeCity: preferredOptionalText(base.homeCity, other.homeCity),
            dateOfBirth: base.dateOfBirth ?? other.dateOfBirth,
            ageAssuranceCompletedAt: base.ageAssuranceCompletedAt ?? other.ageAssuranceCompletedAt,
            parentalControls: base.parentalControls
        )
    }

    private func avatarSourceKey(for profile: UserProfile) -> String {
        let provider = profile.avatarProvider?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let bucket = profile.avatarBucket?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let objectKey = profile.avatarObjectKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !provider.isEmpty, !bucket.isEmpty, !objectKey.isEmpty {
            return "structured:\(provider)|\(bucket)|\(objectKey)"
        }
        let legacy = profile.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !legacy.isEmpty {
            return "legacy:\(legacy)"
        }
        return ""
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizeIdentityState() {
        let currentKey = normalizeUsername(currentUser.username)
        var byUsername: [String: UserProfile] = [currentKey: currentUser]

        for profile in profileRegistry.values {
            let key = normalizeUsername(profile.username)
            if key == currentKey {
                byUsername[key] = currentUser
            } else if let existing = byUsername[key] {
                byUsername[key] = preferredProfile(existing, profile)
            } else {
                byUsername[key] = profile
            }
        }

        let canonicalProfiles = Array(byUsername.values)
        let canonicalByUsername = Dictionary(uniqueKeysWithValues: canonicalProfiles.map { (normalizeUsername($0.username), $0) })
        let oldProfiles = profileRegistry.values
        var idMap: [UUID: UUID] = [:]
        for old in oldProfiles {
            if let canonical = canonicalByUsername[normalizeUsername(old.username)] {
                idMap[old.id] = canonical.id
            }
        }

        profileRegistry = Dictionary(uniqueKeysWithValues: canonicalProfiles.map { ($0.id, $0) })
        profileWriteVersionsByID = profileWriteVersionsByID.reduce(into: [UUID: Date]()) { partial, pair in
            let mappedID = idMap[pair.key] ?? pair.key
            if let existing = partial[mappedID] {
                partial[mappedID] = max(existing, pair.value)
            } else {
                partial[mappedID] = pair.value
            }
        }
        profileLastRefreshedAtByID = profileLastRefreshedAtByID.reduce(into: [UUID: Date]()) { partial, pair in
            let mappedID = idMap[pair.key] ?? pair.key
            if let existing = partial[mappedID] {
                partial[mappedID] = max(existing, pair.value)
            } else {
                partial[mappedID] = pair.value
            }
        }

        followRelations = followRelations.reduce(into: [UUID: Set<UUID>]()) { partial, pair in
            let followerID = idMap[pair.key] ?? pair.key
            var targets = partial[followerID] ?? Set<UUID>()
            for target in pair.value {
                let mappedTarget = idMap[target] ?? target
                if mappedTarget != followerID {
                    targets.insert(mappedTarget)
                }
            }
            partial[followerID] = targets
        }

        circles = circles.map { circle in
            var updated = circle
            var seen = Set<UUID>()
            updated.members = circle.members.compactMap { member in
                let mapped = idMap[member.profileID] ?? member.profileID
                guard seen.insert(mapped).inserted else { return nil }
                return CircleMember(id: member.id, profileID: mapped, status: member.status)
            }
            return updated
        }

        posts = posts.map { post in
            let key = normalizeUsername(post.user.username)
            let mappedUser = canonicalByUsername[key] ?? post.user
            var mappedOrigin = post.rescrollOrigin
            if let origin = post.rescrollOrigin {
                let originKey = normalizeUsername(origin.user.username)
                let mappedOriginUser = canonicalByUsername[originKey] ?? origin.user
                if mappedOriginUser.id != origin.user.id {
                    mappedOrigin = RescrollOrigin(
                        postID: origin.postID,
                        user: mappedOriginUser,
                        caption: origin.caption,
                        websiteURL: origin.websiteURL,
                        timestamp: origin.timestamp
                    )
                }
            }
            if mappedUser.id == post.user.id && mappedOrigin?.user.id == post.rescrollOrigin?.user.id {
                return post
            }
            return FeedPost(
                id: post.id,
                user: mappedUser,
                caption: post.caption,
                websiteURL: post.websiteURL,
                locationCity: post.locationCity,
                timestamp: post.timestamp,
                mediaPreview: post.mediaPreview,
                comments: post.comments,
                rescrollOrigin: mappedOrigin
            )
        }

        if let canonicalCurrent = canonicalByUsername[currentKey], canonicalCurrent.id != currentUser.id {
            currentUser = canonicalCurrent
        }
        currentUser = roleAdjustedProfile(currentUser)
    }

    private func roleAdjustedProfile(_ profile: UserProfile) -> UserProfile {
        // FOUNDER AUTH-ALIAS DISPLAY REMAP.  The founder has multiple
        // Supabase auth UUIDs that all represent the same human (canonical +
        // ~2 historical aliases declared in `founderAuthAliasIDs`).  Content
        // authored when an alias UUID was the authed session shows up in
        // the users table with the alias's username (e.g. "tonitodaro.mm"
        // instead of "primadonvino").  Without normalization, the UI
        // surfaces the alias username on moments, posts, comments, and
        // notifications — incorrect and confusing.
        //
        // Fix: at the boundary where backend user data flows into the app,
        // remap any alias UUID's DISPLAY fields (username, displayName) to
        // the canonical founder identity.  The UUID itself is preserved so
        // that:
        //   • The JWT subject continues to match for any outbound request
        //     that uses `currentUser.id` (post create, moment create, etc.).
        //   • Profile-registry lookups by the historical UUID still resolve.
        //   • Notification actor IDs already in storage continue to work.
        //
        // Only the username/displayName change — and that's all the user
        // sees in the UI.
        var resolved = profile
        // Only remap NON-CANONICAL aliases.  The canonical UUID's profile
        // carries the user's actual chosen displayName (e.g. "Toni Todaro")
        // from the live users table — overwriting it with the hard-coded
        // `founderCanonicalAccount.displayName` was causing the displayName
        // to flicker between the real name and "primadonvino" depending on
        // which code path produced the rendered profile.
        if let managed = founderManagedAccount(matching: profile) {
            resolved = profile.with(
                username: managed.username,
                displayName: managed.displayName,
                isVerified: true,
                isFounder: false,
                accountType: .business
            )
        }
        let isAlias = Self.founderAuthAliasIDs.contains(profile.id)
            && profile.id != Self.founderCanonicalAccount.id
        if founderManagedAccount(matching: profile) != nil {
            // Handled above. Managed brand accounts must keep their own
            // display names even if stale backend rows contain the founder's.
        } else if isAlias {
            resolved = profile.with(
                username: Self.founderCanonicalAccount.username,
                displayName: Self.founderCanonicalAccount.displayName,
                isVerified: true,
                isFounder: true
            )
        } else if profile.id == Self.founderCanonicalAccount.id ||
                    normalizeUsername(profile.username) == normalizeUsername(Self.founderCanonicalAccount.username) {
            let normalizedDisplayName = normalizeUsername(profile.displayName)
            if normalizedDisplayName.isEmpty || normalizedDisplayName == normalizeUsername(Self.founderCanonicalAccount.username) {
                resolved = profile.with(displayName: Self.founderCanonicalAccount.displayName)
            }
        }
        let founder = resolved.isFounder
        let paid = founder || resolved.isVerified
        if founder {
            return resolved.with(
                isVerified: true,
                isFounder: true
            )
        }
        return resolved.with(
            isVerified: paid,
            isFounder: false
        )
    }

    private func normalizePinnedPosts() {
        let validEntries = pinnedPostIDs.filter { userID, postID in
            posts.contains { $0.id == postID && $0.user.id == userID && $0.rescrollOrigin == nil }
        }
        if validEntries != pinnedPostIDs {
            pinnedPostIDs = validEntries
        }
    }

    private func markPostDeleted(_ postID: UUID) {
        pendingDeletedPostIDs.insert(postID)
        // Persist to the long-lived "ever-deleted" file (see saveUserDeletedPostIDs).
        saveUserDeletedPostIDs()
        posts.removeAll { $0.id == postID || $0.rescrollOrigin?.postID == postID }
        pendingRemotePosts.removeAll { $0.id == postID || $0.rescrollOrigin?.postID == postID }
        deliveredAdPosts.removeAll { $0.id == postID || $0.rescrollOrigin?.postID == postID }
        pendingPublishRetryTasks[postID]?.cancel()
        pendingPublishRetryTasks[postID] = nil
        clearPostPublishDeliveryState(postID)
    }

    private func reconcileCachedDeletedPostsWithBackend(force: Bool = false, reason: String) async {
        guard backendClient.isEnabled else { return }
        guard hasLocallyUsableAuthToken() || hasRefreshTokenForBackendSync() else { return }
        let now = Date()
        if !force, now.timeIntervalSince(lastDeletedPostTombstoneSweepAt) < Self.deletedPostTombstoneSweepInterval {
            return
        }
        let cachedPostIDs = Set(posts.flatMap { post -> [UUID] in
            if let originID = post.rescrollOrigin?.postID {
                return [post.id, originID]
            }
            return [post.id]
        })
        guard !cachedPostIDs.isEmpty else { return }

        lastDeletedPostTombstoneSweepAt = now
        var deletedIDs: Set<UUID> = []
        let ids = Array(cachedPostIDs)
        for start in stride(from: 0, to: ids.count, by: 200) {
            let end = min(start + 200, ids.count)
            let chunk = Array(ids[start..<end])
            guard !chunk.isEmpty else { continue }
            if let deleted = try? await backendClient.fetchDeletedPostIDs(postIDs: chunk) {
                deletedIDs.formUnion(deleted)
            }
        }
        guard !deletedIDs.isEmpty else { return }
        for id in deletedIDs {
            markPostDeleted(id)
        }
        updateFeedDebug(
            stage: "deleted_post_tombstones_reconciled",
            status: "Deleted posts purged",
            detail: "count=\(deletedIDs.count), cached=\(cachedPostIDs.count), source=\(reason)"
        )
        saveState()
    }

    private func removePostsWithMissingMedia(checkAssetLibrary: Bool = true) {
        _ = checkAssetLibrary
        // Backend-authoritative mode:
        // Never prune posts because local files or local Photos assets disappear.
        // Deletions must come from backend state, not device-local storage checks.
        normalizePinnedPosts()
        if posts.isEmpty && !useServerAuthoritativeState {
            posts = Self.initialPosts
        }
    }

#if canImport(UIKit)
    private func registerForegroundObserver() {
        guard foregroundObserver == nil else { return }
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.removePostsWithMissingMedia(checkAssetLibrary: true)
                self.syncNotificationInbox()
                let recovered = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
                if recovered {
                    self.lastTerminalAuthFailureAt = nil
                }
                if self.pendingBackendWriteQueue.isEmpty == false {
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                }
                await self.syncFromBackendIfAvailable(lane: .socialSnapshot)
            }
        }
    }

    func bootstrapNotifications() {
        requestNotificationAuthorizationIfNeeded()
        requestRemoteNotificationRegistrationIfNeeded()
        syncNotificationInbox()
        attemptPushTokenRegistrationIfPossible()
    }

    private func registerPushRegistrationObservers() {
        guard pushTokenObserver == nil, pushTokenFailureObserver == nil else { return }
        pushTokenObserver = NotificationCenter.default.addObserver(
            forName: .scrollsDidRegisterForRemoteNotifications,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let token = notification.userInfo?[ScrollsRemoteNotificationUserInfoKey.token] as? String
            else { return }
            Task { @MainActor [weak self] in
                self?.handleRemoteNotificationDeviceToken(token)
            }
        }
        pushTokenFailureObserver = NotificationCenter.default.addObserver(
            forName: .scrollsDidFailRemoteNotificationRegistration,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let description = notification.userInfo?[ScrollsRemoteNotificationUserInfoKey.errorDescription] as? String
            else { return }
            Task { @MainActor [weak self] in
                self?.updateDebugStatus { debug in
                    debug.pushRegistrationStatus = "push_registration_failed"
                    debug.pushRegistrationDetail = description
                    debug.pushRegistrationUpdatedAt = Date()
                }
            }
        }
    }

    private func requestRemoteNotificationRegistrationIfNeeded() {
        let requested = UserDefaults.standard.bool(forKey: Self.remoteNotificationRegistrationRequestedKey)
        if !requested {
            UserDefaults.standard.set(true, forKey: Self.remoteNotificationRegistrationRequestedKey)
        }
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    private func handleRemoteNotificationDeviceToken(_ token: String) {
        let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        UserDefaults.standard.set(normalized, forKey: Self.pendingPushTokenKey)
        attemptPushTokenRegistrationIfPossible()
    }

    private func attemptPushTokenRegistrationIfPossible() {
        guard backendClient.isEnabled else { return }
        let token = (UserDefaults.standard.string(forKey: Self.pendingPushTokenKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !token.isEmpty else { return }
        guard isPushTokenActive(token) else { return }
        guard isAuthenticatedForPushRegistration else { return }

        let alreadyRegistered = (UserDefaults.standard.string(forKey: Self.lastRegisteredPushTokenKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard alreadyRegistered != token else { return }

        let userID = currentUser.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.registerDevicePushToken(
                    token: token,
                    userID: userID,
                    platform: "ios",
                    environment: self.pushEnvironmentLabel(),
                    localeIdentifier: Locale.current.identifier,
                    appVersion: self.currentAppVersionLabel()
                )
                UserDefaults.standard.set(token, forKey: Self.lastRegisteredPushTokenKey)
            } catch {
                self.registerPushTokenFailure(token, hardFailure: false)
                self.updateDebugStatus { debug in
                    debug.pushRegistrationStatus = "push_registration_deferred"
                    debug.pushRegistrationDetail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    debug.pushRegistrationUpdatedAt = Date()
                }
            }
        }
    }

    private var isAuthenticatedForPushRegistration: Bool {
        hasLocallyUsableAuthToken()
            || hasRefreshTokenForBackendSync()
            || hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
    }

    private func currentAppVersionLabel() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func pushEnvironmentLabel() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    private func scheduleAppIconBadgeRefresh() {
        let count = unreadNotificationCount + unreadCircleMessageIDs.count
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(count, withCompletionHandler: nil)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }

    private func registerBackgroundObserver() {
        guard backgroundObserver == nil else { return }
        backgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistStateForAppBackground()
                self?.scheduleDailyReminderIfNeeded()
            }
        }
    }

    private func unregisterForegroundObserver() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }

    private func scheduleDailyReminderIfNeeded() {
        let dailyReminderKey = "scrolls.notifications.dailyReminder.lastSent"
        let unreadCount = notifications.filter { !$0.isRead }.count + unreadCircleMessageIDs.count
        guard unreadCount > 0 else { return }

        let now = Date()
        let lastSent = UserDefaults.standard.object(forKey: dailyReminderKey) as? Date
        if let lastSent, now.timeIntervalSince(lastSent) < 24 * 3600 {
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .denied { return }
            let requestPush = {
                let center = UNUserNotificationCenter.current()
                let content = UNMutableNotificationContent()
                content.title = "You Have Notifications On Your Scrolls"
                content.body = "Open Scrolls to catch up."
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "scrolls-daily-reminder",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                center.removePendingNotificationRequests(withIdentifiers: ["scrolls-daily-reminder"])
                center.add(request, withCompletionHandler: nil)
                UserDefaults.standard.set(now, forKey: dailyReminderKey)
            }

            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                requestPush()
            } else if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    requestPush()
                }
            }
        }
    }

    /// Apple's review team flags apps that cold-call `requestAuthorization`
    /// without first explaining to the user what notifications they'll
    /// receive.  Instead of asking iOS directly, we ask iOS what the
    /// current status is — and if it's `.notDetermined` and we haven't
    /// already prompted, we set a `@Published` flag the view layer
    /// watches.  ContentView shows a SwiftUI alert ("Get pinged about
    /// mentions, comments, and live streams from people you follow")
    /// and only then invokes `enablePushNotificationsAfterConsent()`,
    /// which calls the iOS API.
    private func requestNotificationAuthorizationIfNeeded() {
        let alreadyPrompted = UserDefaults.standard.bool(forKey: Self.notificationPermissionRequestedKey)
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self else { return }
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined where !alreadyPrompted:
                    self.shouldShowPushPrePrompt = true
                default:
                    self.shouldShowPushPrePrompt = false
                }
            }
        }
    }

    /// Called from the view layer after the user taps "Enable" on the
    /// in-app pre-prompt.  Marks the pre-prompt as shown and triggers
    /// the real iOS authorization dialog.
    func enablePushNotificationsAfterConsent() {
        UserDefaults.standard.set(true, forKey: Self.notificationPermissionRequestedKey)
        shouldShowPushPrePrompt = false
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard granted else { return }
                self?.requestRemoteNotificationRegistrationIfNeeded()
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Called from the view layer when the user taps "Not now" on the
    /// pre-prompt.  Records the dismissal so we don't immediately
    /// re-show the pre-prompt on next launch — they can still enable
    /// notifications later from Settings.
    func declinePushNotificationsAfterPrePrompt() {
        UserDefaults.standard.set(true, forKey: Self.notificationPermissionRequestedKey)
        shouldShowPushPrePrompt = false
    }

    private func scheduleBackgroundInboxAlertIfNeeded(previousUnreadCount: Int, nextUnreadCount: Int) {
        guard nextUnreadCount > previousUnreadCount else { return }
        guard UIApplication.shared.applicationState != .active else { return }

        let lastBackgroundInboxAlertAtKey = Self.lastBackgroundInboxAlertAtKey
        let now = Date()
        let lastSent = UserDefaults.standard.object(forKey: lastBackgroundInboxAlertAtKey) as? Date
        if let lastSent, now.timeIntervalSince(lastSent) < 5 * 60 {
            return
        }

        let hasUnreadCircleMessages = !unreadCircleMessageIDs.isEmpty
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            if hasUnreadCircleMessages {
                content.title = "New Circle messages"
                content.body = "Open Scrolls to catch up in Circles."
                content.userInfo = ["scroll_url": "scrolls://circles"]
            } else {
                content.title = "You Have Notifications On Your Scrolls"
                content.body = "Open Scrolls to catch up."
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "scrolls-background-inbox-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            UserDefaults.standard.set(now, forKey: lastBackgroundInboxAlertAtKey)
        }
    }
#endif

    private static let mentionRegex = try? NSRegularExpression(
        pattern: "@([A-Za-z0-9_\\.]+)",
        options: .caseInsensitive
    )

    private func mentionUsernames(in text: String) -> [String] {
        guard let regex = Self.mentionRegex else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let usernameRange = match.range(at: 1)
            return nsText.substring(with: usernameRange).lowercased()
        }
    }

    private func mentionUsers(in text: String) -> [UserProfile] {
        let usernames = Set(mentionUsernames(in: text))
        guard !usernames.isEmpty else { return [] }
        return searchableProfiles.filter { usernames.contains($0.username.lowercased()) }
    }

    private func notifyMentions(in text: String?, context: String, objectID: UUID?, actor: UserProfile? = nil) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let targets = mentionUsers(in: text)
        let source = actor ?? currentUser
        for target in Set(targets) where target.id != source.id {
            enqueueNotification(
                type: .mention,
                title: "Mention from @\(source.username)",
                message: "@\(source.username) mentioned you in \(context).",
                digestKey: "mention:\(target.id.uuidString):\(context)",
                actorKey: "mention:\(source.id.uuidString)",
                urgent: true,
                actorID: source.id,
                objectID: objectID
            )
        }
    }

    var canLoadMoreFeedTimeline: Bool {
        normalizedFeedCursor(feedTimelineNextCursor) != nil
    }

    private var feedTimelineLazyLoadBackoffInterval: TimeInterval {
        guard feedTimelineLazyLoadFailureCount > 0 else { return 0 }
        let attempts = max(0, feedTimelineLazyLoadFailureCount - 1)
        return min(pow(2.0, Double(attempts)), 15.0)
    }

    func loadMorePosts() {
        // Lazy-load next feed window while user scrolls main timeline.
        guard backendClient.isEnabled else { return }
        guard !isFeedTimelineLazyLoadInFlight else { return }
        let now = Date()
        guard now.timeIntervalSince(lastLoadMoreAt) > 0.5 else { return }
        if let lastErrorAt = lastFeedTimelineLazyLoadErrorAt {
            let backoff = feedTimelineLazyLoadBackoffInterval
            guard now.timeIntervalSince(lastErrorAt) >= backoff else { return }
        }
        guard let cursor = normalizedFeedCursor(feedTimelineNextCursor) else { return }
        lastLoadMoreAt = now
        isFeedTimelineLazyLoadInFlight = true
        isFeedTimelineLazyLoading = true

        Task {  [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isFeedTimelineLazyLoadInFlight = false
                    self?.isFeedTimelineLazyLoading = false
                }
            }

            do {
                _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
                await MainActor.run {
                    self.updateFeedDebug(
                        stage: "lazy_load_request",
                        status: "Lazy load page request",
                        detail: "cursor=\(cursor), limit=\(Self.feedTimelineLazyLoadPageSize), auth_override=no"
                    )
                }
                let page = try await self.backendClient.fetchFeed(
                    userID: self.currentUser.id,
                    cursor: cursor,
                    limit: Self.feedTimelineLazyLoadPageSize,
                    allowAuthContextFallbackOnEmpty: true,
                    allowAuthContextFallbackOnAuthFailure: false,
                    includeAuthorization: true
                )
                await MainActor.run {
                    self.feedTimelineNextCursor = self.normalizedFeedCursor(page.nextCursor)
                    self.mergeRemotePosts(page.posts, source: .feedTimelineAppend)
                    self.feedTimelineLazyLoadFailureCount = 0
                    self.lastFeedTimelineLazyLoadErrorAt = nil
                    self.updateFeedDebug(
                        stage: "lazy_load_success",
                        status: "Lazy load success (\(page.posts.count) posts)",
                        detail: "next_cursor=\(self.feedTimelineNextCursor ?? "none")",
                        visibilitySummary: self.mainFeedVisibilitySummary()
                    )
                }
            } catch {
                await MainActor.run {
                    self.feedTimelineLazyLoadFailureCount = min(self.feedTimelineLazyLoadFailureCount + 1, 5)
                    self.lastFeedTimelineLazyLoadErrorAt = Date()
                    let backoff = self.feedTimelineLazyLoadBackoffInterval
                    self.updateFeedDebug(
                        stage: "lazy_load_failed",
                        status: "Lazy load failed: \(self.describeBackendError(error))",
                        detail: "Load-more request failed before merge. retry_backoff=\(Int(backoff))s",
                        error: error
                    )
                }
            }
        }
    }

    private func scheduleFeedFastTopUpIfNeeded() {
        guard backendClient.isEnabled else { return }
        Task { [weak self] in
            await self?.performFeedFastTopUpIfNeeded()
        }
    }

    private func performFeedFastTopUpIfNeeded() async {
        guard backendClient.isEnabled else { return }
        guard !Task.isCancelled else { return }
        guard !isFeedFastTopUpInFlight else { return }
        guard !isFeedTimelineLazyLoadInFlight else { return }
        let visibleNow = mainFeedPosts.count
        guard visibleNow > 0, visibleNow <= Self.feedTimelineFastStartPageSize else { return }
        guard let cursor = normalizedFeedCursor(feedTimelineNextCursor) else { return }
        let remaining = max(0, Self.feedTimelineDefaultPageSize - visibleNow)
        guard remaining > 0 else { return }

        isFeedFastTopUpInFlight = true
        defer { isFeedFastTopUpInFlight = false }

        let topUpLimit = min(remaining, Self.feedTimelineDefaultPageSize - Self.feedTimelineFastStartPageSize)

        do {
            guard !Task.isCancelled else { return }
            _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.updateFeedDebug(
                    stage: "fast_top_up_request",
                    status: "Feed fast-start top-up request",
                    detail: "cursor=\(cursor), limit=\(topUpLimit), auth_override=no"
                )
            }
            guard !Task.isCancelled else { return }
            let page = try await backendClient.fetchFeed(
                userID: currentUser.id,
                cursor: cursor,
                limit: topUpLimit,
                allowAuthContextFallbackOnEmpty: true,
                allowAuthContextFallbackOnAuthFailure: false,
                includeAuthorization: true
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.feedTimelineNextCursor = self.normalizedFeedCursor(page.nextCursor)
                self.mergeRemotePosts(page.posts, source: .feedTimelineAppend)
                self.updateFeedDebug(
                    stage: "fast_top_up_success",
                    status: "Feed fast-start top-up success",
                    detail: "posts=\(page.posts.count), next_cursor=\(self.feedTimelineNextCursor ?? "none")",
                    visibilitySummary: self.mainFeedVisibilitySummary()
                )
            }
        } catch {
            await MainActor.run {
                self.updateFeedDebug(
                    stage: "fast_top_up_failed",
                    status: "Feed fast-start top-up failed: \(self.describeBackendError(error))",
                    detail: "Top-up request failed before merge.",
                    error: error
                )
            }
        }
    }

    func refreshFeed() {
        applyPendingFeedPosts()
        posts.sort { $0.timestamp > $1.timestamp }
        saveState()
        clearFeedCache()
        clearSearchCache()
        Task {  [weak self] in
            guard let self else { return }
            _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
            self.restoreBackendAuthTokenForCurrentUserIfNeeded()
            await self.ensureBackendFollowLinksForCurrentUser()
            await self.syncFromBackendIfAvailable(lane: .manualRefresh)
        }
    }

    func performBackgroundFeedRefresh() async -> Bool {
        guard backendClient.isEnabled else { return false }
        guard shouldRunSignedInBackgroundWork() else { return true }
        guard !Task.isCancelled else { return false }

        _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        await ensureBackendFollowLinksForCurrentUser()
        await syncFromBackendIfAvailable(lane: .feedFast, skipIdentityReconcile: true)

        if !Task.isCancelled {
            await performFeedFastTopUpIfNeeded()
        }

        guard !Task.isCancelled else { return false }
        let hasFeed = !mainFeedPosts.isEmpty || !posts.isEmpty

        if hasFeed {
            await syncFromBackendIfAvailable(lane: .socialSnapshot, skipIdentityReconcile: true)
            if !Task.isCancelled {
                await loadMoments()
            }
            if !Task.isCancelled {
                await prewarmMainFeedMediaCache(limit: 10)
            }
        }

        return hasFeed
    }

    private func prewarmMainFeedMediaCache(limit: Int = 10) async {
        guard limit > 0 else { return }
        let seedPosts = Array(mainFeedPosts.prefix(limit))
        guard !seedPosts.isEmpty else { return }

        for post in seedPosts {
            guard !Task.isCancelled else { return }

            if let avatarURL = post.user.remoteAvatarURL ?? {
                let raw = post.user.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !raw.isEmpty else { return nil }
                return URL(string: raw)
            }() {
                // 240px matches what AvatarView requests for 80pt avatars on
                // all Retina densities — ensures the prefetch populates the
                // exact cache slot AvatarView will look up.
                _ = await FeedMediaPrefetcher.shared.thumbnail(for: avatarURL, maxPixel: 240)
            }

            if let coverURL = post.podcastCoverImageURL {
                _ = await FeedMediaPrefetcher.shared.thumbnail(for: coverURL, maxPixel: 960)
            }

            switch post.mediaPreview {
            case .photo(let preview):
                _ = await FeedMediaPrefetcher.shared.thumbnail(for: preview.fileURL, maxPixel: 960)
            case .video(let preview):
                if !post.isAudioPost {
                    await FeedMediaPrefetcher.shared.prefetchVideo(url: preview.url)
                }
            case .text:
                continue
            }
        }
    }

    func setFeedTopVisible(_ isVisible: Bool) {
        shouldBufferIncomingPosts = !isVisible
        if isVisible {
            applyPendingFeedPosts()
        }
    }

    func applyPendingFeedPosts() {
        guard !pendingRemotePosts.isEmpty else { return }
        let pendingBefore = pendingRemotePosts.count
        let postsBefore = posts.count
        let visibleBefore = mainFeedPosts.count
        var merged = pendingRemotePosts + posts
        merged.sort { $0.timestamp > $1.timestamp }
        posts = deduplicatedPosts(merged)
        posts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
        pendingRemotePosts.removeAll()
        pendingFeedPostCount = 0
        let summary = [
            "pending_applied=\(pendingBefore)",
            "local_posts=\(postsBefore)->\(posts.count)",
            "visible=\(visibleBefore)->\(mainFeedPosts.count)"
        ].joined(separator: ", ")
        updateFeedDebug(
            stage: "pending_feed_applied",
            status: "Applied buffered feed posts",
            detail: summary,
            mergeSummary: summary,
            visibilitySummary: mainFeedVisibilitySummary()
        )
        saveState()
    }

    func pendingFeedPostsCount(in city: String? = nil) -> Int {
        guard let city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return pendingFeedPostCount
        }
        return pendingRemotePosts.filter { post in
            postAppearsInCityFeed(post, city: city) && !isAdDesignatedPost(post)
        }.count
    }

    /// Maximum number of the current user's own posts shown in the main feed.
    /// The feed is intended to surface content from accounts you follow; showing
    /// every own post would crowd out that content.  The full post list is always
    /// visible on the user's own profile tab, which has no cap.
    private static let mainFeedOwnPostLimit = 5

    var mainFeedPosts: [FeedPost] {
        let eligible = posts.filter(shouldIncludeInMainFeed)
        // Separate own posts from following posts and cap own posts at the limit.
        // Sorting own posts before slicing ensures the 5 kept are the most recent.
        let ownPosts = eligible
            .filter { $0.user.id == currentUser.id }
            .sorted(by: isNewerFeedPost(_:than:))
            .prefix(Self.mainFeedOwnPostLimit)
        let followingPosts = eligible.filter { $0.user.id != currentUser.id }
        return (Array(ownPosts) + followingPosts).sorted(by: isNewerFeedPost(_:than:))
    }

    var pendingMainFeedPostCount: Int {
        pendingRemotePosts.filter(shouldIncludeInMainFeed).count
    }

    func pendingMainFeedPostsCount(in city: String) -> Int {
        let normalized = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return pendingRemotePosts.filter { post in
            shouldIncludeInMainFeed(post) &&
            (post.locationCity?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized)
        }.count
    }

    private func shouldIncludeInMainFeed(_ post: FeedPost) -> Bool {
        mainFeedEligibilityReason(for: post).isIncluded
    }

    private func mainFeedEligibilityReason(for post: FeedPost) -> MainFeedEligibilityReason {
        // Blocked users are hidden from all feeds, even your own timeline.
        if blockedUserIDs.contains(post.user.id) { return .excludedAd }
        // Posts the user explicitly hid from their feed stay hidden across
        // launches — same exclusion bucket as ads, since the user has
        // already decided they don't want to see this in their main feed.
        if hiddenPostIDs.contains(post.id) { return .excludedAd }
        if isAdDesignatedPost(post) { return .excludedAd }
        if trustedTimelinePostIDs.contains(post.id) {
            return .includedFollowingID
        }
        // NOTE: founderManagedBusinessAccounts are NOT excluded here — they appear in
        // mandatoryFollowIDs() and are included via .includedFollowingID below.
        // isProtectedFounderManagedAccount only protects these accounts from deletion/unfollow,
        // it does not mean their posts should be hidden from the feed.
        if post.user.id == currentUser.id { return .includedOwnPost }
        // Main feed is strictly follow-based; founder and trusted timeline posts
        // appear via enforced follow relationships rather than bypass rules.
        let normalizedPostUsername = normalizeUsername(post.user.username)
        // Use follow status by username as primary source, with ID fallback.
        // Account switching can transiently remap IDs before followRelations catches up.
        if isFollowing(post.user) {
            return .includedFollowing
        }
        let followingIDs = (followRelations[currentUser.id] ?? []).union(mandatoryFollowIDs())
        if followingIDs.contains(post.user.id) {
            return .includedFollowingID
        }
        let usernameMatch = followingIDs.contains { followeeID in
            guard let followed = profileRegistry[followeeID] else { return false }
            return normalizeUsername(followed.username) == normalizedPostUsername
        }
        return usernameMatch ? .includedFollowingUsername : .excludedNotFollowed
    }

    private func mainFeedEligibilityCounts(for source: [FeedPost]) -> [MainFeedEligibilityReason: Int] {
        var counts: [MainFeedEligibilityReason: Int] = [:]
        for post in source {
            counts[mainFeedEligibilityReason(for: post), default: 0] += 1
        }
        return counts
    }

    private func mainFeedVisibilitySummary() -> String {
        let counts = mainFeedEligibilityCounts(for: posts)
        let total = posts.count
        let visible = counts.reduce(into: 0) { partial, entry in
            if entry.key.isIncluded { partial += entry.value }
        }
        let hidden = max(0, total - visible)
        let pendingVisible = pendingRemotePosts.filter { mainFeedEligibilityReason(for: $0).isIncluded }.count
        let pendingHidden = max(0, pendingRemotePosts.count - pendingVisible)
        let nextCursor = normalizedFeedCursor(feedTimelineNextCursor) ?? "none"
        let followingCount = (followRelations[currentUser.id] ?? []).count
        let parts: [String] = [
            "posts=\(total)",
            "visible=\(visible)",
            "hidden=\(hidden)",
            "pending_visible=\(pendingVisible)",
            "pending_hidden=\(pendingHidden)",
            "following=\(followingCount)",
            "trusted_ids=\(trustedTimelinePostIDs.count)",
            "buffer=\(shouldBufferIncomingPosts ? "on" : "off")",
            "next_cursor=\(nextCursor)",
            "excluded_not_followed=\(counts[.excludedNotFollowed, default: 0])",
            "excluded_ads=\(counts[.excludedAd, default: 0])"
        ]
        return parts.joined(separator: ", ")
    }

    private func isNewerFeedPost(_ lhs: FeedPost, than rhs: FeedPost) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private func containsBlockedLink(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return Self.blockedLinkTokens.contains { normalized.contains($0) }
    }

    private func containsAIGenerationSignal(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return Self.blockedAIGenerationTokens.contains { normalized.contains($0) }
    }

    private func containsNuditySignal(_ text: String) -> Bool {
        let normalized = text.lowercased()
        if Self.blockedGenitalTokens.contains(where: { normalized.contains($0) }) {
            return true
        }
        if Self.blockedChildNudityTokens.contains(where: { normalized.contains($0) }) {
            return true
        }
        let hasBlocked = Self.blockedNudityTokens.contains { normalized.contains($0) }
        if !hasBlocked { return false }
        let hasAllowedShirtlessContext = Self.shirtlessAllowedContextTokens.contains { normalized.contains($0) }
        let hasHardBlockedExplicitContext = normalized.contains("porn") || normalized.contains("onlyfans")
        return !hasAllowedShirtlessContext || hasHardBlockedExplicitContext
    }

    @discardableResult
    private func validateAllowedText(_ text: String?, context: String) -> Bool {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
        guard !containsBlockedLink(text) else {
            moderationErrorMessage = "Links to restricted platforms are not allowed in \(context)."
            return false
        }
        guard !containsAIGenerationSignal(text) else {
            moderationErrorMessage = "AI-generated content is not allowed. Please post human-created content."
            return false
        }
        guard !containsNuditySignal(text) else {
            moderationErrorMessage = "Explicit nudity content is not allowed."
            return false
        }
        return true
    }

    private func normalizedWebsiteURLForPhotoPost(_ rawValue: String?, media: MediaPreview) -> String? {
        let trimmed = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard case .photo = media else {
            moderationErrorMessage = "Website links can only be added to photo Scrolls."
            return nil
        }
        guard currentUser.isVerified || currentUser.isFounder else {
            moderationErrorMessage = "Only verified users can add website links to photo Scrolls."
            return nil
        }
        guard !containsBlockedLink(trimmed) else {
            moderationErrorMessage = "OnlyFans links are not allowed."
            return nil
        }
        let normalized = trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://")
            ? trimmed
            : "https://\(trimmed)"
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            moderationErrorMessage = "Please enter a valid website URL."
            return nil
        }
        return normalized
    }

    private func normalizedLocationForCurrentUser(_ locationCity: String?) -> String? {
        guard currentUser.parentalControls.canTagLocations || !currentUser.parentalControls.isEnabled else {
            moderationErrorMessage = "Parental Controls currently disable city tags for this account."
            return nil
        }
        if let explicitLocation = locationCity {
            let trimmed = explicitLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return nil
            }
            return trimmed
        }
        let fallbackHomeCity = currentUser.homeCity?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (fallbackHomeCity?.isEmpty == false) ? fallbackHomeCity : nil
    }

    private func recordSpamAction(
        key: String,
        limit: Int,
        window: TimeInterval,
        blockedMessage: String
    ) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        var entries = spamActionHistory[key] ?? []
        entries.removeAll { $0 < cutoff }
        guard entries.count < limit else {
            spamActionHistory[key] = entries
            moderationErrorMessage = blockedMessage
            return false
        }
        entries.append(now)
        spamActionHistory[key] = entries
        return true
    }

    private func recordSpamText(
        key: String,
        text: String,
        limit: Int,
        window: TimeInterval,
        blockedMessage: String
    ) -> Bool {
        let normalized = text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !normalized.isEmpty else { return true }
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        var entries = spamTextHistory[key] ?? []
        entries.removeAll { $0.at < cutoff }
        let duplicateCount = entries.filter { $0.text == normalized }.count
        guard duplicateCount < limit else {
            spamTextHistory[key] = entries
            moderationErrorMessage = blockedMessage
            return false
        }
        entries.append(SpamTextRecord(text: normalized, at: now))
        spamTextHistory[key] = entries
        return true
    }

    /// Publishes a multi-photo carousel post.  The primary photo travels
    /// through the standard publish pipeline; extras (slides 2..N, up to 3
    /// more for a 4-photo max) are pre-uploaded separately and their
    /// resolved remote URLs are encoded into the caption via the
    /// [PHOTO_CAROUSEL_BASE64] marker.  Older clients that don't recognize
    /// the marker just see the primary photo, so this is fully backward
    /// compatible.  Returns false (and sets moderationErrorMessage) on
    /// upload failure; on success the standard onPost completion fires
    /// once the primary upload completes.
    func publishPhotoCarousel(
        primary: MediaPreview,
        extras: [PhotoPreview],
        caption: String?,
        locationCity: String? = nil,
        websiteURL: String? = nil,
        backendCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) async -> Bool {
        guard case .photo = primary else { return false }
        guard !extras.isEmpty else {
            return publish(
                media: primary,
                caption: caption,
                locationCity: locationCity,
                websiteURL: websiteURL,
                backendCompletion: backendCompletion
            )
        }
        let carouselPostID = UUID()
        var uploadedURLs: [URL] = []
        for (index, extra) in extras.enumerated() {
            do {
                let result = try await backendClient.uploadPostCarouselPhoto(
                    postID: carouselPostID,
                    authorID: currentUser.id,
                    localURL: extra.fileURL,
                    slideNumber: index + 2
                )
                let normalized = result.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty, let parsed = URL(string: normalized) else {
                    moderationErrorMessage = "Couldn't attach carousel photo \(index + 2)."
                    return false
                }
                uploadedURLs.append(parsed)
            } catch {
                moderationErrorMessage = "Couldn't upload carousel photo \(index + 2). Please try again."
                return false
            }
        }
        let extendedCaption = FeedPost.photoCarouselCaption(
            from: caption,
            extraPhotoURLs: uploadedURLs
        )
        return publish(
            media: primary,
            caption: extendedCaption,
            locationCity: locationCity,
            websiteURL: websiteURL,
            postID: carouselPostID,
            backendCompletion: backendCompletion
        )
    }

    @discardableResult
    func publish(
        media: MediaPreview,
        caption: String?,
        locationCity: String? = nil,
        websiteURL: String? = nil,
        postID: UUID? = nil,
        coverImageRef: String? = nil,
        coverProvider: String? = nil,
        coverBucket: String? = nil,
        coverObjectKey: String? = nil,
        backendCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) -> Bool {
        guard recordSpamAction(
            key: "publish:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.postLimit,
            window: Self.SpamProtectionMode.postWindow,
            blockedMessage: "You're posting too fast. Please wait a moment."
        ) else { return false }
        guard validateAllowedText(caption, context: "captions") else { return false }
        if let caption, !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard recordSpamText(
                key: "publish-caption:\(currentUser.id.uuidString)",
                text: caption,
                limit: Self.SpamProtectionMode.duplicateTextLimit,
                window: Self.SpamProtectionMode.duplicateTextWindow,
                blockedMessage: "You're repeating the same caption too quickly."
            ) else { return false }
        }
        let resolvedWebsiteURL = normalizedWebsiteURLForPhotoPost(websiteURL, media: media)
        if websiteURL != nil && resolvedWebsiteURL == nil {
            return false
        }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        let post = FeedPost(
            id: postID ?? UUID(),
            user: currentUser,
            caption: caption,
            websiteURL: resolvedWebsiteURL,
            locationCity: resolvedLocation,
            timestamp: Date(),
            mediaPreview: media,
            coverImageRef: coverImageRef,
            coverProvider: coverProvider,
            coverBucket: coverBucket,
            coverObjectKey: coverObjectKey,
            comments: [],
            rescrollOrigin: nil
        )
        return publish(
            post: post,
            mentionText: caption,
            mentionContext: "a scroll",
            backendCompletion: backendCompletion
        )
    }

    @MainActor
    @discardableResult
    func publishPodcast(
        media: MediaPreview,
        caption: String? = nil,
        coverPhoto: PhotoPreview,
        loopVideo: VideoPreview? = nil,
        locationCity: String? = nil,
        backendCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) async -> Bool {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedCaption.isEmpty else {
            moderationErrorMessage = "Podcasts need a caption before posting."
            return false
        }

        let postID = UUID()
        let coverUploadResult: MediaUploadResult
        do {
            let preparedCoverURL = try MediaStorage.preparePodcastCoverImage(from: coverPhoto.fileURL)
            defer { try? FileManager.default.removeItem(at: preparedCoverURL) }
            coverUploadResult = try await backendClient.uploadPodcastCoverImage(
                postID: postID,
                authorID: currentUser.id,
                localURL: preparedCoverURL,
                timeoutInterval: 60
            )
        } catch {
            moderationErrorMessage = "Could not upload podcast cover image. Please try again."
            return false
        }

        let normalizedCoverRef = coverUploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCoverRef.isEmpty else {
            moderationErrorMessage = "Could not attach podcast cover image."
            return false
        }

        var loopVideoURL: URL?
        if let loopVideo {
            do {
                let loopUploadResult = try await backendClient.uploadPodcastLoopVideo(
                    postID: postID,
                    authorID: currentUser.id,
                    localURL: loopVideo.url,
                    timeoutInterval: 60
                )
                let normalizedLoopRef = loopUploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedLoopRef.isEmpty, let parsed = URL(string: normalizedLoopRef) {
                    loopVideoURL = parsed
                }
            } catch {
                moderationErrorMessage = "Could not upload podcast loop video. Please try again."
                return false
            }
        }

        let podcastCaption = FeedPost.podcastCaption(from: trimmedCaption, loopVideoURL: loopVideoURL)
        return publish(
            media: media,
            caption: podcastCaption,
            locationCity: locationCity,
            websiteURL: nil,
            postID: postID,
            coverImageRef: normalizedCoverRef,
            coverProvider: coverUploadResult.provider,
            coverBucket: coverUploadResult.bucket,
            coverObjectKey: coverUploadResult.objectKey,
            backendCompletion: backendCompletion
        )
    }

    @MainActor
    @discardableResult
    func publishMusic(
        media: MediaPreview,
        caption: String? = nil,
        coverPhoto: PhotoPreview,
        loopVideo: VideoPreview? = nil,
        releaseType: MusicReleaseType = .singlesEPs,
        tracks: [MusicTrackUploadDraft] = [],
        locationCity: String? = nil,
        releaseDate: Date? = nil,
        recordLabel: String? = nil,
        genre: String? = nil,
        linerNotes: String? = nil,
        backendCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) async -> Bool {
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedCaption.isEmpty else {
            moderationErrorMessage = "Music uploads need a caption before posting."
            return false
        }

        let normalizedTracks = tracks
            .map {
                MusicTrackUploadDraft(
                    id: $0.id,
                    localURL: $0.localURL,
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    // Preserve the per-track lyric draft so it flows into
                    // publishedTrackMetadata below.  Trim outer whitespace
                    // but keep internal newlines (lyrics need line breaks).
                    lyrics: $0.lyrics.trimmingCharacters(in: .whitespacesAndNewlines),
                    isExplicit: $0.isExplicit
                )
            }
            .filter { !$0.title.isEmpty }

        let postID = UUID()
        let coverUploadResult: MediaUploadResult
        do {
            do {
                coverUploadResult = try await backendClient.uploadMusicCoverImage(
                    postID: postID,
                    authorID: currentUser.id,
                    localURL: coverPhoto.fileURL,
                    timeoutInterval: 60
                )
            } catch {
                let preparedCoverURL = try MediaStorage.preparePodcastCoverImage(from: coverPhoto.fileURL)
                defer { try? FileManager.default.removeItem(at: preparedCoverURL) }
                coverUploadResult = try await backendClient.uploadMusicCoverImage(
                    postID: postID,
                    authorID: currentUser.id,
                    localURL: preparedCoverURL,
                    timeoutInterval: 60
                )
            }
        } catch {
            let details = (error as? LocalizedError)?.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let details, !details.isEmpty {
                moderationErrorMessage = "Could not upload music cover image. \(details)"
            } else {
                moderationErrorMessage = "Could not upload music cover image. Please try again."
            }
            return false
        }

        let normalizedCoverRef = coverUploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCoverRef.isEmpty else {
            moderationErrorMessage = "Could not attach music cover image."
            return false
        }

        var loopVideoURL: URL?
        if let loopVideo {
            do {
                let loopUploadResult = try await backendClient.uploadMusicLoopVideo(
                    postID: postID,
                    authorID: currentUser.id,
                    localURL: loopVideo.url,
                    timeoutInterval: 60
                )
                let normalizedLoopRef = loopUploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedLoopRef.isEmpty, let parsed = URL(string: normalizedLoopRef) {
                    loopVideoURL = parsed
                }
            } catch {
                moderationErrorMessage = "Could not upload music loop video. Please try again."
                return false
            }
        }

        var publishedTrackMetadata: [MusicTrackMetadata] = []
        if let firstTrack = normalizedTracks.first {
            // Track 1's audio is the main post asset; its audioURL in metadata is nil
            // (the player falls back to the post's primary asset URL at playback time).
            // Capture duration from the local file before upload so the
            // release-metadata footer can show the total runtime.
            let firstTrackDuration = await Self.readAudioDurationSeconds(from: firstTrack.localURL)
            publishedTrackMetadata.append(
                MusicTrackMetadata(
                    id: firstTrack.id,
                    title: firstTrack.title,
                    audioURL: nil,
                    durationSeconds: firstTrackDuration,
                    lyrics: firstTrack.lyrics.isEmpty ? nil : firstTrack.lyrics,
                    isExplicit: firstTrack.isExplicit,
                    collaboratorCredits: firstTrack.collaboratorCredits
                )
            )
            if normalizedTracks.count > 1 {
                for (index, track) in normalizedTracks.dropFirst().enumerated() {
                    let trackNumber = index + 2
                    if let localURL = track.localURL {
                        // Track has an audio file — capture its duration BEFORE
                        // uploading (after upload the local file may be cleaned
                        // up, plus the AVAsset on the CDN URL would require an
                        // extra round-trip to inspect).
                        let trackDuration = await Self.readAudioDurationSeconds(from: localURL)
                        do {
                            let uploadResult = try await backendClient.uploadMusicTrack(
                                postID: postID,
                                authorID: currentUser.id,
                                localURL: localURL,
                                trackNumber: trackNumber,
                                timeoutInterval: 60
                            )
                            let normalizedTrackRef = uploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !normalizedTrackRef.isEmpty, let trackURL = URL(string: normalizedTrackRef) else {
                                moderationErrorMessage = "Could not attach music track \(trackNumber)."
                                return false
                            }
                            publishedTrackMetadata.append(
                                MusicTrackMetadata(
                                    id: track.id,
                                    title: track.title,
                                    audioURL: trackURL,
                                    durationSeconds: trackDuration,
                                    lyrics: track.lyrics.isEmpty ? nil : track.lyrics,
                                    isExplicit: track.isExplicit,
                                    collaboratorCredits: track.collaboratorCredits
                                )
                            )
                        } catch {
                            moderationErrorMessage = "Could not upload music track \(trackNumber). Please try again."
                            return false
                        }
                    } else {
                        // Placeholder track — no audio yet. Lyrics still
                        // persist (the artist may have written them ahead
                        // of attaching the audio file).  Explicit flag
                        // also persists so the badge appears the moment
                        // the audio file is attached later.
                        publishedTrackMetadata.append(
                            MusicTrackMetadata(
                                id: track.id,
                                title: track.title,
                                audioURL: nil,
                                lyrics: track.lyrics.isEmpty ? nil : track.lyrics,
                                isExplicit: track.isExplicit,
                                collaboratorCredits: track.collaboratorCredits
                            )
                        )
                    }
                }
            }
        }

        let musicCaption = FeedPost.musicCaption(
            from: trimmedCaption,
            loopVideoURL: loopVideoURL,
            releaseType: releaseType,
            tracks: publishedTrackMetadata,
            releaseDate: releaseDate,
            recordLabel: recordLabel,
            genre: genre,
            linerNotes: linerNotes
        )
        return publish(
            media: media,
            caption: musicCaption,
            locationCity: locationCity,
            websiteURL: nil,
            postID: postID,
            coverImageRef: normalizedCoverRef,
            coverProvider: coverUploadResult.provider,
            coverBucket: coverUploadResult.bucket,
            coverObjectKey: coverUploadResult.objectKey,
            backendCompletion: backendCompletion
        )
    }

    private func liveSessionState(from backendSession: BackendLiveStreamSession) -> LiveStreamSessionState {
        let mode: LiveStreamMode = (backendSession.mode == .obs) ? .obs : .mobile
        return LiveStreamSessionState(
            id: backendSession.id,
            ownerUserID: backendSession.ownerUserID,
            mode: mode,
            title: backendSession.title,
            description: backendSession.description,
            tipGoal: backendSession.tipGoal,
            streamKey: backendSession.streamKey,
            ingestURL: backendSession.ingestURL,
            playbackURL: backendSession.playbackURL,
            iframePlaybackURL: backendSession.iframePlaybackURL,
            status: backendSession.status,
            startedAt: backendSession.startedAt,
            endedAt: backendSession.endedAt,
            viewerPassword: backendSession.viewerPassword,
            hasViewerPassword: backendSession.hasViewerPassword
        )
    }

    private func livePlaceholderVideoRef(for sessionID: UUID) -> String {
        "scrolls-live-placeholder://\(sessionID.uuidString.lowercased())"
    }

    private func isLivePlaceholderMoment(_ moment: Moment) -> Bool {
        moment.videoRef.hasPrefix("scrolls-live-placeholder://")
    }

    private func applyActiveLiveSessionToMoments(_ session: LiveStreamSessionState?) {
        let sessionPlayback = session?.playbackURL.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let activeSession: LiveStreamSessionState? = {
            guard let session, session.isActive, !sessionPlayback.isEmpty else { return nil }
            return session
        }()

        let liveBroadcast: Moment.LiveBroadcast? = {
            guard let activeSession else { return nil }
            return Moment.LiveBroadcast(
                id: activeSession.id,
                ownerUserID: activeSession.ownerUserID,
                playbackURL: sessionPlayback,
                iframePlaybackURL: activeSession.iframePlaybackURL,
                title: activeSession.title,
                tipGoal: activeSession.tipGoal,
                startedAt: activeSession.startedAt,
                mode: activeSession.mode == .obs ? .obs : .mobile,
                viewerPassword: activeSession.viewerPassword,
                hasViewerPassword: activeSession.hasViewerPassword
            )
        }()

        var updatedMoments = moments.map { moment in
            guard moment.userID == currentUser.id else { return moment }
            return Moment(
                id: moment.id,
                userID: moment.userID,
                username: moment.username,
                displayName: moment.displayName,
                avatarRef: moment.avatarRef,
                videoRef: moment.videoRef,
                mediaType: moment.mediaType,
                sourceApp: moment.sourceApp,
                circleMomentID: moment.circleMomentID,
                createdAt: moment.createdAt,
                expiresAt: moment.expiresAt,
                liveBroadcast: liveBroadcast,
                viewCount: moment.viewCount,
                viewedBy: moment.viewedBy,
                hasViewed: moment.hasViewed
            )
        }

        if let activeSession, let liveBroadcast {
            let hasCurrentUserMoment = updatedMoments.contains { $0.userID == currentUser.id }
            if !hasCurrentUserMoment {
                let placeholderMoment = Moment(
                    id: activeSession.id,
                    userID: currentUser.id,
                    username: currentUser.username,
                    displayName: currentUser.displayName,
                    avatarRef: currentUser.avatarRef,
                    videoRef: livePlaceholderVideoRef(for: activeSession.id),
                    mediaType: .video,
                    sourceApp: .scrolls,
                    createdAt: activeSession.startedAt,
                    expiresAt: activeSession.startedAt.addingTimeInterval(60 * 60 * 24),
                    liveBroadcast: liveBroadcast
                )
                updatedMoments.insert(placeholderMoment, at: 0)
            }
        } else {
            updatedMoments.removeAll { moment in
                moment.userID == currentUser.id && isLivePlaceholderMoment(moment)
            }
        }

        moments = updatedMoments.sorted { $0.createdAt > $1.createdAt }
    }


    private func resetLiveStartDebugTimeline(for mode: LiveStreamMode) {
        let now = Date()
        liveStartDebugTimeline = LiveStartDebugStep.allCases.map { step in
            let isPublisherStep = (step == .publisherPrepare || step == .publisherConnect || step == .publisherPublishing)
            let status: LiveStartDebugStatus = (mode == .obs && isPublisherStep) ? .skipped : .pending
            let detail = status == .skipped ? "Skipped for OBS mode" : "Waiting"
            return LiveStartDebugEntry(step: step, status: status, detail: detail, updatedAt: now)
        }
    }

    private func updateLiveStartDebug(
        _ step: LiveStartDebugStep,
        status: LiveStartDebugStatus,
        detail: String
    ) {
        let now = Date()
        if let index = liveStartDebugTimeline.firstIndex(where: { $0.step == step }) {
            liveStartDebugTimeline[index].status = status
            liveStartDebugTimeline[index].detail = detail
            liveStartDebugTimeline[index].updatedAt = now
        } else {
            liveStartDebugTimeline.append(LiveStartDebugEntry(step: step, status: status, detail: detail, updatedAt: now))
            liveStartDebugTimeline.sort { lhs, rhs in
                guard let l = LiveStartDebugStep.allCases.firstIndex(of: lhs.step),
                      let r = LiveStartDebugStep.allCases.firstIndex(of: rhs.step) else {
                    return lhs.step.rawValue < rhs.step.rawValue
                }
                return l < r
            }
        }
    }

    private func markPhonePublisherStepsSkipped(reason: String) {
        updateLiveStartDebug(.publisherPrepare, status: .skipped, detail: reason)
        updateLiveStartDebug(.publisherConnect, status: .skipped, detail: reason)
        updateLiveStartDebug(.publisherPublishing, status: .skipped, detail: reason)
    }

    @discardableResult
    func refreshActiveLiveStreamSession(managePublisher: Bool = true) async -> LiveStreamSessionState? {
        do {
            let session = try await backendClient.fetchLiveStreamSession(userID: currentUser.id)
            let mapped = session.map(liveSessionState(from:))
            activeLiveStreamSession = mapped
            applyActiveLiveSessionToMoments(mapped)
            if managePublisher {
                if let mapped, mapped.mode == .mobile, mapped.isActive {
                    _ = await ensurePhoneLivePublisher(for: mapped)
                } else {
                    await stopPhoneLivePublisher()
                    if let mapped, mapped.mode == .obs, mapped.isActive {
                        markPhonePublisherStepsSkipped(reason: "OBS mode uses external encoder")
                        updateLiveStartDebug(.ready, status: .succeeded, detail: "OBS live session active")
                    }
                }
            }
            if managePublisher, mapped != nil {
                liveStreamErrorMessage = nil
            }
            return mapped
        } catch {
            if managePublisher {
                liveStreamErrorMessage = "Couldn't refresh live session right now."
            }
            return nil
        }
    }


    /// Fetches an active live session for any broadcaster without mutating local owner state.
    @discardableResult
    func fetchLiveStreamSession(for userID: UUID) async -> LiveStreamSessionState? {
        do {
            let session = try await backendClient.fetchViewerLiveStreamSession(ownerUserID: userID)
            return session.map(liveSessionState(from:))
        } catch {
            return nil
        }
    }

    /// Sends the viewer's password guess to the backend for server-side
    /// verification.  Returns `true` when the password is accepted.
    /// Local plaintext comparison is only allowed for the broadcaster's own
    /// session; viewers must always be verified by the backend.
    func verifyViewerPassword(ownerUserID: UUID, enteredPassword: String, knownPassword: String?) async -> Bool {
        let trimmed = enteredPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if currentUser.id == ownerUserID,
           let known = knownPassword?.trimmingCharacters(in: .whitespacesAndNewlines),
           !known.isEmpty {
            return trimmed == known
        }
        do {
            return try await backendClient.verifyLiveViewerPassword(ownerUserID: ownerUserID, password: trimmed)
        } catch {
            return false
        }
    }

    @discardableResult
    func startLiveStream(mode: LiveStreamMode, title: String?, description: String?, tipGoal: Decimal? = nil, viewerPassword: String? = nil) async -> Bool {
        resetLiveStartDebugTimeline(for: mode)
        updateLiveStartDebug(.sessionRequest, status: .running, detail: "Requesting live session from backend")

        do {
            let session = try await backendClient.createLiveStreamSession(
                mode: mode.backendMode,
                title: title,
                description: description,
                tipGoal: tipGoal,
                viewerPassword: viewerPassword,
                userID: currentUser.id
            )
            updateLiveStartDebug(.sessionRequest, status: .succeeded, detail: "Backend accepted live start")
            updateLiveStartDebug(.sessionCreated, status: .succeeded, detail: "Session \(session.id.uuidString.lowercased()) created")
            updateLiveStartDebug(.sessionMapped, status: .running, detail: "Applying live session locally")

            let mapped = liveSessionState(from: session)
            activeLiveStreamSession = mapped
            applyActiveLiveSessionToMoments(mapped)
            updateLiveStartDebug(.sessionMapped, status: .succeeded, detail: "Session is active in app state")
            updateLiveStartDebug(.ready, status: .running, detail: "Session active, starting publisher")

            if mode == .mobile {
                let publishStarted = await ensurePhoneLivePublisher(for: mapped)
                if publishStarted {
                    updateLiveStartDebug(.ready, status: .succeeded, detail: "Live session + phone publisher connected")
                } else {
                    updateLiveStartDebug(.ready, status: .failed, detail: "Phone publisher failed; ending inactive live session")
                    try? await backendClient.endLiveStreamSession(sessionID: mapped.id, userID: currentUser.id)
                    activeLiveStreamSession = nil
                    applyActiveLiveSessionToMoments(nil)
                    await stopPhoneLivePublisher()
                    liveStreamErrorMessage = "Could not start the phone live publisher."
                    return false
                }
            } else {
                await stopPhoneLivePublisher()
                markPhonePublisherStepsSkipped(reason: "OBS mode uses external encoder")
                // OBS streams deliver their own encoded audio over RTMP/HLS.
                // Ensure the phone microphone is not captured by resetting the
                // audio session to playback-only now that the phone publisher
                // is stopped.  (stopPhoneLivePublisher → LivePhoneBroadcaster
                // already does this, but calling it here makes the intent
                // explicit and guards against any path that bypasses the
                // broadcaster's teardown.)
                configureAudioSessionForOBSPlayback()
                updateLiveStartDebug(.ready, status: .succeeded, detail: "OBS credentials ready")
            }

            liveStreamErrorMessage = nil
            return true
        } catch {
            updateLiveStartDebug(.sessionRequest, status: .failed, detail: error.localizedDescription)
            updateLiveStartDebug(.ready, status: .failed, detail: "Live startup failed before session became active")
            liveStreamErrorMessage = "Couldn't start live stream right now."
            return false
        }
    }

    @discardableResult
    func endLiveStream(sessionID: UUID? = nil) async -> Bool {
        do {
            let targetID = sessionID ?? activeLiveStreamSession?.id
            try await backendClient.endLiveStreamSession(sessionID: targetID, userID: currentUser.id)
            activeLiveStreamSession = nil
            if let targetID {
                liveStreamCommentsBySessionID[targetID] = nil
                liveStreamKickedSessionIDs.remove(targetID)
            }
            applyActiveLiveSessionToMoments(nil)
            await stopPhoneLivePublisher()
            liveStreamErrorMessage = nil
            return true
        } catch {
            liveStreamErrorMessage = "Couldn't end live stream right now."
            return false
        }
    }

    @discardableResult
    func rotateLiveStreamKey(sessionID: UUID? = nil) async -> Bool {
        do {
            let targetID = sessionID ?? activeLiveStreamSession?.id
            let session = try await backendClient.rotateLiveStreamSessionKey(sessionID: targetID, userID: currentUser.id)
            let mapped = liveSessionState(from: session)
            activeLiveStreamSession = mapped
            applyActiveLiveSessionToMoments(mapped)

            if mapped.mode == .mobile {
                updateLiveStartDebug(.publisherPrepare, status: .running, detail: "Restarting publisher after stream key rotation")
                let publishStarted = await ensurePhoneLivePublisher(for: mapped)
                if !publishStarted {
                    updateLiveStartDebug(.ready, status: .failed, detail: "Rotated key, but publisher reconnect failed")
                    return false
                }
            } else {
                await stopPhoneLivePublisher()
                markPhonePublisherStepsSkipped(reason: "OBS mode uses external encoder")
            }

            liveStreamErrorMessage = nil
            return true
        } catch {
            liveStreamErrorMessage = "Couldn't rotate your stream key right now."
            return false
        }
    }


    func liveStreamComments(for sessionID: UUID?) -> [LiveStreamCommentState] {
        guard let sessionID else { return [] }
        return liveStreamCommentsBySessionID[sessionID] ?? []
    }

    func wasRemovedFromLiveStream(sessionID: UUID?) -> Bool {
        guard let sessionID else { return false }
        return liveStreamKickedSessionIDs.contains(sessionID)
    }

    private func markRemovedFromLiveStream(sessionID: UUID, message: String?) {
        liveStreamKickedSessionIDs.insert(sessionID)
        let normalized = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        liveStreamErrorMessage = (normalized?.isEmpty == false) ? normalized : "You were removed from this live stream."
        liveStreamCommentsBySessionID[sessionID] = []
    }

    func clearRemovedFromLiveStream(sessionID: UUID?) {
        guard let sessionID else { return }
        liveStreamKickedSessionIDs.remove(sessionID)
    }

    @discardableResult
    func refreshLiveStreamComments(sessionID: UUID, limit: Int = 40) async -> [LiveStreamCommentState] {
        if liveStreamCommentFetchInFlightSessionIDs.contains(sessionID) {
            return liveStreamCommentsBySessionID[sessionID] ?? []
        }
        liveStreamCommentFetchInFlightSessionIDs.insert(sessionID)
        defer { liveStreamCommentFetchInFlightSessionIDs.remove(sessionID) }

        do {
            let remote = try await backendClient.fetchLiveStreamComments(sessionID: sessionID, limit: limit)
            let mapped = remote.map { backendComment in
                let author = backendComment.author.asUserProfile
                registerProfile(author, writeVersion: backendComment.author.writeVersion)
                return LiveStreamCommentState(
                    id: backendComment.id,
                    sessionID: backendComment.sessionID,
                    user: author,
                    body: backendComment.body,
                    createdAt: backendComment.createdAt
                )
            }
            liveStreamCommentsBySessionID[sessionID] = mapped.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            liveStreamKickedSessionIDs.remove(sessionID)
            return liveStreamCommentsBySessionID[sessionID] ?? []
        } catch {
            if case let BackendClientError.httpStatus(code, message) = error, code == 403 {
                markRemovedFromLiveStream(sessionID: sessionID, message: message)
            }
            return liveStreamCommentsBySessionID[sessionID] ?? []
        }
    }

    @discardableResult
    func sendLiveJoinPresenceComment(sessionID: UUID) async -> Bool {
        await sendLiveStreamComment("has joined the live", sessionID: sessionID)
    }
    
    func sendLiveTipEventComment(
        amountDisplay: String,
        sessionID: UUID,
        message: String? = nil
    ) async -> Bool {
        let normalizedAmount = amountDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAmount.isEmpty else { return false }
        // A tip attempt remains hidden until the streamer confirms receipt.
        // The backend promotes this pending marker to a confirmed marker or
        // deletes it when the streamer answers No.
        var body = "__scrolls_tip_pending__:\(normalizedAmount)"
        if let message {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMessage.isEmpty,
               let encoded = trimmedMessage.data(using: .utf8)?.base64EncodedString() {
                body += "|msg:\(encoded)"
            }
        }
        return await sendLiveStreamComment(body, sessionID: sessionID)
    }

    @discardableResult
    func resolvePendingLiveTip(
        _ comment: LiveStreamCommentState,
        accepted: Bool,
        sessionID: UUID
    ) async -> Bool {
        do {
            let remote = try await backendClient.resolvePendingLiveTip(
                sessionID: sessionID,
                commentID: comment.id,
                accepted: accepted,
                ownerUserID: currentUser.id
            )
            var existing = liveStreamCommentsBySessionID[sessionID] ?? []
            existing.removeAll { $0.id == comment.id }
            if let remote {
                let author = remote.author.asUserProfile
                registerProfile(author, writeVersion: remote.author.writeVersion)
                existing.append(
                    LiveStreamCommentState(
                        id: remote.id,
                        sessionID: remote.sessionID,
                        user: author,
                        body: remote.body,
                        createdAt: remote.createdAt
                    )
                )
            }
            existing.sort { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            liveStreamCommentsBySessionID[sessionID] = existing
            liveStreamErrorMessage = nil
            return true
        } catch {
            liveStreamErrorMessage = accepted
                ? "Couldn't confirm the tip right now."
                : "Couldn't reject the tip right now."
            return false
        }
    }
    
    func sendLiveStreamComment(_ text: String, sessionID: UUID) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard validateAllowedText(trimmed, context: "live comments") else { return false }

        do {
            let remote = try await backendClient.createLiveStreamComment(
                sessionID: sessionID,
                body: trimmed,
                authorID: currentUser.id
            )
            let author = remote.author.asUserProfile
            registerProfile(author, writeVersion: remote.author.writeVersion)
            let mapped = LiveStreamCommentState(
                id: remote.id,
                sessionID: remote.sessionID,
                user: author,
                body: remote.body,
                createdAt: remote.createdAt
            )
            var existing = liveStreamCommentsBySessionID[sessionID] ?? []
            if !existing.contains(where: { $0.id == mapped.id }) {
                existing.append(mapped)
                existing.sort { lhs, rhs in
                    if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                liveStreamCommentsBySessionID[sessionID] = existing
            }
            return true
        } catch {
            if case let BackendClientError.httpStatus(code, message) = error, code == 403 {
                markRemovedFromLiveStream(sessionID: sessionID, message: message)
            } else {
                liveStreamErrorMessage = "Couldn't send live comment right now."
            }
            return false
        }
    }
    @discardableResult
    func kickUserFromLiveStream(targetUserID: UUID, sessionID: UUID) async -> Bool {
        guard let session = activeLiveStreamSession,
              session.id == sessionID,
              session.ownerUserID == currentUser.id,
              session.isActive else {
            liveStreamErrorMessage = "Only the live streamer can remove viewers."
            return false
        }

        guard targetUserID != currentUser.id else {
            liveStreamErrorMessage = "You cannot remove yourself from your own live stream."
            return false
        }

        do {
            try await backendClient.kickLiveStreamViewer(
                sessionID: sessionID,
                targetUserID: targetUserID,
                ownerUserID: currentUser.id
            )
            if var existing = liveStreamCommentsBySessionID[sessionID] {
                existing.removeAll { $0.user.id == targetUserID }
                liveStreamCommentsBySessionID[sessionID] = existing
            }
            liveStreamErrorMessage = nil
            return true
        } catch {
            if case let BackendClientError.httpStatus(_, message) = error,
               let message,
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                liveStreamErrorMessage = message
            } else {
                liveStreamErrorMessage = "Could not remove this viewer right now."
            }
            return false
        }
    }
    private func ensurePhoneLivePublisher(for session: LiveStreamSessionState) async -> Bool {
        guard session.mode == .mobile, session.isActive else {
            await stopPhoneLivePublisher()
            markPhonePublisherStepsSkipped(reason: "No active phone live session")
            return true
        }

        let ingestHost = URL(string: session.ingestURL)?.host ?? "unknown"
        updateLiveStartDebug(.publisherPrepare, status: .running, detail: "Preparing phone capture pipeline")
        updateLiveStartDebug(.publisherConnect, status: .running, detail: "Connecting to ingest host \(ingestHost)")

        do {
            liveBroadcastDebugDetail = "Connecting publisher to ingest host \(ingestHost)"
            try await livePhoneBroadcaster.startPublishing(ingestURL: session.ingestURL)
            if livePhoneBroadcaster.isPublishing {
                updateLiveStartDebug(.publisherPrepare, status: .succeeded, detail: "Camera/audio pipeline ready")
                updateLiveStartDebug(.publisherConnect, status: .succeeded, detail: "Connected to ingest host \(ingestHost)")
                updateLiveStartDebug(.publisherPublishing, status: .succeeded, detail: "RTMP stream is publishing")
                startLiveSessionHeartbeat(for: session)
                return true
            }
            updateLiveStartDebug(.publisherPublishing, status: .failed, detail: "Publisher returned without active stream")
            return false
        } catch {
            liveBroadcastDebugState = "failed"
            liveBroadcastDebugDetail = "Publisher failed to connect ingest: \(error.localizedDescription)"
            updateLiveStartDebug(.publisherPrepare, status: .failed, detail: error.localizedDescription)
            updateLiveStartDebug(.publisherConnect, status: .failed, detail: "Failed to connect to ingest host \(ingestHost)")
            updateLiveStartDebug(.publisherPublishing, status: .failed, detail: "RTMP did not start")
            updateLiveStartDebug(.ready, status: .failed, detail: "Session active, but broadcaster failed")
            return false
        }
    }

    private func stopPhoneLivePublisher() async {
        isStoppingPhoneLivePublisherIntentionally = true
        defer { isStoppingPhoneLivePublisherIntentionally = false }
        // Cancel any pending retry before stopping so we do not reconnect after an intentional stop.
        broadcasterRetryTask?.cancel()
        broadcasterRetryTask = nil
        liveHeartbeatTask?.cancel()
        liveHeartbeatTask = nil
        broadcasterRetryCount = 0
        await livePhoneBroadcaster.stopPublishing()
        // isPhoneLiveBroadcasting is driven reactively; explicit reset handled by broadcaster -> .idle
    }

    /// Configures the audio session for OBS/playback-only mode.
    /// Called when an OBS stream starts so the phone microphone is never
    /// captured alongside the externally-encoded OBS audio.
    private func configureAudioSessionForOBSPlayback() {
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowAirPlay]
        )
        try? audioSession.setActive(true)
        #endif
    }

    private func startLiveSessionHeartbeat(for session: LiveStreamSessionState) {
        liveHeartbeatTask?.cancel()
        liveHeartbeatTask = nil

        guard session.mode == .mobile, session.isActive else { return }
        let sessionID = session.id

        liveHeartbeatTask = Task { @MainActor [weak self] in
            var consecutiveFailures = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard let active = activeLiveStreamSession, active.id == sessionID, active.isActive, active.mode == .mobile else { return }

                do {
                    if let remote = try await backendClient.sendLiveStreamHeartbeat(sessionID: sessionID, userID: currentUser.id) {
                        consecutiveFailures = 0
                        let mapped = liveSessionState(from: remote)
                        activeLiveStreamSession = mapped
                        applyActiveLiveSessionToMoments(mapped)
                    } else {
                        activeLiveStreamSession = nil
                        applyActiveLiveSessionToMoments(nil)
                        liveStreamErrorMessage = "Live session ended on the server."
                        await stopPhoneLivePublisher()
                        return
                    }
                } catch {
                    consecutiveFailures += 1
                    let heartbeatError = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    liveBroadcastDebugDetail = heartbeatError.isEmpty
                        ? "Live heartbeat failed (attempt \(consecutiveFailures)/3)"
                        : "Live heartbeat failed (attempt \(consecutiveFailures)/3): \(heartbeatError)"
                    if consecutiveFailures >= 3 {
                        liveStreamErrorMessage = "Live connection lost. Start a new live session when your network is back."
                        await stopPhoneLivePublisher()
                        return
                    }
                }
            }
        }
    }

    /// Subscribes to the broadcaster's published state so `isPhoneLiveBroadcasting`
    /// stays accurate even when RTMP drops mid-stream without any app-side trigger.
    /// When the broadcaster enters `.failed` it schedules an exponential-backoff
    /// reconnect — up to 5 attempts — so transient network drops self-heal.
    private func observeBroadcasterState() {
        broadcasterStateCancellable = livePhoneBroadcaster.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                switch newState {
                case .publishing:
                    isPhoneLiveBroadcasting = true
                    liveBroadcastDebugState = "publishing"
                    liveBroadcastDebugDetail = "RTMP publish connected"
                    updateLiveStartDebug(.publisherConnect, status: .succeeded, detail: "Ingest socket connected")
                    updateLiveStartDebug(.publisherPublishing, status: .succeeded, detail: "RTMP publish connected")
                    updateLiveStartDebug(.ready, status: .succeeded, detail: "Live stream is publishing")
                    // Connected — reset the retry counter so the next drop gets fresh attempts.
                    broadcasterRetryCount = 0
                    broadcasterRetryTask?.cancel()
                    broadcasterRetryTask = nil
                case .idle:
                    isPhoneLiveBroadcasting = false
                    liveBroadcastEncoderDebugLine = "encoder=idle"
                    liveHeartbeatTask?.cancel()
                    liveHeartbeatTask = nil
                    if let session = activeLiveStreamSession,
                       session.isActive,
                       session.mode == .mobile,
                       !isStoppingPhoneLivePublisherIntentionally {
                        liveBroadcastDebugState = "failed"
                        liveBroadcastDebugDetail = "Publisher stopped while live session is active; reconnecting"
                        updateLiveStartDebug(.publisherPublishing, status: .failed, detail: "Publisher unexpectedly went idle")
                        updateLiveStartDebug(.publisherConnect, status: .running, detail: "Scheduling reconnect after idle publisher")
                        scheduleBroadcasterRetryIfNeeded()
                        return
                    }
                    liveBroadcastDebugState = "idle"
                    liveBroadcastDebugDetail = "Publisher idle"
                    broadcasterRetryCount = 0
                    broadcasterRetryTask?.cancel()
                    broadcasterRetryTask = nil
                case .failed(let message):
                    isPhoneLiveBroadcasting = false
                    liveBroadcastDebugState = "failed"
                    liveBroadcastDebugDetail = message
                    updateLiveStartDebug(.publisherPublishing, status: .failed, detail: message)
                    updateLiveStartDebug(.ready, status: .failed, detail: "Publisher disconnected")
                    scheduleBroadcasterRetryIfNeeded()
                case .connecting:
                    liveBroadcastDebugState = "connecting"
                    liveBroadcastDebugDetail = "Connecting RTMP publish session"
                    updateLiveStartDebug(.publisherConnect, status: .running, detail: "Opening RTMP connection")
                }
            }

        broadcasterEncoderCancellable = livePhoneBroadcaster.$encoderDiagnostics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] diagnostics in
                self?.liveBroadcastEncoderDebugLine = diagnostics.debugLine
            }
    }

    /// Schedules an RTMP reconnect attempt with exponential backoff (3s → 6s → 12s → 24s → 48s).
    /// Cancels automatically once the session ends or publishing resumes.
    private func scheduleBroadcasterRetryIfNeeded() {
        let maxRetries = 5
        guard broadcasterRetryCount < maxRetries else {
            liveHeartbeatTask?.cancel()
            liveHeartbeatTask = nil
            if let sessionID = activeLiveStreamSession?.id {
                Task { @MainActor [weak self] in
                    _ = await self?.endLiveStream(sessionID: sessionID)
                }
            }
            liveBroadcastDebugDetail = "RTMP failed after \(maxRetries) reconnect attempts"
            updateLiveStartDebug(.publisherConnect, status: .failed, detail: "Reconnect attempts exhausted")
            updateLiveStartDebug(.ready, status: .failed, detail: "Live stream failed after \(maxRetries) retries")
            return
        }

        broadcasterRetryTask?.cancel()
        let attempt = broadcasterRetryCount
        let delaySecs: UInt64 = UInt64(3 * (1 << attempt))  // 3, 6, 12, 24, 48
        liveBroadcastDebugDetail = "RTMP disconnected — reconnecting in \(delaySecs)s (attempt \(attempt + 1)/\(maxRetries))"
        updateLiveStartDebug(.publisherConnect, status: .running, detail: "Retry in \(delaySecs)s (attempt \(attempt + 1)/\(maxRetries))")

        broadcasterRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delaySecs * 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            guard let session = activeLiveStreamSession, session.isActive, session.mode == .mobile else { return }
            broadcasterRetryCount += 1
            liveBroadcastDebugDetail = "Retrying RTMP connect (attempt \(self.broadcasterRetryCount)/\(maxRetries))…"
            updateLiveStartDebug(.publisherConnect, status: .running, detail: "Retrying ingest connect (attempt \(self.broadcasterRetryCount)/\(maxRetries))")
            _ = await ensurePhoneLivePublisher(for: session)
        }
    }

    func publishArticle(
        headline: String,
        blocks: [ScrollArticlePayload.Block],
        coverPhoto: PhotoPreview? = nil,
        locationCity: String? = nil
    ) async -> Bool {
        let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeadline.isEmpty else {
            moderationErrorMessage = "Articles need a headline before posting."
            return false
        }
        guard currentUser.showsBlueCheckBadge || currentUser.isGoldTier || currentUser.isFounder else {
            moderationErrorMessage = "Write Article is available for blue check and higher."
            return false
        }
        guard validateAllowedText(trimmedHeadline, context: "article headline") else { return false }

        let normalizedBlocks = blocks.compactMap { block -> ScrollArticlePayload.Block? in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ScrollArticlePayload.Block(id: block.id, kind: block.kind, text: trimmed)
        }
        guard !normalizedBlocks.isEmpty else {
            moderationErrorMessage = "Articles need content blocks before posting."
            return false
        }

        for block in normalizedBlocks {
            let context: String
            switch block.kind {
            case .paragraph:
                context = "article paragraph"
            case .subheadline:
                context = "article subheadline"
            case .sectionHeading:
                context = "article section heading"
            }
            guard validateAllowedText(block.text, context: context) else { return false }
        }

        guard let coverPhoto else {
            moderationErrorMessage = "Articles need a cover image before posting."
            return false
        }

        var coverImageRef: String?
        var coverImageAspectRatio: Double?
        do {
            let uploaded = try await backendClient.uploadArticleCoverImage(
                articleID: UUID(),
                authorID: currentUser.id,
                localURL: coverPhoto.fileURL
            )
            coverImageRef = uploaded.legacyRef
            coverImageAspectRatio = max(Double(coverPhoto.aspectRatio), 0.1)
        } catch {
            moderationErrorMessage = "Could not upload article cover image. Please try again."
            return false
        }

        guard let encodedArticle = ScrollArticlePayload.encodeToText(
            headline: trimmedHeadline,
            blocks: normalizedBlocks,
            coverImageRef: coverImageRef,
            coverImageAspectRatio: coverImageAspectRatio
        ) else {
            moderationErrorMessage = "Could not format this article. Please try again."
            return false
        }

        let articleCaption = FeedPost.articleCaption(from: trimmedHeadline)
        return publish(
            media: .text(encodedArticle, fontStyle: .original),
            caption: articleCaption,
            locationCity: locationCity,
            websiteURL: nil
        )
    }


    func publish(text: String, locationCity: String? = nil, fontStyle: ScrollPostFontStyle = .original) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard recordSpamAction(
            key: "publish:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.postLimit,
            window: Self.SpamProtectionMode.postWindow,
            blockedMessage: "You're posting too fast. Please wait a moment."
        ) else { return false }
        guard recordSpamText(
            key: "publish-text:\(currentUser.id.uuidString)",
            text: trimmed,
            limit: Self.SpamProtectionMode.duplicateTextLimit,
            window: Self.SpamProtectionMode.duplicateTextWindow,
            blockedMessage: "You're repeating the same text Scroll too quickly."
        ) else { return false }
        guard validateAllowedText(trimmed, context: "text Scrolls") else { return false }
        let resolvedFontStyle = resolvedFontStyleForCurrentUser(fontStyle)
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        let post = FeedPost(
            id: UUID(),
            user: currentUser,
            caption: nil,
            websiteURL: nil,
            locationCity: resolvedLocation,
            timestamp: Date(),
            mediaPreview: .text(trimmed, fontStyle: resolvedFontStyle),
            comments: [],
            rescrollOrigin: nil
        )
        return publish(post: post, mentionText: trimmed, mentionContext: "a text Scroll")
    }

    @discardableResult
    func saveDraft(media: MediaPreview, caption: String?, locationCity: String?, replacingDraftID: UUID? = nil) -> Bool {
        guard validateAllowedText(caption, context: "captions") else { return false }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        if let replacingDraftID {
            postDrafts.removeAll { $0.id == replacingDraftID }
        }
        let draft = PostDraft(
            id: UUID(),
            payload: .media(media),
            caption: caption?.trimmingCharacters(in: .whitespacesAndNewlines),
            locationCity: resolvedLocation,
            textFontStyle: nil,
            ownerUserID: currentUser.id,
            createdAt: Date(),
            scheduledAt: nil
        )
        postDrafts.insert(draft, at: 0)
        saveState()
        return true
    }

    @discardableResult
    func saveDraft(text: String, locationCity: String?, textFontStyle: ScrollPostFontStyle = .original, replacingDraftID: UUID? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard validateAllowedText(trimmed, context: "text Scrolls") else { return false }
        let resolvedFontStyle = resolvedFontStyleForCurrentUser(textFontStyle)
        if let replacingDraftID {
            postDrafts.removeAll { $0.id == replacingDraftID }
        }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        let draft = PostDraft(
            id: UUID(),
            payload: .text(trimmed),
            caption: nil,
            locationCity: resolvedLocation,
            textFontStyle: resolvedFontStyle,
            ownerUserID: currentUser.id,
            createdAt: Date(),
            scheduledAt: nil
        )
        postDrafts.insert(draft, at: 0)
        saveState()
        return true
    }

    @discardableResult
    func saveArticleDraft(
        headline: String,
        blocks: [ScrollArticlePayload.Block],
        coverPhoto: PhotoPreview?,
        locationCity: String?,
        replacingDraftID: UUID? = nil
    ) -> Bool {
        let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeadline.isEmpty else { return false }
        guard validateAllowedText(trimmedHeadline, context: "article headline") else { return false }
        let normalizedBlocks = blocks.compactMap { block -> ScrollArticlePayload.Block? in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return ScrollArticlePayload.Block(id: block.id, kind: block.kind, text: trimmed)
        }
        guard !normalizedBlocks.isEmpty else { return false }
        for block in normalizedBlocks {
            let context: String
            switch block.kind {
            case .paragraph:
                context = "article paragraph"
            case .subheadline:
                context = "article subheadline"
            case .sectionHeading:
                context = "article section heading"
            }
            guard validateAllowedText(block.text, context: context) else { return false }
        }
        if let replacingDraftID {
            postDrafts.removeAll { $0.id == replacingDraftID }
        }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        let draft = PostDraft(
            id: UUID(),
            payload: .article(
                PostDraft.ArticleDraft(
                    headline: trimmedHeadline,
                    blocks: normalizedBlocks,
                    coverPhoto: coverPhoto,
                    locationCity: resolvedLocation
                )
            ),
            caption: FeedPost.articleCaption(from: trimmedHeadline),
            locationCity: resolvedLocation,
            textFontStyle: nil,
            ownerUserID: currentUser.id,
            createdAt: Date(),
            scheduledAt: nil
        )
        postDrafts.insert(draft, at: 0)
        saveState()
        return true
    }

    @discardableResult
    func scheduleDraft(media: MediaPreview, caption: String?, locationCity: String?, publishAt: Date, replacingDraftID: UUID? = nil) -> Bool {
        guard validateAllowedText(caption, context: "captions") else { return false }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        if let replacingDraftID {
            postDrafts.removeAll { $0.id == replacingDraftID }
        }
        let draft = PostDraft(
            id: UUID(),
            payload: .media(media),
            caption: caption?.trimmingCharacters(in: .whitespacesAndNewlines),
            locationCity: resolvedLocation,
            textFontStyle: nil,
            ownerUserID: currentUser.id,
            createdAt: Date(),
            scheduledAt: publishAt
        )
        postDrafts.append(draft)
        postDrafts.sort { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        saveState()
        return true
    }

    @discardableResult
    func scheduleDraft(text: String, locationCity: String?, textFontStyle: ScrollPostFontStyle = .original, publishAt: Date, replacingDraftID: UUID? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard validateAllowedText(trimmed, context: "text Scrolls") else { return false }
        let resolvedFontStyle = resolvedFontStyleForCurrentUser(textFontStyle)
        if let replacingDraftID {
            postDrafts.removeAll { $0.id == replacingDraftID }
        }
        let resolvedLocation = normalizedLocationForCurrentUser(locationCity)
        let draft = PostDraft(
            id: UUID(),
            payload: .text(trimmed),
            caption: nil,
            locationCity: resolvedLocation,
            textFontStyle: resolvedFontStyle,
            ownerUserID: currentUser.id,
            createdAt: Date(),
            scheduledAt: publishAt
        )
        postDrafts.append(draft)
        postDrafts.sort { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        saveState()
        return true
    }

    func deleteDraft(_ draft: PostDraft) {
        guard (draft.ownerUserID ?? currentUser.id) == currentUser.id else { return }
        postDrafts.removeAll { $0.id == draft.id }
        saveState()
    }

    @discardableResult
    func publishDraftNow(_ draft: PostDraft) -> Bool {
        guard (draft.ownerUserID ?? currentUser.id) == currentUser.id else { return false }
        if case .article = draft.payload {
            return false
        }
        let didPublish = publishFromDraftPayload(
            draft.payload,
            caption: draft.caption,
            locationCity: draft.locationCity,
            textFontStyle: draft.textFontStyle
        )
        if didPublish {
            postDrafts.removeAll { $0.id == draft.id }
            saveState()
        }
        return didPublish
    }

    func submitPostForAdReview(
        _ post: FeedPost,
        campaignType: BackendAdSubmission.CampaignType = .gainFollowers,
        websiteURL: String? = nil,
        durationDays: Int? = nil,
        dailyBudgetCents: Int? = nil
    ) {
        _ = post
        _ = campaignType
        _ = websiteURL
        _ = durationDays
        _ = dailyBudgetCents
        moderationErrorMessage = "Ad submissions are disabled. Founder ads publish directly in Curated Ad Feed."
    }

    func uploadFounderCuratedAd(
        media: MediaPreview,
        websiteURL: String,
        caption: String?,
        progress: ((String) -> Void)? = nil
    ) async throws {
        guard backendClient.isEnabled else {
            throw BackendClientError.requestFailed
        }
        guard canCurrentUserPublishFounderAds() else {
            throw BackendClientError.requestFailed
        }
        let cleanedURL = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedURL.isEmpty else {
            throw BackendClientError.requestFailed
        }
        switch media {
        case .video(let video):
            if video.url.isFileURL, FileManager.default.fileExists(atPath: video.url.path) {
                let bytes = (try? FileManager.default.attributesOfItem(atPath: video.url.path)[.size] as? NSNumber)?.int64Value ?? 0
                let maxBytes: Int64 = 70 * 1024 * 1024
                if bytes > maxBytes {
                    throw CuratedAdUploadError.videoTooLarge(maxMB: 70)
                }
            }
        case .photo(let photo):
            if photo.fileURL.isFileURL, FileManager.default.fileExists(atPath: photo.fileURL.path) {
                let bytes = (try? FileManager.default.attributesOfItem(atPath: photo.fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                let maxBytes: Int64 = 20 * 1024 * 1024
                if bytes > maxBytes {
                    throw CuratedAdUploadError.photoTooLarge(maxMB: 20)
                }
            }
        case .text:
            throw BackendClientError.requestFailed
        }
        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let adPost = FeedPost(
            id: UUID(),
            user: currentUser,
            caption: trimmedCaption?.isEmpty == false ? trimmedCaption : nil,
            websiteURL: cleanedURL,
            locationCity: "Global",
            timestamp: Date(),
            mediaPreview: media,
            comments: [],
            rescrollOrigin: nil
        )
        // Mark as ad-designated before publish so it never appears as a normal post.
        adSubmissionPostIDs.insert(adPost.id)
        // Optimistic local insert so composer transition matches normal posting flow.
        posts.insert(adPost, at: 0)
        if let mentionText = trimmedCaption, !mentionText.isEmpty {
            notifyMentions(in: mentionText, context: "a curated ad", objectID: adPost.id, actor: adPost.user)
        }
        if !deliveredAdPosts.contains(where: { $0.id == adPost.id }) {
            deliveredAdPosts.insert(adPost, at: 0)
        }
        if let emptySlotIndex = curatedAdSlotIDs.firstIndex(where: { $0 == nil }) {
            curatedAdSlotIDs[emptySlotIndex] = adPost.id
        } else if !curatedAdSlotIDs.isEmpty {
            curatedAdSlotIDs[0] = adPost.id
        }
        enforceCuratedAdCap()
        saveCuratedAdSlots()
        saveState()
        let adMediaLabel: String
        switch adPost.mediaPreview {
        case .photo:
            adMediaLabel = "photo"
        case .video:
            adMediaLabel = "video"
        case .text:
            adMediaLabel = "text"
        }
        updateAdDebug(
            targetID: adPost.id.uuidString,
            stage: "queued_local",
            status: "Curated ad saved locally",
            detail: "post=\(adPost.id.uuidString.prefix(8)), media=\(adMediaLabel), slots=\(curatedAdSlotIDs.compactMap { $0?.uuidString.prefix(8) }.joined(separator: ","))",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )

        progress?("Step 2/5: Added to ad catalog selection…")
        progress?("Step 3/5: Syncing upload in background…")

        Task {  [weak self] in
            guard let self else { return }
            let adTargetID = adPost.id.uuidString
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "ad_curated_post_publish",
                    debugContext: BackendWriteDebugContext(
                        domain: .ad,
                        targetID: adTargetID,
                        action: "ad_curated_post_publish"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 45
                ) { _ in
                    try await self.publishPostToBackend(
                        adPost,
                        author: adPost.user,
                        maxAttempts: 1,
                        timeoutPerAttempt: 45
                    )
                }
                await MainActor.run {
                    self.updateAdDebug(
                        targetID: adTargetID,
                        stage: "backend_acknowledged",
                        status: "Curated ad synced to backend",
                        detail: "Post publish confirmed by backend."
                    )
                }
            } catch PostPublishError.timeout(let seconds) {
                await MainActor.run {
                    self.moderationErrorMessage = CuratedAdUploadError.uploadTimedOut(seconds: seconds).errorDescription
                    self.updateAdDebug(
                        targetID: adTargetID,
                        stage: "publish_timeout_queued",
                        status: "Curated ad upload timed out; queued for retry",
                        detail: "timeout=\(Int(seconds))s",
                        error: PostPublishError.timeout(seconds: seconds)
                    )
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .adCuratedPostPublish,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: adPost.user.id,
                            postID: adPost.id,
                            authorID: adPost.user.id,
                            commentID: nil,
                            body: nil,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                }
            } catch {
                await MainActor.run {
                    self.moderationErrorMessage = "Ad was added locally, but backend sync failed. Please refresh and try posting again."
                    self.updateAdDebug(
                        targetID: adTargetID,
                        stage: "publish_failed_queued",
                        status: "Curated ad backend sync failed; queued for retry",
                        detail: "Local ad remains visible while retry queue handles backend sync.",
                        error: error
                    )
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .adCuratedPostPublish,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: adPost.user.id,
                            postID: adPost.id,
                            authorID: adPost.user.id,
                            commentID: nil,
                            body: nil,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                }
            }
            await MainActor.run {
                self.triggerPendingBackendWriteFlush(after: 0, force: true)
            }

            let slotsSnapshot = await MainActor.run { self.curatedAdSlotIDs }
            await MainActor.run {
                self.updateAdDebug(
                    targetID: adTargetID,
                    stage: "slot_sync_request",
                    status: "Syncing curated ad slots",
                    detail: "slots=\(slotsSnapshot.compactMap { $0?.uuidString.prefix(8) }.joined(separator: ","))"
                )
            }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "ad_curated_slot_update",
                    debugContext: BackendWriteDebugContext(
                        domain: .ad,
                        targetID: adTargetID,
                        action: "ad_curated_slot_update"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 20
                ) { _ in
                    let updatedSlots = try await self.backendClient.updateCuratedAdSlots(postIDs: slotsSnapshot)
                    await MainActor.run {
                        self.curatedAdSlotIDs = updatedSlots
                        self.saveCuratedAdSlots()
                    }
                }
                await MainActor.run {
                    self.updateAdDebug(
                        targetID: adTargetID,
                        stage: "slot_sync_acknowledged",
                        status: "Curated ad slots synced",
                        detail: "Backend confirmed curated slot assignment."
                    )
                }
            } catch {
                await MainActor.run {
                    // Permission errors (e.g. "Founder access required") are not
                    // transient — retrying will never succeed because the JWT doesn't
                    // carry the Founder claim. Drop silently instead of queuing.
                    if self.isFounderPermissionDeniedError(error) {
                        self.updateAdDebug(
                            targetID: adTargetID,
                            stage: "slot_sync_failed_permission_denied",
                            status: "Curated slot sync failed: Founder permission required",
                            detail: "JWT does not carry Founder claim. Log out and back in to refresh credentials.",
                            error: error
                        )
                        return
                    }
                    if self.isCuratedSlotDataError(error) {
                        self.updateAdDebug(
                            targetID: adTargetID,
                            stage: "slot_sync_failed_data_error",
                            status: "Curated slot sync failed: data not ready",
                            detail: "Submission or post not found. Will not retry until backend data is available.",
                            error: error
                        )
                        return
                    }
                    self.updateAdDebug(
                        targetID: adTargetID,
                        stage: "slot_sync_failed_queued",
                        status: "Curated slot sync failed; queued for retry",
                        detail: "Retry queue will apply slot update when auth/network recovers.",
                        error: error
                    )
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .adCuratedSlotUpdate,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: self.currentUser.id,
                            postID: adPost.id,
                            authorID: nil,
                            commentID: nil,
                            body: nil,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                }
            }
            await self.syncFromBackendIfAvailable(lane: .publishFollowUp, skipIdentityReconcile: true)
        }

        progress?("Step 4/5: Processing feed sync…")
        progress?("Step 5/5: Done.")
    }

    @discardableResult
    func uploadFounderSplashAd(
        media: MediaPreview,
        websiteURL: String,
        caption: String?,
        headline: String? = nil,
        body: String? = nil,
        ctaLabel: String? = nil,
        progress: ((String) -> Void)? = nil
    ) async throws -> BackendSplashAd {
        let targetID = "splash_ad"
        updateAdDebug(
            targetID: targetID,
            stage: "splash_upload_start",
            status: "Starting splash ad upload",
            detail: "Preparing splash upload request.",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )

        guard backendClient.isEnabled else {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_backend_disabled",
                status: "Splash upload failed: backend unavailable",
                detail: "Backend client is disabled.",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw SplashAdUploadError.uploadFailed
        }
        guard canCurrentUserPublishFounderAds() else {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_not_founder",
                status: "Splash upload denied",
                detail: "Current user cannot publish founder ads.",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw SplashAdUploadError.uploadFailed
        }

        let cleanedWebsite = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedWebsite.isEmpty else {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_missing_url",
                status: "Splash upload blocked",
                detail: "Website URL is required.",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw SplashAdUploadError.missingWebsiteURL
        }
        guard case let .video(video) = media else {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_invalid_media",
                status: "Splash upload blocked",
                detail: "Only video media is allowed.",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw SplashAdUploadError.invalidMedia
        }

        if video.url.isFileURL, FileManager.default.fileExists(atPath: video.url.path) {
            let bytes = (try? FileManager.default.attributesOfItem(atPath: video.url.path)[.size] as? NSNumber)?.int64Value ?? 0
            let maxBytes: Int64 = 90 * 1024 * 1024
            if bytes > maxBytes {
                updateAdDebug(
                    targetID: targetID,
                    stage: "splash_upload_failed_too_large",
                    status: "Splash upload blocked",
                    detail: "Video exceeds 90MB limit.",
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                throw SplashAdUploadError.videoTooLarge(maxMB: 90)
            }
        }

        progress?("Step 1/6: Validating splash media…")
        updateAdDebug(
            targetID: targetID,
            stage: "splash_upload_media_validated",
            status: "Splash media validated",
            detail: "Video accepted for upload.",
            authPreflight: currentAuthSnapshotForSyncDebug()
        )

        progress?("Step 2/6: Authenticating…")
        updateAdDebug(
            targetID: targetID,
            stage: "splash_upload_auth_seed",
            status: "Preparing session for splash upload",
            detail: "Seeding and validating backend session.",
            authPreflight: currentAuthSnapshotForSyncDebug()
        )
        BackendTruthSyncCore.seedSessionForActiveUsername(
            currentUser.username,
            expectedUserID: currentUser.id,
            using: backendClient
        )
        let hasSession = await BackendTruthSyncCore.ensureActiveSession(
            for: currentUser.username,
            expectedUserID: currentUser.id,
            using: backendClient,
            preferRefresh: true
        )
        guard hasSession else {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_missing_auth",
                status: "Splash upload failed: authorization missing",
                detail: "Session recovery failed before upload.",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw SplashAdUploadError.missingAuthorization
        }
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        updateAdDebug(
            targetID: targetID,
            stage: "splash_upload_auth_ready",
            status: "Authorization ready",
            detail: "Session active for splash upload.",
            authPreflight: currentAuthSnapshotForSyncDebug()
        )

        #if canImport(UniformTypeIdentifiers)
        let fileExt = UTType(filenameExtension: video.url.pathExtension)?.preferredFilenameExtension ?? "mp4"
        #else
        let fileExt = "mp4"
        #endif

        let cleanedHeadline = headline?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackBody = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBody = (cleanedBody?.isEmpty == false)
            ? cleanedBody
            : ((fallbackBody?.isEmpty == false) ? fallbackBody : nil)
        let cleanedCTA = ctaLabel?.trimmingCharacters(in: .whitespacesAndNewlines)

        progress?("Step 3/6: Uploading splash video…")
        updateAdDebug(
            targetID: targetID,
            stage: "splash_upload_request",
            status: "Uploading splash video",
            detail: "filename=splash-ad.\(fileExt), headline_set=\((cleanedHeadline?.isEmpty == false) ? "yes" : "no"), body_set=\((resolvedBody?.isEmpty == false) ? "yes" : "no"), url_set=yes, cta_set=\((cleanedCTA?.isEmpty == false) ? "yes" : "no")",
            authPreflight: currentAuthSnapshotForSyncDebug()
        )

        func uploadAttempt() async throws -> BackendSplashAd {
            try await backendClient.uploadSplashAdVideo(
                fileName: "splash-ad.\(fileExt)",
                localURL: video.url,
                headline: (cleanedHeadline?.isEmpty == false) ? cleanedHeadline : nil,
                body: resolvedBody,
                websiteURL: cleanedWebsite,
                ctaLabel: (cleanedCTA?.isEmpty == false) ? cleanedCTA : "Open Link"
            )
        }

        do {
            let uploaded = try await uploadAttempt()
            progress?("Step 6/6: Done.")
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_success",
                status: "Splash ad uploaded",
                detail: "asset_ref=\(uploaded.assetRef ?? "none"), website_set=\((uploaded.websiteURL?.isEmpty == false) ? "yes" : "no")",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            return uploaded
        } catch let backendError as BackendClientError {
            if case .httpStatus(_, let message) = backendError,
               (message ?? "").localizedCaseInsensitiveContains("invalid jwt") {
                progress?("Step 4/6: Refreshing session…")
                updateAdDebug(
                    targetID: targetID,
                    stage: "splash_upload_recover_invalid_jwt",
                    status: "Invalid JWT detected; refreshing session",
                    detail: "Retrying splash upload after token refresh.",
                    error: backendError,
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                let existingRefresh = backendClient.currentRefreshToken()
                lastTerminalAuthFailureAt = nil
                backendClient.setAuthSession(
                    token: nil,
                    refreshToken: existingRefresh,
                    source: "splash.invalid_jwt_recovery"
                )
                let recovered = await BackendTruthSyncCore.ensureActiveSession(
                    for: currentUser.username,
                    expectedUserID: currentUser.id,
                    using: backendClient,
                    preferRefresh: true
                )
                guard recovered else {
                    updateAdDebug(
                        targetID: targetID,
                        stage: "splash_upload_failed_recovery",
                        status: "Splash upload failed: session recovery failed",
                        detail: "Could not recover session after invalid JWT.",
                        error: backendError,
                        authPreflight: currentAuthSnapshotForSyncDebug()
                    )
                    throw SplashAdUploadError.missingAuthorization
                }
                restoreBackendAuthTokenForCurrentUserIfNeeded()
                progress?("Step 5/6: Retrying upload…")
                let uploaded = try await uploadAttempt()
                progress?("Step 6/6: Done.")
                updateAdDebug(
                    targetID: targetID,
                    stage: "splash_upload_success_recovered",
                    status: "Splash ad uploaded after session recovery",
                    detail: "asset_ref=\(uploaded.assetRef ?? "none")",
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                return uploaded
            }
            if case .httpStatus(401, let message) = backendError,
               (message ?? "").localizedCaseInsensitiveContains("missing authorization") {
                updateAdDebug(
                    targetID: targetID,
                    stage: "splash_upload_failed_missing_auth",
                    status: "Splash upload failed: missing authorization",
                    detail: "Server rejected request due to missing auth header.",
                    error: backendError,
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                throw SplashAdUploadError.missingAuthorization
            }
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_backend",
                status: "Splash upload failed",
                detail: "Backend returned an error during splash upload.",
                error: backendError,
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw backendError
        } catch {
            updateAdDebug(
                targetID: targetID,
                stage: "splash_upload_failed_unknown",
                status: "Splash upload failed",
                detail: "Unexpected error while uploading splash ad.",
                error: error,
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
            throw error
        }
    }

    private func publishPostViaStandardPipeline(
        _ post: FeedPost,
        mentionText: String?,
        mentionContext: String,
        timeoutSeconds: TimeInterval
    ) async throws {
        // Fast-path publish for curated ads: insert locally, upload directly, then background-sync.
        posts.insert(post, at: 0)
        if let mentionText, !mentionText.isEmpty {
            notifyMentions(in: mentionText, context: mentionContext, objectID: post.id, actor: post.user)
        }
        saveState()
        do {
            try await publishPostToBackend(
                post,
                author: post.user,
                maxAttempts: 2,
                timeoutPerAttempt: timeoutSeconds
            )
        } catch {
            rollbackLocallyInsertedPost(postID: post.id)
            throw error
        }
        Task {  [weak self] in
            await self?.syncFromBackendIfAvailable(lane: .publishFollowUp, skipIdentityReconcile: true)
        }
    }


    func refreshAdSubmissions() {
        guard backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            do {
                let submissions = try await self.backendClient.fetchAdSubmissions(limit: 150)
                await MainActor.run {
                    self.mergeRemoteAdSubmissions(submissions)
                }
            } catch {
                // Keep local fallback state.
            }
        }
    }

    func loadAdReviewQueue() {
        guard isAdReviewAdmin, backendClient.isEnabled else { return }
        isLoadingAdReviewQueue = true
        Task {  [weak self] in
            guard let self else { return }
            do {
                let queue = try await self.backendClient.fetchAdSubmissions(
                    status: "pending",
                    limit: 200
                )
                await MainActor.run {
                    self.adReviewQueue = queue.sorted { $0.createdAt > $1.createdAt }
                    self.isLoadingAdReviewQueue = false
                }
            } catch {
                // Ignore transient failures to keep queue stable.
                await MainActor.run {
                    self.isLoadingAdReviewQueue = false
                }
            }
        }
    }

    func reviewAdSubmission(_ submission: BackendAdSubmission, status: String, notes: String?) {
        guard isAdReviewAdmin, backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            do {
                let updated = try await self.backendClient.reviewAdSubmission(
                    submissionID: submission.id,
                    status: status,
                    reviewNotes: notes
                )
                await MainActor.run {
                    self.mergeRemoteAdSubmissions([updated])
                    self.adReviewQueue.removeAll { $0.id == submission.id }
                }
            } catch {
                // Keep queue and try again.
            }
        }
    }

    func canReportPost(_ post: FeedPost) -> Bool {
        post.user.id != currentUser.id
    }

    // MARK: – Block / Unblock

    func isBlocking(_ profile: UserProfile) -> Bool {
        blockedUserIDs.contains(profile.id)
    }

    func toggleBlock(_ profile: UserProfile) {
        if isBlocking(profile) {
            unblockUserProfile(profile)
        } else {
            blockUserProfile(profile)
        }
    }

    func blockUserProfile(_ profile: UserProfile) {
        guard profile.id != currentUser.id else { return }
        guard canBlockProfile(profile) else { return }
        guard backendClient.isEnabled else { return }
        blockedUserIDs.insert(profile.id)
        pruneBlockedUserContent(profile.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.blockUser(targetUserID: profile.id)
                try? await self.backendClient.reportProfile(
                    targetUserID: profile.id,
                    reason: .harassmentBullying,
                    notes: "User blocked this account from an in-app UGC safety control."
                )
            } catch {
                _ = await MainActor.run {
                    self.blockedUserIDs.remove(profile.id)
                }
            }
        }
    }

    /// Unblock by raw UUID — used by the Blocked Accounts manager
    /// view where we may not have a full UserProfile in the registry
    /// for an entry that was added on another device.
    func unblockUserID(_ userID: UUID) {
        guard userID != currentUser.id else { return }
        guard backendClient.isEnabled else { return }
        blockedUserIDs.remove(userID)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.unblockUser(targetUserID: userID)
            } catch {
                _ = await MainActor.run {
                    self.blockedUserIDs.insert(userID)
                }
            }
        }
    }

    func unblockUserProfile(_ profile: UserProfile) {
        guard profile.id != currentUser.id else { return }
        guard backendClient.isEnabled else { return }
        blockedUserIDs.remove(profile.id)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.unblockUser(targetUserID: profile.id)
            } catch {
                _ = await MainActor.run {
                    self.blockedUserIDs.insert(profile.id)
                }
            }
        }
    }

    private func pruneBlockedUserContent(_ userID: UUID) {
        posts.removeAll { post in
            post.user.id == userID || post.rescrollOrigin?.user.id == userID
        }
        pendingRemotePosts.removeAll { post in
            post.user.id == userID || post.rescrollOrigin?.user.id == userID
        }
        deliveredAdPosts.removeAll { post in
            post.user.id == userID || post.rescrollOrigin?.user.id == userID
        }
        moments.removeAll { $0.userID == userID }
        notifications.removeAll { $0.actorID == userID }
        circles = circles.map { circle in
            var updated = circle
            updated.messages.removeAll { $0.userID == userID }
            return updated
        }
        pendingFeedPostCount = pendingRemotePosts.count
        objectWillChange.send()
        saveState()
    }

    /// Forwards a UGC report to the generic content-report endpoint.
    /// Throws on backend failure so the caller can surface a retry to
    /// the user.  Posts have their own dedicated reportPost flow; this
    /// covers comments, music tracks, voice messages, circle messages,
    /// and avatars.
    func reportContent(
        targetType: BackendContentReport.TargetType,
        targetID: UUID,
        targetOwnerID: UUID?,
        reason: BackendPostReport.Reason,
        notes: String? = nil
    ) async throws {
        guard backendClient.isEnabled else { return }
        try await backendClient.reportContent(
            targetType: targetType,
            targetID: targetID,
            targetOwnerID: targetOwnerID,
            reason: reason,
            notes: notes
        )
    }

    /// Loads the current user's block list from the backend.
    /// Called once at startup alongside following/notifications.
    func loadBlockedUserIDs() {
        guard backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let ids = try await self.backendClient.fetchBlockedUserIDs()
                await MainActor.run {
                    let protected = Set(ids.filter { Self.protectedFounderBlockAccountIDs.contains($0) })
                    self.blockedUserIDs = Set(ids).subtracting(protected)
                    if !protected.isEmpty {
                        for protectedID in protected {
                            Task { [weak self] in
                                try? await self?.backendClient.unblockUser(targetUserID: protectedID)
                            }
                        }
                    }
                }
            } catch {
                // Non-fatal: blocked list will be empty this session.
            }
        }
    }

    /// Hide a single post locally.  Persists across launches and
    /// applies to every feed lane.  Users can manage their hidden list
    /// from Settings if we surface it later; for now, blocking the
    /// author is the long-term sibling action.
    func hidePost(_ post: FeedPost) {
        guard !hiddenPostIDs.contains(post.id) else { return }
        hiddenPostIDs.insert(post.id)
        persistHiddenPostIDs()
    }

    func unhidePost(_ postID: UUID) {
        guard hiddenPostIDs.contains(postID) else { return }
        hiddenPostIDs.remove(postID)
        persistHiddenPostIDs()
    }

    func isPostHidden(_ post: FeedPost) -> Bool {
        hiddenPostIDs.contains(post.id)
    }

    private func persistHiddenPostIDs() {
        let serialized = hiddenPostIDs.map { $0.uuidString }
        UserDefaults.standard.set(serialized, forKey: "scrolls.moderation.hiddenPostIDs")
    }

    func reportPost(_ post: FeedPost, reason: BackendPostReport.Reason, notes: String? = nil) {
        guard canReportPost(post) else { return }
        guard backendClient.isEnabled else {
            moderationErrorMessage = "Reporting is unavailable right now."
            return
        }
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reportPost(postID: post.id, reason: reason, notes: notes)
                if self.isPostReportReviewAdmin {
                    self.loadPostReportQueue()
                }
            } catch {
                await MainActor.run {
                    self.moderationErrorMessage = "Couldn't submit report right now. Please try again."
                }
            }
        }
    }

    func reportProfile(_ profile: UserProfile, reason: BackendPostReport.Reason, notes: String? = nil) {
        guard profile.id != currentUser.id else { return }
        guard backendClient.isEnabled else {
            moderationErrorMessage = "Reporting is unavailable right now."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reportProfile(targetUserID: profile.id, reason: reason, notes: notes)
            } catch {
                await MainActor.run {
                    self.moderationErrorMessage = "Couldn't submit report right now. Please try again."
                }
            }
        }
    }

    func reportLiveStream(sessionID: UUID?, ownerUserID: UUID, reason: BackendPostReport.Reason, notes: String? = nil) {
        guard ownerUserID != currentUser.id else { return }
        guard backendClient.isEnabled else {
            moderationErrorMessage = "Reporting is unavailable right now."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reportLiveStream(sessionID: sessionID, ownerUserID: ownerUserID, reason: reason, notes: notes)
            } catch {
                await MainActor.run {
                    self.moderationErrorMessage = "Couldn't submit report right now. Please try again."
                }
            }
        }
    }

    func loadPostReportQueue() {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        isLoadingPostReportQueue = true
        Task {  [weak self] in
            guard let self else { return }
            do {
                let queue = try await self.backendClient.fetchPostReports(status: .pending, limit: 200)
                await MainActor.run {
                    self.postReportQueue = queue.sorted { $0.createdAt > $1.createdAt }
                    self.isLoadingPostReportQueue = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingPostReportQueue = false
                }
            }
        }
    }

    func reviewPostReport(_ report: BackendPostReport, status: BackendPostReport.Status) {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reviewPostReport(reportID: report.id, status: status)
                await MainActor.run {
                    self.postReportQueue.removeAll { $0.id == report.id }
                }
            } catch {
                // Keep queue; allow retry.
            }
        }
    }

    // MARK: – Profile / live / content report queues (founder)

    func loadProfileReportQueue() {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        isLoadingProfileReportQueue = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let queue = try await self.backendClient.fetchProfileReports(status: .pending, limit: 200)
                await MainActor.run {
                    self.profileReportQueue = queue.sorted { $0.createdAt > $1.createdAt }
                    self.isLoadingProfileReportQueue = false
                }
            } catch {
                await MainActor.run { self.isLoadingProfileReportQueue = false }
            }
        }
    }

    func reviewProfileReport(_ report: BackendProfileReport, status: BackendPostReport.Status) {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reviewProfileReport(reportID: report.id, status: status)
                await MainActor.run { self.profileReportQueue.removeAll { $0.id == report.id } }
            } catch { /* keep for retry */ }
        }
    }

    func loadLiveStreamReportQueue() {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        isLoadingLiveStreamReportQueue = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let queue = try await self.backendClient.fetchLiveStreamReports(status: .pending, limit: 200)
                await MainActor.run {
                    self.liveStreamReportQueue = queue.sorted { $0.createdAt > $1.createdAt }
                    self.isLoadingLiveStreamReportQueue = false
                }
            } catch {
                await MainActor.run { self.isLoadingLiveStreamReportQueue = false }
            }
        }
    }

    func reviewLiveStreamReport(_ report: BackendLiveStreamReport, status: BackendPostReport.Status) {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reviewLiveStreamReport(reportID: report.id, status: status)
                await MainActor.run { self.liveStreamReportQueue.removeAll { $0.id == report.id } }
            } catch { /* keep for retry */ }
        }
    }

    func loadContentReportQueue() {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        isLoadingContentReportQueue = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let queue = try await self.backendClient.fetchContentReports(status: .pending, limit: 200)
                await MainActor.run {
                    self.contentReportQueue = queue.sorted { $0.createdAt > $1.createdAt }
                    self.isLoadingContentReportQueue = false
                }
            } catch {
                await MainActor.run { self.isLoadingContentReportQueue = false }
            }
        }
    }

    func reviewContentReport(_ report: BackendContentReportRecord, status: BackendPostReport.Status) {
        guard isPostReportReviewAdmin, backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.backendClient.reviewContentReport(reportID: report.id, status: status)
                await MainActor.run { self.contentReportQueue.removeAll { $0.id == report.id } }
            } catch { /* keep for retry */ }
        }
    }

    func publishSyncStatus(for postID: UUID) -> PostPublishSyncStatus? {
        if let state = postPublishDeliveryStates[postID] {
            if state.failedMessage == nil {
                return .syncing
            }
            return .failed
        }
        if let acknowledgedAt = postPublishSuccessAcks[postID] {
            if Date().timeIntervalSince(acknowledgedAt) <= Self.publishSuccessIndicatorDuration {
                return .synced
            }
            _ = clearPostPublishSuccessState(postID)
        }
        return nil
    }

    func publishSyncFailureMessage(for postID: UUID) -> String? {
        postPublishDeliveryStates[postID]?.failedMessage
    }

    func refreshDebugAuthDiagnostics() {
        Task {  [weak self] in
            guard let self else { return }
            let recovered = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
            await MainActor.run {
                self.restoreBackendAuthTokenForCurrentUserIfNeeded()
                self.updateDebugStatus { status in
                    status.lastAuthRecoveryAction = recovered
                        ? "Manual diagnostics refresh recovered session"
                        : "Manual diagnostics refresh could not recover session"
                    status.lastAuthFailureAt = Date()
                }
            }
        }
    }

    func repairSessionForCurrentAccount() {
        var usernamesToClear = Set<String>()
        let currentNormalized = normalizeUsername(currentUser.username)
        if !currentNormalized.isEmpty, currentNormalized != "you" {
            usernamesToClear.insert(currentNormalized)
        }
        let resolvedSession = resolvedBackendSessionUsername()
        if !resolvedSession.isEmpty, resolvedSession != "you" {
            usernamesToClear.insert(resolvedSession)
        }
        let active = Self.normalizedActiveUsername()
        if !active.isEmpty, active != "you" {
            usernamesToClear.insert(active)
        }
        for record in LocalAuthStore.sessionRecords() where record.id == currentUser.id {
            let normalizedRecordUsername = normalizeUsername(record.username)
            if !normalizedRecordUsername.isEmpty {
                usernamesToClear.insert(normalizedRecordUsername)
            }
        }
        lastTerminalAuthFailureAt = nil
        backendClient.setAuthSession(
            token: nil,
            refreshToken: nil,
            source: "repairSessionForCurrentAccount"
        )
        for username in usernamesToClear {
            LocalAuthStore.removeSessionRecord(forUsername: username)
        }
        UserDefaults.standard.set(false, forKey: "scrolls.auth.isAuthenticated")
        UserDefaults.standard.set("", forKey: "scrolls.auth.activeUsername")
        UserDefaults.standard.set(false, forKey: "scrolls.auth.needsFollowOnboarding")
        moderationErrorMessage = "Session repaired. Sign in again."
        updateDebugStatus { status in
            status.authTokenPresent = false
            status.refreshTokenPresent = false
            status.lastAuthFailure = "manual_session_repair"
            status.lastAuthFailureContext = "Repair Current Session"
            status.lastAuthRecoveryAction = "Cleared current account session records and forced sign-out"
            status.lastAuthFailureAt = Date()
            status.refreshOutcome = "manual_repair_forced_sign_out"
            status.sessionRecordSource = "none"
            status.bootstrapCandidateCount = "0"
            status.bootstrapFallbackUsed = "No"
        }
    }

    func publishSyncStatusLabel(for postID: UUID) -> String? {
        if let state = postPublishDeliveryStates[postID] {
            if let failedMessage = state.failedMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
               !failedMessage.isEmpty {
                return "Sync failed: \(failedMessage)"
            }
            let elapsed = max(0, Int(Date().timeIntervalSince(state.pendingAt)))
            return "Syncing... \(formattedDuration(seconds: elapsed))"
        }
        if let acknowledgedAt = postPublishSuccessAcks[postID] {
            if Date().timeIntervalSince(acknowledgedAt) <= Self.publishSuccessIndicatorDuration {
                return "Sync successful"
            }
            _ = clearPostPublishSuccessState(postID)
        }
        return nil
    }

    private func markPostPublishPending(_ postID: UUID) {
        _ = clearPostPublishSuccessState(postID)
        postPublishDeliveryStates[postID] = PostPublishDeliveryState(
            pendingAt: Date(),
            failedMessage: nil
        )
        isUploadingPost = !postPublishDeliveryStates.isEmpty
        objectWillChange.send()
    }

    private func markPostBackendAcknowledged(_ postID: UUID) {
        pendingPublishRetryTasks[postID]?.cancel()
        pendingPublishRetryTasks[postID] = nil
        postPublishSuccessAcks[postID] = Date()
        postPublishSuccessClearTasks[postID]?.cancel()
        postPublishSuccessClearTasks[postID] = Task {  [weak self] in
            let delay = UInt64(Self.publishSuccessIndicatorDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                guard let self else { return }
                self.postPublishSuccessClearTasks[postID] = nil
                guard let ackAt = self.postPublishSuccessAcks[postID] else { return }
                guard Date().timeIntervalSince(ackAt) >= Self.publishSuccessIndicatorDuration else { return }
                self.postPublishSuccessAcks.removeValue(forKey: postID)
                self.objectWillChange.send()
            }
        }
        _ = postPublishDeliveryStates.removeValue(forKey: postID)
        isUploadingPost = !postPublishDeliveryStates.isEmpty
        // Show the feed-level success banner briefly.
        postUploadSuccessBanner = "Post uploaded successfully."
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard let self else { return }
            self.postUploadSuccessBanner = nil
        }
        objectWillChange.send()
    }

    private func markPostPublishFailed(_ postID: UUID, message: String) {
        _ = clearPostPublishSuccessState(postID)
        if var existing = postPublishDeliveryStates[postID] {
            existing.failedMessage = message
            postPublishDeliveryStates[postID] = existing
        } else {
            postPublishDeliveryStates[postID] = PostPublishDeliveryState(
                pendingAt: Date(),
                failedMessage: message
            )
        }
        isUploadingPost = !postPublishDeliveryStates.isEmpty
        objectWillChange.send()
    }

    private func clearPostPublishDeliveryState(_ postID: UUID) {
        let removedPending = postPublishDeliveryStates.removeValue(forKey: postID) != nil
        let removedSuccess = clearPostPublishSuccessState(postID)
        guard removedPending || removedSuccess else { return }
        isUploadingPost = !postPublishDeliveryStates.isEmpty
        objectWillChange.send()
    }

    private func clearPostPublishSuccessState(_ postID: UUID) -> Bool {
        let hadSuccess = postPublishSuccessAcks.removeValue(forKey: postID) != nil
        postPublishSuccessClearTasks[postID]?.cancel()
        postPublishSuccessClearTasks[postID] = nil
        return hadSuccess
    }

    private func formattedDuration(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return "\(minutes)m \(remainingSeconds)s"
    }

    private func publish(
        post: FeedPost,
        mentionText: String?,
        mentionContext: String,
        backendCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) -> Bool {
        enforceFreeCatalogLimitIfNeeded(for: post)
        posts.insert(post, at: 0)
        markPostPublishPending(post.id)
        saveState()
        updatePublishDebug(
            postID: post.id,
            stage: "queued_local",
            status: "Publishing post \(post.id.uuidString.prefix(8))...",
            detail: "Post inserted locally and queued for backend sync.",
            resetFlow: true
        )
        Task {  [weak self] in
            guard let self else { return }
            do {
                var hasUsableToken = self.hasLocallyUsableAuthToken()
                var hasSession = hasUsableToken
                var tokenServerValidated = hasUsableToken
                var publishAuthorizationToken: String? = hasUsableToken
                    ? self.currentUsableAuthTokenForWrite()
                    : nil
                let hasRefreshToken = self.hasRefreshTokenForBackendSync()
                let hasRecoverableCandidate = self.hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
                if !hasUsableToken {
                    hasSession = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
                    publishAuthorizationToken = await self.backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                        expectedSubjectUserID: self.currentUser.id
                    )
                    hasUsableToken = self.hasLocallyUsableAuthToken()
                    tokenServerValidated = publishAuthorizationToken != nil
                    if publishAuthorizationToken == nil, hasUsableToken {
                        publishAuthorizationToken = self.currentUsableAuthTokenForWrite()
                        tokenServerValidated = publishAuthorizationToken != nil
                    }
                }
                await MainActor.run {
                    self.updatePublishDebug(
                        postID: post.id,
                        stage: "auth_preflight",
                        status: "Auth preflight complete for \(post.id.uuidString.prefix(8))",
                        detail: hasSession
                            ? (tokenServerValidated
                                ? "Active backend session is ready."
                                : "Session exists locally but preflight gateway validation failed. Proceeding with request-level auth recovery.")
                            : "Session not active; request will rely on token-level recovery.",
                        authPreflight: self.makePublishAuthSnapshot(
                            sessionActive: hasSession,
                            usableToken: hasUsableToken,
                            serverValidated: tokenServerValidated
                        )
                    )
                }
                if !hasUsableToken && !hasRefreshToken && !hasRecoverableCandidate {
                    await MainActor.run {
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "auth_missing",
                            status: "Publish blocked before request",
                            detail: "No usable local auth token or refresh token was available for backend publish.",
                            authPreflight: self.makePublishAuthSnapshot(
                                sessionActive: hasSession,
                                usableToken: false,
                                serverValidated: tokenServerValidated
                            ),
                            retry: "Not scheduled"
                        )
                    }
                    throw BackendClientError.httpStatus(401, "Missing authorization header")
                }
                if !tokenServerValidated {
                    await MainActor.run {
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "auth_preflight_warning",
                            status: "Server token preflight failed; continuing publish",
                            detail: "Proceeding to backend request so request-level auth refresh/retry can recover automatically.",
                            authPreflight: self.makePublishAuthSnapshot(
                                sessionActive: hasSession,
                                usableToken: hasUsableToken,
                                serverValidated: tokenServerValidated
                            ),
                            recovery: "Request-level auth recovery enabled"
                        )
                    }
                }
                let usingStickyToken = !(publishAuthorizationToken ?? "").isEmpty
                await MainActor.run {
                    self.updatePublishDebug(
                        postID: post.id,
                        stage: "backend_request",
                        status: "Publishing to backend \(post.id.uuidString.prefix(8))...",
                        detail: usingStickyToken
                            ? "Sending create-post request to backend with sticky auth header (server-validated)."
                            : "Sending create-post request to backend without sticky auth token."
                    )
                }
                let initialPolicy = publishAttemptPolicy(for: post)
                try await publishPostToBackend(
                    post,
                    author: post.user,
                    maxAttempts: initialPolicy.maxAttempts,
                    timeoutPerAttempt: initialPolicy.timeoutPerAttempt,
                    authorizationTokenOverride: publishAuthorizationToken,
                    onAttemptStart: { [weak self] attempt, total in
                        guard let self else { return }
                        let detail: String = {
                            if case .video = post.mediaPreview {
                                return "Running direct publish attempt \(attempt) of \(total). Uploading video + creating post (timeout \(Int(initialPolicy.timeoutPerAttempt))s)."
                            }
                            return "Running direct publish attempt \(attempt) of \(total)."
                        }()
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "backend_attempt_\(attempt)",
                            status: "Backend attempt \(attempt)/\(total) for \(post.id.uuidString.prefix(8))",
                            detail: detail
                        )
                    },
                    onAttemptFailure: { [weak self] attempt, total, error in
                        guard let self else { return }
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "backend_attempt_failed_\(attempt)",
                            status: "Backend attempt \(attempt)/\(total) failed",
                            detail: "Direct publish attempt failed before backend acknowledgement.",
                            error: error
                        )
                    }
                )
                await MainActor.run {
                    self.markPostBackendAcknowledged(post.id)
                    if let mentionText, !mentionText.isEmpty {
                        self.notifyMentions(in: mentionText, context: mentionContext, objectID: post.id, actor: post.user)
                    }
                    self.updatePublishDebug(
                        postID: post.id,
                        stage: "backend_acknowledged",
                        status: "Publish accepted \(post.id.uuidString.prefix(8))",
                        detail: "Backend confirmed the post and local sync state was cleared.",
                        recovery: "Not needed",
                        retry: "Not needed"
                    )
                }
                Task {  [weak self] in
                    await self?.syncFromBackendIfAvailable(lane: .publishFollowUp)
                }
                await MainActor.run {
                    backendCompletion?(.success(()))
                }
            } catch {
                var terminalError: Error = error
                if self.isAuthenticationFailureError(terminalError) {
                    let shouldAttemptSessionRecovery = !self.isInvalidJWTError(terminalError)
                    await MainActor.run {
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "auth_recovery_attempt",
                            status: "Publish hit auth failure; attempting session recovery",
                            detail: "Initial publish failed with an auth error.",
                            error: terminalError,
                            recovery: "Attempting active-session recovery"
                        )
                        self.recordAuthFailure(
                            terminalError,
                            context: "Publish initial request",
                            recovery: "Attempting active-session recovery"
                        )
                    }
                    if shouldAttemptSessionRecovery {
                        let recovered = await BackendTruthSyncCore.ensureActiveSession(
                            for: self.resolvedBackendSessionUsername(),
                            expectedUserID: self.currentUser.id,
                            using: self.backendClient,
                            preferRefresh: true
                        )
                        if recovered {
                            self.restoreBackendAuthTokenForCurrentUserIfNeeded()
                            await MainActor.run {
                                self.updatePublishDebug(
                                    postID: post.id,
                                    stage: "auth_recovered",
                                    status: "Session recovered; retrying publish",
                                    detail: "Recovered auth session after failure and retrying publish.",
                                    authPreflight: self.makePublishAuthSnapshot(
                                        sessionActive: true,
                                        usableToken: self.hasLocallyUsableAuthToken()
                                    ),
                                    recovery: "Recovered session"
                                )
                            }
                            do {
                                var publishAuthorizationToken = self.currentUsableAuthTokenForWrite()
                                if publishAuthorizationToken == nil {
                                    publishAuthorizationToken = await self.backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                                        expectedSubjectUserID: self.currentUser.id
                                    )
                                }
                                let usingStickyToken = !(publishAuthorizationToken ?? "").isEmpty
                                await MainActor.run {
                                    self.updatePublishDebug(
                                        postID: post.id,
                                        stage: "backend_request_after_recovery",
                                        status: "Retrying publish to backend \(post.id.uuidString.prefix(8))...",
                                        detail: usingStickyToken
                                            ? "Recovered session; retry uses sticky auth header."
                                            : "Recovered session; retry has no sticky auth token."
                                    )
                                }
                                let recoveryPolicy = self.publishAttemptPolicy(for: post)
                                try await self.publishPostToBackend(
                                    post,
                                    author: post.user,
                                    maxAttempts: 1,
                                    timeoutPerAttempt: recoveryPolicy.timeoutPerAttempt,
                                    authorizationTokenOverride: publishAuthorizationToken,
                                    onAttemptStart: { [weak self] attempt, total in
                                        guard let self else { return }
                                        self.updatePublishDebug(
                                            postID: post.id,
                                            stage: "recovery_backend_attempt_\(attempt)",
                                            status: "Recovery attempt \(attempt)/\(total) for \(post.id.uuidString.prefix(8))",
                                            detail: "Running publish attempt after recovered session."
                                        )
                                    },
                                    onAttemptFailure: { [weak self] attempt, total, error in
                                        guard let self else { return }
                                        self.updatePublishDebug(
                                            postID: post.id,
                                            stage: "recovery_backend_attempt_failed_\(attempt)",
                                            status: "Recovery backend attempt \(attempt)/\(total) failed",
                                            detail: "Recovered session but backend publish attempt failed.",
                                            error: error
                                        )
                                    }
                                )
                                await MainActor.run {
                                    self.markPostBackendAcknowledged(post.id)
                                    if let mentionText, !mentionText.isEmpty {
                                        self.notifyMentions(in: mentionText, context: mentionContext, objectID: post.id, actor: post.user)
                                    }
                                    self.updatePublishDebug(
                                        postID: post.id,
                                        stage: "backend_acknowledged_after_recovery",
                                        status: "Publish accepted after session recovery \(post.id.uuidString.prefix(8))",
                                        detail: "Recovered auth and successfully published on retry.",
                                        recovery: "Recovered session and publish succeeded",
                                        retry: "Not needed"
                                    )
                                    backendCompletion?(.success(()))
                                }
                                Task {  [weak self] in
                                    await self?.syncFromBackendIfAvailable(lane: .publishFollowUp)
                                }
                                return
                            } catch {
                                terminalError = error
                                await MainActor.run {
                                    self.updatePublishDebug(
                                        postID: post.id,
                                        stage: "auth_recovery_publish_failed",
                                        status: "Publish retry after recovery failed",
                                        detail: "Session recovered but publish retry still failed.",
                                        error: terminalError,
                                        recovery: "Recovered session but publish failed"
                                    )
                                    self.recordAuthFailure(
                                        terminalError,
                                        context: "Publish retry after recovered session",
                                        recovery: "Session recovered, publish still failed"
                                    )
                                }
                            }
                        } else {
                            await MainActor.run {
                                self.updatePublishDebug(
                                    postID: post.id,
                                    stage: "auth_recovery_failed",
                                    status: "Session recovery failed",
                                    detail: "Unable to refresh backend session after auth failure.",
                                    error: terminalError,
                                    recovery: "Recovery failed"
                                )
                                self.recordAuthFailure(
                                    terminalError,
                                    context: "Publish recovery refresh",
                                    recovery: "Unable to recover session"
                                )
                            }
                        }
                    } else {
                        await MainActor.run {
                            self.updatePublishDebug(
                                postID: post.id,
                                stage: "auth_recovery_skipped_terminal",
                                status: "Terminal auth failure; skipping duplicate recovery",
                                detail: "Request-level auth recovery already ran for this publish. Prompting reauthentication.",
                                error: terminalError,
                                recovery: "Skipped duplicate recovery for terminal auth failure"
                            )
                            self.recordAuthFailure(
                                terminalError,
                                context: "Publish terminal auth failure",
                                recovery: "Skipped duplicate recovery; prompt reauthentication"
                            )
                        }
                    }
                }
                let handledFailurePath: Bool = await MainActor.run {
                    if self.shouldRetryPostPublish(post, error: terminalError) {
                        self.schedulePostBackendRetry(post)
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "retry_scheduled",
                            status: "Publish delayed; retrying \(post.id.uuidString.prefix(8)) in background...",
                            detail: "Initial publish failed and background retry queue was scheduled.",
                            error: terminalError,
                            retry: "Scheduled: up to 3 attempts (2s/6s/14s)"
                        )
                        self.moderationErrorMessage = "Post is syncing to backend in the background. Keeping it visible while we retry."
                        backendCompletion?(.failure(terminalError))
                        return true
                    }
                    if self.isAuthenticationFailureError(terminalError) {
                        let shouldClearStoredTokens = self.shouldClearStoredSessionTokensForAuthFailure(terminalError)
                        let preserveRefreshToken = self.shouldPreserveRefreshTokenAfterAuthFailure(terminalError)
                        let requiresImmediateReauth = shouldClearStoredTokens
                        if requiresImmediateReauth || self.handleMissingAuthorizationHeaderIfUnrecoverable() {
                            let preservedRefresh = self.backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.backendClient.setAuthSession(
                                token: nil,
                                refreshToken: (preserveRefreshToken && preservedRefresh?.isEmpty == false ? preservedRefresh : nil),
                                source: "publish.terminal_auth_failure"
                            )
                            if shouldClearStoredTokens {
                                self.clearStoredSessionTokensForReauthentication(preserveRefreshToken: preserveRefreshToken)
                            }
                            self.markPostPublishFailed(
                                post.id,
                                message: shouldClearStoredTokens
                                    ? "Auth expired during sync. Please sign in again, then post again."
                                    : "Auth was unavailable during sync. Keep the app open and retry."
                            )
                            self.updatePublishDebug(
                                postID: post.id,
                                stage: "reauth_required_no_logout",
                                status: "Publish failed; reauthentication required",
                                detail: shouldClearStoredTokens
                                    ? "Auth was unrecoverable. User remains signed in-app, post is kept failed for retry, and stored session tokens were cleared."
                                    : "Auth was unavailable and recovery did not complete in time. Post is kept failed for retry without clearing stored session tokens.",
                                error: terminalError,
                                recovery: "Prompt reauthentication without forced logout",
                                retry: "Manual retry after sign in"
                            )
                            self.recordAuthFailure(
                                terminalError,
                                context: "Publish terminal auth failure",
                                recovery: shouldClearStoredTokens
                                    ? "Prompt reauthentication without forced logout"
                                    : "Retain stored session; retry when auth recovers"
                            )
                            self.moderationErrorMessage = shouldClearStoredTokens
                                ? "Session expired while posting. Sign in again to resume sync."
                                : "Auth temporarily unavailable while posting. Keep the app open and retry."
                            backendCompletion?(.failure(terminalError))
                            return true
                        }
                    }
                    let shouldRollback = self.shouldRollbackLocallyInsertedPost(for: terminalError, post: post)
                    if shouldRollback {
                        self.rollbackLocallyInsertedPost(postID: post.id)
                    } else {
                        self.markPostPublishFailed(post.id, message: self.describeBackendError(terminalError))
                    }
                    self.updatePublishDebug(
                        postID: post.id,
                        stage: shouldRollback ? "publish_failed_rolled_back" : "publish_failed_local_retained",
                        status: "Publish failed: \(self.describeBackendError(terminalError))",
                        detail: shouldRollback
                            ? "Local optimistic post was removed because this error is not safe to keep."
                            : "Keeping local optimistic post visible while sync is failed.",
                        error: terminalError,
                        retry: "Not scheduled"
                    )
                    self.moderationErrorMessage = "Post upload to backend failed. Please check your login/token and try again."
                    return false
                }
                if handledFailurePath { return }
                await MainActor.run {
                    backendCompletion?(.failure(terminalError))
                }
            }
        }
        return true
    }

    private func enforceFreeCatalogLimitIfNeeded(for incomingPost: FeedPost) {
        guard FreePostCatalogLimit.autoRotateOldestEnabled else { return }
        guard incomingPost.rescrollOrigin == nil else { return }
        guard !hasSubscriberBenefits(for: incomingPost.user) else { return }
        let limit = FreePostCatalogLimit.totalScrolls
        let matching = posts.filter {
            $0.user.id == incomingPost.user.id &&
            $0.rescrollOrigin == nil
        }
        guard matching.count >= limit else { return }
        guard let oldest = matching.min(by: { $0.timestamp < $1.timestamp }) else { return }

        removePostForCatalogRotation(oldest)
        postLimitPromptMessage = "Free accounts can keep up to \(limit) Scrolls. Your oldest Scroll was removed so you can keep posting."
    }

    private func rollbackLocallyInsertedPost(postID: UUID) {
        posts.removeAll { $0.id == postID }
        adSubmissionPostIDs.remove(postID)
        adSubmissionsByPostID.removeValue(forKey: postID)
        deliveredAdPosts.removeAll { $0.id == postID }
        curatedAdSlotIDs = curatedAdSlotIDs.map { $0 == postID ? nil : $0 }
        saveCuratedAdSlots()
        normalizePinnedPosts()
        clearPostPublishDeliveryState(postID)
        saveState()
    }

    private func enforceCuratedAdCap() {
        let curatedPosts = posts
            .filter { adSubmissionPostIDs.contains($0.id) && $0.rescrollOrigin == nil }
            .sorted { $0.timestamp < $1.timestamp } // oldest first
        let overflow = curatedPosts.count - Self.maxCuratedAdCount
        guard overflow > 0 else { return }

        for post in curatedPosts.prefix(overflow) {
            markPostDeleted(post.id)
            adSubmissionPostIDs.remove(post.id)
            adSubmissionsByPostID.removeValue(forKey: post.id)
            deliveredAdPosts.removeAll { $0.id == post.id }
            curatedAdSlotIDs = curatedAdSlotIDs.map { $0 == post.id ? nil : $0 }
            enqueuePendingDeletion(kind: .post, postID: post.id, authorID: post.user.id, post: post)
        }
        saveCuratedAdSlots()
        normalizePinnedPosts()
        saveState()
        Task {  [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    private func shouldRollbackLocallyInsertedPost(for error: Error, post: FeedPost) -> Bool {
        if case .photo = post.mediaPreview { return false }
        if case .video = post.mediaPreview { return false }
        guard let backendError = error as? BackendClientError else { return true }
        switch backendError {
        case .httpStatus(let code, _):
            // Keep optimistic text posts visible on auth failures so they don't look deleted
            // while session recovery/login is being resolved.
            return code != 401
        default:
            return true
        }
    }

    private func shouldRetryPostPublish(_ post: FeedPost, error: Error) -> Bool {
        if let backendError = error as? BackendClientError {
            switch backendError {
            case .httpStatus(let code, let message):
                // Retry transient/network/auth/session style failures.
                if code == 408 || code == 409 || code == 425 || code == 429 {
                    return true
                }
                if code == 401 {
                    let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if reason.contains("missing authorization") {
                        // Missing auth header can still be recoverable when we have a refresh
                        // token or a stored bootstrap candidate for the active account context.
                        return hasLocallyUsableAuthToken()
                            || hasRefreshTokenForBackendSync()
                            || hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
                    }
                    // Request-level auth refresh/recovery already ran in this flow.
                    // Invalid JWT style 401s should fail fast and prompt reauthentication.
                    return false
                }
                if (500...599).contains(code) {
                    return true
                }
                return false
            case .requestFailed, .decodingFailed, .missingUploadedAssetReference:
                return true
            case .invalidBaseURL:
                return false
            }
        }
        if error is PostPublishError {
            if case .video = post.mediaPreview {
                return false
            }
            return true
        }
        return true
    }

    private func publishAttemptPolicy(for post: FeedPost) -> (maxAttempts: Int, timeoutPerAttempt: TimeInterval) {
        switch post.mediaPreview {
        case .text:
            return (maxAttempts: 1, timeoutPerAttempt: 18)
        case .photo:
            return (maxAttempts: 2, timeoutPerAttempt: 45)
        case .video:
            if post.isAudioPost {
                // Podcasts are audio-only files stored via the video pipeline.
                // They can be large (long episodes) so give extra time with one retry.
                return (maxAttempts: 2, timeoutPerAttempt: 240)
            }
            // Avoid duplicate full-video uploads on retry; prefer one authoritative attempt.
            return (maxAttempts: 1, timeoutPerAttempt: 90)
        }
    }

    private func shouldRetryCreatePostAttempt(after error: Error) -> Bool {
        if isAuthenticationFailureError(error) {
            return false
        }
        guard let backendError = error as? BackendClientError else {
            return true
        }
        switch backendError {
        case .httpStatus(let code, _):
            if code == 408 || code == 409 || code == 425 || code == 429 {
                return true
            }
            if (500...599).contains(code) {
                return true
            }
            return false
        case .requestFailed, .decodingFailed, .missingUploadedAssetReference:
            return true
        case .invalidBaseURL:
            return false
        }
    }

    private func publishAttemptBackoffNanos(for attempt: Int) -> UInt64 {
        let clampedAttempt = max(1, attempt)
        let baseDelaySeconds: Double = 0.45
        let delaySeconds = baseDelaySeconds * pow(2.0, Double(clampedAttempt - 1))
        return UInt64(delaySeconds * 1_000_000_000)
    }

    private func shouldRetryBackendWriteAttempt(after error: Error) -> Bool {
        if isBackendWritePreflightError(error) {
            return false
        }
        if isFounderPermissionDeniedError(error) {
            return false
        }
        if isTerminalAuthFailureForBackendWrite(error) {
            return false
        }
        if isConsumedRefreshTokenError(error) {
            return false
        }
        if isAuthenticationFailureError(error) {
            return true
        }
        if error is PostPublishError {
            return true
        }
        guard let backendError = error as? BackendClientError else {
            return true
        }
        switch backendError {
        case .httpStatus(let code, _):
            if code == 408 || code == 409 || code == 425 || code == 429 {
                return true
            }
            if (500...599).contains(code) {
                return true
            }
            return false
        case .requestFailed, .decodingFailed, .missingUploadedAssetReference:
            return true
        case .invalidBaseURL:
            return false
        }
    }

    private func performAuthenticatedBackendWrite(
        operationName: String,
        debugContext: BackendWriteDebugContext? = nil,
        maxAttempts: Int = 2,
        timeoutPerAttempt: TimeInterval = 20,
        operation: @escaping (_ authTokenOverride: String?) async throws -> Void
    ) async throws {
        let attempts = max(1, maxAttempts)
        var lastError: Error?
        for attempt in 1...attempts {
            let preferRefresh = attempt > 1
            var authTokenOverride = !preferRefresh ? currentUsableAuthTokenForWrite() : nil
            if authTokenOverride == nil {
                _ = await ensureBackendSessionForCurrentUser(preferRefresh: preferRefresh)
                authTokenOverride = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                    expectedSubjectUserID: currentUser.id
                )
            }
            if let debugContext {
                let authSnapshot = currentAuthSnapshotForSyncDebug()
                emitBackendWriteDebug(
                    debugContext,
                    stage: "\(debugContext.action)_attempt_\(attempt)_request",
                    status: "\(debugContext.action) attempt \(attempt)/\(attempts) started",
                    detail: "timeout=\(Int(timeoutPerAttempt))s, prefer_refresh=\(preferRefresh ? "yes" : "no"), auth_override=\(authTokenOverride == nil ? "no" : "yes")",
                    authPreflight: authSnapshot
                )
            }
            do {
                guard let authTokenOverride,
                      !authTokenOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    if let recoveryFailure = backendClient.consumeLastAuthTokenRecoveryFailureForDebug() {
                        throw recoveryFailure
                    }
                    throw BackendWritePreflightError.missingSessionToken(operationName: operationName)
                }
                try await withTimeout(seconds: timeoutPerAttempt) {
                    try await operation(authTokenOverride)
                }
                if let debugContext {
                    emitBackendWriteDebug(
                        debugContext,
                        stage: "\(debugContext.action)_attempt_\(attempt)_success",
                        status: "\(debugContext.action) attempt \(attempt)/\(attempts) succeeded",
                        detail: "Backend write acknowledged."
                    )
                }
                return
            } catch {
                lastError = error
                let terminalAuthFailure = isTerminalAuthFailureForBackendWrite(error)
                let shouldRetry = attempt < attempts && shouldRetryBackendWriteAttempt(after: error)
                let founderPermissionDenied = isFounderPermissionDeniedError(error)
                if founderPermissionDenied {
                    noteFounderClaimMismatchSignal(error)
                }
                if let debugContext {
                    emitBackendWriteDebug(
                        debugContext,
                        stage: "\(debugContext.action)_attempt_\(attempt)_failed",
                        status: "\(debugContext.action) attempt \(attempt)/\(attempts) failed",
                        detail: shouldRetry ? "Retrying after backoff." : "No more retries; throwing failure.",
                        error: error
                    )
                }
                if isAuthenticationFailureError(error) && founderPermissionDenied == false {
                    recordAuthFailure(
                        error,
                        context: "\(operationName) terminal auth failure",
                        recovery: terminalAuthFailure
                            ? "Terminal auth failure; waiting for reauthentication"
                            : "Attempting active-session recovery"
                    )
                    if let debugContext {
                        emitBackendWriteDebug(
                            debugContext,
                            stage: terminalAuthFailure
                                ? "\(debugContext.action)_auth_recovery_skipped_terminal"
                                : "\(debugContext.action)_auth_recovery",
                            status: terminalAuthFailure
                                ? "Skipped auth recovery for terminal auth failure"
                                : "Attempting auth recovery for \(debugContext.action)",
                            detail: terminalAuthFailure
                                ? "Auth recovery is terminal for this error and was short-circuited."
                                : "Auth failure detected during backend write.",
                            error: error
                        )
                    }
                    if terminalAuthFailure == false {
                        _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
                        restoreBackendAuthTokenForCurrentUserIfNeeded()
                    }
                } else if founderPermissionDenied, let debugContext {
                    emitBackendWriteDebug(
                        debugContext,
                        stage: "\(debugContext.action)_permission_denied",
                        status: "Permission denied for \(debugContext.action)",
                        detail: "Skipping auth recovery because backend denied Founder role/permission.",
                        error: error
                    )
                }
                if shouldRetry == false {
                    throw error
                }
                let backoff = publishAttemptBackoffNanos(for: attempt)
                try? await Task.sleep(nanoseconds: backoff)
            }
        }
        if let lastError {
            if isAuthenticationFailureError(lastError) && isFounderPermissionDeniedError(lastError) == false {
                let shouldClearStoredTokens = shouldClearStoredSessionTokensForAuthFailure(lastError)
                let preserveRefreshToken = shouldPreserveRefreshTokenAfterAuthFailure(lastError)
                recordAuthFailure(
                    lastError,
                    context: "\(operationName) unrecoverable auth failure",
                    recovery: shouldClearStoredTokens
                        ? "Prompt reauthentication without forced logout"
                        : "Retain stored session; retry auth recovery"
                )
                if shouldClearStoredTokens {
                    clearStoredSessionTokensForReauthentication(preserveRefreshToken: preserveRefreshToken)
                    moderationErrorMessage = "Auth expired during sync. Please sign in again, then retry."
                } else {
                    moderationErrorMessage = "Auth is temporarily unavailable for sync. Please retry."
                }
            }
            if let debugContext {
                emitBackendWriteDebug(
                    debugContext,
                    stage: "\(debugContext.action)_terminal_failure",
                    status: "\(debugContext.action) failed after \(attempts) attempts",
                    detail: "Backend write exhausted retries.",
                    error: lastError
                )
            }
            throw lastError
        }
    }

    private func hasRefreshTokenForBackendSync() -> Bool {
        let activeRefresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isAttemptableRefreshCredential(activeRefresh) {
            return true
        }
        let targetUsername = resolvedBackendSessionUsername()
        if let byUsername = LocalAuthStore.sessionRecord(forUsername: targetUsername) {
            let refresh = byUsername.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isAttemptableRefreshCredential(refresh) {
                return true
            }
        }
        if let byID = LocalAuthStore.sessionRecords().first(where: { $0.id == currentUser.id }) {
            let refresh = byID.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isAttemptableRefreshCredential(refresh) {
                return true
            }
        }
        return false
    }


    private func hasRecoverableSessionCandidateForBackendSync(preferRefresh: Bool = false) -> Bool {
        BackendTruthSyncCore.hasRecoverableSessionCandidate(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            preferRefresh: preferRefresh
        )
    }

    private func isPlausibleRefreshCredential(_ value: String?) -> Bool {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return false
        }
        guard trimmed.count >= 8, trimmed.count <= 4096 else { return false }
        guard !trimmed.contains(where: { $0.isWhitespace }) else { return false }
        return true
    }

    private func isAttemptableRefreshCredential(_ value: String?) -> Bool {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return false
        }
        guard isPlausibleRefreshCredential(trimmed) else { return false }
        return trimmed.count >= 24
    }

    private func refreshAttemptRejectionReason(_ value: String?) -> String {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return "empty"
        }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return "contains_whitespace"
        }
        if trimmed.count < 8 {
            return "too_short_plausibility_gate"
        }
        if trimmed.count > 4096 {
            return "too_long"
        }
        if trimmed.count < 24 {
            return "too_short_attempt_gate"
        }
        return "none"
    }

    @MainActor
    private func schedulePostBackendRetry(_ post: FeedPost) {
        guard pendingPublishRetryTasks[post.id] == nil else { return }
        if !hasLocallyUsableAuthToken()
            && !hasRefreshTokenForBackendSync()
            && !hasRecoverableSessionCandidateForBackendSync(preferRefresh: true) {
            updatePublishDebug(
                postID: post.id,
                stage: "retry_not_scheduled_no_session",
                status: "Background retry not scheduled",
                detail: "No usable token or refresh token is available. Waiting for reauthentication.",
                retry: "Not scheduled: missing session credentials"
            )
            markPostPublishFailed(
                post.id,
                message: "Sync paused until you sign in again."
            )
            moderationErrorMessage = "Session credentials are missing. Sign in again to resume post sync."
            return
        }
        updatePublishDebug(
            postID: post.id,
            stage: "retry_pending",
            status: "Background retry queued for \(post.id.uuidString.prefix(8))",
            detail: "Retry worker created and waiting to run.",
            retry: "Queued"
        )
        let retryTask = Task {  [weak self] in
            guard let self else { return }
            var lastRetryErrorDescription: String?
            defer {
                Task { @MainActor [weak self] in
                    self?.pendingPublishRetryTasks[post.id] = nil
                }
            }

            let retryDelaysNanos: [UInt64] = [
                2_000_000_000,
                6_000_000_000,
                14_000_000_000,
                // Extended window for auth-recovery scenarios (token expired overnight,
                // cold-start race against session self-heal, etc.).  performAuthSessionSelfHealIfNeeded
                // typically completes within ~15 s of app launch, so 45 s is a safe margin.
                45_000_000_000,
            ]

            for (attemptIndex, delay) in retryDelaysNanos.enumerated() {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: delay)
                let stillPending = await MainActor.run {
                    self.postPublishDeliveryStates[post.id] != nil
                }
                if !stillPending {
                    return
                }
                await MainActor.run {
                    self.updatePublishDebug(
                        postID: post.id,
                        stage: "retry_attempt_\(attemptIndex + 1)",
                        status: "Retry \(attemptIndex + 1)/\(retryDelaysNanos.count) in progress...",
                        detail: "Running background retry attempt \(attemptIndex + 1).",
                        retry: "Attempt \(attemptIndex + 1) of \(retryDelaysNanos.count)"
                    )
                }
                _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
                let retryPolicy = self.publishAttemptPolicy(for: post)
                do {
                    try await self.publishPostToBackend(
                        post,
                        author: post.user,
                        maxAttempts: retryPolicy.maxAttempts,
                        timeoutPerAttempt: retryPolicy.timeoutPerAttempt,
                        onAttemptStart: { [weak self] attempt, total in
                            guard let self else { return }
                            self.updatePublishDebug(
                                postID: post.id,
                                stage: "retry_backend_attempt_\(attempt)",
                                status: "Retry backend attempt \(attempt)/\(total) for \(post.id.uuidString.prefix(8))",
                                detail: "Running backend create call from retry worker."
                            )
                        },
                        onAttemptFailure: { [weak self] attempt, total, error in
                            guard let self else { return }
                            self.updatePublishDebug(
                                postID: post.id,
                                stage: "retry_backend_attempt_failed_\(attempt)",
                                status: "Retry backend attempt \(attempt)/\(total) failed",
                                detail: "Retry worker create call failed before acknowledgement.",
                                error: error
                            )
                        }
                    )
                    await MainActor.run {
                        self.markPostBackendAcknowledged(post.id)
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "retry_succeeded",
                            status: "Background publish accepted \(post.id.uuidString.prefix(8))",
                            detail: "Background retry succeeded and sync state is clear.",
                            retry: "Succeeded on attempt \(attemptIndex + 1)"
                        )
                        self.moderationErrorMessage = nil
                    }
                    Task {  [weak self] in
                        await self?.syncFromBackendIfAvailable(lane: .publishFollowUp)
                    }
                    return
                } catch {
                    if self.isAuthenticationFailureError(error) {
                        // Auth failures are almost always transient on first open after a long
                        // sleep — the token is expired but a refresh token still exists and the
                        // self-heal hasn't finished yet.  Continue through all retry windows
                        // (including the extended 45 s one) so the session has time to recover
                        // before we give up.  Only mark the post permanently failed if every
                        // attempt — including the 45 s attempt — returns an auth error.
                        let isLastAttempt = attemptIndex == retryDelaysNanos.count - 1
                        await MainActor.run {
                            self.updatePublishDebug(
                                postID: post.id,
                                stage: isLastAttempt
                                    ? "retry_auth_failure_all_attempts_exhausted"
                                    : "retry_auth_failure_will_retry",
                                status: isLastAttempt
                                    ? "Retry stopped after all attempts: \(self.describeBackendError(error))"
                                    : "Auth failure on attempt \(attemptIndex + 1) — session recovery pending, retrying",
                                detail: "Background retry auth failure. is_last_attempt=\(isLastAttempt ? "yes" : "no"), attempt=\(attemptIndex + 1)/\(retryDelaysNanos.count).",
                                error: error,
                                retry: isLastAttempt ? "All attempts exhausted" : "Will retry after extended delay"
                            )
                        }
                        lastRetryErrorDescription = self.describeBackendError(error)
                        if isLastAttempt { break }
                        continue
                    }
                    await MainActor.run {
                        lastRetryErrorDescription = self.describeBackendError(error)
                        self.updatePublishDebug(
                            postID: post.id,
                            stage: "retry_failed_\(attemptIndex + 1)",
                            status: "Retry \(attemptIndex + 1) failed: \(self.describeBackendError(error))",
                            detail: "Background retry attempt \(attemptIndex + 1) failed.",
                            error: error,
                            retry: "Attempt \(attemptIndex + 1) failed of \(retryDelaysNanos.count)"
                        )
                    }
                }
            }

            await MainActor.run {
                let failureMessage = lastRetryErrorDescription.map { "Retries exhausted. Last error: \($0)" }
                    ?? "Still waiting on backend sync. Keep the app open and connected."
                self.markPostPublishFailed(
                    post.id,
                    message: failureMessage
                )
                self.updatePublishDebug(
                    postID: post.id,
                    stage: "retry_exhausted",
                    status: "Background retries exhausted for \(post.id.uuidString.prefix(8))",
                    detail: "All retry attempts failed; post remains in failed sync state.",
                    retry: "Exhausted all 3 attempts"
                )
                self.moderationErrorMessage = "Post is still pending backend sync. Keep the app open and connected to finish."
            }
        }
        pendingPublishRetryTasks[post.id] = retryTask
    }

    @MainActor
    private func resumePendingMediaPostUploadsIfNeeded() {
        guard backendClient.isEnabled else { return }
        let candidates = posts.filter { shouldPersistPostInPendingMediaCache($0) }
        guard !candidates.isEmpty else { return }
        for post in candidates {
            markPostPublishPending(post.id)
            schedulePostBackendRetry(post)
        }
    }

    private func removePostForCatalogRotation(_ post: FeedPost) {
        markPostDeleted(post.id)
        adSubmissionPostIDs.remove(post.id)
        adSubmissionsByPostID.removeValue(forKey: post.id)
        curatedAdSlotIDs = curatedAdSlotIDs.map { $0 == post.id ? nil : $0 }
        saveCuratedAdSlots()
        normalizePinnedPosts()
        saveState()
        enqueuePendingDeletion(kind: .post, postID: post.id, authorID: post.user.id, post: post)
        Task {  [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    private func publishFromDraftPayload(
        _ payload: PostDraft.Payload,
        caption: String?,
        locationCity: String?,
        textFontStyle: ScrollPostFontStyle? = nil
    ) -> Bool {
        publishFromDraftPayload(
            payload,
            caption: caption,
            locationCity: locationCity,
            owner: currentUser,
            textFontStyle: textFontStyle
        )
    }

    private func publishFromDraftPayload(
        _ payload: PostDraft.Payload,
        caption: String?,
        locationCity: String?,
        owner: UserProfile,
        textFontStyle: ScrollPostFontStyle? = nil
    ) -> Bool {
        switch payload {
        case .media(let media):
            guard validateAllowedText(caption, context: "captions") else { return false }
            let post = FeedPost(
                id: UUID(),
                user: owner,
                caption: caption,
                websiteURL: nil,
                locationCity: locationCity,
                timestamp: Date(),
                mediaPreview: media,
                comments: [],
                rescrollOrigin: nil
            )
            return publish(post: post, mentionText: caption, mentionContext: "a scroll")
        case .text(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard validateAllowedText(trimmed, context: "text Scrolls") else { return false }
            let post = FeedPost(
                id: UUID(),
                user: owner,
                caption: nil,
                websiteURL: nil,
                locationCity: locationCity,
                timestamp: Date(),
                mediaPreview: .text(trimmed, fontStyle: textFontStyle ?? .original),
                comments: [],
                rescrollOrigin: nil
            )
            return publish(post: post, mentionText: trimmed, mentionContext: "a text Scroll")
        case .article:
            return false
        }
    }

    private func startScheduledPublishingLoop() {
        scheduledPublishingTask?.cancel()
        scheduledPublishingTask = Task {  [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.publishDueScheduledDrafts()
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    private func publishDueScheduledDrafts() {
        let now = Date()
        let dueDrafts = postDrafts.filter { ($0.scheduledAt ?? .distantFuture) <= now }
        guard !dueDrafts.isEmpty else { return }
        for draft in dueDrafts {
            guard let owner = draftOwnerProfile(for: draft) else { continue }
            if publishFromDraftPayload(
                draft.payload,
                caption: draft.caption,
                locationCity: draft.locationCity,
                owner: owner,
                textFontStyle: draft.textFontStyle
            ) {
                postDrafts.removeAll { $0.id == draft.id }
            }
        }
        saveState()
    }

    private func draftOwnerProfile(for draft: PostDraft) -> UserProfile? {
        if let ownerUserID = draft.ownerUserID, let owner = profileRegistry[ownerUserID] {
            return owner
        }
        return profileRegistry[currentUser.id] ?? currentUser
    }

    private func publishPostToBackend(
        _ post: FeedPost,
        author: UserProfile,
        maxAttempts: Int = 3,
        timeoutPerAttempt: TimeInterval = 60,
        authorizationTokenOverride: String? = nil,
        onAttemptStart: ((Int, Int) -> Void)? = nil,
        onAttemptFailure: ((Int, Int, Error) -> Void)? = nil
    ) async throws {
        // Do not key publish execution to delivery-state presence: ack/reconcile flows can clear it mid-publish.
        // The authoritative cancellation signal is an explicit local delete.
        guard !pendingDeletedPostIDs.contains(post.id) else { return }
        if inFlightBackendPublishPostIDs.contains(post.id) {
            throw BackendClientError.httpStatus(409, "Publish already in progress")
        }
        inFlightBackendPublishPostIDs.insert(post.id)
        defer {
            inFlightBackendPublishPostIDs.remove(post.id)
        }

        let overrideToken = authorizationTokenOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorScopedToken = authTokenForUser(author.id)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveAuthorizationTokenOverride: String? = {
            if let overrideToken, !overrideToken.isEmpty {
                return overrideToken
            }
            if author.id != currentUser.id, let authorScopedToken, !authorScopedToken.isEmpty {
                return authorScopedToken
            }
            return nil
        }()

        var lastError: Error?
        let attempts = max(1, maxAttempts)
        for attempt in 1...attempts {
            guard !pendingDeletedPostIDs.contains(post.id) else { return }
            onAttemptStart?(attempt, attempts)
            do {
                let result = try await withTimeout(seconds: timeoutPerAttempt) {
                    try await self.backendClient.createPost(
                        post,
                        timeoutInterval: timeoutPerAttempt,
                        authorizationTokenOverride: effectiveAuthorizationTokenOverride
                    )
                }
                if result.type == .photo || result.type == .video {
                    guard hasConfirmedRemoteAssetURL(result.remoteAssetRef) else {
                        throw BackendClientError.missingUploadedAssetReference
                    }
                }
                finalizePostMediaAfterSuccessfulUpload(postID: post.id, result: result)
                return
            } catch {
                lastError = error
                onAttemptFailure?(attempt, attempts, error)
                let shouldRetry = attempt < attempts && shouldRetryCreatePostAttempt(after: error)
                if !shouldRetry {
                    throw error
                }
                let delay = publishAttemptBackoffNanos(for: attempt)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        if let lastError {
            throw lastError
        }
    }

    private func hasConfirmedRemoteAssetURL(_ rawValue: String?) -> Bool {
        guard let raw = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || scheme == "http"
    }

    private func finalizePostMediaAfterSuccessfulUpload(postID: UUID, result: BackendCreatePostResult) {
        guard result.type == .photo || result.type == .video else { return }
        guard let remoteAssetRef = result.remoteAssetRef?.trimmingCharacters(in: .whitespacesAndNewlines),
              !remoteAssetRef.isEmpty,
              let remoteURL = URL(string: remoteAssetRef),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return
        }

        let resolvedAspectRatio: CGFloat = {
            if let aspect = result.aspectRatio, aspect.isFinite, aspect > 0 {
                return CGFloat(aspect)
            }
            if let existing = posts.first(where: { $0.id == postID }) {
                return existing.mediaPreview.aspectRatio
            }
            return 1
        }()

        let updatedMediaPreview: MediaPreview
        switch result.type {
        case .photo:
            updatedMediaPreview = .photo(
                PhotoPreview(
                    fileURL: remoteURL,
                    aspectRatio: resolvedAspectRatio,
                    assetIdentifier: remoteAssetRef
                )
            )
        case .video:
            updatedMediaPreview = .video(
                VideoPreview(
                    url: remoteURL,
                    aspectRatio: resolvedAspectRatio,
                    assetIdentifier: remoteAssetRef
                )
            )
        case .text:
            return
        }

        func remap(_ source: [FeedPost]) -> (mapped: [FeedPost], changed: Bool) {
            var didChange = false
            let mapped = source.map { item in
                guard item.id == postID, item.mediaPreview != updatedMediaPreview else {
                    return item
                }
                didChange = true
                return FeedPost(
                    id: item.id,
                    user: item.user,
                    caption: item.caption,
                    websiteURL: item.websiteURL,
                    locationCity: item.locationCity,
                    timestamp: item.timestamp,
                    mediaPreview: updatedMediaPreview,
                    coverImageRef: item.coverImageRef,
                    coverProvider: item.coverProvider,
                    coverBucket: item.coverBucket,
                    coverObjectKey: item.coverObjectKey,
                    comments: item.comments,
                    rescrollOrigin: item.rescrollOrigin
                )
            }
            return (mapped, didChange)
        }

        let postsRemap = remap(posts)
        if postsRemap.changed {
            posts = postsRemap.mapped
        }

        let pendingRemap = remap(pendingRemotePosts)
        if pendingRemap.changed {
            pendingRemotePosts = pendingRemap.mapped
        }

        let deliveredRemap = remap(deliveredAdPosts)
        if deliveredRemap.changed {
            deliveredAdPosts = deliveredRemap.mapped
        }

        if postsRemap.changed || pendingRemap.changed || deliveredRemap.changed {
            saveState()
        }
    }

    @MainActor
    private func applyUpdatedMediaPreview(
        postID: UUID,
        legacyRef: String,
        aspectRatio: CGFloat,
        assetProvider: String,
        assetBucket: String,
        assetObjectKey: String
    ) {
        let normalizedRef = legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRef.isEmpty,
              let remoteURL = URL(string: normalizedRef),
              let scheme = remoteURL.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return
        }

        let updatedMediaPreview: MediaPreview = .video(
            VideoPreview(
                url: remoteURL,
                aspectRatio: max(aspectRatio, 0.1),
                assetIdentifier: normalizedRef
            )
        )

        func remap(_ source: [FeedPost]) -> (mapped: [FeedPost], changed: Bool) {
            var didChange = false
            let mapped = source.map { item in
                guard item.id == postID else { return item }
                didChange = true
                return FeedPost(
                    id: item.id,
                    user: item.user,
                    caption: item.caption,
                    websiteURL: item.websiteURL,
                    locationCity: item.locationCity,
                    timestamp: item.timestamp,
                    mediaPreview: updatedMediaPreview,
                    coverImageRef: item.coverImageRef,
                    coverProvider: item.coverProvider,
                    coverBucket: item.coverBucket,
                    coverObjectKey: item.coverObjectKey,
                    assetProvider: assetProvider,
                    assetBucket: assetBucket,
                    assetObjectKey: assetObjectKey,
                    comments: item.comments,
                    rescrollOrigin: item.rescrollOrigin
                )
            }
            return (mapped, didChange)
        }

        let postsRemap = remap(posts)
        if postsRemap.changed {
            posts = postsRemap.mapped
        }

        let pendingRemap = remap(pendingRemotePosts)
        if pendingRemap.changed {
            pendingRemotePosts = pendingRemap.mapped
        }

        let deliveredRemap = remap(deliveredAdPosts)
        if deliveredRemap.changed {
            deliveredAdPosts = deliveredRemap.mapped
        }

        if postsRemap.changed || pendingRemap.changed || deliveredRemap.changed {
            saveState()
        }
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let timeoutNanos = UInt64(max(seconds, 1) * 1_000_000_000)
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanos)
                throw PostPublishError.timeout(seconds: Int(seconds))
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    private func authTokenForUser(_ userID: UUID) -> String? {
        authSessionForUser(userID)?.token
    }

    private func authSessionForUser(_ userID: UUID) -> (token: String, refreshToken: String?)? {
        if userID == currentUser.id {
            let activeToken = backendClient.currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let activeToken, !activeToken.isEmpty {
                return (activeToken, backendClient.currentRefreshToken())
            }
            if let byID = LocalAuthStore.sessionRecords().first(where: { $0.id == userID }) {
                let token = byID.token.trimmingCharacters(in: .whitespacesAndNewlines)
                let refresh = byID.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty || (refresh?.isEmpty == false) {
                    return (token, byID.refreshToken)
                }
            }
            return nil
        }
        if let byID = LocalAuthStore.sessionRecords().first(where: { $0.id == userID }) {
            let token = byID.token.trimmingCharacters(in: .whitespacesAndNewlines)
            let refresh = byID.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty || (refresh?.isEmpty == false) {
                return (token, byID.refreshToken)
            }
        }
        if let username = profileRegistry[userID].map({ normalizeUsername($0.username) }),
           let byUsername = LocalAuthStore.sessionRecords().first(where: { normalizeUsername($0.username) == username }) {
            let token = byUsername.token.trimmingCharacters(in: .whitespacesAndNewlines)
            let refresh = byUsername.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty || (refresh?.isEmpty == false) {
                return (token, byUsername.refreshToken)
            }
        }
        return nil
    }

    private func describeBackendError(_ error: Error) -> String {
        if let preflightError = error as? BackendWritePreflightError,
           let message = preflightError.errorDescription {
            return message
        }
        if let backendError = error as? BackendClientError {
            switch backendError {
            case .httpStatus(let code, let message):
                if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "HTTP \(code): \(message)"
                }
                return "HTTP \(code)"
            case .invalidBaseURL:
                return "Invalid backend URL"
            case .requestFailed:
                return "Request failed"
            case .decodingFailed:
                return "Decoding failed"
            case .missingUploadedAssetReference:
                return "Upload completed without a backend asset reference"
            }
        }
        let text = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Unknown error" : text
    }

    private func backendErrorDebugString(_ error: Error) -> String {
        if case let BackendWritePreflightError.missingSessionToken(operationName) = error {
            return "no_session_token: \(operationName)"
        }
        if let backendError = error as? BackendClientError {
            switch backendError {
            case .httpStatus(let code, let message):
                let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return reason.isEmpty ? "http_\(code)" : "http_\(code): \(reason)"
            case .invalidBaseURL:
                return "invalid_base_url"
            case .requestFailed:
                return "request_failed"
            case .decodingFailed:
                return "decoding_failed"
            case .missingUploadedAssetReference:
                return "missing_uploaded_asset_reference"
            }
        }
        let message = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            return String(describing: type(of: error))
        }
        return "\(type(of: error)): \(message)"
    }

    private func makePublishAuthSnapshot(
        sessionActive: Bool,
        usableToken: Bool? = nil,
        serverValidated: Bool? = nil
    ) -> String {
        let diagnostics = backendClient.currentAuthTokenDiagnostics()
        let tokenPresent = diagnostics.tokenPresent ? "yes" : "no"
        let refreshPresent = diagnostics.refreshTokenPresent ? "yes" : "no"
        let refreshTokenValue = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let refreshTokenLength = refreshTokenValue.count
        let refreshTokenPlausible = isPlausibleRefreshCredential(refreshTokenValue) ? "yes" : "no"
        let refreshTokenAttemptable = isAttemptableRefreshCredential(refreshTokenValue) ? "yes" : "no"
        let refreshRejectReason = refreshAttemptRejectionReason(refreshTokenValue)
        let tokenAlgorithm = diagnostics.tokenAlgorithm ?? "unknown"
        let subjectScope = authSubjectScopeDescription(subject: diagnostics.subject)
        let projectHost = diagnostics.projectHost ?? "unknown"
        let tokenIssuerHost = issuerHost(from: diagnostics.issuer) ?? "unknown"
        let usable: String
        if let usableToken {
            usable = diagnostics.tokenPresent ? (usableToken ? "yes" : "no") : "no"
        } else {
            usable = hasLocallyUsableAuthToken() ? "yes" : "no"
        }
        let hostMatch: String
        switch diagnostics.issuerHostMatchesProject {
        case .some(true):
            hostMatch = "yes"
        case .some(false):
            hostMatch = "no"
        case .none:
            hostMatch = "unknown"
        }
        let serverValidation = serverValidated == nil ? "unknown" : (serverValidated == true ? "yes" : "no")
        let recoveryDiagnostics = BackendTruthSyncCore.currentSessionRecoveryDiagnostics()
        let gateWait = recoveryDiagnostics.observedAt == nil ? "not_run" : "\(max(0, recoveryDiagnostics.authGateWaitMS))ms"
        let refreshFingerprint = recoveryDiagnostics.refreshTokenFingerprint
        let refreshOutcome = recoveryDiagnostics.refreshOutcome
        let sessionSource = recoveryDiagnostics.sessionRecordSource
        let candidateRejectionReason = recoveryDiagnostics.candidateRejectionReason
        let bootstrapCandidateCount = max(0, recoveryDiagnostics.bootstrapCandidateCount)
        let bootstrapExpectedUserID = recoveryDiagnostics.bootstrapExpectedUserID
        let bootstrapFallbackUsed = recoveryDiagnostics.bootstrapFallbackUsed ? "yes" : "no"
        return "session_active=\(sessionActive ? "yes" : "no"), usable_token=\(usable), server_validated=\(serverValidation), token=\(tokenPresent), refresh=\(refreshPresent), refresh_token_length=\(refreshTokenLength), refresh_token_plausible=\(refreshTokenPlausible), refresh_token_attemptable=\(refreshTokenAttemptable), refresh_reject_reason=\(refreshRejectReason), token_alg=\(tokenAlgorithm), issuer_host_match=\(hostMatch), issuer_host=\(tokenIssuerHost), project_host=\(projectHost), subject_scope=\(subjectScope), session_username=\(resolvedBackendSessionUsername()), auth_gate_wait_ms=\(gateWait), refresh_token_fingerprint=\(refreshFingerprint), refresh_outcome=\(refreshOutcome), session_record_source=\(sessionSource), candidate_rejection_reason=\(candidateRejectionReason), bootstrap_candidate_count=\(bootstrapCandidateCount), bootstrap_expected_user_id=\(bootstrapExpectedUserID), bootstrap_fallback_used=\(bootstrapFallbackUsed)"
    }

    private func isMissingAuthorizationHeaderError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else { return false }
        guard code == 401 else { return false }
        return (message ?? "").localizedCaseInsensitiveContains("missing authorization header")
    }

    private func isBackendWritePreflightError(_ error: Error) -> Bool {
        guard let preflightError = error as? BackendWritePreflightError else { return false }
        switch preflightError {
        case .missingSessionToken:
            return true
        }
    }

    private func isInvalidJWTError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else { return false }
        guard code == 401 else { return false }
        return (message ?? "").localizedCaseInsensitiveContains("invalid jwt")
    }

    private func isUnsupportedJWTAlgorithmError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else { return false }
        guard code == 400 || code == 401 || code == 403 else { return false }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !reason.isEmpty else { return false }
        return reason.contains("unsupported jwt algorithm")
    }

    private func isRefreshReturnedUnusableAccessTokenError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        guard code == 401 else { return false }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !reason.isEmpty else { return false }
        return reason.contains("refresh returned unusable access token")
    }

    private func isTerminalAuthFailureForBackendWrite(_ error: Error) -> Bool {
        if isBackendWritePreflightError(error) {
            return true
        }
        guard isAuthenticationFailureError(error) else {
            return false
        }
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if reason.isEmpty {
            return false
        }
        if code == 400 {
            return reason.contains("refresh token")
                || reason.contains("invalid_grant")
                || reason.contains("invalid grant")
                || reason.contains("auth refresh failed")
        }
        if code == 401 || code == 403 {
            return reason.contains("missing authorization")
                || reason.contains("invalid jwt")
                || reason.contains("jwt malformed")
                || reason.contains("jwt invalid")
                || reason.contains("token subject mismatch")
                || reason.contains("unsupported jwt algorithm")
        }
        return false
    }

    private func noteFounderClaimMismatchSignal(_ error: Error) {
        guard isFounderPermissionDeniedError(error) else { return }
        founderClaimMismatchSignalAt = Date()
    }

    private func resetFounderClaimMismatchTracking() {
        founderClaimMismatchSignalAt = nil
        founderClaimMismatchPromptShown = false
    }

    private func maybePresentFounderClaimMismatchPromptIfNeeded(_ profile: UserProfile) {
        guard profile.id == currentUser.id else { return }
        guard profile.isFounder else { return }
        guard founderClaimMismatchPromptShown == false else { return }
        guard let signalAt = founderClaimMismatchSignalAt else { return }
        if Date().timeIntervalSince(signalAt) > Self.founderClaimMismatchSignalTTL {
            founderClaimMismatchSignalAt = nil
            return
        }
        founderClaimMismatchPromptShown = true
        founderClaimMismatchSignalAt = nil
        moderationErrorMessage = "Your session needs to be refreshed to activate Founder features. Please log out and back in."
    }

    private func isFounderPermissionDeniedError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError,
              case let BackendClientError.httpStatus(code, message) = backendError,
              code == 401 || code == 403 else {
            return false
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard reason.isEmpty == false else { return false }
        return reason.contains("founder access required")
            || reason.contains("founder access")
            || reason.contains("permission denied")
            || reason.contains("forbidden")
    }

    private func isCuratedSlotDataError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError,
              case let BackendClientError.httpStatus(code, message) = backendError,
              code == 400 else {
            return false
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard reason.isEmpty == false else { return false }
        return reason.contains("ad submission not found for post")
            || reason.contains("only approved ads can be curated")
            || reason.contains("post not found")
            || reason.contains("schema cache")
            || reason.contains("could not find the")
    }

    private func isCircleScopeDeniedError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError,
              case let BackendClientError.httpStatus(code, message) = backendError,
              code == 401 else { return false }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return reason.contains("circle scope denied")
    }

    private func isAuthenticationFailureError(_ error: Error) -> Bool {
        if isMissingAuthorizationHeaderError(error) || isInvalidJWTError(error) {
            return true
        }
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        if code == 401 {
            return true
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if code == 400 && (
            reason.contains("auth refresh failed") ||
            reason.contains("refresh token") ||
            reason.contains("invalid_grant") ||
            reason.contains("invalid grant")
        ) {
            return true
        }
        if code == 403 && (
            reason.contains("authorization") ||
            reason.contains("jwt") ||
            reason.contains("token")
        ) {
            return true
        }
        return false
    }

    private func isConsumedRefreshTokenError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else {
            return false
        }
        guard case let BackendClientError.httpStatus(code, message) = backendError else {
            return false
        }
        guard code == 400 || code == 401 else {
            return false
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !reason.isEmpty else { return false }
        return reason.contains("refresh_token_already_used")
            || reason.contains("invalid refresh token: already used")
            || reason.contains("already used")
    }

    private func shouldPreserveRefreshTokenAfterAuthFailure(_ error: Error) -> Bool {
        // Session hardening rule: preserve refresh token on auth failures unless
        // backend reports an unsupported JWT algorithm for this session.
        if isUnsupportedJWTAlgorithmError(error) {
            return false
        }
        return true
    }

    private func isFeedRateLimitError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else { return false }
        guard case let .httpStatus(code, message) = backendError else { return false }
        if code == 429 { return true }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return reason.contains("rate limit")
            || reason.contains("over_request_rate_limit")
    }

    private func applyFeedRateLimitBackoff(window: TimeInterval) {
        let now = Date()
        let candidate = now.addingTimeInterval(max(1, window))
        if let existing = feedRateLimitBackoffUntil {
            feedRateLimitBackoffUntil = max(existing, candidate)
        } else {
            feedRateLimitBackoffUntil = candidate
        }
    }

    private func registerFeedRateLimitFailureAndResolveBackoffWindow() -> TimeInterval {
        consecutiveFeedRateLimitCount = min(consecutiveFeedRateLimitCount + 1, 6)
        let multiplier = pow(2.0, Double(max(0, consecutiveFeedRateLimitCount - 1)))
        return min(180, Self.feedRateLimitBackoffWindow * multiplier)
    }

    private func resetFeedRateLimitState() {
        consecutiveFeedRateLimitCount = 0
        feedRateLimitBackoffUntil = nil
    }

    private func feedRateLimitRemainingSeconds(now: Date = Date()) -> Int {
        guard let backoffUntil = feedRateLimitBackoffUntil else { return 0 }
        let remaining = backoffUntil.timeIntervalSince(now)
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining))
    }

    private func parseRetryAfterSeconds(_ raw: String?) -> Int? {
        guard let rawValue = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              rawValue.caseInsensitiveCompare("not available") != .orderedSame else {
            return nil
        }
        if let direct = Double(rawValue), direct > 0 {
            return Int(ceil(direct))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss zzz"
        if let date = formatter.date(from: rawValue) {
            let delta = date.timeIntervalSinceNow
            if delta > 0 {
                return Int(ceil(delta))
            }
        }
        return nil
    }

    private func backendWriteRateLimitCooldownRemainingSeconds(now: Date = Date()) -> Int {
        let diagnostics = backendClient.currentRateLimitDiagnostics()
        guard diagnostics.statusCode == 429 else {
            return feedRateLimitRemainingSeconds(now: now)
        }
        let retryAfter = parseRetryAfterSeconds(diagnostics.retryAfter)
            ?? Int(Self.feedRateLimitBackoffWindow)
        guard let observedAt = diagnostics.observedAt else {
            return max(retryAfter, feedRateLimitRemainingSeconds(now: now))
        }
        let elapsed = now.timeIntervalSince(observedAt)
        let remaining = Double(retryAfter) - elapsed
        let backendRemaining = remaining > 0 ? Int(ceil(remaining)) : 0
        return max(backendRemaining, feedRateLimitRemainingSeconds(now: now))
    }

    private func hydrateRateLimitDebugSnapshot(_ debug: inout FeedDebugStatus) {
        let diagnostics = backendClient.currentRateLimitDiagnostics()
        let remaining = feedRateLimitRemainingSeconds()
        debug.rateLimitEndpoint = diagnostics.endpointPath
        debug.rateLimitMethod = diagnostics.httpMethod
        if let statusCode = diagnostics.statusCode {
            debug.rateLimitStatusCode = "\(statusCode)"
        } else {
            debug.rateLimitStatusCode = "Not available"
        }
        debug.rateLimitRetryAfter = diagnostics.retryAfter
        debug.rateLimitLimit = diagnostics.limit
        debug.rateLimitRemaining = diagnostics.remaining
        debug.rateLimitReset = diagnostics.reset
        debug.rateLimitRequestID = diagnostics.requestID
        debug.rateLimitErrorCode = diagnostics.errorCode
        debug.rateLimitMessage = diagnostics.message
        debug.rateLimitObservedAt = diagnostics.observedAt
        debug.rateLimitClientCooldownActive = remaining > 0
        debug.rateLimitClientCooldownRemaining = "\(remaining)s"
        debug.rateLimitClientBackoffUntil = feedRateLimitBackoffUntil
        debug.rateLimitClientConsecutive429Count = consecutiveFeedRateLimitCount
    }

    private func hydrateSessionRecoveryDebugSnapshot(_ debug: inout FeedDebugStatus) {
        let diagnostics = BackendTruthSyncCore.currentSessionRecoveryDiagnostics()
        if diagnostics.observedAt != nil {
            debug.authGateWaitMS = "\(max(0, diagnostics.authGateWaitMS))ms"
            debug.refreshTokenFingerprint = diagnostics.refreshTokenFingerprint
            debug.refreshOutcome = diagnostics.refreshOutcome
            debug.sessionRecordSource = diagnostics.sessionRecordSource
            debug.bootstrapCandidateCount = "\(max(0, diagnostics.bootstrapCandidateCount))"
            debug.bootstrapExpectedUserID = diagnostics.bootstrapExpectedUserID
            debug.bootstrapFallbackUsed = diagnostics.bootstrapFallbackUsed ? "Yes" : "No"
        } else {
            debug.authGateWaitMS = "Not run yet"
            debug.refreshTokenFingerprint = "Not available"
            debug.refreshOutcome = "Not run yet"
            debug.sessionRecordSource = "Not run yet"
            debug.bootstrapCandidateCount = "Not run yet"
            debug.bootstrapExpectedUserID = "Not available"
            debug.bootstrapFallbackUsed = "Not run yet"
        }
    }

    private func recordAuthMutationRatePerMinute(
        _ diagnostics: BackendAuthSessionMutationDiagnostics,
        now: Date = Date()
    ) -> String {
        if let previous = lastAuthMutationSnapshot {
            let accessSetDelta = max(0, diagnostics.accessTokenSetCount - previous.accessTokenSetCount)
            let accessClearDelta = max(0, diagnostics.accessTokenClearCount - previous.accessTokenClearCount)
            let refreshSetDelta = max(0, diagnostics.refreshTokenSetCount - previous.refreshTokenSetCount)
            let refreshClearDelta = max(0, diagnostics.refreshTokenClearCount - previous.refreshTokenClearCount)
            let totalDelta = accessSetDelta + accessClearDelta + refreshSetDelta + refreshClearDelta
            if totalDelta > 0 {
                authMutationRateSamples.append(
                    AuthMutationRateSample(
                        at: now,
                        accessSet: accessSetDelta,
                        accessClear: accessClearDelta,
                        refreshSet: refreshSetDelta,
                        refreshClear: refreshClearDelta
                    )
                )
            }
        }
        lastAuthMutationSnapshot = diagnostics
        authMutationRateSamples = authMutationRateSamples.filter {
            now.timeIntervalSince($0.at) <= Self.authMutationRateWindow
        }
        let totals = authMutationRateSamples.reduce(into: (accessSet: 0, accessClear: 0, refreshSet: 0, refreshClear: 0)) {
            partial, sample in
            partial.accessSet += sample.accessSet
            partial.accessClear += sample.accessClear
            partial.refreshSet += sample.refreshSet
            partial.refreshClear += sample.refreshClear
        }
        let total = totals.accessSet + totals.accessClear + totals.refreshSet + totals.refreshClear
        return "total=\(total)/min, access_set=\(totals.accessSet)/min, access_clear=\(totals.accessClear)/min, refresh_set=\(totals.refreshSet)/min, refresh_clear=\(totals.refreshClear)/min"
    }

    private func feedRateLimitBackoffNanos(forAttempt attempt: Int) -> UInt64 {
        let clamped = max(1, attempt)
        let seconds = min(4.0, 0.8 * pow(2.0, Double(clamped - 1)))
        return UInt64(seconds * 1_000_000_000)
    }

    private func shouldClearStoredSessionTokensForAuthFailure(_ error: Error) -> Bool {
        // Session resilience rule:
        // keep refresh credentials whenever possible and avoid destructive clears
        // on transient/ambiguous auth failures. Explicit logout remains the only
        // guaranteed full-clear path.
        guard let backendError = error as? BackendClientError,
              case let BackendClientError.httpStatus(_, message) = backendError else {
            return false
        }
        let reason = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return reason.contains("unsupported jwt algorithm")
    }

    private func forceReauthentication() {
        backendClient.setAuthSession(
            token: nil,
            refreshToken: nil,
            source: "forceReauthentication"
        )
        LocalAuthStore.markExplicitLogout()
        UserDefaults.standard.set(false, forKey: "scrolls.auth.isAuthenticated")
        UserDefaults.standard.set("", forKey: "scrolls.auth.activeUsername")
        UserDefaults.standard.set(false, forKey: "scrolls.auth.needsFollowOnboarding")
        updateDebugStatus { status in
            status.authTokenPresent = false
            status.refreshTokenPresent = false
            status.lastAuthRecoveryAction = "Forced reauthentication"
        }
    }

    private func clearStoredSessionTokensForReauthentication(preserveRefreshToken: Bool = true) {
        // Collect every username variant that *might* refer to the current
        // account.  Account-switching drift means currentUser.username,
        // resolvedBackendSessionUsername(), and activeUsername UserDefaults
        // can briefly disagree.  We want to clear the active account's stored
        // tokens but never touch a sibling account's records.
        var candidateUsernames = Set<String>()
        let currentNormalized = normalizeUsername(currentUser.username)
        if !currentNormalized.isEmpty, currentNormalized != "you" {
            candidateUsernames.insert(currentNormalized)
        }
        let resolvedSession = resolvedBackendSessionUsername()
        if !resolvedSession.isEmpty, resolvedSession != "you" {
            candidateUsernames.insert(resolvedSession)
        }
        let active = Self.normalizedActiveUsername()
        if !active.isEmpty, active != "you" {
            candidateUsernames.insert(active)
        }
        if let byID = LocalAuthStore.sessionRecords().first(where: { $0.id == currentUser.id }) {
            let sessionUsername = normalizeUsername(byID.username)
            if !sessionUsername.isEmpty {
                candidateUsernames.insert(sessionUsername)
            }
        }
        // Defense in depth: only operate on session records whose user ID
        // matches the current account.  A candidate username that resolves to
        // a *different* account's record (because of account-switching drift
        // mid-failure) MUST NOT have its tokens cleared by this code path.
        let currentUserID = currentUser.id
        let allRecords = LocalAuthStore.sessionRecords()
        let recordsByUsername: [String: AuthSessionRecord] = Dictionary(
            uniqueKeysWithValues: allRecords.map { (normalizeUsername($0.username), $0) }
        )
        for username in candidateUsernames {
            guard let existingRecord = recordsByUsername[username] else { continue }
            // Only proceed if this record genuinely belongs to the current user.
            // Sentinel/fallback IDs (e.g. the placeholder ID before a real
            // profile lands) are excluded too — we never want to clobber a
            // record we're not certain we own.
            guard existingRecord.id == currentUserID else {
                LocalAuthStore.appendAuthPersistenceDebug(
                    "clear_session_skipped_other_account username=\(username) record_id=\(existingRecord.id.uuidString.prefix(8)) current_id=\(currentUserID.uuidString.prefix(8))"
                )
                continue
            }
            let preservedRefresh = existingRecord.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            LocalAuthStore.updateSessionTokens(
                matching: username,
                token: "",
                refreshToken: preserveRefreshToken
                    ? (isAttemptableRefreshCredential(preservedRefresh) ? existingRecord.refreshToken : nil)
                    : nil,
                preserveExistingRefreshIfMissing: preserveRefreshToken
            )
        }
        updateDebugStatus { status in
            status.authTokenPresent = false
            status.refreshTokenPresent = preserveRefreshToken
            status.lastAuthRecoveryAction = preserveRefreshToken
                ? "Cleared access token; preserved refresh token for recovery"
                : "Cleared stored access and refresh tokens for reauthentication"
        }
    }

    private func handleMissingAuthorizationHeaderIfUnrecoverable() -> Bool {
        let token = backendClient.currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let refresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasUsableToken = hasLocallyUsableAuthToken()
        let hasRefreshToken = !refresh.isEmpty
        let hasRecoverableCandidate = hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        updateDebugStatus { status in
            status.authTokenPresent = !token.isEmpty
            status.refreshTokenPresent = !refresh.isEmpty
        }
        if !hasUsableToken && !hasRefreshToken && !hasRecoverableCandidate {
            moderationErrorMessage = "Session auth is missing or expired for backend sync. Please log in again."
            updateDebugStatus { status in
                status.lastAuthFailure = "local_preflight_unusable_token"
                status.lastAuthFailureContext = "Missing authorization preflight"
                status.lastAuthRecoveryAction = "Prompting reauthentication"
                status.lastAuthFailureAt = Date()
            }
            return true
        }
        moderationErrorMessage = "Backend auth is temporarily unavailable. Please retry."
        updateDebugStatus { status in
            status.lastAuthFailure = "auth_temporarily_unavailable"
            status.lastAuthFailureContext = "Missing authorization preflight"
            if hasRefreshToken {
                status.lastAuthRecoveryAction = "Refresh token available; retry requested"
            } else if hasRecoverableCandidate {
                status.lastAuthRecoveryAction = "Stored session candidate available; retry requested"
            } else {
                status.lastAuthRecoveryAction = "Retry requested"
            }
            status.lastAuthFailureAt = Date()
        }
        return false
    }

    private func recordAuthFailure(
        _ error: Error,
        context: String,
        recovery: String
    ) {
        let diagnostics = backendClient.currentAuthTokenDiagnostics()
        updateDebugStatus { status in
            status.lastAuthFailure = backendErrorDebugString(error)
            status.lastAuthFailureContext = context
            status.lastAuthRecoveryAction = recovery
            status.lastAuthFailureAt = Date()
            status.resolvedSessionUsername = resolvedBackendSessionUsername()
            status.tokenAlgorithm = diagnostics.tokenAlgorithm ?? "Unknown"
            status.tokenSubjectScope = authSubjectScopeDescription(subject: diagnostics.subject)
        }
    }

    private func issuerHost(from issuer: String?) -> String? {
        guard let issuer,
              let issuerURL = URL(string: issuer),
              let host = issuerURL.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return nil
        }
        return host.lowercased()
    }

    private func isFounderScopedAuthContext() -> Bool {
        let normalizedCurrentUsername = normalizeUsername(currentUser.username)
        if currentUser.isFounder || Self.founderAuthSubjectIDs.contains(currentUser.id) || Self.founderAuthAliasUsernames.contains(normalizedCurrentUsername) {
            return true
        }
        return Self.founderManagedBusinessAccounts.contains { managed in
            managed.id == currentUser.id || normalizeUsername(managed.username) == normalizedCurrentUsername
        }
    }

    private func authSubjectScopeDescription(subject: String?) -> String {
        guard let subject = subject?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subject.isEmpty else {
            return "Missing subject"
        }
        guard let subjectID = UUID(uuidString: subject) else {
            return "Subject is not a UUID"
        }
        if subjectID == currentUser.id {
            return "Matches current user"
        }
        if Self.founderAuthSubjectIDs.contains(subjectID) {
            let normalizedCurrentUsername = normalizeUsername(currentUser.username)
            let founderManagedAccountContext = Self.founderManagedBusinessAccounts.contains {
                $0.id == currentUser.id || normalizeUsername($0.username) == normalizedCurrentUsername
            } || Self.founderAuthAliasUsernames.contains(normalizedCurrentUsername)
            if founderManagedAccountContext {
                return "Founder-scoped alias subject"
            }
        }
        return "Subject mismatch (token sub \(subjectID.uuidString.prefix(8))...)"
    }

    private func updatePublishDebug(
        postID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        recovery: String? = nil,
        retry: String? = nil,
        resetFlow: Bool = false
    ) {
        let postIDString = postID.uuidString
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastPublishPostID = postIDString
            debug.lastPublishStage = stage
            debug.lastPublishStatus = status
            debug.lastPublishDetail = detail
            if resetFlow {
                debug.lastPublishError = "None"
                debug.lastPublishRecovery = "Not attempted"
                debug.lastPublishRetry = "Not scheduled"
                debug.lastPublishAuthPreflight = "Not run yet"
                debug.publishSteps.removeAll()
            }
            if let errorString {
                debug.lastPublishError = errorString
            } else if stage.contains("acknowledged") || stage == "queued_local" {
                debug.lastPublishError = "None"
            }
            if let authPreflight {
                debug.lastPublishAuthPreflight = authPreflight
            }
            if let recovery {
                debug.lastPublishRecovery = recovery
            }
            if let retry {
                debug.lastPublishRetry = retry
            }
            debug.lastPublishAt = recordedAt

            let step = FeedDebugStatus.PublishStep(
                id: UUID(),
                recordedAt: recordedAt,
                postID: postIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight,
                recovery: recovery,
                retry: retry
            )
            debug.publishSteps.append(step)
            if debug.publishSteps.count > 80 {
                debug.publishSteps.removeFirst(debug.publishSteps.count - 80)
            }
        }
    }

    private func updateFeedDebug(
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        mergeSummary: String? = nil,
        visibilitySummary: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastFeedStage = stage
            debug.lastFeedFetchStatus = status
            debug.lastFeedDetail = detail
            if resetFlow {
                debug.lastFeedError = "None"
                debug.lastFeedAuthPreflight = "Not run yet"
                debug.lastFeedMergeSummary = "Not run yet"
                debug.lastFeedVisibilitySummary = "Not run yet"
                debug.feedSteps.removeAll()
            }
            if let errorString {
                debug.lastFeedError = errorString
            } else if stage.contains("success") || stage.contains("merge") || stage.contains("preflight") {
                debug.lastFeedError = "None"
            }
            if let authPreflight {
                debug.lastFeedAuthPreflight = authPreflight
            }
            if let mergeSummary {
                debug.lastFeedMergeSummary = mergeSummary
            }
            if let visibilitySummary {
                debug.lastFeedVisibilitySummary = visibilitySummary
            }
            debug.lastFeedFetchAt = recordedAt

            let step = FeedDebugStatus.FeedStep(
                id: UUID(),
                recordedAt: recordedAt,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.feedSteps.append(step)
            if debug.feedSteps.count > 120 {
                debug.feedSteps.removeFirst(debug.feedSteps.count - 120)
            }
        }
    }

    private func currentAuthSnapshotForSyncDebug() -> String {
        let usable = hasLocallyUsableAuthToken()
        return makePublishAuthSnapshot(
            sessionActive: usable,
            usableToken: usable,
            serverValidated: nil
        )
    }

    private func updateCommentDebug(
        commentID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        updateCommentDebug(
            commentIDString: commentID.uuidString,
            stage: stage,
            status: status,
            detail: detail,
            error: error,
            authPreflight: authPreflight,
            resetFlow: resetFlow
        )
    }

    private func updateCommentDebug(
        commentIDString: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastCommentSyncTargetID = commentIDString
            debug.lastCommentSyncStage = stage
            debug.lastCommentSyncStatus = status
            debug.lastCommentSyncDetail = detail
            if resetFlow {
                debug.lastCommentSyncError = "None"
                debug.lastCommentSyncAuthPreflight = "Not run yet"
                debug.commentSteps.removeAll()
            }
            if let errorString {
                debug.lastCommentSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastCommentSyncError = "None"
            }
            if let authPreflight {
                debug.lastCommentSyncAuthPreflight = authPreflight
            }
            debug.lastCommentSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: commentIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.commentSteps.append(step)
            if debug.commentSteps.count > 120 {
                debug.commentSteps.removeFirst(debug.commentSteps.count - 120)
            }
        }
    }

    private func updateCommentLikeDebug(
        commentID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        updateCommentLikeDebug(
            commentIDString: commentID.uuidString,
            stage: stage,
            status: status,
            detail: detail,
            error: error,
            authPreflight: authPreflight,
            resetFlow: resetFlow
        )
    }

    private func updateCommentLikeDebug(
        commentIDString: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastCommentLikeSyncTargetID = commentIDString
            debug.lastCommentLikeSyncStage = stage
            debug.lastCommentLikeSyncStatus = status
            debug.lastCommentLikeSyncDetail = detail
            if resetFlow {
                debug.lastCommentLikeSyncError = "None"
                debug.lastCommentLikeSyncAuthPreflight = "Not run yet"
                debug.commentLikeSteps.removeAll()
            }
            if let errorString {
                debug.lastCommentLikeSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastCommentLikeSyncError = "None"
            }
            if let authPreflight {
                debug.lastCommentLikeSyncAuthPreflight = authPreflight
            }
            debug.lastCommentLikeSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: commentIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.commentLikeSteps.append(step)
            if debug.commentLikeSteps.count > 120 {
                debug.commentLikeSteps.removeFirst(debug.commentLikeSteps.count - 120)
            }
        }
    }

    private func updateAdDebug(
        targetID: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastAdSyncTargetID = targetID
            debug.lastAdSyncStage = stage
            debug.lastAdSyncStatus = status
            debug.lastAdSyncDetail = detail
            if resetFlow {
                debug.lastAdSyncError = "None"
                debug.lastAdSyncAuthPreflight = "Not run yet"
                debug.adSteps.removeAll()
            }
            if let errorString {
                debug.lastAdSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastAdSyncError = "None"
            }
            if let authPreflight {
                debug.lastAdSyncAuthPreflight = authPreflight
            }
            debug.lastAdSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.adSteps.append(step)
            if debug.adSteps.count > 120 {
                debug.adSteps.removeFirst(debug.adSteps.count - 120)
            }
        }
    }

    private func updateRescrollDebug(
        postID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        updateRescrollDebug(
            postIDString: postID.uuidString,
            stage: stage,
            status: status,
            detail: detail,
            error: error,
            authPreflight: authPreflight,
            resetFlow: resetFlow
        )
    }

    private func updateRescrollDebug(
        postIDString: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastRescrollSyncTargetID = postIDString
            debug.lastRescrollSyncStage = stage
            debug.lastRescrollSyncStatus = status
            debug.lastRescrollSyncDetail = detail
            if resetFlow {
                debug.lastRescrollSyncError = "None"
                debug.lastRescrollSyncAuthPreflight = "Not run yet"
                debug.rescrollSteps.removeAll()
            }
            if let errorString {
                debug.lastRescrollSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastRescrollSyncError = "None"
            }
            if let authPreflight {
                debug.lastRescrollSyncAuthPreflight = authPreflight
            }
            debug.lastRescrollSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: postIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.rescrollSteps.append(step)
            if debug.rescrollSteps.count > 120 {
                debug.rescrollSteps.removeFirst(debug.rescrollSteps.count - 120)
            }
        }
    }

    private func updateProfileDebug(
        profileID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        updateProfileDebug(
            profileIDString: profileID.uuidString,
            stage: stage,
            status: status,
            detail: detail,
            error: error,
            authPreflight: authPreflight,
            resetFlow: resetFlow
        )
    }

    private func updateProfileDebug(
        profileIDString: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastProfileSyncTargetID = profileIDString
            debug.lastProfileSyncStage = stage
            debug.lastProfileSyncStatus = status
            debug.lastProfileSyncDetail = detail
            if resetFlow {
                debug.lastProfileSyncError = "None"
                debug.lastProfileSyncAuthPreflight = "Not run yet"
                debug.profileSteps.removeAll()
            }
            if let errorString {
                debug.lastProfileSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastProfileSyncError = "None"
            }
            if let authPreflight {
                debug.lastProfileSyncAuthPreflight = authPreflight
            }
            debug.lastProfileSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: profileIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.profileSteps.append(step)
            if debug.profileSteps.count > 120 {
                debug.profileSteps.removeFirst(debug.profileSteps.count - 120)
            }
        }
    }

    private func updateCircleMessageDebug(
        messageID: UUID,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        updateCircleMessageDebug(
            messageIDString: messageID.uuidString,
            stage: stage,
            status: status,
            detail: detail,
            error: error,
            authPreflight: authPreflight,
            resetFlow: resetFlow
        )
    }

    private func updateCircleMessageDebug(
        messageIDString: String,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        let errorString = error.map { backendErrorDebugString($0) }
        let recordedAt = Date()
        updateDebugStatus { debug in
            debug.lastCircleMessageSyncTargetID = messageIDString
            debug.lastCircleMessageSyncStage = stage
            debug.lastCircleMessageSyncStatus = status
            debug.lastCircleMessageSyncDetail = detail
            if resetFlow {
                debug.lastCircleMessageSyncError = "None"
                debug.lastCircleMessageSyncAuthPreflight = "Not run yet"
                debug.circleMessageSteps.removeAll()
            }
            if let errorString {
                debug.lastCircleMessageSyncError = errorString
            } else if stage.contains("queued") || stage.contains("acknowledged") || stage.contains("success") || stage.contains("request") {
                debug.lastCircleMessageSyncError = "None"
            }
            if let authPreflight {
                debug.lastCircleMessageSyncAuthPreflight = authPreflight
            }
            debug.lastCircleMessageSyncAt = recordedAt

            let step = FeedDebugStatus.SyncStep(
                id: UUID(),
                recordedAt: recordedAt,
                targetID: messageIDString,
                stage: stage,
                status: status,
                detail: detail,
                error: errorString,
                authPreflight: authPreflight
            )
            debug.circleMessageSteps.append(step)
            if debug.circleMessageSteps.count > 120 {
                debug.circleMessageSteps.removeFirst(debug.circleMessageSteps.count - 120)
            }
        }
    }

    private func emitBackendWriteDebug(
        _ context: BackendWriteDebugContext,
        stage: String,
        status: String,
        detail: String,
        error: Error? = nil,
        authPreflight: String? = nil,
        resetFlow: Bool = false
    ) {
        switch context.domain {
        case .comment:
            updateCommentDebug(
                commentIDString: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        case .commentLike:
            updateCommentLikeDebug(
                commentIDString: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        case .ad:
            updateAdDebug(
                targetID: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        case .rescroll:
            updateRescrollDebug(
                postIDString: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        case .profile:
            updateProfileDebug(
                profileIDString: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        case .circleMessage:
            updateCircleMessageDebug(
                messageIDString: context.targetID,
                stage: stage,
                status: status,
                detail: detail,
                error: error,
                authPreflight: authPreflight,
                resetFlow: resetFlow
            )
        }
    }

    private func updateDebugStatus(_ mutate: (inout FeedDebugStatus) -> Void) {
        var next = debugStatus
        mutate(&next)
        hydrateRateLimitDebugSnapshot(&next)
        hydrateSessionRecoveryDebugSnapshot(&next)
        // Bumped from 14 → 40 so the trail spans enough events to actually
        // diagnose "I went to sleep and woke up logged out" — the wake-up
        // sequence alone generates ~8-12 entries (foreground heal, refresh
        // attempt, keychain re-read, sticky-preserve check, etc.).  At
        // 14 entries those events would overwrite the smoking-gun events
        // that came before them.
        next.authPersistenceTrail = LocalAuthStore.authPersistenceDebugTrail(maxEntries: 40)
        debugStatus = next
        refreshPostSyncIndicator(reason: "debug_status_updated")
    }

    private func formattedMilliseconds(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return "\(max(0, rounded)) ms"
    }

    private func recordFeedRequestTelemetry(durationMS: Double, requestedLimit: Int, returnedCount: Int) {
        let isShortPage = returnedCount < requestedLimit
        feedShortPageSamples.append(isShortPage)
        if feedShortPageSamples.count > Self.feedShortPageTelemetryWindowSize {
            feedShortPageSamples.removeFirst(feedShortPageSamples.count - Self.feedShortPageTelemetryWindowSize)
        }
        let windowCount = max(1, feedShortPageSamples.count)
        let shortCount = feedShortPageSamples.reduce(into: 0) { count, sample in
            if sample { count += 1 }
        }
        let shortRate = Int((Double(shortCount) / Double(windowCount)) * 100.0)
        updateDebugStatus { status in
            status.lastFeedRequestDurationMS = formattedMilliseconds(durationMS)
            status.feedPageRequestCount += 1
            status.feedShortPageCount = shortCount
            status.feedShortPageRate = "\(shortCount)/\(windowCount) (\(shortRate)%)"
        }
    }

    private func recordFeedMergeTelemetry(durationMS: Double, source: RemotePostMergeSource, remoteCount: Int) {
        updateDebugStatus { status in
            status.lastFeedMergeDurationMS = "\(formattedMilliseconds(durationMS)) [\(source.debugLabel), remote=\(remoteCount)]"
        }
    }

    func recordFeedRenderRowAppearance(postID: UUID, feedKind: String) {
        let now = Date()
        let normalizedKind = feedKind.lowercased()
        let lastAppearAt: Date?
        if normalizedKind == "city" {
            lastAppearAt = lastCityFeedRowAppearAt
            lastCityFeedRowAppearAt = now
        } else {
            lastAppearAt = lastMainFeedRowAppearAt
            lastMainFeedRowAppearAt = now
        }
        guard let lastAppearAt else { return }
        let deltaMS = now.timeIntervalSince(lastAppearAt) * 1000
        guard deltaMS >= Self.feedRenderHitchThresholdMS else { return }
        updateDebugStatus { status in
            status.lastFeedRenderHitchCount += 1
            status.lastFeedRenderHitchMS = "\(formattedMilliseconds(deltaMS)) [\(normalizedKind), post=\(postID.uuidString.prefix(8))]"
            status.lastFeedRenderHitchAt = now
        }
    }

    private func refreshPostSyncIndicator(reason: String, force: Bool = false) {
        let now = Date()
        if !force, now.timeIntervalSince(lastPostSyncIndicatorUpdateAt) < 0.45 {
            return
        }

        let hasToken = hasLocallyUsableAuthToken()
        let hasRefresh = hasRefreshTokenForBackendSync()
        let hasRecoverableCandidate = hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        let hasRecoveryPath = hasRefresh || hasRecoverableCandidate
        let pendingCurrentUserWrites = pendingBackendWriteQueue.reduce(into: 0) { count, operation in
            if operation.userID == currentUser.id {
                count += 1
            }
        }
        let terminalBlocked = lastTerminalAuthFailureAt != nil && !hasToken && !hasRecoveryPath

        let state: PostSyncIndicatorState
        let summary: String
        if terminalBlocked || (!hasToken && !hasRecoveryPath) {
            state = .blocked
            summary = "Posting blocked"
        } else if pendingCurrentUserWrites > 0 || !hasToken || !hasRefresh {
            state = .recovering
            summary = "Recovering sync"
        } else {
            state = .ready
            summary = "Ready to post"
        }

        // Build a detail line that includes BOTH the immediate refresh
        // reason AND — when relevant — the last keychain hard-clear info.
        // Without this, the panel keeps showing `source=debug_status_updated`
        // (just the indicator update marker) which tells the user nothing
        // about which code path actually wiped their auth.  By surfacing
        // `lastClear=<source> at <time-ago>`, the user can immediately see
        // which path is responsible for repeated logouts.
        let mutationDiagnostics = backendClient.currentAuthSessionMutationDiagnostics()
        let refreshDiagnostics = backendClient.currentAuthRefreshDiagnostics()
        var detailParts: [String] = [
            "token=\(hasToken ? "yes" : "no")",
            "refresh=\(hasRefresh ? "yes" : "no")",
            "recoverable=\(hasRecoverableCandidate ? "yes" : "no")",
            "pending=\(pendingCurrentUserWrites)",
            "source=\(reason)"
        ]
        if refreshDiagnostics.lastRefreshFailureCode != "None" {
            detailParts.append("refreshCode=\(refreshDiagnostics.lastRefreshFailureCode)")
            if let terminal = refreshDiagnostics.lastRefreshFailureTerminal {
                detailParts.append("refreshTerminal=\(terminal ? "yes" : "no")")
            }
            if let revoked = refreshDiagnostics.lastRefreshFailureSessionRevoked {
                detailParts.append("sessionRevoked=\(revoked ? "yes" : "no")")
            }
        }
        if state == .blocked,
           !mutationDiagnostics.lastHardSessionClearSource.isEmpty,
           mutationDiagnostics.lastHardSessionClearSource != "Not run yet" {
            let clearedAgo: String
            if let clearedAt = mutationDiagnostics.lastHardSessionClearAt {
                let secondsAgo = max(0, Int(now.timeIntervalSince(clearedAt)))
                if secondsAgo < 60 {
                    clearedAgo = "\(secondsAgo)s ago"
                } else if secondsAgo < 3600 {
                    clearedAgo = "\(secondsAgo / 60)m ago"
                } else {
                    clearedAgo = "\(secondsAgo / 3600)h ago"
                }
            } else {
                clearedAgo = "unknown"
            }
            detailParts.append("lastClear=\(mutationDiagnostics.lastHardSessionClearSource) (\(clearedAgo))")
            detailParts.append("hardClears=\(mutationDiagnostics.hardSessionClearCount)")
        }
        let detail = detailParts.joined(separator: ", ")
        let next = PostSyncIndicator(
            state: state,
            summary: summary,
            detail: detail,
            updatedAt: now
        )
        if force || next != postSyncIndicator {
            postSyncIndicator = next
        }
        lastPostSyncIndicatorUpdateAt = now
        if postSyncIndicator.state == .blocked {
            startPostSyncAutoRecoveryIfNeeded()
        }
    }

    private func performAuthSessionSelfHealIfNeeded(trigger: String) async {
        guard backendClient.isEnabled else { return }
        if trigger == "startup" {
            authSelfHealStartupTriggerCount += 1
        } else if trigger == "foreground" {
            authSelfHealForegroundTriggerCount += 1
        }
        let tokenUsable = hasLocallyUsableAuthToken()
        let refreshPresent = hasRefreshTokenForBackendSync()
        let hasRecoverableCandidate = hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        let shouldAttemptServerValidation = trigger == "startup" || trigger == "foreground"
        if tokenUsable {
            if shouldAttemptServerValidation {
                let serverValidated = await backendClient.currentAuthTokenPassesServerValidation()
                if serverValidated {
                    updateDebugStatus { status in
                        status.lastAuthRecoveryAction = "Auth self-heal (\(trigger)) skipped; token server-validated"
                    }
                    return
                }
                updateDebugStatus { status in
                    status.lastAuthRecoveryAction = "Auth self-heal (\(trigger)) validation failed; attempting recovery"
                    status.lastAuthFailureAt = Date()
                }
            } else {
                updateDebugStatus { status in
                    status.lastAuthRecoveryAction = "Auth self-heal (\(trigger)) skipped; usable token already present"
                }
                return
            }
        }
        guard refreshPresent || hasRecoverableCandidate else {
            authSelfHealFailureCount += 1
            updateDebugStatus { status in
                status.lastAuthRecoveryAction = "Auth self-heal (\(trigger)) skipped; no refresh token or recoverable session candidate available"
                status.lastAuthFailureAt = Date()
            }
            return
        }
        let recovered = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        if recovered {
            authSelfHealSuccessCount += 1
        } else {
            authSelfHealFailureCount += 1
        }
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        updateDebugStatus { status in
            self.hydrateSessionRecoveryDebugSnapshot(&status)
            let outcome = status.refreshOutcome.trimmingCharacters(in: .whitespacesAndNewlines)
            status.lastAuthRecoveryAction = recovered
                ? "Auth self-heal (\(trigger)) recovered session"
                : "Auth self-heal (\(trigger)) could not recover session"
            if !outcome.isEmpty, outcome != "Not run yet" {
                status.lastAuthRecoveryAction += " [outcome=\(outcome)]"
            }
            status.lastAuthFailureAt = Date()
        }
        if recovered {
            lastTerminalAuthFailureAt = nil
            if pendingBackendWriteQueue.isEmpty == false {
                triggerPendingBackendWriteFlush(after: 0, force: true)
            }
            if postPublishDeliveryStates.isEmpty == false {
                resumePendingMediaPostUploadsIfNeeded()
            }
        }
    }

    private func restoreBackendAuthTokenForCurrentUserIfNeeded() {
        let updateAuthFlags: () -> Void = {
            self.updateDebugStatus { status in
                let diagnostics = self.backendClient.currentAuthTokenDiagnostics()
                let mutationDiagnostics = self.backendClient.currentAuthSessionMutationDiagnostics()
                let refreshDiagnostics = self.backendClient.currentAuthRefreshDiagnostics()
                status.authTokenPresent = diagnostics.tokenPresent
                status.refreshTokenPresent = diagnostics.refreshTokenPresent
                status.tokenIssuer = diagnostics.issuer ?? "Unknown"
                status.tokenIssuerHost = self.issuerHost(from: diagnostics.issuer) ?? "Unknown"
                status.tokenProjectHost = diagnostics.projectHost ?? "Unknown"
                status.tokenAlgorithm = diagnostics.tokenAlgorithm ?? "Unknown"
                status.tokenSubject = diagnostics.subject ?? "Unknown"
                status.tokenSubjectScope = self.authSubjectScopeDescription(subject: diagnostics.subject)
                status.resolvedSessionUsername = self.resolvedBackendSessionUsername()
                if let expiresAt = diagnostics.expiresAt {
                    status.tokenExpiry = DateFormatter.localizedString(from: expiresAt, dateStyle: .short, timeStyle: .medium)
                } else {
                    status.tokenExpiry = "Unknown"
                }
                switch diagnostics.issuerHostMatchesProject {
                case .some(true):
                    status.tokenHostMatch = "Yes"
                case .some(false):
                    status.tokenHostMatch = "No"
                case .none:
                    status.tokenHostMatch = "Unknown"
                }
                status.authTokenSetCount = mutationDiagnostics.accessTokenSetCount
                status.authTokenClearCount = mutationDiagnostics.accessTokenClearCount
                status.refreshTokenSetCount = mutationDiagnostics.refreshTokenSetCount
                status.refreshTokenClearCount = mutationDiagnostics.refreshTokenClearCount
                status.hardSessionClearCount = mutationDiagnostics.hardSessionClearCount
                status.lastHardSessionClearSource = mutationDiagnostics.lastHardSessionClearSource
                status.lastHardSessionClearAt = mutationDiagnostics.lastHardSessionClearAt
                status.refreshAttemptCount = refreshDiagnostics.refreshAttemptCount
                status.refreshSuccessCount = refreshDiagnostics.refreshSuccessCount
                status.refreshFailureCount = refreshDiagnostics.refreshFailureCount
                status.refreshLastFailureReason = refreshDiagnostics.lastRefreshFailureReason
                status.refreshLastFailureCode = refreshDiagnostics.lastRefreshFailureCode
                status.refreshLastFailureTerminal = refreshDiagnostics.lastRefreshFailureTerminal.map { $0 ? "Yes" : "No" } ?? "Unknown"
                status.refreshLastFailureSessionRevoked = refreshDiagnostics.lastRefreshFailureSessionRevoked.map { $0 ? "Yes" : "No" } ?? "Unknown"
                status.refreshLastAttemptSource = refreshDiagnostics.lastRefreshAttemptSource
                status.refreshLastTokenAgeMS = refreshDiagnostics.lastRefreshTokenAgeMS.map { "\($0)" } ?? "Unknown"
                status.refreshLastAttemptAt = refreshDiagnostics.lastRefreshAttemptAt
                status.refreshLastSuccessAt = refreshDiagnostics.lastRefreshSuccessAt
                status.refreshLastFailureAt = refreshDiagnostics.lastRefreshFailureAt
                status.authSelfHealStartupTriggerCount = self.authSelfHealStartupTriggerCount
                status.authSelfHealForegroundTriggerCount = self.authSelfHealForegroundTriggerCount
                status.authSelfHealSuccessCount = self.authSelfHealSuccessCount
                status.authSelfHealFailureCount = self.authSelfHealFailureCount
                status.authMutationRatePerMinute = self.recordAuthMutationRatePerMinute(mutationDiagnostics)
                status.lastAuthSessionMutation = mutationDiagnostics.lastMutation
                status.lastAuthSessionMutationAt = mutationDiagnostics.lastMutationAt
            }
        }
        let activeToken = backendClient.currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !activeToken.isEmpty, hasLocallyUsableAuthToken() {
            // Sync the current keychain refresh token back to LocalAuthStore if it has rotated.
            // resolvedAuthorizationToken() rotates the keychain token on every successful refresh
            // but does not update LocalAuthStore. If we leave LocalAuthStore holding the old token,
            // ensureActiveSession will overwrite the keychain with the stale value, causing an
            // "already used" failure that clears both stores and makes the session unrecoverable.
            let keychainRefresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isAttemptableRefreshCredential(keychainRefresh) {
                let sessionUsername = resolvedBackendSessionUsername()
                if let record = LocalAuthStore.sessionRecord(forUsername: sessionUsername) {
                    let storedRefresh = record.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if storedRefresh != keychainRefresh {
                        LocalAuthStore.updateSessionTokens(
                            matching: sessionUsername,
                            token: activeToken,
                            refreshToken: keychainRefresh
                        )
                    }
                }
            }
            updateAuthFlags()
            return
        }
        if !activeToken.isEmpty {
            // Drop stale/wrong-scope access tokens, but keep refresh for recovery.
            let activeRefresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
            backendClient.setAuthSession(
                token: nil,
                refreshToken: ((activeRefresh?.isEmpty == false) ? activeRefresh : nil),
                source: "restoreBackendAuthToken.drop_unusable_active_token"
            )
        }
        func apply(record: AuthSessionRecord) -> Bool {
            let token = record.token.trimmingCharacters(in: .whitespacesAndNewlines)
            let refresh = record.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty || isAttemptableRefreshCredential(refresh) else { return false }
            // Prefer refresh-only seeding so stale access tokens from local storage
            // do not keep reappearing between auth recovery attempts.
            if isAttemptableRefreshCredential(refresh) {
                let existingRefresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
                let refreshToSeed: String?
                if isAttemptableRefreshCredential(existingRefresh) {
                    refreshToSeed = existingRefresh
                } else {
                    refreshToSeed = refresh
                }
                let currentToken = backendClient.currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let currentRefresh = backendClient.currentRefreshToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let targetRefresh = refreshToSeed ?? ""
                if currentToken.isEmpty && currentRefresh == targetRefresh {
                    return true
                }
                backendClient.setAuthSession(
                    token: nil,
                    refreshToken: refreshToSeed,
                    source: "restoreBackendAuthToken.seed_refresh_only_record"
                )
                return true
            }
            // Do not reseed token-only records. They tend to reintroduce stale access
            // tokens and cause set/clear churn loops when refresh credentials are missing.
            // Recovery should be refresh-driven; token-only state prompts reauth.
            return false
        }
        if let byID = LocalAuthStore.sessionRecords().first(where: { $0.id == currentUser.id }) {
            if apply(record: byID) {
                updateAuthFlags()
                return
            }
        }
        if let byUsername = LocalAuthStore.sessionRecords().first(where: {
            normalizeUsername($0.username) == normalizeUsername(currentUser.username)
        }) {
            if apply(record: byUsername) {
                updateAuthFlags()
                return
            }
        }
        let accountEmail = LocalAuthStore.account(forUsername: currentUser.username)?.email.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !accountEmail.isEmpty,
           let byEmail = LocalAuthStore.sessionRecords().first(where: {
               $0.email.caseInsensitiveCompare(accountEmail) == .orderedSame
           }) {
            if apply(record: byEmail) {
                updateAuthFlags()
                return
            }
        }
        let normalizedCurrentUsername = normalizeUsername(currentUser.username)
        let canonicalFounderUsername = normalizeUsername(Self.founderCanonicalAccount.username)
        let isCanonicalFounderAuthContext =
            currentUser.id == Self.founderCanonicalAccount.id
            && normalizedCurrentUsername == canonicalFounderUsername
        // Founder-scoped fallback must only fire for the known managed-business
        // accounts (scrolls, gelanella, etc.) and the explicit alias IDs/usernames.
        // The original `currentUser.isFounder` branch was too broad — it let ANY
        // founder-flagged account use the founder session pool as a default, which
        // meant the canonical founder's session was silently brokered into
        // unrelated contexts.  We now require explicit membership in the managed
        // account list or the alias tables.
        let isKnownManagedAccount = Self.founderManagedBusinessAccounts.contains {
            $0.id == currentUser.id || normalizeUsername($0.username) == normalizedCurrentUsername
        }
        let allowFounderScopedSessionFallback = !isCanonicalFounderAuthContext && (
            isKnownManagedAccount
            || Self.founderAuthSubjectIDs.contains(currentUser.id)
            || Self.founderAuthAliasUsernames.contains(normalizedCurrentUsername)
        )
        if allowFounderScopedSessionFallback,
           let founderScopedSession = LocalAuthStore.sessionRecords().first(where: {
               let token = $0.token.trimmingCharacters(in: .whitespacesAndNewlines)
               let refresh = $0.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
               let hasCredentials = !token.isEmpty || isAttemptableRefreshCredential(refresh)
               // Prefer refresh-bearing founder sessions — token-only founder
               // sessions are stale and should not be used as a bridge.
               let founderScoped = $0.isFounder
                    || Self.founderAuthSubjectIDs.contains($0.id)
                    || Self.founderAuthAliasUsernames.contains(normalizeUsername($0.username))
               return founderScoped && hasCredentials && isAttemptableRefreshCredential($0.refreshToken)
           }) {
            if apply(record: founderScopedSession) {
                LocalAuthStore.appendAuthPersistenceDebug(
                    "founder_fallback_used current_user=\(normalizedCurrentUsername) fallback_from=\(normalizeUsername(founderScopedSession.username)) managed=\(isKnownManagedAccount ? "yes" : "no")"
                )
                updateAuthFlags()
                return
            }
        }
        if let scopedSession = LocalAuthStore.sessionRecords().first(where: { record in
            let token = record.token.trimmingCharacters(in: .whitespacesAndNewlines)
            let refresh = record.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !token.isEmpty || isAttemptableRefreshCredential(refresh) else { return false }
            return record.id == currentUser.id
                || normalizeUsername(record.username) == normalizeUsername(currentUser.username)
        }) {
            _ = apply(record: scopedSession)
        }

        if tokenOnlyBridgeSeedAttemptedUserID == currentUser.id,
           hasRefreshTokenForBackendSync() {
            tokenOnlyBridgeSeedAttemptedUserID = nil
        }

        let canTryTokenOnlyBridge =
            tokenOnlyBridgeSeedAttemptedUserID != currentUser.id
            && !hasRefreshTokenForBackendSync()
            && !hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        if canTryTokenOnlyBridge {
            tokenOnlyBridgeSeedAttemptedUserID = currentUser.id
            let tokenOnlyCandidates = LocalAuthStore.sessionRecords().filter { record in
                let token = record.token.trimmingCharacters(in: .whitespacesAndNewlines)
                let refresh = record.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else { return false }
                guard !isAttemptableRefreshCredential(refresh) else { return false }
                return record.id == currentUser.id
                    || normalizeUsername(record.username) == normalizeUsername(currentUser.username)
            }
            for candidate in tokenOnlyCandidates {
                let candidateToken = candidate.token.trimmingCharacters(in: .whitespacesAndNewlines)
                backendClient.setAuthSession(
                    token: candidateToken,
                    refreshToken: nil,
                    source: "restoreBackendAuthToken.token_only_bridge_fallback"
                )
                if hasLocallyUsableAuthToken() {
                    LocalAuthStore.appendAuthPersistenceDebug(
                        "token_only_bridge_seeded username=\(candidate.username), user_id=\(candidate.id.uuidString.uppercased()), token_len=\(candidateToken.count)"
                    )
                    updateAuthFlags()
                    return
                }
                backendClient.setAuthSession(
                    token: nil,
                    refreshToken: nil,
                    source: "restoreBackendAuthToken.token_only_bridge_rejected"
                )
            }
            LocalAuthStore.appendAuthPersistenceDebug(
                "token_only_bridge_failed username=\(currentUser.username), user_id=\(currentUser.id.uuidString.uppercased()), reason=no_locally_usable_token_candidate"
            )
        }

        updateAuthFlags()
    }

    private func ensureBackendSessionForCurrentUser(preferRefresh: Bool = false) async -> Bool {
        guard backendClient.isEnabled else { return false }
        if currentUsableAuthTokenForWrite() != nil {
            lastTerminalAuthFailureAt = nil
            return true
        }
        let sessionUsername = resolvedBackendSessionUsername()
        if !hasLocallyUsableAuthToken(),
           !hasRefreshTokenForBackendSync(),
           !BackendTruthSyncCore.hasRecoverableSessionCandidate(
                for: sessionUsername,
                expectedUserID: currentUser.id,
                preferRefresh: preferRefresh
           ) {
            return false
        }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastEnsureSessionStartedAt)
        if elapsed >= 0, elapsed < Self.ensureSessionCooldownFastLane {
            let remaining = Self.ensureSessionCooldownFastLane - elapsed
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        lastEnsureSessionStartedAt = Date()
        BackendTruthSyncCore.seedSessionForActiveUsername(
            sessionUsername,
            expectedUserID: currentUser.id,
            using: backendClient
        )
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: sessionUsername,
            expectedUserID: currentUser.id,
            using: backendClient,
            preferRefresh: preferRefresh
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        if hasLocallyUsableAuthToken() {
            lastTerminalAuthFailureAt = nil
            return true
        }
        let scopedToken = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
            expectedSubjectUserID: currentUser.id
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        let result = (scopedToken?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            && hasLocallyUsableAuthToken()
        if result {
            lastTerminalAuthFailureAt = nil
        }
        return result
    }

    private func currentUsableAuthTokenForWrite() -> String? {
        guard hasLocallyUsableAuthToken() else {
            return nil
        }
        let token = backendClient.currentAuthToken()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            return nil
        }
        return token
    }

    private func hasLocallyUsableAuthToken() -> Bool {
        let diagnostics = backendClient.currentAuthTokenDiagnostics()
        guard diagnostics.tokenPresent else {
            return false
        }
        guard diagnostics.issuerHostMatchesProject == true else {
            return false
        }
        guard let subject = diagnostics.subject?.trimmingCharacters(in: .whitespacesAndNewlines),
              !subject.isEmpty else {
            return false
        }
        guard isTokenSubjectCompatibleWithCurrentUser(subject) else {
            return false
        }
        guard let expiresAt = diagnostics.expiresAt else {
            return false
        }
        // Keep local session gating a little looser than write-time auth checks.
        // The app should not look logged out minutes before a token actually expires
        // if refresh recovery is still available.
        if expiresAt <= Date().addingTimeInterval(Self.localAuthTokenUsabilityLeewaySeconds) {
            return false
        }
        return true
    }

    private func isTokenSubjectCompatibleWithCurrentUser(_ subject: String) -> Bool {
        let trimmed = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let subjectID = UUID(uuidString: trimmed) else { return false }
        if subjectID == currentUser.id {
            return true
        }
        let currentUsername = normalizeUsername(currentUser.username)
        if let session = LocalAuthStore.sessionRecord(forUsername: currentUsername), session.id == subjectID {
            return true
        }
        if let account = LocalAuthStore.account(forUsername: currentUsername), account.id == subjectID {
            return true
        }
        if Self.founderAuthSubjectIDs.contains(subjectID) {
            let founderManagedAccountContext = Self.founderManagedBusinessAccounts.contains {
                $0.id == currentUser.id || normalizeUsername($0.username) == currentUsername
            } || Self.founderAuthAliasUsernames.contains(currentUsername)
            if founderManagedAccountContext {
                return true
            }
        }
        return false
    }

    private func resolvedBackendSessionUsername() -> String {
        let current = normalizeUsername(currentUser.username)
        if !current.isEmpty, current != "you" {
            return current
        }
        let active = Self.normalizedActiveUsername()
        if active != "you" {
            return active
        }
        if let fallback = LocalAuthStore.sessionRecords()
            .map(\.username)
            .map({ normalizeUsername($0) })
            .first(where: { !$0.isEmpty }) {
            return fallback
        }
        return current
    }

    private func ensureBackendFollowLinksForCurrentUser() async {
        guard backendClient.isEnabled else { return }

        var followees = followRelations[currentUser.id] ?? []
        var normalizedChanged = false
        if followees.contains(currentUser.id) {
            followees.remove(currentUser.id)
            normalizedChanged = true
        }

        let requiredFollowees = mandatoryFollowIDs().subtracting([currentUser.id])
        let missingRequired = requiredFollowees.subtracting(followees)
        if !missingRequired.isEmpty {
            followees.formUnion(missingRequired)
            normalizedChanged = true
            for followeeID in missingRequired {
                enqueuePendingFollowSync(
                    followerID: currentUser.id,
                    followeeID: followeeID,
                    isFollowing: true
                )
            }
        }

        if normalizedChanged {
            followRelations[currentUser.id] = followees
        }

        // Only flush what is already pending; do not re-enqueue all follows on refresh.
        if !pendingFollowSyncQueue.isEmpty {
            await flushPendingFollowSyncQueue()
        }
    }

    private func migrateDraftOwnershipIfNeeded() {
        var changed = false
        postDrafts = postDrafts.map { draft in
            guard draft.ownerUserID == nil else { return draft }
            var updated = draft
            updated.ownerUserID = currentUser.id
            changed = true
            return updated
        }
        if changed {
            saveState()
        }
    }

    func addComment(_ text: String, to post: FeedPost) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPostID = canonicalCommentThreadPostID(for: post)
        let targetIndices = commentThreadIndices(forCanonicalPostID: targetPostID, fallbackPostID: post.id)
        guard !trimmed.isEmpty, !targetIndices.isEmpty else {
            return
        }
        let authorProfile = currentUser
        guard recordSpamAction(
            key: "comment:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.commentLimit,
            window: Self.SpamProtectionMode.commentWindow,
            blockedMessage: "You're commenting too quickly. Please slow down."
        ) else { return }
        guard recordSpamText(
            key: "comment-text:\(currentUser.id.uuidString)",
            text: trimmed,
            limit: Self.SpamProtectionMode.duplicateTextLimit,
            window: Self.SpamProtectionMode.duplicateTextWindow,
            blockedMessage: "You're repeating the same comment too quickly."
        ) else { return }
        guard validateAllowedText(trimmed, context: "comments") else { return }
        let comment = PostComment(id: UUID(), user: currentUser, text: trimmed, timestamp: Date(), replies: [])
        updateCommentDebug(
            commentID: comment.id,
            stage: "queued_local",
            status: "Comment saved locally",
            detail: "post=\(targetPostID.uuidString.prefix(8)), chars=\(trimmed.count)",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        markCommentLocalCreated(comment.id)
        cachedCommentsFetchedAt.removeValue(forKey: targetPostID)
        for index in targetIndices where posts.indices.contains(index) {
            posts[index].comments.append(comment)
        }
        saveState()
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "comment_create",
                    debugContext: BackendWriteDebugContext(
                        domain: .comment,
                        targetID: comment.id.uuidString,
                        action: "comment_create"
                    ),
                    maxAttempts: 3,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.createComment(
                        postID: targetPostID,
                        authorID: authorProfile.id,
                        body: trimmed,
                        commentID: comment.id,
                        authTokenOverride: authTokenOverride
                    )
                }
                await MainActor.run {
                    self.markCommentBackendAcknowledged(comment.id)
                    self.notifyMentions(in: trimmed, context: "a comment", objectID: targetPostID)
                    self.updateCommentDebug(
                        commentID: comment.id,
                        stage: "backend_acknowledged",
                        status: "Comment synced",
                        detail: "Comment acknowledged by backend for post \(targetPostID.uuidString.prefix(8))."
                    )
                }
                await self.refreshCommentsFromBackendForCanonicalPostID(targetPostID, forceRefresh: true)
            } catch {
                await MainActor.run {
                    self.markCommentDeliveryError(comment.id, message: self.describeBackendError(error))
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .commentCreate,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: authorProfile.id,
                            postID: targetPostID,
                            authorID: authorProfile.id,
                            commentID: comment.id,
                            body: trimmed,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                    self.moderationErrorMessage = "Comment saved locally, but backend sync failed. Please refresh session if it doesn't persist."
                    self.updateCommentDebug(
                        commentID: comment.id,
                        stage: "queued_retry",
                        status: "Comment sync failed; queued for retry",
                        detail: "Operation queued locally for retry worker.",
                        error: error
                    )
                }
            }
        }
    }

    func addReply(_ text: String, to comment: PostComment, in post: FeedPost) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPostID = canonicalCommentThreadPostID(for: post)
        let targetIndices = commentThreadIndices(forCanonicalPostID: targetPostID, fallbackPostID: post.id)
        guard !trimmed.isEmpty, !targetIndices.isEmpty else {
            return
        }
        let authorProfile = currentUser
        guard recordSpamAction(
            key: "reply:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.replyLimit,
            window: Self.SpamProtectionMode.replyWindow,
            blockedMessage: "You're replying too quickly. Please slow down."
        ) else { return }
        guard recordSpamText(
            key: "reply-text:\(currentUser.id.uuidString)",
            text: trimmed,
            limit: Self.SpamProtectionMode.duplicateTextLimit,
            window: Self.SpamProtectionMode.duplicateTextWindow,
            blockedMessage: "You're repeating the same reply too quickly."
        ) else { return }
        guard validateAllowedText(trimmed, context: "replies") else { return }
        let reply = PostComment(id: UUID(), user: currentUser, text: trimmed, timestamp: Date(), replies: [])
        updateCommentDebug(
            commentID: reply.id,
            stage: "queued_local",
            status: "Reply saved locally",
            detail: "post=\(targetPostID.uuidString.prefix(8)), parent=\(comment.id.uuidString.prefix(8)), chars=\(trimmed.count)",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        markCommentLocalCreated(reply.id)
        cachedCommentsFetchedAt.removeValue(forKey: targetPostID)
        let referenceIndex = targetIndices[0]
        var updatedComments = posts[referenceIndex].comments
        let didAppend = appendReply(reply, to: comment.id, in: &updatedComments)
        guard didAppend else { return }
        for index in targetIndices where posts.indices.contains(index) {
            posts[index].comments = updatedComments
        }
        saveState()
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "comment_reply_create",
                    debugContext: BackendWriteDebugContext(
                        domain: .comment,
                        targetID: reply.id.uuidString,
                        action: "comment_reply_create"
                    ),
                    maxAttempts: 3,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.createComment(
                        postID: targetPostID,
                        authorID: authorProfile.id,
                        body: reply.text,
                        parentCommentID: comment.id,
                        commentID: reply.id,
                        authTokenOverride: authTokenOverride
                    )
                }
                await MainActor.run {
                    self.markCommentBackendAcknowledged(reply.id)
                    self.notifyMentions(in: reply.text, context: "a reply", objectID: targetPostID)
                    self.updateCommentDebug(
                        commentID: reply.id,
                        stage: "backend_acknowledged",
                        status: "Reply synced",
                        detail: "Reply acknowledged by backend for post \(targetPostID.uuidString.prefix(8))."
                    )
                }
                await self.refreshCommentsFromBackendForCanonicalPostID(targetPostID, forceRefresh: true)
            } catch {
                await MainActor.run {
                    self.markCommentDeliveryError(reply.id, message: self.describeBackendError(error))
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .commentCreate,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: authorProfile.id,
                            postID: targetPostID,
                            authorID: authorProfile.id,
                            commentID: reply.id,
                            body: reply.text,
                            parentCommentID: comment.id,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                    self.moderationErrorMessage = "Reply saved locally, but backend sync failed. Please refresh session if it doesn't persist."
                    self.updateCommentDebug(
                        commentID: reply.id,
                        stage: "queued_retry",
                        status: "Reply sync failed; queued for retry",
                        detail: "Operation queued locally for retry worker.",
                        error: error
                    )
                }
            }
        }
    }
    func deleteComment(_ comment: PostComment, in post: FeedPost) {
        let targetPostID = canonicalCommentThreadPostID(for: post)
        let targetIndices = commentThreadIndices(forCanonicalPostID: targetPostID, fallbackPostID: post.id)
        guard !targetIndices.isEmpty else { return }

        let requesterProfile = currentUser
        let commentAuthorID = comment.user.id
        let canDelete = commentAuthorID == requesterProfile.id
            || post.user.id == requesterProfile.id
            || requesterProfile.isFounder
        guard canDelete else { return }

        var updatedComments = posts[targetIndices[0]].comments
        guard removeComment(withID: comment.id, from: &updatedComments) else { return }
        cachedCommentsFetchedAt.removeValue(forKey: targetPostID)
        for index in targetIndices where posts.indices.contains(index) {
            posts[index].comments = updatedComments
        }
        updateCommentDebug(
            commentID: comment.id,
            stage: "delete_queued_local",
            status: "Comment removed locally",
            detail: "post=\(targetPostID.uuidString.prefix(8)); awaiting backend delete",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        saveState()
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "comment_delete",
                    debugContext: BackendWriteDebugContext(
                        domain: .comment,
                        targetID: comment.id.uuidString,
                        action: "comment_delete"
                    ),
                    maxAttempts: 2,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.deleteComment(
                        commentID: comment.id,
                        authorID: commentAuthorID,
                        requestedByID: requesterProfile.id,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                await MainActor.run {
                    self.enqueuePendingBackendWrite(
                        PendingBackendWriteOperation(
                            id: UUID(),
                            kind: .commentDelete,
                            createdAt: Date(),
                            retryCount: 0,
                            userID: requesterProfile.id,
                            postID: targetPostID,
                            authorID: commentAuthorID,
                            commentID: comment.id,
                            body: nil,
                            parentCommentID: nil,
                            originalPostID: nil,
                            rescrollPostID: nil,
                            circleID: nil,
                            messageID: nil,
                            encryptedText: nil,
                            messageTimestamp: nil
                        )
                    )
                    self.triggerPendingBackendWriteFlush(after: 0, force: true)
                    self.moderationErrorMessage = "Comment deletion failed to sync. Please retry after signing in again."
                    self.updateCommentDebug(
                        commentID: comment.id,
                        stage: "delete_queued_retry",
                        status: "Comment delete failed; queued for retry",
                        detail: "Delete operation queued locally.",
                        error: error
                    )
                }
            }
        }
    }

    func post(withID id: UUID) -> FeedPost? {
        posts.first(where: { $0.id == id })
    }

    func comments(for postID: UUID) -> [PostComment] {
        guard let sourcePost = post(withID: postID) else { return [] }
        let targetPostID = canonicalCommentThreadPostID(for: sourcePost)
        return post(withID: targetPostID)?.comments ?? sourcePost.comments
    }

    private func refreshCommentsAfterAccountSwitch() {
        let currentUsername = normalizeUsername(currentUser.username)
        guard currentUsername != lastCommentRefreshUsername else { return }
        lastCommentRefreshUsername = currentUsername
        cachedCommentsFetchedAt.removeAll()
        commentLikeOverrides.removeAll()
        commentsCacheOwnerUserID = currentUser.id

        Task {  [weak self] in
            guard let self else { return }
            let visiblePostIDs = Array(self.posts.prefix(30).map(\.id))
            for postID in visiblePostIDs {
                await self.refreshCommentsFromBackend(for: postID, forceRefresh: true)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
    }

    func refreshCommentsFromBackend(for displayedPostID: UUID, forceRefresh: Bool = false) async {
        guard backendClient.isEnabled else { return }
        guard let sourcePost = post(withID: displayedPostID) else { return }
        let targetPostID = canonicalCommentThreadPostID(for: sourcePost)
        _ = await refreshCommentsFromBackendForCanonicalPostID(
            targetPostID,
            forceRefresh: forceRefresh
        )
    }

    @discardableResult
    private func refreshCommentsFromBackendForCanonicalPostID(
        _ targetPostID: UUID,
        forceRefresh: Bool = false,
        skipSessionEnsure: Bool = false
    ) async -> CommentRefreshResult {
        guard backendClient.isEnabled else { return .skippedUnavailable }
        if commentsCacheOwnerUserID != currentUser.id {
            cachedCommentsFetchedAt.removeAll()
            commentsCacheOwnerUserID = currentUser.id
        }
        if !forceRefresh,
           let fetchedAt = cachedCommentsFetchedAt[targetPostID],
           Date().timeIntervalSince(fetchedAt) < BackendPollingCostSaverMode.commentsTTL {
            return .skippedCached
        }

        if !skipSessionEnsure {
            _ = await ensureBackendSessionForCurrentUser()
        }
        var fetched: [BackendComment]?
        var finalError: Error?
        var authTokenOverride = currentUsableAuthTokenForWrite()
        if authTokenOverride == nil {
            authTokenOverride = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                expectedSubjectUserID: currentUser.id
            )
        }
        do {
            fetched = try await backendClient.fetchComments(
                postID: targetPostID,
                includeAuthorization: true,
                allowAuthRetry: true,
                authTokenOverride: authTokenOverride
            )
        } catch {
            finalError = error
            if isAuthenticationFailureError(error) {
                _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
                let retryOverride = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                    expectedSubjectUserID: currentUser.id
                )
                do {
                    fetched = try await backendClient.fetchComments(
                        postID: targetPostID,
                        includeAuthorization: true,
                        allowAuthRetry: true,
                        authTokenOverride: retryOverride
                    )
                } catch {
                    finalError = error
                }
            }
        }
        guard let comments = fetched else {
            updateFeedDebug(
                stage: "comment_fetch_failed",
                status: "Comment refresh failed",
                detail: "post=\(targetPostID.uuidString.prefix(8)), force_refresh=\(forceRefresh ? "yes" : "no"), auth_override=\(authTokenOverride == nil ? "no" : "yes")",
                error: finalError
            )
            return .failed(finalError)
        }
        cachedCommentsFetchedAt[targetPostID] = Date()
        mergeRemoteComments(comments, into: targetPostID)
        return .refreshed
    }

    func commentDeliveryDebugLabel(for commentID: UUID) -> String? {
        guard let trace = commentDeliveryTraces[commentID] else { return "sync L0 B0 R0" }
        let local = trace.localAt != nil ? "1" : "0"
        let backend = trace.backendAckAt != nil ? "1" : "0"
        let remote = trace.remoteSeenAt != nil ? "1" : "0"
        let error = (trace.lastError ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if error.isEmpty {
            return "sync L\(local) B\(backend) R\(remote)"
        }
        return "sync L\(local) B\(backend) R\(remote) ⚠︎"
    }

    private func markCommentLocalCreated(_ commentID: UUID) {
        var trace = commentDeliveryTraces[commentID] ?? CommentDeliveryTrace()
        trace.localAt = trace.localAt ?? Date()
        trace.lastError = nil
        commentDeliveryTraces[commentID] = trace
    }

    private func markCommentBackendAcknowledged(_ commentID: UUID) {
        var trace = commentDeliveryTraces[commentID] ?? CommentDeliveryTrace()
        trace.backendAckAt = trace.backendAckAt ?? Date()
        trace.lastError = nil
        commentDeliveryTraces[commentID] = trace
    }

    private func markCommentDeliveryError(_ commentID: UUID, message: String) {
        var trace = commentDeliveryTraces[commentID] ?? CommentDeliveryTrace()
        trace.lastError = message
        commentDeliveryTraces[commentID] = trace
    }

    private func setCommentLikeOverride(_ commentID: UUID, isLiked: Bool) {
        commentLikeOverrides[commentID] = CommentLikeOverride(
            isLiked: isLiked,
            localUpdatedAt: Date(),
            backendAckAt: nil,
            lastMismatchLoggedAt: nil
        )
    }

    private func markCommentLikeBackendAcknowledged(_ commentID: UUID, isLiked: Bool) {
        var state = commentLikeOverrides[commentID] ?? CommentLikeOverride(
            isLiked: isLiked,
            localUpdatedAt: Date(),
            backendAckAt: nil,
            lastMismatchLoggedAt: nil
        )
        state.isLiked = isLiked
        state.backendAckAt = Date()
        commentLikeOverrides[commentID] = state
    }

    private func commentIDs(in comments: [PostComment]) -> Set<UUID> {
        var ids: Set<UUID> = []
        func walk(_ list: [PostComment]) {
            for comment in list {
                ids.insert(comment.id)
                if !comment.replies.isEmpty {
                    walk(comment.replies)
                }
            }
        }
        walk(comments)
        return ids
    }

    private func markRemoteSeenForTrackedComments(_ comments: [PostComment]) {
        let ids = commentIDs(in: comments)
        guard !ids.isEmpty else { return }
        for id in ids where commentDeliveryTraces[id] != nil {
            var trace = commentDeliveryTraces[id] ?? CommentDeliveryTrace()
            trace.remoteSeenAt = trace.remoteSeenAt ?? Date()
            commentDeliveryTraces[id] = trace
        }
    }

    private func canonicalCommentThreadPostID(for post: FeedPost) -> UUID {
        post.rescrollOrigin?.postID ?? post.id
    }

    private func commentThreadIndices(forCanonicalPostID canonicalPostID: UUID, fallbackPostID: UUID? = nil) -> [Int] {
        let direct = posts.indices.filter { index in
            let item = posts[index]
            return item.id == canonicalPostID || item.rescrollOrigin?.postID == canonicalPostID
        }
        if !direct.isEmpty { return direct }
        if let fallbackPostID,
           let fallbackIndex = posts.firstIndex(where: { $0.id == fallbackPostID }) {
            return [fallbackIndex]
        }
        return []
    }

    func hasRescrolled(_ post: FeedPost) -> Bool {
        rescrollPost(for: post) != nil
    }

    func toggleRescroll(for post: FeedPost, quoteText: String? = nil) {
        if let existingRescroll = rescrollPost(for: post) {
            unrescroll(post: existingRescroll)
        } else {
            rescroll(post: post, quoteText: quoteText)
        }
    }

    private func rescrollPost(for post: FeedPost) -> FeedPost? {
        let originalID = post.rescrollOrigin?.postID ?? post.id
        return posts.first(where: {
            $0.user.id == currentUser.id && $0.rescrollOrigin?.postID == originalID
        })
    }

    func rescroll(post: FeedPost, quoteText: String? = nil) {
        guard rescrollPost(for: post) == nil else { return }
        let normalizedQuoteText = normalizedRescrollQuoteText(quoteText)
        let originUser = post.rescrollOrigin?.user ?? post.user
        let originCaption = post.rescrollOrigin?.caption ?? post.caption
        let originTimestamp = post.rescrollOrigin?.timestamp ?? post.timestamp
        let originPostID = post.rescrollOrigin?.postID ?? post.id
        let origin = RescrollOrigin(
            postID: originPostID,
            user: originUser,
            caption: originCaption,
            websiteURL: post.rescrollOrigin?.websiteURL ?? post.websiteURL,
            timestamp: originTimestamp
        )
        let sharedPost = FeedPost(
            id: UUID(),
            user: currentUser,
            caption: originCaption,
            websiteURL: post.rescrollOrigin?.websiteURL ?? post.websiteURL,
            locationCity: post.locationCity,
            timestamp: Date(),
            mediaPreview: post.mediaPreview,
            coverImageRef: post.coverImageRef,
            coverProvider: post.coverProvider,
            coverBucket: post.coverBucket,
            coverObjectKey: post.coverObjectKey,
            comments: [],
            rescrollOrigin: origin,
            rescrollQuoteText: normalizedQuoteText
        )
        updateRescrollDebug(
            postID: sharedPost.id,
            stage: "queued_local",
            status: "Rescroll saved locally",
            detail: "original_post=\(originPostID.uuidString.prefix(8))",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        posts.insert(sharedPost, at: 0)
        if originUser.id != currentUser.id {
            enqueueNotification(
                type: .rescrolled,
                title: "Rescroll",
                message: "@\(currentUser.username) rescrolled your post.",
                digestKey: "rescroll:\(originUser.id.uuidString):\(originPostID.uuidString)",
                actorKey: "rescroll:\(currentUser.id.uuidString)",
                urgent: true,
                actorID: currentUser.id,
                objectID: originPostID
            )
        }
        saveState()
        Task {  [weak self] in
            guard let self else { return }
            _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "rescroll_create",
                    debugContext: BackendWriteDebugContext(
                        domain: .rescroll,
                        targetID: sharedPost.id.uuidString,
                        action: "rescroll_create"
                    ),
                    maxAttempts: 2,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.createRescroll(
                        userID: self.currentUser.id,
                        originalPostID: originPostID,
                        quoteText: normalizedQuoteText,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                await MainActor.run {
                    if self.isBackendWritePreflightError(error) {
                        self.enqueuePendingBackendWrite(
                            PendingBackendWriteOperation(
                                id: UUID(),
                                kind: .rescrollCreate,
                                createdAt: Date(),
                                retryCount: 0,
                                userID: self.currentUser.id,
                                postID: sharedPost.id,
                                authorID: self.currentUser.id,
                                commentID: nil,
                                body: normalizedQuoteText,
                                parentCommentID: nil,
                                originalPostID: originPostID,
                                rescrollPostID: nil,
                                circleID: nil,
                                messageID: nil,
                                encryptedText: nil,
                                messageTimestamp: nil
                            )
                        )
                        self.triggerPendingBackendWriteFlush(after: 0, force: true)
                        self.moderationErrorMessage = "Rescroll queued. It will sync automatically when your session recovers."
                        self.updateRescrollDebug(
                            postID: sharedPost.id,
                            stage: "queued_pending_auth_recovery",
                            status: "Rescroll queued; awaiting auth recovery",
                            detail: "No active session token at write preflight. Operation queued for retry worker.",
                            error: error
                        )
                        return
                    }
                    if self.isAuthenticationFailureError(error) {
                        let shouldClearStoredTokens = self.shouldClearStoredSessionTokensForAuthFailure(error)
                        let preserveRefreshToken = self.shouldPreserveRefreshTokenAfterAuthFailure(error)
                        if shouldClearStoredTokens {
                            self.clearStoredSessionTokensForReauthentication(preserveRefreshToken: preserveRefreshToken)
                        }
                        self.moderationErrorMessage = shouldClearStoredTokens
                            ? "Session expired while rescrolling. Sign in again to sync rescrolls."
                            : "Auth unavailable while rescrolling. Please retry."
                        self.updateRescrollDebug(
                            postID: sharedPost.id,
                            stage: "reauth_required_no_queue",
                            status: "Rescroll sync failed; reauthentication required",
                            detail: shouldClearStoredTokens
                                ? "Terminal auth failure. Local rescroll remains visible; backend sync requires sign in."
                                : "Auth unavailable. Retry after session recovers.",
                            error: error
                        )
                        return
                    }
                    if self.shouldRetryBackendWriteAttempt(after: error) {
                        self.enqueuePendingBackendWrite(
                            PendingBackendWriteOperation(
                                id: UUID(),
                                kind: .rescrollCreate,
                                createdAt: Date(),
                                retryCount: 0,
                                userID: self.currentUser.id,
                                postID: sharedPost.id,
                                authorID: self.currentUser.id,
                                commentID: nil,
                                body: normalizedQuoteText,
                                parentCommentID: nil,
                                originalPostID: originPostID,
                                rescrollPostID: nil,
                                circleID: nil,
                                messageID: nil,
                                encryptedText: nil,
                                messageTimestamp: nil
                            )
                        )
                        let retryDelay: UInt64 = self.isFeedRateLimitError(error) ? 12_000_000_000 : 4_000_000_000
                        self.triggerPendingBackendWriteFlush(after: retryDelay)
                        self.moderationErrorMessage = self.isFeedRateLimitError(error)
                            ? "Rescroll queued. Backend is rate-limited; it will retry automatically."
                            : "Rescroll queued for retry. It will sync automatically."
                        self.updateRescrollDebug(
                            postID: sharedPost.id,
                            stage: "queued_retryable_failure",
                            status: "Rescroll queued for retry",
                            detail: self.isFeedRateLimitError(error)
                                ? "Backend returned rate limit; local rescroll kept visible and queued for retry worker."
                                : "Retryable backend failure; local rescroll kept visible and queued for retry worker.",
                            error: error
                        )
                        return
                    }
                    self.moderationErrorMessage = "Rescroll saved locally, but backend sync failed. Please retry."
                    self.updateRescrollDebug(
                        postID: sharedPost.id,
                        stage: "sync_failed_local_retained",
                        status: "Rescroll sync failed",
                        detail: "Local rescroll remains visible; backend sync was not queued.",
                        error: error
                    )
                }
            }
        }
    }

    func unrescroll(post: FeedPost) {
        guard post.rescrollOrigin != nil, post.user.id == currentUser.id else { return }
        updateRescrollDebug(
            postID: post.id,
            stage: "delete_queued_local",
            status: "Unrescroll applied locally",
            detail: "Awaiting backend delete for rescroll \(post.id.uuidString.prefix(8)).",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        posts.removeAll(where: { $0.id == post.id })
        saveState()
        Task {  [weak self] in
            guard let self else { return }
            _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "rescroll_delete",
                    debugContext: BackendWriteDebugContext(
                        domain: .rescroll,
                        targetID: post.id.uuidString,
                        action: "rescroll_delete"
                    ),
                    maxAttempts: 2,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.deleteRescroll(
                        userID: self.currentUser.id,
                        rescrollPostID: post.id,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                await MainActor.run {
                    if self.isBackendWritePreflightError(error) {
                        self.enqueuePendingBackendWrite(
                            PendingBackendWriteOperation(
                                id: UUID(),
                                kind: .rescrollDelete,
                                createdAt: Date(),
                                retryCount: 0,
                                userID: self.currentUser.id,
                                postID: post.id,
                                authorID: self.currentUser.id,
                                commentID: nil,
                                body: nil,
                                parentCommentID: nil,
                                originalPostID: nil,
                                rescrollPostID: post.id,
                                circleID: nil,
                                messageID: nil,
                                encryptedText: nil,
                                messageTimestamp: nil
                            )
                        )
                        self.triggerPendingBackendWriteFlush(after: 0, force: true)
                        self.moderationErrorMessage = "Unrescroll queued. It will sync automatically when your session recovers."
                        self.updateRescrollDebug(
                            postID: post.id,
                            stage: "delete_queued_pending_auth_recovery",
                            status: "Unrescroll queued; awaiting auth recovery",
                            detail: "No active session token at write preflight. Delete operation queued for retry worker.",
                            error: error
                        )
                        return
                    }
                    if self.isAuthenticationFailureError(error) {
                        let shouldClearStoredTokens = self.shouldClearStoredSessionTokensForAuthFailure(error)
                        let preserveRefreshToken = self.shouldPreserveRefreshTokenAfterAuthFailure(error)
                        if shouldClearStoredTokens {
                            self.clearStoredSessionTokensForReauthentication(preserveRefreshToken: preserveRefreshToken)
                        }
                        self.moderationErrorMessage = shouldClearStoredTokens
                            ? "Session expired while removing rescroll. Sign in again to sync."
                            : "Auth unavailable while removing rescroll. Please retry."
                        self.updateRescrollDebug(
                            postID: post.id,
                            stage: "delete_reauth_required_no_queue",
                            status: "Unrescroll sync failed; reauthentication required",
                            detail: shouldClearStoredTokens
                                ? "Terminal auth failure. Local unrescroll applied; backend sync requires sign in."
                                : "Auth unavailable. Retry after session recovers.",
                            error: error
                        )
                        return
                    }
                    if self.shouldRetryBackendWriteAttempt(after: error) {
                        self.enqueuePendingBackendWrite(
                            PendingBackendWriteOperation(
                                id: UUID(),
                                kind: .rescrollDelete,
                                createdAt: Date(),
                                retryCount: 0,
                                userID: self.currentUser.id,
                                postID: post.id,
                                authorID: self.currentUser.id,
                                commentID: nil,
                                body: nil,
                                parentCommentID: nil,
                                originalPostID: nil,
                                rescrollPostID: post.id,
                                circleID: nil,
                                messageID: nil,
                                encryptedText: nil,
                                messageTimestamp: nil
                            )
                        )
                        let retryDelay: UInt64 = self.isFeedRateLimitError(error) ? 12_000_000_000 : 4_000_000_000
                        self.triggerPendingBackendWriteFlush(after: retryDelay)
                        self.moderationErrorMessage = self.isFeedRateLimitError(error)
                            ? "Unrescroll queued. Backend is rate-limited; it will retry automatically."
                            : "Unrescroll queued for retry. It will sync automatically."
                        self.updateRescrollDebug(
                            postID: post.id,
                            stage: "delete_queued_retryable_failure",
                            status: "Unrescroll queued for retry",
                            detail: self.isFeedRateLimitError(error)
                                ? "Backend returned rate limit; local unrescroll kept and queued for retry worker."
                                : "Retryable backend failure; local unrescroll kept and queued for retry worker.",
                            error: error
                        )
                        return
                    }
                    self.moderationErrorMessage = "Unrescroll update failed to sync. Please retry."
                    self.updateRescrollDebug(
                        postID: post.id,
                        stage: "delete_sync_failed_local_retained",
                        status: "Unrescroll sync failed",
                        detail: "Local unrescroll applied; backend sync was not queued.",
                        error: error
                    )
                }
            }
        }
    }

    func prepareMediaPreview(
        from item: PhotosPickerItem,
        progress: MediaStorage.PreparationProgressHandler? = nil
    ) async throws -> MediaPreview {
        let videoType = item.supportedContentTypes.first(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) })
        let assetIdentifier = item.itemIdentifier
        if let type = videoType {
            guard let videoUploadPolicy = currentUserVideoUploadPolicy() else {
                throw MediaPreparationError.videoUploadsRequireSubscription
            }
            if let sourceURL = try? await item.loadTransferable(type: URL.self) {
                let ext = sourceURL.pathExtension.isEmpty ? (UTType(type.identifier)?.preferredFilenameExtension ?? "mov") : sourceURL.pathExtension
                let dest: URL
                do {
                    dest = try await MediaStorage.copyVideoFile(
                        from: sourceURL,
                        fileExtension: ext,
                        uploadPolicy: videoUploadPolicy,
                        progress: progress
                    )
                } catch {
                    throw mapVideoPreparationError(error, policy: videoUploadPolicy)
                }
                let ratio = try await MediaStorage.videoAspectRatio(for: dest)
                return .video(url: dest, aspectRatio: ratio, assetIdentifier: assetIdentifier)
            }
            guard let videoData = try await item.loadTransferable(type: Data.self) else {
                throw MediaPreparationError.unableToLoadVideo
            }
            let extensionCandidate = UTType(type.identifier)?.preferredFilenameExtension ?? "mov"
            let url: URL
            do {
                url = try await MediaStorage.saveVideoData(
                    videoData,
                    fileExtension: extensionCandidate,
                    uploadPolicy: videoUploadPolicy,
                    progress: progress
                )
            } catch {
                throw mapVideoPreparationError(error, policy: videoUploadPolicy)
            }
            let ratio = try await MediaStorage.videoAspectRatio(for: url)
            return .video(url: url, aspectRatio: ratio, assetIdentifier: assetIdentifier)
        }

        guard item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) else {
            throw MediaPreparationError.unsupportedType
        }
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw MediaPreparationError.unableToLoadImage
        }
        if let image = PlatformImage(data: data),
           let preview = Self.photoPreview(from: image, assetIdentifier: assetIdentifier) {
            return preview
        }
        throw MediaPreparationError.unableToCreatePreview
    }

    func currentUserVideoUploadPolicy() -> MediaStorage.VideoUploadPolicy? {
        if isFounderAccount(currentUser) || currentUser.isGoldTier {
            return MediaStorage.goldVideoUploadPolicy
        }
        if currentUser.isVerified || hasSubscriberBenefits(for: currentUser) {
            return MediaStorage.blueVideoUploadPolicy
        }
        return MediaStorage.freeVideoUploadPolicy
    }

    private func mapVideoPreparationError(
        _ error: Error,
        policy: MediaStorage.VideoUploadPolicy
    ) -> MediaPreparationError {
        guard let compressionError = error as? MediaStorage.VideoCompressionError else {
            return .unableToCreatePreview
        }
        switch compressionError {
        case .durationExceeded(let maxSeconds, let tierLabel):
            return .videoDurationExceeded(maxSeconds: maxSeconds, tierLabel: tierLabel)
        case .tooLarge:
            return .videoTooLarge(maxMB: policy.maxFileDisplayMB, tierLabel: policy.tierLabel)
        case .unsupportedSubscriptionTier:
            return .videoUploadsRequireSubscription
        }
    }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func markAllNotificationsRead() {
        syncNotificationInboxLocally()
        guard notifications.contains(where: { !$0.isRead }) else { return }
        notifications = notifications.map { notification in
            var updated = notification
            updated.isRead = true
            return updated
        }
        patchCachedNotifications(for: currentUser.id) { cached in
            cached.map { notification in
                BackendNotification(
                    id: notification.id,
                    userID: notification.userID,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    createdAt: notification.createdAt,
                    isRead: true,
                    actorID: notification.actorID,
                    objectID: notification.objectID
                )
            }
        }
        saveState()
        let userID = currentUser.id
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "notifications_mark_all_read",
                    maxAttempts: 2,
                    timeoutPerAttempt: 15
                ) { authTokenOverride in
                    try await self.backendClient.markAllNotificationsRead(
                        userID: userID,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                self.recordAuthFailure(
                    error,
                    context: "Mark notifications read",
                    recovery: "No local rollback; will retry on next action"
                )
                self.enqueuePendingBackendWrite(
                    PendingBackendWriteOperation(
                        id: UUID(),
                        kind: .notificationsMarkAllRead,
                        createdAt: Date(),
                        retryCount: 0,
                        userID: userID,
                        postID: nil,
                        authorID: nil,
                        commentID: nil,
                        body: nil,
                        parentCommentID: nil,
                        originalPostID: nil,
                        rescrollPostID: nil,
                        circleID: nil,
                        messageID: nil,
                        encryptedText: nil,
                        messageTimestamp: nil
                    )
                )
                self.triggerPendingBackendWriteFlush(after: 0, force: true)
            }
        }
    }

    func markNotification(_ notification: AppNotification, read: Bool) {
        syncNotificationInboxLocally()
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        var updated = notification
        updated.isRead = read
        notifications[index] = updated
        patchCachedNotifications(for: currentUser.id) { cached in
            cached.map { remote in
                guard remote.id == notification.id else { return remote }
                return BackendNotification(
                    id: remote.id,
                    userID: remote.userID,
                    type: remote.type,
                    title: remote.title,
                    message: remote.message,
                    createdAt: remote.createdAt,
                    isRead: read,
                    actorID: remote.actorID,
                    objectID: remote.objectID
                )
            }
        }
        saveState()
        let userID = currentUser.id
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "notification_mark",
                    maxAttempts: 2,
                    timeoutPerAttempt: 15
                ) { authTokenOverride in
                    try await self.backendClient.setNotificationRead(
                        notificationID: notification.id,
                        read: read,
                        userID: userID,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                self.recordAuthFailure(
                    error,
                    context: "Mark notification read state",
                    recovery: "Local state kept; next inbox sync can reconcile once the write succeeds."
                )
            }
        }
    }

    func clearReadNotifications() {
        syncNotificationInboxLocally()
        let hasRead = notifications.contains(where: { $0.isRead })
        guard hasRead else { return }
        notifications.removeAll(where: { $0.isRead })
        patchCachedNotifications(for: currentUser.id) { cached in
            cached.filter { !$0.isRead }
        }
        saveState()
        let userID = currentUser.id
        Task {  [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "notifications_delete_read",
                    maxAttempts: 2,
                    timeoutPerAttempt: 15
                ) { authTokenOverride in
                    try await self.backendClient.deleteReadNotifications(
                        userID: userID,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                self.recordAuthFailure(
                    error,
                    context: "Delete read notifications",
                    recovery: "No local rollback; will retry on next action"
                )
                self.enqueuePendingBackendWrite(
                    PendingBackendWriteOperation(
                        id: UUID(),
                        kind: .notificationsDeleteRead,
                        createdAt: Date(),
                        retryCount: 0,
                        userID: userID,
                        postID: nil,
                        authorID: nil,
                        commentID: nil,
                        body: nil,
                        parentCommentID: nil,
                        originalPostID: nil,
                        rescrollPostID: nil,
                        circleID: nil,
                        messageID: nil,
                        encryptedText: nil,
                        messageTimestamp: nil
                    )
                )
                self.triggerPendingBackendWriteFlush(after: 0, force: true)
            }
        }
    }

    func syncNotificationInbox(forceRefresh: Bool = true) {
        syncNotificationInboxLocally()
        guard backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            await self.syncNotificationInboxFromBackend(forceRefresh: forceRefresh)
        }
    }

    func loadMoreNotificationsIfNeeded(currentNotificationID: UUID) {
        guard notifications.last?.id == currentNotificationID else { return }
        guard !isLoadingMoreNotifications else { return }
        guard let nextCursor = notificationNextCursorByUserID[currentUser.id] ?? nil,
              !nextCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard backendClient.isEnabled else { return }

        let userID = currentUser.id
        isLoadingMoreNotifications = true
        Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    self?.isLoadingMoreNotifications = false
                }
            }
            do {
                let page = try await self.backendClient.fetchNotifications(
                    userID: userID,
                    allowAuthContextFallbackOnEmpty: false,
                    limit: 60,
                    before: nextCursor
                )
                await MainActor.run {
                    self.mergeRemoteNotificationsPage(page.items, nextCursor: page.nextCursor, append: true)
                }
            } catch {
                if self.isAuthenticationFailureError(error) {
                    _ = await self.ensureBackendSessionForCurrentUser(preferRefresh: true)
                    if let page = try? await self.backendClient.fetchNotifications(
                        userID: userID,
                        allowAuthContextFallbackOnEmpty: false,
                        limit: 60,
                        before: nextCursor
                    ) {
                        await MainActor.run {
                            self.mergeRemoteNotificationsPage(page.items, nextCursor: page.nextCursor, append: true)
                        }
                    }
                }
            }
        }
    }

    private func syncNotificationInboxLocally() {
        pruneInvalidSelfFollowNotifications()
        flushDeferredNotificationsIfNeeded()
        pruneNotificationsForCost()
    }

    private func syncNotificationInboxFromBackend(forceRefresh: Bool) async {
        let userID = currentUser.id
        guard let remoteNotifications = await fetchNotificationsForSync(
            userID: userID,
            forceRefresh: forceRefresh
        ) else {
            return
        }
        await MainActor.run {
            self.mergeRemoteNotifications(remoteNotifications)
        }
    }

    private func pruneInvalidSelfFollowNotifications() {
        let originalCount = notifications.count
        notifications.removeAll { notification in
            notification.type == .followed &&
            notification.actorID == currentUser.id &&
            (notification.recipientUserID == nil || notification.recipientUserID == currentUser.id)
        }
        if notifications.count != originalCount {
            saveState()
        }
    }

    private func patchCachedNotifications(
        for userID: UUID,
        _ transform: ([BackendNotification]) -> [BackendNotification]
    ) {
        guard let cached = cachedNotifications,
              cached.ownerUserID == userID else { return }
        cachedNotifications = SyncCacheEntry(
            ownerUserID: cached.ownerUserID,
            value: transform(cached.value),
            fetchedAt: cached.fetchedAt
        )
    }

    private func enqueueNotification(
        type: AppNotification.NotificationType,
        title: String,
        message: String,
        digestKey: String,
        actorKey: String,
        urgent: Bool,
        actorID: UUID? = nil,
        objectID: UUID? = nil
    ) {
        pruneNotificationsForCost()
        guard !isRateLimitedForNotificationActor(actorKey) else { return }
        if shouldDeferNotification(urgent: urgent) {
            deferredNotifications.append(
                DeferredNotificationItem(
                    type: type,
                    title: title,
                    message: message,
                    digestKey: digestKey,
                    actorKey: actorKey,
                    actorID: actorID,
                    objectID: objectID
                )
            )
            return
        }
        registerNotificationActorEvent(actorKey)
        pushDigestNotification(
            type: type,
            title: title,
            message: message,
            digestKey: digestKey,
            actorID: actorID,
            objectID: objectID
        )
    }

    private func pushDigestNotification(
        type: AppNotification.NotificationType,
        title: String,
        message: String,
        digestKey: String,
        actorID: UUID?,
        objectID: UUID?
    ) {
        let now = Date()
        if let existingID = notificationDigestIndex[digestKey],
           let index = notifications.firstIndex(where: { $0.id == existingID }),
           now.timeIntervalSince(notifications[index].timestamp) <= Self.NotificationCostSaverMode.digestWindow {
            let existing = notifications[index]
            let updatedCount = extractedDigestCount(from: existing.message) + 1
            notifications[index] = AppNotification(
                id: existing.id,
                type: existing.type,
                title: existing.title,
                message: "\(updatedCount) new updates",
                timestamp: now,
                isRead: false,
                recipientUserID: currentUser.id,
                actorID: existing.actorID ?? actorID,
                objectID: existing.objectID ?? objectID
            )
            notifications.sort { $0.timestamp > $1.timestamp }
            return
        }
        let notification = AppNotification(
            id: UUID(),
            type: type,
            title: title,
            message: message,
            timestamp: now,
            isRead: false,
            recipientUserID: currentUser.id,
            actorID: actorID,
            objectID: objectID
        )
        notificationDigestIndex[digestKey] = notification.id
        notifications.insert(notification, at: 0)
    }

    private func extractedDigestCount(from message: String) -> Int {
        let first = message.split(separator: " ").first
        return Int(first ?? "") ?? 1
    }

    private func shouldDeferNotification(urgent: Bool) -> Bool {
        guard !urgent else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return Self.NotificationCostSaverMode.quietHourStart <= hour || hour < Self.NotificationCostSaverMode.quietHourEnd
    }

    private func flushDeferredNotificationsIfNeeded() {
        guard !deferredNotifications.isEmpty else { return }
        guard !shouldDeferNotification(urgent: false) else { return }
        let queued = deferredNotifications
        deferredNotifications.removeAll()
        for item in queued {
            guard !isRateLimitedForNotificationActor(item.actorKey) else { continue }
            registerNotificationActorEvent(item.actorKey)
            pushDigestNotification(
                type: item.type,
                title: item.title,
                message: item.message,
                digestKey: item.digestKey,
                actorID: item.actorID,
                objectID: item.objectID
            )
        }
    }

    private func registerNotificationActorEvent(_ actorKey: String) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Self.NotificationCostSaverMode.actorWindow)
        var entries = (notificationActorHistory[actorKey] ?? []).filter { $0 >= cutoff }
        entries.append(now)
        notificationActorHistory[actorKey] = entries
    }

    private func isRateLimitedForNotificationActor(_ actorKey: String) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-Self.NotificationCostSaverMode.actorWindow)
        let entries = (notificationActorHistory[actorKey] ?? []).filter { $0 >= cutoff }
        notificationActorHistory[actorKey] = entries
        return entries.count >= Self.NotificationCostSaverMode.maxEventsPerActorWindow
    }

    private func pruneNotificationsForCost() {
        let cutoff = Date().addingTimeInterval(-TimeInterval(Self.NotificationCostSaverMode.retentionHours * 3600))
        notifications.removeAll { $0.timestamp < cutoff }
        let validIDs = Set(notifications.map(\.id))
        notificationDigestIndex = notificationDigestIndex.filter { validIDs.contains($0.value) }
    }

    // APNs hygiene hooks for future backend wiring.
    func registerPushTokenFailure(_ token: String, hardFailure: Bool) {
        guard hardFailure else { return }
        invalidPushTokens.insert(token)
    }

    func isPushTokenActive(_ token: String) -> Bool {
        !invalidPushTokens.contains(token)
    }

    func searchProfiles(matching query: String) -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return searchableProfiles.filter { profile in
            let keywordsToken = profile.keywords.joined(separator: " ").lowercased()
            let tokens = [
                profile.displayName.lowercased(),
                profile.username.lowercased(),
                profile.bio.lowercased(),
                keywordsToken
            ]
            return tokens.contains(where: { $0.contains(lower) })
        }
    }

    func mentionSuggestions(matching query: String, limit: Int = 6) -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        let uniqueProfiles = Array(
            Dictionary(grouping: searchableProfiles, by: \.id).compactMap { $0.value.first }
        )
        let ranked = uniqueProfiles.sorted { lhs, rhs in
            lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }
        let results = ranked.filter { profile in
            if lower.isEmpty { return true }
            return profile.username.lowercased().hasPrefix(lower) ||
                profile.displayName.lowercased().contains(lower)
        }
        return Array(results.prefix(max(limit, 1)))
    }

    // MARK: - Search Caching (stale-while-revalidate)

    func clearAllCaches() {
        clearFeedCache()
        clearTrustedTimelineWindow()
        clearSearchCache()
        clearCommentCache()
        clearSocialSnapshotCaches()
        clearAdSnapshotCaches()
    }

    func clearSearchCache() {
        cachedUserSearchResults.removeAll()
        cachedCitySearchResults.removeAll()
        cachedPublicCircleSearchResults.removeAll()
        inFlightUserSearchRefreshKeys.removeAll()
        inFlightCitySearchRefreshKeys.removeAll()
        inFlightPublicCircleSearchRefreshKeys.removeAll()
    }

    func clearFeedCache() {
        cachedFeedFirstPage = nil
        feedTimelineNextCursor = nil
        isFeedTimelineLazyLoadInFlight = false
        isFeedTimelineLazyLoading = false
        isFeedFastTopUpInFlight = false
    }

    private func clearTrustedTimelineWindow() {
        trustedTimelinePostIDs.removeAll()
        trustedTimelinePostOrder.removeAll()
    }

    private func normalizedFeedCursor(_ cursor: String?) -> String? {
        guard let value = cursor?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func markTimelinePostsTrusted(_ remotePosts: [BackendPost]) {
        guard !remotePosts.isEmpty else { return }
        for remote in remotePosts {
            let postID = remote.id
            if trustedTimelinePostIDs.insert(postID).inserted {
                trustedTimelinePostOrder.append(postID)
            }
        }
        let overflow = trustedTimelinePostOrder.count - Self.trustedTimelinePostLimit
        if overflow > 0 {
            let evicted = trustedTimelinePostOrder.prefix(overflow)
            for postID in evicted {
                trustedTimelinePostIDs.remove(postID)
            }
            trustedTimelinePostOrder.removeFirst(overflow)
        }
    }

    private func evictStaleTrustedTimelinePosts(
        confirmedPostIDs: Set<UUID>,
        oldestConfirmedTimestamp: Date?
    ) -> Int {
        guard !confirmedPostIDs.isEmpty else { return 0 }
        let staleTrustedPostIDs = trustedTimelinePostIDs.subtracting(confirmedPostIDs)
        guard !staleTrustedPostIDs.isEmpty else { return 0 }

        let now = Date()
        let graceCutoff = now.addingTimeInterval(-Self.feedTimelineEvictionGraceWindow)
        let oldestTimestamp = oldestConfirmedTimestamp ?? now
        var removableFromTrustOnly = Set<UUID>()
        var evictablePostIDs = Set<UUID>()

        for postID in staleTrustedPostIDs {
            guard let post = posts.first(where: { $0.id == postID })
                ?? pendingRemotePosts.first(where: { $0.id == postID })
                ?? deliveredAdPosts.first(where: { $0.id == postID }) else {
                removableFromTrustOnly.insert(postID)
                continue
            }

            if postPublishDeliveryStates[postID] != nil {
                // Never evict local optimistic posts that are still awaiting backend ack.
                continue
            }

            // Guard against index propagation lag for very recent posts.
            if post.timestamp >= graceCutoff {
                continue
            }

            // Only evict posts whose timestamp falls within the confirmed feed
            // window (i.e. newer than or equal to the oldest confirmed post).
            // Such posts should have been returned by the backend but weren't —
            // meaning they were deleted.  Posts older than the window may simply
            // be on a later page and must not be touched.
            if post.timestamp >= oldestTimestamp {
                evictablePostIDs.insert(postID)
            }
        }

        let trustRemovals = removableFromTrustOnly.union(evictablePostIDs)
        if !trustRemovals.isEmpty {
            trustedTimelinePostIDs.subtract(trustRemovals)
            trustedTimelinePostOrder.removeAll { trustRemovals.contains($0) }
        }

        guard !evictablePostIDs.isEmpty else { return 0 }
        posts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        pendingRemotePosts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        deliveredAdPosts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        pendingFeedPostCount = pendingRemotePosts.count
        normalizePinnedPosts()
        return evictablePostIDs.count
    }

    private func clearCommentCache() {
        cachedCommentsFetchedAt.removeAll()
        commentsCacheOwnerUserID = currentUser.id
    }

    private func clearSocialSnapshotCaches() {
        cachedFollowingUsers = nil
        cachedFollowerUsers = nil
        cachedCircles = nil
        cachedNotifications = nil
        cachedDirectoryProfiles = nil
        profileDeltaVersionByUserID.removeValue(forKey: currentUser.id)
    }

    private func clearAdSnapshotCaches() {
        cachedAdSubmissions = nil
        cachedAdDeliveryItems = nil
        cachedCuratedSlots = nil
    }

    private func invalidateCachesForAccountTransition() {
        clearAllCaches()
        dirtyCircleIDs.removeAll()
        currentUserWriteVersion = nil
        pendingFollowRequests.removeAll()
        pendingOutgoingFollowRequestIDs.removeAll()
        authMutationRateSamples.removeAll()
        lastAuthMutationSnapshot = nil
    }

    private func invalidateCachesForFollowGraphMutation() {
        clearSearchCache()
        clearFeedCache()
        clearTrustedTimelineWindow()
        clearSocialSnapshotCaches()
    }

    private func invalidateSearchCachesBecauseDirectoryChanged() {
        clearSearchCache()
    }

    func searchProfilesFromBackend(matching query: String, forceRefresh: Bool = false) async -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard backendClient.isEnabled, !trimmed.isEmpty else { return [] }
        guard trimmed.count <= ProductionSearchGuardrails.maximumRemoteSearchCharacters else { return [] }
        let normalizedForExact = normalizedUsernameCandidate(from: trimmed)
        guard trimmed.count >= ProductionSearchGuardrails.minimumRemoteSearchCharacters || normalizedForExact != nil else {
            return []
        }
        let key = trimmed.lowercased()
        let scopedKey = scopedSearchKey(for: key, ownerID: currentUser.id)
        if !forceRefresh,
           let cached = cachedUserSearchResults[key],
           cached.ownerUserID == currentUser.id {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < BackendPollingCostSaverMode.searchResultsFreshTTL {
                return cached.value
            }
            if age < BackendPollingCostSaverMode.searchResultsTTL {
                if let refreshed = await refreshUserSearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
                    return refreshed
                }
                return cached.value
            }
        }
        if let refreshed = await refreshUserSearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
            return refreshed
        }
        if let cached = cachedUserSearchResults[key], cached.ownerUserID == currentUser.id {
            return cached.value
        }
        return []
    }

    func searchCitiesFromBackend(matching query: String, forceRefresh: Bool = false) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard backendClient.isEnabled, !trimmed.isEmpty else { return [] }
        guard trimmed.count >= ProductionSearchGuardrails.minimumRemoteSearchCharacters else { return [] }
        guard trimmed.count <= ProductionSearchGuardrails.maximumRemoteSearchCharacters else { return [] }
        let key = trimmed.lowercased()
        let scopedKey = scopedSearchKey(for: key, ownerID: currentUser.id)
        if !forceRefresh,
           let cached = cachedCitySearchResults[key] {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < BackendPollingCostSaverMode.searchResultsFreshTTL {
                return cached.results
            }
            if age < BackendPollingCostSaverMode.searchResultsTTL {
                if let refreshed = await refreshCitySearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
                    return refreshed
                }
                return cached.results
            }
        }
        if let refreshed = await refreshCitySearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
            return refreshed
        }
        if let cached = cachedCitySearchResults[key] {
            return cached.results
        }
        return []
    }

    func searchPublicCirclesFromBackend(matching query: String, forceRefresh: Bool = false) async -> [PublicCircleSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard backendClient.isEnabled, !trimmed.isEmpty else { return [] }
        guard trimmed.count >= ProductionSearchGuardrails.minimumRemoteSearchCharacters else { return [] }
        guard trimmed.count <= ProductionSearchGuardrails.maximumRemoteSearchCharacters else { return [] }
        let key = trimmed.lowercased()
        let scopedKey = scopedSearchKey(for: key, ownerID: currentUser.id)
        if !forceRefresh,
           let cached = cachedPublicCircleSearchResults[key],
           cached.ownerUserID == currentUser.id {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < BackendPollingCostSaverMode.searchResultsFreshTTL {
                return cached.value
            }
            if age < BackendPollingCostSaverMode.searchResultsTTL {
                if let refreshed = await refreshPublicCircleSearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
                    return refreshed
                }
                return cached.value
            }
        }
        if let refreshed = await refreshPublicCircleSearchCache(query: trimmed, key: key, scopedKey: scopedKey) {
            return refreshed
        }
        if let cached = cachedPublicCircleSearchResults[key], cached.ownerUserID == currentUser.id {
            return cached.value
        }
        return []
    }

    func searchPostsFromBackend(matching query: String, limit: Int = 24) async -> (relevant: [FeedPost], recent: [FeedPost]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard backendClient.isEnabled else { return ([], []) }
        guard trimmed.count <= ProductionSearchGuardrails.maximumRemoteSearchCharacters else { return ([], []) }
        let resolvedLimit = min(max(limit, 1), 60)

        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()

        do {
            let remotePosts = try await backendClient.searchPosts(query: trimmed, limit: resolvedLimit)
            return mappedBackendSearchPosts(remotePosts)
        } catch {
            if isAuthenticationFailureError(error) {
                _ = await BackendTruthSyncCore.ensureActiveSession(
                    for: resolvedBackendSessionUsername(),
                    expectedUserID: currentUser.id,
                    using: backendClient,
                    preferRefresh: true
                )
                restoreBackendAuthTokenForCurrentUserIfNeeded()
                if let retried = try? await backendClient.searchPosts(query: trimmed, limit: resolvedLimit) {
                    return mappedBackendSearchPosts(retried)
                }
            }
            if let publicResults = try? await backendClient.searchPosts(
                query: trimmed,
                limit: resolvedLimit,
                includeAuthorization: false
            ) {
                return mappedBackendSearchPosts(publicResults)
            }
            return ([], [])
        }
    }

    private func mappedBackendSearchPosts(_ page: BackendPostSearchPage) -> (relevant: [FeedPost], recent: [FeedPost]) {
        let relevant = deduplicatedSearchPosts(page.relevant.map(mapBackendSearchPost))
        let recent = deduplicatedSearchPosts(page.recent.map(mapBackendSearchPost))
        return (relevant, recent)
    }

    private func mapBackendSearchPost(_ remote: BackendPost) -> FeedPost {
        let author = roleAdjustedProfile(remote.author.asUserProfile)
        registerProfile(author, writeVersion: remote.author.writeVersion)
        let mappedOrigin = mappedRescrollOrigin(from: remote)
        let resolvedTimestamp = resolvedFeedPostTimestamp(
            remoteCreatedAt: remote.createdAt,
            rescrollOrigin: mappedOrigin
        )
        return FeedPost(
            id: remote.id,
            user: author,
            caption: remote.caption,
            websiteURL: remote.websiteURL,
            locationCity: remote.locationCity,
            timestamp: resolvedTimestamp,
            mediaPreview: remote.asMediaPreview,
            coverImageRef: remote.coverImageRef,
            coverProvider: remote.coverProvider,
            coverBucket: remote.coverBucket,
            coverObjectKey: remote.coverObjectKey,
            comments: [],
            rescrollOrigin: mappedOrigin
        )
    }

    private func deduplicatedSearchPosts(_ source: [FeedPost]) -> [FeedPost] {
        var seen = Set<UUID>()
        return source.filter { seen.insert($0.id).inserted }
    }

    private func refreshUserSearchCache(query: String, key: String, scopedKey: String) async -> [UserProfile]? {
        if inFlightUserSearchRefreshKeys.contains(scopedKey) { return nil }
        inFlightUserSearchRefreshKeys.insert(scopedKey)
        defer { inFlightUserSearchRefreshKeys.remove(scopedKey) }
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        do {
            let remoteUsers = try await backendClient.searchUsers(query: query)
            var mapped = remoteUsers.map(\.asUserProfile)
            if mapped.isEmpty,
               let directMatch = await fetchDirectUsernameSearchCandidate(query: query),
               !mapped.contains(where: { $0.id == directMatch.id }) {
                mapped.append(directMatch)
            }
            registerProfiles(from: mapped)
            cachedUserSearchResults[key] = SyncCacheEntry(
                ownerUserID: currentUser.id,
                value: mapped,
                fetchedAt: Date()
            )
            return mapped
        } catch {
            if isAuthenticationFailureError(error) {
                _ = await BackendTruthSyncCore.ensureActiveSession(
                    for: resolvedBackendSessionUsername(),
                    expectedUserID: currentUser.id,
                    using: backendClient,
                    preferRefresh: true
                )
                restoreBackendAuthTokenForCurrentUserIfNeeded()
                if let retried = try? await backendClient.searchUsers(query: query) {
                    var mapped = retried.map(\.asUserProfile)
                    if mapped.isEmpty,
                       let directMatch = await fetchDirectUsernameSearchCandidate(query: query),
                       !mapped.contains(where: { $0.id == directMatch.id }) {
                        mapped.append(directMatch)
                    }
                    registerProfiles(from: mapped)
                    cachedUserSearchResults[key] = SyncCacheEntry(
                        ownerUserID: currentUser.id,
                        value: mapped,
                        fetchedAt: Date()
                    )
                    return mapped
                }
            }
            if let publicResults = try? await backendClient.searchUsers(query: query, includeAuthorization: false) {
                var mapped = publicResults.map(\.asUserProfile)
                if mapped.isEmpty,
                   let directMatch = await fetchDirectUsernameSearchCandidate(query: query),
                   !mapped.contains(where: { $0.id == directMatch.id }) {
                    mapped.append(directMatch)
                }
                registerProfiles(from: mapped)
                cachedUserSearchResults[key] = SyncCacheEntry(
                    ownerUserID: currentUser.id,
                    value: mapped,
                    fetchedAt: Date()
                )
                return mapped
            }
            if let directMatch = await fetchDirectUsernameSearchCandidate(query: query) {
                registerProfile(directMatch)
                cachedUserSearchResults[key] = SyncCacheEntry(
                    ownerUserID: currentUser.id,
                    value: [directMatch],
                    fetchedAt: Date()
                )
                return [directMatch]
            }
            return nil
        }
    }

    private func refreshCitySearchCache(query: String, key: String, scopedKey: String) async -> [String]? {
        if inFlightCitySearchRefreshKeys.contains(scopedKey) { return nil }
        inFlightCitySearchRefreshKeys.insert(scopedKey)
        defer { inFlightCitySearchRefreshKeys.remove(scopedKey) }
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        do {
            let remoteCities = try await backendClient.searchCities(query: query)
            let normalized = remoteCities
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            cachedCitySearchResults[key] = (results: normalized, fetchedAt: Date())
            return normalized
        } catch {
            return nil
        }
    }

    private func refreshPublicCircleSearchCache(query: String, key: String, scopedKey: String) async -> [PublicCircleSearchResult]? {
        if inFlightPublicCircleSearchRefreshKeys.contains(scopedKey) { return nil }
        inFlightPublicCircleSearchRefreshKeys.insert(scopedKey)
        defer { inFlightPublicCircleSearchRefreshKeys.remove(scopedKey) }
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        do {
            let remoteCircles = try await backendClient.searchPublicCircles(query: query)
            let mapped = remoteCircles.map(mapBackendPublicCircleSearchResult)
            cachedPublicCircleSearchResults[key] = SyncCacheEntry(
                ownerUserID: currentUser.id,
                value: mapped,
                fetchedAt: Date()
            )
            return mapped
        } catch {
            if isAuthenticationFailureError(error) {
                _ = await BackendTruthSyncCore.ensureActiveSession(
                    for: resolvedBackendSessionUsername(),
                    expectedUserID: currentUser.id,
                    using: backendClient,
                    preferRefresh: true
                )
                restoreBackendAuthTokenForCurrentUserIfNeeded()
                if let retried = try? await backendClient.searchPublicCircles(query: query) {
                    let mapped = retried.map(mapBackendPublicCircleSearchResult)
                    cachedPublicCircleSearchResults[key] = SyncCacheEntry(
                        ownerUserID: currentUser.id,
                        value: mapped,
                        fetchedAt: Date()
                    )
                    return mapped
                }
            }
            if let publicResults = try? await backendClient.searchPublicCircles(
                query: query,
                includeAuthorization: false
            ) {
                let mapped = publicResults.map(mapBackendPublicCircleSearchResult)
                cachedPublicCircleSearchResults[key] = SyncCacheEntry(
                    ownerUserID: currentUser.id,
                    value: mapped,
                    fetchedAt: Date()
                )
                return mapped
            }
            return nil
        }
    }

    private func mapBackendPublicCircleSearchResult(_ remote: BackendPublicCircleSearchResult) -> PublicCircleSearchResult {
        let creator = remote.creator.map { roleAdjustedProfile($0.asUserProfile) }
        if let creator {
            registerProfile(creator, writeVersion: remote.creator?.writeVersion)
        }
        return PublicCircleSearchResult(
            id: remote.id,
            name: remote.name,
            summary: remote.summary,
            category: remote.category,
            tags: remote.tags,
            avatarRef: remote.avatarRef,
            memberCount: remote.memberCount,
            creator: creator,
            createdAt: remote.createdAt
        )
    }

    private func fetchDirectUsernameSearchCandidate(query: String) async -> UserProfile? {
        guard let normalized = normalizedUsernameCandidate(from: query) else { return nil }
        guard !normalized.isEmpty else { return nil }
        guard normalized.range(of: #"^[a-z0-9_\.]{2,32}$"#, options: .regularExpression) != nil else {
            return nil
        }
        guard let exact = try? await backendClient.fetchUserByUsername(normalized, includeAuthorization: false) else {
            return nil
        }
        let mapped = exact.asUserProfile
        guard normalizeUsername(mapped.username) == normalized else { return nil }
        return mapped
    }

    private func scopedSearchKey(for key: String, ownerID: UUID) -> String {
        "\(ownerID.uuidString.lowercased())::\(key)"
    }

    private func normalizedUsernameCandidate(from rawQuery: String) -> String? {
        var normalized = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.hasPrefix("@") {
            normalized = String(normalized.dropFirst())
        }
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    func hydrateCityDiscoveryPosts(city: String, force: Bool = false) {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard backendClient.isEnabled, !trimmed.isEmpty else { return }
        let key = trimmed.lowercased()
        if !force,
           let last = cityDiscoveryFetchTimestamps[key],
           Date().timeIntervalSince(last) < 25 {
            return
        }
        cityDiscoveryFetchTimestamps[key] = Date()
        Task {  [weak self] in
            guard let self else { return }
            if let page = try? await backendClient.fetchCityPosts(city: trimmed, limit: 90) {
                await MainActor.run {
                    self.mergeRemotePosts(page.posts, source: .cityDiscovery)
                }
            }
        }
    }

    func searchTextScrolls(matching query: String) -> [FeedPost] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return posts.filter { post in
            guard case let .text(textPreview) = post.mediaPreview else { return false }
            return textPreview.text.lowercased().contains(lower)
        }
    }

    func searchLocationScrolls(matching query: String) -> [FeedPost] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.lowercased()
        return posts.filter { post in
            guard let city = post.locationCity?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !city.isEmpty else {
                return false
            }
            return city.lowercased().contains(lower)
        }
    }

    func searchPosts(matching query: String) -> [FeedPost] {
        searchPostsByRelevance(matching: query)
    }

    /// `true` when the given postID is currently in our local "this should
    /// be deleted" set.  Lives across app launches via the pendingDeletion
    /// queue restore at startup.  Callers should use this to filter remote
    /// search/feed/profile results so a stuck backend deletion (silent
    /// failure on the original delete RPC) doesn't make the user see their
    /// own deleted post still surfaced and playable.
    func isLocallyDeleted(_ postID: UUID) -> Bool {
        pendingDeletedPostIDs.contains(postID)
    }

    /// Called when a remote response (search, feed, etc.) returns posts.
    /// For every post in the response that the iOS app thinks SHOULD be
    /// deleted (i.e. is in `pendingDeletedPostIDs`), re-enqueue the backend
    /// delete RPC.  This auto-heals the "deleted long ago but backend never
    /// got the memo" case: every search/feed refresh becomes an opportunity
    /// to retry the stuck deletion.  Idempotent — `enqueuePendingDeletion`
    /// dedups against the existing queue.
    func reissueDeletionForLocallyDeletedRemotePosts(_ posts: [FeedPost]) {
        let stuck = posts.filter { pendingDeletedPostIDs.contains($0.id) }
        guard !stuck.isEmpty else { return }
        for post in stuck {
            enqueuePendingDeletion(
                kind: .post,
                postID: post.id,
                authorID: post.user.id,
                post: post
            )
        }
        Task { [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    /// BackendPost variant of `reissueDeletionForLocallyDeletedRemotePosts`.
    /// Called from `mergeRemotePosts` so every passive surface that ingests
    /// remote posts (feed, profile fetch, deep-link resolve, etc.) becomes
    /// an opportunity to retry stuck deletions.
    private func autoRetryStuckDeletionsForBackendPosts(_ posts: [BackendPost]) {
        guard !pendingDeletedPostIDs.isEmpty else { return }
        let stuck = posts.filter { pendingDeletedPostIDs.contains($0.id) }
        guard !stuck.isEmpty else { return }
        for post in stuck {
            // Refresh the cached authorID — the version we have stored
            // might be stale, but the backend just told us who it thinks
            // owns this post.
            userDeletedPostAuthorIDs[post.id] = post.author.id
            // Enqueue manually (not via enqueuePendingDeletion) so we don't
            // re-double-save the persistent file for every iteration — one
            // save at the end covers all of them.
            let request = PendingDeletionRequest(
                kind: .post,
                postID: post.id,
                authorID: post.author.id,
                createdAt: Date()
            )
            if !pendingDeletionQueue.contains(request) {
                pendingDeletionQueue.append(request)
            }
        }
        savePendingDeletionQueue()
        saveUserDeletedPostIDs()
        Task { [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    func searchPostsByRelevance(matching query: String, limit: Int = 25) -> [FeedPost] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let normalizedQuery = trimmed.lowercased()
        let tokens = normalizedQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        let now = Date()
        let scored = posts.compactMap { post -> (post: FeedPost, score: Int)? in
            let caption = post.caption?.lowercased() ?? ""
            // Track titles and lyrics are searchable independently from the
            // release caption. Track-title matches receive a stronger score
            // so searching "Forever" surfaces the release containing that
            // song ahead of incidental caption or lyric matches.
            let trackTitles: [String]
            let lyricsCorpus: String
            if post.isMusic {
                trackTitles = post.musicTracks
                    .map { $0.title.lowercased() }
                    .filter { !$0.isEmpty }
                let joined = post.musicTracks
                    .compactMap { $0.lyrics }
                    .joined(separator: "\n")
                    .lowercased()
                lyricsCorpus = joined
            } else {
                trackTitles = []
                lyricsCorpus = ""
            }
            let searchable = [caption, lyricsCorpus]
            let phraseScore = searchable.reduce(0) { partial, field in
                partial + scoreSearchMatch(
                    query: normalizedQuery,
                    in: field,
                    exact: 80,
                    prefix: 40,
                    contains: 24
                )
            }
            let tokenScore = tokens.reduce(0) { partial, token in
                partial + searchable.reduce(0) { inner, field in
                    inner + scoreSearchMatch(
                        query: token,
                        in: field,
                        exact: 20,
                        prefix: 12,
                        contains: 8
                    )
                }
            }
            let trackPhraseScore = trackTitles.reduce(0) { partial, title in
                partial + scoreSearchMatch(
                    query: normalizedQuery,
                    in: title,
                    exact: 140,
                    prefix: 100,
                    contains: 70
                )
            }
            let trackTokenScore = tokens.reduce(0) { partial, token in
                partial + trackTitles.reduce(0) { inner, title in
                    inner + scoreSearchMatch(
                        query: token,
                        in: title,
                        exact: 40,
                        prefix: 28,
                        contains: 18
                    )
                }
            }
            let totalScore = phraseScore + tokenScore + trackPhraseScore + trackTokenScore
            guard totalScore > 0 else { return nil }

            // 30-day logarithmic decay over remaining freshness window.
            // Recent posts keep meaningful lift, but keyword relevance still dominates.
            let ageDays = max(0.0, now.timeIntervalSince(post.timestamp) / 86400.0)
            let clampedAgeDays = min(ageDays, 30.0)
            let remainingWindow = 30.0 - clampedAgeDays
            let recencyRatio = log1p(remainingWindow) / log1p(30.0)
            let recencyBonus = Int((20.0 * recencyRatio).rounded())
            return (post: post, score: totalScore + recencyBonus)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.post.timestamp > rhs.post.timestamp
        }

        guard limit > 0 else { return [] }
        return Array(scored.prefix(limit).map(\.post))
    }

    private func scoreSearchMatch(
        query: String,
        in value: String,
        exact: Int,
        prefix: Int,
        contains: Int
    ) -> Int {
        guard !query.isEmpty, !value.isEmpty else { return 0 }
        if value == query { return exact }
        if value.hasPrefix(query) { return prefix }
        if value.contains(query) { return contains }
        return 0
    }

    /// For a music post that surfaced in search results, find the first
    /// per-track lyric line that contains the user's query and return it
    /// trimmed for display next to the post.  Used by SearchPostRow to
    /// render "Lyrics: \"...\"" under the post when the match came from
    /// lyrics rather than the caption.
    ///
    /// Returns nil when the post isn't music, has no lyrics, or none of
    /// its lyric lines contain the query (the post may have been ranked
    /// in via caption alone).
    func lyricSearchSnippet(in post: FeedPost, matching query: String) -> String? {
        guard post.isMusic else { return nil }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else { return nil }
        // Also try the first token if the full-phrase doesn't match —
        // a multi-word query may straddle line breaks in the lyrics.
        let queryCandidates: [String]
        if trimmedQuery.contains(" ") {
            let firstToken = trimmedQuery
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .first ?? trimmedQuery
            queryCandidates = [trimmedQuery, firstToken]
        } else {
            queryCandidates = [trimmedQuery]
        }
        for track in post.musicTracks {
            guard let lyrics = track.lyrics?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lyrics.isEmpty else { continue }
            let lines = lyrics.components(separatedBy: .newlines)
            for line in lines {
                let normalizedLine = line.lowercased()
                for candidate in queryCandidates where normalizedLine.contains(candidate) {
                    // Clamp to a reasonable length so a single huge line
                    // (no internal newlines) doesn't dominate the search
                    // result card.  ~80 chars matches Apple Music's
                    // single-line lyric snippet treatment.
                    let snippet = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if snippet.count > 80 {
                        let endIndex = snippet.index(snippet.startIndex, offsetBy: 80)
                        return String(snippet[..<endIndex]) + "…"
                    }
                    return snippet
                }
            }
        }
        return nil
    }

    func profile(forUsername username: String) -> UserProfile? {
        let normalized = normalizeUsername(username.replacingOccurrences(of: "@", with: ""))
        guard !normalized.isEmpty else { return nil }
        let matches = profileRegistry.values.filter { normalizeUsername($0.username) == normalized }
        if !matches.isEmpty {
            if let currentMatch = matches.first(where: { $0.id == currentUser.id }) {
                return currentMatch
            }
            return matches.dropFirst().reduce(matches[0]) { partial, next in
                preferredProfile(partial, next)
            }
        }
        let founderUsername = normalizeUsername(Self.founderCanonicalAccount.username)
        if normalized == founderUsername {
            ensureFounderAccountExists()
            let founderMatches = profileRegistry.values.filter { normalizeUsername($0.username) == normalized }
            if founderMatches.isEmpty { return nil }
            return founderMatches.dropFirst().reduce(founderMatches[0]) { partial, next in
                preferredProfile(partial, next)
            }
        }
        return nil
    }

    func updateCurrentUserProfile(
        username: String? = nil,
        displayName: String? = nil,
        bio: String? = nil,
        keywords: [String]? = nil,
        avatarImage: PlatformImage? = nil,
        avatarVideoRef: String? = nil,
        websiteURL: String? = nil,
        venmoURL: String? = nil,
        cashAppURL: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil,
        isPrivateAccount: Bool? = nil,
        businessLocation: String? = nil,
        businessPhone: String? = nil,
        homeCity: String? = nil,
        dateOfBirth: Date? = nil,
        parentalControls: UserProfile.ParentalControls? = nil
    ) {
        let previousUsername = currentUser.username
        var updateNeeded = false
        var finalUsername: String? = nil
        if let username {
            let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != currentUser.username {
                finalUsername = trimmed
                updateNeeded = true
            }
        }

        var finalDisplayName: String? = nil
        if let displayName {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != currentUser.displayName {
                finalDisplayName = trimmed
                updateNeeded = true
            }
        }

        var finalBio: String? = nil
        if let bio {
            let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != currentUser.bio {
                finalBio = trimmed
                updateNeeded = true
            }
        }

        var finalKeywords: [String]? = nil
        if let keywords {
            let normalized = keywords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if normalized != currentUser.keywords {
                finalKeywords = normalized
                updateNeeded = true
            }
        }

        if avatarImage != nil {
            updateNeeded = true
        }

        var finalAvatarVideoRef: String? = nil
        if let avatarVideoRef {
            let trimmed = avatarVideoRef.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = trimmed.isEmpty ? "" : trimmed
            if normalized != (currentUser.avatarVideoRef ?? "") {
                finalAvatarVideoRef = normalized
                updateNeeded = true
            }
        }

        var finalWebsiteURL: String? = nil
        if let websiteURL {
            let trimmed = websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.websiteURL ?? "") {
                finalWebsiteURL = trimmed
                updateNeeded = true
            }
        }

        var finalBusinessLocation: String? = nil
        if let businessLocation {
            let trimmed = businessLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.businessLocation ?? "") {
                finalBusinessLocation = trimmed
                updateNeeded = true
            }
        }

        var finalVenmoURL: String? = nil
        if let venmoURL {
            let trimmed = venmoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.venmoURL ?? "") {
                finalVenmoURL = trimmed
                updateNeeded = true
            }
        }

        var finalCashAppURL: String? = nil
        if let cashAppURL {
            let trimmed = cashAppURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.cashAppURL ?? "") {
                finalCashAppURL = trimmed
                updateNeeded = true
            }
        }

        var finalSpotifyURL: String? = nil
        if let spotifyURL {
            let trimmed = spotifyURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.spotifyURL ?? "") {
                finalSpotifyURL = trimmed
                updateNeeded = true
            }
        }

        var finalAppleMusicURL: String? = nil
        if let appleMusicURL {
            let trimmed = appleMusicURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.appleMusicURL ?? "") {
                finalAppleMusicURL = trimmed
                updateNeeded = true
            }
        }

        var finalBusinessPhone: String? = nil
        if let businessPhone {
            let trimmed = businessPhone.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.businessPhone ?? "") {
                finalBusinessPhone = trimmed
                updateNeeded = true
            }
        }

        var finalHomeCity: String? = nil
        if let homeCity {
            let trimmed = homeCity.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != (currentUser.homeCity ?? "") {
                finalHomeCity = trimmed
                updateNeeded = true
            }
        }

        var finalIsPrivateAccount: Bool? = nil
        if let isPrivateAccount, isPrivateAccount != currentUser.isPrivateAccount {
            finalIsPrivateAccount = isPrivateAccount
            updateNeeded = true
        }

        var finalDateOfBirth: Date? = nil
        var finalAgeAssuranceCompletedAt: Date? = nil
        if let dateOfBirth {
            let existingDOB = currentUser.dateOfBirth
            let dateChanged = existingDOB.map { !Calendar.current.isDate($0, inSameDayAs: dateOfBirth) } ?? true
            if dateChanged || currentUser.ageAssuranceCompletedAt == nil {
                finalDateOfBirth = dateOfBirth
                finalAgeAssuranceCompletedAt = Date()
                updateNeeded = true
            }
        }

        var finalParentalControls: UserProfile.ParentalControls? = nil
        if let parentalControls, parentalControls != currentUser.parentalControls {
            finalParentalControls = parentalControls
            updateNeeded = true
        }

        guard updateNeeded else {
            updateProfileDebug(
                profileID: currentUser.id,
                stage: "no_local_changes",
                status: "No local profile changes detected",
                detail: "Save invoked, but mutable profile fields matched current local state.",
                authPreflight: currentAuthSnapshotForSyncDebug(),
                resetFlow: true
            )
            guard backendClient.isEnabled else { return }
            markPendingProfilePush(currentUser)
            let generation = profilePushGeneration
            let profileToPersist = currentUser
            scheduleProfileSync(
                profile: profileToPersist,
                generation: generation,
                trigger: "profile_save_without_local_delta",
                isAutomaticRetry: false
            )
            return
        }
        let changedFields = [
            finalUsername != nil ? "username" : nil,
            finalDisplayName != nil ? "display_name" : nil,
            finalBio != nil ? "bio" : nil,
            finalKeywords != nil ? "keywords" : nil,
            avatarImage != nil ? "avatar_image" : nil,
            finalAvatarVideoRef != nil ? "avatar_video" : nil,
            finalWebsiteURL != nil ? "website_url" : nil,
            finalVenmoURL != nil ? "venmo_url" : nil,
            finalCashAppURL != nil ? "cashapp_url" : nil,
            finalSpotifyURL != nil ? "spotify_url" : nil,
            finalAppleMusicURL != nil ? "apple_music_url" : nil,
            finalIsPrivateAccount != nil ? "is_private" : nil,
            finalBusinessLocation != nil ? "business_location" : nil,
            finalBusinessPhone != nil ? "business_phone" : nil,
            finalHomeCity != nil ? "home_city" : nil,
            finalDateOfBirth != nil ? "date_of_birth" : nil,
            finalAgeAssuranceCompletedAt != nil ? "age_assurance" : nil,
            finalParentalControls != nil ? "parental_controls" : nil
        ].compactMap { $0 }

        currentUser = currentUser.with(
            username: finalUsername,
            displayName: finalDisplayName,
            bio: finalBio,
            keywords: finalKeywords,
            avatarImage: avatarImage,
            isPrivateAccount: finalIsPrivateAccount,
            avatarVideoRef: finalAvatarVideoRef,
            websiteURL: finalWebsiteURL,
            venmoURL: finalVenmoURL,
            cashAppURL: finalCashAppURL,
            spotifyURL: finalSpotifyURL,
            appleMusicURL: finalAppleMusicURL,
            businessLocation: finalBusinessLocation,
            businessPhone: finalBusinessPhone,
            homeCity: finalHomeCity,
            dateOfBirth: finalDateOfBirth,
            ageAssuranceCompletedAt: finalAgeAssuranceCompletedAt,
            parentalControls: finalParentalControls
        )
        if let finalAvatarVideoRef {
            let trimmedAvatarVideoRef = finalAvatarVideoRef.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedAvatarVideoRef.isEmpty {
                setPreferredProfileHeroMedia(.photo, for: currentUser)
            } else {
                setPreferredProfileHeroMedia(.video, for: currentUser)
            }
        }
        registerProfile(currentUser)
        normalizeIdentityState()
        refreshCurrentUserPosts()
        Self.saveProfileSnapshot(currentUser)
        saveState()
        LocalAuthStore.updateAccount(
            matching: previousUsername,
            isSubscriber: currentUser.isVerified,
            websiteURL: currentUser.websiteURL ?? "",
            venmoURL: currentUser.venmoURL ?? "",
            cashAppURL: currentUser.cashAppURL ?? "",
            businessLocation: currentUser.businessLocation ?? "",
            businessPhone: currentUser.businessPhone ?? "",
            accountType: currentUser.accountType,
            dateOfBirth: currentUser.dateOfBirth,
            ageAssuranceCompletedAt: currentUser.ageAssuranceCompletedAt,
            parentalControls: currentUser.parentalControls
        )
        updateProfileDebug(
            profileID: currentUser.id,
            stage: "queued_local",
            status: "Profile changes saved locally",
            detail: "changed_fields=\(changedFields.joined(separator: ","))",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        markPendingProfilePush(currentUser)
        let generation = profilePushGeneration
        let profileToPersist = currentUser
        scheduleProfileSync(
            profile: profileToPersist,
            generation: generation,
            trigger: "local_profile_edit",
            isAutomaticRetry: false
        )
    }

    func hasSubscriberBenefits(for profile: UserProfile) -> Bool {
        isFounderAccount(profile) || profile.isVerified || profile.isGoldTier || !(profile.subscriptionPlan?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func signatureImage(for profile: UserProfile) -> PlatformImage? {
        guard hasSubscriberBenefits(for: profile) else { return nil }
        if let cached = signatureImageCache[profile.id] {
            return cached
        }
        let key = Self.profileSignatureImageKeyPrefix + profile.id.uuidString.lowercased()
        var data = UserDefaults.standard.data(forKey: key)
        if data == nil, let signatureRef = profile.signatureRef {
            data = Data(base64Encoded: signatureRef)
            if let data {
                Self.setUserDefaultsDataSafely(data, forKey: key)
            }
        }
        guard let data else { return nil }
        // Legacy JPEG signatures lose transparency and render as white blocks on avatars.
        if Self.isJPEGData(data) {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        guard let image = PlatformImage(data: data) else {
            return nil
        }
        signatureImageCache[profile.id] = image
        return image
    }

    func updateCurrentUserSignatureImage(_ image: PlatformImage?) {
        guard hasSubscriberBenefits(for: currentUser) else { return }
        let key = Self.profileSignatureImageKeyPrefix + currentUser.id.uuidString.lowercased()
        if let image, let data = compactSignatureData(from: image) {
            Self.setUserDefaultsDataSafely(data, forKey: key)
            signatureImageCache[currentUser.id] = PlatformImage(data: data) ?? image
            UserDefaults.standard.removeObject(forKey: Self.profileSignatureKeyPrefix + currentUser.id.uuidString.lowercased())
            currentUser = currentUser.with(signatureRef: data.base64EncodedString())
        } else {
            UserDefaults.standard.removeObject(forKey: key)
            signatureImageCache.removeValue(forKey: currentUser.id)
            UserDefaults.standard.removeObject(forKey: Self.profileSignatureKeyPrefix + currentUser.id.uuidString.lowercased())
            currentUser = currentUser.with(signatureRef: nil)
        }
        registerProfile(currentUser)
        refreshCurrentUserPosts()
        Self.saveProfileSnapshot(currentUser)
        saveState()
        updateProfileDebug(
            profileID: currentUser.id,
            stage: "queued_local",
            status: "Profile signature saved locally",
            detail: image == nil ? "signature=cleared" : "signature=updated",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        markPendingProfilePush(currentUser)
        let generation = profilePushGeneration
        let profileToPersist = currentUser
        scheduleProfileSync(
            profile: profileToPersist,
            generation: generation,
            trigger: "signature_edit",
            isAutomaticRetry: false
        )
    }

    private func compactSignatureData(from image: PlatformImage) -> Data? {
        #if canImport(UIKit)
        let cleanedImage = cleanedSignatureImage(from: image)
        let maxDimension: CGFloat = 640
        let sourceSize = cleanedImage.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return cleanedImage.encodedDataRepresentation()
        }
        var currentMaxDimension = maxDimension
        while currentMaxDimension >= 220 {
            let longestEdge = max(sourceSize.width, sourceSize.height)
            let scale = min(1, currentMaxDimension / longestEdge)
            let targetSize = CGSize(
                width: max((sourceSize.width * scale).rounded(), 1),
                height: max((sourceSize.height * scale).rounded(), 1)
            )
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            let rendered = renderer.image { _ in
                cleanedImage.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            if let png = rendered.pngData(), png.count <= 800_000 {
                return png
            }
            currentMaxDimension -= 120
        }
        return cleanedImage.pngData()
        #else
        return image.encodedDataRepresentation()
        #endif
    }

    #if canImport(UIKit)
    private func cleanedSignatureImage(from image: PlatformImage) -> PlatformImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        guard let data = calloc(height * width, bytesPerPixel) else { return image }
        defer { free(data) }

        guard let context = CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        let totalPixels = width * height

        for index in 0..<totalPixels {
            let offset = index * 4
            let r = buffer[offset]
            let g = buffer[offset + 1]
            let b = buffer[offset + 2]
            let a = buffer[offset + 3]

            // Remove white board residue and keep signature strokes prominent.
            if a < 6 || (r > 244 && g > 244 && b > 244) {
                buffer[offset] = 0
                buffer[offset + 1] = 0
                buffer[offset + 2] = 0
                buffer[offset + 3] = 0
            } else {
                let darkness = UInt8(255 - max(r, max(g, b)))
                let boostedAlpha = max(a, max(UInt8(120), darkness))
                buffer[offset] = 0
                buffer[offset + 1] = 0
                buffer[offset + 2] = 0
                buffer[offset + 3] = boostedAlpha
            }
        }

        guard let outputCG = context.makeImage() else { return image }
        return PlatformImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
    }
    #endif

    private func resolvedFontStyleForCurrentUser(_ requested: ScrollPostFontStyle) -> ScrollPostFontStyle {
        guard requested != .original else { return .original }
        return hasSubscriberBenefits(for: currentUser) ? requested : .original
    }

    func isUsernameAvailable(_ username: String, excluding profileID: UUID? = nil) -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.lowercased()
        let candidates = Array(profileRegistry.values)
        return !candidates.contains { candidate in
            candidate.id != profileID && candidate.username.lowercased() == normalized
        }
    }

    func verifyCurrentUser() {
        applySubscriptionEntitlement(isActive: true, planID: "01", expiresAt: nil)
    }

    func cancelVerification() {
        applySubscriptionEntitlement(isActive: false, planID: nil, expiresAt: nil)
    }

    func applySubscriptionEntitlement(isActive: Bool, planID: String?, expiresAt: Date?, originalTransactionID: String? = nil) {
        let founder = isFounderAccount(currentUser)
        let shouldVerify = founder || isActive
        let requiresBusinessDowngrade = !shouldVerify && currentUser.accountType == .business

        let nextProfile = currentUser.with(
            isVerified: shouldVerify,
            accountType: requiresBusinessDowngrade ? .personal : currentUser.accountType,
            subscriptionPlan: shouldVerify ? planID : nil,
            websiteURL: requiresBusinessDowngrade ? "" : currentUser.websiteURL,
            businessLocation: requiresBusinessDowngrade ? "" : currentUser.businessLocation,
            businessPhone: requiresBusinessDowngrade ? "" : currentUser.businessPhone
        )
        let changed =
            nextProfile.isVerified != currentUser.isVerified ||
            nextProfile.accountType != currentUser.accountType ||
            (nextProfile.websiteURL ?? "") != (currentUser.websiteURL ?? "") ||
            (nextProfile.businessLocation ?? "") != (currentUser.businessLocation ?? "") ||
            (nextProfile.businessPhone ?? "") != (currentUser.businessPhone ?? "")

        currentUser = nextProfile
        if changed {
            registerProfile(currentUser)
            normalizeIdentityState()
            refreshCurrentUserPosts()
            Self.saveProfileSnapshot(currentUser)
            saveState()
        }
        LocalAuthStore.updateAccount(
            matching: currentUser.username,
            isSubscriber: isActive,
            websiteURL: currentUser.websiteURL ?? "",
            businessLocation: currentUser.businessLocation ?? "",
            businessPhone: currentUser.businessPhone ?? "",
            accountType: currentUser.accountType
        )
        Task {
            try? await backendClient.updateSubscriptionState(
                userID: currentUser.id,
                isSubscriber: isActive,
                planID: planID,
                expiresAt: expiresAt,
                originalTransactionID: originalTransactionID
            )
            if let refreshed = try? await backendClient.fetchUser(id: currentUser.id) {
                await MainActor.run {
                    self.mergeRemoteCurrentUser(refreshed)
                }
            }
        }
    }

    func toggleLike(on comment: PostComment, in post: FeedPost) {
        let targetPostID = post.rescrollOrigin?.postID ?? post.id
        let commentID = comment.id
        guard let postIndex = posts.firstIndex(where: { $0.id == targetPostID }) else {
            return
        }
        var comments = posts[postIndex].comments
        var likedUser: UserProfile?
        var didLike = false
        var likedReply = false
        let changed = toggleLike(
            in: &comments,
            targetID: comment.id,
            depth: 0,
            likedUser: &likedUser,
            didLike: &didLike,
            likedReply: &likedReply
        )
        guard changed else { return }
        posts[postIndex].comments = comments
        if didLike, let likedUser, likedUser.id != currentUser.id {
            enqueueNotification(
                type: .commentLiked,
                title: likedReply ? "Reply activity" : "Comment activity",
                message: likedReply
                    ? "@\(likedUser.username)'s reply got a new like."
                    : "@\(likedUser.username)'s comment got a new like.",
                digestKey: "comment-liked:\(likedUser.id.uuidString)",
                actorKey: "comment-liked:\(currentUser.id.uuidString)",
                urgent: false,
                actorID: currentUser.id,
                objectID: targetPostID
            )
        }
        saveState()

        let likeOperationKind: PendingBackendWriteOperation.Kind = didLike ? .commentLikeCreate : .commentLikeDelete
        updateCommentLikeDebug(
            commentID: commentID,
            stage: didLike ? "comment_like_queued_local" : "comment_unlike_queued_local",
            status: didLike ? "Like queued for backend sync" : "Unlike queued for backend sync",
            detail: "Local comment like state updated and queued for backend write.",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        setCommentLikeOverride(commentID, isLiked: didLike)
        enqueuePendingBackendWrite(
            PendingBackendWriteOperation(
                id: UUID(),
                kind: likeOperationKind,
                createdAt: Date(),
                retryCount: 0,
                userID: currentUser.id,
                postID: targetPostID,
                authorID: nil,
                commentID: commentID,
                body: nil,
                parentCommentID: nil,
                originalPostID: nil,
                rescrollPostID: nil,
                circleID: nil,
                messageID: nil,
                encryptedText: nil,
                messageTimestamp: nil
            )
        )
        triggerPendingBackendWriteFlush(after: 250_000_000, force: true)
    }

    private func toggleLike(
        in comments: inout [PostComment],
        targetID: UUID,
        depth: Int,
        likedUser: inout UserProfile?,
        didLike: inout Bool,
        likedReply: inout Bool
    ) -> Bool {
        for index in comments.indices {
            if comments[index].id == targetID {
                likedUser = comments[index].user
                likedReply = depth > 0
                let currentlyLiked = commentLikeOverrides[targetID]?.isLiked
                    ?? comments[index].likedBy.contains(currentUser.id)
                if currentlyLiked {
                    comments[index].likedBy.removeAll(where: { $0 == currentUser.id })
                    didLike = false
                } else {
                    if !comments[index].likedBy.contains(currentUser.id) {
                        comments[index].likedBy.append(currentUser.id)
                    }
                    didLike = true
                }
                return true
            }
            if toggleLike(
                in: &comments[index].replies,
                targetID: targetID,
                depth: depth + 1,
                likedUser: &likedUser,
                didLike: &didLike,
                likedReply: &likedReply
            ) {
                return true
            }
        }
        return false
    }

    private func updateComment(in comments: inout [PostComment], matching id: UUID, handler: (inout PostComment) -> Bool) -> Bool {
        for index in comments.indices {
            if comments[index].id == id {
                return handler(&comments[index])
            }
            if updateComment(in: &comments[index].replies, matching: id, handler: handler) {
                return true
            }
        }
        return false
    }

    private func mutateCircle(id: UUID, handler: (inout CircleGroup) -> Void) {
        mutateCircle(id: id, deferSave: false, handler: handler)
    }

    private func mutateCircle(
        id: UUID,
        deferSave: Bool,
        scheduleBackendSync: Bool = true,
        handler: (inout CircleGroup) -> Void
    ) {
        guard let index = circles.firstIndex(where: { $0.id == id }) else { return }
        var circle = circles[index]
        handler(&circle)
        pruneMessagesForCost(in: &circle)
        circles[index] = circle
        if scheduleBackendSync {
            dirtyCircleIDs.insert(id)
        }
        if deferSave {
            scheduleBatchedCircleSave()
        } else {
            saveState()
        }
        if scheduleBackendSync {
            scheduleBatchedCircleBackendSync()
        }
    }

    func requestJoin(circle: CircleGroup) {
        mutateCircle(id: circle.id) { updated in
            guard !updated.members.contains(where: { $0.profileID == currentUser.id }) else { return }
            updated.members.append(
                CircleMember(id: UUID(), profileID: currentUser.id, status: .pending)
            )
        }
    }

    func acceptInvitation(circle: CircleGroup) {
        respondTo(circle: circle, newStatus: .member)
    }

    func declineInvitation(circle: CircleGroup) {
        respondTo(circle: circle, newStatus: .declined)
    }

    func cancelJoinRequest(circle: CircleGroup) {
        mutateCircle(id: circle.id) { updated in
            updated.members.removeAll(where: { $0.profileID == currentUser.id && $0.status == .pending })
        }
    }

    private func respondTo(circle: CircleGroup, newStatus: CircleMemberStatus) {
        mutateCircle(id: circle.id) { updated in
            guard let memberIndex = updated.members.firstIndex(where: { $0.profileID == currentUser.id }) else { return }
            updated.members[memberIndex].status = newStatus
        }
    }

    var circleMessageCharacterLimit: Int {
        Self.CostSaverMode.maxMessageCharacters
    }

    func isCircleMessageRateLimited(circleID: UUID) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        let recent = (circleMessageSendHistory[circleID] ?? []).filter { $0 >= cutoff }
        return recent.count >= Self.CostSaverMode.maxMessagesPerMinutePerCircle
    }

    private func canSendMessage(in circle: CircleGroup) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        let recent = (circleMessageSendHistory[circle.id] ?? []).filter { $0 >= cutoff }
        circleMessageSendHistory[circle.id] = recent
        return recent.count < Self.CostSaverMode.maxMessagesPerMinutePerCircle
    }

    private func normalizeCircleMessageText(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return "" }
        if collapsed.count <= Self.CostSaverMode.maxMessageCharacters {
            return collapsed
        }
        return String(collapsed.prefix(Self.CostSaverMode.maxMessageCharacters))
    }

    private func circleMessageDebugTextLength(_ encryptedText: String, circleID: UUID) -> Int {
        let trimmed = encryptedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        if trimmed.hasPrefix("plain:") {
            let plainText = String(trimmed.dropFirst("plain:".count))
            return normalizeCircleMessageText(plainText).count
        }
        return normalizeCircleMessageText(
            CircleEncryption.shared.decrypt(trimmed, circleID: circleID)
        ).count
    }

    private func circleMessageDebugSummary(
        message: CircleMessage,
        circleID: UUID,
        source: String,
        retryCount: Int? = nil,
        queuedAgeSeconds: Int? = nil
    ) -> String {
        let textLength = circleMessageDebugTextLength(message.encryptedText, circleID: circleID)
        let wireMode = message.encryptedText.hasPrefix("plain:") ? "plain" : "encrypted"
        let sharedPost = message.sharedPostID.map { String($0.uuidString.prefix(8)) } ?? "none"
        var parts: [String] = [
            "source=\(source)",
            "circle=\(String(circleID.uuidString.prefix(8)))",
            "message=\(String(message.id.uuidString.prefix(8)))",
            "chars=\(textLength)",
            "wire=\(wireMode)",
            "shared_post=\(sharedPost)"
        ]
        if let retryCount {
            parts.append("retry_count=\(retryCount)")
        }
        if let queuedAgeSeconds {
            parts.append("queued_age_s=\(max(0, queuedAgeSeconds))")
        }
        return parts.joined(separator: ", ")
    }

    private func circleMessageDebugSummary(
        operation: PendingBackendWriteOperation,
        source: String
    ) -> String {
        guard let circleID = operation.circleID,
              let messageID = operation.messageID,
              let encryptedText = operation.encryptedText,
              let messageTimestamp = operation.messageTimestamp else {
            return "source=\(source), message=unknown, queue_op_missing_fields=yes"
        }
        let message = CircleMessage(
            id: messageID,
            userID: operation.userID,
            encryptedText: encryptedText,
            timestamp: messageTimestamp,
            sharedPostID: operation.postID
        )
        return circleMessageDebugSummary(
            message: message,
            circleID: circleID,
            source: source,
            retryCount: operation.retryCount,
            queuedAgeSeconds: Int(Date().timeIntervalSince(operation.createdAt))
        )
    }

    private func circleLocalMembershipDebugSummary(circleID: UUID) -> String {
        guard let localCircle = circle(by: circleID) else {
            return "local_circle_found=no, local_member_status=none, local_member_count=0, local_member_sample=none"
        }
        let currentStatus = localCircle.members.first(where: { $0.profileID == currentUser.id })?.status.rawValue ?? "none"
        let sample = localCircle.members.prefix(6).map { member in
            "\(String(member.profileID.uuidString.prefix(8))):\(member.status.rawValue)"
        }.joined(separator: "|")
        return "local_circle_found=yes, local_member_status=\(currentStatus), local_member_count=\(localCircle.members.count), local_member_sample=\(sample.isEmpty ? "none" : sample)"
    }

    private func registerMessageSend(for circleID: UUID) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        var recent = (circleMessageSendHistory[circleID] ?? []).filter { $0 >= cutoff }
        recent.append(now)
        circleMessageSendHistory[circleID] = recent
    }

    private func scheduleBatchedCircleSave() {
        pendingCircleSaveTask?.cancel()
        pendingCircleSaveTask = Task {  [weak self] in
            try? await Task.sleep(nanoseconds: Self.CostSaverMode.batchedCircleSaveDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.saveState()
            }
        }
    }

    private func scheduleBatchedCircleBackendSync() {
        pendingCircleBackendSyncTask?.cancel()
        guard backendClient.isEnabled else { return }
        pendingCircleBackendSyncTask = Task {  [weak self] in
            try? await Task.sleep(nanoseconds: Self.CostSaverMode.batchedCircleSaveDelay)
            guard !Task.isCancelled else { return }
            await self?.pushCirclesToBackend()
        }
    }

    @discardableResult
    private func pruneCirclesForCost() -> Bool {
        let previousCircles = circles
        let previousUnread = unreadCircleMessageIDs
        circles = circles.map { circle in
            var updated = circle
            pruneMessagesForCost(in: &updated)
            return updated
        }
        let messageLookup = Dictionary(uniqueKeysWithValues: circles.flatMap { $0.messages }.map { ($0.id, $0) })
        unreadCircleMessageIDs = Set(
            unreadCircleMessageIDs.filter { messageID in
                guard let message = messageLookup[messageID] else { return false }
                return message.userID != currentUser.id
            }
        )
        return previousCircles != circles || previousUnread != unreadCircleMessageIDs
    }

    private func pruneMessagesForCost(in circle: inout CircleGroup) {
        let now = Date()
        circle.messages = circle.messages.filter { message in
            guard message.hasVoiceAttachment || message.hasPhotoAttachment else { return true }
            return (message.expiresAt ?? message.timestamp.addingTimeInterval(24 * 60 * 60)) > now
        }
        guard !currentUser.isVerified else { return }
        let expiry = Date().addingTimeInterval(-TimeInterval(Self.CostSaverMode.messageRetentionHours * 3600))
        circle.messages = circle.messages.filter { $0.timestamp >= expiry }
        if circle.messages.count > Self.CostSaverMode.maxMessagesStoredPerCircle {
            circle.messages = Array(circle.messages.suffix(Self.CostSaverMode.maxMessagesStoredPerCircle))
        }
    }

    func sendMessage(text: String, in circle: CircleGroup, sharedPostID: UUID? = nil) {
        guard currentUser.parentalControls.canUseCirclesMessaging || !currentUser.parentalControls.isEnabled else {
            moderationErrorMessage = "Parental Controls currently disable circles messaging for this account."
            return
        }
        let normalizedText = normalizeCircleMessageText(text)
        // The body text is allowed to be empty IF this message is a
        // shared-scroll forward — the sharedPostID alone is meaningful
        // content (the recipient sees a SharedScrollPreview card).  Pure
        // text messages with no share still require non-empty content.
        //
        // The share-only sentinel (a zero-width space) gets stripped here
        // by trimmingCharacters because `.whitespacesAndNewlines` includes
        // U+200B, so we must let `normalizedText` be empty in the share
        // path or the share is silently dropped.
        let hasSharedPost = sharedPostID != nil
        guard hasSharedPost || !normalizedText.isEmpty,
              circle.containsMember(currentUser),
              canSendMessage(in: circle) else { return }
        // Internal text used for spam/validation checks.  For pure shares
        // (empty normalized text), we substitute a stable sentinel so the
        // downstream spam-text dedup doesn't choke and the validator has
        // something concrete to operate on.  The downstream wire payload
        // still carries whatever the caller passed (preserving the actual
        // sentinel so the renderer's `isShareOnlySentinel` check fires).
        let trimmed = normalizedText.isEmpty ? "[shared_scroll]" : normalizedText
        guard recordSpamAction(
            key: "circle-message:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.circlesLimit,
            window: Self.SpamProtectionMode.circlesWindow,
            blockedMessage: "You're sending messages too quickly. Please slow down."
        ) else { return }
        guard recordSpamText(
            key: "circle-message-text:\(currentUser.id.uuidString)",
            text: trimmed,
            limit: Self.SpamProtectionMode.duplicateTextLimit,
            window: Self.SpamProtectionMode.duplicateTextWindow,
            blockedMessage: "You're repeating the same message too quickly."
        ) else { return }
        guard validateAllowedText(trimmed, context: "Circle messages") else { return }
        registerMessageSend(for: circle.id)
        // Circle encryption currently uses device-local key material, so
        // cross-device recipients cannot decrypt `v3:` payloads yet.
        // Keep wire format plaintext-prefixed for cross-account delivery
        // until shared circle-key exchange is implemented.
        //
        // Wire payload selection:
        //   • Pure shared-scroll forward (no user text) → send the
        //     zero-width-space sentinel so the recipient's chat renderer's
        //     `isShareOnlySentinel` check fires and hides the text bubble.
        //   • User-typed text (with or without an attached share) → send the
        //     user's normalized text.
        // The `trimmed` variable above is for spam/dedup checks only; it
        // can be a synthetic placeholder like `[shared_scroll]` without
        // affecting what the recipient sees.
        let wireBody: String
        if hasSharedPost && normalizedText.isEmpty {
            wireBody = SharedScrollMessageText.shareOnlySentinel
        } else {
            wireBody = normalizedText
        }
        let message = CircleMessage(
            id: UUID(),
            userID: currentUser.id,
            encryptedText: "plain:\(wireBody)",
            timestamp: Date(),
            sharedPostID: sharedPostID,
            sendStatus: .sending
        )
        setTyping(false, in: circle.id)
        updateCircleMessageDebug(
            messageID: message.id,
            stage: "queued_local",
            status: "Message saved locally",
            detail: "\(circleMessageDebugSummary(message: message, circleID: circle.id, source: "queued_local")), \(circleLocalMembershipDebugSummary(circleID: circle.id))",
            authPreflight: currentAuthSnapshotForSyncDebug(),
            resetFlow: true
        )
        mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
            updated.messages.append(message)
        }
        cachedCircles = nil
        relayCircleMessageToBackend(message, circleID: circle.id)
    }

    func sendVoiceMessage(localURL: URL, durationSeconds: Int, in circle: CircleGroup) {
        guard currentUser.parentalControls.canUseCirclesMessaging || !currentUser.parentalControls.isEnabled else {
            moderationErrorMessage = "Parental Controls currently disable circles messaging for this account."
            return
        }
        guard circle.containsMember(currentUser), canSendMessage(in: circle) else { return }
        let cappedDuration = max(1, min(durationSeconds, 120))
        guard durationSeconds <= 120 else {
            moderationErrorMessage = "Voice messages are limited to 2 minutes."
            return
        }
        guard recordSpamAction(
            key: "circle-voice:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.circlesLimit,
            window: Self.SpamProtectionMode.circlesWindow,
            blockedMessage: "You're sending messages too quickly. Please slow down."
        ) else { return }

        registerMessageSend(for: circle.id)
        setTyping(false, in: circle.id)
        let messageID = UUID()
        let expiresAt = Date().addingTimeInterval(24 * 60 * 60)
        let placeholder = CircleMessage(
            id: messageID,
            userID: currentUser.id,
            encryptedText: "plain:",
            timestamp: Date(),
            voiceDurationSeconds: cappedDuration,
            expiresAt: expiresAt,
            sendStatus: .sending
        )
        mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
            updated.messages.append(placeholder)
        }
        cachedCircles = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let upload = try await self.backendClient.uploadCircleVoiceMessage(
                    messageID: messageID,
                    authorID: self.currentUser.id,
                    localURL: localURL
                )
                let wirePayload = CircleMessage.voicePayloadText(
                    url: upload.legacyRef,
                    provider: upload.provider,
                    bucket: upload.bucket,
                    objectKey: upload.objectKey,
                    durationSeconds: cappedDuration,
                    expiresAt: expiresAt
                )
                let message = CircleMessage(
                    id: messageID,
                    userID: self.currentUser.id,
                    encryptedText: "plain:\(wirePayload)",
                    timestamp: placeholder.timestamp,
                    voiceProvider: upload.provider,
                    voiceBucket: upload.bucket,
                    voiceObjectKey: upload.objectKey,
                    voiceDurationSeconds: cappedDuration,
                    expiresAt: expiresAt,
                    sendStatus: .sending
                )
                await MainActor.run {
                    self.mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
                        guard let index = updated.messages.firstIndex(where: { $0.id == messageID }) else { return }
                        updated.messages[index] = message
                    }
                    self.cachedCircles = nil
                }
                await MainActor.run {
                    self.relayCircleMessageToBackend(message, circleID: circle.id)
                }
            } catch {
                await MainActor.run {
                    self.updateMessageSendStatus(messageID, in: circle.id, status: .failed)
                    self.moderationErrorMessage = "Voice message failed to upload. Please try again."
                }
            }
        }
    }

    func sendPhotoMessage(imageData: Data, in circle: CircleGroup) {
        guard currentUser.parentalControls.canUseCirclesMessaging || !currentUser.parentalControls.isEnabled else {
            moderationErrorMessage = "Parental Controls currently disable circles messaging for this account."
            return
        }
        guard circle.containsMember(currentUser), canSendMessage(in: circle) else { return }
        guard recordSpamAction(
            key: "circle-photo:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.circlesLimit,
            window: Self.SpamProtectionMode.circlesWindow,
            blockedMessage: "You're sending messages too quickly. Please slow down."
        ) else { return }
        guard let prepared = Self.preparedCirclePhotoJPEG(from: imageData) else {
            moderationErrorMessage = "Could not prepare that photo. Please try another image."
            return
        }

        registerMessageSend(for: circle.id)
        setTyping(false, in: circle.id)
        let messageID = UUID()
        let createdAt = Date()
        let expiresAt = createdAt.addingTimeInterval(24 * 60 * 60)
        let placeholder = CircleMessage(
            id: messageID,
            userID: currentUser.id,
            encryptedText: "plain:\(CircleMessage.photoPayloadPrefix)",
            timestamp: createdAt,
            photoObjectKey: "uploading",
            photoContentType: "image/jpeg",
            photoWidth: prepared.width,
            photoHeight: prepared.height,
            photoPreviewData: prepared.data,
            expiresAt: expiresAt,
            sendStatus: .sending
        )
        mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
            updated.messages.append(placeholder)
        }
        cachedCircles = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let upload = try await self.backendClient.uploadCirclePhotoMessage(
                    messageID: messageID,
                    authorID: self.currentUser.id,
                    data: prepared.data
                )
                let message = CircleMessage(
                    id: messageID,
                    userID: self.currentUser.id,
                    encryptedText: "plain:\(CircleMessage.photoPayloadPrefix)",
                    timestamp: createdAt,
                    photoProvider: upload.provider,
                    photoBucket: upload.bucket,
                    photoObjectKey: upload.objectKey,
                    photoContentType: "image/jpeg",
                    photoWidth: prepared.width,
                    photoHeight: prepared.height,
                    photoPreviewData: prepared.data,
                    expiresAt: expiresAt,
                    sendStatus: .sending
                )
                await MainActor.run {
                    self.mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
                        guard let index = updated.messages.firstIndex(where: { $0.id == messageID }) else { return }
                        updated.messages[index] = message
                    }
                    self.cachedCircles = nil
                }
                await MainActor.run {
                    self.relayCircleMessageToBackend(message, circleID: circle.id)
                }
            } catch {
                await MainActor.run {
                    self.mutateCircle(id: circle.id, deferSave: true, scheduleBackendSync: false) { updated in
                        updated.messages.removeAll { $0.id == messageID }
                    }
                    self.cachedCircles = nil
                    self.saveState()
                    self.moderationErrorMessage = "Photo message failed to upload. Please try again."
                }
            }
        }
    }

    private struct PreparedCirclePhotoJPEG: Sendable {
        let data: Data
        let width: Int
        let height: Int
    }

    private static func preparedCirclePhotoJPEG(from data: Data) -> PreparedCirclePhotoJPEG? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let maxPixel: CGFloat = 1600
        let largestSide = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxPixel / largestSide)
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = rendered.jpegData(compressionQuality: 0.82), !jpegData.isEmpty else {
            return nil
        }
        return PreparedCirclePhotoJPEG(
            data: jpegData,
            width: Int(targetSize.width),
            height: Int(targetSize.height)
        )
        #else
        return nil
        #endif
    }

    func markCircleVoiceMessageListened(_ message: CircleMessage, in circleID: UUID) {
        guard message.isVoiceMessage else { return }
        let messageID = message.id
        listenedCircleVoiceMessageIDs.insert(messageID)
        saveListenedCircleVoiceMessageIDs()
        mutateCircle(id: circleID, deferSave: true, scheduleBackendSync: false) { circle in
            circle.messages.removeAll { $0.id == messageID }
        }
        unreadCircleMessageIDs.remove(messageID)
        cachedCircles = nil
        saveState()
        guard backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "circle_voice_listened",
                    debugContext: BackendWriteDebugContext(
                        domain: .circleMessage,
                        targetID: messageID.uuidString,
                        action: "circle_voice_listened"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 15
                ) { authTokenOverride in
                    try await self.backendClient.markCircleVoiceMessageListened(
                        circleID: circleID,
                        messageID: messageID,
                        userID: self.currentUser.id,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                await MainActor.run {
                    self.updateCircleMessageDebug(
                        messageID: messageID,
                        stage: "voice_listened_failed",
                        status: "Voice delete-after-listen failed",
                        detail: "circle=\(String(circleID.uuidString.prefix(8))), message=\(String(messageID.uuidString.prefix(8)))",
                        error: error,
                        authPreflight: self.currentAuthSnapshotForSyncDebug()
                    )
                }
            }
        }
    }

    func markCirclePhotoMessageViewed(_ message: CircleMessage, in circleID: UUID) {
        guard message.isPhotoMessage else { return }
        guard message.userID != currentUser.id else { return }
        let messageID = message.id
        mutateCircle(id: circleID, deferSave: true, scheduleBackendSync: false) { circle in
            circle.messages.removeAll { $0.id == messageID }
        }
        unreadCircleMessageIDs.remove(messageID)
        cachedCircles = nil
        saveState()
        guard backendClient.isEnabled else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "circle_photo_viewed",
                    debugContext: BackendWriteDebugContext(
                        domain: .circleMessage,
                        targetID: messageID.uuidString,
                        action: "circle_photo_viewed"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 15
                ) { authTokenOverride in
                    try await self.backendClient.markCirclePhotoMessageViewed(
                        circleID: circleID,
                        messageID: messageID,
                        userID: self.currentUser.id,
                        authTokenOverride: authTokenOverride
                    )
                }
                await self.syncFromBackendIfAvailable(lane: .publishFollowUp, skipIdentityReconcile: true)
            } catch {
                await MainActor.run {
                    self.updateCircleMessageDebug(
                        messageID: messageID,
                        stage: "photo_viewed_failed",
                        status: "Photo delete-after-view failed",
                        detail: "circle=\(String(circleID.uuidString.prefix(8))), message=\(String(messageID.uuidString.prefix(8)))",
                        error: error,
                        authPreflight: self.currentAuthSnapshotForSyncDebug()
                    )
                }
            }
        }
    }

    func typingParticipants(for circleID: UUID) -> [TypingParticipant] {
        (typingParticipantsByCircleID[circleID] ?? [])
            .filter { $0.id != currentUser.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func startTypingPresence(for circleID: UUID) {
        guard backendClient.isEnabled else { return }
        guard typingPresenceTasks[circleID] == nil else { return }
        typingPresenceTasks[circleID] = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshTypingParticipants(for: circleID)
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    break
                }
            }
        }
    }

    func stopTypingPresence(for circleID: UUID) {
        setTyping(false, in: circleID)
        typingPresenceTasks[circleID]?.cancel()
        typingPresenceTasks[circleID] = nil
        typingClearTasks[circleID]?.cancel()
        typingClearTasks[circleID] = nil
        currentlyTypingCircleIDs.remove(circleID)
        lastTypingSignalAtByCircleID.removeValue(forKey: circleID)
        typingParticipantsByCircleID[circleID] = []
    }

    func setTyping(_ isTyping: Bool, in circleID: UUID) {
        guard backendClient.isEnabled else { return }
        if isTyping {
            let now = Date()
            let lastSignal = lastTypingSignalAtByCircleID[circleID] ?? .distantPast
            if now.timeIntervalSince(lastSignal) >= 2 {
                currentlyTypingCircleIDs.insert(circleID)
                lastTypingSignalAtByCircleID[circleID] = now
                sendTypingStatus(true, in: circleID, userID: currentUser.id)
            }
            typingClearTasks[circleID]?.cancel()
            typingClearTasks[circleID] = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 4_000_000_000)
                } catch {
                    return
                }
                await MainActor.run {
                    self?.setTyping(false, in: circleID)
                }
            }
        } else {
            typingClearTasks[circleID]?.cancel()
            typingClearTasks[circleID] = nil
            let hadTypingState = currentlyTypingCircleIDs.remove(circleID) != nil
                || lastTypingSignalAtByCircleID[circleID] != nil
            lastTypingSignalAtByCircleID.removeValue(forKey: circleID)
            if hadTypingState {
                sendTypingStatus(false, in: circleID, userID: currentUser.id)
            }
        }
    }

    private func refreshTypingParticipants(for circleID: UUID) async {
        guard backendClient.isEnabled else { return }
        let viewerID = await MainActor.run { currentUser.id }
        do {
            let participants = try await backendClient.fetchTypingParticipants(circleID: circleID, userID: viewerID)
            await MainActor.run {
                typingParticipantsByCircleID[circleID] = participants.filter { $0.id != self.currentUser.id }
            }
        } catch {
            await MainActor.run {
                typingParticipantsByCircleID[circleID] = typingParticipantsByCircleID[circleID] ?? []
            }
        }
    }

    private func sendTypingStatus(_ isTyping: Bool, in circleID: UUID, userID: UUID) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "circle_typing_status",
                    debugContext: BackendWriteDebugContext(
                        domain: .circleMessage,
                        targetID: circleID.uuidString,
                        action: isTyping ? "circle_typing_start" : "circle_typing_stop"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 8
                ) { authTokenOverride in
                    try await self.backendClient.updateTypingStatus(
                        circleID: circleID,
                        userID: userID,
                        isTyping: isTyping,
                        authTokenOverride: authTokenOverride
                    )
                }
            } catch {
                // Typing presence is intentionally best-effort; failed writes
                // must never block the actual message-send path.
            }
        }
    }

    private func clearTypingPresenceState(sendStopSignals: Bool) {
        let activeCircleIDs = Array(currentlyTypingCircleIDs)
        typingPresenceTasks.values.forEach { $0.cancel() }
        typingPresenceTasks.removeAll()
        typingClearTasks.values.forEach { $0.cancel() }
        typingClearTasks.removeAll()
        typingParticipantsByCircleID.removeAll()
        currentlyTypingCircleIDs.removeAll()
        lastTypingSignalAtByCircleID.removeAll()
        guard sendStopSignals else { return }
        let userID = currentUser.id
        activeCircleIDs.forEach { circleID in
            sendTypingStatus(false, in: circleID, userID: userID)
        }
    }

    private func updateMessageSendStatus(_ messageID: UUID, in circleID: UUID, status: MessageSendStatus) {
        mutateCircle(id: circleID, deferSave: false, scheduleBackendSync: false) { circle in
            guard let index = circle.messages.firstIndex(where: { $0.id == messageID }) else { return }
            circle.messages[index].sendStatus = status
        }
    }

    private func relayCircleMessageToBackend(_ message: CircleMessage, circleID: UUID) {
        guard backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.updateCircleMessageDebug(
                    messageID: message.id,
                    stage: "backend_request",
                    status: "Sending circle message to backend",
                    detail: "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "direct_send")), \(self.circleLocalMembershipDebugSummary(circleID: circleID))",
                    authPreflight: self.currentAuthSnapshotForSyncDebug()
                )
            }
            do {
                try await self.performAuthenticatedBackendWrite(
                    operationName: "circle_message_send",
                    debugContext: BackendWriteDebugContext(
                        domain: .circleMessage,
                        targetID: message.id.uuidString,
                        action: "circle_message_send"
                    ),
                    maxAttempts: 1,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    try await self.backendClient.sendCircleMessage(
                        circleID: circleID,
                        message: message,
                        authTokenOverride: authTokenOverride
                    )
                }
                await MainActor.run {
                    self.updateMessageSendStatus(message.id, in: circleID, status: .sent)
                    self.cachedCircles = nil
                    self.updateCircleMessageDebug(
                        messageID: message.id,
                        stage: "sync_success_direct",
                        status: "Message synced",
                        detail: "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "direct_success")), outcome=success, path=direct",
                        authPreflight: self.currentAuthSnapshotForSyncDebug()
                    )
                }
                await self.syncFromBackendIfAvailable(lane: .publishFollowUp, skipIdentityReconcile: true)
            } catch {
                var recovered = false
                var recoveryError: Error?
                // Circle scope denied (members=0) means the circle wasn't upserted yet —
                // upsert recovery is exactly the right fix even though it's a 401.
                let canAttemptUpsertRecovery = (!self.isAuthenticationFailureError(error) || self.isCircleScopeDeniedError(error))
                    && !self.isBackendWritePreflightError(error)
                if canAttemptUpsertRecovery, let latestCircle = self.circle(by: circleID) {
                    do {
                        try await self.performAuthenticatedBackendWrite(
                            operationName: "circle_upsert_then_send",
                            debugContext: BackendWriteDebugContext(
                                domain: .circleMessage,
                                targetID: message.id.uuidString,
                                action: "circle_upsert"
                            ),
                            maxAttempts: 1,
                            timeoutPerAttempt: 20
                        ) { _ in
                            try await self.backendClient.upsertCircle(latestCircle)
                        }
                        try await self.performAuthenticatedBackendWrite(
                            operationName: "circle_message_send_recover",
                            debugContext: BackendWriteDebugContext(
                                domain: .circleMessage,
                                targetID: message.id.uuidString,
                                action: "circle_message_send_recover"
                            ),
                            maxAttempts: 1,
                            timeoutPerAttempt: 20
                        ) { authTokenOverride in
                            try await self.backendClient.sendCircleMessage(
                                circleID: circleID,
                                message: message,
                                authTokenOverride: authTokenOverride
                            )
                        }
                        recovered = true
                    } catch {
                        recoveryError = error
                        recovered = false
                    }
                } else if !canAttemptUpsertRecovery {
                    await MainActor.run {
                        self.updateCircleMessageDebug(
                            messageID: message.id,
                            stage: "upsert_recovery_skipped_auth",
                            status: "Skipped circle upsert recovery due auth state",
                            detail: "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "recovery_skipped_auth")), queued_retry_preferred=yes, \(self.circleLocalMembershipDebugSummary(circleID: circleID))",
                            error: error,
                            authPreflight: self.currentAuthSnapshotForSyncDebug()
                        )
                    }
                }
                if recovered {
                    await MainActor.run {
                        self.updateMessageSendStatus(message.id, in: circleID, status: .sent)
                        self.cachedCircles = nil
                        self.updateCircleMessageDebug(
                            messageID: message.id,
                            stage: "sync_success_recovered",
                            status: "Message synced after recovery",
                            detail: "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "recovered_success")), outcome=success, path=upsert_then_send",
                            authPreflight: self.currentAuthSnapshotForSyncDebug()
                        )
                    }
                    await self.syncFromBackendIfAvailable(lane: .publishFollowUp, skipIdentityReconcile: true)
                    return
                }
                let finalError = recoveryError ?? error
                let initialErrorString = self.backendErrorDebugString(error)
                let recoveryErrorString = recoveryError.map { self.backendErrorDebugString($0) } ?? "none"
                let terminalAuthFailure = self.isTerminalAuthFailureForBackendWrite(finalError)
                await MainActor.run {
                    self.updateMessageSendStatus(message.id, in: circleID, status: .failed)
                    if terminalAuthFailure {
                        self.lastTerminalAuthFailureAt = Date()
                        self.moderationErrorMessage = "Message failed due to authentication. Please reauthenticate and retry."
                        let terminalDetail = "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "terminal_auth", retryCount: 0)), outcome=failure, terminal_auth=yes, initial_error=\(initialErrorString), recovery_error=\(recoveryErrorString), \(self.circleLocalMembershipDebugSummary(circleID: circleID))"
                        self.updateCircleMessageDebug(
                            messageID: message.id,
                            stage: "sync_failure_terminal_auth",
                            status: "Message sync paused for terminal auth failure",
                            detail: terminalDetail,
                            error: finalError,
                            authPreflight: self.currentAuthSnapshotForSyncDebug()
                        )
                    } else {
                        self.enqueuePendingBackendWrite(
                            PendingBackendWriteOperation(
                                id: UUID(),
                                kind: .circleMessage,
                                createdAt: Date(),
                                retryCount: 0,
                                userID: message.userID,
                                postID: message.sharedPostID,
                                authorID: nil,
                                commentID: nil,
                                body: nil,
                                parentCommentID: nil,
                                originalPostID: nil,
                                rescrollPostID: nil,
                                circleID: circleID,
                                messageID: message.id,
                                encryptedText: message.encryptedText,
                                messageTimestamp: message.timestamp
                            )
                        )
                        self.triggerPendingBackendWriteFlush(after: 0, force: true)
                        self.moderationErrorMessage = "Message failed to sync. Please retry after signing in again."
                        let queuedDetail = "\(self.circleMessageDebugSummary(message: message, circleID: circleID, source: "queued_retry", retryCount: 0)), outcome=failure, initial_error=\(initialErrorString), recovery_error=\(recoveryErrorString), next_worker_delay=2s, \(self.circleLocalMembershipDebugSummary(circleID: circleID))"
                        self.updateCircleMessageDebug(
                            messageID: message.id,
                            stage: "sync_failure_queued_retry",
                            status: "Message sync failed; queued for retry",
                            detail: queuedDetail,
                            error: finalError,
                            authPreflight: self.currentAuthSnapshotForSyncDebug()
                        )
                    }
                }
            }
        }
    }

    func pruneCircleMessagesNow() {
        pruneCirclesForCost()
        saveState()
    }

    func syncCircleInbox(forceRefresh: Bool = true) {
        guard backendClient.isEnabled else { return }
        Task {  [weak self] in
            guard let self else { return }
            await self.syncCircleInboxFromBackend(forceRefresh: forceRefresh)
        }
    }

    func ensureCircleAvailable(circleID: UUID, forceRefresh: Bool = true) async -> Bool {
        if await MainActor.run(body: { self.circle(by: circleID) != nil }) {
            return true
        }

        await syncCircleInboxFromBackend(forceRefresh: forceRefresh)
        if await MainActor.run(body: { self.circle(by: circleID) != nil }) {
            return true
        }

        cachedCircles = nil
        await syncCircleInboxFromBackend(forceRefresh: true)
        let resolved = await MainActor.run(body: { self.circle(by: circleID) != nil })
        if !resolved {
            updateFeedDebug(
                stage: "circle_invite_missing",
                status: "Circle invite unavailable",
                detail: "circle_id=\(String(circleID.uuidString.prefix(8))), local_circles=\(circles.count)"
            )
        }
        return resolved
    }

    private func syncCircleInboxFromBackend(forceRefresh: Bool) async {
        let userID = currentUser.id
        guard let remoteCircles = await fetchCirclesForSync(userID: userID, forceRefresh: forceRefresh) else {
            return
        }
        await MainActor.run {
            self.mergeRemoteCircles(remoteCircles)
            if self.pruneCirclesForCost() {
                self.saveState()
            }
        }
    }

    func createCircle(name: String, members: [UserProfile]) {
        guard currentUser.parentalControls.canUseCirclesMessaging || !currentUser.parentalControls.isEnabled else {
            moderationErrorMessage = "Parental Controls currently disable circles messaging for this account."
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let eligibleMembers = members.filter { canAddToCircleChats($0) }
        guard !eligibleMembers.isEmpty else { return }
        var circleMembers = eligibleMembers.map { profile in
            CircleMember(id: UUID(), profileID: profile.id, status: .invited)
        }
        circleMembers.append(
            CircleMember(id: UUID(), profileID: currentUser.id, status: .member)
        )
        let circle = CircleGroup(
            id: UUID(),
            name: trimmed,
            members: circleMembers,
            messages: [],
            createdAt: Date()
        )
        circles.insert(circle, at: 0)
        dirtyCircleIDs.insert(circle.id)
        saveState()
        scheduleBatchedCircleBackendSync()
    }

    func updateCreatedCircleName(_ circle: CircleGroup, to name: String) {
        guard canEditCreatedCircle(circle) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != circle.name else { return }
        mutateCircle(id: circle.id) { updated in
            updated.name = trimmed
        }
    }

    func updateCreatedCircleAvatar(_ circle: CircleGroup, image: PlatformImage) {
        guard canEditCreatedCircle(circle) else { return }
        guard let data = MediaStorage.compressedAvatarData(from: image), !data.isEmpty else { return }
        mutateCircle(id: circle.id) { updated in
            updated.avatarImageData = data
            updated.avatarRef = nil
        }
    }

    func clearCreatedCircleAvatar(_ circle: CircleGroup) {
        guard canEditCreatedCircle(circle) else { return }
        guard circle.avatarImageData != nil || !(circle.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) else { return }
        mutateCircle(id: circle.id) { updated in
            updated.avatarImageData = nil
            updated.avatarRef = nil
        }
    }

    func deleteCircle(_ circle: CircleGroup) {
        let messageIDs = Set(circle.messages.map { $0.id })
        unreadCircleMessageIDs.subtract(messageIDs)
        pendingBackendWriteQueue.removeAll { operation in
            operation.circleID == circle.id
        }
        circles.removeAll(where: { $0.id == circle.id })
        dirtyCircleIDs.remove(circle.id)
        cachedCircles = nil
        saveState()
        savePendingBackendWriteQueue()
        guard backendClient.isEnabled else { return }
        enqueuePendingBackendWrite(
            PendingBackendWriteOperation(
                id: UUID(),
                kind: .circleDelete,
                createdAt: Date(),
                retryCount: 0,
                userID: currentUser.id,
                postID: nil,
                authorID: nil,
                commentID: nil,
                body: nil,
                parentCommentID: nil,
                originalPostID: nil,
                rescrollPostID: nil,
                circleID: circle.id,
                messageID: nil,
                encryptedText: nil,
                messageTimestamp: nil
            )
        )
        triggerPendingBackendWriteFlush(after: 300_000_000, force: true)
    }

    private func canEditCreatedCircle(_ circle: CircleGroup) -> Bool {
        !circle.isOneOnOneConversation
    }

    func addMember(_ profile: UserProfile, to circle: CircleGroup) {
        guard canAddToCircleChats(profile) else { return }
        mutateCircle(id: circle.id) { updated in
            guard !updated.members.contains(where: { $0.profileID == profile.id }) else { return }
            updated.members.append(
                CircleMember(id: UUID(), profileID: profile.id, status: .invited)
            )
        }
    }

    func removeMember(_ profile: UserProfile, from circle: CircleGroup) {
        mutateCircle(id: circle.id) { updated in
            updated.members.removeAll(where: { $0.profileID == profile.id })
        }
    }

    func leaveCircle(_ circle: CircleGroup) {
        mutateCircle(id: circle.id) { updated in
            updated.members.removeAll(where: { $0.profileID == currentUser.id })
        }
        if let updated = self.circle(by: circle.id), updated.members.isEmpty {
            deleteCircle(updated)
        }
    }

    func clearCircleChat(_ circle: CircleGroup) {
        guard circle.members.contains(where: { $0.profileID == currentUser.id && $0.status == .member }) else { return }
        unreadCircleMessageIDs.subtract(circle.messages.map(\.id))
        pendingBackendWriteQueue.removeAll { operation in
            operation.circleID == circle.id && operation.kind == .circleMessage
        }
        mutateCircle(id: circle.id, deferSave: false, scheduleBackendSync: false) { updated in
            updated.messages.removeAll()
        }
        savePendingBackendWriteQueue()
        guard backendClient.isEnabled else { return }
        enqueuePendingBackendWrite(
            PendingBackendWriteOperation(
                id: UUID(),
                kind: .circleClear,
                createdAt: Date(),
                retryCount: 0,
                userID: currentUser.id,
                postID: nil,
                authorID: nil,
                commentID: nil,
                body: nil,
                parentCommentID: nil,
                originalPostID: nil,
                rescrollPostID: nil,
                circleID: circle.id,
                messageID: nil,
                encryptedText: nil,
                messageTimestamp: nil
            )
        )
        triggerPendingBackendWriteFlush(after: 300_000_000, force: true)
    }

    func ensureOneOnOneCircle(with profile: UserProfile) -> CircleGroup? {
        guard canAddToCircleChats(profile) else { return nil }
        if let existing = circles.first(where: { $0.isDirectConversation(between: currentUser.id, and: profile.id) }) {
            return existing
        }
        let circle = CircleGroup(
            id: UUID(),
            name: "One On One With \(profile.displayName)",
            members: [
                CircleMember(id: UUID(), profileID: currentUser.id, status: .member),
                CircleMember(id: UUID(), profileID: profile.id, status: .member)
            ],
            messages: [],
            createdAt: Date()
        )
        circles.insert(circle, at: 0)
        dirtyCircleIDs.insert(circle.id)
        saveState()
        return circle
    }

    func circle(by id: UUID) -> CircleGroup? {
        circles.first(where: { $0.id == id })
    }

    func markCircleMessagesRead(in circleID: UUID) {
        guard let circle = circle(by: circleID) else { return }
        let messageIDs = circle.messages.filter { $0.userID != currentUser.id }.map { $0.id }
        let updatedSet = unreadCircleMessageIDs.subtracting(messageIDs)
        if updatedSet != unreadCircleMessageIDs {
            unreadCircleMessageIDs = updatedSet
            saveState()
        }
    }

    func decryptedCircleMessageText(_ message: CircleMessage, in circleID: UUID) -> String {
        if message.hasPhotoAttachment {
            return "Photo message"
        }
        return message.text(for: circleID)
    }

    func profile(for id: UUID) -> UserProfile? {
        guard let profile = profileRegistry[id] else { return nil }
        return self.profile(forUsername: profile.username) ?? profile
    }

    func refreshProfileFromBackend(id: UUID, username: String) async {
        guard backendClient.isEnabled else { return }
        var resolved: BackendUser?
        if let byID = try? await backendClient.fetchUser(id: id) {
            resolved = byID
        } else if let byIDPublic = try? await backendClient.fetchUser(id: id, includeAuthorization: false) {
            resolved = byIDPublic
        } else if let byUsername = try? await backendClient.fetchUserByUsername(username, includeAuthorization: false) {
            resolved = byUsername
        }
        guard let resolved else { return }
        let mapped = roleAdjustedProfile(resolved.asUserProfile)
        registerProfile(mapped, writeVersion: resolved.writeVersion)
        if mapped.id == currentUser.id {
            mergeRemoteCurrentUser(resolved)
        }
        normalizeIdentityState()
        syncFollowDirectories()
        saveState()
    }

    func refreshCurrentUserProfileFromBackend() async {
        let username = currentUser.username
        let currentID = currentUser.id
        await refreshProfileFromBackend(id: currentID, username: username)
        let resolvedProfile = profile(forUsername: username) ?? currentUser
        await fetchAndMergeProfilePosts(for: resolvedProfile, resetPagination: true)
    }

    func fetchAndMergeProfilePosts(for profile: UserProfile, resetPagination: Bool = false) async {
        guard backendClient.isEnabled else { return }

        func pruneMissingProfilePosts(authorID: UUID, keeping fetchedIDs: Set<UUID>, exhausted: Bool) {
            guard exhausted else { return }
            let removedIDs = Set(
                posts
                    .filter { $0.user.id == authorID && !fetchedIDs.contains($0.id) }
                    .map(\.id)
            )
            guard !removedIDs.isEmpty else { return }
            posts.removeAll { removedIDs.contains($0.id) }
            pendingRemotePosts.removeAll { removedIDs.contains($0.id) }
            deliveredAdPosts.removeAll { removedIDs.contains($0.id) }
            trustedTimelinePostIDs.subtract(removedIDs)
        }

        func loadPage(for targetProfile: UserProfile, reset: Bool) async throws -> (fetchedIDs: Set<UUID>, exhausted: Bool) {
            let authorID = targetProfile.id
            if reset {
                profilePostsNextCursorByUserID[authorID] = nil
                profilePostsExhaustedUserIDs.remove(authorID)
            } else {
                guard !profilePostsExhaustedUserIDs.contains(authorID) else {
                    return ([], true)
                }
            }
            guard !profilePostsLoadInFlightUserIDs.contains(authorID) else {
                return ([], false)
            }
            profilePostsLoadInFlightUserIDs.insert(authorID)
            defer { profilePostsLoadInFlightUserIDs.remove(authorID) }

            let cursor = reset ? nil : (profilePostsNextCursorByUserID[authorID] ?? nil)
            let page = try await backendClient.fetchPostsByAuthor(
                authorID: authorID,
                limit: Self.profilePostsPageSize,
                cursor: cursor
            )
            if let tombstones = page.deletedPostIDs, !tombstones.isEmpty {
                for id in tombstones {
                    markPostDeleted(id)
                }
                saveState()
            }
            guard !page.posts.isEmpty else {
                profilePostsNextCursorByUserID[authorID] = nil
                profilePostsExhaustedUserIDs.insert(authorID)
                return ([], true)
            }
            mergeRemotePosts(page.posts, source: .profileFetch)
            let fetchedIDs = Set(page.posts.map(\.id))
            let nextCursor = normalizedFeedCursor(page.nextCursor)
            profilePostsNextCursorByUserID[authorID] = nextCursor
            if nextCursor == nil {
                profilePostsExhaustedUserIDs.insert(authorID)
            } else {
                profilePostsExhaustedUserIDs.remove(authorID)
            }
            return (fetchedIDs, nextCursor == nil)
        }

        let performLoad = { [self] (preferRefresh: Bool) async throws in
            _ = await BackendTruthSyncCore.ensureActiveSession(
                for: resolvedBackendSessionUsername(),
                expectedUserID: currentUser.id,
                using: backendClient,
                preferRefresh: preferRefresh
            )
            restoreBackendAuthTokenForCurrentUserIfNeeded()

            let initialResult = try await loadPage(for: profile, reset: resetPagination)
            if resetPagination {
                pruneMissingProfilePosts(
                    authorID: profile.id,
                    keeping: initialResult.fetchedIDs,
                    exhausted: initialResult.exhausted
                )
            }

            if let latestProfile = self.profile(forUsername: profile.username),
               latestProfile.id != profile.id {
                let latestResult = try await loadPage(for: latestProfile, reset: resetPagination)
                if resetPagination {
                    pruneMissingProfilePosts(
                        authorID: latestProfile.id,
                        keeping: latestResult.fetchedIDs,
                        exhausted: latestResult.exhausted
                    )
                }
            }
        }

        do {
            try await performLoad(false)
        } catch {
            if isAuthenticationFailureError(error) {
                do {
                    try await performLoad(true)
                    return
                } catch {
                    // Non-critical — profile shows whatever is already in cache
                }
            }
            // Non-critical — profile shows whatever is already in cache
        }
    }

    func loadMoreProfilePostsIfNeeded(for profile: UserProfile) {
        let resolved = self.profile(forUsername: profile.username) ?? self.profile(for: profile.id) ?? profile
        let targetIDs = Set([profile.id, resolved.id])
        guard targetIDs.contains(where: { !profilePostsExhaustedUserIDs.contains($0) }) else { return }
        guard !targetIDs.contains(where: { profilePostsLoadInFlightUserIDs.contains($0) }) else { return }
        Task { [weak self] in
            await self?.fetchAndMergeProfilePosts(for: resolved, resetPagination: false)
        }
    }

    func refreshDirectoryProfilesFromBackend(for profile: UserProfile) async {
        guard backendClient.isEnabled else { return }
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        var targetProfile = profile
        var didMutateRelations = false

        if let resolved = try? await backendClient.fetchUserByUsername(profile.username, includeAuthorization: false) {
            let mapped = roleAdjustedProfile(resolved.asUserProfile)
            registerProfile(mapped, writeVersion: resolved.writeVersion)
            targetProfile = mapped
            if mapped.id != profile.id, let oldFollowing = followRelations.removeValue(forKey: profile.id) {
                var merged = followRelations[mapped.id] ?? []
                merged.formUnion(oldFollowing.map { $0 == profile.id ? mapped.id : $0 })
                followRelations[mapped.id] = merged
                didMutateRelations = true
            }
            if mapped.id == currentUser.id {
                mergeRemoteCurrentUser(resolved)
            }
        }

        let targetProfileID = targetProfile.id
        let requestedGraphUserID = targetProfileID
        async let followingFetch = backendClient.fetchFollowing(
            userID: requestedGraphUserID,
            allowAuthContextFallbackOnEmpty: false
        )
        async let followersFetch = backendClient.fetchFollowers(
            userID: requestedGraphUserID,
            allowAuthContextFallbackOnEmpty: false
        )

        if let remoteFollowing = try? await followingFetch {
            let mappedFollowing = remoteFollowing.map { roleAdjustedProfile($0.asUserProfile) }
            registerProfiles(from: remoteFollowing, applyRoleAdjustment: true)
            for profile in mappedFollowing {
                Self.saveProfileSnapshot(profile)
            }
            var followeeIDs = Set(mappedFollowing.map(\.id))
            if targetProfile.id == currentUser.id {
                for requiredID in mandatoryFollowIDs() where requiredID != currentUser.id {
                    followeeIDs.insert(requiredID)
                }
            }
            if followRelations[targetProfile.id] != followeeIDs {
                followRelations[targetProfile.id] = followeeIDs
                didMutateRelations = true
            }
        }

        if let remoteFollowers = try? await followersFetch {
            let mappedFollowers = remoteFollowers.map { roleAdjustedProfile($0.asUserProfile) }
            registerProfiles(from: remoteFollowers, applyRoleAdjustment: true)
            for profile in mappedFollowers {
                Self.saveProfileSnapshot(profile)
            }
            let followerIDs = Set(mappedFollowers.map(\.id))
            let allKnownIDs = Set(followRelations.keys).union(profileRegistry.keys)
            for userID in allKnownIDs {
                var follows = followRelations[userID] ?? []
                let shouldFollow = followerIDs.contains(userID)
                let alreadyFollows = follows.contains(targetProfile.id)
                if shouldFollow && !alreadyFollows {
                    follows.insert(targetProfile.id)
                    followRelations[userID] = follows
                    didMutateRelations = true
                } else if !shouldFollow && alreadyFollows {
                    follows.remove(targetProfile.id)
                    followRelations[userID] = follows
                    didMutateRelations = true
                }
            }
        }

        if targetProfileID == currentUser.id {
            await refreshPendingFollowRequestsFromBackend()
        }

        normalizeIdentityState()
        syncFollowDirectories()
        if didMutateRelations {
            saveState()
        }
    }

    func refreshPendingFollowRequestsFromBackend() async {
        guard backendClient.isEnabled else { return }
        guard let remoteRequests = try? await backendClient.fetchFollowRequests(userID: currentUser.id) else { return }
        mergeRemoteFollowRequests(remoteRequests)
    }

    private func mergeRemoteFollowRequests(_ users: [BackendUser]) {
        registerProfiles(from: users, applyRoleAdjustment: true)
        let mapped = users.map { roleAdjustedProfile($0.asUserProfile) }
        for profile in mapped {
            Self.saveProfileSnapshot(profile)
        }
        var deduped: [UUID: UserProfile] = [:]
        for profile in mapped {
            deduped[profile.id] = profile
        }
        let sorted = Array(deduped.values).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        if pendingFollowRequests != sorted {
            pendingFollowRequests = sorted
        }
    }

    func post(with id: UUID) -> FeedPost? {
        posts.first(where: { $0.id == id })
    }

    func notificationTargetPostID(for notification: AppNotification) -> UUID? {
        switch notification.type {
        case .commentLiked, .commentReplied, .rescrolled, .mention, .collaborated:
            if let objectID = notification.objectID,
               post(with: objectID) != nil {
                return objectID
            }
            if let actorID = notification.actorID {
                return posts.first(where: { $0.user.id == actorID || $0.rescrollOrigin?.user.id == actorID })?.id
            }
            return posts.first?.id
        case .general, .followed, .circleMessage, .circleVoiceMessage, .circleSharedPost:
            return nil
        }
    }

    func notificationTargetProfile(for notification: AppNotification) -> UserProfile? {
        switch notification.type {
        case .followed:
            if let actorID = notification.actorID, let profile = profileRegistry[actorID] {
                return profile
            }
            if let objectID = notification.objectID {
                return profileRegistry[objectID]
            }
            return nil
        case .mention, .collaborated:
            if let actorID = notification.actorID {
                return profileRegistry[actorID]
            }
            return nil
        case .general, .commentLiked, .commentReplied, .rescrolled, .circleMessage, .circleVoiceMessage, .circleSharedPost:
            return nil
        }
    }

    func updateCurrentUserUsername(to username: String) {
        updateCurrentUserProfile(username: username)
    }

    func updateCurrentUserAvatar(with image: PlatformImage) {
        updateCurrentUserProfile(avatarImage: image)
    }

    func updateCurrentUserAvatarVideo(withVideoAt localURL: URL) async throws {
        guard hasSubscriberBenefits(for: currentUser) else {
            throw MediaPreparationError.unsupportedType
        }
        let uploadedRef: String?
        if backendClient.isEnabled {
            BackendTruthSyncCore.seedSessionForActiveUsername(
                currentUser.username,
                expectedUserID: currentUser.id,
                using: backendClient
            )
            _ = await BackendTruthSyncCore.ensureActiveSession(
                for: currentUser.username,
                expectedUserID: currentUser.id,
                using: backendClient,
                preferRefresh: true
            )
            restoreBackendAuthTokenForCurrentUserIfNeeded()
            do {
                uploadedRef = try await backendClient.uploadProfileAvatarVideo(localURL: localURL, userID: currentUser.id)
            } catch {
                if isAuthenticationFailureError(error) {
                    _ = await BackendTruthSyncCore.ensureActiveSession(
                        for: currentUser.username,
                        expectedUserID: currentUser.id,
                        using: backendClient,
                        preferRefresh: true
                    )
                    restoreBackendAuthTokenForCurrentUserIfNeeded()
                    uploadedRef = try await backendClient.uploadProfileAvatarVideo(localURL: localURL, userID: currentUser.id)
                } else {
                    throw error
                }
            }
        } else {
            uploadedRef = nil
        }
        let resolvedRef = (uploadedRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? uploadedRef!
            : localURL.absoluteString
        updateCurrentUserProfile(avatarVideoRef: resolvedRef)
        setPreferredProfileHeroMedia(.video, for: currentUser)
    }

    func clearCurrentUserAvatarVideo() {
        updateCurrentUserProfile(avatarVideoRef: "")
        setPreferredProfileHeroMedia(.photo, for: currentUser)
    }

    func usePhotoForCurrentUserProfileAvatar() {
        setPreferredProfileHeroMedia(.photo, for: currentUser)
    }

    func useVideoForCurrentUserProfileAvatar() {
        let resolvedProfile = profile(forUsername: currentUser.username) ?? currentUser
        let resolvedVideoRef = resolvedProfile.avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolvedVideoRef.isEmpty else { return }
        let currentVideoRef = currentUser.avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if currentVideoRef != resolvedVideoRef {
            currentUser = currentUser.with(avatarVideoRef: resolvedVideoRef)
            registerProfile(currentUser)
            Self.saveProfileSnapshot(currentUser)
            saveState()
        }
        setPreferredProfileHeroMedia(.video, for: currentUser)
    }

    func preferredProfileHeroMedia(for profile: UserProfile) -> ProfileHeroMediaPreference {
        let normalized = normalizeUsername(profile.username)
        let key = Self.profileHeroMediaPreferenceKeyPrefix + normalized
        if let raw = UserDefaults.standard.string(forKey: key),
           let stored = ProfileHeroMediaPreference(rawValue: raw) {
            return stored
        }
        let resolvedProfile = self.profile(forUsername: profile.username) ?? profile
        let hasVideo = !(resolvedProfile.avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasVideo ? .video : .photo
    }

    func setPreferredProfileHeroMedia(_ preference: ProfileHeroMediaPreference, for profile: UserProfile) {
        let normalized = normalizeUsername(profile.username)
        let key = Self.profileHeroMediaPreferenceKeyPrefix + normalized
        UserDefaults.standard.set(preference.rawValue, forKey: key)
        objectWillChange.send()
    }

    func flushCurrentProfileToBackendBeforeSwitch() async {
        pendingStateSaveTask?.cancel()
        persistStateSnapshot()
        Self.saveProfileSnapshot(currentUser)
        for account in Self.founderManagedBusinessAccounts {
            if let profile = profileRegistry[account.id] {
                Self.saveProfileSnapshot(profile)
            }
        }
        guard backendClient.isEnabled else { return }
        let profile = currentUser
        markPendingProfilePush(profile)
        let generation = profilePushGeneration
        await persistCurrentUserProfileToBackend(expectedGeneration: generation, profileOverride: profile)
        Self.saveProfileSnapshot(currentUser)
    }

    func refreshCurrentUserProfilePresentation() {
        registerProfile(currentUser)
        normalizeIdentityState()
        refreshCurrentUserPosts()
        syncFollowDirectories()
        saveState()
    }

    func persistStateForAppBackground() {
        pendingStateSaveTask?.cancel()
        persistStateSnapshot()
        Self.saveProfileSnapshot(currentUser)
    }

    func isFollowing(_ profile: UserProfile) -> Bool {
        guard normalizeUsername(profile.username) != normalizeUsername(currentUser.username) else { return false }
        return following.contains(where: { normalizeUsername($0.username) == normalizeUsername(profile.username) })
    }

    func canAddToCircleChats(_ profile: UserProfile) -> Bool {
        guard normalizeUsername(profile.username) != normalizeUsername(currentUser.username) else { return false }
        guard let canonical = canonicalProfile(matching: profile) else { return false }
        let currentIDs = profileIdentityIDs(for: currentUser)
        let recipientIDs = profileIdentityIDs(for: canonical)
        let currentFollowing = currentIDs.reduce(into: Set<UUID>()) { partial, userID in
            partial.formUnion(followRelations[userID] ?? [])
        }
        let recipientFollowing = recipientIDs.reduce(into: Set<UUID>()) { partial, userID in
            partial.formUnion(followRelations[userID] ?? [])
        }
        return !currentFollowing.intersection(recipientIDs).isEmpty
            && !recipientFollowing.intersection(currentIDs).isEmpty
    }

    private func profileIdentityIDs(for profile: UserProfile) -> Set<UUID> {
        var ids: Set<UUID> = [profile.id]
        let normalizedUsername = normalizeUsername(profile.username)
        if isFounderClusterProfile(profile) || Self.protectedFounderBlockUsernames.contains(normalizedUsername) {
            ids.formUnion(Self.founderAuthSubjectIDs)
            ids.insert(Self.founderCanonicalAccount.id)
            for candidate in profileRegistry.values where isFounderClusterProfile(candidate) {
                ids.insert(candidate.id)
            }
        } else if !normalizedUsername.isEmpty {
            for candidate in profileRegistry.values where normalizeUsername(candidate.username) == normalizedUsername {
                ids.insert(candidate.id)
            }
        }
        return ids
    }

    var mutualCircleCandidates: [UserProfile] {
        searchableProfiles.filter { canAddToCircleChats($0) }
    }

    func follow(profile: UserProfile) {
        guard normalizeUsername(profile.username) != normalizeUsername(currentUser.username) else { return }
        guard let canonical = canonicalProfile(matching: profile) else { return }
        guard recordSpamAction(
            key: "follow:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.followLimit,
            window: Self.SpamProtectionMode.followWindow,
            blockedMessage: "You've reached the follow limit. Please try again later."
        ) else { return }
        let alreadyFollowing = isFollowing(profile)
        let requiresApproval = canonical.isPrivateAccount && canonical.id != currentUser.id
        if requiresApproval && !alreadyFollowing {
            pendingOutgoingFollowRequestIDs.insert(canonical.id)
            invalidateCachesForFollowGraphMutation()
            enqueuePendingFollowSync(
                followerID: currentUser.id,
                followeeID: canonical.id,
                isFollowing: true
            )
            triggerPendingFollowSyncFlush(force: true)
            return
        }
        addFollowRelation(from: currentUser.id, to: canonical.id)
        pendingOutgoingFollowRequestIDs.remove(canonical.id)
        syncFollowDirectories()
        if !alreadyFollowing {
            // Follow notifications are backend-authored for the followee.
            // Never create them locally on the follower's own inbox.
            saveState()
        }
        invalidateCachesForFollowGraphMutation()
        // Force SwiftUI to re-render the feed immediately so any posts the new
        // followee already has cached in `posts` become visible via the
        // mainFeedPosts filter without waiting on the backend round-trip.
        objectWillChange.send()
        enqueuePendingFollowSync(
            followerID: currentUser.id,
            followeeID: canonical.id,
            isFollowing: true
        )
        triggerPendingFollowSyncFlush(force: true)
        // Pull a fresh feed page so posts the newly-followed user has authored
        // (but that aren't yet in our local `posts` array) load on the next
        // refresh.  Without this, the user has to manually pull-to-refresh to
        // see any of the new followee's content.
        if !alreadyFollowing {
            Task { [weak self] in
                guard let self else { return }
                await self.syncFromBackendIfAvailable(lane: .feedFast, skipIdentityReconcile: true)
            }
        }
    }

    func unfollow(profile: UserProfile) {
        guard normalizeUsername(profile.username) != normalizeUsername(currentUser.username) else { return }
        guard !isMandatoryFollowAccount(profile) else { return }
        guard let canonical = canonicalProfile(matching: profile) else { return }
        guard !isMandatoryFollowAccount(canonical) else { return }
        guard recordSpamAction(
            key: "unfollow:\(currentUser.id.uuidString)",
            limit: Self.SpamProtectionMode.unfollowLimit,
            window: Self.SpamProtectionMode.unfollowWindow,
            blockedMessage: "You've reached the unfollow limit for today. Please try again tomorrow."
        ) else { return }
        let wasPendingRequest = pendingOutgoingFollowRequestIDs.contains(canonical.id)
        if wasPendingRequest {
            pendingOutgoingFollowRequestIDs.remove(canonical.id)
            invalidateCachesForFollowGraphMutation()
            enqueuePendingFollowSync(
                followerID: currentUser.id,
                followeeID: canonical.id,
                isFollowing: false
            )
            triggerPendingFollowSyncFlush(force: true)
            return
        }
        let wasFollowing = isFollowing(profile)
        removeFollowRelation(from: currentUser.id, to: canonical.id)
        enforceMandatoryFounderFollows()
        syncFollowDirectories()
        if wasFollowing {
            saveState()
        }
        invalidateCachesForFollowGraphMutation()
        // Explicitly drop the unfollowed user's posts from the local feed
        // arrays.  `mainFeedPosts` already filters them via the follow check,
        // but pruning the underlying arrays guarantees they cannot resurface
        // through any trusted-id or username-match fallback and shrinks the
        // memory footprint.  If the user re-follows later, posts will be
        // re-fetched by the backend sync that runs from follow().
        if wasFollowing {
            let unfollowedID = canonical.id
            let normalizedUnfollowedUsername = normalizeUsername(canonical.username)
            let isAuthoredByUnfollowed: (FeedPost) -> Bool = { [weak self] post in
                if post.user.id == unfollowedID { return true }
                guard let self else { return false }
                return self.normalizeUsername(post.user.username) == normalizedUnfollowedUsername
            }
            posts.removeAll(where: isAuthoredByUnfollowed)
            pendingRemotePosts.removeAll(where: isAuthoredByUnfollowed)
            pendingFeedPostCount = pendingRemotePosts.count
        }
        // Force SwiftUI to re-render the feed immediately so the unfollowed
        // user's posts disappear without waiting on a separate publish from
        // `following`/`followers`.
        objectWillChange.send()
        enqueuePendingFollowSync(
            followerID: currentUser.id,
            followeeID: canonical.id,
            isFollowing: false
        )
        triggerPendingFollowSyncFlush(force: true)
    }

    func toggleFollow(_ profile: UserProfile) {
        guard profile != currentUser else { return }
        guard !isMandatoryFollowAccount(profile) else { return }
        if isFollowing(profile) || hasPendingOutgoingFollowRequest(to: profile) {
            unfollow(profile: profile)
        } else {
            follow(profile: profile)
        }
    }

    func acceptFollowRequest(from profile: UserProfile) {
        resolveFollowRequest(from: profile, accept: true)
    }

    func denyFollowRequest(from profile: UserProfile) {
        resolveFollowRequest(from: profile, accept: false)
    }

    private func resolveFollowRequest(from profile: UserProfile, accept: Bool) {
        guard let canonical = canonicalProfile(matching: profile) else { return }
        guard pendingFollowRequests.contains(where: { $0.id == canonical.id }) else { return }

        let previousRequests = pendingFollowRequests
        let previousRelations = followRelations

        pendingFollowRequests.removeAll { $0.id == canonical.id }
        if accept {
            addFollowRelation(from: canonical.id, to: currentUser.id)
            syncFollowDirectories()
        }
        saveState()

        Task {  [weak self] in
            guard let self else { return }
            do {
                var response: BackendFollowResponse?
                try await self.performAuthenticatedBackendWrite(
                    operationName: accept ? "follow_request_accept" : "follow_request_deny",
                    maxAttempts: 2,
                    timeoutPerAttempt: 20
                ) { authTokenOverride in
                    response = try await self.backendClient.respondToFollowRequest(
                        followerID: canonical.id,
                        followeeID: self.currentUser.id,
                        accept: accept,
                        authTokenOverride: authTokenOverride
                    )
                }
                _ = response
                await self.syncFromBackendIfAvailable(lane: .socialSnapshot, skipIdentityReconcile: true)
                await self.refreshPendingFollowRequestsFromBackend()
            } catch {
                self.pendingFollowRequests = previousRequests
                self.followRelations = previousRelations
                self.syncFollowDirectories()
                self.saveState()
                self.moderationErrorMessage = "Couldn't update follow request. \(self.describeBackendError(error))"
            }
        }
    }

    func hasRecentPost(from profile: UserProfile) -> Bool {
        let cutoff = Date().addingTimeInterval(-86_400)
        return posts.contains { $0.user.id == profile.id && $0.timestamp >= cutoff }
    }

    private func addFollowRelation(from followerID: UUID, to targetID: UUID) {
        var existing = followRelations[followerID] ?? []
        existing.insert(targetID)
        followRelations[followerID] = existing
    }

    private func removeFollowRelation(from followerID: UUID, to targetID: UUID) {
        if mandatoryFollowIDs().contains(targetID) { return }
        var existing = followRelations[followerID] ?? []
        existing.remove(targetID)
        followRelations[followerID] = existing
    }

    /// Optimistically updates a post's caption and location in the local feed,
    /// then syncs the change to the backend. Throws if the backend call fails;
    /// callers are responsible for reverting or surfacing the error.
    @MainActor
    /// Persist a new value for the album-level liner notes on a music post.
    /// Rebuilds the music caption preserving every other field (caption text,
    /// release type, loop video, tracks, release date, label) and writes the
    /// result back via the standard updatePostCaption path.  Pass nil or an
    /// empty string to clear the liner notes.
    func updateMusicLinerNotes(_ post: FeedPost, linerNotes: String?) async throws {
        guard post.isMusic else { return }
        let trimmed = linerNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (trimmed?.isEmpty == true) ? nil : trimmed
        let newCaption = FeedPost.musicCaption(
            from: post.displayCaption,
            loopVideoURL: post.musicLoopVideoURL,
            releaseType: post.musicReleaseType,
            tracks: post.musicTracks,
            releaseDate: post.musicReleaseDate,
            recordLabel: post.musicRecordLabel,
            genre: post.musicGenre,
            linerNotes: resolved,
            musicVideoLinkIDs: post.musicVideoLinkIDs
        )
        try await updatePostCaption(post, caption: newCaption, locationCity: post.locationCity)
        PodcastStickyPlayerCoordinator.shared.invalidateIfCurrent(postID: post.id)
    }

    /// Persist new lyrics for a specific track inside a music post.  Looks
    /// up the track by id, rewrites just that track's `lyrics` field, and
    /// re-encodes the [MUSIC_TRACKS_BASE64] payload.  Other tracks and all
    /// release metadata are preserved.
    func updateMusicTrackLyrics(_ post: FeedPost, trackID: UUID, lyrics: String?) async throws {
        guard post.isMusic else { return }
        let trimmed = lyrics?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = (trimmed?.isEmpty == true) ? nil : trimmed
        var updatedTracks = post.musicTracks
        guard let idx = updatedTracks.firstIndex(where: { $0.id == trackID }) else { return }
        let existing = updatedTracks[idx]
        updatedTracks[idx] = MusicTrackMetadata(
            id: existing.id,
            title: existing.title,
            audioURL: existing.audioURL,
            durationSeconds: existing.durationSeconds,
            lyrics: resolved,
            isExplicit: existing.isExplicit,
            collaboratorCredits: existing.collaboratorCredits
        )
        let newCaption = FeedPost.musicCaption(
            from: post.displayCaption,
            loopVideoURL: post.musicLoopVideoURL,
            releaseType: post.musicReleaseType,
            tracks: updatedTracks,
            releaseDate: post.musicReleaseDate,
            recordLabel: post.musicRecordLabel,
            genre: post.musicGenre,
            linerNotes: post.musicLinerNotes,
            musicVideoLinkIDs: post.musicVideoLinkIDs
        )
        try await updatePostCaption(post, caption: newCaption, locationCity: post.locationCity)
        PodcastStickyPlayerCoordinator.shared.invalidateIfCurrent(postID: post.id)
    }

    /// Persist a new list of linked music-video post IDs on a music post.
    /// Validates each ID maps to a real post and that the post is a
    /// video.  Other release metadata is preserved unchanged.
    @MainActor
    func updateMusicVideoLinks(_ post: FeedPost, linkedPostIDs: [UUID]) async throws {
        guard post.isMusic else { return }
        // Dedupe but preserve user-chosen order.
        var seen = Set<UUID>()
        let ordered = linkedPostIDs.filter { seen.insert($0).inserted }
        let newCaption = FeedPost.musicCaption(
            from: post.displayCaption,
            loopVideoURL: post.musicLoopVideoURL,
            releaseType: post.musicReleaseType,
            tracks: post.musicTracks,
            releaseDate: post.musicReleaseDate,
            recordLabel: post.musicRecordLabel,
            genre: post.musicGenre,
            linerNotes: post.musicLinerNotes,
            musicVideoLinkIDs: ordered
        )
        try await updatePostCaption(post, caption: newCaption, locationCity: post.locationCity)
        PodcastStickyPlayerCoordinator.shared.invalidateIfCurrent(postID: post.id)
    }

    func fetchMusicPlaylists() async throws -> [BackendMusicPlaylist] {
        try await backendClient.fetchMusicPlaylists(ownerID: currentUser.id)
    }

    func fetchMusicPlaylistDetail(playlistID: UUID) async throws -> BackendMusicPlaylistDetail {
        try await backendClient.fetchMusicPlaylistDetail(playlistID: playlistID)
    }

    func createMusicPlaylist(title: String, coverPhoto: PhotoPreview? = nil) async throws -> BackendMusicPlaylist {
        let coverUploadResult: MediaUploadResult?
        if let coverPhoto {
            let preparedCoverURL = try MediaStorage.preparePodcastCoverImage(from: coverPhoto.fileURL)
            defer { try? FileManager.default.removeItem(at: preparedCoverURL) }
            coverUploadResult = try await backendClient.uploadMusicPlaylistCoverImage(
                playlistDraftID: UUID(),
                ownerID: currentUser.id,
                localURL: preparedCoverURL,
                timeoutInterval: 60
            )
        } else {
            coverUploadResult = nil
        }
        return try await backendClient.createMusicPlaylist(
            ownerID: currentUser.id,
            title: title,
            coverUploadResult: coverUploadResult
        )
    }

    @MainActor
    func deleteMusicPlaylist(playlistID: UUID, postID: UUID?) async throws {
        if let postID {
            markPostDeleted(postID)
            notifications.removeAll { $0.objectID == postID }
            pinnedPostIDs = pinnedPostIDs.filter { _, pinnedID in pinnedID != postID }
            adSubmissionPostIDs.remove(postID)
            adSubmissionsByPostID.removeValue(forKey: postID)
            curatedAdSlotIDs = curatedAdSlotIDs.map { $0 == postID ? nil : $0 }
            saveCuratedAdSlots()
            normalizePinnedPosts()
            PodcastStickyPlayerCoordinator.shared.invalidateIfCurrent(postID: postID)
            saveState()
        }
        try await backendClient.deleteMusicPlaylist(ownerID: currentUser.id, playlistID: playlistID)
    }

    @discardableResult
    func addMusicTrackToPlaylist(
        playlistID: UUID,
        sourcePostID: UUID,
        track: MusicTrackMetadata,
        leadArtist: UserProfile
    ) async throws -> BackendMusicPlaylistTrack {
        let leadCredit = MusicTrackArtistCredit(profile: leadArtist)
        let credits = [leadCredit] + track.collaboratorCredits.filter { $0.userID != leadCredit.userID }
        return try await backendClient.addMusicTrackToPlaylist(
            playlistID: playlistID,
            ownerID: currentUser.id,
            sourcePostID: sourcePostID,
            trackID: track.id,
            trackTitle: track.title,
            artistCreditsSnapshot: credits
        )
    }

    func updatePostCaption(_ post: FeedPost, caption: String?, locationCity: String?) async throws {
        guard post.user.id == currentUser.id || currentUser.isFounder else { return }
        guard backendClient.isEnabled else { return }

        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCaption = (trimmedCaption?.isEmpty == true) ? nil : trimmedCaption
        let trimmedCity = locationCity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCity = (trimmedCity?.isEmpty == true) ? nil : trimmedCity

        func applyLocalUpdate(to source: inout [FeedPost]) {
            for idx in source.indices where source[idx].id == post.id {
                source[idx].caption = resolvedCaption
                source[idx].locationCity = resolvedCity
            }
        }

        // Optimistic local update — update every reference to this post in local state.
        applyLocalUpdate(to: &posts)
        applyLocalUpdate(to: &pendingRemotePosts)
        applyLocalUpdate(to: &deliveredAdPosts)

        try await backendClient.updatePostCaption(
            postID: post.id,
            authorID: post.user.id,
            caption: resolvedCaption,
            locationCity: resolvedCity
        )
        saveState()
    }

    @MainActor
    func updatePodcastCoverImage(_ post: FeedPost, coverPhoto: PhotoPreview) async throws {
        guard post.user.id == currentUser.id || currentUser.isFounder else { return }
        guard backendClient.isEnabled else { return }
        guard post.isAudioPost else { return }

        let preparedCoverURL = try MediaStorage.preparePodcastCoverImage(from: coverPhoto.fileURL)
        defer { try? FileManager.default.removeItem(at: preparedCoverURL) }

        let coverResult = try await (post.isMusic
            ? backendClient.uploadMusicCoverImage(
                postID: post.id,
                authorID: post.user.id,
                localURL: preparedCoverURL,
                timeoutInterval: 60
            )
            : backendClient.uploadPodcastCoverImage(
            postID: post.id,
            authorID: post.user.id,
            localURL: preparedCoverURL,
            timeoutInterval: 60
        ))

        guard let coverProvider = coverResult.provider,
              let coverBucket = coverResult.bucket,
              let coverObjectKey = coverResult.objectKey,
              !coverProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !coverBucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !coverObjectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BackendClientError.missingUploadedAssetReference
        }

        do {
            try await backendClient.updatePostCoverImageRef(
                postID: post.id,
                authorID: post.user.id,
                coverProvider: coverProvider,
                coverBucket: coverBucket,
                coverObjectKey: coverObjectKey
            )
        } catch {
            if post.user.id != currentUser.id {
                try await backendClient.updatePostCoverImageRef(
                    postID: post.id,
                    authorID: currentUser.id,
                    coverProvider: coverProvider,
                    coverBucket: coverBucket,
                    coverObjectKey: coverObjectKey
                )
            } else {
                throw error
            }
        }


        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx].coverImageRef = nil
            posts[idx].coverProvider = coverResult.provider
            posts[idx].coverBucket = coverResult.bucket
            posts[idx].coverObjectKey = coverResult.objectKey
        }
        if let pendingIdx = pendingRemotePosts.firstIndex(where: { $0.id == post.id }) {
            pendingRemotePosts[pendingIdx].coverImageRef = nil
            pendingRemotePosts[pendingIdx].coverProvider = coverResult.provider
            pendingRemotePosts[pendingIdx].coverBucket = coverResult.bucket
            pendingRemotePosts[pendingIdx].coverObjectKey = coverResult.objectKey
        }
        saveState()
    }

    @MainActor
    struct MusicPostEditProgress: Sendable {
        let message: String
        let fractionCompleted: Double
        let activeTrackID: UUID?
    }

    @MainActor
    func updateMusicPost(
        _ post: FeedPost,
        caption: String?,
        locationCity: String?,
        coverPhoto: PhotoPreview?,
        loopVideo: VideoPreview?,
        tracks: [MusicTrackEditDraft],
        releaseDate: Date? = nil,
        recordLabel: String? = nil,
        genre: String? = nil,
        linerNotes: String? = nil,
        progress: ((MusicPostEditProgress) -> Void)? = nil
    ) async throws {
        guard post.user.id == currentUser.id || currentUser.isFounder else { return }
        guard backendClient.isEnabled else { return }
        guard post.isMusic else { return }

        let normalizedTracks = tracks
            .map {
                MusicTrackEditDraft(
                    id: $0.id,
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    existingAudioURL: $0.existingAudioURL,
                    replacementLocalURL: $0.replacementLocalURL,
                    replacementFilename: $0.replacementFilename,
                    lyrics: $0.lyrics.trimmingCharacters(in: .whitespacesAndNewlines),
                    isExplicit: $0.isExplicit
                )
            }
            .filter { !$0.title.isEmpty }

        guard !normalizedTracks.isEmpty else {
            throw BackendClientError.requestFailed
        }

        let replacementTrackCount = normalizedTracks.filter { $0.replacementLocalURL != nil }.count
        let totalStepCount = max(1, (coverPhoto == nil ? 0 : 1) + (loopVideo == nil ? 0 : 1) + replacementTrackCount + 1)
        var completedSteps = 0
        let publishProgress: (_ message: String, _ activeTrackID: UUID?) -> Void = { message, activeTrackID in
            progress?(MusicPostEditProgress(
                message: message,
                fractionCompleted: min(max(Double(completedSteps) / Double(totalStepCount), 0), 1),
                activeTrackID: activeTrackID
            ))
        }

        if let coverPhoto {
            publishProgress("Uploading artwork…", nil)
            try await updatePodcastCoverImage(post, coverPhoto: coverPhoto)
            completedSteps += 1
        }

        var resolvedLoopVideoURL = post.musicLoopVideoURL
        if let loopVideo {
            publishProgress("Uploading loop video…", nil)
            resolvedLoopVideoURL = try await uploadAudioLoopVideo(for: post, loopVideo: loopVideo)
            completedSteps += 1
        }

        var primaryTrackAudioURL = normalizedTracks.first?.existingAudioURL
        if let primaryTrack = normalizedTracks.first,
           let primaryReplacementURL = primaryTrack.replacementLocalURL {
            publishProgress("Uploading track 1 of \(normalizedTracks.count)…", primaryTrack.id)
            let uploadResult = try await backendClient.uploadMusicTrack(
                postID: post.id,
                authorID: post.user.id,
                localURL: primaryReplacementURL,
                trackNumber: 1,
                timeoutInterval: 60
            )

            guard let provider = uploadResult.provider,
                  let bucket = uploadResult.bucket,
                  let objectKey = uploadResult.objectKey,
                  !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !objectKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackendClientError.missingUploadedAssetReference
            }

            try await backendClient.updatePostMedia(
                postID: post.id,
                authorID: post.user.id,
                assetProvider: provider,
                assetBucket: bucket,
                assetObjectKey: objectKey,
                aspectRatio: Double(post.mediaPreview.aspectRatio)
            )
            applyUpdatedMediaPreview(
                postID: post.id,
                legacyRef: uploadResult.legacyRef,
                aspectRatio: post.mediaPreview.aspectRatio,
                assetProvider: provider,
                assetBucket: bucket,
                assetObjectKey: objectKey
            )
            let normalizedPrimaryRef = uploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedPrimaryRef.isEmpty, let uploadedPrimaryURL = URL(string: normalizedPrimaryRef) {
                primaryTrackAudioURL = uploadedPrimaryURL
            }
            completedSteps += 1
        }

        // Pre-existing per-track durations from the post we're editing,
        // keyed by track id so we can preserve them when a track wasn't
        // changed (no replacement file) — otherwise the edit would wipe
        // durations captured during the original upload.
        let priorTrackDurationsByID: [UUID: Double] = Dictionary(
            uniqueKeysWithValues: post.musicTracks.compactMap { metadata -> (UUID, Double)? in
                guard let dur = metadata.durationSeconds else { return nil }
                return (metadata.id, dur)
            }
        )

        var updatedTrackMetadata: [MusicTrackMetadata] = []
        for (index, track) in normalizedTracks.enumerated() {
            if index == 0 {
                // Track 1: capture duration from the newly-uploaded primary
                // asset's local file if available, otherwise preserve the
                // previous duration so untouched tracks keep their runtime.
                let track1Duration: Double?
                if let replacement = track.replacementLocalURL {
                    track1Duration = await Self.readAudioDurationSeconds(from: replacement)
                } else {
                    track1Duration = priorTrackDurationsByID[track.id]
                }
                updatedTrackMetadata.append(
                    MusicTrackMetadata(
                        id: track.id,
                        title: track.title,
                        audioURL: primaryTrackAudioURL,
                        durationSeconds: track1Duration,
                        lyrics: track.lyrics.isEmpty ? nil : track.lyrics,
                        isExplicit: track.isExplicit,
                        collaboratorCredits: track.collaboratorCredits
                    )
                )
                continue
            }

            var resolvedAudioURL = track.existingAudioURL
            var resolvedDuration: Double? = priorTrackDurationsByID[track.id]
            if let replacementLocalURL = track.replacementLocalURL {
                publishProgress("Uploading track \(index + 1) of \(normalizedTracks.count)…", track.id)
                // Read duration from the local file BEFORE the upload (the
                // local URL stays valid for the read; afterward it may be
                // cleaned up by the system).
                resolvedDuration = await Self.readAudioDurationSeconds(from: replacementLocalURL)
                let uploadResult = try await backendClient.uploadMusicTrack(
                    postID: post.id,
                    authorID: post.user.id,
                    localURL: replacementLocalURL,
                    trackNumber: index + 1,
                    timeoutInterval: 60
                )
                let normalizedTrackRef = uploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedTrackRef.isEmpty, let uploadedTrackURL = URL(string: normalizedTrackRef) else {
                    throw BackendClientError.missingUploadedAssetReference
                }
                resolvedAudioURL = uploadedTrackURL
                completedSteps += 1
            }

            updatedTrackMetadata.append(
                MusicTrackMetadata(
                    id: track.id,
                    title: track.title,
                    audioURL: resolvedAudioURL,
                    durationSeconds: resolvedDuration,
                    lyrics: track.lyrics.isEmpty ? nil : track.lyrics,
                    isExplicit: track.isExplicit,
                    collaboratorCredits: track.collaboratorCredits
                )
            )
        }

        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Preserve any release metadata that was previously set if the caller
        // didn't pass new values.  Callers that DO want to clear a field
        // (e.g. user wiped the record label in the edit sheet) should pass
        // an explicit empty string for that field — we trim+nil-out on the
        // builder side so empty strings vanish from the caption.
        let resolvedReleaseDate = releaseDate ?? post.musicReleaseDate
        let resolvedRecordLabel = recordLabel ?? post.musicRecordLabel
        let resolvedGenre = genre ?? post.musicGenre
        let resolvedLinerNotes = linerNotes ?? post.musicLinerNotes
        let finalCaption = FeedPost.musicCaption(
            from: trimmedCaption,
            loopVideoURL: resolvedLoopVideoURL,
            releaseType: post.musicReleaseType,
            tracks: updatedTrackMetadata,
            releaseDate: resolvedReleaseDate,
            recordLabel: resolvedRecordLabel,
            genre: resolvedGenre,
            linerNotes: resolvedLinerNotes,
            // Music-video links are managed through their own dedicated
            // helper (updateMusicVideoLinks) so they're not in the edit
            // sheet's parameter list.  Preserve them across other edits.
            musicVideoLinkIDs: post.musicVideoLinkIDs
        )
        publishProgress("Saving release metadata…", nil)
        try await updatePostCaption(
            post,
            caption: finalCaption,
            locationCity: locationCity
        )
        PodcastStickyPlayerCoordinator.shared.invalidateIfCurrent(postID: post.id)
        completedSteps += 1
        progress?(MusicPostEditProgress(
            message: "Saved",
            fractionCompleted: 1,
            activeTrackID: nil
        ))
    }

    @MainActor
    func uploadAudioLoopVideo(for post: FeedPost, loopVideo: VideoPreview) async throws -> URL {
        guard post.user.id == currentUser.id || currentUser.isFounder else {
            throw BackendClientError.requestFailed
        }
        guard backendClient.isEnabled, post.isAudioPost else {
            throw BackendClientError.requestFailed
        }

        let uploadResult: MediaUploadResult
        if post.isMusic {
            uploadResult = try await backendClient.uploadMusicLoopVideo(
                postID: post.id,
                authorID: post.user.id,
                localURL: loopVideo.url,
                timeoutInterval: 60
            )
        } else {
            uploadResult = try await backendClient.uploadPodcastLoopVideo(
                postID: post.id,
                authorID: post.user.id,
                localURL: loopVideo.url,
                timeoutInterval: 60
            )
        }

        let normalizedLoopRef = uploadResult.legacyRef.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLoopRef.isEmpty, let parsed = URL(string: normalizedLoopRef) else {
            throw BackendClientError.missingUploadedAssetReference
        }
        return parsed
    }




    func deletePost(_ post: FeedPost) {
        guard post.user.id == currentUser.id || currentUser.isFounder else { return }
        if let playlist = post.musicPlaylistPayload {
            Task { [weak self] in
                do {
                    try await self?.deleteMusicPlaylist(playlistID: playlist.playlistID, postID: post.id)
                } catch {
                    print("Failed to delete music playlist \(playlist.playlistID): \(error.localizedDescription)")
                }
            }
            return
        }
        if post.rescrollOrigin != nil {
            markPostDeleted(post.id)
            notifications.removeAll { $0.objectID == post.id }
            pinnedPostIDs = pinnedPostIDs.filter { _, pinnedID in pinnedID != post.id }
            adSubmissionPostIDs.remove(post.id)
            adSubmissionsByPostID.removeValue(forKey: post.id)
            curatedAdSlotIDs = curatedAdSlotIDs.map { $0 == post.id ? nil : $0 }
            saveCuratedAdSlots()
            normalizePinnedPosts()
            saveState()
            enqueuePendingDeletion(kind: .rescroll, postID: post.id, authorID: post.user.id)
            Task {  [weak self] in
                await self?.flushPendingDeletions()
            }
            return
        }

        let originalPostID = post.id
        let originalAuthorID = post.user.id
        let relatedRescrolls = posts.filter { $0.rescrollOrigin?.postID == originalPostID }
        let removedPostIDs = Set([originalPostID] + relatedRescrolls.map(\.id))

        markPostDeleted(originalPostID)
        notifications.removeAll { notification in
            if let objectID = notification.objectID, removedPostIDs.contains(objectID) {
                return true
            }
            return false
        }
        pinnedPostIDs = pinnedPostIDs.filter { _, pinnedID in !removedPostIDs.contains(pinnedID) }
        adSubmissionPostIDs = adSubmissionPostIDs.subtracting(removedPostIDs)
        for removedID in removedPostIDs {
            adSubmissionsByPostID.removeValue(forKey: removedID)
        }
        deliveredAdPosts.removeAll { removedPostIDs.contains($0.id) }
        curatedAdSlotIDs = curatedAdSlotIDs.map { id in
            guard let id else { return nil }
            return removedPostIDs.contains(id) ? nil : id
        }
        saveCuratedAdSlots()
        normalizePinnedPosts()
        saveState()
        for rescroll in relatedRescrolls {
            // Rescrolls carry no media of their own; pass nil for post.
            enqueuePendingDeletion(kind: .rescroll, postID: rescroll.id, authorID: rescroll.user.id)
        }
        // Pass the full post so media/cover object keys are forwarded to the
        // backend for R2/Cloudflare asset cleanup.
        enqueuePendingDeletion(kind: .post, postID: originalPostID, authorID: originalAuthorID, post: post)
        Task {  [weak self] in
            await self?.flushPendingDeletions()
        }
    }

    func deleteCurrentUserAccount() async throws {
        guard backendClient.isEnabled else {
            throw BackendClientError.invalidBaseURL
        }

        let deletedProfile = currentUser
        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: deletedProfile.username,
            expectedUserID: deletedProfile.id,
            using: backendClient,
            preferRefresh: true
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()

        try await backendClient.deleteCurrentUserAccount()

        applyFounderAccountDeletionLocally(deletedProfile)
        backendClient.setAuthSession(
            token: nil,
            refreshToken: nil,
            source: "deleteCurrentUserAccount"
        )
        LocalAuthStore.markExplicitLogout()
        UserDefaults.standard.set(false, forKey: "scrolls.auth.isAuthenticated")
        UserDefaults.standard.set("", forKey: "scrolls.auth.activeUsername")
        UserDefaults.standard.set(false, forKey: "scrolls.auth.needsFollowOnboarding")
        moderationErrorMessage = nil
    }

    func deleteAccount(_ profile: UserProfile) {
        guard canFounderDeleteAccount(profile) else { return }
        guard backendClient.isEnabled else {
            moderationErrorMessage = "Backend account deletion is unavailable. Please reconnect and try again."
            return
        }

        let targetID = profile.id
        Task {  [weak self] in
            guard let self else { return }
            _ = await BackendTruthSyncCore.ensureActiveSession(
                for: self.currentUser.username,
                expectedUserID: self.currentUser.id,
                using: self.backendClient,
                preferRefresh: true
            )
            await MainActor.run {
                self.restoreBackendAuthTokenForCurrentUserIfNeeded()
            }
            do {
                try await self.backendClient.deleteUserAsFounder(targetUserID: targetID)
                await MainActor.run {
                    self.applyFounderAccountDeletionLocally(profile)
                    self.moderationErrorMessage = nil
                }
                await self.syncFromBackendIfAvailable(lane: .manualRefresh, skipIdentityReconcile: true)
            } catch {
                await MainActor.run {
                    self.moderationErrorMessage = "Couldn't delete this account globally. \(self.describeBackendError(error))"
                }
            }
        }
    }

    private func applyFounderAccountDeletionLocally(_ profile: UserProfile) {
        let targetID = profile.id
        let removedPostIDs = Set(posts.filter {
            $0.user.id == targetID || $0.rescrollOrigin?.user.id == targetID
        }.map(\.id))

        posts.removeAll {
            $0.user.id == targetID ||
            $0.rescrollOrigin?.user.id == targetID
        }
        pendingRemotePosts.removeAll {
            $0.user.id == targetID ||
            $0.rescrollOrigin?.user.id == targetID
        }
        pendingFeedPostCount = pendingRemotePosts.count
        notifications.removeAll {
            $0.actorID == targetID || $0.objectID == targetID || ($0.objectID.map { removedPostIDs.contains($0) } ?? false)
        }
        pinnedPostIDs = pinnedPostIDs.filter { ownerID, pinnedID in
            ownerID != targetID && !removedPostIDs.contains(pinnedID)
        }
        adSubmissionPostIDs = adSubmissionPostIDs.subtracting(removedPostIDs)
        for postID in removedPostIDs {
            adSubmissionsByPostID.removeValue(forKey: postID)
        }
        deliveredAdPosts.removeAll { removedPostIDs.contains($0.id) }
        postDrafts.removeAll { $0.ownerUserID == targetID }
        pendingDeletionQueue.removeAll { request in
            request.authorID == targetID || removedPostIDs.contains(request.postID)
        }
        pendingFollowSyncQueue.removeAll { operation in
            operation.followerID == targetID || operation.followeeID == targetID
        }
        pendingBackendWriteQueue.removeAll { operation in
            operation.userID == targetID
                || operation.authorID == targetID
                || (operation.postID.map { removedPostIDs.contains($0) } ?? false)
                || (operation.originalPostID.map { removedPostIDs.contains($0) } ?? false)
                || (operation.rescrollPostID.map { removedPostIDs.contains($0) } ?? false)
        }
        pendingFollowRequests.removeAll { $0.id == targetID }
        pendingOutgoingFollowRequestIDs.remove(targetID)
        savePendingDeletionQueue()
        savePendingFollowSyncQueue()
        savePendingBackendWriteQueue()

        followRelations.removeValue(forKey: targetID)
        for key in followRelations.keys {
            followRelations[key]?.remove(targetID)
        }

        circles = circles.compactMap { circle in
            var updated = circle
            updated.members.removeAll(where: { $0.profileID == targetID })
            updated.messages.removeAll(where: { $0.userID == targetID })
            if updated.members.isEmpty {
                return nil
            }
            return updated
        }
        unreadCircleMessageIDs = Set(
            unreadCircleMessageIDs.filter { messageID in
                !circles.flatMap(\.messages).contains(where: { $0.id == messageID && $0.userID == targetID })
            }
        )

        profileRegistry.removeValue(forKey: targetID)
        signatureImageCache.removeValue(forKey: targetID)
        purgeDeletedAccountFromLocalPersistence(targetID: targetID, username: profile.username, removedPostIDs: removedPostIDs)
        LocalAuthStore.deleteAccount(username: profile.username)
        clearAllCaches()
        syncFollowDirectories()
        saveState()
    }

    private func purgeDeletedAccountFromLocalPersistence(targetID: UUID, username: String, removedPostIDs: Set<UUID>) {
        UserDefaults.standard.removeObject(forKey: Self.profileSnapshotKey(for: username))
        // Also remove Keychain snapshot so a deleted account leaves no residual data.
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !account.isEmpty {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.profileSnapshotKeychainService,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }
        UserDefaults.standard.removeObject(forKey: Self.profileSignatureKeyPrefix + targetID.uuidString.lowercased())
        UserDefaults.standard.removeObject(forKey: Self.profileSignatureImageKeyPrefix + targetID.uuidString.lowercased())

        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = documentDir.appendingPathComponent("Scrolls", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        for file in files {
            let name = file.lastPathComponent.lowercased()
            guard name == "scrolls-state.json" || (name.hasPrefix("scrolls-state-") && name.hasSuffix(".json")) else { continue }
            guard let data = Persistence.loadData(from: file),
                  let persisted = try? JSONDecoder().decode(ScrollsState.self, from: data) else { continue }
            if persisted.currentUser.id == targetID {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            let updatedPosts = persisted.posts.filter {
                $0.user.id != targetID && $0.rescrollOrigin?.user.id != targetID
            }
            let updatedNotifications = persisted.notifications.filter { notification in
                if notification.actorID == targetID || notification.objectID == targetID {
                    return false
                }
                if let objectID = notification.objectID, removedPostIDs.contains(objectID) {
                    return false
                }
                return true
            }
            let updatedFollowing = persisted.following.filter { $0.id != targetID }
            let updatedFollowers = persisted.followers.filter { $0.id != targetID }
            let updatedFollowRelations = persisted.followRelations.reduce(into: [UUID: [UUID]]()) { partial, entry in
                guard entry.key != targetID else { return }
                partial[entry.key] = entry.value.filter { $0 != targetID }
            }
            let updatedPinned = persisted.pinnedPostIDs.filter { ownerID, postID in
                ownerID != targetID && !removedPostIDs.contains(postID)
            }
            let updatedCircles: [CircleGroup] = persisted.circles.compactMap { circle -> CircleGroup? in
                var updated = circle
                updated.members.removeAll(where: { $0.profileID == targetID })
                updated.messages.removeAll(where: { $0.userID == targetID })
                if updated.members.isEmpty {
                    return nil
                }
                return updated
            }
            let validMessageIDs = Set(updatedCircles.flatMap { $0.messages }.map { $0.id })
            let updatedUnreadIDs = persisted.unreadCircleMessageIDs.filter { validMessageIDs.contains($0) }
            let updatedDrafts = persisted.postDrafts.filter { $0.ownerUserID != targetID }
            let updatedAdSubmissionPostIDs = persisted.adSubmissionPostIDs.filter { !removedPostIDs.contains($0) }

            let updatedState = ScrollsState(
                posts: updatedPosts,
                following: updatedFollowing,
                currentUser: persisted.currentUser,
                notifications: updatedNotifications,
                unreadCircleMessageIDs: updatedUnreadIDs,
                circles: updatedCircles,
                followers: updatedFollowers,
                followRelations: updatedFollowRelations,
                pinnedPostIDs: updatedPinned,
                postDrafts: updatedDrafts,
                adSubmissionPostIDs: updatedAdSubmissionPostIDs
            )
            guard let updatedData = try? JSONEncoder().encode(updatedState) else { continue }
            try? updatedData.write(to: file, options: Data.WritingOptions.atomic)
        }
    }

    func canPinToProfile(_ post: FeedPost) -> Bool {
        post.user.id == currentUser.id && post.rescrollOrigin == nil
    }

    func isPinned(_ post: FeedPost) -> Bool {
        pinnedPostIDs[post.user.id] == post.id || post.user.pinnedPostID == post.id
    }

    func pinStatusLabel(for post: FeedPost) -> String {
        isPinned(post) ? "Unpin Scroll from profile" : "Pin Scroll to profile"
    }

    func togglePin(post: FeedPost) {
        guard canPinToProfile(post) else { return }
        let previousPinnedID = pinnedPostIDs[post.user.id] ?? currentUser.pinnedPostID
        let nextPinnedID: UUID?
        if isPinned(post) {
            pinnedPostIDs.removeValue(forKey: post.user.id)
            nextPinnedID = nil
        } else {
            pinnedPostIDs[post.user.id] = post.id
            nextPinnedID = post.id
        }
        let updatedCurrent = currentUser.with(pinnedPostID: nextPinnedID)
        currentUser = updatedCurrent
        registerProfile(updatedCurrent)
        // IMMEDIATE save.  The debounced `saveState()` waits ~500ms before
        // actually writing the snapshot, during which it can be cancelled
        // by any subsequent `saveState()` call (which fires very often —
        // every realtime sync event, every state mutation).  If the user
        // pins then quickly backgrounds the app, the pending save task is
        // killed before it writes and the pin is lost on next launch.
        // Pin toggles are rare and small — no reason to debounce them.
        saveState(immediate: true)
        // Persist the pin into the user's session record too, so a state-
        // snapshot file corruption doesn't lose it (cold-launch restore
        // falls back to scanning session records when the main snapshot
        // is unreadable).  Best-effort — no-op if the record doesn't
        // exist for this user.
        persistPinnedPostIDSnapshot()
        Task { [weak self] in
            guard let self else { return }
            do {
                let remote = try await backendClient.updatePinnedPost(userID: post.user.id, postID: nextPinnedID)
                await MainActor.run {
                    self.mergeRemoteCurrentUser(remote)
                    if let remotePinnedID = remote.pinnedPostID {
                        self.pinnedPostIDs[remote.id] = remotePinnedID
                    } else {
                        self.pinnedPostIDs.removeValue(forKey: remote.id)
                    }
                    self.persistPinnedPostIDSnapshot()
                }
            } catch {
                await MainActor.run {
                    if let previousPinnedID {
                        self.pinnedPostIDs[post.user.id] = previousPinnedID
                    } else {
                        self.pinnedPostIDs.removeValue(forKey: post.user.id)
                    }
                    let restored = self.currentUser.with(pinnedPostID: previousPinnedID)
                    self.currentUser = restored
                    self.registerProfile(restored)
                    self.persistPinnedPostIDSnapshot()
                    self.saveState(immediate: true)
                }
            }
        }
    }

    private func syncCurrentUserPinnedPostToBackendIfNeeded() async {
        guard backendClient.isEnabled else { return }
        guard let localPinnedID = await MainActor.run(resultType: UUID?.self, body: { pinnedPostIDs[currentUser.id] }) else { return }
        let alreadySynced = await MainActor.run(resultType: Bool.self, body: { currentUser.pinnedPostID == localPinnedID })
        guard !alreadySynced else { return }
        do {
            let remote = try await backendClient.updatePinnedPost(userID: currentUser.id, postID: localPinnedID)
            await MainActor.run {
                self.mergeRemoteCurrentUser(remote)
                if let remotePinnedID = remote.pinnedPostID {
                    self.pinnedPostIDs[remote.id] = remotePinnedID
                }
                self.persistPinnedPostIDSnapshot()
                self.saveState(immediate: true)
            }
        } catch {
            // Best-effort migration for pins saved before backend pinning existed.
            // The next startup/foreground sync will try again.
        }
    }

    /// Writes the current `pinnedPostIDs` dictionary to a dedicated
    /// sidecar file so pins survive even if the main state snapshot is
    /// corrupted, partially written, or reset by an account-switch or
    /// repair flow.  Tiny payload (UUID-to-UUID map), no I/O cost worth
    /// debouncing.  See `loadPinnedPostIDSnapshot` for the restore path.
    private func persistPinnedPostIDSnapshot() {
        let url = pinnedPostIDsSnapshotURL
        guard !pinnedPostIDs.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        // Encode as [String: String] (UUID stringified) so it's robust
        // to any future model refactors.
        let payload = pinnedPostIDs.reduce(into: [String: String]()) { result, entry in
            result[entry.key.uuidString] = entry.value.uuidString
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        Task.detached(priority: .background) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Reads the pinned-post sidecar.  Used during cold-launch restore as
    /// a fallback when the main snapshot's `pinnedPostIDs` is empty.
    private func loadPinnedPostIDSnapshot() -> [UUID: UUID] {
        let url = pinnedPostIDsSnapshotURL
        guard let data = Persistence.loadData(from: url) else { return [:] }
        guard let payload = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        var result: [UUID: UUID] = [:]
        for (rawKey, rawValue) in payload {
            guard let userID = UUID(uuidString: rawKey),
                  let postID = UUID(uuidString: rawValue) else { continue }
            result[userID] = postID
        }
        return result
    }

    private var pinnedPostIDsSnapshotURL: URL {
        persistenceDirectory.appendingPathComponent("scrolls-pinned-posts.json")
    }

    func orderedProfilePosts(_ posts: [FeedPost], for profile: UserProfile) -> [FeedPost] {
        guard let pinnedPostID = pinnedPostIDs[profile.id] ?? profile.pinnedPostID,
              let pinnedIndex = posts.firstIndex(where: { $0.id == pinnedPostID }) else {
            return posts
        }
        var ordered = posts
        let pinnedPost = ordered.remove(at: pinnedIndex)
        ordered.insert(pinnedPost, at: 0)
        return ordered
    }

    func sharePost(_ post: FeedPost, to circle: CircleGroup) {
        // Use a zero-width-space sentinel as the message body instead of the
        // legacy generated "Shared Scroll from @user: <caption>" text.  The
        // legacy body exposed raw caption metadata (e.g. `[MUSIC]
        // [MUSIC_RELEASE_TYPE] singlesEPs [MUSIC_TRACKS_BASE64]W3sid…`) which
        // is meant for client parsing, not human reading, and produced an
        // ugly leading bubble in the chat.  With a sentinel body, the chat
        // renderer (CirclesViews.swift) hides the text bubble entirely and
        // shows only the SharedScrollPreview card — cover, title, author tag.
        // The sentinel keeps the underlying messaging layer happy (which
        // requires non-empty text) without surfacing any visible string.
        sendMessage(
            text: SharedScrollMessageText.shareOnlySentinel,
            in: circle,
            sharedPostID: post.id
        )
    }

    private func refreshCurrentUserPosts() {
        posts = posts.map { post in
            guard post.user.id == currentUser.id else { return post }
            return FeedPost(
                id: post.id,
                user: currentUser,
                caption: post.caption,
                websiteURL: post.websiteURL,
                locationCity: post.locationCity,
                timestamp: post.timestamp,
                mediaPreview: post.mediaPreview,
                comments: post.comments,
                rescrollOrigin: post.rescrollOrigin
            )
        }
        saveState()
    }

    private func restoreUnreadCircleMessageIDs(from circles: [CircleGroup], persistedIDs: [UUID]) -> Set<UUID> {
        let messageLookup = Dictionary(uniqueKeysWithValues: circles.flatMap { $0.messages }.map { ($0.id, $0) })
        return Set(persistedIDs.compactMap { messageLookup[$0] }.filter { $0.userID != currentUser.id }.map { $0.id })
    }

    private func defaultUnreadCircleMessageIDs(from circles: [CircleGroup]) -> Set<UUID> {
        let cutoff = Date().addingTimeInterval(-3600)
        return Set(
            circles
                .flatMap { $0.messages }
                .filter { $0.userID != currentUser.id && $0.timestamp >= cutoff }
                .map { $0.id }
        )
    }

    private func appendReply(_ reply: PostComment, to targetID: UUID, in comments: inout [PostComment]) -> Bool {
        for index in comments.indices {
            if comments[index].id == targetID {
                comments[index].replies.append(reply)
                return true
            }
            if appendReply(reply, to: targetID, in: &comments[index].replies) {
                return true
            }
        }
        return false
    }

    private func removeComment(withID id: UUID, from comments: inout [PostComment]) -> Bool {
        if let index = comments.firstIndex(where: { $0.id == id }) {
            comments.remove(at: index)
            return true
        }
        for index in comments.indices {
            if removeComment(withID: id, from: &comments[index].replies) {
                return true
            }
        }
        return false
    }

    private static func photoPreview(from image: PlatformImage, assetIdentifier: String? = nil) -> MediaPreview? {
        MediaStorage.photoPreview(from: image, assetIdentifier: assetIdentifier)
    }

    private static func videoAspectRatio(for url: URL) async throws -> CGFloat {
        try await MediaStorage.videoAspectRatio(for: url)
    }

    /// Reads the duration in seconds from an audio file at the given local URL.
    /// Used by the music-post publish flow to capture per-track runtime so the
    /// release-metadata footer can show "12 songs, 39 minutes".  Returns nil
    /// for:
    ///   • a nil URL (placeholder track slots with no audio attached yet)
    ///   • a file that can't be opened or whose duration is indeterminate
    ///     (CMTime.invalid, e.g. a corrupted asset)
    /// Always async + non-throwing — a duration probe is never important
    /// enough to fail the whole upload.  We just store nil and the footer's
    /// formatter falls back to "N songs" without runtime.
    static func readAudioDurationSeconds(from localURL: URL?) async -> Double? {
        guard let localURL else { return nil }
        let asset = AVURLAsset(url: localURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            // CMTimeGetSeconds returns NaN for invalid durations and a
            // negative number is also nonsensical for audio.
            guard seconds.isFinite, seconds > 0 else { return nil }
            return seconds
        } catch {
            return nil
        }
    }

    private static func createCurrentUser() -> UserProfile {
        let username = normalizedActiveUsername()
        let displayName = username.replacingOccurrences(of: ".", with: " ").capitalized
        let accountRecord = LocalAuthStore.account(forUsername: username)
        let sessionRecord = LocalAuthStore.sessionRecord(forUsername: username)
        let profileID = canonicalProfileID(forNormalizedUsername: username)
            ?? accountRecord?.id
            ?? sessionRecord?.id
            ?? UUID(uuidString: "90F021EE-84F9-4A2A-83F6-2A6489D3FC38")!
        let snapshot = loadProfileSnapshot(username: username)
        if shouldPreferServerProfileSeed() {
            let founder = accountRecord?.isFounder ?? sessionRecord?.isFounder ?? false
            return UserProfile(
                id: profileID,
                username: username,
                displayName: snapshot?.displayName ?? (displayName.isEmpty ? "You" : displayName),
                bio: snapshot?.bio ?? "",
                keywords: snapshot?.keywords ?? [],
                gradientSpec: snapshot?.gradientSpec ?? gradientSpec(for: [.systemPink, .systemPurple]),
                avatarImageData: snapshot?.avatarImageData,
                avatarRef: snapshot?.avatarRef,
                avatarProvider: snapshot?.avatarProvider,
                avatarBucket: snapshot?.avatarBucket,
                avatarObjectKey: snapshot?.avatarObjectKey,
                isVerified: founder || (accountRecord?.isSubscriber ?? sessionRecord?.isSubscriber ?? false),
                isFounder: founder,
                accountType: snapshot?.accountType ?? (accountRecord?.accountType ?? sessionRecord?.accountType ?? .personal),
                signatureRef: snapshot?.signatureRef,
                avatarVideoRef: snapshot?.avatarVideoRef,
                websiteURL: snapshot?.websiteURL,
                venmoURL: snapshot?.venmoURL ?? accountRecord?.venmoURL ?? sessionRecord?.venmoURL,
                cashAppURL: snapshot?.cashAppURL ?? accountRecord?.cashAppURL ?? sessionRecord?.cashAppURL,
                spotifyURL: snapshot?.spotifyURL,
                appleMusicURL: snapshot?.appleMusicURL,
                businessLocation: snapshot?.businessLocation,
                businessPhone: snapshot?.businessPhone,
                homeCity: snapshot?.homeCity ?? accountRecord?.homeCity ?? sessionRecord?.homeCity,
                dateOfBirth: snapshot?.dateOfBirth ?? accountRecord?.dateOfBirth ?? sessionRecord?.dateOfBirth,
                ageAssuranceCompletedAt: snapshot?.ageAssuranceCompletedAt ?? accountRecord?.ageAssuranceCompletedAt ?? sessionRecord?.ageAssuranceCompletedAt,
                parentalControls: snapshot?.parentalControls ?? accountRecord?.parentalControls ?? sessionRecord?.parentalControls ?? .none
            )
        }
        if let snapshot {
            let founder = accountRecord?.isFounder ?? sessionRecord?.isFounder ?? snapshot.isFounder
            return UserProfile(
                id: profileID,
                username: username,
                displayName: snapshot.displayName,
                bio: snapshot.bio,
                keywords: snapshot.keywords,
                gradientSpec: snapshot.gradientSpec,
                avatarImageData: snapshot.avatarImageData,
                avatarRef: snapshot.avatarRef,
                avatarProvider: snapshot.avatarProvider,
                avatarBucket: snapshot.avatarBucket,
                avatarObjectKey: snapshot.avatarObjectKey,
                isVerified: founder || (accountRecord?.isSubscriber ?? sessionRecord?.isSubscriber ?? snapshot.isVerified),
                isFounder: founder,
                accountType: snapshot.accountType,
                signatureRef: snapshot.signatureRef,
                avatarVideoRef: snapshot.avatarVideoRef,
                websiteURL: snapshot.websiteURL,
                venmoURL: snapshot.venmoURL,
                cashAppURL: snapshot.cashAppURL,
                spotifyURL: snapshot.spotifyURL,
                appleMusicURL: snapshot.appleMusicURL,
                businessLocation: snapshot.businessLocation,
                businessPhone: snapshot.businessPhone,
                homeCity: snapshot.homeCity,
                dateOfBirth: snapshot.dateOfBirth,
                ageAssuranceCompletedAt: snapshot.ageAssuranceCompletedAt,
                parentalControls: snapshot.parentalControls
            )
        }
        let founder = accountRecord?.isFounder ?? sessionRecord?.isFounder ?? false
        return UserProfile(
            id: profileID,
            username: username,
            displayName: displayName.isEmpty ? "You" : displayName,
            bio: "",
            keywords: [],
            gradientSpec: gradientSpec(for: [.systemPink, .systemPurple]),
            avatarImageData: nil,
            avatarRef: nil,
            avatarProvider: nil,
            avatarBucket: nil,
            avatarObjectKey: nil,
            isVerified: founder || (accountRecord?.isSubscriber ?? sessionRecord?.isSubscriber ?? false),
            isFounder: founder,
            accountType: accountRecord?.accountType ?? sessionRecord?.accountType ?? .personal,
            signatureRef: nil,
            avatarVideoRef: nil,
            websiteURL: accountRecord?.websiteURL ?? sessionRecord?.websiteURL,
            venmoURL: accountRecord?.venmoURL ?? sessionRecord?.venmoURL,
            cashAppURL: accountRecord?.cashAppURL ?? sessionRecord?.cashAppURL,
            spotifyURL: nil,
            appleMusicURL: nil,
            businessLocation: accountRecord?.businessLocation ?? sessionRecord?.businessLocation,
            businessPhone: accountRecord?.businessPhone ?? sessionRecord?.businessPhone,
            homeCity: accountRecord?.homeCity ?? sessionRecord?.homeCity,
            dateOfBirth: accountRecord?.dateOfBirth ?? sessionRecord?.dateOfBirth,
            ageAssuranceCompletedAt: accountRecord?.ageAssuranceCompletedAt ?? sessionRecord?.ageAssuranceCompletedAt,
            parentalControls: accountRecord?.parentalControls ?? sessionRecord?.parentalControls ?? .none
        )
    }

    private static func normalizedActiveUsername() -> String {
        let saved = UserDefaults.standard.string(forKey: "scrolls.auth.activeUsername") ?? ""
        let cleaned = saved.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleaned.isEmpty { return cleaned }
        if let recovered = LocalAuthStore.recoverableLastSessionUsername()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !recovered.isEmpty {
            return recovered
        }
        return "you"
    }

    private static func shouldPreferServerProfileSeed() -> Bool {
        let defaults = UserDefaults.standard
        let supabaseURL = (defaults.string(forKey: "scrolls.supabase.url") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !supabaseURL.isEmpty { return true }
        let backendURL = (defaults.string(forKey: "scrolls.backend.baseURL") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !backendURL.isEmpty
    }

    private static func canonicalProfileID(forNormalizedUsername username: String) -> UUID? {
        if let founder = founderCanonicalAccounts.first(where: {
            $0.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == username
        }) {
            return founder.id
        }
        if let managed = founderManagedBusinessAccounts.first(where: {
            $0.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == username
        }) {
            return managed.id
        }
        return nil
    }

    private static func profileSnapshotKey(for username: String) -> String {
        "\(profileSnapshotKeyPrefix)\(username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func saveProfileSnapshot(_ profile: UserProfile) {
        let snapshot = UserProfile(
            id: profile.id,
            username: profile.username,
            displayName: profile.displayName,
            bio: profile.bio,
            keywords: profile.keywords,
            gradientSpec: profile.gradientSpec,
            avatarImageData: profile.avatarImageData,
            avatarRef: profile.avatarRef,
            avatarProvider: profile.avatarProvider,
            avatarBucket: profile.avatarBucket,
            avatarObjectKey: profile.avatarObjectKey,
            isVerified: profile.isVerified,
            isFounder: profile.isFounder,
            isPrivateAccount: profile.isPrivateAccount,
            accountType: profile.accountType,
            subscriptionPlan: profile.subscriptionPlan,
            signatureRef: profile.signatureRef,
            avatarVideoRef: profile.avatarVideoRef,
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
            parentalControls: profile.parentalControls
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        // Write to UserDefaults for fast reads during the session.
        setUserDefaultsDataSafely(data, forKey: profileSnapshotKey(for: profile.username))
        // Also write to Keychain so display name, bio, and avatar video
        // reference survive an app delete + reinstall (Keychain outlives the app).
        saveProfileSnapshotToKeychain(data, username: profile.username)
    }

    private static func saveProfileSnapshotToKeychain(_ data: Data, username: String) {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !account.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: profileSnapshotKeychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var create = query
        create[kSecValueData as String] = data
        create[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(create as CFDictionary, nil)
    }

    private static func loadProfileSnapshotFromKeychain(username: String) -> UserProfile? {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !account.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: profileSnapshotKeychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return nil }
        return profile
    }

    private static func loadProfileSnapshot(username: String) -> UserProfile? {
        // Try UserDefaults first (fast path, populated during normal sessions).
        if let data = UserDefaults.standard.data(forKey: profileSnapshotKey(for: username)),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        // Fall back to Keychain — survives app deletion so display name, bio,
        // and avatar video ref are restored on a fresh reinstall.
        if let profile = loadProfileSnapshotFromKeychain(username: username) {
            // Re-seed UserDefaults from Keychain so subsequent reads are fast.
            if let data = try? JSONEncoder().encode(profile) {
                setUserDefaultsDataSafely(data, forKey: profileSnapshotKey(for: username))
            }
            return profile
        }
        return nil
    }

    private func registerProfileSnapshotsForLocalSessions() {
        let sessions = LocalAuthStore.sessionRecords()
        guard !sessions.isEmpty else { return }
        for session in sessions {
            guard let snapshot = Self.loadProfileSnapshot(username: session.username) else { continue }
            let normalizedUsername = normalizeUsername(session.username)
            let canonicalID = Self.canonicalProfileID(forNormalizedUsername: normalizedUsername) ?? session.id
            // Prefer snapshot values when present; fall back to in-memory registry only if snapshot is empty.
            let existingRegistry = profileRegistry[canonicalID]
            let resolvedAvatarData: Data?
            if let snapshotAvatar = snapshot.avatarImageData {
                resolvedAvatarData = snapshotAvatar
            } else if let registryAvatar = existingRegistry?.avatarImageData {
                resolvedAvatarData = registryAvatar
            } else {
                resolvedAvatarData = nil
            }
            let resolvedBio: String
            let snapshotBio = snapshot.bio.trimmingCharacters(in: .whitespacesAndNewlines)
            if !snapshotBio.isEmpty {
                resolvedBio = snapshot.bio
            } else if let registryBio = existingRegistry?.bio,
                      !registryBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resolvedBio = registryBio
            } else {
                resolvedBio = snapshot.bio
            }
            let resolvedAvatarVideoRef: String?
            let snapshotAvatarVideoRef = snapshot.avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !snapshotAvatarVideoRef.isEmpty {
                resolvedAvatarVideoRef = snapshotAvatarVideoRef
            } else if let registryAvatarVideoRef = existingRegistry?.avatarVideoRef?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !registryAvatarVideoRef.isEmpty {
                resolvedAvatarVideoRef = registryAvatarVideoRef
            } else {
                resolvedAvatarVideoRef = nil
            }
            let snapshotAvatarSource = avatarSourceKey(for: snapshot)
            let registryAvatarSource = existingRegistry.map(avatarSourceKey(for:)) ?? ""
            let shouldPreferSnapshotAvatarSource = !snapshotAvatarSource.isEmpty || registryAvatarSource.isEmpty
            let resolvedAvatarRef = shouldPreferSnapshotAvatarSource ? snapshot.avatarRef : existingRegistry?.avatarRef
            let resolvedAvatarProvider = shouldPreferSnapshotAvatarSource ? snapshot.avatarProvider : existingRegistry?.avatarProvider
            let resolvedAvatarBucket = shouldPreferSnapshotAvatarSource ? snapshot.avatarBucket : existingRegistry?.avatarBucket
            let resolvedAvatarObjectKey = shouldPreferSnapshotAvatarSource ? snapshot.avatarObjectKey : existingRegistry?.avatarObjectKey
            let merged = UserProfile(
                id: canonicalID,
                username: normalizedUsername,
                displayName: snapshot.displayName,
                bio: resolvedBio,
                keywords: snapshot.keywords,
                gradientSpec: snapshot.gradientSpec,
                avatarImageData: resolvedAvatarData,
                avatarRef: resolvedAvatarRef,
                avatarProvider: resolvedAvatarProvider,
                avatarBucket: resolvedAvatarBucket,
                avatarObjectKey: resolvedAvatarObjectKey,
                isVerified: snapshot.isVerified || session.isSubscriber,
                isFounder: snapshot.isFounder || session.isFounder,
                isPrivateAccount: snapshot.isPrivateAccount,
                accountType: session.accountType,
                subscriptionPlan: snapshot.subscriptionPlan,
                signatureRef: snapshot.signatureRef,
                avatarVideoRef: resolvedAvatarVideoRef,
                websiteURL: session.websiteURL.isEmpty ? snapshot.websiteURL : session.websiteURL,
                venmoURL: session.venmoURL.isEmpty ? snapshot.venmoURL : session.venmoURL,
                cashAppURL: session.cashAppURL.isEmpty ? snapshot.cashAppURL : session.cashAppURL,
                spotifyURL: snapshot.spotifyURL,
                appleMusicURL: snapshot.appleMusicURL,
                businessLocation: session.businessLocation.isEmpty ? snapshot.businessLocation : session.businessLocation,
                businessPhone: session.businessPhone.isEmpty ? snapshot.businessPhone : session.businessPhone,
                homeCity: session.homeCity.isEmpty ? snapshot.homeCity : session.homeCity,
                dateOfBirth: session.dateOfBirth ?? snapshot.dateOfBirth,
                ageAssuranceCompletedAt: session.ageAssuranceCompletedAt ?? snapshot.ageAssuranceCompletedAt,
                parentalControls: session.parentalControls
            )
            registerProfile(roleAdjustedProfile(merged))
        }
    }

    private func mergeFounderClusterPostsFromLocalCache() {
        guard !useServerAuthoritativeState else { return }
        guard isCanonicalFounderProfile(currentUser) else { return }
        let clusterUsernames = founderClusterUsernames()
        let clusterIDs = Self.founderCanonicalAccounts.map(\.id) + Self.founderManagedBusinessAccounts.map(\.id)
        var extraPosts: [FeedPost] = []
        for profileID in clusterIDs where profileID != currentUser.id {
            let url = persistenceURL(for: profileID)
            guard let data = Persistence.loadData(from: url),
                  let persisted = try? JSONDecoder().decode(ScrollsState.self, from: data) else {
                continue
            }
            let filtered = persisted.posts.filter { post in
                clusterUsernames.contains(normalizeUsername(post.user.username))
            }
            extraPosts.append(contentsOf: filtered)
        }
        guard !extraPosts.isEmpty else { return }
        posts = deduplicatedPosts(posts + extraPosts)
        registerProfiles(from: extraPosts.map { $0.user })
    }

    private static let sampleProfiles: [UserProfile] = []

    private static func setUserDefaultsDataSafely(_ data: Data, forKey key: String) {
        if data.count >= maxUserDefaultsBlobBytes {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func isJPEGData(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        return data[data.startIndex] == 0xFF && data[data.startIndex.advanced(by: 1)] == 0xD8
    }

    private static let suggestedFollowProfiles: [UserProfile] = [
        UserProfile(
            id: UUID(uuidString: "06C05FF4-18E5-4D36-BEFF-EEB0C45A754D")!,
            username: "lumen.waves",
            displayName: "Lumen Waves",
            bio: "Light studies and city textures.",
            keywords: ["light", "texture", "city"],
            gradientSpec: gradientSpec(for: [.systemOrange, .systemYellow]),
            avatarImageData: nil,
            isVerified: false,
            isFounder: false
        ),
        UserProfile(
            id: UUID(uuidString: "78FF1D21-5694-4D96-A2D8-7A20AA0C2A62")!,
            username: "echo.looms",
            displayName: "Echo Looms",
            bio: "Handheld clips and night edits.",
            keywords: ["video", "night", "edits"],
            gradientSpec: gradientSpec(for: [.systemBlue, .systemMint]),
            avatarImageData: nil,
            isVerified: false,
            isFounder: false
        ),
        UserProfile(
            id: UUID(uuidString: "A82CC737-BFF0-4E95-8E2D-4B2078D9053C")!,
            username: "cadenza",
            displayName: "Cadenza",
            bio: "Music and rooftop moments.",
            keywords: ["music", "rooftops", "rain"],
            gradientSpec: gradientSpec(for: [.systemIndigo, .systemTeal]),
            avatarImageData: nil,
            isVerified: true,
            isFounder: false
        ),
        UserProfile(
            id: UUID(uuidString: "D6AD4F28-0015-4301-BE6B-6D54F6A1AA37")!,
            username: "stereo.cast",
            displayName: "Stereo Cast",
            bio: "Cinematic loops and color studies.",
            keywords: ["cinematic", "color", "loops"],
            gradientSpec: gradientSpec(for: [.systemPink, .systemPurple]),
            avatarImageData: nil,
            isVerified: false,
            isFounder: false
        )
    ]

    private static var sampleTextScrolls: [FeedPost] {
        let snippets = [
            "Morning light pours through the studio windows, turning every sheet of paper into a soft reflection.",
            "City hums in bursts of synth—each stoplight a metronome for the skyline.",
            "Orbiting the quiet hum of this new feed, adding words that feel like breath."
        ]
        return snippets.enumerated().compactMap { index, text in
            guard index < sampleProfiles.count else { return nil }
            return FeedPost(
                id: UUID(),
                user: sampleProfiles[index],
                caption: nil,
                websiteURL: nil,
                timestamp: Date().addingTimeInterval(TimeInterval(-(index + 1) * 420)),
                mediaPreview: .text(text),
                comments: [],
                rescrollOrigin: nil
            )
        }
    }

    private static var initialPosts: [FeedPost] {
        var posts = sampleTextScrolls
        sampleProfiles.enumerated().forEach { index, profile in
            let palette = ScrollsFeedViewModel.gradientPalettes[index % ScrollsFeedViewModel.gradientPalettes.count]
            let image = PlatformImage.gradient(with: palette)
            if let media = Self.photoPreview(from: image) {
                posts.append(generatePost(user: profile, offset: index, mediaPreview: media))
            }
        }
        return posts
    }

    private static func generatePost(user: UserProfile, offset: Int, mediaPreview: MediaPreview) -> FeedPost {
        let captions = [
            "Rooftop reflections at golden hour.",
            "Textured shadows + analog warmth.",
            "Field report: rainy morning city glass.",
            "Night drive loop, soft neon.",
            "Fresh frame from the studio window."
        ]
        return FeedPost(
            id: UUID(),
            user: user,
            caption: captions[offset % captions.count],
            websiteURL: nil,
            timestamp: Date().addingTimeInterval(TimeInterval(-offset * 620)),
            mediaPreview: mediaPreview,
            comments: [],
            rescrollOrigin: nil
        )
    }

    private static let gradientPalettes: [[PlatformColor]] = [
        [.systemPink, .systemPurple],
        [.systemBlue, .systemTeal],
        [.systemOrange, .systemYellow],
        [.systemIndigo, .systemMint]
    ]

    private static func gradientSpec(for colors: [PlatformColor]) -> GradientSpec {
        let components = colors.compactMap { $0.toComponents() }
        let fallback = ColorComponents(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        return GradientSpec(colors: components.isEmpty ? [fallback] : components)
    }

    private static let sampleNotifications: [AppNotification] = []

    private static var sampleCircles: [CircleGroup] {
        []
    }

    private static func defaultFollowRelations(currentUserID: UUID) -> [UUID: Set<UUID>] {
        if shouldPreferServerProfileSeed() {
            // In backend-backed mode, avoid seeding synthetic follows.
            // Follow graph should come from remote truth during initial sync.
            return [currentUserID: []]
        }
        var relations: [UUID: Set<UUID>] = [:]
        let profileIDs = sampleProfiles.map { $0.id }
        relations[currentUserID] = Set(profileIDs)
        for (index, profile) in sampleProfiles.enumerated() {
            let candidates = sampleProfiles.filter { $0.id != profile.id }
            let followCount = min(candidates.count, 2 + (index % 2))
            var following = Set(candidates.prefix(followCount).map { $0.id })
            if index.isMultiple(of: 2) {
                following.insert(currentUserID)
            }
            relations[profile.id] = following
        }
        return relations
    }

    private func syncLanePriority(_ lane: BackendSyncLane) -> Int {
        switch lane {
        case .adSnapshot: return 1
        case .feedFast: return 2
        case .splashPrefetch: return 3
        case .socialSnapshot: return 4
        case .publishFollowUp: return 5
        case .manualRefresh: return 6
        }
    }

    private func queueBackendSyncRequest(lane: BackendSyncLane, skipIdentityReconcile: Bool) {
        if var queued = queuedBackendSyncRequest {
            if syncLanePriority(lane) > syncLanePriority(queued.lane) {
                queued.lane = lane
            }
            // If any caller requests identity reconciliation, preserve it.
            queued.skipIdentityReconcile = queued.skipIdentityReconcile && skipIdentityReconcile
            queuedBackendSyncRequest = queued
            return
        }
        queuedBackendSyncRequest = PendingBackendSyncRequest(
            lane: lane,
            skipIdentityReconcile: skipIdentityReconcile
        )
    }

    private func syncPlan(for lane: BackendSyncLane, skipIdentityReconcile: Bool) -> BackendSyncPlan {
        switch lane {
        case .feedFast:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: false,
                fetchRemoteUser: false,
                feedPages: 1,
                allowFeedFirstPageCache: true,
                forceSocialRefresh: false,
                forceAdRefresh: false,
                fetchFollowingFollowers: false,
                fetchCircles: false,
                fetchNotifications: false,
                fetchAdDelivery: false,
                fetchAdSubmissions: false,
                fetchCuratedSlots: false,
                fetchRecentCommentsBackfill: false
            )
        case .splashPrefetch:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: false,
                fetchRemoteUser: false,
                feedPages: 1,
                allowFeedFirstPageCache: false,
                forceSocialRefresh: false,
                forceAdRefresh: false,
                fetchFollowingFollowers: false,
                fetchCircles: false,
                fetchNotifications: false,
                fetchAdDelivery: false,
                fetchAdSubmissions: false,
                fetchCuratedSlots: false,
                fetchRecentCommentsBackfill: false
            )
        case .socialSnapshot:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: !skipIdentityReconcile,
                fetchRemoteUser: true,
                feedPages: 0,
                allowFeedFirstPageCache: false,
                forceSocialRefresh: false,
                forceAdRefresh: false,
                fetchFollowingFollowers: true,
                fetchCircles: true,
                fetchNotifications: true,
                fetchAdDelivery: false,
                fetchAdSubmissions: false,
                fetchCuratedSlots: false,
                fetchRecentCommentsBackfill: true
            )
        case .adSnapshot:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: false,
                fetchRemoteUser: false,
                feedPages: 0,
                allowFeedFirstPageCache: false,
                forceSocialRefresh: false,
                forceAdRefresh: false,
                fetchFollowingFollowers: false,
                fetchCircles: false,
                fetchNotifications: false,
                fetchAdDelivery: true,
                fetchAdSubmissions: canCurrentUserPublishFounderAds() || isAdReviewAdmin,
                fetchCuratedSlots: true,
                fetchRecentCommentsBackfill: false
            )
        case .publishFollowUp:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: false,
                fetchRemoteUser: false,
                feedPages: 0,
                allowFeedFirstPageCache: false,
                forceSocialRefresh: true,
                forceAdRefresh: true,
                fetchFollowingFollowers: true,
                fetchCircles: true,
                fetchNotifications: true,
                fetchAdDelivery: true,
                fetchAdSubmissions: canCurrentUserPublishFounderAds() || isAdReviewAdmin,
                fetchCuratedSlots: true,
                fetchRecentCommentsBackfill: true
            )
        case .manualRefresh:
            return BackendSyncPlan(
                lane: lane,
                reconcileIdentity: !skipIdentityReconcile,
                fetchRemoteUser: true,
                feedPages: 1,
                allowFeedFirstPageCache: false,
                forceSocialRefresh: true,
                forceAdRefresh: true,
                fetchFollowingFollowers: true,
                fetchCircles: true,
                fetchNotifications: true,
                fetchAdDelivery: true,
                fetchAdSubmissions: canCurrentUserPublishFounderAds() || isAdReviewAdmin,
                fetchCuratedSlots: true,
                fetchRecentCommentsBackfill: true
            )
        }
    }

    private func cachedValue<Value>(
        from entry: SyncCacheEntry<Value>?,
        for userID: UUID,
        ttl: TimeInterval
    ) -> Value? {
        guard let entry else { return nil }
        guard entry.ownerUserID == userID else { return nil }
        guard Date().timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return entry.value
    }

    private func fetchFollowingForSync(userID: UUID, forceRefresh: Bool) async -> [BackendUser]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedFollowingUsers,
            for: userID,
            ttl: BackendPollingCostSaverMode.followingFollowersTTL
           ) {
            return cached
        }
        let requestedUserID = userID
        let publicFallbackUserID = userID
        let remote: [BackendUser]
        do {
            remote = try await backendClient.fetchFollowing(
                userID: requestedUserID,
                allowAuthContextFallbackOnEmpty: false
            )
        } catch {
            guard isAuthenticationFailureError(error),
                  let publicRemote = try? await backendClient.fetchFollowing(
                    userID: publicFallbackUserID,
                    allowAuthContextFallbackOnEmpty: false,
                    includeAuthorization: false
                  ) else {
                return nil
            }
            cachedFollowingUsers = SyncCacheEntry(ownerUserID: userID, value: publicRemote, fetchedAt: Date())
            return publicRemote
        }
        cachedFollowingUsers = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
        return remote
    }

    private func fetchFollowersForSync(userID: UUID, forceRefresh: Bool) async -> [BackendUser]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedFollowerUsers,
            for: userID,
            ttl: BackendPollingCostSaverMode.followingFollowersTTL
           ) {
            return cached
        }
        let requestedUserID = userID
        let publicFallbackUserID = userID
        let remote: [BackendUser]
        do {
            remote = try await backendClient.fetchFollowers(
                userID: requestedUserID,
                allowAuthContextFallbackOnEmpty: false
            )
        } catch {
            guard isAuthenticationFailureError(error),
                  let publicRemote = try? await backendClient.fetchFollowers(
                    userID: publicFallbackUserID,
                    allowAuthContextFallbackOnEmpty: false,
                    includeAuthorization: false
                  ) else {
                return nil
            }
            cachedFollowerUsers = SyncCacheEntry(ownerUserID: userID, value: publicRemote, fetchedAt: Date())
            return publicRemote
        }
        cachedFollowerUsers = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
        return remote
    }

    private func fetchCirclesForSync(userID: UUID, forceRefresh: Bool) async -> [BackendCircle]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedCircles,
            for: userID,
            ttl: BackendPollingCostSaverMode.circlesTTL
           ) {
            return cached
        }
        let expectedSubject = currentUser.id
        var authTokenOverride = currentUsableAuthTokenForWrite()
        if authTokenOverride == nil {
            authTokenOverride = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                expectedSubjectUserID: expectedSubject
            )
        }
        // Cross-app safety: do not use one global message cursor for all
        // circles. A newer message in one thread can otherwise hide an
        // older-but-unseen message from the standalone Circles app in another
        // thread. Until the backend supports per-circle cursors, fetch the
        // canonical full inbox like the standalone messaging app does.
        let circlesSince: Date? = nil
        do {
let remote = try await backendClient.fetchCircles(
    userID: userID,
    since: circlesSince,
    includeAuthorization: true,
    allowAuthRetry: true,
    authTokenOverride: authTokenOverride
)
let remoteMessageCount = remote.reduce(0) { $0 + $1.messages.count }
updateFeedDebug(
    stage: "circles_fetch_success",
    status: "Circles fetched",
    detail: "user_id=\(userID.uuidString.prefix(8)), force_refresh=\(forceRefresh ? "yes" : "no"), since=\(circlesSince == nil ? "none" : "set"), circles=\(remote.count), messages=\(remoteMessageCount), auth_override=\(authTokenOverride == nil ? "no" : "yes")"
)
cachedCircles = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
return remote
        } catch {
            if isAuthenticationFailureError(error) {
                _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
                let retryOverride = await backendClient.serverValidatedAuthorizationTokenForEdgeRequests(
                    expectedSubjectUserID: expectedSubject
                )
if let remote = try? await backendClient.fetchCircles(
    userID: userID,
    since: circlesSince,
    includeAuthorization: true,
    allowAuthRetry: true,
    authTokenOverride: retryOverride
) {
    let remoteMessageCount = remote.reduce(0) { $0 + $1.messages.count }
    updateFeedDebug(
        stage: "circles_fetch_success_retry",
        status: "Circles fetched after auth refresh",
        detail: "user_id=\(userID.uuidString.prefix(8)), force_refresh=\(forceRefresh ? "yes" : "no"), since=\(circlesSince == nil ? "none" : "set"), circles=\(remote.count), messages=\(remoteMessageCount), auth_override=\(retryOverride == nil ? "no" : "yes")"
    )
    cachedCircles = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
    return remote
}
            }
            updateFeedDebug(
                stage: "circles_fetch_failed",
                status: "Circles fetch failed",
                detail: "user_id=\(userID.uuidString.prefix(8)), force_refresh=\(forceRefresh ? "yes" : "no"), auth_override=\(authTokenOverride == nil ? "no" : "yes")",
                error: error
            )
            return nil
        }
    }

    private func fetchNotificationsForSync(userID: UUID, forceRefresh: Bool) async -> [BackendNotification]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedNotifications,
            for: userID,
            ttl: BackendPollingCostSaverMode.notificationsTTL
           ) {
            return cached
        }
        do {
            let page = try await backendClient.fetchNotifications(
                userID: userID,
                allowAuthContextFallbackOnEmpty: false,
                limit: 60
            )
            cachedNotifications = SyncCacheEntry(ownerUserID: userID, value: page.items, fetchedAt: Date())
            notificationNextCursorByUserID[userID] = page.nextCursor
            return page.items
        } catch {
            if isAuthenticationFailureError(error) {
                _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
                if let page = try? await backendClient.fetchNotifications(
                    userID: userID,
                    allowAuthContextFallbackOnEmpty: false,
                    limit: 60
                ) {
                    cachedNotifications = SyncCacheEntry(ownerUserID: userID, value: page.items, fetchedAt: Date())
                    notificationNextCursorByUserID[userID] = page.nextCursor
                    return page.items
                }
            }
            return nil
        }
    }

    private func fetchAdSubmissionsForSync(userID: UUID, forceRefresh: Bool) async -> [BackendAdSubmission]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedAdSubmissions,
            for: userID,
            ttl: BackendPollingCostSaverMode.adSubmissionsTTL
           ) {
            return cached
        }
        updateAdDebug(
            targetID: userID.uuidString,
            stage: "ad_submissions_fetch_request",
            status: "Fetching ad submissions",
            detail: "limit=180"
        )
        do {
            let remote = try await backendClient.fetchAdSubmissions(limit: 180)
            cachedAdSubmissions = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "ad_submissions_fetch_success",
                status: "Fetched ad submissions",
                detail: "count=\(remote.count)"
            )
            return remote
        } catch {
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "ad_submissions_fetch_failed",
                status: "Ad submissions fetch failed",
                detail: "Will retry on next ad snapshot sync lane.",
                error: error
            )
            return nil
        }
    }

    private func ensureAuthReadyForAdReadSyncIfNeeded() async -> Bool {
        guard backendClient.isEnabled else { return false }
        if hasLocallyUsableAuthToken() { return true }
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        if hasLocallyUsableAuthToken() { return true }

        let hasRecoveryPath = hasRefreshTokenForBackendSync()
            || hasRecoverableSessionCandidateForBackendSync(preferRefresh: true)
        guard hasRecoveryPath else { return false }

        let recovered = await ensureBackendSessionForCurrentUser(preferRefresh: true)
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        return recovered && hasLocallyUsableAuthToken()
    }

    private func fetchAdDeliveryForSync(userID: UUID, forceRefresh: Bool) async -> [BackendAdDeliveryItem]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedAdDeliveryItems,
            for: userID,
            ttl: BackendPollingCostSaverMode.adDeliveryTTL
           ) {
            return cached
        }
        if !(await ensureAuthReadyForAdReadSyncIfNeeded()) {
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "ad_delivery_fetch_skipped_auth_not_ready",
                status: "Skipping ad delivery fetch until auth is ready",
                detail: "Startup auth recovery still in progress."
            )
            return nil
        }
        updateAdDebug(
            targetID: userID.uuidString,
            stage: "ad_delivery_fetch_request",
            status: "Fetching ad delivery",
            detail: "city=global, limit=20"
        )
        do {
            let remote = try await backendClient.fetchAdDelivery(city: nil, limit: 20)
            cachedAdDeliveryItems = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "ad_delivery_fetch_success",
                status: "Fetched ad delivery",
                detail: "count=\(remote.count)"
            )
            return remote
        } catch {
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "ad_delivery_fetch_failed",
                status: "Ad delivery fetch failed",
                detail: "Will reuse cache until next successful sync.",
                error: error
            )
            return nil
        }
    }

    private func fetchCuratedSlotsForSync(userID: UUID, forceRefresh: Bool) async -> [UUID?]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedCuratedSlots,
            for: userID,
            ttl: BackendPollingCostSaverMode.curatedSlotsTTL
           ) {
            return cached
        }
        if !(await ensureAuthReadyForAdReadSyncIfNeeded()) {
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "curated_slots_fetch_skipped_auth_not_ready",
                status: "Skipping curated slots fetch until auth is ready",
                detail: "Startup auth recovery still in progress."
            )
            return nil
        }
        updateAdDebug(
            targetID: userID.uuidString,
            stage: "curated_slots_fetch_request",
            status: "Fetching curated ad slots",
            detail: "source=backend"
        )
        do {
            let remote = try await backendClient.fetchCuratedAdSlots()
            cachedCuratedSlots = SyncCacheEntry(ownerUserID: userID, value: remote, fetchedAt: Date())
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "curated_slots_fetch_success",
                status: "Fetched curated ad slots",
                detail: "count=\(remote.count)"
            )
            return remote
        } catch {
            updateAdDebug(
                targetID: userID.uuidString,
                stage: "curated_slots_fetch_failed",
                status: "Curated slots fetch failed",
                detail: "Will retry on next ad snapshot sync lane.",
                error: error
            )
            return nil
        }
    }

    private func knownProfileIDsForDirectorySync(maxCount: Int = 220) -> [UUID] {
        var prioritized: [UUID] = []
        var seen = Set<UUID>()
        func append(_ id: UUID) {
            guard seen.insert(id).inserted else { return }
            prioritized.append(id)
        }

        // Tier 1/2: profiles visible now or directly connected to current account.
        append(currentUser.id)
        for id in following.map(\.id) { append(id) }
        for id in followers.map(\.id) { append(id) }
        for id in pendingFollowRequests.map(\.id) { append(id) }
        for post in posts {
            append(post.user.id)
            if let origin = post.rescrollOrigin {
                append(origin.user.id)
            }
        }
        for follows in followRelations.values {
            for id in follows {
                append(id)
            }
        }

        // Tier 3 sweep: oldest untouched profiles in registry.
        let staleCandidates = profileRegistry.keys
            .filter { !seen.contains($0) }
            .sorted {
                let lhs = profileLastRefreshedAtByID[$0] ?? .distantPast
                let rhs = profileLastRefreshedAtByID[$1] ?? .distantPast
                return lhs < rhs
            }
        for id in staleCandidates {
            append(id)
            if prioritized.count >= maxCount { break }
        }
        return Array(prioritized.prefix(maxCount))
    }

    private func staleProfileIDsForRefresh(limit: Int = 80) -> [UUID] {
        let now = Date()
        return profileRegistry.keys
            .filter { profileID in
                let refreshedAt = profileLastRefreshedAtByID[profileID] ?? .distantPast
                return now.timeIntervalSince(refreshedAt) > BackendPollingCostSaverMode.profileStaleSweepMaxAge
            }
            .sorted {
                let lhs = profileLastRefreshedAtByID[$0] ?? .distantPast
                let rhs = profileLastRefreshedAtByID[$1] ?? .distantPast
                return lhs < rhs
            }
            .prefix(limit)
            .map { $0 }
    }

    private func fetchDirectoryProfilesForSync(userID: UUID, forceRefresh: Bool) async -> [BackendUser]? {
        if !forceRefresh,
           let cached = cachedValue(
            from: cachedDirectoryProfiles,
            for: userID,
            ttl: BackendPollingCostSaverMode.profileDirectoryTTL
           ) {
            return cached
        }
        var merged: [BackendUser] = []
        var seen = Set<UUID>()
        func append(_ users: [BackendUser]) {
            for user in users where seen.insert(user.id).inserted {
                merged.append(user)
            }
        }

        let previousDeltaVersion = profileDeltaVersionByUserID[userID]
        var newestDeltaVersion = previousDeltaVersion

        if !forceRefresh, let previousDeltaVersion {
            if let deltaPage = try? await backendClient.fetchUsersDelta(
                sinceVersion: previousDeltaVersion,
                limit: 80,
                includeAuthorization: true
            ) {
                append(deltaPage.users)
                newestDeltaVersion = normalizedWriteVersionString(deltaPage.latestVersion) ?? newestDeltaVersion
            } else if let publicDelta = try? await backendClient.fetchUsersDelta(
                sinceVersion: previousDeltaVersion,
                limit: 80,
                includeAuthorization: false
            ) {
                append(publicDelta.users)
                newestDeltaVersion = normalizedWriteVersionString(publicDelta.latestVersion) ?? newestDeltaVersion
            }
        }

        // Seed/repair pass for first syncs and forced refreshes.
        if forceRefresh || previousDeltaVersion == nil {
            if let directoryPage = try? await backendClient.fetchUsersDirectory(limit: 60, includeAuthorization: true) {
                append(directoryPage.users)
            } else if let publicDirectoryPage = try? await backendClient.fetchUsersDirectory(limit: 60, includeAuthorization: false) {
                append(publicDirectoryPage.users)
            }
        }

        let ids = knownProfileIDsForDirectorySync(maxCount: 60)
        let staleIDs = staleProfileIDsForRefresh(limit: 20)
        let scopedIDs = Array(Set(ids + staleIDs))
        if !scopedIDs.isEmpty {
            do {
                let scoped = try await backendClient.fetchUsers(ids: scopedIDs, includeAuthorization: true)
                append(scoped)
            } catch {
                if isAuthenticationFailureError(error),
                   let scopedPublic = try? await backendClient.fetchUsers(ids: scopedIDs, includeAuthorization: false) {
                    append(scopedPublic)
                } else if let legacy = await fetchDirectoryProfilesLegacy(ids: scopedIDs) {
                    append(legacy)
                }
            }
        }

        guard !merged.isEmpty else { return nil }
        if let maxVersion = merged.compactMap({ normalizedWriteVersionString($0.writeVersion) }).max() {
            newestDeltaVersion = maxVersion
        }
        if let newestDeltaVersion {
            profileDeltaVersionByUserID[userID] = newestDeltaVersion
        }
        cachedDirectoryProfiles = SyncCacheEntry(ownerUserID: userID, value: merged, fetchedAt: Date())
        return merged
    }

    private func fetchDirectoryProfilesLegacy(ids: [UUID], maxCount: Int = 60) async -> [BackendUser]? {
        var resolved: [BackendUser] = []
        for id in ids.prefix(maxCount) {
            if let user = try? await backendClient.fetchUser(id: id) {
                resolved.append(user)
            }
        }
        return resolved.isEmpty ? nil : resolved
    }

    private func mergeRemoteDirectoryProfiles(_ users: [BackendUser]) {
        guard !users.isEmpty else { return }
        let previousCurrentUser = currentUser
        let didChangeProfiles = registerProfiles(from: users, applyRoleAdjustment: true)
        if let remoteCurrent = users.first(where: { $0.id == currentUser.id }) {
            currentUserWriteVersion = normalizeWriteVersion(remoteCurrent.writeVersion)
        }
        guard didChangeProfiles || previousCurrentUser != currentUser else { return }
        normalizeIdentityState()
        syncFollowDirectories()
        if previousCurrentUser != currentUser {
            refreshCurrentUserPosts()
        }
        saveState()
    }

    private func syncFeedFastIfAvailable(sessionUsername: String) async {
        _ = sessionUsername
        await syncFromBackendIfAvailable(lane: .feedFast, skipIdentityReconcile: true)
    }

    private func syncFromBackendIfAvailable(
        lane: BackendSyncLane = .manualRefresh,
        skipIdentityReconcile: Bool = false
    ) async {
        guard backendClient.isEnabled else { return }
        guard !Task.isCancelled else { return }
        guard !backendSyncInFlight else {
            queueBackendSyncRequest(lane: lane, skipIdentityReconcile: skipIdentityReconcile)
            return
        }
        backendSyncInFlight = true
        defer {
            backendSyncInFlight = false
            if !Task.isCancelled, let queued = queuedBackendSyncRequest {
                queuedBackendSyncRequest = nil
                Task { @MainActor [weak self] in
                    await self?.syncFromBackendIfAvailable(
                        lane: queued.lane,
                        skipIdentityReconcile: queued.skipIdentityReconcile
                    )
                }
            }
        }
        let plan = syncPlan(for: lane, skipIdentityReconcile: skipIdentityReconcile)
        let isFeedStartupLane = lane == .feedFast || lane == .splashPrefetch

        let rateLimitRemaining = feedRateLimitRemainingSeconds()
        if rateLimitRemaining > 0 && lane != .manualRefresh {
            let now = Date()
            if now.timeIntervalSince(lastFeedRateLimitSkipLogAt) >= Self.feedRateLimitSkipLogInterval {
                lastFeedRateLimitSkipLogAt = now
                updateFeedDebug(
                    stage: "lane_\(lane.debugLabel)_rate_limited",
                    status: "Skipping sync lane due to feed rate limit",
                    detail: "cooldown_remaining=\(rateLimitRemaining)s, lane=\(lane.debugLabel)"
                )
            }
            return
        }

        // Keep first-feed paint fast: avoid blocking feedFast lane on full
        // session ensure. fetchFeedWithTokenRecovery already performs auth
        // validation/recovery and public fallback when needed.
        if !isFeedStartupLane {
            _ = await BackendTruthSyncCore.ensureActiveSession(
                for: resolvedBackendSessionUsername(),
                expectedUserID: currentUser.id,
                using: backendClient
            )
        }
        restoreBackendAuthTokenForCurrentUserIfNeeded()
        let authUnavailableForNonEssentialSync = !hasLocallyUsableAuthToken() && !hasRefreshTokenForBackendSync()
        let shouldThrottleNonEssentialSync = authUnavailableForNonEssentialSync && lane != .manualRefresh
        if shouldThrottleNonEssentialSync {
            updateFeedDebug(
                stage: "lane_\(lane.debugLabel)_auth_unavailable_throttled",
                status: "Pausing non-essential sync work; awaiting session recovery",
                detail: "reconcile=\(plan.reconcileIdentity ? "yes" : "no"), remote_user=\(plan.fetchRemoteUser ? "yes" : "no"), following=\(plan.fetchFollowingFollowers ? "yes" : "no"), circles=\(plan.fetchCircles ? "yes" : "no"), notifications=\(plan.fetchNotifications ? "yes" : "no"), ad_delivery=\(plan.fetchAdDelivery ? "yes" : "no"), ad_submissions=\(plan.fetchAdSubmissions ? "yes" : "no"), curated_slots=\(plan.fetchCuratedSlots ? "yes" : "no"), comments_backfill=\(plan.fetchRecentCommentsBackfill ? "yes" : "no")",
                authPreflight: currentAuthSnapshotForSyncDebug()
            )
        }
        if !pendingFollowSyncQueue.isEmpty, !shouldThrottleNonEssentialSync {
            Task {  [weak self] in
                await self?.flushPendingFollowSyncQueue()
            }
        }
        if !shouldThrottleNonEssentialSync {
            Task {  [weak self] in
                await self?.flushPendingDeletions()
            }
        }

        if plan.reconcileIdentity && !shouldThrottleNonEssentialSync {
            await reconcileCurrentUserIdentityFromBackendIfNeeded()
        }

        let feedPageLimitOverride = lane == .feedFast ? Self.feedTimelineFastStartPageSize : nil
        if plan.feedPages > 0,
           let page = await fetchFeedWithTokenRecovery(
            maxPages: plan.feedPages,
            allowFirstPageCache: plan.allowFeedFirstPageCache,
            pageLimitOverride: feedPageLimitOverride,
            prioritizeFirstPaint: lane == .feedFast && self.posts.isEmpty && self.pendingRemotePosts.isEmpty
           ) {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.updateFeedDebug(
                    stage: "lane_\(lane.debugLabel)_fetched",
                    status: "Feed fetched for lane \(lane.debugLabel)",
                    detail: "remote_posts=\(page.posts.count), next_cursor=\(self.normalizedFeedCursor(page.nextCursor) ?? "none"), local_posts_before=\(self.posts.count), pending_before=\(self.pendingRemotePosts.count)"
                )
                feedTimelineNextCursor = normalizedFeedCursor(page.nextCursor)
                // feedFast fetches only feedTimelineFastStartPageSize posts — too small a
                // window to be authoritative for eviction. Use feedTimelineAppend so posts
                // are marked trusted but stale-post eviction is deferred until a full-page
                // sync runs. Eviction with 6 confirmed IDs was silently dropping cached
                // posts from followed users that didn't appear in the fast-start slice.
                let mergeSource: RemotePostMergeSource = isFeedStartupLane ? .feedTimelineAppend : .feedTimeline
                mergeRemotePosts(
                    page.posts,
                    source: mergeSource,
                    timelineCursorExhausted: self.normalizedFeedCursor(page.nextCursor) == nil
                )
                // Process server-pushed tombstones: purge any post IDs the
                // backend reports as deleted from every local feed array so
                // that other users' in-memory feeds are cleaned up immediately
                // rather than waiting for the stale-eviction window.
                if let tombstones = page.deletedPostIDs, !tombstones.isEmpty {
                    for id in tombstones {
                        self.markPostDeleted(id)
                    }
                    self.saveState()
                }
                self.updateFeedDebug(
                    stage: "lane_\(lane.debugLabel)_merged",
                    status: "Feed merged for lane \(lane.debugLabel)",
                    detail: "local_posts_after=\(self.posts.count), pending_after=\(self.pendingRemotePosts.count), visible_after=\(self.mainFeedPosts.count)",
                    visibilitySummary: self.mainFeedVisibilitySummary()
                )
                if lane == .feedFast {
                    self.scheduleFeedFastTopUpIfNeeded()
                }
            }
        }

        if plan.feedPages > 0 && !shouldThrottleNonEssentialSync {
            await reconcileCachedDeletedPostsWithBackend(
                force: isFeedStartupLane || lane == .manualRefresh,
                reason: "lane_\(lane.debugLabel)"
            )
        }

        if plan.fetchRemoteUser && !shouldThrottleNonEssentialSync {
            if let remoteUser = try? await backendClient.fetchUser(id: currentUser.id) {
                await MainActor.run { mergeRemoteCurrentUser(remoteUser) }
            } else {
                let normalized = normalizeUsername(currentUser.username)
                if !normalized.isEmpty,
                   let remoteByUsername = try? await backendClient.fetchUserByUsername(normalized, includeAuthorization: false) {
                    await MainActor.run { mergeRemoteCurrentUser(remoteByUsername) }
                }
            }
        }


        guard !Task.isCancelled else { return }
        let resolvedUserID = currentUser.id

        if plan.fetchFollowingFollowers && !shouldThrottleNonEssentialSync {
            async let remoteFollowingTask = fetchFollowingForSync(userID: resolvedUserID, forceRefresh: plan.forceSocialRefresh)
            async let remoteFollowersTask = fetchFollowersForSync(userID: resolvedUserID, forceRefresh: plan.forceSocialRefresh)
            if let remoteFollowing = await remoteFollowingTask {
                await MainActor.run { mergeRemoteFollowing(remoteFollowing) }
            }
            if let remoteFollowers = await remoteFollowersTask {
                await MainActor.run { mergeRemoteFollowers(remoteFollowers) }
            }
            if resolvedUserID == currentUser.id,
               let remoteRequests = try? await backendClient.fetchFollowRequests(userID: currentUser.id) {
                await MainActor.run { mergeRemoteFollowRequests(remoteRequests) }
            }
        }

        if !isFeedStartupLane,
           !shouldThrottleNonEssentialSync,
           let directoryProfiles = await fetchDirectoryProfilesForSync(
            userID: resolvedUserID,
            forceRefresh: plan.forceSocialRefresh
           ) {
            await MainActor.run { mergeRemoteDirectoryProfiles(directoryProfiles) }
        }

        if plan.fetchNotifications,
           !shouldThrottleNonEssentialSync,
           let remoteNotifications = await fetchNotificationsForSync(userID: resolvedUserID, forceRefresh: plan.forceSocialRefresh) {
            await MainActor.run { mergeRemoteNotifications(remoteNotifications) }
        }

        // Block list: load once per session on any sync plan that fetches notifications.
        // A simple flag avoids redundant network calls on subsequent refreshes.
        if plan.fetchNotifications, !shouldThrottleNonEssentialSync, blockedUserIDs.isEmpty {
            loadBlockedUserIDs()
        }


        if plan.fetchCircles,
           !shouldThrottleNonEssentialSync,
           let remoteCircles = await fetchCirclesForSync(userID: resolvedUserID, forceRefresh: plan.forceSocialRefresh) {
            await MainActor.run {
                mergeRemoteCircles(remoteCircles)
                if pruneCirclesForCost() {
                    saveState()
                }
            }
        }

        if plan.fetchAdSubmissions,
           !shouldThrottleNonEssentialSync,
           let remoteSubmissions = await fetchAdSubmissionsForSync(userID: resolvedUserID, forceRefresh: plan.forceAdRefresh) {
            await MainActor.run { mergeRemoteAdSubmissions(remoteSubmissions) }
        }

        if plan.fetchAdDelivery,
           !shouldThrottleNonEssentialSync,
           let delivered = await fetchAdDeliveryForSync(userID: resolvedUserID, forceRefresh: plan.forceAdRefresh) {
            await MainActor.run { mergeDeliveredAds(delivered) }
        }

        if plan.fetchCuratedSlots,
           !shouldThrottleNonEssentialSync,
           let curatedSlots = await fetchCuratedSlotsForSync(userID: resolvedUserID, forceRefresh: plan.forceAdRefresh) {
            await MainActor.run {
                curatedAdSlotIDs = curatedSlots
                saveCuratedAdSlots()
            }
            await hydrateDeliveredAdsForCuratedSlots(slotIDs: curatedSlots.compactMap { $0 })
        }
        if plan.fetchRecentCommentsBackfill && !shouldThrottleNonEssentialSync {
            await backfillRecentCommentsForSyncLane(lane)
        }

        if !shouldThrottleNonEssentialSync {
            await refreshLiveMomentsSnapshotIfNeeded(for: lane)
        }

        guard !Task.isCancelled else { return }
        if !isFeedStartupLane && !shouldThrottleNonEssentialSync {
            Task {  [weak self] in
                await self?.ensureBackendFollowLinksForCurrentUser()
            }
        }
    }
    private func shouldRefreshLiveMomentsSnapshot(for lane: BackendSyncLane) -> Bool {
        switch lane {
        case .socialSnapshot, .publishFollowUp, .manualRefresh:
            return true
        case .feedFast, .splashPrefetch, .adSnapshot:
            return false
        }
    }

    private func refreshLiveMomentsSnapshotIfNeeded(for lane: BackendSyncLane) async {
        guard shouldRefreshLiveMomentsSnapshot(for: lane) else { return }

        let forceRefresh = (lane == .manualRefresh || lane == .publishFollowUp)
        let now = Date()
        if !forceRefresh, now.timeIntervalSince(lastLiveMomentsSnapshotRefreshAt) < BackendPollingCostSaverMode.momentsLiveSnapshotMinInterval {
            return
        }
        lastLiveMomentsSnapshotRefreshAt = now

        _ = await refreshActiveLiveStreamSession(managePublisher: false)
        await loadMoments()
    }

    private func recentCanonicalPostIDsForCommentBackfill(limit: Int) -> [UUID] {
        guard limit > 0 else { return [] }
        var ordered: [UUID] = []
        var seen = Set<UUID>()

        let sourcePosts = mainFeedPosts.isEmpty ? posts : mainFeedPosts
        for post in sourcePosts {
            let canonicalID = canonicalCommentThreadPostID(for: post)
            guard seen.insert(canonicalID).inserted else { continue }
            ordered.append(canonicalID)
            if ordered.count >= limit {
                break
            }
        }
        return ordered
    }

    private func backfillRecentCommentsForSyncLane(_ lane: BackendSyncLane) async {
        let targetPostIDs = recentCanonicalPostIDsForCommentBackfill(
            limit: BackendPollingCostSaverMode.commentsBackfillVisiblePostLimit
        )
        guard !targetPostIDs.isEmpty else { return }

        _ = await ensureBackendSessionForCurrentUser()
        var refreshed = 0
        var skippedCached = 0
        var skippedUnavailable = 0
        var failed = 0
        var firstFailure: Error?

        for postID in targetPostIDs {
            guard !Task.isCancelled else { return }
            let result = await refreshCommentsFromBackendForCanonicalPostID(
                postID,
                forceRefresh: false,
                skipSessionEnsure: true
            )
            switch result {
            case .refreshed:
                refreshed += 1
            case .skippedCached:
                skippedCached += 1
            case .skippedUnavailable:
                skippedUnavailable += 1
            case .failed(let error):
                failed += 1
                if firstFailure == nil {
                    firstFailure = error
                }
            }
            try? await Task.sleep(
                nanoseconds: BackendPollingCostSaverMode.commentsBackfillInterRequestDelayNanos
            )
        }

        if refreshed > 0 || failed > 0 || lane == .manualRefresh {
            updateFeedDebug(
                stage: "comments_backfill_\(lane.debugLabel)",
                status: "Comment backfill completed",
                detail: "targets=\(targetPostIDs.count), refreshed=\(refreshed), skipped_cached=\(skippedCached), skipped_unavailable=\(skippedUnavailable), failed=\(failed)",
                error: firstFailure
            )
        }
    }

    private func reconcileCurrentUserIdentityFromBackendIfNeeded() async {
        let username = normalizeUsername(currentUser.username)
        guard !username.isEmpty else { return }
        let remote: BackendUser
        do {
            do {
                remote = try await backendClient.fetchUserByUsername(username, includeAuthorization: true)
            } catch {
                remote = try await backendClient.fetchUserByUsername(username, includeAuthorization: false)
            }
            updateDebugStatus { status in
                status.lastIdentityResolveStatus = "Success"
            }
        } catch {
            updateDebugStatus { status in
                status.lastIdentityResolveStatus = "Failed: \(describeBackendError(error))"
            }
            return
        }
        updateDebugStatus { status in
            status.backendResolvedUserID = remote.id
        }
        guard remote.id != currentUser.id else { return }

        let oldID = currentUser.id
        let remoteProfile = resolvedCurrentUserProfile(remoteProfile: roleAdjustedProfile(remote.asUserProfile))
        currentUser = remoteProfile
        currentUserWriteVersion = normalizeWriteVersion(remote.writeVersion)
        if let parsed = parsedWriteVersionDate(remote.writeVersion) {
            profileWriteVersionsByID[remoteProfile.id] = parsed
        }
        if let oldVersion = profileWriteVersionsByID.removeValue(forKey: oldID) {
            if let existing = profileWriteVersionsByID[remoteProfile.id] {
                profileWriteVersionsByID[remoteProfile.id] = max(existing, oldVersion)
            } else {
                profileWriteVersionsByID[remoteProfile.id] = oldVersion
            }
        }

        if let oldProfile = profileRegistry.removeValue(forKey: oldID) {
            profileRegistry[remoteProfile.id] = UserProfile(
                id: remoteProfile.id,
                username: remoteProfile.username,
                displayName: remoteProfile.displayName,
                bio: remoteProfile.bio,
                keywords: remoteProfile.keywords,
                gradientSpec: remoteProfile.gradientSpec,
                avatarImageData: remoteProfile.avatarImageData ?? oldProfile.avatarImageData,
                avatarRef: remoteProfile.avatarRef,
                avatarProvider: remoteProfile.avatarProvider,
                avatarBucket: remoteProfile.avatarBucket,
                avatarObjectKey: remoteProfile.avatarObjectKey,
                isVerified: remoteProfile.isVerified,
                isFounder: remoteProfile.isFounder,
                isPrivateAccount: remoteProfile.isPrivateAccount,
                accountType: remoteProfile.accountType,
                subscriptionPlan: remoteProfile.subscriptionPlan,
                signatureRef: remoteProfile.signatureRef,
                avatarVideoRef: remoteProfile.avatarVideoRef,
                websiteURL: remoteProfile.websiteURL,
                venmoURL: remoteProfile.venmoURL,
                cashAppURL: remoteProfile.cashAppURL,
                spotifyURL: remoteProfile.spotifyURL,
                appleMusicURL: remoteProfile.appleMusicURL,
                businessLocation: remoteProfile.businessLocation,
                businessPhone: remoteProfile.businessPhone,
                homeCity: remoteProfile.homeCity,
                dateOfBirth: remoteProfile.dateOfBirth,
                ageAssuranceCompletedAt: remoteProfile.ageAssuranceCompletedAt,
                parentalControls: remoteProfile.parentalControls
            )
        } else {
            profileRegistry[remoteProfile.id] = remoteProfile
        }

        if let oldFollowing = followRelations.removeValue(forKey: oldID) {
            var merged = followRelations[remoteProfile.id] ?? []
            merged.formUnion(oldFollowing.map { $0 == oldID ? remoteProfile.id : $0 })
            followRelations[remoteProfile.id] = merged
        }
        followRelations = followRelations.reduce(into: [UUID: Set<UUID>]()) { partial, pair in
            let mappedKey = pair.key == oldID ? remoteProfile.id : pair.key
            let mappedValues = Set(pair.value.map { $0 == oldID ? remoteProfile.id : $0 })
            var existing = partial[mappedKey] ?? []
            existing.formUnion(mappedValues.filter { $0 != mappedKey })
            partial[mappedKey] = existing
        }

        let normalized = username
        let remapPost: (FeedPost) -> FeedPost = { post in
            let postUsername = self.normalizeUsername(post.user.username)
            let mappedUser = (post.user.id == oldID || postUsername == normalized) ? remoteProfile : post.user
            var mappedOrigin = post.rescrollOrigin
            if let origin = post.rescrollOrigin {
                let originUsername = self.normalizeUsername(origin.user.username)
                if origin.user.id == oldID || originUsername == normalized {
                    mappedOrigin = RescrollOrigin(
                        postID: origin.postID,
                        user: remoteProfile,
                        caption: origin.caption,
                        websiteURL: origin.websiteURL,
                        timestamp: origin.timestamp
                    )
                }
            }
            let mappedComments = self.remapCommentUsers(post.comments, with: remoteProfile)
            if mappedUser == post.user && mappedOrigin == post.rescrollOrigin && mappedComments == post.comments {
                return post
            }
            return FeedPost(
                id: post.id,
                user: mappedUser,
                caption: post.caption,
                websiteURL: post.websiteURL,
                locationCity: post.locationCity,
                timestamp: post.timestamp,
                mediaPreview: post.mediaPreview,
                comments: mappedComments,
                rescrollOrigin: mappedOrigin
            )
        }
        posts = posts.map(remapPost)
        pendingRemotePosts = pendingRemotePosts.map(remapPost)
        deliveredAdPosts = deliveredAdPosts.map(remapPost)
        circles = circles.map { circle in
            var updated = circle
            updated.members = circle.members.map { member in
                CircleMember(
                    id: member.id,
                    profileID: member.profileID == oldID ? remoteProfile.id : member.profileID,
                    status: member.status
                )
            }
            updated.messages = circle.messages.map { message in
                CircleMessage(
                    id: message.id,
                    userID: message.userID == oldID ? remoteProfile.id : message.userID,
                    encryptedText: message.encryptedText,
                    timestamp: message.timestamp,
                    sharedPostID: message.sharedPostID,
                    voiceProvider: message.voiceProvider,
                    voiceBucket: message.voiceBucket,
                    voiceObjectKey: message.voiceObjectKey,
                    voiceDurationSeconds: message.voiceDurationSeconds,
                    photoProvider: message.photoProvider,
                    photoBucket: message.photoBucket,
                    photoObjectKey: message.photoObjectKey,
                    photoContentType: message.photoContentType,
                    photoWidth: message.photoWidth,
                    photoHeight: message.photoHeight,
                    photoPreviewData: message.photoPreviewData,
                    expiresAt: message.expiresAt,
                    sendStatus: message.sendStatus
                )
            }
            return updated
        }

        LocalAuthStore.updateStoredUserID(matching: username, to: remoteProfile.id)
        registerProfile(currentUser)
        syncFollowDirectories()
        Self.saveProfileSnapshot(currentUser)
        saveState()
    }

    private func fetchFeedWithTokenRecovery(
        maxPages: Int = 2,
        allowFirstPageCache: Bool = false,
        pageLimitOverride: Int? = nil,
        prioritizeFirstPaint: Bool = false
    ) async -> BackendFeedPage? {
        let initialUsableToken = hasLocallyUsableAuthToken()
        let initialAuthSnapshot = makePublishAuthSnapshot(
            sessionActive: initialUsableToken,
            usableToken: initialUsableToken,
            serverValidated: nil
        )
        let resolvedMaxPages = max(1, maxPages)
        let resolvedPageLimit = max(
            1,
            min(pageLimitOverride ?? Self.feedTimelineDefaultPageSize, Self.feedTimelineDefaultPageSize)
        )
        updateFeedDebug(
            stage: "flow_start",
            status: "Feed sync started",
            detail: "max_pages=\(resolvedMaxPages), allow_first_page_cache=\(allowFirstPageCache ? "yes" : "no"), user_id=\(currentUser.id.uuidString.prefix(8))",
            authPreflight: initialAuthSnapshot,
            visibilitySummary: mainFeedVisibilitySummary(),
            resetFlow: true
        )

        if allowFirstPageCache,
           prioritizeFirstPaint,
           resolvedMaxPages == 1,
           let cached = cachedValue(
            from: cachedFeedFirstPage,
            for: currentUser.id,
            ttl: BackendPollingCostSaverMode.feedFirstPageTTL
           ) {
            updateFeedDebug(
                stage: "first_paint_cache_hit",
                status: "Using cached feed for first paint",
                detail: "cached_posts=\(cached.posts.count), limit=\(resolvedPageLimit)"
            )
            return cached
        }

        if !initialUsableToken, hasRefreshTokenForBackendSync() {
            _ = await ensureBackendSessionForCurrentUser(preferRefresh: true)
            restoreBackendAuthTokenForCurrentUserIfNeeded()
        }

        let preRequestUsableToken = hasLocallyUsableAuthToken()
        let preflightSnapshot = makePublishAuthSnapshot(
            sessionActive: preRequestUsableToken,
            usableToken: preRequestUsableToken,
            serverValidated: nil
        )
        updateFeedDebug(
            stage: "auth_ready",
            status: "Feed auth ready",
            detail: "Attempting feed fetch with local token state.",
            authPreflight: preflightSnapshot
        )

        func finish(
            page: BackendFeedPage,
            stage: String,
            status: String,
            detail: String
        ) -> BackendFeedPage {
            if resolvedMaxPages == 1 {
                cachedFeedFirstPage = SyncCacheEntry(
                    ownerUserID: currentUser.id,
                    value: page,
                    fetchedAt: Date()
                )
            }
            resetFeedRateLimitState()
            updateFeedDebug(
                stage: stage,
                status: status,
                detail: detail
            )
            return page
        }

        func fetchPage(
            stagePrefix: String,
            includeAuthorization: Bool,
            allowAuthContextFallbackOnEmpty: Bool
        ) async throws -> BackendFeedPage {
            updateFeedDebug(
                stage: "\(stagePrefix)_request",
                status: "Requesting feed page",
                detail: "limit=\(resolvedPageLimit), include_authorization=\(includeAuthorization ? "yes" : "no")"
            )
            let requestStartedAt = Date()
            let page = try await backendClient.fetchFeed(
                userID: currentUser.id,
                cursor: nil,
                limit: resolvedPageLimit,
                allowAuthContextFallbackOnEmpty: allowAuthContextFallbackOnEmpty,
                allowAuthContextFallbackOnAuthFailure: false,
                includeAuthorization: includeAuthorization
            )
            recordFeedRequestTelemetry(
                durationMS: Date().timeIntervalSince(requestStartedAt) * 1000,
                requestedLimit: resolvedPageLimit,
                returnedCount: page.posts.count
            )
            updateFeedDebug(
                stage: "\(stagePrefix)_response",
                status: "Feed page received",
                detail: "posts=\(page.posts.count), next_cursor=\(normalizedFeedCursor(page.nextCursor) ?? "none")"
            )
            return page
        }

        let hasRefreshToken = hasRefreshTokenForBackendSync()
        let shouldAttemptAuthorizedFetch = preRequestUsableToken || hasRefreshToken
        var lastError: Error?
        var terminalRateLimited = false

        if shouldAttemptAuthorizedFetch {
            do {
                let page = try await fetchPage(
                    stagePrefix: "authorized",
                    includeAuthorization: true,
                    allowAuthContextFallbackOnEmpty: true
                )
                moderationErrorMessage = nil
                return finish(
                    page: page,
                    stage: "authorized_success",
                    status: "Authorized feed fetch succeeded",
                    detail: "posts=\(page.posts.count), next_cursor=\(normalizedFeedCursor(page.nextCursor) ?? "none")"
                )
            } catch {
                lastError = error
                terminalRateLimited = isFeedRateLimitError(error)
                if terminalRateLimited {
                    let cooldownWindow = registerFeedRateLimitFailureAndResolveBackoffWindow()
                    applyFeedRateLimitBackoff(window: cooldownWindow)
                }
                updateFeedDebug(
                    stage: "authorized_failed",
                    status: "Authorized feed fetch failed: \(describeBackendError(error))",
                    detail: "Falling back only if the failure is auth-related.",
                    error: error
                )
                if isAuthenticationFailureError(error) {
                    recordAuthFailure(
                        error,
                        context: "Feed authorized fetch",
                        recovery: "Attempting public fallback"
                    )
                    _ = handleMissingAuthorizationHeaderIfUnrecoverable()
                }
            }
        }

        let shouldAttemptPublicFallback = !preRequestUsableToken || (lastError.map(isAuthenticationFailureError) ?? false)
        if shouldAttemptPublicFallback {
            do {
                let publicPage = try await fetchPage(
                    stagePrefix: "public_fallback",
                    includeAuthorization: false,
                    allowAuthContextFallbackOnEmpty: false
                )
                moderationErrorMessage = preRequestUsableToken
                    ? "Signed-out feed loaded. Sign in again to resume personalized sync."
                    : nil
                return finish(
                    page: publicPage,
                    stage: "public_fallback_success",
                    status: "Public feed fallback succeeded",
                    detail: "posts=\(publicPage.posts.count), next_cursor=\(normalizedFeedCursor(publicPage.nextCursor) ?? "none")"
                )
            } catch {
                lastError = error
                if isFeedRateLimitError(error) {
                    terminalRateLimited = true
                    let cooldownWindow = registerFeedRateLimitFailureAndResolveBackoffWindow()
                    applyFeedRateLimitBackoff(window: cooldownWindow)
                }
                updateFeedDebug(
                    stage: "public_fallback_failed",
                    status: "Public feed fallback failed: \(describeBackendError(error))",
                    detail: "No additional feed retries will be attempted.",
                    error: error
                )
            }
        }

        let hadPostsBeforeFallback = !posts.isEmpty
        if posts.isEmpty {
            hydrateFeedFromGlobalCacheFallbackIfNeeded()
            if !posts.isEmpty {
                updateFeedDebug(
                    stage: "cache_fallback_applied",
                    status: "Hydrated feed from local cache fallback",
                    detail: "fallback_posts=\(posts.count)",
                    visibilitySummary: mainFeedVisibilitySummary()
                )
            }
        }
        if hadPostsBeforeFallback {
            updateFeedDebug(
                stage: "sync_failed_using_existing_posts",
                status: "Feed sync failed; using existing local posts",
                detail: "existing_posts=\(posts.count)",
                visibilitySummary: mainFeedVisibilitySummary()
            )
        }
        if terminalRateLimited {
            let remaining = feedRateLimitRemainingSeconds()
            moderationErrorMessage = "Feed is rate limited. Auto retry in about \(max(remaining, 1))s."
        } else {
            if let lastError, isAuthenticationFailureError(lastError) {
                let shouldClearStoredTokens = shouldClearStoredSessionTokensForAuthFailure(lastError)
                let preserveRefreshToken = shouldPreserveRefreshTokenAfterAuthFailure(lastError)
                recordAuthFailure(
                    lastError,
                    context: "Feed terminal failure",
                    recovery: shouldClearStoredTokens
                        ? "Session marked stale; prompt reauthentication without forced logout"
                        : "Session retained; retry feed sync later"
                )
                if shouldClearStoredTokens {
                    clearStoredSessionTokensForReauthentication(preserveRefreshToken: preserveRefreshToken)
                }
            }
            moderationErrorMessage = "Feed sync failed. Pull to refresh, or sign in again if it keeps happening."
        }
        return nil
    }

    private func hydrateFeedFromGlobalCacheFallbackIfNeeded() {
        guard posts.isEmpty else { return }
        let cached = loadGlobalFeedCache()
        guard !cached.isEmpty else { return }
        posts = deduplicatedPosts(cached)
        registerProfiles(from: cached.map { $0.user })
        removePostsWithMissingMedia(checkAssetLibrary: false)
    }

    private static let fallbackProfileID = UUID(uuidString: "90F021EE-84F9-4A2A-83F6-2A6489D3FC38")!

    private func mergeRemoteCurrentUser(_ remoteUser: BackendUser) {
        let remoteProfile = remoteUser.asUserProfile
        let resolvedProfile = resolvedCurrentUserProfile(remoteProfile: remoteProfile)
        registerProfile(resolvedProfile, writeVersion: remoteUser.writeVersion)
        // Allow merge when currentUser still holds the placeholder UUID from a fresh install —
        // in that case we adopt the real UUID from the server response.
        let currentIsFallback = currentUser.id == Self.fallbackProfileID
        guard resolvedProfile.id == currentUser.id || currentIsFallback else { return }
        if currentIsFallback {
            // Adopt the server's real UUID so subsequent ID-based lookups work.
            currentUser = resolvedProfile
        }
        currentUserWriteVersion = normalizeWriteVersion(remoteUser.writeVersion)
        maybePresentFounderClaimMismatchPromptIfNeeded(resolvedProfile)
        // Sync the pinned-post dictionary from the backend's authoritative
        // value.  Without this, a cold launch (or reinstall, or fresh
        // device) would load `currentUser.pinnedPostID` correctly from
        // /me but the `pinnedPostIDs[userID]` dictionary that drives the
        // pin-detection in the feed would stay empty — so the user's pin
        // existed on the backend but didn't show up locally.  Pins
        // appeared to be "only saved locally" because the local-only
        // sidecar file was the only thing seeding the dictionary; the
        // backend response was being ignored for this dict.
        let resolvedUserID = resolvedProfile.id
        if let remotePinnedID = resolvedProfile.pinnedPostID {
            if pinnedPostIDs[resolvedUserID] != remotePinnedID {
                pinnedPostIDs[resolvedUserID] = remotePinnedID
                persistPinnedPostIDSnapshot()
            }
        } else if pinnedPostIDs[resolvedUserID] != nil {
            pinnedPostIDs.removeValue(forKey: resolvedUserID)
            persistPinnedPostIDSnapshot()
        }
        guard resolvedProfile != currentUser else { return }
        currentUser = resolvedProfile
        refreshCurrentUserPosts()
        Self.saveProfileSnapshot(currentUser)
        saveState()
        // If the avatar is remote-only (no local binary yet), download it now and
        // persist it into the snapshot so the profile hero renders instantly on
        // the next launch without needing a CDN round-trip.
        if resolvedProfile.avatarImageData == nil, let avatarURL = resolvedProfile.remoteAvatarURL {
            Task { [weak self] in
                guard let self else { return }
                if let downloaded = await FeedMediaPrefetcher.shared.thumbnail(
                    for: avatarURL, maxPixel: 420
                ) {
                    #if canImport(UIKit)
                    let data = downloaded.jpegData(compressionQuality: 0.82)
                    #elseif canImport(AppKit)
                    let data = downloaded.tiffRepresentation
                    #else
                    let data: Data? = nil
                    #endif
                    guard let data else { return }
                    await MainActor.run {
                        guard self.currentUser.id == resolvedProfile.id,
                              self.currentUser.avatarImageData == nil else { return }
                        let updated = self.currentUser.withAvatarImageData(data)
                        self.currentUser = updated
                        Self.saveProfileSnapshot(updated)
                    }
                }
            }
        }
    }

    private func scheduleProfileSync(
        profile: UserProfile,
        generation: Int,
        trigger: String,
        isAutomaticRetry: Bool
    ) {
        _ = trigger
        guard backendClient.isEnabled else { return }
        guard generation == profilePushGeneration else { return }
        if isAutomaticRetry {
            if profileAutoRetrySuspendedGeneration == generation {
                return
            }
            let now = Date()
            guard now.timeIntervalSince(lastProfileAutoRetryAt) >= Self.profileAutoRetryMinimumInterval else {
                return
            }
            lastProfileAutoRetryAt = now
        }
        Task {  [weak self] in
            guard let self else { return }
            await self.persistCurrentUserProfileToBackend(
                expectedGeneration: generation,
                profileOverride: profile
            )
        }
    }

    private func persistCurrentUserProfileToBackend(
        expectedGeneration: Int? = nil,
        profileOverride: UserProfile? = nil
    ) async {
        guard backendClient.isEnabled else { return }
        let generation = expectedGeneration ?? profilePushGeneration
        guard generation == profilePushGeneration else { return }
        if profileSyncInFlightGenerations.contains(generation) {
            let profile = profileOverride ?? pendingProfilePushSnapshot ?? currentUser
            updateProfileDebug(
                profileID: profile.id,
                stage: "backend_sync_coalesced",
                status: "Profile sync already in flight",
                detail: "generation=\(generation)"
            )
            return
        }
        profileSyncInFlightGenerations.insert(generation)
        defer { profileSyncInFlightGenerations.remove(generation) }
        let profile = profileOverride ?? pendingProfilePushSnapshot ?? currentUser
        var sawWriteVersionConflict = false
        var conflictRecoveryAttempts = 0
        updateProfileDebug(
            profileID: profile.id,
            stage: "backend_sync_started",
            status: "Syncing profile to backend",
            detail: "generation=\(generation), max_attempts=3",
            authPreflight: currentAuthSnapshotForSyncDebug()
        )
        for _ in 0..<3 {
            guard generation == profilePushGeneration else { return }
            do {
                var expectedWriteVersion = currentUserWriteVersion
                if expectedWriteVersion == nil,
                   let remoteUser = await fetchRemoteUserForProfileSync(profile),
                   generation == profilePushGeneration {
                    expectedWriteVersion = normalizeWriteVersion(remoteUser.writeVersion)
                    currentUserWriteVersion = expectedWriteVersion
                    if let expectedWriteVersion {
                        updateProfileDebug(
                            profileID: profile.id,
                            stage: "write_version_hydrated",
                            status: "Loaded latest write version before sync",
                            detail: "expected_write_version=\(expectedWriteVersion)"
                        )
                    }
                }
                updateProfileDebug(
                    profileID: profile.id,
                    stage: "backend_request",
                    status: "Profile backend request started",
                    detail: "expected_write_version=\(expectedWriteVersion ?? "none")",
                    authPreflight: currentAuthSnapshotForSyncDebug()
                )
                let upserted = try await backendClient.upsertProfile(
                    profile,
                    expectedWriteVersion: expectedWriteVersion
                )
                await MainActor.run {
                    Self.saveProfileSnapshot(profile)
                }
                clearPendingProfilePushIfRemoteCatchesUp(upserted.asUserProfile)
                mergeRemoteCurrentUser(upserted)
                updateProfileDebug(
                    profileID: profile.id,
                    stage: "backend_acknowledged",
                    status: "Profile sync succeeded",
                    detail: "write_version=\(normalizeWriteVersion(upserted.writeVersion) ?? "none")"
                )
                return
            } catch {
                guard generation == profilePushGeneration else { return }
                if isWriteVersionConflictError(error) {
                    sawWriteVersionConflict = true
                    if conflictRecoveryAttempts >= 1 {
                        profileAutoRetrySuspendedGeneration = generation
                        updateProfileDebug(
                            profileID: profile.id,
                            stage: "write_version_conflict_paused",
                            status: "Repeated profile conflict; pausing auto retry",
                            detail: "Auto retry paused for this edit generation. Save again after refreshing profile.",
                            error: error
                        )
                        moderationErrorMessage = "Profile changed on another device. Refresh profile and save again."
                        return
                    }
                    conflictRecoveryAttempts += 1
                    updateProfileDebug(
                        profileID: profile.id,
                        stage: "write_version_conflict",
                        status: "Profile sync conflict",
                        detail: "Backend reported write-version conflict; refreshing write version and retrying with local edits.",
                        error: error
                    )
                    let recovered = await resolveCurrentUserWriteVersionConflict(
                        using: profile,
                        generation: generation
                    )
                    if recovered {
                        continue
                    }
                    profileAutoRetrySuspendedGeneration = generation
                    return
                }
                updateProfileDebug(
                    profileID: profile.id,
                    stage: "backend_attempt_failed",
                    status: "Profile backend attempt failed",
                    detail: "Retrying after short backoff.",
                    error: error
                )
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
        updateProfileDebug(
            profileID: profile.id,
            stage: "backend_retry_exhausted",
            status: "Profile sync exhausted retries",
            detail: "Profile remains pending local sync."
        )
        if sawWriteVersionConflict {
            profileAutoRetrySuspendedGeneration = generation
        }
    }

    private func fetchRemoteUserForProfileSync(_ profile: UserProfile) async -> BackendUser? {
        if let remoteUserByID = try? await backendClient.fetchUser(id: profile.id) {
            return remoteUserByID
        }
        let normalizedUsername = normalizeUsername(profile.username)
        guard !normalizedUsername.isEmpty else { return nil }
        return try? await backendClient.fetchUserByUsername(normalizedUsername, includeAuthorization: false)
    }

    private func resolveCurrentUserWriteVersionConflict(
        using attemptedProfile: UserProfile,
        generation: Int
    ) async -> Bool {
        guard generation == profilePushGeneration else { return false }
        guard let remoteUser = await fetchRemoteUserForProfileSync(attemptedProfile),
              generation == profilePushGeneration else {
            currentUserWriteVersion = nil
            updateProfileDebug(
                profileID: attemptedProfile.id,
                stage: "conflict_remote_refresh_failed",
                status: "Profile conflict refresh failed",
                detail: "Could not load remote profile snapshot after conflict."
            )
            moderationErrorMessage = "Profile sync conflict could not be resolved. Please try saving again."
            return false
        }

        let remoteProfile = remoteUser.asUserProfile
        let retryProfile = attemptedProfile.with(
            isVerified: remoteProfile.isVerified,
            isFounder: remoteProfile.isFounder,
            accountType: remoteProfile.accountType,
            subscriptionPlan: remoteProfile.subscriptionPlan,
            dateOfBirth: remoteProfile.dateOfBirth,
            ageAssuranceCompletedAt: remoteProfile.ageAssuranceCompletedAt
        )

        currentUserWriteVersion = normalizeWriteVersion(remoteUser.writeVersion)
        pendingProfilePushSnapshot = retryProfile
        pendingProfilePushStartedAt = Date()
        registerProfile(retryProfile, writeVersion: remoteUser.writeVersion)
        if retryProfile.id == currentUser.id, retryProfile != currentUser {
            currentUser = retryProfile
            refreshCurrentUserPosts()
            Self.saveProfileSnapshot(currentUser)
            saveState()
        }

        updateProfileDebug(
            profileID: attemptedProfile.id,
            stage: "conflict_remote_refresh_success",
            status: "Loaded latest profile write version",
            detail: "Preserved local edits and retrying profile sync."
        )
        return currentUserWriteVersion != nil
    }

    private func isWriteVersionConflictError(_ error: Error) -> Bool {
        guard let backendError = error as? BackendClientError else { return false }
        guard case let .httpStatus(code, message) = backendError else { return false }
        guard code == 409 else { return false }
        let normalizedMessage = message?.lowercased() ?? ""
        if normalizedMessage.isEmpty { return true }
        return normalizedMessage.contains("write version")
            || normalizedMessage.contains("another device")
            || normalizedMessage.contains("refresh profile before saving")
    }

    private func normalizeWriteVersion(_ writeVersion: String?) -> String? {
        guard let trimmed = writeVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        guard let parsed = parsedWriteVersionDate(trimmed) else {
            return nil
        }
        return Self.writeVersionFormatterWithFractionalSeconds.string(from: parsed)
    }

    private func markPendingProfilePush(_ profile: UserProfile) {
        profilePushGeneration += 1
        pendingProfilePushSnapshot = profile
        pendingProfilePushStartedAt = Date()
        profileAutoRetrySuspendedGeneration = nil
        lastProfileAutoRetryAt = .distantPast
    }

    private func pendingProfilePushIsActive(for profileID: UUID) -> Bool {
        guard let pending = pendingProfilePushSnapshot, pending.id == profileID else { return false }
        guard let startedAt = pendingProfilePushStartedAt else { return false }
        if Date().timeIntervalSince(startedAt) > ProfileSyncCostSaverMode.localEditProtectionWindow {
            pendingProfilePushSnapshot = nil
            pendingProfilePushStartedAt = nil
            return false
        }
        return true
    }

    private func clearPendingProfilePushIfRemoteCatchesUp(_ remoteProfile: UserProfile) {
        guard let pending = pendingProfilePushSnapshot, pending.id == remoteProfile.id else { return }
        guard !isRemoteProfileStaleComparedToPendingLocal(remote: remoteProfile, pending: pending) else { return }
        pendingProfilePushSnapshot = nil
        pendingProfilePushStartedAt = nil
    }

    private func resolvedCurrentUserProfile(remoteProfile: UserProfile) -> UserProfile {
        guard pendingProfilePushIsActive(for: remoteProfile.id),
              let pending = pendingProfilePushSnapshot else {
            clearPendingProfilePushIfRemoteCatchesUp(remoteProfile)
            return remoteProfile
        }
        guard isRemoteProfileStaleComparedToPendingLocal(remote: remoteProfile, pending: pending) else {
            clearPendingProfilePushIfRemoteCatchesUp(remoteProfile)
            return remoteProfile
        }
        if backendClient.isEnabled {
            scheduleProfileSync(
                profile: pending,
                generation: profilePushGeneration,
                trigger: "remote_profile_stale_auto_retry",
                isAutomaticRetry: true
            )
        }
        // Keep recent local edits stable while server write catches up; preserve server-owned entitlement flags.
        return pending.with(
            isVerified: remoteProfile.isVerified,
            isFounder: remoteProfile.isFounder,
            accountType: remoteProfile.accountType,
            subscriptionPlan: remoteProfile.subscriptionPlan,
            dateOfBirth: remoteProfile.dateOfBirth,
            ageAssuranceCompletedAt: remoteProfile.ageAssuranceCompletedAt
        )
    }

    private func isRemoteProfileStaleComparedToPendingLocal(remote: UserProfile, pending: UserProfile) -> Bool {
        normalizeUsername(remote.username) != normalizeUsername(pending.username) ||
        remote.displayName != pending.displayName ||
        remote.bio != pending.bio ||
        remote.keywords != pending.keywords ||
        remote.websiteURL != pending.websiteURL ||
        remote.venmoURL != pending.venmoURL ||
        remote.cashAppURL != pending.cashAppURL ||
        remote.spotifyURL != pending.spotifyURL ||
        remote.appleMusicURL != pending.appleMusicURL ||
        remote.businessLocation != pending.businessLocation ||
        remote.businessPhone != pending.businessPhone ||
        remote.homeCity != pending.homeCity ||
        remote.isPrivateAccount != pending.isPrivateAccount ||
        remote.parentalControls != pending.parentalControls ||
        remote.signatureRef != pending.signatureRef ||
        remote.avatarVideoRef != pending.avatarVideoRef ||
        remote.avatarRef != pending.avatarRef ||
        remote.avatarProvider != pending.avatarProvider ||
        remote.avatarBucket != pending.avatarBucket ||
        remote.avatarObjectKey != pending.avatarObjectKey ||
        remote.avatarImageData != pending.avatarImageData
    }

    private func mergeRemotePosts(
        _ remotePosts: [BackendPost],
        source: RemotePostMergeSource,
        timelineCursorExhausted: Bool = false
    ) {
        guard !remotePosts.isEmpty else {
            updateFeedDebug(
                stage: "merge_\(source.debugLabel)_skipped_empty",
                status: "Merge skipped (no remote posts)",
                detail: "source=\(source.debugLabel)"
            )
            return
        }
        // STUCK-DELETION AUTO-HEAL: if any incoming remote post matches a
        // postID the user previously requested deleted, the backend never
        // actually removed it (silent 200 from a buggy delete handler, an
        // auth-rejected retry stuck in the queue, etc.).  Re-enqueue the
        // delete RPC NOW so every passive surface — feed pull, profile
        // browse, deep-link resolve, search — becomes an opportunity to
        // self-heal stuck deletions.  The downstream merge code already
        // filters these IDs out via `pendingDeletedPostIDs` so the user
        // never SEES the resurfaced post; this hook handles the cleanup
        // on the server side.
        autoRetryStuckDeletionsForBackendPosts(remotePosts)
        let mergeStartedAt = Date()
        defer {
            recordFeedMergeTelemetry(
                durationMS: Date().timeIntervalSince(mergeStartedAt) * 1000,
                source: source,
                remoteCount: remotePosts.count
            )
        }
        let postsBefore = posts.count
        let pendingBefore = pendingRemotePosts.count
        let visibleBefore = mainFeedPosts.count
        var acknowledgedPublishCount = 0
        var updatedExistingCount = 0
        var updatedPendingCount = 0
        let isTimelineMerge = source == .feedTimeline || source == .feedTimelineAppend
        let shouldEvictStaleTrustedTimelinePosts = source == .feedTimeline
        if isTimelineMerge {
            markTimelinePostsTrusted(remotePosts)
        }
        var confirmedTimelinePostIDs: Set<UUID> = []
        var oldestConfirmedTimelineTimestamp: Date?
        var incoming: [FeedPost] = []
        var didUpdateExisting = false
        let pendingCirclePostNotifications: [(postID: UUID, author: UserProfile, circleName: String)] = []
        for remote in remotePosts {
            if postPublishDeliveryStates[remote.id] != nil {
                markPostBackendAcknowledged(remote.id)
                acknowledgedPublishCount += 1
            }
            let author = roleAdjustedProfile(remote.author.asUserProfile)
            registerProfile(author, writeVersion: remote.author.writeVersion)
            let mappedOrigin = mappedRescrollOrigin(from: remote)
            let resolvedTimestamp = resolvedFeedPostTimestamp(
                remoteCreatedAt: remote.createdAt,
                rescrollOrigin: mappedOrigin
            )
            if shouldEvictStaleTrustedTimelinePosts {
                confirmedTimelinePostIDs.insert(remote.id)
                if let oldest = oldestConfirmedTimelineTimestamp {
                    if resolvedTimestamp < oldest {
                        oldestConfirmedTimelineTimestamp = resolvedTimestamp
                    }
                } else {
                    oldestConfirmedTimelineTimestamp = resolvedTimestamp
                }
            }
            if let existingIndex = posts.firstIndex(where: { $0.id == remote.id }) {
                let existing = posts[existingIndex]
                posts[existingIndex] = FeedPost(
                    id: existing.id,
                    user: author,
                    caption: remote.caption,
                    websiteURL: remote.websiteURL,
                    locationCity: remote.locationCity,
                    timestamp: resolvedTimestamp,
                    mediaPreview: remote.asMediaPreview,
                    coverImageRef: remote.coverImageRef ?? existing.coverImageRef,
                    coverProvider: remote.coverProvider ?? existing.coverProvider,
                    coverBucket: remote.coverBucket ?? existing.coverBucket,
                    coverObjectKey: remote.coverObjectKey ?? existing.coverObjectKey,
                    comments: existing.comments,
                    rescrollOrigin: mappedOrigin,
                    rescrollQuoteText: normalizedRescrollQuoteText(remote.quoteText)
                )
                didUpdateExisting = true
                updatedExistingCount += 1
                continue
            }
            if let pendingIndex = pendingRemotePosts.firstIndex(where: { $0.id == remote.id }) {
                let existing = pendingRemotePosts[pendingIndex]
                pendingRemotePosts[pendingIndex] = FeedPost(
                    id: existing.id,
                    user: author,
                    caption: remote.caption,
                    websiteURL: remote.websiteURL,
                    locationCity: remote.locationCity,
                    timestamp: resolvedTimestamp,
                    mediaPreview: remote.asMediaPreview,
                    coverImageRef: remote.coverImageRef ?? existing.coverImageRef,
                    coverProvider: remote.coverProvider ?? existing.coverProvider,
                    coverBucket: remote.coverBucket ?? existing.coverBucket,
                    coverObjectKey: remote.coverObjectKey ?? existing.coverObjectKey,
                    comments: existing.comments,
                    rescrollOrigin: mappedOrigin,
                    rescrollQuoteText: normalizedRescrollQuoteText(remote.quoteText)
                )
                didUpdateExisting = true
                updatedPendingCount += 1
                continue
            }
            let mapped = FeedPost(
                id: remote.id,
                user: author,
                caption: remote.caption,
                websiteURL: remote.websiteURL,
                locationCity: remote.locationCity,
                timestamp: resolvedTimestamp,
                mediaPreview: remote.asMediaPreview,
                coverImageRef: remote.coverImageRef,
                coverProvider: remote.coverProvider,
                coverBucket: remote.coverBucket,
                coverObjectKey: remote.coverObjectKey,
                comments: [],
                rescrollOrigin: mappedOrigin,
                rescrollQuoteText: normalizedRescrollQuoteText(remote.quoteText)
            )
            incoming.append(mapped)
        }
        let evictedStaleTrustedCount = shouldEvictStaleTrustedTimelinePosts
            ? evictStaleTrustedTimelinePosts(
                confirmedPostIDs: confirmedTimelinePostIDs,
                oldestConfirmedTimestamp: oldestConfirmedTimelineTimestamp
            )
            : 0
        let evictedStaleUntrustedCount = shouldEvictStaleTrustedTimelinePosts
            ? evictStaleUntrustedTimelinePosts(
                confirmedPostIDs: confirmedTimelinePostIDs,
                timelineCursorExhausted: timelineCursorExhausted
            )
            : 0
        let insertedIncomingCount = incoming.count
        guard !incoming.isEmpty || didUpdateExisting || evictedStaleTrustedCount > 0 || evictedStaleUntrustedCount > 0 else {
            let summary = [
                "source=\(source.debugLabel)",
                "remote=\(remotePosts.count)",
                "inserted=0",
                "updated_existing=0",
                "updated_pending=0",
                "evicted_stale_trusted=0",
                "evicted_stale_untrusted=0",
                "acked_publish=\(acknowledgedPublishCount)",
                "local_posts=\(postsBefore)",
                "pending=\(pendingBefore)",
                "visible=\(visibleBefore)"
            ].joined(separator: ", ")
            updateFeedDebug(
                stage: "merge_\(source.debugLabel)_noop",
                status: "Remote posts already present",
                detail: summary,
                mergeSummary: summary,
                visibilitySummary: mainFeedVisibilitySummary()
            )
            return
        }
        if shouldBufferIncomingPosts {
            pendingRemotePosts.append(contentsOf: incoming)
            pendingRemotePosts = deduplicatedPosts(pendingRemotePosts)
            pendingRemotePosts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
            pendingFeedPostCount = pendingRemotePosts.count
            for item in pendingCirclePostNotifications {
                enqueueNotification(
                    type: .general,
                    title: "Circle post",
                    message: "Someone from your \(item.circleName) circle posted.",
                    digestKey: "circle_post:\(item.postID.uuidString):\(item.circleName.lowercased())",
                    actorKey: "circle_post_actor:\(item.author.id.uuidString)",
                    urgent: false,
                    actorID: item.author.id,
                    objectID: item.postID
                )
            }
            let mergeSummary = [
                "source=\(source.debugLabel)",
                "remote=\(remotePosts.count)",
                "inserted=\(insertedIncomingCount)",
                "updated_existing=\(updatedExistingCount)",
                "updated_pending=\(updatedPendingCount)",
                "evicted_stale_trusted=\(evictedStaleTrustedCount)",
                "evicted_stale_untrusted=\(evictedStaleUntrustedCount)",
                "acked_publish=\(acknowledgedPublishCount)",
                "local_posts=\(postsBefore)->\(posts.count)",
                "pending=\(pendingBefore)->\(pendingRemotePosts.count)",
                "visible=\(visibleBefore)->\(mainFeedPosts.count)",
                "buffer=on"
            ].joined(separator: ", ")
            updateFeedDebug(
                stage: "merge_\(source.debugLabel)_buffered",
                status: "Buffered remote posts",
                detail: mergeSummary,
                mergeSummary: mergeSummary,
                visibilitySummary: mainFeedVisibilitySummary()
            )
            if evictedStaleTrustedCount > 0 || evictedStaleUntrustedCount > 0 {
                saveState()
            }
            return
        }
        posts = deduplicatedPosts(posts + incoming)
        posts.removeAll { pendingDeletedPostIDs.contains($0.id) || ($0.rescrollOrigin.map { pendingDeletedPostIDs.contains($0.postID) } ?? false) }
        normalizeIdentityState()
        syncFollowDirectories()
        posts.sort { $0.timestamp > $1.timestamp }
        for item in pendingCirclePostNotifications {
            enqueueNotification(
                type: .general,
                title: "Circle post",
                message: "Someone from your \(item.circleName) circle posted.",
                digestKey: "circle_post:\(item.postID.uuidString):\(item.circleName.lowercased())",
                actorKey: "circle_post_actor:\(item.author.id.uuidString)",
                urgent: false,
                actorID: item.author.id,
                objectID: item.postID
            )
        }
        let mergeSummary = [
            "source=\(source.debugLabel)",
            "remote=\(remotePosts.count)",
            "inserted=\(insertedIncomingCount)",
            "updated_existing=\(updatedExistingCount)",
            "updated_pending=\(updatedPendingCount)",
            "evicted_stale_trusted=\(evictedStaleTrustedCount)",
            "evicted_stale_untrusted=\(evictedStaleUntrustedCount)",
            "acked_publish=\(acknowledgedPublishCount)",
            "local_posts=\(postsBefore)->\(posts.count)",
            "pending=\(pendingBefore)->\(pendingRemotePosts.count)",
            "visible=\(visibleBefore)->\(mainFeedPosts.count)",
            "buffer=off"
        ].joined(separator: ", ")
        updateFeedDebug(
            stage: "merge_\(source.debugLabel)_applied",
            status: "Applied remote posts",
            detail: mergeSummary,
            mergeSummary: mergeSummary,
            visibilitySummary: mainFeedVisibilitySummary()
        )
        saveState()
    }

    private func evictStaleUntrustedTimelinePosts(
        confirmedPostIDs: Set<UUID>,
        timelineCursorExhausted: Bool
    ) -> Int {
        // Only run this broader omission sweep when the feed window is complete.
        // If there is another cursor, a post may simply be outside the current page.
        guard timelineCursorExhausted, !confirmedPostIDs.isEmpty else { return 0 }

        let graceCutoff = Date().addingTimeInterval(-Self.feedTimelineEvictionGraceWindow)
        var candidatesByID: [UUID: FeedPost] = [:]
        for post in posts where candidatesByID[post.id] == nil {
            candidatesByID[post.id] = post
        }
        for post in pendingRemotePosts where candidatesByID[post.id] == nil {
            candidatesByID[post.id] = post
        }
        for post in deliveredAdPosts where candidatesByID[post.id] == nil {
            candidatesByID[post.id] = post
        }

        var evictablePostIDs = Set<UUID>()
        for (postID, post) in candidatesByID {
            guard !confirmedPostIDs.contains(postID) else { continue }
            guard !trustedTimelinePostIDs.contains(postID) else { continue }
            guard post.user.id != currentUser.id else { continue }
            guard postPublishDeliveryStates[postID] == nil else { continue }
            guard !isAdDesignatedPost(post) else { continue }
            guard post.timestamp < graceCutoff else { continue }
            evictablePostIDs.insert(postID)
        }

        guard !evictablePostIDs.isEmpty else { return 0 }
        posts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        pendingRemotePosts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        deliveredAdPosts.removeAll {
            evictablePostIDs.contains($0.id)
                || ($0.rescrollOrigin.map { evictablePostIDs.contains($0.postID) } ?? false)
        }
        pendingFeedPostCount = pendingRemotePosts.count
        normalizePinnedPosts()
        return evictablePostIDs.count
    }

    private func resolvedFeedPostTimestamp(
        remoteCreatedAt: Date,
        rescrollOrigin: RescrollOrigin?
    ) -> Date {
        guard let rescrollOrigin else { return remoteCreatedAt }
        if remoteCreatedAt <= rescrollOrigin.timestamp {
            return rescrollOrigin.timestamp.addingTimeInterval(1)
        }
        return remoteCreatedAt
    }

    private func mappedRescrollOrigin(from remote: BackendPost) -> RescrollOrigin? {
        guard let origin = remote.rescrollOrigin else { return nil }
        let originUser = roleAdjustedProfile(origin.user.asUserProfile)
        registerProfile(originUser, writeVersion: origin.user.writeVersion)

        // Defensive normalization for malformed backend rows that self-link an original post as a rescroll.
        if origin.postID == remote.id {
            return nil
        }
        let sameAuthorByID = originUser.id == remote.author.id
        let sameAuthorByUsername = normalizeUsername(originUser.username) == normalizeUsername(remote.author.username)
        if sameAuthorByID || sameAuthorByUsername {
            let timestampDelta = abs(origin.timestamp.timeIntervalSince(remote.createdAt))
            let sameCaption = normalizedTextForComparison(origin.caption) == normalizedTextForComparison(remote.caption)
            let sameWebsite = normalizedTextForComparison(origin.websiteURL) == normalizedTextForComparison(remote.websiteURL)
            if timestampDelta <= 2 || (timestampDelta <= 30 && sameCaption && sameWebsite) {
                return nil
            }
        }

        return RescrollOrigin(
            postID: origin.postID,
            user: originUser,
            caption: origin.caption,
            websiteURL: origin.websiteURL,
            timestamp: origin.timestamp
        )
    }

    private func isMalformedSelfRescroll(_ post: FeedPost) -> Bool {
        guard let origin = post.rescrollOrigin else { return false }
        if origin.postID == post.id {
            return true
        }
        let sameAuthorByID = origin.user.id == post.user.id
        let sameAuthorByUsername = normalizeUsername(origin.user.username) == normalizeUsername(post.user.username)
        guard sameAuthorByID || sameAuthorByUsername else { return false }
        let timestampDelta = abs(origin.timestamp.timeIntervalSince(post.timestamp))
        let sameCaption = normalizedTextForComparison(origin.caption) == normalizedTextForComparison(post.caption)
        let sameWebsite = normalizedTextForComparison(origin.websiteURL) == normalizedTextForComparison(post.websiteURL)
        return timestampDelta <= 2 || (timestampDelta <= 30 && sameCaption && sameWebsite)
    }

    private func normalizedTextForComparison(_ raw: String?) -> String {
        raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private func normalizedRescrollQuoteText(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(280))
    }

    private func totalCommentCount(in comments: [PostComment]) -> Int {
        comments.reduce(0) { subtotal, comment in
            subtotal + 1 + totalCommentCount(in: comment.replies)
        }
    }

    private func newestCommentTimestamp(in comments: [PostComment]) -> Date {
        var newest = Date.distantPast
        func walk(_ items: [PostComment]) {
            for item in items {
                if item.timestamp > newest {
                    newest = item.timestamp
                }
                if !item.replies.isEmpty {
                    walk(item.replies)
                }
            }
        }
        walk(comments)
        return newest
    }

    private func replacingComments(in post: FeedPost, with comments: [PostComment]) -> FeedPost {
        guard post.comments != comments else { return post }
        return FeedPost(
            id: post.id,
            user: post.user,
            caption: post.caption,
            websiteURL: post.websiteURL,
            locationCity: post.locationCity,
            timestamp: post.timestamp,
            mediaPreview: post.mediaPreview,
            coverImageRef: post.coverImageRef,
            coverProvider: post.coverProvider,
            coverBucket: post.coverBucket,
            coverObjectKey: post.coverObjectKey,
            comments: comments,
            rescrollOrigin: post.rescrollOrigin,
            rescrollQuoteText: post.rescrollQuoteText
        )
    }

    private func preferredDuplicatePost(existing: FeedPost, incoming: FeedPost) -> FeedPost {
        let base = incoming.timestamp >= existing.timestamp ? incoming : existing
        let existingCommentCount = totalCommentCount(in: existing.comments)
        let incomingCommentCount = totalCommentCount(in: incoming.comments)

        if incomingCommentCount > existingCommentCount {
            return replacingComments(in: base, with: incoming.comments)
        }
        if existingCommentCount > incomingCommentCount {
            return replacingComments(in: base, with: existing.comments)
        }

        let existingNewestComment = newestCommentTimestamp(in: existing.comments)
        let incomingNewestComment = newestCommentTimestamp(in: incoming.comments)
        if incomingNewestComment > existingNewestComment {
            return replacingComments(in: base, with: incoming.comments)
        }
        if existingNewestComment > incomingNewestComment {
            return replacingComments(in: base, with: existing.comments)
        }
        return base
    }

    private func deduplicatedPosts(_ source: [FeedPost]) -> [FeedPost] {
        var orderedIDs: [UUID] = []
        var mergedByID: [UUID: FeedPost] = [:]

        for post in source {
            if let existing = mergedByID[post.id] {
                mergedByID[post.id] = preferredDuplicatePost(existing: existing, incoming: post)
            } else {
                orderedIDs.append(post.id)
                mergedByID[post.id] = post
            }
        }

        return orderedIDs.compactMap { mergedByID[$0] }
    }

    private func shouldPreservePendingLocalComment(_ commentID: UUID) -> Bool {
        guard let trace = commentDeliveryTraces[commentID],
              let localAt = trace.localAt,
              trace.backendAckAt == nil else {
            return false
        }
        return Date().timeIntervalSince(localAt) <= CommentSyncCostSaverMode.pendingPreservationWindow
    }

    private func mergeRemoteCommentsPreservingPending(
        remote mappedRemote: [PostComment],
        local localComments: [PostComment]
    ) -> [PostComment] {
        struct PendingNode {
            let comment: PostComment
            let parentID: UUID?
        }

        var pendingNodes: [PendingNode] = []
        func collectPending(from comments: [PostComment], parentID: UUID?) {
            for comment in comments {
                if shouldPreservePendingLocalComment(comment.id) {
                    pendingNodes.append(PendingNode(comment: comment, parentID: parentID))
                }
                if !comment.replies.isEmpty {
                    collectPending(from: comment.replies, parentID: comment.id)
                }
            }
        }

        func insertReply(
            _ reply: PostComment,
            under parentID: UUID,
            in comments: inout [PostComment]
        ) -> Bool {
            for index in comments.indices {
                if comments[index].id == parentID {
                    if !comments[index].replies.contains(where: { $0.id == reply.id }) {
                        comments[index].replies.append(reply)
                    }
                    return true
                }
                if insertReply(reply, under: parentID, in: &comments[index].replies) {
                    return true
                }
            }
            return false
        }

        collectPending(from: localComments, parentID: nil)
        var merged = mappedRemote
        if !pendingNodes.isEmpty {
            var mergedIDs = commentIDs(in: merged)
            for node in pendingNodes {
                if mergedIDs.contains(node.comment.id) { continue }
                if let parentID = node.parentID,
                   insertReply(node.comment, under: parentID, in: &merged) {
                    mergedIDs.insert(node.comment.id)
                    continue
                }
                merged.append(node.comment)
                mergedIDs.insert(node.comment.id)
            }
        }

        var pendingLikeOperationsByCommentID: [UUID: Bool] = [:]
        for operation in pendingBackendWriteQueue where operation.userID == currentUser.id {
            guard let commentID = operation.commentID else { continue }
            switch operation.kind {
            case .commentLikeCreate:
                pendingLikeOperationsByCommentID[commentID] = true
            case .commentLikeDelete:
                pendingLikeOperationsByCommentID[commentID] = false
            default:
                break
            }
        }

        func applyLikeOverridesAndReconcile(to comments: inout [PostComment]) {
            for index in comments.indices {
                let commentID = comments[index].id
                let remoteHasCurrentUserLike = comments[index].likedBy.contains(currentUser.id)
                let remoteLikeCount = comments[index].likedBy.count
                let remoteLikePreview = comments[index].likedBy
                    .prefix(4)
                    .map { String($0.uuidString.prefix(8)) }
                    .joined(separator: ",")
                let pendingDesiredLike = pendingLikeOperationsByCommentID[commentID]
                let overrideState = commentLikeOverrides[commentID]
                let hasLocalOverride = overrideState != nil
                let hasPendingOperation = pendingDesiredLike != nil
                let remotePreviewLabel = remoteLikePreview.isEmpty ? "none" : remoteLikePreview
                let remoteHasCurrentUserLikeLabel = remoteHasCurrentUserLike ? "yes" : "no"
                let localOverridePresentLabel = hasLocalOverride ? "yes" : "no"
                let pendingOperationPresentLabel = hasPendingOperation ? "yes" : "no"
                if hasLocalOverride || hasPendingOperation {
                    let localOverrideDesiredLabel = overrideState.map { $0.isLiked ? "liked" : "unliked" } ?? "none"
                    let pendingOperationDesiredLabel: String
                    if let pendingDesiredLike {
                        pendingOperationDesiredLabel = pendingDesiredLike ? "liked" : "unliked"
                    } else {
                        pendingOperationDesiredLabel = "none"
                    }
                    updateCommentLikeDebug(
                        commentID: commentID,
                        stage: "comment_like_merge_observed",
                        status: "Observed remote comment-like state during merge",
                        detail: "remote_like_count=\(remoteLikeCount), remote_has_current_user_like=\(remoteHasCurrentUserLikeLabel), local_override_present=\(localOverridePresentLabel), local_override_desired=\(localOverrideDesiredLabel), pending_operation_present=\(pendingOperationPresentLabel), pending_operation_desired=\(pendingOperationDesiredLabel), remote_like_preview=\(remotePreviewLabel)"
                    )
                }

                if let state = overrideState {
                    let localAgeMS = Int(Date().timeIntervalSince(state.localUpdatedAt) * 1000)
                    let desiredLabel = state.isLiked ? "liked" : "unliked"
                    let remoteLabel = remoteHasCurrentUserLike ? "liked" : "unliked"
                    let previewLabel = remoteLikePreview.isEmpty ? "none" : remoteLikePreview
                    let pendingLabel = pendingDesiredLike == nil ? "no" : "yes"

                    if remoteHasCurrentUserLike == state.isLiked {
                        if state.backendAckAt != nil {
                            updateCommentLikeDebug(
                                commentID: commentID,
                                stage: "comment_like_remote_reconciled_after_ack",
                                status: "Remote comment-like state reconciled",
                                detail: "desired=\(desiredLabel), remote=\(remoteLabel), remote_like_count=\(remoteLikeCount), remote_like_preview=\(previewLabel), local_age_ms=\(localAgeMS), pending_override=\(pendingLabel)"
                            )
                        }
                        commentLikeOverrides.removeValue(forKey: commentID)
                    } else if state.backendAckAt != nil {
                        let now = Date()
                        let shouldLogMismatch: Bool
                        if let last = state.lastMismatchLoggedAt {
                            shouldLogMismatch = now.timeIntervalSince(last) >= Self.commentLikeMismatchLogInterval
                        } else {
                            shouldLogMismatch = true
                        }
                        if shouldLogMismatch {
                            var updated = state
                            updated.lastMismatchLoggedAt = now
                            commentLikeOverrides[commentID] = updated
                            let ackAgeMS = Int(now.timeIntervalSince(state.backendAckAt ?? now) * 1000)
                            updateCommentLikeDebug(
                                commentID: commentID,
                                stage: "comment_like_remote_mismatch_after_ack",
                                status: "Remote comment-like state is stale after backend ack",
                                detail: "Keeping local override active until backend comments payload matches. desired=\(desiredLabel), remote=\(remoteLabel), remote_like_count=\(remoteLikeCount), remote_like_preview=\(previewLabel), ack_age_ms=\(ackAgeMS), local_age_ms=\(localAgeMS), pending_override=\(pendingLabel)"
                            )
                        }
                    }
                }

                let desiredLike = pendingDesiredLike ?? commentLikeOverrides[commentID]?.isLiked
                if let shouldLike = desiredLike {
                    if shouldLike {
                        if !comments[index].likedBy.contains(currentUser.id) {
                            comments[index].likedBy.append(currentUser.id)
                        }
                    } else {
                        comments[index].likedBy.removeAll(where: { $0 == currentUser.id })
                    }
                }

                if !comments[index].replies.isEmpty {
                    applyLikeOverridesAndReconcile(to: &comments[index].replies)
                }
            }
        }

        applyLikeOverridesAndReconcile(to: &merged)
        return merged
    }

    private func mergeRemoteComments(_ remoteComments: [BackendComment], into postID: UUID) {
        let mapped = remoteComments.map(mapBackendComment)
        markRemoteSeenForTrackedComments(mapped)
        let targetIndices = commentThreadIndices(forCanonicalPostID: postID, fallbackPostID: postID)
        guard !targetIndices.isEmpty else { return }
        var didChange = false
        for index in targetIndices where posts.indices.contains(index) {
            let mergedComments = mergeRemoteCommentsPreservingPending(
                remote: mapped,
                local: posts[index].comments
            )
            if posts[index].comments != mergedComments {
                posts[index].comments = mergedComments
                didChange = true
            }
        }
        if didChange {
            saveState()
        }
    }

    private func orderedUniqueRecentCommentThreadPostIDs(limit: Int) -> [UUID] {
        guard limit > 0 else { return [] }
        var output: [UUID] = []
        var seen = Set<UUID>()
        for post in posts {
            let canonicalID = canonicalCommentThreadPostID(for: post)
            if seen.insert(canonicalID).inserted {
                output.append(canonicalID)
            }
            if output.count >= limit {
                break
            }
        }
        return output
    }

    private func mergeRemoteNotifications(_ remoteNotifications: [BackendNotification]) {
        mergeRemoteNotificationsPage(remoteNotifications, nextCursor: notificationNextCursorByUserID[currentUser.id] ?? nil, append: false)
    }

    private func mergeRemoteNotificationsPage(
        _ remoteNotifications: [BackendNotification],
        nextCursor: String?,
        append: Bool
    ) {
        let previousUnread = notifications.filter { !$0.isRead }.count
        let locallyReadIDs = Set(notifications.filter(\.isRead).map(\.id))
        let incoming = remoteNotifications
            .filter { remote in
                guard let recipientID = remote.userID else { return false }
                return recipientID == currentUser.id
            }
            .map { remote in
            AppNotification(
                id: remote.id,
                type: AppNotification.NotificationType(rawValue: remote.type) ?? .general,
                title: remote.title,
                message: remote.message,
                timestamp: remote.createdAt,
                isRead: remote.isRead || locallyReadIDs.contains(remote.id),
                recipientUserID: remote.userID,
                actorID: remote.actorID,
                objectID: remote.objectID
            )
        }
        let mapped: [AppNotification]
        if append {
            var mergedByID = Dictionary(uniqueKeysWithValues: notifications.map { ($0.id, $0) })
            for notification in incoming {
                if let existing = mergedByID[notification.id], existing.isRead {
                    var updated = notification
                    updated.isRead = true
                    mergedByID[notification.id] = updated
                } else {
                    mergedByID[notification.id] = notification
                }
            }
            mapped = mergedByID.values.sorted(by: { $0.timestamp > $1.timestamp })
        } else {
            mapped = incoming.sorted(by: { $0.timestamp > $1.timestamp })
        }
        notificationNextCursorByUserID[currentUser.id] = nextCursor
        guard mapped != notifications else { return }
        notifications = mapped
        if !append {
            cachedNotifications = SyncCacheEntry(ownerUserID: currentUser.id, value: remoteNotifications, fetchedAt: Date())
        }
        saveState()
#if canImport(UIKit)
        let nextUnread = notifications.filter { !$0.isRead }.count
        scheduleBackgroundInboxAlertIfNeeded(previousUnreadCount: previousUnread, nextUnreadCount: nextUnread)
#endif
    }

private func mergeRemoteCircles(_ remoteCircles: [BackendCircle]) {
    let sharedPosts = remoteCircles.flatMap { circle in
        circle.messages.compactMap(\.sharedPost)
    }
    if !sharedPosts.isEmpty {
        mergeRemotePosts(sharedPosts, source: .circleSharedPost)
    }

    let previousCircles = circles
    let previousUnread = unreadCircleMessageIDs
    let previousMessageCount = previousCircles.reduce(0) { $0 + $1.messages.count }
    let remoteMessageCount = remoteCircles.reduce(0) { $0 + $1.messages.count }
    let remoteMapped = filterListenedCircleVoiceMessages(in: remoteCircles.map(mapBackendCircle))
        .sorted { $0.createdAt > $1.createdAt }
        var localByID = Dictionary(uniqueKeysWithValues: circles.map { ($0.id, $0) })
        var merged: [CircleGroup] = []

        for remote in remoteMapped {
            guard let local = localByID.removeValue(forKey: remote.id) else {
                merged.append(remote)
                continue
            }
            var messagesByID: [UUID: CircleMessage] = [:]
            for message in local.messages {
                messagesByID[message.id] = message
            }
            for message in remote.messages {
                if let existing = messagesByID[message.id] {
                    if message.timestamp > existing.timestamp {
                        messagesByID[message.id] = message
                    }
                } else {
                    messagesByID[message.id] = message
                }
            }
            var combined = remote
            combined.messages = messagesByID.values.sorted { $0.timestamp < $1.timestamp }
            let hasRemoteAvatarData = combined.avatarImageData != nil
            let hasRemoteAvatarRef = !(combined.avatarRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasRemoteAvatarData && !hasRemoteAvatarRef {
                combined.avatarImageData = local.avatarImageData
                combined.avatarRef = local.avatarRef
            }
            merged.append(combined)
        }

        // Preserve local-only circles until backend acknowledges them.
        merged.append(contentsOf: localByID.values.filter { circle in
            circle.members.contains(where: { $0.profileID == currentUser.id })
        })

let mapped = filterListenedCircleVoiceMessages(in: mergedOneOnOneCircles(merged))
    .sorted { $0.createdAt > $1.createdAt }
let mergedMessageCount = mapped.reduce(0) { $0 + $1.messages.count }
if mapped == circles {
    updateFeedDebug(
        stage: "circles_merge_noop",
        status: "Circles merge produced no changes",
        detail: "remote_circles=\(remoteCircles.count), remote_messages=\(remoteMessageCount), local_circles=\(previousCircles.count), local_messages=\(previousMessageCount)"
    )
    return
}
        let previousMessageIDs = Set(previousCircles.flatMap { $0.messages.map(\.id) })
        let nextMessageByID = Dictionary(uniqueKeysWithValues: mapped.flatMap { $0.messages }.map { ($0.id, $0) })
        let nextMessageIDs = Set(nextMessageByID.keys)
        let preservedUnread = Set(
            previousUnread.filter { messageID in
                guard let message = nextMessageByID[messageID] else { return false }
                return message.userID != currentUser.id
            }
        )
        let newIncomingIDs = nextMessageIDs
            .subtracting(previousMessageIDs)
            .filter { messageID in
                guard let message = nextMessageByID[messageID] else { return false }
                return message.userID != currentUser.id
            }
        let newIncomingUnread = Set(newIncomingIDs)
circles = mapped
unreadCircleMessageIDs = preservedUnread.union(newIncomingUnread)
saveState()
        // Notify for each newly received circle message so the badge and in-app
        // notification bell update even when the user is not on the circles tab.
        if !newIncomingIDs.isEmpty {
            let circleByMessageID: [UUID: CircleGroup] = mapped.reduce(into: [:]) { result, circle in
                for message in circle.messages {
                    result[message.id] = circle
                }
            }
            for messageID in newIncomingIDs {
                guard let message = nextMessageByID[messageID],
                      let circle = circleByMessageID[messageID] else { continue }
                let senderProfile = profile(for: message.userID)
                let senderName = senderProfile?.displayName ?? senderProfile?.username ?? "Someone"
                let circleLabel = circle.isOneOnOneConversation ? senderName : circle.name
                let plainText = decryptedCircleMessageText(message, in: circle.id)
                let body: String
                if message.hasVoiceAttachment {
                    body = "Sent a voice message"
                } else if message.hasPhotoAttachment {
                    body = "Sent a photo message"
                } else if !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    body = plainText
                } else if message.sharedPostID != nil {
                    body = "Shared a scroll"
                } else {
                    body = "Sent a message"
                }
                let notificationType: AppNotification.NotificationType
                if message.hasVoiceAttachment {
                    notificationType = .circleVoiceMessage
                } else if message.hasPhotoAttachment {
                    notificationType = .circleMessage
                } else if message.sharedPostID != nil {
                    notificationType = .circleSharedPost
                } else {
                    notificationType = .circleMessage
                }
                enqueueNotification(
                    type: notificationType,
                    title: circleLabel,
                    message: "\(circle.isOneOnOneConversation ? "" : "\(senderName): ")\(body)",
                    digestKey: "circle_msg:\(circle.id.uuidString)",
                    actorKey: "circle_msg_actor:\(message.userID.uuidString)",
                    urgent: false,
                    actorID: message.userID,
                    objectID: circle.id
                )
            }
        }
updateFeedDebug(
    stage: "circles_merge_success",
    status: "Circles merged",
    detail: "remote_circles=\(remoteCircles.count), remote_messages=\(remoteMessageCount), merged_circles=\(mapped.count), merged_messages=\(mergedMessageCount), unread=\(unreadCircleMessageIDs.count)"
)
    }

    private func mergedOneOnOneCircles(_ source: [CircleGroup]) -> [CircleGroup] {
        var output: [CircleGroup] = []
        var usedIDs = Set<UUID>()
        var buckets: [String: [CircleGroup]] = [:]

        for circle in source {
            let relevantMemberIDs = circle.members
                .filter { $0.status != .declined }
                .map(\.profileID)
            let activeMemberIDs = circle.members
                .filter { $0.status == .member }
                .map(\.profileID)
            guard Set(relevantMemberIDs).count == 2, Set(activeMemberIDs).count == 2 else { continue }
            let key = Set(relevantMemberIDs)
                .map { $0.uuidString.lowercased() }
                .sorted()
                .joined(separator: ":")
            buckets[key, default: []].append(circle)
        }

        for circlesForPair in buckets.values {
            guard circlesForPair.count > 1 else { continue }
            let ranked = circlesForPair.sorted { lhs, rhs in
                if lhs.messages.count != rhs.messages.count {
                    return lhs.messages.count > rhs.messages.count
                }
                let lhsLast = lhs.messages.last?.timestamp ?? .distantPast
                let rhsLast = rhs.messages.last?.timestamp ?? .distantPast
                if lhsLast != rhsLast {
                    return lhsLast > rhsLast
                }
                return lhs.createdAt < rhs.createdAt
            }
            guard var merged = ranked.first else { continue }

            var membersByProfileID: [UUID: CircleMember] = [:]
            for circle in ranked {
                for member in circle.members {
                    if let existing = membersByProfileID[member.profileID] {
                        if membershipRank(member.status) > membershipRank(existing.status) {
                            membersByProfileID[member.profileID] = member
                        }
                    } else {
                        membersByProfileID[member.profileID] = member
                    }
                }
            }

            var messagesByID: [UUID: CircleMessage] = [:]
            for circle in ranked {
                for message in circle.messages {
                    if let existing = messagesByID[message.id] {
                        if message.timestamp > existing.timestamp {
                            messagesByID[message.id] = message
                        }
                    } else {
                        messagesByID[message.id] = message
                    }
                }
            }

            merged.members = membersByProfileID.values.sorted { $0.profileID.uuidString < $1.profileID.uuidString }
            merged.messages = messagesByID.values.sorted { $0.timestamp < $1.timestamp }
            output.append(merged)
            usedIDs.formUnion(ranked.map(\.id))
        }

        output.append(contentsOf: source.filter { !usedIDs.contains($0.id) })
        return output
    }

    private func membershipRank(_ status: CircleMemberStatus) -> Int {
        switch status {
        case .member:
            return 3
        case .invited:
            return 2
        case .pending:
            return 1
        case .declined:
            return 0
        }
    }

    private func mergeRemoteFollowing(_ users: [BackendUser]) {
        registerProfiles(from: users, applyRoleAdjustment: true)
        let profiles = users.map { roleAdjustedProfile($0.asUserProfile) }
        let remoteFolloweeIDs = Set(profiles.map(\.id))
        let existingFolloweeIDs = followRelations[currentUser.id] ?? []
        var requiredFolloweeIDs = mandatoryFollowIDs()
        requiredFolloweeIDs.remove(currentUser.id)
        // Guard against transient backend/account-switch mismatches wiping local follow state to empty.
        var resolvedFolloweeIDs: Set<UUID>
        if remoteFolloweeIDs.isEmpty && !existingFolloweeIDs.isEmpty {
            resolvedFolloweeIDs = existingFolloweeIDs.union(requiredFolloweeIDs)
        } else {
            resolvedFolloweeIDs = remoteFolloweeIDs.union(requiredFolloweeIDs)
        }

        pendingOutgoingFollowRequestIDs.subtract(resolvedFolloweeIDs)
        if followRelations[currentUser.id] != resolvedFolloweeIDs {
            followRelations[currentUser.id] = resolvedFolloweeIDs
            invalidateCachesForFollowGraphMutation()
            syncFollowDirectories()
            saveState()
        }
    }

    private func mergeRemoteFollowers(_ users: [BackendUser]) {
        registerProfiles(from: users, applyRoleAdjustment: true)
        let profiles = users.map { roleAdjustedProfile($0.asUserProfile) }
        let followerIDs = Set(profiles.map(\.id))
        var changed = false
        let allKnownIDs = Set(followRelations.keys).union(profileRegistry.keys)
        for userID in allKnownIDs {
            var follows = followRelations[userID] ?? []
            if follows.contains(currentUser.id), !followerIDs.contains(userID) {
                follows.remove(currentUser.id)
                followRelations[userID] = follows
                changed = true
            }
        }
        for profile in profiles {
            var follows = followRelations[profile.id] ?? []
            if !follows.contains(currentUser.id) {
                follows.insert(currentUser.id)
                followRelations[profile.id] = follows
                changed = true
            }
        }
        if changed {
            invalidateCachesForFollowGraphMutation()
            syncFollowDirectories()
            saveState()
        }
    }

    private func mergeRemoteAdSubmissions(_ submissions: [BackendAdSubmission]) {
        let ownSubmissions = submissions.filter { $0.businessUserID == currentUser.id }
        let map = Dictionary(uniqueKeysWithValues: ownSubmissions.map { ($0.postID, $0) })
        let preservedDirectCuratedIDs = Set(curatedAdSlotIDs.compactMap { $0 })
            .union(deliveredAdPosts.map(\.id))
            .intersection(Set(posts.map(\.id)))
        let mergedIDs = Set(map.keys).union(preservedDirectCuratedIDs)
        guard map != adSubmissionsByPostID || mergedIDs != adSubmissionPostIDs else { return }
        adSubmissionsByPostID = map
        adSubmissionPostIDs = mergedIDs
        saveState()
    }

    private func mergeDeliveredAds(_ deliveryItems: [BackendAdDeliveryItem]) {
        let mapped = Array(deliveryItems.compactMap(mapDeliveredAdPost).prefix(Self.maxCuratedAdCount))
        guard mapped != deliveredAdPosts else { return }
        deliveredAdPosts = mapped
    }

    private func mapDeliveredAdPost(_ item: BackendAdDeliveryItem) -> FeedPost? {
        let post = item.post
        let backendBusinessUser = item.businessUser
        let existingPost = posts.first(where: { $0.id == post.id })
        let user = backendBusinessUser?.asUserProfile
            ?? profileRegistry[item.submission.businessUserID]
            ?? existingPost?.user
        guard let user else { return nil }
        registerProfile(user, writeVersion: backendBusinessUser.flatMap { $0.writeVersion })
        return FeedPost(
            id: post.id,
            user: user,
            caption: post.caption,
            websiteURL: post.websiteURL,
            locationCity: post.locationCity,
            timestamp: post.createdAt,
            mediaPreview: post.asMediaPreview,
            coverImageRef: post.coverImageRef ?? existingPost?.coverImageRef,
            coverProvider: existingPost?.coverProvider,
            coverBucket: existingPost?.coverBucket,
            coverObjectKey: existingPost?.coverObjectKey,
            comments: existingPost?.comments ?? [],
            rescrollOrigin: nil
        )
    }

    private func mapBackendComment(_ comment: BackendComment) -> PostComment {
        let author = comment.author.asUserProfile
        registerProfile(author, writeVersion: comment.author.writeVersion)
        return PostComment(
            id: comment.id,
            user: author,
            text: comment.body,
            timestamp: comment.createdAt,
            replies: comment.replies.map(mapBackendComment),
            likedBy: comment.likedBy
        )
    }

    private func mapBackendCircle(_ circle: BackendCircle) -> CircleGroup {
        let remoteAvatarData = circle.avatarRef.flatMap { Data(base64Encoded: $0) }
        let members = circle.members.map { member in
            let profile = member.user.asUserProfile
            registerProfile(profile, writeVersion: member.user.writeVersion)
            return CircleMember(
                id: member.id,
                profileID: profile.id,
                status: CircleMemberStatus(rawValue: member.status) ?? .invited
            )
        }

        let messages = circle.messages.map { message in
            let profile = message.user.asUserProfile
            registerProfile(profile, writeVersion: message.user.writeVersion)
            return CircleMessage(
                id: message.id,
                userID: profile.id,
                encryptedText: message.encryptedText,
                timestamp: message.createdAt,
                sharedPostID: message.sharedPostID,
                voiceProvider: message.voiceProvider,
                voiceBucket: message.voiceBucket,
                voiceObjectKey: message.voiceObjectKey,
                voiceDurationSeconds: message.voiceDurationSeconds,
                photoProvider: message.photoProvider,
                photoBucket: message.photoBucket,
                photoObjectKey: message.photoObjectKey,
                photoContentType: message.photoContentType,
                photoWidth: message.photoWidth,
                photoHeight: message.photoHeight,
                expiresAt: message.expiresAt
            )
        }

        return CircleGroup(
            id: circle.id,
            name: circle.name,
            avatarImageData: remoteAvatarData,
            avatarRef: remoteAvatarData == nil ? circle.avatarRef : nil,
            members: members,
            messages: messages,
            createdAt: circle.createdAt
        )
    }

    private func pushCirclesToBackend() async {
        guard backendClient.isEnabled else { return }
        let targetCircleIDs = dirtyCircleIDs
        guard !targetCircleIDs.isEmpty else { return }

        let circlesByID = Dictionary(uniqueKeysWithValues: circles.map { ($0.id, $0) })
        let circlesToSync = targetCircleIDs.compactMap { circlesByID[$0] }
            .filter { circle in circle.members.contains(where: { $0.profileID == currentUser.id }) }
        guard !circlesToSync.isEmpty else {
            dirtyCircleIDs.subtract(targetCircleIDs)
            return
        }

        _ = await BackendTruthSyncCore.ensureActiveSession(
            for: resolvedBackendSessionUsername(),
            expectedUserID: currentUser.id,
            using: backendClient,
            preferRefresh: true
        )
        restoreBackendAuthTokenForCurrentUserIfNeeded()

        for circle in circlesToSync {
            guard !Task.isCancelled else { return }
            do {
                try await backendClient.upsertCircle(circle)
                dirtyCircleIDs.remove(circle.id)
            } catch {
                // Keep local state; next batch sync will retry.
            }
        }
        cachedCircles = nil
    }

    private func removeSeedDataIfNeeded() {
        let seededIDs = Set(profileRegistry.values.filter { Self.seededUsernames.contains(normalizeUsername($0.username)) }.map(\.id))
        guard !seededIDs.isEmpty else { return }

        profileRegistry = profileRegistry.filter { !seededIDs.contains($0.key) }

        posts.removeAll { post in
            seededIDs.contains(post.user.id) || (post.rescrollOrigin.map { seededIDs.contains($0.user.id) } ?? false)
        }

        followRelations = followRelations.reduce(into: [UUID: Set<UUID>]()) { partial, entry in
            guard !seededIDs.contains(entry.key) else { return }
            let filtered = Set(entry.value.filter { !seededIDs.contains($0) && $0 != entry.key })
            partial[entry.key] = filtered
        }

        circles = circles.compactMap { circle in
            var updated = circle
            updated.members.removeAll { seededIDs.contains($0.profileID) }
            updated.messages.removeAll { seededIDs.contains($0.userID) }
            return updated.members.isEmpty ? nil : updated
        }

        following.removeAll { seededIDs.contains($0.id) }
        followers.removeAll { seededIDs.contains($0.id) }
    }

    private func ensureFounderAccountExists() {
        let canonicalFounderID = Self.founderCanonicalAccount.id
        let founderUsername = normalizeUsername(Self.founderCanonicalAccount.username)

        if let existing = founderProfile {
            if existing.id == canonicalFounderID {
                if !existing.isFounder || !existing.isVerified {
                    registerProfile(existing.with(isVerified: true, isFounder: true))
                }
                return
            }

            profileRegistry.removeValue(forKey: existing.id)
            followRelations = followRelations.reduce(into: [UUID: Set<UUID>]()) { partial, pair in
                let mappedKey = pair.key == existing.id ? canonicalFounderID : pair.key
                var mappedValues = Set<UUID>()
                for value in pair.value {
                    mappedValues.insert(value == existing.id ? canonicalFounderID : value)
                }
                var existingValues = partial[mappedKey] ?? []
                existingValues.formUnion(mappedValues.filter { $0 != mappedKey })
                partial[mappedKey] = existingValues
            }
        }

        if currentUser.id == canonicalFounderID || normalizeUsername(currentUser.username) == founderUsername {
            let upgradedCurrent = currentUser.with(
                username: Self.founderCanonicalAccount.username,
                isVerified: true,
                isFounder: true
            )
            registerProfile(upgradedCurrent)
            if currentUser.id == canonicalFounderID {
                currentUser = upgradedCurrent
            }
            return
        }

        if let existingByID = profileRegistry[canonicalFounderID] {
            if !existingByID.isFounder || !existingByID.isVerified {
                registerProfile(existingByID.with(isVerified: true, isFounder: true))
            }
            return
        }

        registerProfile(
            UserProfile(
                id: canonicalFounderID,
                username: Self.founderCanonicalAccount.username,
                displayName: Self.founderCanonicalAccount.displayName,
                bio: "",
                keywords: [],
                gradientSpec: Self.gradientSpec(for: [.systemPink, .systemPurple]),
                avatarImageData: nil,
                isVerified: true,
                isFounder: true,
                accountType: .personal,
                websiteURL: "",
                businessLocation: "",
                businessPhone: "",
                homeCity: ""
            )
        )
    }

    private func ensureFounderManagedBusinessAccountsExist() {
        for entry in Self.founderManagedBusinessAccounts {
            let exists = profileRegistry.values.contains { normalizeUsername($0.username) == normalizeUsername(entry.username) }
            if exists { continue }
            let snapshot = Self.loadProfileSnapshot(username: entry.username)
            registerProfile(
                UserProfile(
                    id: entry.id,
                    username: entry.username,
                    displayName: entry.displayName,
                    bio: snapshot?.bio ?? "",
                    keywords: snapshot?.keywords ?? [],
                    gradientSpec: snapshot?.gradientSpec ?? Self.gradientSpec(for: [.systemTeal, .systemBlue]),
                    avatarImageData: snapshot?.avatarImageData,
                    isVerified: true,
                    isFounder: false,
                    accountType: .business,
                    websiteURL: snapshot?.websiteURL ?? "",
                    businessLocation: snapshot?.businessLocation ?? ""
                )
            )
        }
    }

    private func purgeLegacyLoserProfileDataIfNeeded() {
        let loserUsername = "loserprofile"
        let loserProfiles = profileRegistry.values.filter { normalizeUsername($0.username) == loserUsername }
        guard !loserProfiles.isEmpty else { return }
        let loserIDs = Set(loserProfiles.map(\.id))

        profileRegistry = profileRegistry.filter { !loserIDs.contains($0.key) }
        posts.removeAll { post in
            loserIDs.contains(post.user.id) || (post.rescrollOrigin.map { loserIDs.contains($0.user.id) } ?? false)
        }
        pendingRemotePosts.removeAll { post in
            loserIDs.contains(post.user.id) || (post.rescrollOrigin.map { loserIDs.contains($0.user.id) } ?? false)
        }
        deliveredAdPosts.removeAll { post in
            loserIDs.contains(post.user.id) || (post.rescrollOrigin.map { loserIDs.contains($0.user.id) } ?? false)
        }

        followRelations = followRelations.reduce(into: [UUID: Set<UUID>]()) { partial, entry in
            guard !loserIDs.contains(entry.key) else { return }
            partial[entry.key] = Set(entry.value.filter { !loserIDs.contains($0) && $0 != entry.key })
        }
        circles = circles.compactMap { circle in
            var updated = circle
            updated.members.removeAll { loserIDs.contains($0.profileID) }
            updated.messages.removeAll { loserIDs.contains($0.userID) }
            return updated.members.isEmpty ? nil : updated
        }
        following.removeAll { loserIDs.contains($0.id) }
        followers.removeAll { loserIDs.contains($0.id) }
        normalizePinnedPosts()
        pendingFeedPostCount = pendingRemotePosts.count
    }

    private func mandatoryFollowIDs() -> Set<UUID> {
        var required = Set<UUID>()
        if let founder = founderProfile {
            required.insert(founder.id)
        } else {
            required.insert(Self.founderCanonicalAccount.id)
        }
        for entry in Self.founderManagedBusinessAccounts {
            if let profile = profileRegistry.values.first(where: { normalizeUsername($0.username) == normalizeUsername(entry.username) }) {
                required.insert(profile.id)
            } else {
                required.insert(entry.id)
            }
        }
        return required
    }

    private func enforceMandatoryFounderFollows() {
        let mandatoryIDs = mandatoryFollowIDs()
        guard !mandatoryIDs.isEmpty else { return }
        var follows = followRelations[currentUser.id] ?? []
        for requiredID in mandatoryIDs where requiredID != currentUser.id {
            follows.insert(requiredID)
        }
        followRelations[currentUser.id] = follows
    }

    // MARK: - Moments

    var canPostMomentToday: Bool {
        let calendar = Calendar.current
        let todayCount = moments.filter {
            $0.userID == currentUser.id && calendar.isDateInToday($0.createdAt)
        }.count
        return todayCount < 3
    }

    var todayMomentCount: Int {
        let calendar = Calendar.current
        return moments.filter {
            $0.userID == currentUser.id && calendar.isDateInToday($0.createdAt)
        }.count
    }

    func canCommentOnMomentViaCircles(_ moment: Moment) -> Bool {
        let normalizedMomentUsername = normalizeUsername(moment.username)
        let normalizedCurrentUsername = normalizeUsername(currentUser.username)
        guard moment.userID != currentUser.id,
              normalizedMomentUsername != normalizedCurrentUsername,
              let recipient = resolvedMomentCommentRecipient(for: moment, registerFallback: false) else {
            return false
        }
        return canAddToCircleChats(recipient)
    }

    @discardableResult
    func sendMomentComment(_ text: String, for moment: Moment) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalizedMomentUsername = normalizeUsername(moment.username)
        let normalizedCurrentUsername = normalizeUsername(currentUser.username)
        guard moment.userID != currentUser.id,
              normalizedMomentUsername != normalizedCurrentUsername else {
            moderationErrorMessage = "Comments on your own moments stay in your own circle inbox."
            return false
        }
        guard let recipient = resolvedMomentCommentRecipient(for: moment, registerFallback: true) else {
            moderationErrorMessage = "Couldn't resolve this moment owner for circle messaging."
            return false
        }
        guard canAddToCircleChats(recipient) else {
            moderationErrorMessage = "You can comment on moments through circles only with mutual followers."
            return false
        }
        guard let circle = ensureOneOnOneCircle(with: recipient) else {
            moderationErrorMessage = "Couldn't open a one-on-one circle for this moment."
            return false
        }
        sendMessage(text: "Moment comment: \(trimmed)", in: circle)
        return true
    }

    private func resolvedMomentCommentRecipient(for moment: Moment, registerFallback: Bool) -> UserProfile? {
        if let byUsername = profile(forUsername: moment.username) {
            return byUsername
        }
        if let byID = profile(for: moment.userID) {
            return byID
        }
        guard registerFallback else { return nil }
        let normalizedUsername = normalizeUsername(moment.username)
        guard !normalizedUsername.isEmpty else { return nil }
        let fallback = UserProfile(
            id: moment.userID,
            username: normalizedUsername,
            displayName: moment.displayName,
            bio: "",
            keywords: [normalizedUsername],
            gradientSpec: currentUser.gradientSpec,
            avatarImageData: nil,
            avatarRef: moment.avatarRef,
            isVerified: false,
            isFounder: false
        )
        registerProfile(fallback)
        return profile(for: moment.userID) ?? profile(forUsername: normalizedUsername) ?? fallback
    }

    func loadMoments() async {
        guard backendClient.isEnabled else { return }
        isLoadingMoments = true
        defer { isLoadingMoments = false }
        do {
            let backendMoments = try await backendClient.fetchMoments()
            _ = registerProfiles(from: backendMoments.map(\.user), applyRoleAdjustment: true)
            let now = Date()
            moments = backendMoments.compactMap { bm -> Moment? in
                guard bm.expiresAt > now else { return nil }
                // Apply the same display-only alias remap used everywhere
                // else.  Without this, moments authored under a founder
                // auth alias UUID (e.g. "tonitodaro.mm") surface that
                // alias's username instead of the canonical founder
                // identity.  The userID stays as the original alias UUID
                // so any tap-to-profile navigation continues to work via
                // the profile-registry (which keys by UUID).
                let adjustedUser = roleAdjustedProfile(bm.user.asUserProfile)
                return Moment(
                    id: bm.id,
                    userID: bm.user.id,
                    username: adjustedUser.username,
                    displayName: adjustedUser.displayName,
                    avatarRef: MediaURLResolver.resolve(
                        provider: bm.user.avatarProvider,
                        bucket: bm.user.avatarBucket,
                        objectKey: bm.user.avatarObjectKey
                    )?.absoluteString ?? bm.user.avatarRef,
                    videoRef: bm.videoRef,
                    mediaType: bm.mediaType == .image ? .image : .video,
                    sourceApp: bm.sourceApp == .circles ? .circles : .scrolls,
                    circleMomentID: bm.circleMomentID,
                    createdAt: bm.createdAt,
                    expiresAt: bm.expiresAt,
                    liveBroadcast: bm.liveSession.map {
                        Moment.LiveBroadcast(
                            id: $0.id,
                            ownerUserID: $0.ownerUserID,
                            playbackURL: $0.playbackURL,
                            iframePlaybackURL: $0.iframePlaybackURL,
                            title: $0.title,
                            tipGoal: $0.tipGoal,
                            startedAt: $0.startedAt,
                            mode: $0.mode == .obs ? .obs : .mobile,
                            viewerPassword: $0.viewerPassword,
                            hasViewerPassword: $0.hasViewerPassword
                        )
                    },
                    viewCount: bm.viewCount,
                    viewedBy: bm.viewedBy.compactMap { UUID(uuidString: $0) },
                    hasViewed: bm.hasViewed
                )
            }.sorted { $0.createdAt > $1.createdAt }
            applyActiveLiveSessionToMoments(activeLiveStreamSession)
        } catch {
            momentPostError = "Couldn't refresh moments: \(error.localizedDescription)"
        }
    }

    func postMoment(boomerangURL: URL) async {
        momentPostError = nil
        guard canPostMomentToday else {
            momentPostError = "You've reached your 3 moments for today."
            return
        }
        let newID = UUID()
        do {
            let bm = try await backendClient.createMoment(
                id: newID,
                authorID: currentUser.id,
                videoLocalURL: boomerangURL
            )
            // Apply display-only alias remap so the just-posted moment
            // surfaces canonical founder identity in the local feed
            // (matches the list-fetch path).  userID stays as the original.
            let adjustedUser = roleAdjustedProfile(bm.user.asUserProfile)
            let moment = Moment(
                id: bm.id,
                userID: bm.user.id,
                username: adjustedUser.username,
                displayName: adjustedUser.displayName,
                avatarRef: MediaURLResolver.resolve(
                    provider: bm.user.avatarProvider,
                    bucket: bm.user.avatarBucket,
                    objectKey: bm.user.avatarObjectKey
                )?.absoluteString ?? bm.user.avatarRef,
                videoRef: bm.videoRef,
                mediaType: bm.mediaType == .image ? .image : .video,
                sourceApp: bm.sourceApp == .circles ? .circles : .scrolls,
                circleMomentID: bm.circleMomentID,
                createdAt: bm.createdAt,
                expiresAt: bm.expiresAt,
                liveBroadcast: bm.liveSession.map {
                    Moment.LiveBroadcast(
                        id: $0.id,
                        ownerUserID: $0.ownerUserID,
                        playbackURL: $0.playbackURL,
                        iframePlaybackURL: $0.iframePlaybackURL,
                        title: $0.title,
                        startedAt: $0.startedAt,
                        mode: $0.mode == .obs ? .obs : .mobile,
                        viewerPassword: $0.viewerPassword,
                        hasViewerPassword: $0.hasViewerPassword
                    )
                },
                viewCount: bm.viewCount,
                viewedBy: bm.viewedBy.compactMap { UUID(uuidString: $0) },
                hasViewed: bm.hasViewed
            )
            moments.insert(moment, at: 0)
        } catch {
            momentPostError = error.localizedDescription
        }
    }

    func deleteMoment(id: UUID) async {
        moments.removeAll { $0.id == id }
        try? await backendClient.deleteMoment(id: id)
    }

    /// Record that the current user viewed a moment.  Skips the user's
    /// own moments (the backend treats a self-view as a no-op anyway)
    /// and swallows errors — a failed view record should never disrupt
    /// playback.
    func recordMomentView(_ moment: Moment) async {
        guard moment.userID != currentUser.id else { return }
        try? await backendClient.recordMomentView(momentID: moment.id, userID: currentUser.id)
    }

    /// Author-only: fetch the list of users who viewed a moment, newest
    /// first.  Returns an empty list on error or when called by a
    /// non-author (the backend returns 401 in that case).
    func momentViewers(for moment: Moment) async -> [BackendMomentViewer] {
        (try? await backendClient.fetchMomentViewers(momentID: moment.id, userID: currentUser.id)) ?? []
    }

    func momentViewerProfiles(for viewerIDs: [UUID]) async -> [UserProfile] {
        var seen = Set<UUID>()
        let uniqueIDs = viewerIDs.filter { seen.insert($0).inserted }
        guard !uniqueIDs.isEmpty else { return [] }

        var resolved: [UUID: UserProfile] = [:]
        for id in uniqueIDs {
            if let local = profile(for: id) {
                resolved[id] = local
            }
        }

        let missing = uniqueIDs.filter { resolved[$0] == nil }
        if !missing.isEmpty,
           let remote = try? await backendClient.fetchUsers(ids: missing, includeAuthorization: true) {
            _ = registerProfiles(from: remote, applyRoleAdjustment: true)
            for user in remote {
                if let profile = profile(for: user.id) {
                    resolved[user.id] = profile
                } else {
                    resolved[user.id] = roleAdjustedProfile(user.asUserProfile)
                }
            }
        }

        let stillMissing = uniqueIDs.filter { resolved[$0] == nil }
        if !stillMissing.isEmpty,
           let remotePublic = try? await backendClient.fetchUsers(ids: stillMissing, includeAuthorization: false) {
            _ = registerProfiles(from: remotePublic, applyRoleAdjustment: true)
            for user in remotePublic {
                if let profile = profile(for: user.id) {
                    resolved[user.id] = profile
                } else {
                    resolved[user.id] = roleAdjustedProfile(user.asUserProfile)
                }
            }
        }

        return uniqueIDs.compactMap { resolved[$0] ?? profile(for: $0) }
    }

}

private struct Persistence {
    static nonisolated func loadData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return data
    }
}
