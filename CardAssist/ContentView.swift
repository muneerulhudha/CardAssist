import Foundation
import PhotosUI
import SwiftUI
import UIKit
import ElevenLabs
import AVFoundation

enum AppTab: String, CaseIterable {
    case cards
    case chat

    var title: String { rawValue }
}

struct WalletCard: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let issuer: String
    let network: String
    let confidence: Double
    let visibleClues: [String]
    let addedAt: Date
    let benefits: [CardBenefit]
    let coupons: [CardCoupon]
    let benefitCatalogUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        issuer: String,
        network: String,
        confidence: Double,
        visibleClues: [String],
        addedAt: Date = .now,
        benefits: [CardBenefit] = [],
        coupons: [CardCoupon] = [],
        benefitCatalogUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.issuer = issuer
        self.network = network
        self.confidence = confidence
        self.visibleClues = visibleClues
        self.addedAt = addedAt
        self.benefits = benefits
        self.coupons = coupons
        self.benefitCatalogUpdatedAt = benefitCatalogUpdatedAt
    }

    var subtitle: String {
        let parts = [issuer, network].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if parts.isEmpty {
            return "scanned from photo"
        }
        return parts.joined(separator: " • ")
    }

    var confidenceLabel: String {
        "\(Int((confidence * 100).rounded()))%"
    }

    var tint: Color {
        CardTintPalette.color(for: displayName)
    }

    var couponCountLabel: String {
        "\(coupons.count) coupon\(coupons.count == 1 ? "" : "s")"
    }

    var benefitCountLabel: String {
        "\(benefits.count) benefit\(benefits.count == 1 ? "" : "s")"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case issuer
        case network
        case confidence
        case visibleClues
        case addedAt
        case benefits
        case coupons
        case benefitCatalogUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decode(String.self, forKey: .displayName)
        issuer = try container.decode(String.self, forKey: .issuer)
        network = try container.decode(String.self, forKey: .network)
        confidence = try container.decode(Double.self, forKey: .confidence)
        visibleClues = try container.decodeIfPresent([String].self, forKey: .visibleClues) ?? []
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? .now
        benefits = try container.decodeIfPresent([CardBenefit].self, forKey: .benefits) ?? []
        coupons = try container.decodeIfPresent([CardCoupon].self, forKey: .coupons) ?? []
        benefitCatalogUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .benefitCatalogUpdatedAt)
    }
}

enum CouponCadence: String, Codable, CaseIterable, Sendable {
    case monthly
    case quarterly
    case semiannual
    case yearly
    case ongoing
    case oneTime

    var title: String {
        switch self {
        case .monthly:
            return "monthly"
        case .quarterly:
            return "quarterly"
        case .semiannual:
            return "half yearly"
        case .yearly:
            return "yearly"
        case .ongoing:
            return "ongoing"
        case .oneTime:
            return "one-time"
        }
    }
}

struct CardBenefit: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let name: String
    let details: String
    let sourceTitle: String
    let sourceURL: String

    init(
        id: UUID = UUID(),
        name: String,
        details: String,
        sourceTitle: String,
        sourceURL: String
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
    }
}

struct CardCoupon: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let name: String
    let details: String
    let cadence: CouponCadence
    let sourceTitle: String
    let sourceURL: String
    let usedPeriodKeys: [String]

    init(
        id: UUID = UUID(),
        name: String,
        details: String,
        cadence: CouponCadence,
        sourceTitle: String,
        sourceURL: String,
        usedPeriodKeys: [String] = []
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.cadence = cadence
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.usedPeriodKeys = usedPeriodKeys
    }

    func isUsed(referenceDate: Date = .now) -> Bool {
        usedPeriodKeys.contains(periodKey(for: referenceDate))
    }

    func toggled(referenceDate: Date = .now) -> CardCoupon {
        let currentKey = periodKey(for: referenceDate)
        var keys = usedPeriodKeys

        if let existingIndex = keys.firstIndex(of: currentKey) {
            keys.remove(at: existingIndex)
        } else {
            keys.append(currentKey)
        }

        return CardCoupon(
            id: id,
            name: name,
            details: details,
            cadence: cadence,
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            usedPeriodKeys: keys
        )
    }

    private func periodKey(for referenceDate: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: referenceDate)
        let month = calendar.component(.month, from: referenceDate)

        switch cadence {
        case .monthly:
            return String(format: "%04d-%02d", year, month)
        case .quarterly:
            let quarter = ((month - 1) / 3) + 1
            return "\(year)-Q\(quarter)"
        case .semiannual:
            let half = month <= 6 ? 1 : 2
            return "\(year)-H\(half)"
        case .yearly:
            return "\(year)"
        case .ongoing, .oneTime:
            return "once"
        }
    }
}

struct DetectedCard: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let displayName: String
    let issuer: String
    let network: String
    let confidence: Double
    let visibleClues: [String]

    init(
        id: UUID = UUID(),
        displayName: String,
        issuer: String,
        network: String,
        confidence: Double,
        visibleClues: [String]
    ) {
        self.id = id
        self.displayName = displayName
        self.issuer = issuer
        self.network = network
        self.confidence = confidence
        self.visibleClues = visibleClues
    }

    var subtitle: String {
        let parts = [issuer, network].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if parts.isEmpty {
            return "best guess"
        }
        return parts.joined(separator: " • ")
    }

    var confidenceLabel: String {
        "\(Int((confidence * 100).rounded()))%"
    }
}

struct ToastState: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String
}

enum ChatRole: String, Equatable, Sendable {
    case user
    case agent
    case system
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: String
    let role: ChatRole
    let text: String
    let createdAt: Date

    init(id: String = UUID().uuidString, role: ChatRole, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

enum ChatConnectionState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case error(String)

    var label: String {
        switch self {
        case .idle:
            return "ready"
        case .connecting:
            return "connecting"
        case .connected:
            return "live"
        case let .error(message):
            return message
        }
    }
}

struct AppConfig: Sendable {
    let openRouterAPIKey: String?
    let openRouterModel: String
    let elevenLabsAPIKey: String?
    let elevenAgentID: String?
    let firecrawlAPIKey: String?

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.openRouterAPIKey = environment["OPENROUTER_API_KEY"]?.nonEmpty
        self.openRouterModel = environment["OPENROUTER_MODEL"]?.nonEmpty ?? "openai/gpt-5-mini"
        self.elevenLabsAPIKey = environment["ELEVENLABS_API_KEY"]?.nonEmpty
        self.elevenAgentID = environment["ELEVEN_AGENT_ID"]?.nonEmpty
        self.firecrawlAPIKey = environment["FIRECRAWL_API_KEY"]?.nonEmpty
    }
}

enum AppError: LocalizedError, Equatable, Sendable {
    case missingOpenRouterKey
    case invalidPhoto
    case invalidOpenRouterResponse
    case noCardsDetected
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingOpenRouterKey:
            return "Set OPENROUTER_API_KEY in the Xcode scheme to scan cards."
        case .invalidPhoto:
            return "Could not read that photo."
        case .invalidOpenRouterResponse:
            return "OpenRouter returned a response we could not parse."
        case .noCardsDetected:
            return "No cards were detected in that image."
        case let .httpError(statusCode, message):
            if message.isEmpty {
                return "OpenRouter request failed with status \(statusCode)."
            }
            return message
        }
    }
}

enum ChatError: LocalizedError, Equatable, Sendable {
    case missingElevenAgentID
    case missingFirecrawlKey
    case invalidElevenResponse
    case invalidFirecrawlResponse
    case invalidSignedURL
    case noActiveConversation
    case elevenRequestFailed(statusCode: Int, message: String)
    case firecrawlRequestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingElevenAgentID:
            return "Set ELEVEN_AGENT_ID in the Xcode scheme to chat with your agent."
        case .missingFirecrawlKey:
            return "Set FIRECRAWL_API_KEY in the Xcode scheme to ground card benefits."
        case .invalidElevenResponse:
            return "Eleven returned a response we could not parse."
        case .invalidFirecrawlResponse:
            return "Firecrawl returned a response we could not parse."
        case .invalidSignedURL:
            return "Eleven signed URL was invalid."
        case .noActiveConversation:
            return "The agent is not connected yet."
        case let .elevenRequestFailed(statusCode, message):
            if message.isEmpty {
                return "Eleven request failed with status \(statusCode)."
            }
            return message
        case let .firecrawlRequestFailed(statusCode, message):
            if message.isEmpty {
                return "Firecrawl request failed with status \(statusCode)."
            }
            return message
        }
    }
}

final class WalletStore {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadCards() throws -> [WalletCard] {
        let url = try storageURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode([WalletCard].self, from: data)
    }

    func saveCards(_ cards: [WalletCard]) throws {
        let url = try storageURL()
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(cards)
        try data.write(to: url, options: .atomic)
    }

    private func storageURL() throws -> URL {
        let baseDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return baseDirectory
            .appendingPathComponent("CardAssist", isDirectory: true)
            .appendingPathComponent("wallet.json")
    }
}

struct CardScannerService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func scanWalletPhoto(imageData: Data, config: AppConfig) async throws -> [DetectedCard] {
        guard let apiKey = config.openRouterAPIKey else {
            throw AppError.missingOpenRouterKey
        }

