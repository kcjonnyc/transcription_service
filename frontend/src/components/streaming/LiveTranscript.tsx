import { useEffect, useRef } from 'react';
import { StreamingSegment, StreamingPhase } from '../../types/streaming';

interface LiveTranscriptProps {
  phase: StreamingPhase;
  segments: StreamingSegment[];
  interimText: string;
}

function LiveTranscript({ phase, segments, interimText }: LiveTranscriptProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [segments, interimText]);

  const hasContent = segments.length > 0 || interimText.length > 0;

  if (phase === 'idle' && !hasContent) {
    return null;
  }

  return (
    <div className="live-transcript">
      <h3 className="section-title">Live Transcript</h3>

      {!hasContent && (phase === 'connecting' || phase === 'recording') && (
        <div className="live-transcript-empty">
          <span className="live-transcript-placeholder">
            Start speaking and your words will appear here...
          </span>
        </div>
      )}

      {hasContent && (
        <div className="live-transcript-content">
          {segments.map((segment) => (
            <span key={segment.item_id} className="live-segment">
              {segment.text}{' '}
            </span>
          ))}
          {interimText && (
            <span className="live-interim">
              {interimText}
              <span className="typing-cursor" />
            </span>
          )}
          <div ref={bottomRef} />
        </div>
      )}
    </div>
  );
}

export default LiveTranscript;
