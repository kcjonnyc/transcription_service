# frozen_string_literal: true

# Regex-based disfluency detection engine
class RegexDisfluencyAnalyzer
  include DisfluencyAnalysis

  SIMPLE_FILLERS = %w[um uh hmm basically actually literally].freeze #: Array[String]
  MULTI_WORD_FILLERS = ['you know', 'i mean'].freeze #: Array[String]

  # Class-method shim so existing call sites (RegexDisfluencyAnalyzer.analyze) keep working.
  #: (String, words: Array[Hash[String, untyped]]) -> Hash[Symbol, untyped]
  def self.analyze(text, words: [])
    new.analyze(text, words: words)
  end

  #: (String, words: Array[Hash[String, untyped]]) -> Hash[Symbol, untyped]
  def analyze(text, words: [])
    sentences = split_sentences(text)
    all_disfluencies = []
    total_words = 0
    pauses = detect_pauses(words)

    annotated_sentences = sentences.map do |sentence|
      disfluencies = analyze_sentence(sentence)
      word_count = count_words(sentence)
      total_words += word_count
      all_disfluencies.concat(disfluencies)

      {
        text: sentence,
        disfluencies: disfluencies,
        struggle_score: compute_struggle_score(disfluencies, word_count)
      }
    end

    annotated_sentences, within_sentence_pauses = inject_pauses_into_sentences(
      annotated_sentences, pauses, text, words
    )

    {
      annotated_sentences: annotated_sentences,
      pauses: within_sentence_pauses,
      summary: build_summary(all_disfluencies, total_words, within_sentence_pauses)
    }
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def analyze_sentence(sentence)
    disfluencies = []

    disfluencies.concat(detect_revisions(sentence))
    disfluencies.concat(detect_sound_repetitions(sentence))
    disfluencies.concat(detect_partial_words(sentence))
    disfluencies.concat(detect_prolongations(sentence))
    disfluencies.concat(detect_word_repetitions(sentence))
    disfluencies.concat(detect_filler_words(sentence))

    deduplicate(disfluencies)
  end

  private

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_filler_words(sentence)
    disfluencies = []

    # Multi-word fillers first
    MULTI_WORD_FILLERS.each do |filler|
      pattern = /\b#{Regexp.escape(filler)}\b/i
      sentence.scan(pattern) do
        match = Regexp.last_match
        disfluencies << {
          category: 'filler_words',
          text: match[0],
          position: match.begin(0),
          length: match[0].length
        }
      end
    end

    # Simple fillers
    SIMPLE_FILLERS.each do |filler|
      pattern = /\b#{Regexp.escape(filler)}\b/i
      sentence.scan(pattern) do
        match = Regexp.last_match
        disfluencies << {
          category: 'filler_words',
          text: match[0],
          position: match.begin(0),
          length: match[0].length
        }
      end
    end

    # "like" as filler: at start of sentence followed by comma
    sentence.scan(/\ALike(?=,)/i) do
      match = Regexp.last_match
      disfluencies << {
        category: 'filler_words',
        text: match[0],
        position: match.begin(0),
        length: match[0].length
      }
    end

    # ", like," in the middle
    sentence.scan(/,\s*(like)\s*,/i) do
      full_match = Regexp.last_match
      like_text = full_match[1]
      like_pos = full_match.begin(1)
      disfluencies << {
        category: 'filler_words',
        text: like_text,
        position: like_pos,
        length: like_text.length
      }
    end

    # "right" as filler: at start of sentence followed by comma
    sentence.scan(/\Aright(?=,)/i) do
      match = Regexp.last_match
      disfluencies << {
        category: 'filler_words',
        text: match[0],
        position: match.begin(0),
        length: match[0].length
      }
    end

    sentence.scan(/,\s*(right)\s*,/i) do
      full_match = Regexp.last_match
      right_text = full_match[1]
      right_pos = full_match.begin(1)
      disfluencies << {
        category: 'filler_words',
        text: right_text,
        position: right_pos,
        length: right_text.length
      }
    end

    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_word_repetitions(sentence)
    disfluencies = []
    pattern = /\b(\w+)(\s+\1)+\b/i
    sentence.scan(pattern) do
      match = Regexp.last_match
      disfluencies << {
        category: 'word_repetitions',
        text: match[0],
        position: match.begin(0),
        length: match[0].length
      }
    end
    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_sound_repetitions(sentence)
    disfluencies = []
    pattern = /\b([a-zA-Z]{1,2})-\s+([a-zA-Z]+)\b/
    sentence.scan(pattern) do
      match = Regexp.last_match
      prefix = match[1].downcase
      word = match[2].downcase
      if word.start_with?(prefix) && prefix.length < word.length
        disfluencies << {
          category: 'sound_repetitions',
          text: match[0],
          position: match.begin(0),
          length: match[0].length
        }
      end
    end
    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_prolongations(sentence)
    disfluencies = []
    pattern = /\b\w*([a-zA-Z])\1{2,}\w*\b/
    sentence.scan(pattern) do
      match = Regexp.last_match
      disfluencies << {
        category: 'prolongations',
        text: match[0],
        position: match.begin(0),
        length: match[0].length
      }
    end
    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_revisions(sentence)
    disfluencies = []
    pattern = /\b(\w+)\s*--\s*(\w+)/
    sentence.scan(pattern) do
      match = Regexp.last_match
      disfluencies << {
        category: 'revisions',
        text: match[0],
        position: match.begin(0),
        length: match[0].length
      }
    end
    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_partial_words(sentence)
    disfluencies = []
    pattern = /\b([a-zA-Z]+)-(?!-)(?=\s)/
    sentence.scan(pattern) do
      match = Regexp.last_match
      prefix = match[1].downcase
      pos = match.begin(0)

      if prefix.length <= 2
        rest = sentence[(pos + match[0].length)..]
        next_word_match = rest&.match(/^\s+([a-zA-Z]+)\b/)
        if next_word_match
          next_word = next_word_match[1].downcase
          next if next_word.start_with?(prefix) && prefix.length < next_word.length
        end
      end

      disfluencies << {
        category: 'partial_words',
        text: "#{match[1]}-",
        position: pos,
        length: match[1].length + 1
      }
    end
    disfluencies
  end
end