        let base64Image = imageData.base64EncodedString()
        let prompt = """
        You are identifying front-side payment cards in a single wallet photo.

        The image may contain multiple overlapping cards. Return each distinct visible card at most once.

        Rules:
        - Focus on consumer payment cards only.
        - Ignore full card numbers, CVV, and expiration data.
        - Use visible branding, logos, colors, and product names to identify the card.
        - If you are unsure, still provide the best likely match with a lower confidence.
        - If no payment cards are visible, return an empty cards array.
        - Keep `display_name` short and user-facing, for example `Chase Sapphire Reserve`.
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "cards": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "display_name": ["type": "string"],
                            "issuer": ["type": "string"],
                            "network": ["type": "string"],
                            "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                            "visible_clues": [
                                "type": "array",
                                "items": ["type": "string"]
                            ]
                        ],
                        "required": [
                            "display_name",
                            "issuer",
                            "network",
                            "confidence",
                            "visible_clues"
                        ],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["cards"],
            "additionalProperties": false
        ]

        let body: [String: Any] = [
            "model": config.openRouterModel,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "wallet_card_scan",
                    "strict": true,
                    "schema": schema
                ]
            ],
            "provider": [
                "require_parameters": true
            ]
        ]

        let outputText = try await performOpenRouterRequest(body: body, apiKey: apiKey)
        guard let outputData = outputText.data(using: .utf8) else {
            throw AppError.invalidOpenRouterResponse
        }

        let decoded = try JSONDecoder().decode(DetectedCardsPayload.self, from: outputData)
        let cards = decoded.cards
            .map {
                DetectedCard(
                    displayName: $0.displayName.cleanedLabel,
                    issuer: $0.issuer.cleanedLabel,
                    network: $0.network.cleanedLabel,
                    confidence: min(max($0.confidence, 0), 1),
                    visibleClues: $0.visibleClues.map(\.cleanedLabel).filter { !$0.isEmpty }
                )
            }
            .filter { !$0.displayName.isEmpty }

        guard !cards.isEmpty else {
            throw AppError.noCardsDetected
        }

        return deduplicate(cards)
    }

    private func deduplicate(_ cards: [DetectedCard]) -> [DetectedCard] {
        var seen = Set<String>()
        return cards.filter { card in
            let key = card.displayName.normalizedCardKey
            guard !key.isEmpty else { return false }
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    static func extractOutputText(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        guard
            let choices = json["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any]
        else {
            return nil
        }

        if let content = message["content"] as? String, !content.isEmpty {
            return content
        }

        if let contentParts = message["content"] as? [[String: Any]] {
            let combined = contentParts
                .compactMap { part -> String? in
                    if let text = part["text"] as? String {
                        return text
                    }
                    if let textObject = part["text"] as? [String: Any] {
                        return textObject["value"] as? String
                    }
                    return nil
                }
                .joined()
            return combined.isEmpty ? nil : combined
        }

        return nil
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return nil
        }

        return message
    }

    private func performOpenRouterRequest(body: [String: Any], apiKey: String) async throws -> String {
        let requestData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("CardAssist", forHTTPHeaderField: "X-OpenRouter-Title")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidOpenRouterResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AppError.httpError(
                statusCode: httpResponse.statusCode,
                message: Self.extractErrorMessage(from: data) ?? ""
            )
        }

        guard let outputText = Self.extractOutputText(from: data) else {
            throw AppError.invalidOpenRouterResponse
        }

        return outputText
    }

    private struct DetectedCardsPayload: Decodable {
        let cards: [DetectedCardPayload]
    }

    private struct DetectedCardPayload: Decodable {
        let displayName: String
        let issuer: String
        let network: String
        let confidence: Double
        let visibleClues: [String]

        private enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case issuer
            case network
            case confidence
            case visibleClues = "visible_clues"
        }
    }
}

struct CardBenefitCatalog: Equatable, Sendable {
    let benefits: [CardBenefit]
    let coupons: [CardCoupon]
}

struct CardBenefitCatalogService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func buildCatalog(for card: WalletCard, config: AppConfig) async throws -> CardBenefitCatalog {
        guard let firecrawlAPIKey = config.firecrawlAPIKey else {
            throw ChatError.missingFirecrawlKey
        }

        guard let openRouterAPIKey = config.openRouterAPIKey else {
            throw AppError.missingOpenRouterKey
        }

        let sources = try await fetchSources(for: card, apiKey: firecrawlAPIKey)
        return try await extractCatalog(
            for: card,
            from: sources,
            openRouterAPIKey: openRouterAPIKey,
            model: config.openRouterModel
        )
    }

    private func fetchSources(for card: WalletCard, apiKey: String) async throws -> [CatalogSource] {
        let queries = sourceQueries(for: card)
        var seenURLs = Set<String>()
        var sources: [CatalogSource] = []

        for query in queries {
            logCatalog("Running onboarding search for \(card.displayName): \(query)")
            let results = try await runSearch(query: query, apiKey: apiKey)

            for result in results {
                guard seenURLs.insert(result.url).inserted else { continue }
                sources.append(result)
                if sources.count >= 4 {
                    return sources
                }
            }
        }

        return sources
    }

    private func sourceQueries(for card: WalletCard) -> [String] {
        let cardName = "\"\(card.displayName.cleanedLabel)\""
        let domainPrefix = officialDomain(for: card.issuer).map { "site:\($0) " } ?? ""

        return [
            "\(domainPrefix)\(cardName) benefits overview credits lounge insurance travel",
            "\(domainPrefix)\(cardName) card benefits credits hotel airline dining rideshare entertainment"
        ]
    }

    private func officialDomain(for issuer: String) -> String? {
        switch issuer.normalizedSearchText {
        case let key where key.contains("american express"), let key where key == "amex":
            return "americanexpress.com"
        case let key where key.contains("chase"):
            return "chase.com"
        case let key where key.contains("discover"):
            return "discover.com"
        case let key where key.contains("capital one"):
            return "capitalone.com"
        case let key where key.contains("citi"):
            return "citi.com"
        case let key where key.contains("bank of america"):
            return "bankofamerica.com"
        case let key where key.contains("u s bank"), let key where key.contains("us bank"):
            return "usbank.com"
        case let key where key.contains("wells fargo"):
            return "wellsfargo.com"
        default:
            return nil
        }
    }

    private func runSearch(query: String, apiKey: String) async throws -> [CatalogSource] {
        let body: [String: Any] = [
            "query": query,
            "limit": 3,
            "country": "US",
            "sources": ["web"],
            "scrapeOptions": [
                "formats": [
                    ["type": "markdown"]
                ]
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.firecrawl.dev/v2/search")!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidFirecrawlResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ChatError.firecrawlRequestFailed(
                statusCode: httpResponse.statusCode,
                message: Self.extractErrorMessage(from: data) ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(FirecrawlCatalogSearchResponse.self, from: data)
        guard decoded.success else {
            throw ChatError.invalidFirecrawlResponse
        }

        return (decoded.data.web ?? []).compactMap { item in
            guard
                let title = item.title?.cleanedLabel.nonEmpty,
                let url = item.url?.cleanedLabel.nonEmpty
            else {
                return nil
            }

            let markdown = item.markdown?.cleanedLabel ?? ""
            let description = item.description?.cleanedLabel ?? ""
            return CatalogSource(
                title: title,
                url: url,
                description: description,
                markdown: String(markdown.prefix(6_000))
            )
        }
    }

    private func extractCatalog(
        for card: WalletCard,
        from sources: [CatalogSource],
        openRouterAPIKey: String,
        model: String
    ) async throws -> CardBenefitCatalog {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "benefits": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "details": ["type": "string"],
                            "source_title": ["type": "string"],
                            "source_url": ["type": "string"]
                        ],
                        "required": ["name", "details", "source_title", "source_url"],
                        "additionalProperties": false
                    ]
                ],
                "coupons": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "details": ["type": "string"],
                            "cadence": [
                                "type": "string",
                                "enum": CouponCadence.allCases.map(\.rawValue)
                            ],
                            "source_title": ["type": "string"],
                            "source_url": ["type": "string"]
                        ],
                        "required": ["name", "details", "cadence", "source_title", "source_url"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["benefits", "coupons"],
            "additionalProperties": false
        ]

        let sourceText = sources.enumerated().map { index, source in
            """
            Source \(index + 1):
            Title: \(source.title)
            URL: \(source.url)
            Description: \(source.description)
            Markdown:
            \(source.markdown)
            """
        }
        .joined(separator: "\n\n")

        let prompt = """
        You are extracting a benefit ledger for one specific credit card from official issuer benefit pages.

        Card: \(card.displayName)
        Issuer: \(card.issuer)

        Definitions:
        - Benefits: durable perks like lounge access, travel protections, rental car coverage, baggage insurance, elite status, or hotel programs.
        - Coupons: trackable credits, rebates, or discounts like hotel credits, airline credits, rideshare credits, dining credits, entertainment credits, lululemon credits, or similar recurring offers.

        Rules:
        - Only include benefits or coupons that clearly apply to this specific card from the sources provided.
        - Do not invent amounts, terms, or cadences that are not supported by the source text.
        - Put recurring credits into coupons and normalize cadence to one of: monthly, quarterly, semiannual, yearly, ongoing, oneTime.
        - Deduplicate overlapping items.
        - Keep names short and user-facing.
        - Keep details concise but useful for future voice recommendations.
        - Prefer official issuer pages when multiple sources overlap.

        Sources:
        \(sourceText)
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "card_benefit_catalog",
                    "strict": true,
                    "schema": schema
                ]
            ],
            "provider": [
                "require_parameters": true
            ]
        ]

        let outputText = try await performOpenRouterRequest(body: body, apiKey: openRouterAPIKey)
        guard let outputData = outputText.data(using: .utf8) else {
            throw AppError.invalidOpenRouterResponse
        }

        let decoded = try JSONDecoder().decode(CardCatalogPayload.self, from: outputData)
        return CardBenefitCatalog(
            benefits: decoded.benefits.map {
                CardBenefit(
                    name: $0.name.cleanedLabel,
                    details: $0.details.cleanedLabel,
                    sourceTitle: $0.sourceTitle.cleanedLabel,
                    sourceURL: $0.sourceURL.cleanedLabel
                )
            },
            coupons: decoded.coupons.map {
                CardCoupon(
                    name: $0.name.cleanedLabel,
                    details: $0.details.cleanedLabel,
                    cadence: $0.cadence,
                    sourceTitle: $0.sourceTitle.cleanedLabel,
                    sourceURL: $0.sourceURL.cleanedLabel
                )
            }
        )
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let message = json["error"] as? String {
            return message
        }

        if
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }

        return nil
    }

    private func performOpenRouterRequest(body: [String: Any], apiKey: String) async throws -> String {
        let requestData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("CardAssist", forHTTPHeaderField: "X-OpenRouter-Title")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidOpenRouterResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AppError.httpError(
                statusCode: httpResponse.statusCode,
                message: Self.extractErrorMessage(from: data) ?? ""
            )
        }

        guard let outputText = CardScannerService.extractOutputText(from: data) else {
            throw AppError.invalidOpenRouterResponse
        }

        return outputText
    }

    private func logCatalog(_ message: String) {
        print("[Catalog] \(message)")
    }

    private struct CatalogSource: Sendable {
        let title: String
        let url: String
        let description: String
        let markdown: String
    }

    private struct FirecrawlCatalogSearchResponse: Decodable {
        let success: Bool
        let data: FirecrawlCatalogData
    }

    private struct FirecrawlCatalogData: Decodable {
        let web: [FirecrawlCatalogItem]?
    }

    private struct FirecrawlCatalogItem: Decodable {
        let title: String?
        let description: String?
        let url: String?
        let markdown: String?
    }

    private struct CardCatalogPayload: Decodable {
        let benefits: [CardBenefitPayload]
        let coupons: [CardCouponPayload]
    }

    private struct CardBenefitPayload: Decodable {
        let name: String
        let details: String
        let sourceTitle: String
        let sourceURL: String

        private enum CodingKeys: String, CodingKey {
            case name
            case details
            case sourceTitle = "source_title"
            case sourceURL = "source_url"
        }
    }

    private struct CardCouponPayload: Decodable {
        let name: String
        let details: String
        let cadence: CouponCadence
        let sourceTitle: String
        let sourceURL: String

        private enum CodingKeys: String, CodingKey {
            case name
            case details
            case cadence
            case sourceTitle = "source_title"
            case sourceURL = "source_url"
        }
    }
}

struct BenefitLookupResult: Equatable, Sendable {
    let userQuestion: String
    let entries: [BenefitLookupEntry]

    var hasEvidence: Bool {
        entries.contains { !$0.results.isEmpty }
    }

