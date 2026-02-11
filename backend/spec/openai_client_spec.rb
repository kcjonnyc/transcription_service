# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OpenAIClient do
  let(:client) { described_class.new }
  let(:file) { File.open(File.join(__dir__, 'fixtures', 'test.mp3')) }
  let(:filename) { 'test.mp3' }
  let(:mock_audio) { instance_double(OpenAI::Audio) }
  let(:mock_openai_client) { instance_double(OpenAI::Client, audio: mock_audio) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
  end

  after { file.close }

  describe '#initialize' do
    it 'creates an OpenAI client with the API key and base URL' do
      expected_base = ENV.fetch('OPENAI_BASE_URL', 'https://api.openai.com/v1')
      expect(OpenAI::Client).to receive(:new).with(
        access_token: 'test-api-key',
        uri_base: expected_base
      )

      described_class.new
    end
  end

  describe '#transcribe_diarized' do
    let(:response_body) do
      {
        'text' => 'Hello how can I help you?',
        'segments' => [
          { 'id' => 0, 'start' => 0.0, 'end' => 3.5, 'text' => 'Hello how can I help you?', 'speaker' => 'speaker_0' }
        ]
      }
    end

    before do
      allow(mock_audio).to receive(:transcribe).and_return(response_body)
    end

    it 'calls audio.transcribe with gpt-4o-transcribe model' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(model: 'gpt-4o-transcribe')
      )
      client.transcribe_diarized(file, filename)
    end

    it 'includes logprobs in the include parameter' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(include: ['logprobs'])
      )
      client.transcribe_diarized(file, filename)
    end

    it 'requests verbose_json response format' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(response_format: 'verbose_json')
      )
      client.transcribe_diarized(file, filename)
    end

    it 'returns parsed response hash' do
      result = client.transcribe_diarized(file, filename)

      expect(result).to be_a(Hash)
      expect(result['text']).to eq('Hello how can I help you?')
      expect(result['segments']).to be_an(Array)
    end

    context 'when the API returns an error' do
      before do
        allow(mock_audio).to receive(:transcribe).and_return(
          { 'error' => { 'message' => 'Unauthorized' } }
        )
      end

      it 'raises OpenAIClient::ApiError' do
        expect { client.transcribe_diarized(file, filename) }
          .to raise_error(OpenAIClient::ApiError, /Unauthorized/)
      end
    end
  end

  describe '#transcribe_with_disfluencies' do
    let(:response_body) do
      {
        'text' => 'Um, I was, uh, thinking about going to the store.',
        'segments' => [
          { 'id' => 0, 'start' => 0.0, 'end' => 4.0, 'text' => 'Um, I was, uh, thinking about going to the store.' }
        ]
      }
    end

    before do
      allow(mock_audio).to receive(:transcribe).and_return(response_body)
    end

    it 'calls audio.transcribe with whisper-1 model' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(model: 'whisper-1')
      )
      client.transcribe_with_disfluencies(file, filename)
    end

    it 'includes a disfluency prompt' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(prompt: a_string_including('Um, uh, hmm'))
      )
      client.transcribe_with_disfluencies(file, filename)
    end

    it 'requests verbose_json response format' do
      expect(mock_audio).to receive(:transcribe).with(
        parameters: hash_including(response_format: 'verbose_json')
      )
      client.transcribe_with_disfluencies(file, filename)
    end

    it 'returns parsed response hash' do
      result = client.transcribe_with_disfluencies(file, filename)

      expect(result).to be_a(Hash)
      expect(result['text']).to eq('Um, I was, uh, thinking about going to the store.')
    end

    context 'when the API returns an error' do
      before do
        allow(mock_audio).to receive(:transcribe).and_return(
          { 'error' => { 'message' => 'Rate limit exceeded' } }
        )
      end

      it 'raises OpenAIClient::ApiError' do
        expect { client.transcribe_with_disfluencies(file, filename) }
          .to raise_error(OpenAIClient::ApiError, /Rate limit exceeded/)
      end
    end
  end

  describe '#translate_to_english' do
    let(:response_body) do
      {
        'text' => 'Hello, how are you?',
        'segments' => [
          { 'id' => 0, 'start' => 0.0, 'end' => 2.0, 'text' => 'Hello, how are you?' }
        ]
      }
    end

    before do
      allow(mock_audio).to receive(:translate).and_return(response_body)
    end

    it 'calls audio.translate with whisper-1 model' do
      expect(mock_audio).to receive(:translate).with(
        parameters: hash_including(model: 'whisper-1')
      )
      client.translate_to_english(file, filename)
    end

    it 'requests verbose_json response format' do
      expect(mock_audio).to receive(:translate).with(
        parameters: hash_including(response_format: 'verbose_json')
      )
      client.translate_to_english(file, filename)
    end

    it 'returns parsed response hash' do
      result = client.translate_to_english(file, filename)

      expect(result).to be_a(Hash)
      expect(result['text']).to eq('Hello, how are you?')
    end

    context 'when the API returns an error' do
      before do
        allow(mock_audio).to receive(:translate).and_return(
          { 'error' => { 'message' => 'Service Unavailable' } }
        )
      end

      it 'raises OpenAIClient::ApiError' do
        expect { client.translate_to_english(file, filename) }
          .to raise_error(OpenAIClient::ApiError, /Service Unavailable/)
      end
    end
  end

  describe 'DISFLUENCY_ANALYSIS_PROMPT' do
    it 'includes all disfluency categories' do
      %w[filler_words word_repetitions sound_repetitions prolongations revisions partial_words].each do |cat|
        expect(described_class::DISFLUENCY_ANALYSIS_PROMPT).to include("\"#{cat}\"")
      end
    end

    it 'does not include pauses (pauses are injected locally, not by the LLM)' do
      expect(described_class::DISFLUENCY_ANALYSIS_PROMPT).not_to include('"pauses"')
    end
  end
end
