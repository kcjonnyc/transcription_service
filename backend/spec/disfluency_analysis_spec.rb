# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe DisfluencyAnalysis do
  # Harness that mimics RegexDisfluencyAnalyzer: each disfluency counts as 1
  let(:regex_style) do
    Class.new do
      include DisfluencyAnalysis
      public :compute_struggle_score, :build_summary, :build_by_category, :build_most_common_fillers

      def occurrence_count(_disfluency)
        1
      end
    end.new
  end

  # Harness that mimics LlmDisfluencyAnalyzer: count from ranges length
  let(:llm_style) do
    Class.new do
      include DisfluencyAnalysis
      public :compute_struggle_score, :build_summary, :build_by_category, :build_most_common_fillers

      def occurrence_count(disfluency)
        disfluency[:ranges].length
      end
    end.new
  end

  describe '#compute_struggle_score' do
    it 'returns 0.0 when word_count is zero' do
      expect(regex_style.compute_struggle_score([], 0)).to eq(0.0)
    end

    it 'returns 0.0 when disfluencies are empty' do
      expect(regex_style.compute_struggle_score([], 5)).to eq(0.0)
    end

    it 'computes weighted score for regex-style (1 per disfluency)' do
      disfluencies = [{ category: 'filler_words' }]
      # weight 1, 1 occurrence, 3 words => (1/3)*100 = 33.3
      expect(regex_style.compute_struggle_score(disfluencies, 3)).to be_within(0.1).of(33.3)
    end

    it 'computes weighted score for llm-style (ranges.length per disfluency)' do
      disfluencies = [{ category: 'filler_words', ranges: [{ start: 0, end: 0 }, { start: 4, end: 4 }] }]
      # weight 1, 2 occurrences, 5 words => (2/5)*100 = 40.0
      expect(llm_style.compute_struggle_score(disfluencies, 5)).to be_within(0.1).of(40.0)
    end

    it 'caps the score at 100.0' do
      disfluencies = Array.new(20) { { category: 'sound_repetitions' } }
      expect(regex_style.compute_struggle_score(disfluencies, 1)).to eq(100.0)
    end
  end

  describe '#build_summary' do
    it 'returns correct structure with zero stats for no disfluencies' do
      summary = regex_style.build_summary([], 10, [])

      expect(summary[:total_disfluencies]).to eq(0)
      expect(summary[:disfluency_rate]).to eq(0.0)
      expect(summary[:by_category]).to eq({})
      expect(summary[:most_common_fillers]).to eq({})
    end

    it 'counts pauses in total for regex-style' do
      pauses = [{ duration: 1.5 }]
      summary = regex_style.build_summary([], 10, pauses)

      expect(summary[:total_disfluencies]).to eq(1)
    end

    it 'includes pause category in by_category when pauses present' do
      pauses = [{ duration: 1.5 }, { duration: 2.0 }]
      summary = regex_style.build_summary([], 10, pauses)

      expect(summary[:by_category]['pauses'][:count]).to eq(2)
      expect(summary[:by_category]['pauses'][:examples]).to eq(['1.5s', '2.0s'])
    end

    it 'uses occurrence_count for llm-style totals' do
      disfluencies = [{ category: 'filler_words', text: 'um', ranges: [{ start: 0, end: 0 }, { start: 3, end: 3 }, { start: 7, end: 7 }] }]
      summary = llm_style.build_summary(disfluencies, 10, [])

      expect(summary[:total_disfluencies]).to eq(3)
    end
  end

  describe '#build_by_category' do
    it 'groups by category with count and examples for regex-style' do
      disfluencies = [
        { category: 'filler_words', text: 'um' },
        { category: 'filler_words', text: 'uh' },
        { category: 'consecutive_word_repetitions', text: 'the the' }
      ]
      result = regex_style.build_by_category(disfluencies)

      expect(result['filler_words'][:count]).to eq(2)
      expect(result['filler_words'][:examples]).to eq(%w[um uh])
      expect(result['consecutive_word_repetitions'][:count]).to eq(1)
    end

    it 'uses occurrence_count for llm-style counts' do
      disfluencies = [
        { category: 'filler_words', text: 'um', ranges: [{ start: 0, end: 0 }, { start: 3, end: 3 }] }
      ]
      result = llm_style.build_by_category(disfluencies)

      expect(result['filler_words'][:count]).to eq(2)
    end

    it 'limits examples to 5' do
      disfluencies = (1..8).map { |i| { category: 'filler_words', text: "word#{i}" } }
      result = regex_style.build_by_category(disfluencies)

      expect(result['filler_words'][:examples].length).to eq(5)
    end
  end

  describe '#build_most_common_fillers' do
    it 'returns empty hash when no filler_words' do
      expect(regex_style.build_most_common_fillers([])).to eq({})
    end

    it 'counts fillers for regex-style (1 each)' do
      disfluencies = [
        { category: 'filler_words', text: 'um' },
        { category: 'filler_words', text: 'um' },
        { category: 'filler_words', text: 'uh' }
      ]
      result = regex_style.build_most_common_fillers(disfluencies)

      expect(result['um']).to eq(2)
      expect(result['uh']).to eq(1)
    end

    it 'counts fillers for llm-style (ranges.length each)' do
      disfluencies = [
        { category: 'filler_words', text: 'um', ranges: [{ start: 0, end: 0 }, { start: 3, end: 3 }, { start: 7, end: 7 }] }
      ]
      result = llm_style.build_most_common_fillers(disfluencies)

      expect(result['um']).to eq(3)
    end

    it 'limits to top 10' do
      disfluencies = (1..15).map { |i| { category: 'filler_words', text: "filler#{i}" } }
      result = regex_style.build_most_common_fillers(disfluencies)

      expect(result.length).to eq(10)
    end
  end
end