    func contextualUpdateText(walletCards: [WalletCard]) -> String {
        var lines: [String] = [
            "CardAssist app instructions:",
            "- Recommend only from the wallet cards listed below.",
            "- Use the Firecrawl research below when it looks relevant.",
            "- Prioritize named credits, hotel programs, wellness perks, and statement credits when the research mentions them.",
            "- If a benefit requires enrollment or portal booking, mention that briefly.",
            "- Be short, conversational, and decisive.",
            "- If the evidence is weak, say that clearly and give the best fallback from the wallet.",
            "",
            "Saved wallet:"
        ]

        for (index, card) in walletCards.enumerated() {
            lines.append("\(index + 1). \(card.displayName) — \(card.subtitle)")
        }

        lines.append("")
        lines.append("User request: \(userQuestion)")
        lines.append("")
        lines.append("Firecrawl research:")

        if !hasEvidence {
            lines.append("No strong search results were found for the saved cards.")
        }

        for entry in entries {
            lines.append("")
            lines.append("Card: \(entry.card.displayName)")
            lines.append("Search query: \(entry.query)")

            if !entry.highlights.isEmpty {
                lines.append("Matched benefits:")
                for highlight in entry.highlights {
                    lines.append("- \(highlight.name): \(highlight.summary)")
                    lines.append("  Source: \(highlight.sourceTitle)")
                    lines.append("  URL: \(highlight.sourceURL)")
                }
            }

            if entry.results.isEmpty {
                lines.append("No strong matches found.")
                continue
            }

            for (index, result) in entry.results.enumerated() {
                lines.append("Result \(index + 1): \(result.title)")
                lines.append("URL: \(result.url)")
                if let description = result.description.nonEmpty {
                    lines.append("Description: \(description)")
                }
                if let snippet = result.snippet.nonEmpty {
                    lines.append("Snippet: \(snippet)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    func toolSummaryText(walletCards: [WalletCard]) -> String {
        var lines: [String] = [
            "User request: \(userQuestion)",
            "",
            "Applicable wallet benefits:"
        ]

        let entriesWithHighlights = entries.filter { !$0.highlights.isEmpty }

        if entriesWithHighlights.isEmpty {
            lines.append("No specific named benefit was confidently matched from the current Firecrawl research.")
            return lines.joined(separator: "\n")
        }

        for entry in entriesWithHighlights {
            lines.append("")
            lines.append("Card: \(entry.card.displayName)")
            for highlight in entry.highlights {
                lines.append("- \(highlight.name): \(highlight.summary)")
                lines.append("  Source: \(highlight.sourceTitle)")
                lines.append("  URL: \(highlight.sourceURL)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

struct BenefitLookupEntry: Equatable, Sendable {
    let card: WalletCard
    let query: String
    let highlights: [BenefitHighlight]
    let results: [BenefitSearchResult]
}

struct BenefitHighlight: Equatable, Sendable {
    let name: String
    let summary: String
    let sourceTitle: String
    let sourceURL: String
}

struct BenefitSearchResult: Equatable, Sendable {
    let title: String
    let url: String
    let description: String
    let snippet: String
}

struct FirecrawlBenefitService: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupBenefits(
        for cards: [WalletCard],
        useCase: String,
        config: AppConfig
    ) async throws -> BenefitLookupResult {
        guard let apiKey = config.firecrawlAPIKey else {
            throw ChatError.missingFirecrawlKey
        }

        let trimmedUseCase = useCase.cleanedLabel
        let limitedCards = Array(cards.prefix(8))
        let queries = walletQueryPlan(for: limitedCards, useCase: trimmedUseCase)
        logFirecrawl("Starting benefit lookup for use case: \(trimmedUseCase)")
        logFirecrawl("Searching across \(limitedCards.count) saved card(s) with \(queries.count) wallet-level quer\(queries.count == 1 ? "y" : "ies")")

        let combinedResults = try await collectResults(for: queries, apiKey: apiKey)
        let intent = UseCaseIntent(text: trimmedUseCase)

        let result = BenefitLookupResult(
            userQuestion: trimmedUseCase,
            entries: buildEntries(
                for: limitedCards,
                from: combinedResults,
                using: queries,
                intent: intent
            )
        )

        let populatedEntries = result.entries.filter { !$0.results.isEmpty }.count
        logFirecrawl("Benefit lookup complete. Cards with evidence: \(populatedEntries)/\(result.entries.count)")
        return result
    }

    private func buildEntries(
        for cards: [WalletCard],
        from combinedResults: [BenefitSearchResult],
        using queries: [String],
        intent: UseCaseIntent
    ) -> [BenefitLookupEntry] {
        let querySummary = queries.joined(separator: " | ")

        return cards
            .map { card in
                let matched = matchedResults(for: card, in: combinedResults, intent: intent)
                return BenefitLookupEntry(
                    card: card,
                    query: querySummary,
                    highlights: extractBenefitHighlights(for: card, from: matched, intent: intent),
                    results: matched
                )
            }
            .sorted { lhs, rhs in
                let lhsScore = lhs.highlights.count * 10 + lhs.results.count
                let rhsScore = rhs.highlights.count * 10 + rhs.results.count
                if lhsScore == rhsScore {
                    return lhs.card.displayName < rhs.card.displayName
                }
                return lhsScore > rhsScore
            }
    }

    private func matchedResults(
        for card: WalletCard,
        in results: [BenefitSearchResult],
        intent: UseCaseIntent
    ) -> [BenefitSearchResult] {
        let aliases = resultAliases(for: card, intent: intent)

        let matched = results.filter { result in
            let haystack = [result.title, result.description, result.snippet, result.url]
                .joined(separator: " ")
                .normalizedSearchText

            return aliases.contains { alias in
                haystack.contains(alias)
            }
        }

        return Array(matched.prefix(4))
    }

    private func extractBenefitHighlights(
        for card: WalletCard,
        from results: [BenefitSearchResult],
        intent: UseCaseIntent
    ) -> [BenefitHighlight] {
        let patterns = benefitPatterns(for: card, intent: intent)
        var seen = Set<String>()
        var highlights: [BenefitHighlight] = []

        for result in results {
            let haystack = [result.title, result.description, result.snippet, result.url]
                .joined(separator: " ")
                .normalizedSearchText

            for pattern in patterns {
                guard pattern.aliases.contains(where: { haystack.contains($0) }) else { continue }
                guard seen.insert(pattern.name.lowercased()).inserted else { continue }

                highlights.append(
                    BenefitHighlight(
                        name: pattern.name,
                        summary: pattern.summary,
                        sourceTitle: result.title,
                        sourceURL: result.url
                    )
                )
            }
        }

        logFirecrawl("Matched \(highlights.count) named benefit(s) for \(card.displayName)")
        return highlights
    }

    private func collectResults(
        for queries: [String],
        apiKey: String
    ) async throws -> [BenefitSearchResult] {
        var seenResultKeys = Set<String>()
        var collectedResults: [BenefitSearchResult] = []

        for query in queries {
            logFirecrawl("Running search query: \(query)")
            let searchResults = try await runSearch(query: query, apiKey: apiKey)

            for result in searchResults {
                let key = "\(result.url.lowercased())|\(result.title.lowercased())"
                guard seenResultKeys.insert(key).inserted else { continue }
                collectedResults.append(result)

                if collectedResults.count >= 4 {
                    return collectedResults
                }
            }
        }

        return collectedResults
    }

    private func walletQueryPlan(for cards: [WalletCard], useCase: String) -> [String] {
        let intent = UseCaseIntent(text: useCase)
        let cardNames = cards
            .prefix(6)
            .map { "\"\($0.displayName.cleanedLabel)\"" }
            .joined(separator: " ")
        let walletTerms = walletBenefitQueryTerms(for: cards, intent: intent)

        var queries: [String] = [
            "\(useCase) credit card benefits statement credit perks",
            "\(useCase) \(cardNames) credit card benefits"
        ]

        if !walletTerms.isEmpty {
            queries.append("\(useCase) \(walletTerms.joined(separator: " "))")
        }

        return deduplicatedQueries(queries)
    }

    private func walletBenefitQueryTerms(for cards: [WalletCard], intent: UseCaseIntent) -> [String] {
        var terms = intent.genericTerms

        for card in cards {
            terms.append(contentsOf: cardSpecificQueryTerms(for: card, intent: intent))
        }

        return deduplicatedTerms(terms)
    }

    private func cardSpecificQueryTerms(for card: WalletCard, intent: UseCaseIntent) -> [String] {
        var terms = intent.genericTerms
        let cardKey = card.displayName.normalizedCardKey
        let issuerKey = card.issuer.normalizedCardKey

        if (issuerKey.contains("american express") || issuerKey == "amex") && cardKey.contains("platinum") {
            if intent.isWellnessFocused {
                terms.append(contentsOf: [
                    "\"equinox credit\"",
                    "\"lululemon credit\"",
                    "\"wellness benefits\"",
                    "\"shopping benefits\""
                ])
            }

            if intent.isHotelFocused {
                terms.append(contentsOf: [
                    "\"Fine Hotels + Resorts\"",
                    "\"The Hotel Collection\"",
                    "\"hotel credit\""
                ])
            }
        }

        if issuerKey.contains("chase") && cardKey.contains("sapphire reserve") && intent.isHotelFocused {
            terms.append(contentsOf: [
                "\"The Edit by Chase Travel\"",
                "\"The Edit\"",
                "\"property credit\"",
                "\"daily breakfast\""
            ])
        }

        if cardKey.contains("world of hyatt") && intent.isHotelFocused {
            terms.append(contentsOf: [
                "\"free night\"",
                "\"award night\"",
                "\"Hyatt stay\""
            ])
        }

        for benefit in card.benefits where intent.matchesInventoryText("\(benefit.name) \(benefit.details)") {
            terms.append("\"\(benefit.name.cleanedLabel)\"")
        }

        for coupon in card.coupons where intent.matchesInventoryText("\(coupon.name) \(coupon.details)") {
            terms.append("\"\(coupon.name.cleanedLabel)\"")
        }

        return deduplicatedTerms(terms)
    }

    private func resultAliases(for card: WalletCard, intent: UseCaseIntent) -> [String] {
        var aliases = [
            card.displayName.normalizedSearchText,
            "\(card.issuer) \(card.displayName)".normalizedSearchText
        ]

        let cardKey = card.displayName.normalizedCardKey
        let issuerKey = card.issuer.normalizedCardKey

        if (issuerKey.contains("american express") || issuerKey == "amex") && cardKey.contains("platinum") {
            aliases.append(contentsOf: [
                "the platinum card",
                "american express platinum",
                "amex platinum"
            ])

            if intent.isWellnessFocused {
                aliases.append(contentsOf: [
                    "equinox",
                    "lululemon"
                ])
            }

            if intent.isHotelFocused {
                aliases.append(contentsOf: [
                    "fine hotels resorts",
                    "the hotel collection",
                    "hotel collection"
                ])
            }
        }

        if issuerKey.contains("chase") && cardKey.contains("sapphire reserve") {
            aliases.append(contentsOf: [
                "sapphire reserve",
                "chase sapphire reserve"
            ])

            if intent.isHotelFocused {
                aliases.append(contentsOf: [
                    "the edit",
                    "the edit by chase travel"
                ])
            }
        }

        if cardKey.contains("world of hyatt") {
            aliases.append(contentsOf: [
                "world of hyatt",
                "hyatt visa"
            ])

            if intent.isHotelFocused {
                aliases.append(contentsOf: [
                    "free night",
                    "award night"
                ])
            }
        }

        aliases.append(contentsOf: card.benefits.map { $0.name.normalizedSearchText })
        aliases.append(contentsOf: card.coupons.map { $0.name.normalizedSearchText })

        return deduplicatedTerms(aliases.map(\.normalizedSearchText))
    }

    private func benefitPatterns(for card: WalletCard, intent: UseCaseIntent) -> [BenefitPattern] {
        var patterns: [BenefitPattern] = []
        let cardKey = card.displayName.normalizedCardKey
        let issuerKey = card.issuer.normalizedCardKey

        if (issuerKey.contains("american express") || issuerKey == "amex") && cardKey.contains("platinum") {
            if intent.isWellnessFocused {
                patterns.append(
                    BenefitPattern(
                        name: "Equinox credit",
                        summary: "fitness and wellness credit that can help with gym membership spend on Amex Platinum",
                        aliases: ["equinox", "equinox credit"]
                    )
                )
                patterns.append(
                    BenefitPattern(
                        name: "lululemon credit",
                        summary: "shopping credit mentioned for Amex Platinum that can help with gym clothes",
                        aliases: ["lululemon", "lululemon credit"]
                    )
                )
            }

            if intent.isHotelFocused {
                patterns.append(
                    BenefitPattern(
                        name: "Fine Hotels + Resorts",
                        summary: "Amex Travel hotel program with premium stay perks when you book through the program",
                        aliases: ["fine hotels resorts", "fine hotels + resorts"]
                    )
                )
                patterns.append(
                    BenefitPattern(
                        name: "The Hotel Collection",
                        summary: "Amex Travel hotel program with property perks when booked through Amex Travel",
                        aliases: ["hotel collection", "the hotel collection"]
                    )
                )
            }
        }

        if issuerKey.contains("chase") && cardKey.contains("sapphire reserve") && intent.isHotelFocused {
            patterns.append(
                BenefitPattern(
                    name: "The Edit by Chase Travel",
                    summary: "Chase hotel program with property perks when you book through Chase Travel",
                    aliases: ["the edit by chase travel", "the edit"]
                )
            )
        }

        if cardKey.contains("world of hyatt") && intent.isHotelFocused {
            patterns.append(
                BenefitPattern(
                    name: "World of Hyatt free night",
                    summary: "Hyatt free-night style benefit that can be valuable for hotel stays",
                    aliases: ["free night", "award night", "hyatt stay"]
                )
            )
        }

        return patterns
    }

    private func deduplicatedQueries(_ queries: [String]) -> [String] {
        var seen = Set<String>()
        var deduplicated: [String] = []

        for query in queries.map(\.cleanedLabel).filter({ !$0.isEmpty }) {
            let key = query.lowercased()
            guard seen.insert(key).inserted else { continue }
            deduplicated.append(query)
        }

        return deduplicated
    }

    private func deduplicatedTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        var deduplicated: [String] = []

        for term in terms.map(\.cleanedLabel).filter({ !$0.isEmpty }) {
            let key = term.lowercased()
            guard seen.insert(key).inserted else { continue }
            deduplicated.append(term)
        }

        return deduplicated
    }

    private func runSearch(query: String, apiKey: String) async throws -> [BenefitSearchResult] {
        let body: [String: Any] = [
            "query": query,
            "limit": 4,
            "country": "US",
            "sources": ["web"],
            "scrapeOptions": [
                "formats": [
                    ["type": "markdown"]
                ]
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.firecrawl.dev/v2/search")!)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        logFirecrawl("POST /v2/search")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            logFirecrawl("Search response was not an HTTP response")
            throw ChatError.invalidFirecrawlResponse
        }

        logFirecrawl("Search status \(httpResponse.statusCode) for query: \(query)")

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8)?.cleanedLabel ?? "<non-utf8>"
            logFirecrawl("Search failed. Body: \(rawBody)")
            throw ChatError.firecrawlRequestFailed(
                statusCode: httpResponse.statusCode,
                message: Self.extractErrorMessage(from: data) ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(FirecrawlSearchResponse.self, from: data)
        guard decoded.success else {
            throw ChatError.invalidFirecrawlResponse
        }

        let webResults = Array((decoded.data.web ?? []).prefix(4))
        let mappedResults: [BenefitSearchResult] = webResults.compactMap { result -> BenefitSearchResult? in
            guard
                let title = result.title?.cleanedLabel.nonEmpty,
                let url = result.url?.cleanedLabel.nonEmpty
            else {
                return nil
            }

            let description = result.description?.cleanedLabel ?? ""
            let snippet = extractSnippet(from: result.markdown, fallback: description)

            return BenefitSearchResult(
                title: title,
                url: url,
                description: description,
                snippet: snippet
            )
        }

        logFirecrawl("Search returned \(mappedResults.count) result(s) for query: \(query)")
        return mappedResults
    }

    private func extractSnippet(from markdown: String?, fallback: String) -> String {
        let fallbackText = fallback.cleanedLabel
        guard let markdown = markdown?.cleanedLabel, !markdown.isEmpty else {
            return String(fallbackText.prefix(220))
        }

        let lines = markdown
            .components(separatedBy: .newlines)
            .map(\.cleanedLabel)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("!") }

        guard let firstLine = lines.first else {
            return String(fallbackText.prefix(220))
        }

        return String(firstLine.prefix(220))
    }

    private static func extractErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let message = json["error"] as? String {
            return message
        }

        if
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }

        return nil
    }

    private func logFirecrawl(_ message: String) {
        print("[Firecrawl] \(message)")
    }

    private struct FirecrawlSearchResponse: Decodable {
        let success: Bool
        let data: FirecrawlSearchData
    }

    private struct FirecrawlSearchData: Decodable {
        let web: [FirecrawlSearchItem]?
    }

    private struct FirecrawlSearchItem: Decodable {
        let title: String?
        let description: String?
        let url: String?
        let markdown: String?
    }

    private struct BenefitPattern {
        let name: String
        let summary: String
        let aliases: [String]
    }

    private struct UseCaseIntent {
        let normalizedText: String

        init(text: String) {
            normalizedText = text.normalizedSearchText
        }

        var isHotelFocused: Bool {
            containsAny([
                "hotel", "stay", "room", "booking", "book", "resort", "travel", "trip", "vacation"
            ])
        }

        var isWellnessFocused: Bool {
            containsAny([
                "gym", "fitness", "workout", "class", "classes", "wellness", "equinox", "pilates", "yoga"
            ]) || isShoppingFocused
        }

        var isShoppingFocused: Bool {
            containsAny([
                "clothes", "clothing", "apparel", "gear", "leggings", "shoes", "shopping", "lululemon", "retail"
            ])
        }

        var isDiningFocused: Bool {
            containsAny([
                "restaurant", "food", "dining", "meal", "lunch", "dinner", "coffee", "mcdonald"
            ])
        }

        var genericTerms: [String] {
            var terms: [String] = []

            if isHotelFocused {
                terms.append(contentsOf: [
                    "\"hotel credit\"",
                    "\"property credit\"",
                    "\"room upgrade\"",
                    "\"daily breakfast\""
                ])
            }

            if isWellnessFocused {
                terms.append(contentsOf: [
                    "\"wellness benefits\"",
                    "\"fitness credit\"",
                    "\"statement credit\""
                ])
            }

            if isShoppingFocused {
                terms.append(contentsOf: [
                    "\"shopping benefits\"",
                    "\"retail credit\"",
                    "\"statement credit\""
                ])
            }

            if isDiningFocused {
                terms.append(contentsOf: [
                    "\"dining benefits\"",
                    "\"restaurant\"",
                    "\"points\""
                ])
            }

            return terms
        }

        private func containsAny(_ tokens: [String]) -> Bool {
            tokens.contains { normalizedText.contains($0) }
        }

        func matchesInventoryText(_ text: String) -> Bool {
            let candidate = text.normalizedSearchText
            guard !candidate.isEmpty else { return false }

            if isHotelFocused {
                return candidate.contains("hotel") || candidate.contains("travel") || candidate.contains("airline")
            }

            if isWellnessFocused {
                return candidate.contains("gym") || candidate.contains("fitness") || candidate.contains("wellness") || candidate.contains("equinox")
            }

            if isShoppingFocused {
                return candidate.contains("shopping") || candidate.contains("retail") || candidate.contains("lululemon") || candidate.contains("apparel")
            }

            if isDiningFocused {
                return candidate.contains("dining") || candidate.contains("restaurant") || candidate.contains("doordash") || candidate.contains("food")
            }

            return false
        }
    }
}

enum AppSoundCue: String, Sendable {
    case sessionStarted = "eleven_session_started"
    case sessionEnded = "eleven_session_ended"
    case toolStarted = "eleven_tool_started"
    case toolFinished = "eleven_tool_finished"
    case error = "eleven_error"
}

final class SoundEffectManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundEffectManager()

    private var activePlayers: [AVAudioPlayer] = []

    func play(_ cue: AppSoundCue) {
        if let assetPlayer = makeBundledPlayer(for: cue) {
            play(assetPlayer, cue: cue, source: "bundle")
            return
        }

        do {
            let data = try synthesizedWaveData(for: cue)
            let player = try AVAudioPlayer(data: data)
            player.volume = defaultVolume(for: cue)
            play(player, cue: cue, source: "synth")
        } catch {
            print("[Sound] Failed to play \(cue.rawValue): \(error.localizedDescription)")
            fallbackHaptic(for: cue)
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.activePlayers.removeAll { $0 === player }
        }
    }

    private func play(_ player: AVAudioPlayer, cue: AppSoundCue, source: String) {
        player.delegate = self
        player.prepareToPlay()
        activePlayers.append(player)
        let started = player.play()
        print("[Sound] \(started ? "Playing" : "Failed to play") \(cue.rawValue) from \(source)")
        if !started {
            activePlayers.removeAll { $0 === player }
            fallbackHaptic(for: cue)
        }
    }

    private func makeBundledPlayer(for cue: AppSoundCue) -> AVAudioPlayer? {
        let fileExtensions = ["wav", "mp3", "m4a"]

        for fileExtension in fileExtensions {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: fileExtension) else {
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                return player
            } catch {
                print("[Sound] Could not load bundled cue \(cue.rawValue).\(fileExtension): \(error.localizedDescription)")
            }
        }

        return nil
    }

    private func defaultVolume(for cue: AppSoundCue) -> Float {
        switch cue {
        case .sessionStarted, .sessionEnded:
            return 0.22
        case .toolStarted, .toolFinished:
            return 0.18
        case .error:
            return 0.25
        }
    }

    private func fallbackHaptic(for cue: AppSoundCue) {
        switch cue {
        case .sessionStarted, .toolFinished:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .toolStarted:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .sessionEnded:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func synthesizedWaveData(for cue: AppSoundCue) throws -> Data {
        switch cue {
        case .sessionStarted:
            return try makeWave(segments: [
                WaveSegment(startFrequency: 660, endFrequency: 720, duration: 0.08, amplitude: 0.45),
                WaveSegment(startFrequency: 880, endFrequency: 960, duration: 0.10, amplitude: 0.4)
            ])
        case .sessionEnded:
            return try makeWave(segments: [
                WaveSegment(startFrequency: 700, endFrequency: 620, duration: 0.08, amplitude: 0.32),
                WaveSegment(startFrequency: 560, endFrequency: 500, duration: 0.08, amplitude: 0.28)
            ])
        case .toolStarted:
            return try makeWave(segments: [
                WaveSegment(startFrequency: 520, endFrequency: 560, duration: 0.06, amplitude: 0.24),
                WaveSegment(startFrequency: 520, endFrequency: 540, duration: 0.06, amplitude: 0.18)
            ])
        case .toolFinished:
            return try makeWave(segments: [
                WaveSegment(startFrequency: 780, endFrequency: 820, duration: 0.06, amplitude: 0.26),
                WaveSegment(startFrequency: 980, endFrequency: 1060, duration: 0.07, amplitude: 0.24)
            ])
        case .error:
            return try makeWave(segments: [
                WaveSegment(startFrequency: 420, endFrequency: 360, duration: 0.08, amplitude: 0.3),
                WaveSegment(startFrequency: 360, endFrequency: 300, duration: 0.1, amplitude: 0.26)
            ])
        }
    }

    private func makeWave(
        segments: [WaveSegment],
        sampleRate: Int = 24_000
    ) throws -> Data {
        let sampleRateDouble = Double(sampleRate)
        var pcmBytes = Data()

        for segment in segments {
            let sampleCount = max(Int(segment.duration * sampleRateDouble), 1)

            for index in 0 ..< sampleCount {
                let progress = Double(index) / Double(sampleCount)
                let frequency = segment.startFrequency + (segment.endFrequency - segment.startFrequency) * progress
                let envelope = envelopeAmplitude(progress: progress) * segment.amplitude
                let angle = 2 * Double.pi * frequency * Double(index) / sampleRateDouble
                let sample = sin(angle) * envelope
                let intSample = Int16(max(min(sample, 1), -1) * Double(Int16.max))
                pcmBytes.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
            }
        }

        return wavData(from: pcmBytes, sampleRate: sampleRate)
    }

    private func envelopeAmplitude(progress: Double) -> Double {
        let clamped = max(0, min(progress, 1))
        let attack = min(clamped / 0.12, 1)
        let release = min((1 - clamped) / 0.18, 1)
        return attack * release
    }

    private func wavData(from pcmBytes: Data, sampleRate: Int) -> Data {
        let pcmByteCount = UInt32(pcmBytes.count)
        let byteRate = UInt32(sampleRate * 2)
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(littleEndianData(UInt32(36) + pcmByteCount))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(littleEndianData(UInt32(16)))
        data.append(littleEndianData(UInt16(1)))
        data.append(littleEndianData(UInt16(1)))
        data.append(littleEndianData(UInt32(sampleRate)))
        data.append(littleEndianData(byteRate))
        data.append(littleEndianData(blockAlign))
        data.append(littleEndianData(bitsPerSample))
        data.append("data".data(using: .ascii)!)
        data.append(littleEndianData(pcmByteCount))
        data.append(pcmBytes)
        return data
    }

    private func littleEndianData<T: FixedWidthInteger>(_ value: T) -> Data {
        var littleEndianValue = value.littleEndian
        return withUnsafeBytes(of: &littleEndianValue) { Data($0) }
    }

    private struct WaveSegment {
        let startFrequency: Double
        let endFrequency: Double
        let duration: TimeInterval
        let amplitude: Double
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedTab: AppTab = .cards
    @Published var cards: [WalletCard]
    @Published var isAddCardsPresented = false
    @Published var isAnalyzingCards = false
    @Published var detectedCards: [DetectedCard] = []
    @Published var scanError: String?
    @Published var toast: ToastState?
    @Published var chatMessages: [ChatMessage] = []
    @Published var chatConnectionState: ChatConnectionState = .idle
    @Published var voiceStatusDetail = "tap mic to start"
    @Published var isConversationMuted = false
    @Published var voiceActivityScore = 0.0
    @Published var enrichingCardIDs = Set<UUID>()

    let config = AppConfig()

    private let walletStore = WalletStore()
    private let cardScanner = CardScannerService()
    private let cardBenefitCatalogService = CardBenefitCatalogService()
    private let firecrawlBenefits = FirecrawlBenefitService()
    private let soundEffects = SoundEffectManager.shared
    private var conversation: Conversation?
    private var observationTasks: [Task<Void, Never>] = []
    private var tokenPrefetchTask: Task<Void, Never>?
    private var handledToolCallIDs = Set<String>()
    private var groundedTranscriptEventIDs = Set<String>()
    private var isEndingConversation = false
    private var shouldResetStatusOnDisconnect = true
    private var prefetchedConversationToken: String?
    private var prefetchedConversationTokenDate: Date?
    private var latestUserTranscriptEventID: String?
    private var latestUserTranscriptText: String?
    private var currentTurnLookupTask: Task<BenefitLookupResult, Error>?
    private var currentTurnLookupTaskTurnID: String?
    private var currentTurnLookupResult: BenefitLookupResult?
    private var currentTurnLookupResultTurnID: String?
    private var cachedBenefitLookups: [String: CachedBenefitLookup] = [:]

    init() {
        self.cards = (try? walletStore.loadCards()) ?? []
        prefetchConversationTokenIfNeeded()
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
        tokenPrefetchTask?.cancel()
    }

    var cardsCountLabel: String {
        "\(cards.count) saved"
    }

    var openRouterScanReady: Bool {
        config.openRouterAPIKey != nil
    }

    var canAnalyzeSelectedPhoto: Bool {
        !isAnalyzingCards && openRouterScanReady
    }

    var chatStatusLabel: String {
        if let blockingMessage = chatBlockingMessage {
            return blockingMessage
        }

        switch chatConnectionState {
        case .idle:
            return voiceStatusDetail
        case .connecting:
            return "connecting"
        case .connected:
            return voiceStatusDetail
        case let .error(message):
            return message
        }
    }

    var chatCardsLabel: String {
        "\(cards.count) cards"
    }

    var voiceButtonLabel: String {
        isConversationLive ? "end voice" : "Ask me about your cards"
    }

    var muteButtonLabel: String {
        isConversationMuted ? "unmute" : "mute"
    }

    var canToggleVoice: Bool {
        if chatBlockingMessage != nil {
            return false
        }
        if case .connecting = chatConnectionState {
            return false
        }
        return true
    }

    var canToggleMute: Bool {
        isConversationLive
    }

    var isVoiceLive: Bool {
        isConversationLive
    }

    private var isConversationLive: Bool {
        if case .connected = chatConnectionState {
            return true
        }
        return false
    }

    var chatBlockingMessage: String? {
        if cards.isEmpty {
            return "add cards first"
        }
        if config.elevenAgentID == nil {
            return "set ELEVEN_AGENT_ID"
        }
        if config.firecrawlAPIKey == nil {
            return "set FIRECRAWL_API_KEY"
        }
        return nil
    }

    func switchTab(_ tab: AppTab) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
            selectedTab = tab
        }

        if tab == .chat {
            prefetchConversationTokenIfNeeded()
        }
    }

    func presentAddCards() {
        resetScanSession()
        isAddCardsPresented = true
    }

    func dismissAddCards() {
        isAddCardsPresented = false
        resetScanSession()
    }

    func resetScanSession() {
        detectedCards = []
        scanError = nil
        isAnalyzingCards = false
    }

    func analyzePhoto(_ imageData: Data) async {
        scanError = nil
        detectedCards = []

        isAnalyzingCards = true
        defer { isAnalyzingCards = false }

        do {
            detectedCards = try await cardScanner.scanWalletPhoto(imageData: imageData, config: config)
        } catch {
            scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func saveDetectedCards(_ cardsToSave: [DetectedCard]) {
        guard !cardsToSave.isEmpty else {
            showToast("select at least one card")
            return
        }

        let existingKeys = Set(cards.map { $0.displayName.normalizedCardKey })
        let newCards = cardsToSave
            .filter { !existingKeys.contains($0.displayName.normalizedCardKey) }
            .map {
                WalletCard(
                    displayName: $0.displayName,
                    issuer: $0.issuer,
                    network: $0.network,
                    confidence: $0.confidence,
                    visibleClues: $0.visibleClues
                )
            }

        guard !newCards.isEmpty else {
            showToast("no new cards to save")
            return
        }

        cards.append(contentsOf: newCards)
        cards.sort { $0.addedAt > $1.addedAt }

        do {
            try walletStore.saveCards(cards)
            showToast("added \(newCards.count) card\(newCards.count == 1 ? "" : "s")")
            dismissAddCards()
            selectedTab = .cards
            Task {
                await enrichCatalogs(for: newCards.map(\.id))
            }
        } catch {
            scanError = "Could not save scanned cards."
        }
    }

    func deleteCard(_ card: WalletCard) {
        cards.removeAll { $0.id == card.id }
        enrichingCardIDs.remove(card.id)

        do {
            try walletStore.saveCards(cards)
            showToast("deleted \(card.displayName)")
        } catch {
            showToast("could not delete card")
        }
    }

    func updateDetectedCard(_ cardID: UUID, cardType: String, issuer: String) {
        guard let index = detectedCards.firstIndex(where: { $0.id == cardID }) else {
            return
        }

        let cleanedType = cardType.cleanedLabel
        let cleanedIssuer = issuer.cleanedLabel
        guard !cleanedType.isEmpty, !cleanedIssuer.isEmpty else {
            showToast("enter card type and issuer")
            return
        }

        let existing = detectedCards[index]
        detectedCards[index] = DetectedCard(
            id: existing.id,
            displayName: cleanedType,
            issuer: cleanedIssuer,
            network: "",
            confidence: existing.confidence,
            visibleClues: existing.visibleClues
        )

        showToast("updated \(cleanedType)")
    }

    func toggleCouponUsage(cardID: UUID, couponID: UUID) {
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardID }) else {
            return
        }

        guard let couponIndex = cards[cardIndex].coupons.firstIndex(where: { $0.id == couponID }) else {
            return
        }

        var updatedCoupons = cards[cardIndex].coupons
        let toggledCoupon = updatedCoupons[couponIndex].toggled()
        updatedCoupons[couponIndex] = toggledCoupon

        let updatedCard = WalletCard(
            id: cards[cardIndex].id,
            displayName: cards[cardIndex].displayName,
            issuer: cards[cardIndex].issuer,
            network: cards[cardIndex].network,
            confidence: cards[cardIndex].confidence,
            visibleClues: cards[cardIndex].visibleClues,
            addedAt: cards[cardIndex].addedAt,
            benefits: cards[cardIndex].benefits,
            coupons: updatedCoupons,
            benefitCatalogUpdatedAt: cards[cardIndex].benefitCatalogUpdatedAt
        )

        cards[cardIndex] = updatedCard

        do {
            try walletStore.saveCards(cards)
            let statusText = toggledCoupon.isUsed() ? "used" : "available"
            showToast("\(toggledCoupon.name) marked \(statusText)")
        } catch {
            showToast("could not update coupon")
        }
    }

    func isEnriching(cardID: UUID) -> Bool {
        enrichingCardIDs.contains(cardID)
    }

    private func enrichCatalogs(for cardIDs: [UUID]) async {
        guard !cardIDs.isEmpty else { return }

        enrichingCardIDs.formUnion(cardIDs)
        showToast("researching card benefits...")

        for cardID in cardIDs {
            guard let card = cards.first(where: { $0.id == cardID }) else {
                enrichingCardIDs.remove(cardID)
                continue
            }

            do {
                let catalog = try await cardBenefitCatalogService.buildCatalog(for: card, config: config)
                applyCatalog(catalog, to: cardID)
            } catch {
                logElevenError("Failed to build benefit catalog for \(card.displayName)", error)
            }

            enrichingCardIDs.remove(cardID)
        }

        showToast("benefits ready")
    }

    private func applyCatalog(_ catalog: CardBenefitCatalog, to cardID: UUID) {
        guard let cardIndex = cards.firstIndex(where: { $0.id == cardID }) else {
            return
        }

        let existingCard = cards[cardIndex]
        let updatedCard = WalletCard(
            id: existingCard.id,
            displayName: existingCard.displayName,
            issuer: existingCard.issuer,
            network: existingCard.network,
            confidence: existingCard.confidence,
            visibleClues: existingCard.visibleClues,
            addedAt: existingCard.addedAt,
            benefits: catalog.benefits,
            coupons: catalog.coupons,
            benefitCatalogUpdatedAt: .now
        )

        cards[cardIndex] = updatedCard

        do {
            try walletStore.saveCards(cards)
        } catch {
            showToast("could not save benefits")
        }
    }

    func resetChatThread() {
        chatMessages = []
        voiceActivityScore = 0
        handledToolCallIDs.removeAll()
        groundedTranscriptEventIDs.removeAll()
        voiceStatusDetail = "tap mic to start"
        Task {
            await endVoiceConversation(resetTranscript: false)
        }
        chatConnectionState = .idle
    }

    func toggleVoiceConversation() {
        if let blockingMessage = chatBlockingMessage {
            logEleven("Voice toggle blocked: \(blockingMessage)")
            showToast(blockingMessage)
            return
        }

        Task {
            if isConversationLive || chatConnectionState == .connecting {
                await endVoiceConversation()
            } else {
                await startVoiceConversation()
            }
        }
    }

    func toggleMute() {
        guard let conversation else {
            logEleven("Mute requested without an active conversation")
            showToast("start voice first")
            return
        }

        Task {
            do {
                try await conversation.toggleMute()
                logEleven("Toggled mute. Muted now: \(conversation.isMuted)")
            } catch {
                logElevenError("Mute toggle failed", error)
                appendSystemMessage((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func startVoiceConversation() async {
        guard let agentID = config.elevenAgentID else {
            logEleven("Cannot start voice conversation: missing ELEVEN_AGENT_ID")
            showToast("set ELEVEN_AGENT_ID")
            return
        }

        logEleven("Starting voice conversation for agent \(agentID). Mode: \(config.elevenLabsAPIKey == nil ? "public" : "private token")")
        chatConnectionState = .connecting
        do {
            let conversationConfig = makeConversationConfig()
            let startedConversation: Conversation

            if let apiKey = config.elevenLabsAPIKey {
                let token: String
                if let prefetchedToken = takePrefetchedConversationToken() {
                    token = prefetchedToken
                } else {
                    token = try await fetchConversationToken(agentID: agentID, apiKey: apiKey)
                }
                logEleven("Using conversation token for agent \(agentID). Token length: \(token.count)")
                startedConversation = try await ElevenLabs.startConversation(
                    conversationToken: token,
                    config: conversationConfig
                )
                prefetchConversationTokenIfNeeded()
            } else {
                startedConversation = try await ElevenLabs.startConversation(
                    agentId: agentID,
                    config: conversationConfig
                )
            }

            conversation = startedConversation
            handledToolCallIDs.removeAll()
            groundedTranscriptEventIDs.removeAll()
            voiceActivityScore = 0
            isEndingConversation = false
            isConversationMuted = startedConversation.isMuted

            observeConversation(startedConversation)

            logEleven("Voice conversation started. Sending base context to Eleven.")
            try await startedConversation.updateContext(baseConversationContext())
            logEleven("Base context sent to Eleven successfully")
        } catch {
            logElevenError("Voice conversation failed to start", error)
            soundEffects.play(.error)
            chatConnectionState = .error("needs attention")
            voiceStatusDetail = "voice failed to start"
            appendSystemMessage((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            clearConversationState(resetStatus: false)
        }
    }

    private func endVoiceConversation(resetTranscript: Bool = true) async {
        isEndingConversation = true
        shouldResetStatusOnDisconnect = resetTranscript
        logEleven("Ending voice conversation. Reset transcript: \(resetTranscript)")

        if let conversation {
            await conversation.endConversation()
            logEleven("Conversation end requested")
            return
        }

        clearConversationState(resetStatus: resetTranscript)
        isEndingConversation = false
        prefetchConversationTokenIfNeeded()
    }

    private func makeConversationConfig() -> ConversationConfig {
        ConversationConfig(
            conversationOverrides: ConversationOverrides(textOnly: false),
            onAgentReady: { [weak self] in
                Task { @MainActor in
                    self?.logEleven("Agent ready")
                    self?.soundEffects.play(.sessionStarted)
                    self?.chatConnectionState = .connected
                    self?.voiceStatusDetail = "listening"
                }
            },
            onDisconnect: { [weak self] _ in
                Task { @MainActor in
                    self?.logEleven("Received onDisconnect callback from Eleven")
                    self?.handleDisconnect()
                }
            },
            onStartupStateChange: { [weak self] state in
                let description = String(describing: state).lowercased()
                Task { @MainActor in
                    self?.logEleven("Startup state changed: \(description)")
                    self?.applyStartupStateDescription(description)
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    self?.logEleven("Conversation onError callback: \(error.localizedDescription)")
                    self?.handleConversationError(error.localizedDescription)
                }
            },
            onUserTranscript: { [weak self] text, eventId in
                let transcript = text.cleanedLabel
                let resolvedEventID = "\(eventId)"
                Task { @MainActor in
                    self?.logEleven("Final user transcript received. Event \(resolvedEventID): \(transcript)")
                    await self?.handleFinalUserTranscript(transcript, eventID: resolvedEventID)
                }
            },
            onVadScore: { [weak self] score in
                Task { @MainActor in
                    self?.voiceActivityScore = score
                }
            }
        )
    }

    private func observeConversation(_ conversation: Conversation) {
        observationTasks.forEach { $0.cancel() }
        observationTasks = []

        observationTasks.append(
            Task { [weak self] in
                for await state in conversation.$state.values {
                    let description = String(describing: state).lowercased()
                    let isActive = state.isActive
                    await MainActor.run {
                        self?.logEleven("Observed conversation state: \(description), active: \(isActive)")
                        self?.applyObservedState(description: description, isActive: isActive)
                    }
                }
            }
        )

        observationTasks.append(
            Task { [weak self] in
                for await agentState in conversation.$agentState.values {
                    let description = String(describing: agentState).lowercased()
                    await MainActor.run {
                        self?.logEleven("Observed agent state: \(description)")
                        self?.applyAgentStateDescription(description)
                    }
                }
            }
        )

        observationTasks.append(
            Task { [weak self] in
                for await isMuted in conversation.$isMuted.values {
                    await MainActor.run {
                        self?.logEleven("Observed mute state change. Muted: \(isMuted)")
                        self?.applyMutedState(isMuted)
                    }
                }
            }
        )

        observationTasks.append(
            Task { [weak self] in
                for await messages in conversation.$messages.values {
                    let mapped = messages.compactMap { message -> ChatMessage? in
                        let text = message.content.cleanedLabel
                        guard !text.isEmpty else { return nil }

                        let role: ChatRole = message.role == .user ? .user : .agent

                        return ChatMessage(id: "\(message.id)", role: role, text: text)
                    }

                    await MainActor.run {
                        self?.logEleven("Observed message count: \(mapped.count)")
                        self?.applyConversationMessages(mapped)
                    }
                }
            }
        )

        observationTasks.append(
            Task { [weak self] in
                for await pendingToolCalls in conversation.$pendingToolCalls.values {
                    guard let self else { return }

                    for toolCall in pendingToolCalls {
                        let toolCallID = "\(toolCall.toolCallId)"
                        let shouldHandle = await MainActor.run {
                            self.registerToolCallIfNeeded(toolCallID)
                        }
                        guard shouldHandle else { continue }

                        Task { @MainActor [weak self] in
                            guard let self else { return }

                            do {
                                let toolName = toolCall.toolName
                                self.logEleven("Handling client tool call \(toolName) with id \(toolCallID)")
                                self.soundEffects.play(.toolStarted)

                                if toolName == "get_wallet_cards" {
                                    try await conversation.sendToolResult(
                                        for: toolCall.toolCallId,
                                        result: self.walletSummaryText()
                                    )
                                    self.soundEffects.play(.toolFinished)
                                    self.logEleven("Sent get_wallet_cards result for tool call \(toolCallID)")
                                    return
                                }

                                if toolName == "lookup_wallet_benefits" {
                                    let parameters = try toolCall.getParameters()
                                    let question = self.extractToolQuestion(from: parameters)

                                    guard let question, !question.isEmpty else {
                                        throw ChatError.invalidElevenResponse
                                    }

                                    let lookup = try await self.lookupBenefitsForCurrentTurn(question: question)

                                    try await conversation.sendToolResult(
                                        for: toolCall.toolCallId,
                                        result: lookup.toolSummaryText(walletCards: self.cards)
                                    )
                                    self.soundEffects.play(.toolFinished)
                                    self.logEleven("Sent lookup_wallet_benefits result for tool call \(toolCallID)")
                                    return
                                }

                                try await conversation.sendToolResult(
                                    for: toolCall.toolCallId,
                                    result: "Unknown client tool: \(toolName)",
                                    isError: true
                                )
                                self.soundEffects.play(.error)
                                self.logEleven("Returned unknown client tool error for tool call \(toolCallID)")
                            } catch {
                                self.logElevenError("Client tool call failed for \(toolCallID)", error)
                                self.soundEffects.play(.error)
                                try? await conversation.sendToolResult(
                                    for: toolCall.toolCallId,
                                    result: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
                                    isError: true
                                )
                            }
                        }
                    }
                }
            }
        )
    }

    private func fetchConversationToken(agentID: String, apiKey: String) async throws -> String {
        var components = URLComponents(string: "https://api.elevenlabs.io/v1/convai/conversation/token")!
        components.queryItems = [
            URLQueryItem(name: "agent_id", value: agentID)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        logEleven("Requesting Eleven conversation token for agent \(agentID)")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            logEleven("Token response was not an HTTP response")
            throw ChatError.invalidElevenResponse
        }

        logEleven("Token response status: \(httpResponse.statusCode)")

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8)?.cleanedLabel ?? "<non-utf8>"
            logEleven("Token request failed. Body: \(rawBody)")
            throw ChatError.elevenRequestFailed(
                statusCode: httpResponse.statusCode,
                message: Self.extractHTTPErrorMessage(from: data) ?? ""
            )
        }

        let payload = try JSONDecoder().decode(ConversationTokenPayload.self, from: data)
        logEleven("Token request succeeded")
        return payload.token
    }

    private func handleFinalUserTranscript(_ text: String, eventID: String) async {
        guard !text.isEmpty else { return }
        guard groundedTranscriptEventIDs.insert(eventID).inserted else { return }
        latestUserTranscriptEventID = eventID
        latestUserTranscriptText = text.normalizedSearchText
        currentTurnLookupTask?.cancel()
        currentTurnLookupTask = nil
        currentTurnLookupTaskTurnID = nil
        currentTurnLookupResult = nil
        currentTurnLookupResultTurnID = nil
        logEleven("Captured final user transcript for event \(eventID). Waiting for agent tool call instead of auto-running Firecrawl.")
    }

    private func lookupBenefitsForCurrentTurn(question: String) async throws -> BenefitLookupResult {
        let questionKey = question.normalizedSearchText
        let currentTurnID = latestUserTranscriptEventID

        if
            let currentTurnID,
            currentTurnLookupResultTurnID == currentTurnID,
            let currentTurnLookupResult
        {
            logEleven("Reusing existing lookup_wallet_benefits result for turn \(currentTurnID)")
            return currentTurnLookupResult
        }

        if
            let currentTurnID,
            currentTurnLookupTaskTurnID == currentTurnID,
            let currentTurnLookupTask
        {
            logEleven("Awaiting in-flight lookup_wallet_benefits task for turn \(currentTurnID)")
            let lookup = try await currentTurnLookupTask.value
            currentTurnLookupResult = lookup
            currentTurnLookupResultTurnID = currentTurnID
            return lookup
        }

        if let cachedLookup = cachedLookupResult(for: questionKey) {
            if let currentTurnID {
                currentTurnLookupResult = cachedLookup
                currentTurnLookupResultTurnID = currentTurnID
            }
            logEleven("Using cached lookup_wallet_benefits result for query: \(questionKey)")
            return cachedLookup
        }

        let lookupTask = Task { [cards = self.cards, config = self.config, firecrawlBenefits = self.firecrawlBenefits] in
            try await firecrawlBenefits.lookupBenefits(
                for: cards,
                useCase: question,
                config: config
            )
        }

        currentTurnLookupTask = lookupTask
        currentTurnLookupTaskTurnID = currentTurnID
        logEleven("Starting new lookup_wallet_benefits request for query: \(questionKey)")

        do {
            let lookup = try await lookupTask.value
            cacheLookupResult(lookup, for: questionKey)
            if let currentTurnID {
                currentTurnLookupResult = lookup
                currentTurnLookupResultTurnID = currentTurnID
            }
            currentTurnLookupTask = nil
            currentTurnLookupTaskTurnID = nil
            return lookup
        } catch {
            currentTurnLookupTask = nil
            currentTurnLookupTaskTurnID = nil
            throw error
        }
    }

    private func cachedLookupResult(for questionKey: String) -> BenefitLookupResult? {
        purgeExpiredLookupCache()

        guard let cached = cachedBenefitLookups[questionKey] else {
            return nil
        }

        return cached.result
    }

    private func cacheLookupResult(_ result: BenefitLookupResult, for questionKey: String) {
        purgeExpiredLookupCache()
        cachedBenefitLookups[questionKey] = CachedBenefitLookup(result: result, createdAt: .now)
    }

    private func purgeExpiredLookupCache() {
        let cutoff = Date().addingTimeInterval(-120)
        cachedBenefitLookups = cachedBenefitLookups.filter { $0.value.createdAt > cutoff }
    }

    private func handleDisconnect() {
        logEleven("Handling disconnect")
        let endedManually = isEndingConversation
        soundEffects.play(.sessionEnded)
        clearConversationState(resetStatus: shouldResetStatusOnDisconnect)
        isEndingConversation = false
        shouldResetStatusOnDisconnect = true
        prefetchConversationTokenIfNeeded()

        if !endedManually && !chatMessages.isEmpty {
            appendSystemMessage("Voice chat disconnected. Tap start voice to reconnect.")
        }
    }

    private func handleConversationError(_ message: String) {
        if isEndingConversation {
            logEleven("Ignoring conversation error during manual shutdown: \(message)")
            return
        }

        logEleven("Conversation error surfaced: \(message)")
        soundEffects.play(.error)
        chatConnectionState = .error("needs attention")
        voiceStatusDetail = "voice error"
        appendSystemMessage(message)
    }

    private func applyStartupStateDescription(_ description: String) {
        if description.contains("connecting") || description.contains("initial") || description.contains("auth") {
            chatConnectionState = .connecting
            voiceStatusDetail = "starting mic"
        }
    }

    private func applyObservedState(description: String, isActive: Bool) {
        if isActive || description.contains("active") {
            chatConnectionState = .connected
            if voiceStatusDetail == "tap mic to start" || voiceStatusDetail == "starting mic" {
                voiceStatusDetail = "listening"
            }
            return
        }

        if description.contains("connecting") {
            chatConnectionState = .connecting
            voiceStatusDetail = "starting mic"
            return
        }

        if description.contains("error") {
            if isEndingConversation {
                return
            }
            chatConnectionState = .error("needs attention")
            return
        }

        if !isEndingConversation {
            chatConnectionState = .idle
        }
    }

    private func applyAgentStateDescription(_ description: String) {
        if description.contains("speaking") {
            voiceStatusDetail = "speaking"
        } else if description.contains("listening") {
            voiceStatusDetail = "listening"
        } else if description.contains("thinking") {
            voiceStatusDetail = "thinking"
        }
    }

    private func applyMutedState(_ isMuted: Bool) {
        isConversationMuted = isMuted
    }

    private func applyConversationMessages(_ messages: [ChatMessage]) {
        let hasExistingTranscript = chatMessages.contains { $0.role != .system }
        if messages.isEmpty, hasExistingTranscript {
            logEleven("Ignoring empty conversation message sync so the transcript stays visible")
            return
        }

        let systemMessages = chatMessages.filter { $0.role == .system }
        chatMessages = messages + systemMessages
    }

    private func registerToolCallIfNeeded(_ id: String) -> Bool {
        handledToolCallIDs.insert(id).inserted
    }

    private func extractToolQuestion(from parameters: Any) -> String? {
        if let dictionary = parameters as? [String: Any] {
            return (
                toolParameterString(dictionary["question"]) ??
                toolParameterString(dictionary["use_case"]) ??
                toolParameterString(dictionary["query"])
            )?.cleanedLabel
        }

        return nil
    }

    private func toolParameterString(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }

        if let customStringConvertible = value as? CustomStringConvertible {
            let rendered = customStringConvertible.description.cleanedLabel
            return rendered.isEmpty ? nil : rendered
        }

        return nil
    }

    private func clearConversationState(resetStatus: Bool) {
        observationTasks.forEach { $0.cancel() }
        observationTasks = []
        currentTurnLookupTask?.cancel()
        conversation = nil
        handledToolCallIDs.removeAll()
        groundedTranscriptEventIDs.removeAll()
        latestUserTranscriptEventID = nil
        latestUserTranscriptText = nil
        currentTurnLookupTask = nil
        currentTurnLookupTaskTurnID = nil
        currentTurnLookupResult = nil
        currentTurnLookupResultTurnID = nil
        isConversationMuted = false
        voiceActivityScore = 0

        if resetStatus {
            chatConnectionState = .idle
            voiceStatusDetail = "tap mic to start"
        }
    }

    private func prefetchConversationTokenIfNeeded() {
        guard
            tokenPrefetchTask == nil,
            prefetchedConversationToken == nil || !hasFreshPrefetchedConversationToken,
            let agentID = config.elevenAgentID,
            let apiKey = config.elevenLabsAPIKey
        else {
            return
        }

        tokenPrefetchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            defer { self.tokenPrefetchTask = nil }

            do {
                self.logEleven("Prefetching Eleven conversation token for agent \(agentID)")
                let token = try await self.fetchConversationToken(agentID: agentID, apiKey: apiKey)
                self.prefetchedConversationToken = token
                self.prefetchedConversationTokenDate = .now
                self.logEleven("Prefetched conversation token is ready")
            } catch {
                self.logElevenError("Failed to prefetch Eleven token", error)
            }
        }
    }

    private var hasFreshPrefetchedConversationToken: Bool {
        guard let fetchedAt = prefetchedConversationTokenDate else {
            return false
        }

        return Date().timeIntervalSince(fetchedAt) < 9 * 60
    }

    private func takePrefetchedConversationToken() -> String? {
        guard hasFreshPrefetchedConversationToken, let token = prefetchedConversationToken else {
            prefetchedConversationToken = nil
            prefetchedConversationTokenDate = nil
            return nil
        }

        prefetchedConversationToken = nil
        prefetchedConversationTokenDate = nil
        logEleven("Using prefetched Eleven conversation token")
        return token
    }

    private func baseConversationContext() -> String {
        [
            "You are CardAssist, a concise spoken credit-card concierge.",
            "Only recommend cards from the wallet the client provides.",
            "For merchant, travel, dining, hotel, shopping, wellness, perk, or benefit questions, call the lookup_wallet_benefits client tool before answering when it is available.",
            "Call lookup_wallet_benefits at most once per user turn. After the client returns results, answer directly instead of calling it again for the same question.",
            "When calling lookup_wallet_benefits, do not pass the raw transcript with filler words. Pass a short search brief focused on the likely benefit or merchant, such as 'gym membership equinox credit fitness benefits', 'gym clothes lululemon shopping credit', or 'hotel booking fine hotels resorts hotel collection the edit'.",
            "If the tool is not available, use the contextual updates the client sends after each user question.",
            "When grounded research mentions a named benefit or hotel program, say its name out loud.",
            "Keep answers short and natural for voice.",
            "",
            "Saved wallet:",
            walletSummaryText()
        ]
        .joined(separator: "\n")
    }

    private func walletSummaryText() -> String {
        guard !cards.isEmpty else {
            return "The wallet is currently empty."
        }

        return cards.enumerated().map { index, card in
            var lines = ["\(index + 1). \(card.displayName) — \(card.subtitle)"]

            if !card.benefits.isEmpty {
                lines.append("Benefits: \(card.benefits.map(\.name).joined(separator: ", "))")
            }

            if !card.coupons.isEmpty {
                let couponSummary = card.coupons.map { coupon in
                    "\(coupon.name) [\(coupon.cadence.title)] = \(coupon.isUsed() ? "used" : "available")"
                }
                .joined(separator: ", ")
                lines.append("Coupons: \(couponSummary)")
            }

            return lines.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
    }

    private func appendSystemMessage(_ text: String) {
        let cleaned = text.cleanedLabel
        guard !cleaned.isEmpty else { return }

        if chatMessages.last?.role == .system, chatMessages.last?.text == cleaned {
            return
        }

        logEleven("System message appended: \(cleaned)")
        chatMessages.append(ChatMessage(role: .system, text: cleaned))
    }

    private func logEleven(_ message: String) {
        print("[Eleven] \(message)")
    }

    private func logElevenError(_ prefix: String, _ error: Error) {
        let localized = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        print("[Eleven] \(prefix): \(localized)")
        print("[Eleven] Error type: \(type(of: error))")
        print("[Eleven] Error detail: \(String(describing: error))")
    }

    private static func extractHTTPErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let detail = json["detail"] as? [String: Any], let message = detail["message"] as? String {
            return message
        }

        if let detail = json["detail"] as? String {
            return detail
        }

        if let message = json["message"] as? String {
            return message
        }

        if
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        {
            return message
        }

        return nil
    }

    private func showToast(_ text: String) {
        let nextToast = ToastState(text: text)
        toast = nextToast

        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if toast == nextToast {
                withAnimation(.easeOut(duration: 0.2)) {
                    toast = nil
                }
            }
        }
    }

    private struct ConversationTokenPayload: Decodable {
        let token: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let token = try container.decodeIfPresent(String.self, forKey: .token), !token.isEmpty {
                self.token = token
                return
            }

            if let token = try container.decodeIfPresent(String.self, forKey: .conversationToken), !token.isEmpty {
                self.token = token
                return
            }

            throw DecodingError.keyNotFound(
                CodingKeys.token,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected `token` or `conversation_token` in Eleven token response."
                )
            )
        }

        private enum CodingKeys: String, CodingKey {
            case token
            case conversationToken = "conversation_token"
        }
    }

    private struct CachedBenefitLookup {
        let result: BenefitLookupResult
        let createdAt: Date
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.canvas.ignoresSafeArea()

            currentScreen
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 126)

            TabBar(selectedTab: model.selectedTab) { tab in
                model.switchTab(tab)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                Text(toast.text)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .brutalCapsuleSurface(fill: Palette.green, lineWidth: 3, shadow: 6)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $model.isAddCardsPresented) {
            AddCardsSheet()
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch model.selectedTab {
        case .cards:
            CardsTab()
        case .chat:
            ChatTab()
        }
    }
}

struct CardsTab: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedCardSheet: SelectedCardSheet?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DecorativeBlock(color: Palette.yellow, size: 60)
                .offset(x: 4, y: 0)
            DecorativeBlock(color: Palette.pink, size: 72)
                .offset(x: -14, y: 72)

            VStack(alignment: .leading, spacing: 18) {
                header

                if model.cards.isEmpty {
                    EmptyCardsState()
                } else {
                    cardsList
                }
            }
            .padding(.top, 2)
        }
        .sheet(item: $selectedCardSheet) { sheet in
            CardDetailSheet(cardID: sheet.id)
                .presentationDetents([.fraction(0.92)])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("my cards")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)

                Pill(text: model.cardsCountLabel, fill: Palette.green)
            }

            Spacer()

            Button(action: model.presentAddCards) {
                Text("+")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 60, height: 60)
                    .brutalRoundedSurface(fill: Palette.yellow, cornerRadius: 18, lineWidth: 3, shadow: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add cards")
        }
    }

