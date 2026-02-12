import { useState } from 'react';
import { StreamingPhase } from '../../types/streaming';

interface StreamingRecorderProps {
  phase: StreamingPhase;
  durationWarning: boolean;
  onStart: (language?: string, translate?: boolean) => void;
  onStop: () => void;
}

const LANGUAGES = [
  { value: '', label: 'Auto-detect' },
  { value: 'en', label: 'English' },
  { value: 'es', label: 'Spanish' },
  { value: 'fr', label: 'French' },
  { value: 'de', label: 'German' },
  { value: 'it', label: 'Italian' },
  { value: 'pt', label: 'Portuguese' },
  { value: 'ja', label: 'Japanese' },
  { value: 'ko', label: 'Korean' },
  { value: 'zh', label: 'Chinese' },
  { value: 'ar', label: 'Arabic' },
  { value: 'hi', label: 'Hindi' },
  { value: 'ru', label: 'Russian' },
];

function StreamingRecorder({
  phase,
  durationWarning,
  onStart,
  onStop,
}: StreamingRecorderProps) {
  const [language, setLanguage] = useState('');
  const [translate, setTranslate] = useState(false);

  const isRecording = phase === 'recording';
  const isConnecting = phase === 'connecting';
  const isProcessing = phase === 'processing';
  const isBusy = isRecording || isConnecting || isProcessing;

  function handleToggle() {
    if (isRecording) {
      onStop();
    } else if (phase === 'idle') {
      onStart(language || undefined, translate);
    }
  }

  return (
    <div className="streaming-recorder">
      <div className="streaming-controls">
        <div className="streaming-options">
          <div className="streaming-option">
            <label className="streaming-label" htmlFor="stream-language">
              Language
            </label>
            <select
              id="stream-language"
              className="streaming-select"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
              disabled={isBusy}
            >
              {LANGUAGES.map((lang) => (
                <option key={lang.value} value={lang.value}>
                  {lang.label}
                </option>
              ))}
            </select>
          </div>

          <label className="translate-checkbox">
            <input
              type="checkbox"
              checked={translate}
              onChange={(e) => setTranslate(e.target.checked)}
              disabled={isBusy}
            />
            <span className="checkbox-label">Translate to English</span>
          </label>
        </div>

        <button
          className={`record-btn ${isRecording ? 'recording' : ''}`}
          onClick={handleToggle}
          disabled={isConnecting || isProcessing}
        >
          {isConnecting && (
            <>
              <span className="record-btn-spinner" />
              Connecting...
            </>
          )}
          {isRecording && (
            <>
              <span className="record-indicator" />
              Stop Recording
            </>
          )}
          {isProcessing && (
            <>
              <span className="record-btn-spinner" />
              Processing...
            </>
          )}
          {phase === 'idle' && (
            <>
              <span className="record-icon" />
              Start Recording
            </>
          )}
        </button>
      </div>

      {isRecording && (
        <div className="recording-status">
          <span className="pulse-dot" />
          <span className="recording-text">Listening...</span>
        </div>
      )}

      {isProcessing && (
        <div className="processing-status">
          <span className="spinner spinner-sm" />
          <span>Analyzing speakers and finalizing transcript...</span>
        </div>
      )}

      {durationWarning && (
        <div className="duration-warning">
          Recording will automatically stop in 5 minutes (30 min limit).
        </div>
      )}
    </div>
  );
}

export default StreamingRecorder;
