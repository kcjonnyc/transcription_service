# frozen_string_literal: true

require 'logger'
require 'openai'

# OpenAI client using ruby-openai gem
class OpenAIClient
  class ApiError < StandardError; end

  LOG_LEVEL = ENV.fetch('LOG_LEVEL', 'INFO')

  DEFAULT_BASE_URL = 'https://api.openai.com/v1'

  TRANSCRIPTION_MODEL = 'gpt-4o-transcribe'
  DISFLUENCY_TRANSCRIPTION_MODEL = 'whisper-1'
  CHAT_MODEL = 'gpt-4o'

  DISFLUENCY_PROMPT = 'Um, uh, hmm, like, you know, I mean, so, basically, actually, literally, right, well, anyway. ' \
    'I- I was, uh, th- thinking about, um, like, you know what I mean? I went to the, the, the store. ' \
    'Sooo, wellll, I, um, beca- because, like, I just, you know, I- I- I couldn\'t, um, reme- remember.'

  def initialize(logger: nil)
    base_url = ENV.fetch('OPENAI_BASE_URL', DEFAULT_BASE_URL)
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      uri_base: base_url
    )
    @logger = logger || Logger.new($stdout, level: LOG_LEVEL)
  end

  def transcribe(file)
    @logger.info { "transcribe: model=#{TRANSCRIPTION_MODEL}" }
    file.rewind
    response = @client.audio.transcribe(
      parameters: {
        file: file,
        model: TRANSCRIPTION_MODEL,
        response_format: 'json'
      }
    )
    @logger.debug { "transcribe: response=#{response.inspect}" }
    handle_response(response)
  end

  def transcribe_with_disfluencies(file)
    @logger.info { "transcribe_with_disfluencies: model=#{DISFLUENCY_TRANSCRIPTION_MODEL}" }
    file.rewind
    response = @client.audio.transcribe(
      parameters: {
        file: file,
        model: DISFLUENCY_TRANSCRIPTION_MODEL,
        response_format: 'verbose_json',
        prompt: DISFLUENCY_PROMPT,
        timestamp_granularities: ['word']
      }
    )
    @logger.debug { "transcribe_with_disfluencies: response=#{response.inspect}" }
    handle_response(response)
  end

  def translate_to_english(text)
    @logger.info { "translate_to_english: model=#{CHAT_MODEL}" }
    @logger.debug { "translate_to_english: text=#{text}" }
    response = @client.chat(
      parameters: {
        model: CHAT_MODEL,
        temperature: 0,
        messages: [
          { role: 'system', content: 'Translate the following text to English. Return only the translated text, nothing else.' },
          { role: 'user', content: text }
        ]
      }
    )
    handle_response(response)
    result = response.dig('choices', 0, 'message', 'content')
    @logger.debug { "translate_to_english: result=#{result}" }
    result
  end

  DISFLUENCY_ANALYSIS_PROMPT = <<~PROMPT.freeze
    You are a speech disfluency analyzer. You receive a sentence where each word is prefixed
    with its index like [0]word [1]word. Identify and return all disfluencies in the following format.

    Return JSON: {"disfluencies": {"category": {"text": [ranges]}, ...}}

    - Group by category, then by the exact disfluency text as it appears (without index prefixes).
    - Each occurrence is a range object {"start": N, "end": M} where start and end are token indices.
    - Single-word disfluencies appearing at indices 0 and 5: "um": [{"start": 0, "end": 0}, {"start": 5, "end": 5}]
    - Multi-word disfluencies spanning indices 1-2: "I I": [{"start": 1, "end": 2}]

    Categories (use these exact strings):
    - "filler_words": um, uh, hmm, like (filler), you know, I mean, basically, actually, literally
    - "consecutive_word_repetitions": same word repeated consecutively ("I I", "the the").
      Non-consecutive repetitions are not disfluencies.
    - "sound_repetitions": stuttered beginnings before the completed word. Includes single
      stutters ("b- but", "wh- what") and repeated stutters ("a- a- a- another").
    - "prolongations": repeated characters ("sooo", "wellll")
    - "revisions": sentence is corrected by the speaker ("I was going, I went")
    - "partial_words": incomplete words ending with a hyphen where the speaker does NOT
      complete the word ("gon-", "thi-"). If the completed word follows, classify as
      sound_repetitions instead.

    If none found, return {"disfluencies": {}}.

    Example input: [0]Um, [1]I [2]I [3]was [4]thinking.
    Example output: {"disfluencies": {
      "filler_words": { "Um,": [{"start": 0, "end": 0}] },
      "consecutive_word_repetitions": { "I I": [{"start": 1, "end": 2}] },
    }}

    Example input: [0]This [1]is [2]a- [3]a- [4]a- [5]another [6]test.
    Example output: {"disfluencies": {
      "sound_repetitions": { "a- a- a- another": [{"start": 2, "end": 5}] }
    }}
  PROMPT

  def chat_analyze_disfluencies(indexed_words)
    indexed_sentence = indexed_words.map { |w| "[#{w[:index]}]#{w[:text]}" }.join(' ')
    @logger.info { "chat_analyze_disfluencies: model=#{CHAT_MODEL}" }
    @logger.debug { "chat_analyze_disfluencies: indexed_sentence=#{indexed_sentence}" }
    response = @client.chat(
      parameters: {
        model: CHAT_MODEL,
        temperature: 0,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: DISFLUENCY_ANALYSIS_PROMPT },
          { role: 'user', content: indexed_sentence }
        ]
      }
    )
    handle_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    result = JSON.parse(content)['disfluencies'] || {}
    @logger.debug { "chat_analyze_disfluencies: result=#{result.inspect}" }
    result
  rescue JSON::ParserError => e
    @logger.error { "chat_analyze_disfluencies: JSON parse failed: #{e.message}" }
    {}
  end

  private

  def handle_response(response)
    if response.is_a?(Hash) && response['error']
      raise ApiError, response['error']['message'] || response['error'].to_s
    end

    response
  end
end
