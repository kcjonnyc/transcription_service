export type Mode = 'merchant_buyer' | 'disfluency' | 'streaming_merchant_buyer';

export interface Segment {
  id: number;
  speaker: string;
  start: number;
  end: number;
  text: string;
}

export interface MerchantBuyerResponse {
  mode: 'merchant_buyer';
  full_text: string;
  segments: Segment[];
  speakers: string[];
  speaker_labels: Record<string, string>;
  translation: string | null;
}

export interface Disfluency {
  category: string;
  text: string;
  position: number;
  length: number;
}

export interface AnnotatedSentence {
  text: string;
  disfluencies: Disfluency[];
  struggle_score: number;
}

export interface CategoryStats {
  count: number;
  examples: string[];
}

export interface DisfluencyAnalysis {
  annotated_sentences: AnnotatedSentence[];
  pauses: Pause[];
  summary: {
    total_disfluencies: number;
    disfluency_rate: number;
    by_category: Record<string, CategoryStats>;
    most_common_fillers: Record<string, number>;
  };
}

export interface WordTimestamp {
  word: string;
  start: number;
  end: number;
}

export interface Pause {
  after_word: string;
  before_word: string;
  start: number;
  end: number;
  duration: number;
}

export interface Token {
  index: number;
  text: string;
}

export interface LlmDisfluency {
  category: string;
  text: string;
  word_indices: number[];
}

export interface LlmAnnotatedSentence {
  text: string;
  tokens: Token[];
  disfluencies: LlmDisfluency[];
  struggle_score: number;
}

export interface LlmDisfluencyAnalysis {
  annotated_sentences: LlmAnnotatedSentence[];
  pauses: Pause[];
  summary: {
    total_disfluencies: number;
    disfluency_rate: number;
    by_category: Record<string, CategoryStats>;
    most_common_fillers: Record<string, number>;
  };
}

export interface DisfluencyResponse {
  mode: 'disfluency';
  full_text: string;
  words: WordTimestamp[];
  regex_analysis: DisfluencyAnalysis;
  llm_analysis: LlmDisfluencyAnalysis;
}

export type TranscriptionResponse = MerchantBuyerResponse | DisfluencyResponse;
