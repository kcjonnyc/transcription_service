import { useState, useRef, useCallback, useEffect } from 'react';

export type RecorderStatus = 'idle' | 'requesting-permission' | 'recording' | 'recorded';

const MAX_DURATION_S = 300; // 5 minutes
const MIME_TYPES = ['audio/webm;codecs=opus', 'audio/webm'];

function getSupportedMimeType(): string {
  for (const mime of MIME_TYPES) {
    if (MediaRecorder.isTypeSupported(mime)) return mime;
  }
  return '';
}

function friendlyError(err: unknown): string {
  if (err instanceof DOMException) {
    switch (err.name) {
      case 'NotAllowedError':
        return 'Microphone access was denied. Please allow microphone access in your browser settings and try again.';
      case 'NotFoundError':
        return 'No microphone found. Please connect a microphone and try again.';
      case 'NotReadableError':
        return 'Microphone is already in use by another application.';
      default:
        return `Microphone error: ${err.message}`;
    }
  }
  return 'An unexpected error occurred while accessing the microphone.';
}

export function useAudioRecorder() {
  const [status, setStatus] = useState<RecorderStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const [duration, setDuration] = useState(0);
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [analyserNode, setAnalyserNode] = useState<AnalyserNode | null>(null);

  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const startTimeRef = useRef<number>(0);

  const cleanup = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }
    mediaRecorderRef.current = null;
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((t) => t.stop());
      streamRef.current = null;
    }
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }
    setAnalyserNode(null);
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      cleanup();
      // Revoke any lingering object URL
      setAudioUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev);
        return null;
      });
    };
  }, [cleanup]);

  const startRecording = useCallback(async () => {
    setError(null);
    setStatus('requesting-permission');

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      // Set up AudioContext + AnalyserNode for waveform
      const audioCtx = new AudioContext();
      audioContextRef.current = audioCtx;
      const source = audioCtx.createMediaStreamSource(stream);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      setAnalyserNode(analyser);

      const mimeType = getSupportedMimeType();
      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream);
      mediaRecorderRef.current = recorder;
      chunksRef.current = [];

      recorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunksRef.current.push(e.data);
      };

      recorder.onstop = () => {
        const type = recorder.mimeType || 'audio/webm';
        const blob = new Blob(chunksRef.current, { type });
        setAudioBlob(blob);

        // Revoke previous URL if any
        setAudioUrl((prev) => {
          if (prev) URL.revokeObjectURL(prev);
          return URL.createObjectURL(blob);
        });

        setStatus('recorded');

        // Stop tracks & close context after recording finishes
        streamRef.current?.getTracks().forEach((t) => t.stop());
        streamRef.current = null;
        audioContextRef.current?.close();
        audioContextRef.current = null;
        setAnalyserNode(null);
      };

      recorder.start(250); // collect data every 250ms
      startTimeRef.current = Date.now();
      setDuration(0);
      setStatus('recording');

      timerRef.current = setInterval(() => {
        const elapsed = Math.floor((Date.now() - startTimeRef.current) / 1000);
        setDuration(elapsed);
        if (elapsed >= MAX_DURATION_S) {
          recorder.stop();
          if (timerRef.current) {
            clearInterval(timerRef.current);
            timerRef.current = null;
          }
        }
      }, 250);
    } catch (err) {
      cleanup();
      setError(friendlyError(err));
      setStatus('idle');
    }
  }, [cleanup]);

  const stopRecording = useCallback(() => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
      timerRef.current = null;
    }
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }
  }, []);

  const resetRecording = useCallback(() => {
    cleanup();
    setAudioUrl((prev) => {
      if (prev) URL.revokeObjectURL(prev);
      return null;
    });
    setAudioBlob(null);
    setDuration(0);
    setError(null);
    setStatus('idle');
  }, [cleanup]);

  return {
    status,
    error,
    duration,
    audioBlob,
    audioUrl,
    analyserNode,
    startRecording,
    stopRecording,
    resetRecording,
  };
}
