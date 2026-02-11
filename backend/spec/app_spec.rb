# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranscriptionApp do
  def app
    described_class
  end

  let(:fixture_path) { File.join(__dir__, 'fixtures', 'test.mp3') }
  let(:mock_audio) { instance_double(OpenAI::Audio) }
  let(:mock_openai_client) { instance_double(OpenAI::Client, audio: mock_audio) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
  end

  describe 'GET /api/health' do
    it 'returns status ok' do
      get '/api/health'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['status']).to eq('ok')
    end

    it 'includes a timestamp' do
      get '/api/health'

      body = JSON.parse(last_response.body)
      expect(body['timestamp']).not_to be_nil
    end
  end

  describe 'POST /api/transcribe' do
    context 'with missing file' do
      it 'returns 400 with an error message' do
        post '/api/transcribe', { mode: 'merchant_buyer' }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('No audio file')
      end
    end

    context 'with invalid mode' do
      it 'returns 400 with an error message' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'invalid_mode'
        }

        expect(last_response.status).to eq(400)
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('Invalid mode')
      end
    end

    context 'with valid merchant_buyer request' do
      let(:diarized_response) do
        {
          'text' => 'Hello how can I help you? I would like to buy a phone.',
          'segments' => [
            { 'id' => 0, 'start' => 0.0, 'end' => 3.5, 'text' => 'Hello how can I help you?', 'speaker' => 'speaker_0' },
            { 'id' => 1, 'start' => 4.0, 'end' => 7.0, 'text' => 'I would like to buy a phone.', 'speaker' => 'speaker_1' }
          ],
          'words' => []
        }
      end

      before do
        allow(mock_audio).to receive(:transcribe).and_return(diarized_response)
      end

      it 'returns 200 with transcription result' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'merchant_buyer'
        }

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['mode']).to eq('merchant_buyer')
        expect(body['full_text']).to include('Hello')
        expect(body['segments']).to be_an(Array)
        expect(body['speakers']).to eq(%w[A B])
      end

      it 'includes speaker labels in the response' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'merchant_buyer'
        }

        body = JSON.parse(last_response.body)
        expect(body['speaker_labels']).to eq({ 'A' => 'A', 'B' => 'B' })
      end

      it 'returns nil translation when translate is not requested' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'merchant_buyer'
        }

        body = JSON.parse(last_response.body)
        expect(body['translation']).to be_nil
      end
    end

    context 'with valid disfluency request' do
      let(:disfluency_response) do
        {
          'text' => 'Um, I was, uh, thinking about going.',
          'segments' => [
            { 'id' => 0, 'start' => 0.0, 'end' => 3.0, 'text' => 'Um, I was, uh, thinking about going.' }
          ]
        }
      end

      let(:regex_analyzer_result) do
        {
          annotated_sentences: [
            { text: 'Um, I was, uh, thinking about going.', disfluencies: [], struggle_score: 0.0 }
          ],
          summary: { total_disfluencies: 0, disfluency_rate: 0.0, by_category: {}, most_common_fillers: {} }
        }
      end

      let(:llm_analyzer_result) do
        {
          annotated_sentences: [
            { text: 'Um, I was, uh, thinking about going.', disfluencies: [], struggle_score: 0.0 }
          ],
          summary: { total_disfluencies: 0, disfluency_rate: 0.0, by_category: {}, most_common_fillers: {} }
        }
      end

      before do
        allow(mock_audio).to receive(:transcribe).and_return(disfluency_response)
        allow(RegexDisfluencyAnalyzer).to receive(:analyze).and_return(regex_analyzer_result)
        allow(LlmDisfluencyAnalyzer).to receive(:analyze).and_return(llm_analyzer_result)
      end

      it 'returns 200 with disfluency analysis result' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'disfluency'
        }

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body['mode']).to eq('disfluency')
        expect(body['full_text']).to include('Um')
        expect(body['regex_analysis']).to be_a(Hash)
        expect(body['llm_analysis']).to be_a(Hash)
      end
    end

    context 'when OpenAI API returns an error' do
      before do
        allow(mock_audio).to receive(:transcribe).and_return(
          { 'error' => { 'message' => 'Server error' } }
        )
      end

      it 'returns 502 with error message' do
        post '/api/transcribe', {
          file: Rack::Test::UploadedFile.new(fixture_path, 'audio/mpeg'),
          mode: 'merchant_buyer'
        }

        expect(last_response.status).to eq(502)
        body = JSON.parse(last_response.body)
        expect(body['error']).to include('OpenAI API error')
      end
    end
  end
end
