import { TranscribeResponse } from '../types';

interface TranscribeResultProps {
  result: TranscribeResponse;
}

function TranscribeResult({ result }: TranscribeResultProps) {
  return (
    <div className="transcribe-result">
      <div className="result-card">
        <h3 className="section-title">Transcription</h3>
        <p className="result-card-text">{result.full_text}</p>
      </div>

      {result.translation && (
        <div className="result-card">
          <h3 className="section-title">Translation (English)</h3>
          <p className="result-card-text">{result.translation}</p>
        </div>
      )}
    </div>
  );
}

export default TranscribeResult;
