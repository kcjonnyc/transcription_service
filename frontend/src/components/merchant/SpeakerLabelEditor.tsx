interface SpeakerLabelEditorProps {
  speakers: string[];
  speakerLabels: Record<string, string>;
  onLabelChange: (speakerId: string, label: string) => void;
}

const LABEL_OPTIONS = ['Merchant', 'Buyer', 'Customer', 'Agent'];

function SpeakerLabelEditor({ speakers, speakerLabels, onLabelChange }: SpeakerLabelEditorProps) {
  return (
    <div className="speaker-label-editor">
      <h3 className="section-title">Speaker Labels</h3>
      <p className="section-description">
        Assign roles to each detected speaker in the conversation.
      </p>
      <div className="speaker-labels-grid">
        {speakers.map((speaker) => (
          <div key={speaker} className="speaker-label-row">
            <span className="speaker-id">Speaker {speaker}:</span>
            <select
              className="speaker-label-select"
              value={speakerLabels[speaker] || speaker}
              onChange={(e) => onLabelChange(speaker, e.target.value)}
            >
              <option value={speaker}>{speaker} (raw)</option>
              {LABEL_OPTIONS.map((label) => (
                <option key={label} value={label}>
                  {label}
                </option>
              ))}
            </select>
          </div>
        ))}
      </div>
    </div>
  );
}

export default SpeakerLabelEditor;