    private var cardsList: some View {
        List {
            ForEach(model.cards) { card in
                Button {
                    selectedCardSheet = SelectedCardSheet(id: card.id)
                } label: {
                    CardRow(card: card, isEnriching: model.isEnriching(cardID: card.id))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .padding(.bottom, 18)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        model.deleteCard(card)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

struct EmptyCardsState: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start by scanning one photo with all your card fronts.")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("We’ll detect the cards and save them locally on your device.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.8))

            Button("add cards") {
                model.presentAddCards()
            }
            .buttonStyle(BrutalActionButtonStyle(fill: Palette.yellow))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalRoundedSurface(fill: .white, cornerRadius: 30, lineWidth: 3, shadow: 8)
        .padding(.top, 8)
    }
}

struct CardRow: View {
    let card: WalletCard
    let isEnriching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.displayName)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(card.subtitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            if isEnriching {
                Text("researching benefits and coupons...")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.72))
            } else if !card.benefits.isEmpty || !card.coupons.isEmpty {
                HStack(spacing: 10) {
                    if !card.benefits.isEmpty {
                        Pill(text: card.benefitCountLabel, fill: Palette.cream)
                    }
                    if !card.coupons.isEmpty {
                        Pill(text: card.couponCountLabel, fill: .white)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalRoundedSurface(fill: card.tint, cornerRadius: 26, lineWidth: 3, shadow: 8)
    }
}

private struct SelectedCardSheet: Identifiable {
    let id: UUID
}

struct CardDetailSheet: View {
    @EnvironmentObject private var model: AppModel

    let cardID: UUID

    private var card: WalletCard? {
        model.cards.first(where: { $0.id == cardID })
    }

    private var groupedCoupons: [(CouponCadence, [CardCoupon])] {
        guard let card else { return [] }

        return CouponCadence.allCases.compactMap { cadence in
            let coupons = card.coupons.filter { $0.cadence == cadence }
            return coupons.isEmpty ? nil : (cadence, coupons)
        }
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            if let card {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(card.displayName)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.ink)

                        Text(card.subtitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.72))

                        if model.isEnriching(cardID: card.id) {
                            catalogLoadingCard
                        }

                        if !card.benefits.isEmpty {
                            BenefitSection(benefits: card.benefits)
                        }

                        if !groupedCoupons.isEmpty {
                            CouponSection(
                                groupedCoupons: groupedCoupons,
                                onToggle: { couponID in
                                    model.toggleCouponUsage(cardID: card.id, couponID: couponID)
                                }
                            )
                        }

                        if card.benefits.isEmpty && card.coupons.isEmpty && !model.isEnriching(cardID: card.id) {
                            EmptyCatalogState()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 40)
                }
            } else {
                EmptyCatalogState()
                    .padding(20)
            }
        }
    }

    private var catalogLoadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Palette.ink)

            Text("researching benefits and coupons")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalRoundedSurface(fill: Palette.yellow, cornerRadius: 20, lineWidth: 3, shadow: 6)
    }
}

