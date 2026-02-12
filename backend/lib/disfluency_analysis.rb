# frozen_string_literal: true

# Shared utilities for disfluency analyzers.
# Include this module to get access to sentence splitting, pause detection,
# and word counting.
module DisfluencyAnalysis
  PAUSE_THRESHOLD_SECONDS = 1

  WEIGHTS = {
    'filler_words' => 1,
    'consecutive_word_repetitions' => 1.5,
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

  #: (String) -> Integer
  def count_words(sentence)
    sentence.split(/\s+/).reject(&:empty?).length
  end

  #: (Array[Hash[Symbol, untyped]], Integer) -> Float
  def compute_struggle_score(disfluencies, word_count)
    return 0.0 if word_count.zero? || disfluencies.empty?

    weighted_sum = disfluencies.sum do |d|
      WEIGHTS.fetch(d[:category], 1) * occurrence_count(d)
    end

    score = (weighted_sum.to_f / word_count) * 100
    [score.round(1), 100.0].min
  end

  #: (Array[Hash[Symbol, untyped]], Integer, Array[Hash[Symbol, untyped]]) -> Hash[Symbol, untyped]
  def build_summary(all_disfluencies, total_words, pauses)
    total = all_disfluencies.sum { |d| occurrence_count(d) } + pauses.length
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

  #: (Array[Hash[Symbol, untyped]]) -> Hash[String, Hash[Symbol, untyped]]
  def build_by_category(all_disfluencies)
    result = {}
    grouped = all_disfluencies.group_by { |d| d[:category] }

    grouped.each do |category, items|
      examples = items.map { |d| d[:text].downcase }.uniq.first(5)
      result[category] = {
        count: items.sum { |d| occurrence_count(d) },
        examples: examples
      }
    end

    result
  end

  #: (Array[Hash[Symbol, untyped]]) -> Hash[String, Integer]
  def build_most_common_fillers(all_disfluencies)
    fillers = all_disfluencies.select { |d| d[:category] == 'filler_words' }
    return {} if fillers.empty?

    counts = Hash.new(0)
    fillers.each { |f| counts[f[:text].downcase] += occurrence_count(f) }

    counts.sort_by { |_k, v| -v }.first(10).to_h
  end
end
