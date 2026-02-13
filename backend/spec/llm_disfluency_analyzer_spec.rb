# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LlmDisfluencyAnalyzer do
  let(:client) { instance_double(OpenAIClient) }
  let(:analyzer) { LlmDisfluencyAnalyzer.new(client: client) }

  before do
    allow(client).to receive(:chat_analyze_disfluencies).and_return({})
  end

  # ---------------------------------------------------------------------------
  # #analyze_sentence
  # ---------------------------------------------------------------------------
  describe '#analyze_sentence' do
    it 'tokenizes the sentence into indexed word tokens' do
      result = analyzer.analyze_sentence('Um, I was thinking.')

      expect(result[:tokens]).to eq([
        { index: 0, text: 'Um,' },
        { index: 1, text: 'I' },
        { index: 2, text: 'was' },
        { index: 3, text: 'thinking.' }
      ])
    end

    it 'sends the indexed words array to the client' do
      expect(client).to receive(:chat_analyze_disfluencies)
        .with([
          { index: 0, text: 'Um,' },
          { index: 1, text: 'I' },
          { index: 2, text: 'was' },
          { index: 3, text: 'thinking.' }
        ])

      analyzer.analyze_sentence('Um, I was thinking.')
    end

    it 'returns an empty disfluencies array when the LLM finds none' do
      result = analyzer.analyze_sentence('Um, I was thinking.')

      expect(result[:disfluencies]).to eq([])
    end

    it 'parses and returns disfluencies with symbolized keys' do
      allow(client).to receive(:chat_analyze_disfluencies).and_return({
        'filler_words' => { 'Um,' => [{ 'start' => 0, 'end' => 0 }] }
      })

      result = analyzer.analyze_sentence('Um, I was thinking.')

      expect(result[:disfluencies]).to eq([
        { category: 'filler_words', text: 'Um,', ranges: [{ start: 0, end: 0 }] }
      ])
    end

    it 'skips categories with non-hash values' do
      allow(client).to receive(:chat_analyze_disfluencies).and_return({
        'filler_words' => 'not a hash',
        'consecutive_word_repetitions' => { 'I I' => [{ 'start' => 1, 'end' => 2 }] }
      })

      result = analyzer.analyze_sentence('Um, I I was thinking.')

      expect(result[:disfluencies].length).to eq(1)
      expect(result[:disfluencies][0][:category]).to eq('consecutive_word_repetitions')
      expect(result[:disfluencies][0][:ranges]).to eq([{ start: 1, end: 2 }])
    end

    it 'stores all occurrences in a single entry with multiple ranges' do
      allow(client).to receive(:chat_analyze_disfluencies).and_return({
        'filler_words' => { 'Um,' => [{ 'start' => 0, 'end' => 0 }, { 'start' => 4, 'end' => 4 }] }
      })

      result = analyzer.analyze_sentence('Um, I was thinking uh, yeah.')

      fillers = result[:disfluencies].select { |d| d[:category] == 'filler_words' }

      expect(fillers.length).to eq(1)
      expect(fillers[0][:ranges]).to eq([{ start: 0, end: 0 }, { start: 4, end: 4 }])
    end

    it 'parses range-based multi-word disfluency' do
      allow(client).to receive(:chat_analyze_disfluencies).and_return({
        'consecutive_word_repetitions' => { 'I I' => [{ 'start' => 1, 'end' => 2 }] }
      })

      result = analyzer.analyze_sentence('Um, I I was thinking.')

      expect(result[:disfluencies].length).to eq(1)
      expect(result[:disfluencies][0][:ranges]).to eq([{ start: 1, end: 2 }])
    end

    it 'uses LLM-provided text for disfluency entries' do
      allow(client).to receive(:chat_analyze_disfluencies).and_return({
        'filler_words' => { 'um' => [{ 'start' => 0, 'end' => 0 }] }
      })

      result = analyzer.analyze_sentence('Um, I was thinking.')

      expect(result[:disfluencies][0][:text]).to eq('um')
    end
  end

  # ---------------------------------------------------------------------------
  # #analyze
  # ---------------------------------------------------------------------------
  describe '#analyze' do
    context 'without pauses (no timing gaps)' do
      let(:words) do
        [
          { 'word' => 'I', 'start' => 0.0, 'end' => 0.2 },
          { 'word' => 'was', 'start' => 0.3, 'end' => 0.5 },
          { 'word' => 'thinking.', 'start' => 0.6, 'end' => 1.0 }
        ]
      end

      it 'returns annotated_sentences, pauses, and summary' do
        result = analyzer.analyze('I was thinking.', words: words)

        expect(result).to have_key(:annotated_sentences)
        expect(result).to have_key(:pauses)
        expect(result).to have_key(:summary)
      end

      it 'calls analyze_sentence once for a single sentence' do
        expect(client).to receive(:chat_analyze_disfluencies).once

        analyzer.analyze('I was thinking.', words: words)
      end

      it 'returns empty pauses array when no timing gaps exceed threshold' do
        result = analyzer.analyze('I was thinking.', words: words)

        expect(result[:pauses]).to eq([])
      end

      it 'includes correct token count in summary calculation' do
        result = analyzer.analyze('I was thinking.', words: words)

        expect(result[:summary][:total_disfluencies]).to eq(0)
        expect(result[:summary][:disfluency_rate]).to eq(0.0)
      end

      it 'sends indexed words to the LLM without pause markers' do
        expect(client).to receive(:chat_analyze_disfluencies)
          .with([
            { index: 0, text: 'I' },
            { index: 1, text: 'was' },
            { index: 2, text: 'thinking.' }
          ])

        analyzer.analyze('I was thinking.', words: words)
      end
    end

    context 'with pauses (timing gap exceeds threshold)' do
      let(:text) { 'I was thinking.' }
      let(:words) do
        [
          { 'word' => 'I', 'start' => 0.0, 'end' => 0.2 },
          { 'word' => 'was', 'start' => 0.3, 'end' => 0.5 },
          { 'word' => 'thinking.', 'start' => 2.0, 'end' => 2.5 }
        ]
      end

      it 'sends indexed words to the LLM without pause markers' do
        expect(client).to receive(:chat_analyze_disfluencies)
          .with([
            { index: 0, text: 'I' },
            { index: 1, text: 'was' },
            { index: 2, text: 'thinking.' }
          ])

        analyzer.analyze(text, words: words)
      end

      it 'detects the pause between was and thinking' do
        result = analyzer.analyze(text, words: words)

        expect(result[:pauses].length).to eq(1)
        expect(result[:pauses][0][:after_word]).to eq('was')
        expect(result[:pauses][0][:before_word]).to eq('thinking.')
        expect(result[:pauses][0][:duration]).to eq(1.5)
      end

      it 'counts pauses in summary total_disfluencies' do
        result = analyzer.analyze(text, words: words)

        expect(result[:summary][:total_disfluencies]).to eq(1)
      end
    end

    context 'pauses are returned as separate data channel' do
      let(:text) { 'I was thinking.' }
      let(:words) do
        [
          { 'word' => 'I', 'start' => 0.0, 'end' => 0.2 },
          { 'word' => 'was', 'start' => 0.3, 'end' => 0.5 },
          { 'word' => 'thinking.', 'start' => 2.0, 'end' => 2.5 }
        ]
      end

      it 'does not inject pause tokens into annotated sentence tokens' do
        result = analyzer.analyze(text, words: words)
        tokens = result[:annotated_sentences][0][:tokens]

        expect(tokens.none? { |t| t[:pause] }).to be true
        expect(tokens.length).to eq(3)
      end

      it 'includes pauses in the top-level pauses array' do
        result = analyzer.analyze(text, words: words)

        expect(result[:pauses].length).to eq(1)
        expect(result[:pauses][0][:after_word]).to eq('was')
      end
    end

    context 'return structure' do
      it 'returns a hash with :annotated_sentences, :pauses, and :summary keys' do
        result = analyzer.analyze('Hello there.', words: [])

        expect(result).to be_a(Hash)
        expect(result).to have_key(:annotated_sentences)
        expect(result).to have_key(:pauses)
        expect(result).to have_key(:summary)
      end

      it 'each annotated sentence has :text, :tokens, :disfluencies, :struggle_score' do
        result = analyzer.analyze('Hello there.', words: [])
        sentence = result[:annotated_sentences][0]

        expect(sentence).to have_key(:text)
        expect(sentence).to have_key(:tokens)
        expect(sentence).to have_key(:disfluencies)
        expect(sentence).to have_key(:struggle_score)
      end

      it 'summary has :total_disfluencies, :disfluency_rate, :by_category, :most_common_fillers' do
        result = analyzer.analyze('Hello there.', words: [])
        summary = result[:summary]

        expect(summary).to have_key(:total_disfluencies)
        expect(summary).to have_key(:disfluency_rate)
        expect(summary).to have_key(:by_category)
        expect(summary).to have_key(:most_common_fillers)
      end
    end

    context 'with multiple sentences' do
      it 'calls analyze_sentence for each sentence' do
        expect(client).to receive(:chat_analyze_disfluencies).twice

        analyzer.analyze('Hello there. How are you?', words: [])
      end

      it 'aggregates disfluencies from all sentences' do
        call_count = 0
        allow(client).to receive(:chat_analyze_disfluencies) do
          call_count += 1
          if call_count == 1
            { 'filler_words' => { 'Um,' => [{ 'start' => 0, 'end' => 0 }] } }
          else
            { 'filler_words' => { 'Uh,' => [{ 'start' => 0, 'end' => 0 }] } }
          end
        end

        result = analyzer.analyze('Um, hello. Uh, yeah.', words: [])

        expect(result[:summary][:total_disfluencies]).to eq(2)
      end
    end

    context 'with clean text and no words' do
      it 'returns zero stats and empty pauses' do
        result = analyzer.analyze('The weather is nice today.', words: [])

        expect(result[:annotated_sentences][0][:disfluencies]).to eq([])
        expect(result[:annotated_sentences][0][:struggle_score]).to eq(0.0)
        expect(result[:pauses]).to eq([])
        expect(result[:summary][:total_disfluencies]).to eq(0)
        expect(result[:summary][:disfluency_rate]).to eq(0.0)
      end
    end
  end

end