struct BenefitSection: View {
    let benefits: [CardBenefit]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("benefits")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            ForEach(benefits) { benefit in
                VStack(alignment: .leading, spacing: 8) {
                    Text(benefit.name)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)

                    Text(benefit.details)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.78))

                    Text(benefit.sourceTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.56))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brutalRoundedSurface(fill: .white, cornerRadius: 20, lineWidth: 3, shadow: 6)
            }
        }
    }
}

struct CouponSection: View {
    let groupedCoupons: [(CouponCadence, [CardCoupon])]
    let onToggle: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("coupons")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            ForEach(groupedCoupons, id: \.0) { cadence, coupons in
                VStack(alignment: .leading, spacing: 12) {
                    Text(cadence.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)

                    ForEach(coupons) { coupon in
                        Button {
                            onToggle(coupon.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: coupon.isUsed() ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(Palette.ink)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(coupon.name)
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundStyle(Palette.ink)

                                    Text(coupon.details)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Palette.ink.opacity(0.78))

                                    Text(coupon.isUsed() ? "used this period" : "still available")
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(Palette.ink.opacity(0.56))
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .brutalRoundedSurface(fill: .white, cornerRadius: 20, lineWidth: 3, shadow: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct EmptyCatalogState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No benefit catalog yet.")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("Once we research this card, benefits and coupons will show up here.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.74))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brutalRoundedSurface(fill: .white, cornerRadius: 24, lineWidth: 3, shadow: 6)
    }
}

struct ChatTab: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DecorativeBlock(color: Palette.pink, size: 54)
                .offset(x: -8, y: 0)
            DecorativeBlock(color: Palette.blue, size: 86)
                .offset(x: -4, y: 72)

            VStack(alignment: .leading, spacing: 14) {
                header
                ChatTranscript()
                VoiceControlPanel()
            }
            .padding(.top, 2)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("chat")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Spacer()

            if !model.chatMessages.isEmpty {
                Button("new") {
                    model.resetChatThread()
                }
                .buttonStyle(BrutalActionButtonStyle(fill: .white, width: 82))
            }
        }
    }
}

