import { Mode } from '../types';

interface ModeSelectorProps {
  mode: Mode;
  onModeChange: (mode: Mode) => void;
}

function ModeSelector({ mode, onModeChange }: ModeSelectorProps) {
  return (
    <div className="mode-selector">
      <button
        className={`mode-tab ${mode === 'transcribe' ? 'active' : ''}`}
        onClick={() => onModeChange('transcribe')}
      >
        <span className="mode-tab-icon">&#127908;</span>
        Transcribe &amp; Translate
      </button>
      <button
        className={`mode-tab ${mode === 'disfluency' ? 'active' : ''}`}
        onClick={() => onModeChange('disfluency')}
      >
        <span className="mode-tab-icon">&#128200;</span>
        Disfluency Analysis
      </button>
    </div>
  );
}

export default ModeSelector;
