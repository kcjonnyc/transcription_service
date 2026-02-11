# frozen_string_literal: true

# LLM-based disfluency detection engine using OpenAI chat completions.
#
# Flow for each sentence:
#   1. index_words        — tokenise the sentence into {index, text} pairs
#   2. format_indexed     — build an indexed string like "[0]Um, [1]I [2]was"
#   3. LLM call           — send the indexed string to the OpenAI client
#   4. parse_disfluencies — walk the hierarchical hash and build per-occurrence entries
class LlmDisfluencyAnalyzer
  include DisfluencyAnalysis

  #: (?client: OpenAIClient?) -> void
  def initialize(client: nil)
    @client = client || OpenAIClient.new #: OpenAIClient
  end

  # Class-method shim so existing call sites (LlmDisfluencyAnalyzer.analyze) keep working.
  #: (String, words: Array[Hash[String, untyped]], ?client: OpenAIClient?) -> Hash[Symbol, untyped]
  def self.analyze(text, words: [], client: nil)
    new(client: client).analyze(text, words: words)
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
    indexed_text = format_indexed(indexed_words)
    raw = @client.chat_analyze_disfluencies(indexed_text)

    { tokens: indexed_words, disfluencies: parse_disfluencies(raw, indexed_words) }
  end

  private

  # Walk the hierarchical hash from the LLM and build one disfluency entry per occurrence.
  #
  # Expected format:
  #   { "filler_words" => { "um" => [0, 5], "you know" => [[3, 4]] },
  #     "word_repetitions" => { "I I" => [[1, 2]] } }
  #
  # Single-word disfluencies have flat integer indices; multi-word have arrays of index-arrays.
  #: (Hash[String, untyped], Array[Hash[Symbol, untyped]]) -> Array[Hash[Symbol, untyped]]
  def parse_disfluencies(raw, indexed_words)
    return [] unless raw.is_a?(Hash)

    disfluencies = []
    raw.each do |category, words_hash|
      next unless words_hash.is_a?(Hash)

      words_hash.each do |_text, indices_data|
        Array(indices_data).each do |item|
          word_indices = item.is_a?(Array) ? item : [item]
          text = word_indices.map { |i|
            indexed_words.find { |w| w[:index] == i }&.dig(:text)
          }.compact.join(' ')
          next if text.empty?

          disfluencies << { category: category, text: text, word_indices: word_indices }
        end
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

  # Build the indexed string sent to the LLM, e.g. "[0]Um, [1]I [2]was".
  #: (Array[Hash[Symbol, untyped]]) -> String
  def format_indexed(indexed_words)
    indexed_words.map { |w| "[#{w[:index]}]#{w[:text]}" }.join(' ')
  end
end
