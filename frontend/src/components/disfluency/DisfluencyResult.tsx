import { useState } from 'react';
import { DisfluencyResponse } from '../../types';
import DisfluencySummary from './DisfluencySummary';
import HighlightedTranscript from './HighlightedTranscript';
import TokenHighlightedTranscript from './TokenHighlightedTranscript';

interface DisfluencyResultProps {
  result: DisfluencyResponse;
}

function DisfluencyResult({ result }: DisfluencyResultProps) {
  const [showCleanSentences, setShowCleanSentences] = useState(true);

  return (
    <div className="disfluency-result">
      <div className="transcript-controls">
        <label className="show-clean-toggle">
          <input
            type="checkbox"
            checked={showCleanSentences}
            onChange={(e) => setShowCleanSentences(e.target.checked)}
          />
          <span className="checkbox-label">Show sentences without disfluencies</span>
        </label>
      </div>

      <div className="analysis-comparison">
        <div className="analysis-panel">
          <h3 className="section-title">Regex Analysis</h3>
          <DisfluencySummary summary={result.regex_analysis.summary} />
          <HighlightedTranscript
            sentences={result.regex_analysis.annotated_sentences}
            showCleanSentences={showCleanSentences}
          />
        </div>
        <div className="analysis-panel">
          <h3 className="section-title">LLM Analysis</h3>
          <DisfluencySummary summary={result.llm_analysis.summary} />
          <TokenHighlightedTranscript
            sentences={result.llm_analysis.annotated_sentences}
            pauses={result.llm_analysis.pauses}
            showCleanSentences={showCleanSentences}
          />
        </div>
      </div>
    </div>
  );
}

export default DisfluencyResult;
