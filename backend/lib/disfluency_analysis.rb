# frozen_string_literal: true

# Shared utilities for disfluency analyzers.
# Include this module to get access to sentence splitting, pause detection,
# scoring helpers, and summary building.
module DisfluencyAnalysis
  PAUSE_THRESHOLD_SECONDS = 1

  WEIGHTS = {
    'filler_words' => 1,
    'word_repetitions' => 1.5,
    'sound_repetitions' => 2,
    'prolongations' => 1.5,
    'revisions' => 1.5,
    'partial_words' => 2,
    'pauses' => 1.5
  }.freeze #: Hash[String, Integer | Float]

  private

  #: (String) -> Array[String]
  def split_sentences(text)
    text.split(/(?<=[.!?])/).map(&:strip).reject(&:empty?)
  end

  #: (Array[Hash[String, untyped]]) -> Array[Hash[Symbol, untyped]]
  def detect_pauses(words)
    return [] if words.length < 2

    pauses = []
    words.each_cons(2).with_index do |(prev_word, next_word), i|
      prev_end = prev_word['end']
      next_start = next_word['start']
      next unless prev_end && next_start

      gap = next_start - prev_end
      if gap >= PAUSE_THRESHOLD_SECONDS
        pauses << {
          category: 'pauses',
          after_word: prev_word['word']&.strip,
          before_word: next_word['word']&.strip,
          after_word_index: i,
          before_word_index: i + 1,
          start: prev_end.round(2),
          end: next_start.round(2),
          duration: gap.round(2)
        }
      end
    end

    pauses
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

  #: (Array[Hash[Symbol, untyped]], Integer) -> Float
  def compute_struggle_score(disfluencies, word_count)
    return 0.0 if word_count.zero? || disfluencies.empty?

    weighted_sum = disfluencies.sum do |d|
      WEIGHTS.fetch(d[:category], 1)
    end

    score = (weighted_sum.to_f / word_count) * 100
    [score.round(1), 100.0].min
  end

  #: (Array[Hash[Symbol, untyped]], Integer, Array[Hash[Symbol, untyped]]) -> Hash[Symbol, untyped]
  def build_summary(all_disfluencies, total_words, pauses)
    total = all_disfluencies.length + pauses.length
    rate = total_words.positive? ? (total.to_f / total_words) * 100 : 0.0

    by_category = build_by_category(all_disfluencies)
    if pauses.any?
      pause_examples = pauses.first(5).map { |p| "#{p[:duration]}s" }
      by_category['pauses'] = { count: pauses.length, examples: pause_examples }
    end
    most_common_fillers = build_most_common_fillers(all_disfluencies)

    {
      total_disfluencies: total,
      disfluency_rate: rate.round(1),
      by_category: by_category,
      most_common_fillers: most_common_fillers
    }
  end

  #: (String) -> Integer
  def count_words(sentence)
    sentence.split(/\s+/).reject(&:empty?).length
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

  #: (Array[Hash[Symbol, untyped]]) -> Hash[String, Hash[Symbol, untyped]]
  def build_by_category(disfluencies)
    result = {}
    grouped = disfluencies.group_by { |d| d[:category] }

    grouped.each do |category, items|
      examples = items.map { |d| d[:text].downcase }.uniq.first(5)
      result[category] = {
        count: items.length,
        examples: examples
      }
    end

    result
  end

  #: (Array[Hash[Symbol, untyped]]) -> Hash[String, Integer]
  def build_most_common_fillers(disfluencies)
    fillers = disfluencies.select { |d| d[:category] == 'filler_words' }
    return {} if fillers.empty?

    counts = Hash.new(0)
    fillers.each { |f| counts[f[:text].downcase] += 1 }

    counts.sort_by { |_k, v| -v }.first(10).to_h
  end
end
