import { useState } from 'react';
import './App.css';
import { Mode, TranscriptionResponse } from './types';
import { transcribeAudio } from './api/transcriptionApi';
import ModeSelector from './components/ModeSelector';
import AudioUploader from './components/AudioUploader';
import TranscriptionStatus from './components/TranscriptionStatus';
import MerchantBuyerResult from './components/merchant/MerchantBuyerResult';
import DisfluencyResult from './components/disfluency/DisfluencyResult';

function App() {
  const [mode, setMode] = useState<Mode>('merchant_buyer');
  const [result, setResult] = useState<TranscriptionResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleUpload(file: File, translate: boolean) {
    setIsLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await transcribeAudio(file, mode, translate);
      setResult(response);
    } catch (err: unknown) {
      if (err instanceof Error) {
        const axiosErr = err as { response?: { data?: { error?: string } } };
        if (axiosErr.response?.data?.error) {
          setError(axiosErr.response.data.error);
        } else {
          setError(err.message || 'An unexpected error occurred.');
        }
      } else {
        setError('An unexpected error occurred.');
      }
    } finally {
      setIsLoading(false);
    }
  }

  function handleModeChange(newMode: Mode) {
    setMode(newMode);
    setResult(null);
    setError(null);
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1 className="app-title">Transcription Service</h1>
        <p className="app-subtitle">
          Upload an audio file to transcribe and analyze conversations
        </p>
      </header>

      <main className="app-main">
        <ModeSelector mode={mode} onModeChange={handleModeChange} />

        <AudioUploader
          onUpload={handleUpload}
          mode={mode}
          isLoading={isLoading}
        />

        <TranscriptionStatus isLoading={isLoading} mode={mode} />

        {error && (
          <div className="error-alert">
            <span className="error-icon">!</span>
            <span className="error-message">{error}</span>
          </div>
        )}

        {result && result.mode === 'merchant_buyer' && (
          <MerchantBuyerResult result={result} />
        )}

        {result && result.mode === 'disfluency' && (
          <DisfluencyResult result={result} />
        )}
      </main>

      <footer className="app-footer">
        <p>Powered by Whisper and Claude AI</p>
      </footer>
    </div>
  );
}

export default App;
