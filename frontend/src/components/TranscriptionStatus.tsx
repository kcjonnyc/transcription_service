import { Mode } from '../types';

interface TranscriptionStatusProps {
  isLoading: boolean;
  mode: Mode;
}

function TranscriptionStatus({ isLoading, mode }: TranscriptionStatusProps) {
  if (!isLoading) return null;

  const modeMessage = mode === 'merchant_buyer'
    ? 'Identifying speakers and transcribing conversation...'
    : 'Transcribing and analyzing disfluencies...';

  return (
    <div className="transcription-status">
      <div className="spinner"></div>
      <h3 className="status-title">Transcribing audio...</h3>
      <p className="status-message">{modeMessage}</p>
      <p className="status-note">
        This may take a minute or two depending on the length of the audio file.
      </p>
    </div>
  );
}

export default TranscriptionStatus;