struct ChatTranscript: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if model.chatMessages.isEmpty {
                        ChatEmptyState()
                    } else {
                        ForEach(model.chatMessages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom")
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .brutalRoundedSurface(fill: .white, cornerRadius: 30, lineWidth: 3, shadow: 8)
            .onChange(of: model.chatMessages.count) { _, _ in
                withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }
        }
    }
}

struct ChatEmptyState: View {
    private let suggestions = [
        "I’m at McDonald’s. Which card should I use?",
        "Do I have any perks for joining a gym?",
        "I need to book a hotel in San Francisco. What should I use?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ask what you’re about to spend on")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("The transcript will show up here while you talk.")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.78))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .brutalRoundedSurface(fill: Palette.cream, cornerRadius: 18, lineWidth: 3, shadow: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 30)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.7))

                Text(message.text)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: 280, alignment: .leading)
            .brutalRoundedSurface(fill: fill, cornerRadius: 24, lineWidth: 3, shadow: 6)

            if message.role != .user {
                Spacer(minLength: 30)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch message.role {
        case .user:
            return "you"
        case .agent:
            return "agent"
        case .system:
            return "status"
        }
    }

    private var fill: Color {
        switch message.role {
        case .user:
            return Palette.yellow
        case .agent:
            return .white
        case .system:
            return Palette.blue
        }
    }
}

