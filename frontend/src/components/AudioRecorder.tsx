import { useState, useRef, useEffect, useCallback } from 'react';
import { Mode } from '../types';
import { useAudioRecorder } from '../hooks/useAudioRecorder';

interface AudioRecorderProps {
  onUpload: (file: File, translate: boolean) => void;
  mode: Mode;
  isLoading: boolean;
}

function formatTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function AudioRecorder({ onUpload, mode, isLoading }: AudioRecorderProps) {
  const [translate, setTranslate] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animFrameRef = useRef<number>(0);

  const {
    status,
    error,
    duration,
    audioBlob,
    audioUrl,
    analyserNode,
    startRecording,
    stopRecording,
    resetRecording,
  } = useAudioRecorder();

  // Waveform drawing
  const drawWaveform = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas || !analyserNode) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bufferLength = analyserNode.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);

    function draw() {
      animFrameRef.current = requestAnimationFrame(draw);
      analyserNode!.getByteTimeDomainData(dataArray);

      const w = canvas!.width;
      const h = canvas!.height;
      ctx!.fillStyle = '#f9fafb';
      ctx!.fillRect(0, 0, w, h);

      ctx!.lineWidth = 2;
      ctx!.strokeStyle = '#ef4444';
      ctx!.beginPath();

      const sliceWidth = w / bufferLength;
      let x = 0;
      for (let i = 0; i < bufferLength; i++) {
        const v = dataArray[i] / 128.0;
        const y = (v * h) / 2;
        if (i === 0) ctx!.moveTo(x, y);
        else ctx!.lineTo(x, y);
        x += sliceWidth;
      }

      ctx!.lineTo(w, h / 2);
      ctx!.stroke();
    }

    draw();
  }, [analyserNode]);

  useEffect(() => {
    if (status === 'recording' && analyserNode) {
      drawWaveform();
    }
    return () => {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
      }
    };
  }, [status, analyserNode, drawWaveform]);

  function handleSubmit() {
    if (!audioBlob || isLoading) return;
    const file = new File([audioBlob], 'recording.webm', { type: audioBlob.type });
    onUpload(file, translate);
  }

  return (
    <div className="audio-uploader">
      {/* Idle state */}
      {status === 'idle' && (
        <div className="recorder-idle" onClick={startRecording}>
          <button className="mic-button" type="button" aria-label="Start recording">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
              <line x1="12" y1="19" x2="12" y2="23" />
              <line x1="8" y1="23" x2="16" y2="23" />
            </svg>
          </button>
          <p className="recorder-hint">Click to start recording</p>
          <p className="upload-info">Records up to 5 minutes of audio</p>
        </div>
      )}

      {/* Requesting permission */}
      {status === 'requesting-permission' && (
        <div className="recorder-permission">
          <div className="spinner" />
          <p className="recorder-hint">Requesting microphone access...</p>
        </div>
      )}

      {/* Recording */}
      {status === 'recording' && (
        <div className="recorder-active">
          <div className="recorder-header">
            <span className="recording-indicator">
              <span className="red-dot" />
              Recording
            </span>
            <span className="recording-timer">{formatTime(duration)}</span>
          </div>
          <canvas ref={canvasRef} className="waveform-canvas" width={600} height={80} />
          <button className="stop-button" type="button" onClick={stopRecording}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
              <rect x="4" y="4" width="16" height="16" rx="2" />
            </svg>
            Stop Recording
          </button>
        </div>
      )}

      {/* Recorded / review */}
      {status === 'recorded' && audioUrl && (
        <div className="recorder-review">
          <audio controls src={audioUrl} className="audio-player" />
          <div className="recorder-review-actions">
            <button className="re-record-btn" type="button" onClick={resetRecording}>
              Re-record
            </button>
            <span className="recording-duration">{formatTime(duration)}</span>
          </div>
        </div>
      )}

      {error && <div className="upload-error">{error}</div>}

      {/* Translate checkbox + submit — only when we have a recording */}
      {status === 'recorded' && (
        <>
          <div className="upload-options">
            {mode === 'transcribe' && (
              <label className="translate-checkbox">
                <input
                  type="checkbox"
                  checked={translate}
                  onChange={(e) => setTranslate(e.target.checked)}
                />
                <span className="checkbox-label">Translate to English</span>
              </label>
            )}
          </div>

          <button
            className="transcribe-btn"
            onClick={handleSubmit}
            disabled={!audioBlob || isLoading}
          >
            {isLoading ? 'Transcribing...' : 'Transcribe'}
          </button>
        </>
      )}
    </div>
  );
}

export default AudioRecorder;
