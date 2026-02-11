import React from 'react';
import { AnnotatedSentence, Disfluency } from '../../types';

interface HighlightedTranscriptProps {
  sentences: AnnotatedSentence[];
  showCleanSentences: boolean;
}

const CATEGORY_COLORS: Record<string, { bg: string; label: string }> = {
  filler_words: { bg: '#fef3c7', label: 'Filler Word' },
  word_repetitions: { bg: '#fed7aa', label: 'Word Repetition' },
  sound_repetitions: { bg: '#fecaca', label: 'Sound Repetition (Stutter)' },
  prolongations: { bg: '#e9d5ff', label: 'Prolongation' },
  revisions: { bg: '#bfdbfe', label: 'Revision' },
  partial_words: { bg: '#fca5a5', label: 'Partial Word' },
  pauses: { bg: '#fce7f3', label: 'Pause' },
};

function getStruggleColor(score: number): string {
  if (score <= 2) return '#22c55e';
  if (score <= 5) return '#f59e0b';
  return '#ef4444';
}

function renderHighlightedText(text: string, disfluencies: Disfluency[]) {
  if (disfluencies.length === 0) {
    return <span>{text}</span>;
  }

  const sorted = [...disfluencies].sort((a, b) => a.position - b.position);
  const parts: React.ReactElement[] = [];
  let lastIndex = 0;

  sorted.forEach((dis, i) => {
    // Add plain text before this disfluency
    if (dis.position > lastIndex) {
      parts.push(
        <span key={`plain-${i}`}>
          {text.slice(lastIndex, dis.position)}
        </span>
      );
    }

    const categoryInfo = CATEGORY_COLORS[dis.category] || { bg: '#e5e7eb', label: dis.category };
    const highlightEnd = dis.position + dis.length;

    parts.push(
      <span
        key={`dis-${i}`}
        className="disfluency-highlight"
        style={{ backgroundColor: categoryInfo.bg }}
        title={categoryInfo.label}
      >
        {text.slice(dis.position, highlightEnd)}
      </span>
    );

    lastIndex = highlightEnd;
  });

  // Add remaining text after last disfluency
  if (lastIndex < text.length) {
    parts.push(
      <span key="plain-end">
        {text.slice(lastIndex)}
      </span>
    );
  }

  return <>{parts}</>;
}

function HighlightedTranscript({ sentences, showCleanSentences }: HighlightedTranscriptProps) {
  const displaySentences = showCleanSentences
    ? sentences
    : sentences.filter((s) => s.disfluencies.length > 0);

  return (
    <div className="highlighted-transcript">
      <div className="highlight-legend">
        {Object.entries(CATEGORY_COLORS).map(([category, info]) => (
          <span key={category} className="legend-item">
            <span className="legend-swatch" style={{ backgroundColor: info.bg }}></span>
            {info.label}
          </span>
        ))}
      </div>

      <div className="annotated-sentences">
        {displaySentences.map((sentence, index) => (
          <div key={index} className="annotated-sentence">
            <div className="sentence-content">
              {renderHighlightedText(sentence.text, sentence.disfluencies)}
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

export default HighlightedTranscript;