struct VoiceControlPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            Button(action: model.toggleVoiceConversation) {
                HStack(spacing: 18) {
                    VoiceActivityBadge(
                        isLive: model.isVoiceLive,
                        activity: model.voiceActivityScore
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.voiceButtonLabel)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.ink)

                        if model.isVoiceLive {
                            Text(model.chatStatusLabel)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Palette.ink.opacity(0.72))
                        } else {
                            Text(model.chatCardsLabel)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Palette.ink.opacity(0.72))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 108)
                .brutalRoundedSurface(
                    fill: model.isVoiceLive ? Palette.pink : Palette.yellow,
                    cornerRadius: 28,
                    lineWidth: 4,
                    shadow: 8
                )
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggleVoice)
            .opacity(model.canToggleVoice ? 1 : 0.7)

            if model.canToggleMute {
                Button(model.muteButtonLabel) {
                    model.toggleMute()
                }
                .buttonStyle(BrutalActionButtonStyle(fill: .white, width: 120))
            }
        }
    }
}

struct VoiceActivityBadge: View {
    let isLive: Bool
    let activity: Double

    private var clampedActivity: Double {
        min(max(activity, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(isLive ? 0.55 : 0.92))
                .frame(width: 66, height: 66)
                .overlay(
                    Circle()
                        .stroke(Palette.ink, lineWidth: 3)
                )

            if isLive {
                Circle()
                    .stroke(Palette.ink.opacity(0.18 + clampedActivity * 0.42), lineWidth: 3)
                    .frame(width: 82 + clampedActivity * 12, height: 82 + clampedActivity * 12)
                    .animation(.easeInOut(duration: 0.18), value: clampedActivity)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Palette.ink)
                            .frame(width: 5, height: barHeight(for: index))
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: clampedActivity)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(width: 84, height: 84)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeights: [CGFloat] = [14, 24, 18]
        let extraHeights: [CGFloat] = [10, 18, 12]
        return baseHeights[index] + extraHeights[index] * clampedActivity
    }
}

