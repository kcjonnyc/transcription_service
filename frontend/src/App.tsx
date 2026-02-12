import { useState } from 'react';
import './App.css';
import { Mode, TranscriptionResponse } from './types';
import { transcribeAudio } from './api/transcriptionApi';
import { useStreamingTranscription } from './hooks/useStreamingTranscription';
import ModeSelector from './components/ModeSelector';
import AudioUploader from './components/AudioUploader';
import TranscriptionStatus from './components/TranscriptionStatus';
import MerchantBuyerResult from './components/merchant/MerchantBuyerResult';
import DisfluencyResult from './components/disfluency/DisfluencyResult';
import StreamingRecorder from './components/streaming/StreamingRecorder';
import LiveTranscript from './components/streaming/LiveTranscript';

function App() {
  const [mode, setMode] = useState<Mode>('merchant_buyer');
  const [result, setResult] = useState<TranscriptionResponse | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const streaming = useStreamingTranscription();

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
    if (newMode !== 'streaming_merchant_buyer') {
      streaming.reset();
    }
  }

  const isStreaming = mode === 'streaming_merchant_buyer';
  const displayError = isStreaming ? streaming.error : error;

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

        {isStreaming ? (
          <>
            <StreamingRecorder
              phase={streaming.phase}
              durationWarning={streaming.durationWarning}
              onStart={streaming.startRecording}
              onStop={streaming.stopRecording}
            />

            <LiveTranscript
              phase={streaming.phase}
              segments={streaming.segments}
              interimText={streaming.interimText}
            />

            {streaming.finalResult && (
              <MerchantBuyerResult result={streaming.finalResult} />
            )}
          </>
        ) : (
          <>
            <AudioUploader
              onUpload={handleUpload}
              mode={mode}
              isLoading={isLoading}
            />

            <TranscriptionStatus isLoading={isLoading} mode={mode} />

            {result && result.mode === 'merchant_buyer' && (
              <MerchantBuyerResult result={result} />
            )}

            {result && result.mode === 'disfluency' && (
              <DisfluencyResult result={result} />
            )}
          </>
        )}

        {displayError && (
          <div className="error-alert">
            <span className="error-icon">!</span>
            <span className="error-message">{displayError}</span>
          </div>
        )}
      </main>

      <footer className="app-footer">
        <p>Powered by Whisper and Claude AI</p>
      </footer>
    </div>
  );
}

export default App;
