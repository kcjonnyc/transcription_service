# frozen_string_literal: true

# LLM-based disfluency detection engine using OpenAI chat completions.
#
# Flow for each sentence:
#   1. index_words        — tokenise the sentence into {index, text} pairs
#   2. LLM call           — send the indexed words to the OpenAI client
#   4. parse_disfluencies — walk the hierarchical hash and build per-occurrence entries
class LlmDisfluencyAnalyzer
  include DisfluencyAnalysis

  #: (?client: OpenAIClient?) -> void
  def initialize(client: nil)
    @client = client || OpenAIClient.new #: OpenAIClient
  end

  #: (String, words: Array[Hash[String, untyped]]) -> Hash[Symbol, untyped]
  def analyze(text, words: [])
    sentences = split_sentences(text)
    all_disfluencies = []
    total_words = 0
    pauses = detect_pauses(words)

    annotated_sentences = sentences.map do |sentence|
      result = analyze_sentence(sentence)
      word_count = result[:tokens].length
      total_words += word_count
      all_disfluencies.concat(result[:disfluencies])

      {
        text: sentence,
        tokens: result[:tokens],
        disfluencies: result[:disfluencies],
        struggle_score: compute_struggle_score(result[:disfluencies], word_count)
      }
    end

    {
      annotated_sentences: annotated_sentences,
      pauses: pauses,
      summary: build_summary(all_disfluencies, total_words, pauses)
    }
  end

  #: (String) -> Hash[Symbol, untyped]
  def analyze_sentence(sentence)
    indexed_words = index_words(sentence)
    raw = @client.chat_analyze_disfluencies(indexed_words)

    { tokens: indexed_words, disfluencies: parse_disfluencies(raw, indexed_words) }
  end

  private

  # Walk the hierarchical hash from the LLM and build one disfluency entry per occurrence.
  #
  # Expected format:
  #   { "filler_words" => { "um" => [0, 5], "you know" => [[3, 4]] },
  #     "consecutive_word_repetitions" => { "I I" => [[1, 2]] } }
  #
  # Single-word disfluencies have flat integer indices; multi-word have arrays of index-arrays.
  #: (Hash[String, untyped], Array[Hash[Symbol, untyped]]) -> Array[Hash[Symbol, untyped]]
  def parse_disfluencies(raw, indexed_words)
    return [] unless raw.is_a?(Hash)

    disfluencies = []
    raw.each do |category, words_hash|
      next unless words_hash.is_a?(Hash)

      words_hash.each do |text, indices_data|
        if indices_data.is_a?(Array) && indices_data.first.is_a?(Array)
          # Multi-word: [[1, 2], [7, 8]] → flat [1, 2, 7, 8], count 2
          flat_indices = indices_data.flatten
          count = indices_data.length
        else
          # Single-word: [0, 5] → unchanged, count = array length
          flat_indices = Array(indices_data)
          count = flat_indices.length
        end

        disfluencies << { category: category, text: text, word_indices: flat_indices, count: count }
      end
    end

    disfluencies
  end

  # Tokenise a sentence into words, tracking each word's sequential index.
  #   "Um, I was" => [{ index: 0, text: "Um," }, { index: 1, text: "I" }, ...]
  #: (String) -> Array[Hash[Symbol, untyped]]
  def index_words(sentence)
    sentence.split(/\s+/).reject(&:empty?).each_with_index.map do |word, i|
      { index: i, text: word }
    end
  end

  #: (Hash[Symbol, untyped]) -> Integer
  def occurrence_count(disfluency)
    disfluency[:count]
  end
end
