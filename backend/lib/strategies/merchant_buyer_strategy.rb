# frozen_string_literal: true

module Strategies
  class MerchantBuyerStrategy < TranscriptionStrategy
    def transcribe(file, filename, translate: false, **_options)
      response = @client.transcribe(file)
      text = response['text']

      result = {
        mode: 'transcribe',
        full_text: text,
        translation: nil
      }

      if translate
        result[:translation] = @client.translate_to_english(text)
      end

      result
    end
  end
end
