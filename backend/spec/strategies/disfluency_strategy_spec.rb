# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Strategies::DisfluencyStrategy do
  let(:client) { instance_double(OpenAIClient) }
  let(:strategy) { described_class.new(client) }
  let(:file) { double('file') }
  let(:filename) { 'test.mp3' }

  let(:transcription_text) { 'Um, I was, uh, thinking about, like, going to the store.' }

  let(:disfluency_response) do
    {
      'text' => transcription_text,
      'segments' => [
        { 'id' => 0, 'start' => 0.0, 'end' => 5.0, 'text' => transcription_text }
      ]
    }
  end

  let(:regex_analyzer_result) do
    {
      disfluencies: [
        { type: 'filler', word: 'Um', position: 0 },
        { type: 'filler', word: 'uh', position: 12 },
        { type: 'discourse_marker', word: 'like', position: 28 }
      ],
      disfluency_count: 3,
      clean_text: 'I was thinking about going to the store.'
    }
  end

  let(:llm_analyzer_result) do
    {
      annotated_sentences: [
        { text: 'Um, I was, uh, thinking about, like, going to the store.', disfluencies: [], struggle_score: 0.0 }
      ],
      summary: { total_disfluencies: 3, disfluency_rate: 0.3, by_category: {}, most_common_fillers: {} }
    }
  end

  describe '#transcribe' do
    before do
      allow(client).to receive(:transcribe_with_disfluencies).and_return(disfluency_response)
      allow_any_instance_of(RegexDisfluencyAnalyzer).to receive(:analyze).and_return(regex_analyzer_result)
      allow_any_instance_of(LlmDisfluencyAnalyzer).to receive(:analyze).and_return(llm_analyzer_result)
    end

    it 'calls transcribe_with_disfluencies on the client' do
      strategy.transcribe(file, filename)

      expect(client).to have_received(:transcribe_with_disfluencies).with(file)
    end

    it 'runs regex analysis on the transcription text' do
      result = strategy.transcribe(file, filename)

      expect(result[:regex_analysis]).to eq(regex_analyzer_result)
    end

    it 'runs LLM analysis on the transcription text' do
      result = strategy.transcribe(file, filename)

      expect(result[:llm_analysis]).to eq(llm_analyzer_result)
    end

    it 'returns a hash with mode set to disfluency' do
      result = strategy.transcribe(file, filename)

      expect(result[:mode]).to eq('disfluency')
    end

    it 'includes the full text from the transcription' do
      result = strategy.transcribe(file, filename)

      expect(result[:full_text]).to eq(transcription_text)
    end

    it 'includes the regex analysis result from RegexDisfluencyAnalyzer' do
      result = strategy.transcribe(file, filename)

      expect(result[:regex_analysis]).to eq(regex_analyzer_result)
    end

    it 'includes the LLM analysis result from LlmDisfluencyAnalyzer' do
      result = strategy.transcribe(file, filename)

      expect(result[:llm_analysis]).to eq(llm_analyzer_result)
    end

    it 'returns a hash with the expected keys' do
      result = strategy.transcribe(file, filename)

      expect(result).to have_key(:mode)
      expect(result).to have_key(:full_text)
      expect(result).to have_key(:words)
      expect(result).to have_key(:regex_analysis)
      expect(result).to have_key(:llm_analysis)
    end
  end
end
