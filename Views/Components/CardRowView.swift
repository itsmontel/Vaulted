import SwiftUI

// MARK: - CardRowView
struct CardRowView: View {
    let card: CardEntity
    var isRedacted: Bool = false

    private var dateString: String {
        guard let d = card.createdAt else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Title + type icon
                HStack(spacing: 6) {
                    Image(systemName: card.isVoice ? "waveform" : "doc.text")
                        .font(.caption)
                        .foregroundColor(.accentGold)
                    Text(isRedacted ? "Private card" : (card.title ?? "Untitled"))
                        .font(.cardTitle)
                        .foregroundColor(.inkPrimary)
                        .lineLimit(1)
                        .redacted(reason: isRedacted ? .placeholder : [])
                }
                Spacer()
                HStack(spacing: 6) {
                    if card.starred && !isRedacted {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.accentGold)
                    }
                    Text(dateString)
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
            }

            // Snippet (hide transcript for voice cards in list; show for text cards only)
            if !card.isVoice {
                Text(isRedacted ? "••••••••••••••••" : (card.snippet ?? ""))
                    .font(.cardSnippet)
                    .foregroundColor(.inkMuted)
                    .lineLimit(2)
                    .redacted(reason: isRedacted ? .placeholder : [])
            }

            HStack(spacing: 6) {
                // Duration badge for voice
                if card.isVoice && !isRedacted {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text(formatDuration(card.durationSec))
                    }
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.borderMuted.opacity(0.4))
                    .cornerRadius(4)
                }

                // Tags
                if !isRedacted {
                    ForEach(card.tagList.prefix(3), id: \.self) { tag in
                        TagChip(label: tag)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.cardSurface)
        .vaultCard()
    }

    private func formatDuration(_ secs: Double) -> String {
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Preview
#Preview {
    let pc = PersistenceController.preview
    let card = CardRepository(pc: pc).fetchAllCards().first!
    CardRowView(card: card)
        .padding()
        .background(Color.paperBackground)
}