struct AddCardsSheet: View {
    @EnvironmentObject private var model: AppModel

    @State private var manualEditDraft: ManualEditDraft?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedImageData: Data?
    @State private var selectedDetectedCardIDs: Set<UUID> = []
    @State private var isLoadingPhoto = false
    @State private var isShowingCamera = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.canvas.ignoresSafeArea()

            DecorativeBlock(color: Palette.green, size: 66)
                .padding(.top, 86)
                .padding(.trailing, 24)

            VStack(alignment: .leading, spacing: 22) {
                header
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await loadSelectedPhoto(from: newValue)
            }
        }
        .onChange(of: model.detectedCards) { _, newValue in
            selectedDetectedCardIDs = Set(newValue.map(\.id))
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                handleCapturedImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $manualEditDraft) { draft in
            ManualCardEditSheet(
                draft: draft,
                onSave: { updatedDraft in
                    model.updateDetectedCard(
                        updatedDraft.id,
                        cardType: updatedDraft.cardType,
                        issuer: updatedDraft.issuer
                    )
                    selectedDetectedCardIDs.insert(updatedDraft.id)
                    manualEditDraft = nil
                },
                onCancel: {
                    manualEditDraft = nil
                }
            )
            .presentationDetents([.fraction(0.42)])
            .presentationDragIndicator(.visible)
        }
        .safeAreaInset(edge: .bottom) {
            if showsReview {
                reviewFooter
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .background(Palette.canvas.opacity(0.96))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("add cards")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }

            Spacer()

            Button(action: model.dismissAddCards) {
                Text("×")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 54, height: 54)
                    .brutalRoundedSurface(fill: .white, cornerRadius: 16, lineWidth: 3, shadow: 6)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isAnalyzingCards {
            loadingState
        } else if showsReview {
            reviewState
        } else {
            captureState
        }
    }

    private var showsReview: Bool {
        !model.isAnalyzingCards && !model.detectedCards.isEmpty
    }

    private var selectedDetectedCards: [DetectedCard] {
        model.detectedCards.filter { selectedDetectedCardIDs.contains($0.id) }
    }

    private var captureState: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                pickerCard

                if let scanError = model.scanError {
                    ErrorCard(message: scanError)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(Palette.ink)
                .scaleEffect(1.5)

            Text("finding your cards")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("hang tight for a sec")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("keep what looks right")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)

            Text("\(selectedDetectedCards.count) of \(model.detectedCards.count) selected")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.72))

            ScrollView(showsIndicators: false) {
                DetectedCardsList(
                    cards: model.detectedCards,
                    selectedIDs: selectedDetectedCardIDs,
                    onToggle: toggleDetectedCardSelection,
                    onEditManually: startManualEdit
                )
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var reviewFooter: some View {
        VStack(spacing: 12) {
            Button("confirm") {
                model.saveDetectedCards(selectedDetectedCards)
            }
            .buttonStyle(BrutalActionButtonStyle(fill: Palette.green))
            .disabled(selectedDetectedCards.isEmpty)
            .opacity(selectedDetectedCards.isEmpty ? 0.65 : 1)

            Button("scan again") {
                clearSelectedImage()
                model.resetScanSession()
            }
            .buttonStyle(BrutalActionButtonStyle(fill: .white))
        }
    }

    private var pickerCard: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.clear)
                    .frame(height: 360)
                    .brutalRoundedSurface(fill: .white, cornerRadius: 30, lineWidth: 3, shadow: 8)

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .padding(10)
                } else {
                    PlaceholderWalletStage()
                }

                if isLoadingPhoto {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Palette.ink)
                        .scaleEffect(1.3)
                }
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button(selectedImage == nil ? "take photo" : "retake photo") {
                    isShowingCamera = true
                }
                .buttonStyle(BrutalActionButtonStyle(fill: Palette.yellow))
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text(selectedImage == nil ? "pick photo instead" : "choose from library")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BrutalActionButtonStyle(fill: .white))

            Button {
                guard let selectedImageData else { return }
                Task {
                    await model.analyzePhoto(selectedImageData)
                }
            } label: {
                if model.isAnalyzingCards {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Palette.ink)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("analyze")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(BrutalActionButtonStyle(fill: Palette.blue))
            .disabled(selectedImageData == nil || !model.canAnalyzeSelectedPhoto)
            .opacity((selectedImageData == nil || !model.canAnalyzeSelectedPhoto) ? 0.65 : 1)
        }
    }

    private func loadSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoadingPhoto = true
        model.resetScanSession()
        defer { isLoadingPhoto = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AppError.invalidPhoto
            }

            guard let image = UIImage(data: data) else {
                throw AppError.invalidPhoto
            }

            selectedImage = image
            selectedImageData = image.jpegData(compressionQuality: 0.9) ?? data
        } catch {
            clearSelectedImage()
            model.scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleCapturedImage(_ image: UIImage) {
        selectedPhotoItem = nil
        model.resetScanSession()
        selectedImage = image
        selectedImageData = image.jpegData(compressionQuality: 0.9)
    }

    private func clearSelectedImage() {
        selectedPhotoItem = nil
        selectedImage = nil
        selectedImageData = nil
        selectedDetectedCardIDs = []
    }

    private func toggleDetectedCardSelection(_ id: UUID) {
        if selectedDetectedCardIDs.contains(id) {
            selectedDetectedCardIDs.remove(id)
        } else {
            selectedDetectedCardIDs.insert(id)
        }
    }

    private func startManualEdit(_ cardID: UUID) {
        guard let card = model.detectedCards.first(where: { $0.id == cardID }) else {
            return
        }

        manualEditDraft = ManualEditDraft(
            id: card.id,
            cardType: card.displayName,
            issuer: card.issuer
        )
    }
}

struct PlaceholderWalletStage: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.pink)
                .frame(width: 136, height: 84)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 3)
                )
                .rotationEffect(.degrees(-12))
                .offset(x: -62, y: -74)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.blue)
                .frame(width: 146, height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 3)
                )
                .rotationEffect(.degrees(8))
                .offset(x: 44, y: -6)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.yellow)
                .frame(width: 156, height: 96)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.ink, lineWidth: 3)
                )
                .rotationEffect(.degrees(4))
                .offset(x: 4, y: 104)

            Text("one photo. front sides only.")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Palette.paper)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(Palette.ink))
        }
    }
}

struct DetectedCardsList: View {
    let cards: [DetectedCard]
    let selectedIDs: Set<UUID>
    let onToggle: (UUID) -> Void
    let onEditManually: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(cards) { card in
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(card.displayName)
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Pill(text: card.confidenceLabel, fill: .white)
                        }

                        Text(card.subtitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.ink)

                        Button {
                            onEditManually(card.id)
                        } label: {
                            Text("edit manually")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .brutalCapsuleSurface(fill: Palette.yellow, lineWidth: 3, shadow: 0)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: selectedIDs.contains(card.id) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brutalRoundedSurface(
                    fill: selectedIDs.contains(card.id) ? Palette.cream : .white,
                    cornerRadius: 22,
                    lineWidth: 3,
                    shadow: 6
                )
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    onToggle(card.id)
                }
            }
        }
    }
}

struct ErrorCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Palette.ink)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brutalRoundedSurface(fill: Palette.pink, cornerRadius: 22, lineWidth: 3, shadow: 6)
    }
}

struct ManualEditDraft: Identifiable, Equatable {
    let id: UUID
    var cardType: String
    var issuer: String
}

struct ManualCardEditSheet: View {
    @State private var cardType: String
    @State private var issuer: String

    let draft: ManualEditDraft
    let onSave: (ManualEditDraft) -> Void
    let onCancel: () -> Void

    init(draft: ManualEditDraft, onSave: @escaping (ManualEditDraft) -> Void, onCancel: @escaping () -> Void) {
        self.draft = draft
        self.onSave = onSave
        self.onCancel = onCancel
        _cardType = State(initialValue: draft.cardType)
        _issuer = State(initialValue: draft.issuer)
    }

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("edit card")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)

                    Spacer()

                    Button(action: onCancel) {
                        Text("×")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 52, height: 52)
                            .brutalRoundedSurface(fill: .white, cornerRadius: 16, lineWidth: 3, shadow: 6)
                    }
                    .buttonStyle(.plain)
                }

                ManualField(label: "card type", text: $cardType, placeholder: "Chase Sapphire Reserve")
                ManualField(label: "issuer", text: $issuer, placeholder: "Chase")

                Spacer(minLength: 0)

                Button("save") {
                    onSave(
                        ManualEditDraft(
                            id: draft.id,
                            cardType: cardType,
                            issuer: issuer
                        )
                    )
                }
                .buttonStyle(BrutalActionButtonStyle(fill: Palette.green))
                .disabled(cardType.cleanedLabel.isEmpty || issuer.cleanedLabel.isEmpty)
                .opacity(cardType.cleanedLabel.isEmpty || issuer.cleanedLabel.isEmpty ? 0.65 : 1)
            }
            .padding(20)
        }
    }
}

struct ManualField: View {
    let label: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .brutalRoundedSurface(fill: .white, cornerRadius: 20, lineWidth: 3, shadow: 6)
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }
    }
}

struct TabBar: View {
    let selectedTab: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: { onSelect(tab) }) {
                    Text(tab.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .brutalRoundedSurface(
                            fill: selectedTab == tab ? Palette.yellow : .white,
                            cornerRadius: 22,
                            lineWidth: 3,
                            shadow: 6
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct Pill: View {
    let text: String
    let fill: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .brutalCapsuleSurface(fill: fill, lineWidth: 3, shadow: 0)
    }
}

struct DecorativeBlock: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 3)
            )
            .rotationEffect(.degrees(8))
    }
}

struct BrutalActionButtonStyle: ButtonStyle {
    let fill: Color
    var width: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .frame(width: width)
            .padding(.vertical, 16)
            .brutalRoundedSurface(fill: fill, cornerRadius: 20, lineWidth: 3, shadow: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct BrutalRoundedSurfaceModifier: ViewModifier {
    let fill: Color
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let shadow: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Palette.ink)
                        .offset(x: shadow, y: shadow)

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fill)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.ink, lineWidth: lineWidth)
            }
    }
}

private struct BrutalCapsuleSurfaceModifier: ViewModifier {
    let fill: Color
    let lineWidth: CGFloat
    let shadow: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(Palette.ink)
                        .offset(x: shadow, y: shadow)

                    Capsule()
                        .fill(fill)
                }
            }
            .overlay {
                Capsule()
                    .stroke(Palette.ink, lineWidth: lineWidth)
            }
    }
}

private extension View {
    func brutalRoundedSurface(fill: Color, cornerRadius: CGFloat, lineWidth: CGFloat, shadow: CGFloat) -> some View {
        modifier(
            BrutalRoundedSurfaceModifier(
                fill: fill,
                cornerRadius: cornerRadius,
                lineWidth: lineWidth,
                shadow: shadow
            )
        )
    }

    func brutalCapsuleSurface(fill: Color, lineWidth: CGFloat, shadow: CGFloat) -> some View {
        modifier(
            BrutalCapsuleSurfaceModifier(
                fill: fill,
                lineWidth: lineWidth,
                shadow: shadow
            )
        )
    }
}

private enum CardTintPalette {
    static let colors: [Color] = [
        Palette.blue,
        Palette.cream,
        Palette.pink,
        Palette.green,
        Palette.yellow
    ]

    static func color(for displayName: String) -> Color {
        let bucket = abs(displayName.normalizedCardKey.hashValue) % colors.count
        return colors[bucket]
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var cleanedLabel: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    var normalizedCardKey: String {
        cleanedLabel.lowercased()
    }

    var normalizedSearchText: String {
        cleanedLabel.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Palette {
    static let canvas = Color(red: 247.0 / 255.0, green: 243.0 / 255.0, blue: 234.0 / 255.0)
    static let ink = Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 18.0 / 255.0)
    static let paper = Color(red: 250.0 / 255.0, green: 247.0 / 255.0, blue: 240.0 / 255.0)
    static let blue = Color(red: 110.0 / 255.0, green: 155.0 / 255.0, blue: 1.0)
    static let pink = Color(red: 1.0, green: 143.0 / 255.0, blue: 163.0 / 255.0)
    static let green = Color(red: 185.0 / 255.0, green: 242.0 / 255.0, blue: 140.0 / 255.0)
    static let yellow = Color(red: 1.0, green: 217.0 / 255.0, blue: 90.0 / 255.0)
    static let cream = Color(red: 1.0, green: 245.0 / 255.0, blue: 230.0 / 255.0)
}
