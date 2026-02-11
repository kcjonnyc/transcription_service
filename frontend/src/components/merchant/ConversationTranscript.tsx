import { Segment } from '../../types';

interface ConversationTranscriptProps {
  segments: Segment[];
  speakerLabels: Record<string, string>;
}

const SPEAKER_COLORS: Record<number, { bg: string; border: string; text: string }> = {
  0: { bg: '#eff6ff', border: '#3b82f6', text: '#1e40af' },
  1: { bg: '#f0fdf4', border: '#22c55e', text: '#166534' },
  2: { bg: '#fef3c7', border: '#f59e0b', text: '#92400e' },
  3: { bg: '#fdf2f8', border: '#ec4899', text: '#9d174d' },
  4: { bg: '#f5f3ff', border: '#8b5cf6', text: '#5b21b6' },
};

function formatTimestamp(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
}

function ConversationTranscript({ segments, speakerLabels }: ConversationTranscriptProps) {
  const uniqueSpeakers = [...new Set(segments.map((s) => s.speaker))];
  const speakerIndexMap: Record<string, number> = {};
  uniqueSpeakers.forEach((speaker, index) => {
    speakerIndexMap[speaker] = index;
  });

  function getSpeakerColor(speaker: string) {
    const index = speakerIndexMap[speaker] ?? 0;
    return SPEAKER_COLORS[index % Object.keys(SPEAKER_COLORS).length];
  }

  function getSpeakerDisplayName(speaker: string): string {
    return speakerLabels[speaker] || speaker;
  }

  return (
    <div className="conversation-transcript">
      <h3 className="section-title">Conversation</h3>
      <div className="transcript-messages">
        {segments.map((segment) => {
          const colors = getSpeakerColor(segment.speaker);
          const isEven = (speakerIndexMap[segment.speaker] ?? 0) % 2 === 0;

          return (
            <div
              key={segment.id}
              className={`message ${isEven ? 'message-left' : 'message-right'}`}
            >
              <div
                className="message-bubble"
                style={{
                  backgroundColor: colors.bg,
                  borderLeft: isEven ? `4px solid ${colors.border}` : 'none',
                  borderRight: !isEven ? `4px solid ${colors.border}` : 'none',
                }}
              >
                <div className="message-header">
                  <span
                    className="message-speaker"
                    style={{ color: colors.text }}
                  >
                    {getSpeakerDisplayName(segment.speaker)}
                  </span>
                  <span className="message-timestamp">
                    {formatTimestamp(segment.start)} - {formatTimestamp(segment.end)}
                  </span>
                </div>
                <p className="message-text">{segment.text}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default ConversationTranscript;
