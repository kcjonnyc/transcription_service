import { useState, useRef, useCallback } from 'react';
import { MerchantBuyerResponse } from '../types';
import {
  StreamingSegment,
  StreamingPhase,
  ServerMessage,
} from '../types/streaming';

const SAMPLE_RATE = 24000;
const MAX_DURATION_MS = 30 * 60 * 1000; // 30 minutes
const WARN_DURATION_MS = 25 * 60 * 1000; // 25 minutes

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export interface UseStreamingTranscriptionReturn {
  phase: StreamingPhase;
  segments: StreamingSegment[];
  interimText: string;
  finalResult: MerchantBuyerResponse | null;
  error: string | null;
  durationWarning: boolean;
  startRecording: (language?: string, translate?: boolean) => Promise<void>;
  stopRecording: () => void;
  reset: () => void;
}

export function useStreamingTranscription(): UseStreamingTranscriptionReturn {
  const [phase, setPhase] = useState<StreamingPhase>('idle');
  const [segments, setSegments] = useState<StreamingSegment[]>([]);
  const [interimText, setInterimText] = useState('');
  const [finalResult, setFinalResult] = useState<MerchantBuyerResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [durationWarning, setDurationWarning] = useState(false);

  const wsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const workletNodeRef = useRef<AudioWorkletNode | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const warnTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const maxTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const cleanup = useCallback(() => {
    workletNodeRef.current?.disconnect();
    workletNodeRef.current = null;

    audioContextRef.current?.close();
    audioContextRef.current = null;

    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;

    if (warnTimerRef.current) clearTimeout(warnTimerRef.current);
    if (maxTimerRef.current) clearTimeout(maxTimerRef.current);
    warnTimerRef.current = null;
    maxTimerRef.current = null;
  }, []);

  const stopRecording = useCallback(() => {
    const ws = wsRef.current;
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'stop' }));
      setPhase('processing');
    }
    cleanup();
  }, [cleanup]);

  const handleServerMessage = useCallback(
    (msg: ServerMessage) => {
      switch (msg.type) {
        case 'session_started':
          setPhase('recording');
          break;

        case 'transcript_delta':
          setInterimText((prev) => prev + msg.text);
          break;

        case 'transcript_complete':
          setSegments((prev) => {
            const existing = prev.find((s) => s.item_id === msg.item_id);
            if (existing) {
              return prev.map((s) =>
                s.item_id === msg.item_id
                  ? { ...s, text: msg.text, is_final: true }
                  : s
              );
            }
            return [
              ...prev,
              { item_id: msg.item_id, text: msg.text, is_final: true },
            ];
          });
          setInterimText('');
          break;

        case 'session_stopped':
          if (msg.diarized_result) {
            setFinalResult(msg.diarized_result);
          }
          setPhase('idle');
          wsRef.current?.close();
          wsRef.current = null;
          break;

        case 'error':
          setError(msg.message);
          break;
      }
    },
    []
  );

  const startRecording = useCallback(
    async (language?: string, translate?: boolean) => {
      setError(null);
      setSegments([]);
      setInterimText('');
      setFinalResult(null);
      setDurationWarning(false);
      setPhase('connecting');

      try {
        // 1. Get microphone access
        const stream = await navigator.mediaDevices.getUserMedia({
          audio: {
            channelCount: 1,
            sampleRate: SAMPLE_RATE,
            echoCancellation: true,
            noiseSuppression: true,
          },
        });
        streamRef.current = stream;

        // 2. Set up AudioContext and worklet
        const audioContext = new AudioContext({ sampleRate: SAMPLE_RATE });
        audioContextRef.current = audioContext;

        await audioContext.audioWorklet.addModule('/pcm16-worklet-processor.js');
        const workletNode = new AudioWorkletNode(audioContext, 'pcm16-worklet-processor');
        workletNodeRef.current = workletNode;

        const source = audioContext.createMediaStreamSource(stream);
        source.connect(workletNode);
        // Do NOT connect workletNode to destination (no feedback)

        // 3. Open WebSocket
        const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${wsProtocol}//${window.location.host}/api/stream-transcribe`;
        const ws = new WebSocket(wsUrl);
        wsRef.current = ws;

        ws.onopen = () => {
          ws.send(
            JSON.stringify({
              type: 'start',
              language: language || undefined,
              translate: translate || false,
            })
          );
        };

        ws.onmessage = (event) => {
          try {
            const msg: ServerMessage = JSON.parse(event.data);
            handleServerMessage(msg);
          } catch {
            console.error('Failed to parse server message:', event.data);
          }
        };

        ws.onerror = () => {
          setError('WebSocket connection error');
          setPhase('idle');
          cleanup();
        };

        ws.onclose = (event) => {
          if (event.code !== 1000 && event.code !== 1005) {
            setError(`Connection closed unexpectedly (code: ${event.code})`);
          }
          cleanup();
        };

        // 4. Forward PCM16 audio chunks over WebSocket
        workletNode.port.onmessage = (event: MessageEvent<ArrayBuffer>) => {
          if (ws.readyState === WebSocket.OPEN) {
            const base64 = arrayBufferToBase64(event.data);
            ws.send(JSON.stringify({ type: 'audio', data: base64 }));
          }
        };

        // 5. Duration timers
        warnTimerRef.current = setTimeout(() => {
          setDurationWarning(true);
        }, WARN_DURATION_MS);

        maxTimerRef.current = setTimeout(() => {
          stopRecording();
        }, MAX_DURATION_MS);
      } catch (err) {
        const message =
          err instanceof DOMException && err.name === 'NotAllowedError'
            ? 'Microphone permission denied. Please allow microphone access and try again.'
            : err instanceof Error
              ? err.message
              : 'Failed to start recording';
        setError(message);
        setPhase('idle');
        cleanup();
      }
    },
    [cleanup, handleServerMessage, stopRecording]
  );

  const reset = useCallback(() => {
    setPhase('idle');
    setSegments([]);
    setInterimText('');
    setFinalResult(null);
    setError(null);
    setDurationWarning(false);
    cleanup();
    wsRef.current?.close();
    wsRef.current = null;
  }, [cleanup]);

  return {
    phase,
    segments,
    interimText,
    finalResult,
    error,
    durationWarning,
    startRecording,
    stopRecording,
    reset,
  };
}
