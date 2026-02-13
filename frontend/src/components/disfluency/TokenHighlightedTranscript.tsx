import React from 'react';
import { LlmAnnotatedSentence, LlmDisfluency, Pause } from '../../types';

interface TokenHighlightedTranscriptProps {
  sentences: LlmAnnotatedSentence[];
  pauses?: Pause[];
  showCleanSentences: boolean;
}

const CATEGORY_COLORS: Record<string, { bg: string; label: string }> = {
  filler_words: { bg: '#fef3c7', label: 'Filler Word' },
  consecutive_word_repetitions: { bg: '#fed7aa', label: 'Word Repetition' },
  sound_repetitions: { bg: '#fecaca', label: 'Sound Repetition (Stutter)' },
  prolongations: { bg: '#e9d5ff', label: 'Prolongation' },
  revisions: { bg: '#bfdbfe', label: 'Revision' },
  partial_words: { bg: '#fca5a5', label: 'Partial Word' },
};

function getStruggleColor(score: number): string {
  if (score <= 2) return '#22c55e';
  if (score <= 5) return '#f59e0b';
  return '#ef4444';
}

function normalizeWord(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9']/g, '');
}

function renderTokenHighlightedText(
  sentence: LlmAnnotatedSentence,
  pauses: Pause[]
) {
  // Build a map of after_word → pause for quick lookup
  const pauseAfterWord = new Map<string, Pause>();
  pauses.forEach((p) => {
    pauseAfterWord.set(normalizeWord(p.after_word), p);
  });

  // Build a lookup: tokenIndex → { disfluency, rangeStart, rangeEnd }
  const tokenLookup = new Map<
    number,
    { disfluency: LlmDisfluency; rangeStart: number; rangeEnd: number }
  >();
  for (const d of sentence.disfluencies) {
    for (const range of d.ranges) {
      for (let idx = range.start; idx <= range.end; idx++) {
        tokenLookup.set(idx, {
          disfluency: d,
          rangeStart: range.start,
          rangeEnd: range.end,
        });
      }
    }
  }

  const elements: React.ReactNode[] = [];
  let i = 0;

  while (i < sentence.tokens.length) {
    const token = sentence.tokens[i];
    const lookup = tokenLookup.get(token.index);
    const separator = i > 0 ? ' ' : '';

    if (lookup && token.index === lookup.rangeStart) {
      // Collect all tokens in this range into a single highlighted span
      const rangeTokens: string[] = [];
      let lastTokenIndex = i;
      for (let idx = i; idx < sentence.tokens.length; idx++) {
        const t = sentence.tokens[idx];
        if (t.index > lookup.rangeEnd) break;
        rangeTokens.push(t.text);
        lastTokenIndex = idx;
      }

      const categoryInfo = CATEGORY_COLORS[lookup.disfluency.category] || {
        bg: '#e5e7eb',
        label: lookup.disfluency.category,
      };

      elements.push(
        <React.Fragment key={token.index}>
          {separator}
          <span
            className="disfluency-highlight"
            style={{ backgroundColor: categoryInfo.bg }}
            title={categoryInfo.label}
          >
            {rangeTokens.join(' ')}
          </span>
        </React.Fragment>
      );

      // Check for pause after the last token in the range
      const lastToken = sentence.tokens[lastTokenIndex];
      const pause = pauseAfterWord.get(normalizeWord(lastToken.text));
      if (pause) {
        elements.push(
          <span
            key={`pause-${lastToken.index}`}
            className="disfluency-highlight"
            style={{ backgroundColor: '#fce7f3' }}
            title={`Pause: ${pause.duration}s`}
          >
            {' '}[Pause {pause.duration}s]
          </span>
        );
      }

      i = lastTokenIndex + 1;
    } else {
      // Non-highlighted token
      const pause = pauseAfterWord.get(normalizeWord(token.text));
      const pauseMarker = pause ? (
        <span
          key={`pause-${token.index}`}
          className="disfluency-highlight"
          style={{ backgroundColor: '#fce7f3' }}
          title={`Pause: ${pause.duration}s`}
        >
          {' '}[Pause {pause.duration}s]
        </span>
      ) : null;

      elements.push(
        <React.Fragment key={token.index}>
          {separator}{token.text}
          {pauseMarker}
        </React.Fragment>
      );
      i++;
    }
  }

  return <>{elements}</>;
}

function TokenHighlightedTranscript({
  sentences,
  pauses = [],
  showCleanSentences,
}: TokenHighlightedTranscriptProps) {
  const displaySentences = showCleanSentences
    ? sentences
    : sentences.filter((s) => s.disfluencies.length > 0);

  return (
    <div className="highlighted-transcript">
      <div className="highlight-legend">
        {Object.entries(CATEGORY_COLORS).map(([category, info]) => (
          <span key={category} className="legend-item">
            <span
              className="legend-swatch"
              style={{ backgroundColor: info.bg }}
            ></span>
            {info.label}
          </span>
        ))}
        {pauses.length > 0 && (
          <span className="legend-item">
            <span
              className="legend-swatch"
              style={{ backgroundColor: '#fce7f3' }}
            ></span>
            Pause
          </span>
        )}
      </div>

      <div className="annotated-sentences">
        {displaySentences.map((sentence, index) => (
          <div key={index} className="annotated-sentence">
            <div className="sentence-content">
              {renderTokenHighlightedText(sentence, pauses)}
            </div>
            <span
              className="struggle-badge"
              style={{
                backgroundColor: getStruggleColor(sentence.struggle_score),
              }}
              title={`Struggle score: ${sentence.struggle_score}`}
            >
              {sentence.struggle_score.toFixed(1)}
            </span>
          </div>
        ))}

        {displaySentences.length === 0 && (
          <p className="no-sentences-message">
            No sentences with disfluencies found.
          </p>
        )}
      </div>
    </div>
  );
}

export default TokenHighlightedTranscript;
