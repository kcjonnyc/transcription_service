# frozen_string_literal: true

# Regex-based disfluency detection engine
class RegexDisfluencyAnalyzer
  include DisfluencyAnalysis

  SIMPLE_FILLERS = %w[um uh hmm basically actually literally].freeze #: Array[String]
  MULTI_WORD_FILLERS = ['you know', 'i mean'].freeze #: Array[String]

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

  #: (String, Regexp, String, capture_group: Integer) -> Array[Hash[Symbol, untyped]]
  def scan_pattern(sentence, pattern, category, capture_group: 0)
    results = []
    sentence.scan(pattern) do
      match = Regexp.last_match
      text = match[capture_group]
      position = match.begin(capture_group)
      results << {
        category: category,
        text: text,
        position: position,
        length: text.length
      }
    end
    results
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_filler_words(sentence)
    disfluencies = []

    (MULTI_WORD_FILLERS + SIMPLE_FILLERS).each do |filler|
      disfluencies.concat(scan_pattern(sentence, /\b#{Regexp.escape(filler)}\b/i, 'filler_words'))
    end

    # "like"/"right" as filler: at start followed by comma, or surrounded by commas
    %w[like right].each do |word|
      disfluencies.concat(scan_pattern(sentence, /\A#{word}(?=,)/i, 'filler_words'))
      disfluencies.concat(scan_pattern(sentence, /,\s*(#{word})\s*,/i, 'filler_words', capture_group: 1))
    end

    disfluencies
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_word_repetitions(sentence)
    scan_pattern(sentence, /\b(\w+)(\s+\1)+\b/i, 'consecutive_word_repetitions')
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
    scan_pattern(sentence, /\b\w*([a-zA-Z])\1{2,}\w*\b/, 'prolongations')
  end

  #: (String) -> Array[Hash[Symbol, untyped]]
  def detect_revisions(sentence)
    scan_pattern(sentence, /\b(\w+)\s*--\s*(\w+)/, 'revisions')
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

  #: (Array[Hash[Symbol, untyped]], Array[Hash[Symbol, untyped]], String, Array[Hash[String, untyped]]) -> [Array[Hash[Symbol, untyped]], Array[Hash[Symbol, untyped]]]
  def inject_pauses_into_sentences(annotated_sentences, pauses, full_text, words)
    return [annotated_sentences, []] if pauses.empty? || words.empty?

    word_positions = find_word_positions(full_text, words)
    sentence_ranges = find_sentence_ranges(full_text, annotated_sentences)

    within_sentence_pauses = []
    sentence_insertions = Hash.new { |h, k| h[k] = [] }

    pauses.each do |pause|
      after_pos = word_positions[pause[:after_word_index]]
      before_pos = word_positions[pause[:before_word_index]]
      next unless after_pos && before_pos

      gap_start = after_pos[:end]
      gap_end = before_pos[:start]

      sentence_idx = sentence_ranges.index do |sr|
        sr && gap_start >= sr[:start] && gap_end <= sr[:end]
      end
      next unless sentence_idx

      sr = sentence_ranges[sentence_idx]
      sentence_insertions[sentence_idx] << {
        pause: pause,
        insert_at: gap_end - sr[:start]
      }
      within_sentence_pauses << pause
    end

    updated_sentences = annotated_sentences.each_with_index.map do |sentence, idx|
      insertions = sentence_insertions[idx]
      next sentence unless insertions

      text = sentence[:text]
      disfluencies = sentence[:disfluencies].dup

      insertions.sort_by { |ins| -ins[:insert_at] }.each do |ins|
        insert_at = ins[:insert_at]
        marker = "[Pause #{ins[:pause][:duration]}s]"
        insertion = "#{marker} "

        text = text[0...insert_at] + insertion + text[insert_at..]

        disfluencies = disfluencies.map do |d|
          d[:position] >= insert_at ? d.merge(position: d[:position] + insertion.length) : d
        end

        disfluencies << {
          category: 'pauses',
          text: marker,
          position: insert_at,
          length: marker.length
        }
      end

      sentence.merge(text: text, disfluencies: disfluencies)
    end

    [updated_sentences, within_sentence_pauses]
  end

  #: (Hash[Symbol, untyped]) -> Integer
  def occurrence_count(_disfluency)
    1
  end

  #: (String, Array[Hash[String, untyped]]) -> Array[Hash[Symbol, Integer]?]
  def find_word_positions(full_text, words)
    positions = []
    scan_pos = 0

    words.each do |w|
      word_text = w['word']&.strip
      unless word_text && !word_text.empty?
        positions << nil
        next
      end

      idx = full_text.index(word_text, scan_pos)
      if idx
        positions << { start: idx, end: idx + word_text.length }
        scan_pos = idx + word_text.length
        next
      end

      core = word_text.gsub(/\A[^a-zA-Z0-9]+|[^a-zA-Z0-9]+\z/, '')
      idx = full_text.index(core, scan_pos) if core && !core.empty?
      if idx
        positions << { start: idx, end: idx + core.length }
        scan_pos = idx + core.length
      else
        positions << nil
      end
    end

    positions
  end

  #: (String, Array[Hash[Symbol, untyped]]) -> Array[Hash[Symbol, Integer]?]
  def find_sentence_ranges(full_text, annotated_sentences)
    ranges = []
    pos = 0

    annotated_sentences.each do |s|
      idx = full_text.index(s[:text], pos)
      if idx
        ranges << { start: idx, end: idx + s[:text].length }
        pos = idx + s[:text].length
      else
        ranges << nil
      end
    end

    ranges
  end

  #: (Array[Hash[Symbol, untyped]]) -> Array[Hash[Symbol, untyped]]
  def deduplicate(disfluencies)
    sorted = disfluencies.sort_by { |d| d[:position] }
    result = []
    covered_ranges = []

    sorted.each do |d|
      d_range = (d[:position]...(d[:position] + d[:length]))
      overlaps = covered_ranges.any? { |r| ranges_overlap?(r, d_range) }
      unless overlaps
        result << d
        covered_ranges << d_range
      end
    end

    result
  end

  #: (Range[Integer], Range[Integer]) -> bool
  def ranges_overlap?(r1, r2)
    r1.begin < r2.end && r2.begin < r1.end
  end
end
