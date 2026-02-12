# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Strategies::MerchantBuyerStrategy do
  let(:client) { instance_double(OpenAIClient) }
  let(:strategy) { described_class.new(client) }
  let(:file) { double('file') }
  let(:filename) { 'test.mp3' }

  let(:diarized_response) do
    {
      'text' => 'Hello how can I help you? I would like to buy a phone.',
      'segments' => [
        { 'id' => 0, 'start' => 0.0, 'end' => 3.5, 'text' => 'Hello how can I help you?', 'speaker' => 'speaker_0' },
        { 'id' => 1, 'start' => 4.0, 'end' => 7.0, 'text' => 'I would like to buy a phone.', 'speaker' => 'speaker_1' }
      ],
      'words' => [
        { 'word' => 'Hello', 'start' => 0.0, 'end' => 0.5, 'speaker' => 'speaker_0' },
        { 'word' => 'how', 'start' => 0.5, 'end' => 0.8, 'speaker' => 'speaker_0' },
        { 'word' => 'I', 'start' => 4.0, 'end' => 4.2, 'speaker' => 'speaker_1' }
      ]
    }
  end

  describe '#transcribe' do
    before do
      allow(client).to receive(:transcribe_diarized).and_return(diarized_response)
    end

    it 'calls transcribe_diarized on the client' do
      strategy.transcribe(file, filename)

      expect(client).to have_received(:transcribe_diarized).with(file)
    end

    it 'returns a hash with mode set to merchant_buyer' do
      result = strategy.transcribe(file, filename)

      expect(result[:mode]).to eq('merchant_buyer')
    end

    it 'includes the full text from the response' do
      result = strategy.transcribe(file, filename)

      expect(result[:full_text]).to eq('Hello how can I help you? I would like to buy a phone.')
    end

    it 'maps the first unique speaker to A and the second to B' do
      result = strategy.transcribe(file, filename)

      expect(result[:segments][0][:speaker]).to eq('A')
      expect(result[:segments][1][:speaker]).to eq('B')
    end

    it 'includes all segments with correct structure' do
      result = strategy.transcribe(file, filename)

      expect(result[:segments]).to be_an(Array)
      expect(result[:segments].length).to eq(2)

      first_segment = result[:segments][0]
      expect(first_segment[:id]).to eq(0)
      expect(first_segment[:start]).to eq(0.0)
      expect(first_segment[:end]).to eq(3.5)
      expect(first_segment[:text]).to eq('Hello how can I help you?')
      expect(first_segment[:speaker]).to eq('A')
    end

    it 'returns the list of unique speakers' do
      result = strategy.transcribe(file, filename)

      expect(result[:speakers]).to eq(%w[A B])
    end

    it 'returns speaker labels mapping' do
      result = strategy.transcribe(file, filename)

      expect(result[:speaker_labels]).to eq({ 'A' => 'A', 'B' => 'B' })
    end

    it 'returns nil translation when translate is false' do
      result = strategy.transcribe(file, filename)

      expect(result[:translation]).to be_nil
    end

    context 'with three speakers' do
      let(:diarized_response) do
        {
          'text' => 'Hello. Hi. Hey.',
          'segments' => [
            { 'id' => 0, 'start' => 0.0, 'end' => 1.0, 'text' => 'Hello.', 'speaker' => 'speaker_0' },
            { 'id' => 1, 'start' => 1.0, 'end' => 2.0, 'text' => 'Hi.', 'speaker' => 'speaker_1' },
            { 'id' => 2, 'start' => 2.0, 'end' => 3.0, 'text' => 'Hey.', 'speaker' => 'speaker_2' }
          ]
        }
      end

      it 'maps third speaker to C' do
        result = strategy.transcribe(file, filename)

        expect(result[:segments][2][:speaker]).to eq('C')
        expect(result[:speakers]).to eq(%w[A B C])
      end
    end

    context 'when segments lack speaker field' do
      let(:diarized_response) do
        {
          'text' => 'Hello how can I help you?',
          'segments' => [
            { 'id' => 0, 'start' => 0.0, 'end' => 3.5, 'text' => 'Hello how can I help you?' }
          ]
        }
      end

      it 'falls back to unknown speaker label' do
        result = strategy.transcribe(file, filename)

        expect(result[:segments][0][:speaker]).to eq('A')
        expect(result[:speakers]).to eq(['A'])
      end
    end

    context 'with translate: true' do
      let(:translation_response) do
        {
          'text' => 'Hello how can I help you? I would like to buy a phone.'
        }
      end

      before do
        allow(client).to receive(:translate_to_english).and_return(translation_response)
      end

      it 'calls translate_to_english on the client' do
        strategy.transcribe(file, filename, translate: true)

        expect(client).to have_received(:translate_to_english).with(file)
      end

      it 'includes the translation text in the result' do
        result = strategy.transcribe(file, filename, translate: true)

        expect(result[:translation]).to eq('Hello how can I help you? I would like to buy a phone.')
      end
    end

    context 'with translate: false' do
      it 'does not call translate_to_english' do
        strategy.transcribe(file, filename, translate: false)

        expect(client).not_to have_received(:translate_to_english) if client.respond_to?(:translate_to_english)
      end
    end
  end
end
