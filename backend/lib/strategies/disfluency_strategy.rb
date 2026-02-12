# frozen_string_literal: true

module Strategies
  class DisfluencyStrategy < TranscriptionStrategy
    def transcribe(file, filename, translate: false, **_options)
      response = @client.transcribe_with_disfluencies(file)
      text = response['text']
      words = response['words'] || []

      {
        mode: 'disfluency',
        full_text: text,
        words: words,
        regex_analysis: RegexDisfluencyAnalyzer.new.analyze(text, words: words),
        llm_analysis: LlmDisfluencyAnalyzer.new(client: @client).analyze(text, words: words)
      }
    end
  end
end
