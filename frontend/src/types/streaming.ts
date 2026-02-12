import { MerchantBuyerResponse } from './index';

// Messages sent from browser to backend
export interface StartMessage {
  type: 'start';
  language?: string;
  translate?: boolean;
}

export interface AudioMessage {
  type: 'audio';
  data: string; // base64-encoded PCM16
}

export interface StopMessage {
  type: 'stop';
}

export type ClientMessage = StartMessage | AudioMessage | StopMessage;

// Messages received from backend
export interface SessionStartedMessage {
  type: 'session_started';
}

export interface TranscriptDeltaMessage {
  type: 'transcript_delta';
  text: string;
  item_id: string;
}

export interface TranscriptCompleteMessage {
  type: 'transcript_complete';
  text: string;
  item_id: string;
}

export interface SessionStoppedMessage {
  type: 'session_stopped';
  diarized_result: MerchantBuyerResponse | null;
  translation?: string | null;
}

export interface ErrorMessage {
  type: 'error';
  message: string;
}

export type ServerMessage =
  | SessionStartedMessage
  | TranscriptDeltaMessage
  | TranscriptCompleteMessage
  | SessionStoppedMessage
  | ErrorMessage;

// Streaming state
export interface StreamingSegment {
  item_id: string;
  text: string;
  is_final: boolean;
}

export type StreamingPhase = 'idle' | 'connecting' | 'recording' | 'processing';
