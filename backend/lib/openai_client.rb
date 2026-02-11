# frozen_string_literal: true

require 'openai'

# OpenAI client using ruby-openai gem
class OpenAIClient
  class ApiError < StandardError; end

  DEFAULT_BASE_URL = 'https://api.openai.com/v1'

  DISFLUENCY_PROMPT = 'Um, uh, hmm, like, you know, I mean, so, basically, actually, literally, right, well, anyway. ' \
    'I- I was, uh, th- thinking about, um, like, you know what I mean? So I was going-- I went to the, the, the store. ' \
    'Sooo, wellll, I, um, beca- because, like, I just, you know, I- I- I couldn\'t, um, reme- remember.'

  def initialize
    base_url = ENV.fetch('OPENAI_BASE_URL', DEFAULT_BASE_URL)
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'],
      uri_base: base_url
    )
  end

  def transcribe_diarized(file, filename)
    file.rewind
    response = @client.audio.transcribe(
      parameters: {
        file: file,
        model: 'gpt-4o-transcribe',
        response_format: 'verbose_json',
        include: ['logprobs'],
        timestamp_granularities: ['word']
      }
    )
    handle_response(response)
  end

  def transcribe_with_disfluencies(file, filename)
    file.rewind
    response = @client.audio.transcribe(
      parameters: {
        file: file,
        model: 'whisper-1',
        response_format: 'verbose_json',
        prompt: DISFLUENCY_PROMPT,
        timestamp_granularities: ['word']
      }
    )
    handle_response(response)
  end

  def translate_to_english(file, filename)
    file.rewind
    response = @client.audio.translate(
      parameters: {
        file: file,
        model: 'whisper-1',
        response_format: 'verbose_json'
      }
    )
    handle_response(response)
  end

  DISFLUENCY_ANALYSIS_PROMPT = <<~PROMPT.freeze
    You are a speech disfluency analyzer. You receive a sentence where each word is prefixed
    with its index like [0]word [1]word. Identify all disfluencies.

    Return JSON: {"disfluencies": {"category": {"text": [indices], ...}, ...}}

    - Group by category, then by the disfluency text as it appears (without index prefixes).
    - Single-word disfluencies: flat array of integer indices — "um": [0, 5]
    - Multi-word disfluencies: array of index-arrays — "I I": [[1, 2]]

    Categories (use these exact strings):
    - "filler_words": um, uh, hmm, like (filler), you know, I mean, basically, actually, literally
    - "word_repetitions": same word repeated consecutively ("I I", "the the")
    - "sound_repetitions": stuttered beginnings ("b- but", "wh- what")
    - "prolongations": repeated characters ("sooo", "wellll")
    - "revisions": self-corrections with -- ("going-- I went")
    - "partial_words": incomplete words with hyphen ("gon-", "thi-")

    If none found, return {"disfluencies": {}}.

    Example input: [0]Um, [1]I [2]I [3]was [4]thinking.
    Example output: {"disfluencies": {
      "filler_words": { "Um,": [0] },
      "word_repetitions": { "I I": [[1, 2]] }
    }}
  PROMPT

  def chat_analyze_disfluencies(indexed_sentence)
    response = @client.chat(
      parameters: {
        model: 'gpt-4o-mini',
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
    JSON.parse(content)['disfluencies'] || {}
  rescue JSON::ParserError
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
