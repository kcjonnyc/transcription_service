# frozen_string_literal: true

module Strategies
  class MerchantBuyerStrategy < TranscriptionStrategy
    def transcribe(file, filename, translate: false, **_options)
      response = @client.transcribe_diarized(file)

      segments = parse_segments(response)
      speakers = segments.map { |s| s[:speaker] }.uniq

      result = {
        mode: 'merchant_buyer',
        full_text: response['text'],
        segments: segments,
        speakers: speakers,
        speaker_labels: speakers.each_with_object({}) { |s, h| h[s] = s },
        translation: nil
      }

      if translate
        translation_response = @client.translate_to_english(file)
        result[:translation] = translation_response['text']
      end

      result
    end

    private

    def parse_segments(response)
      raw_segments = response['segments'] || []
      speaker_map = {}
      current_label = 'A'

      raw_segments.map do |seg|
        speaker_id = seg['speaker'] || 'unknown_0'

        unless speaker_map.key?(speaker_id)
          speaker_map[speaker_id] = current_label
          current_label = current_label.next
        end

        {
          id: seg['id'],
          speaker: speaker_map[speaker_id],
          start: seg['start'],
          end: seg['end'],
          text: seg['text']
        }
      end
    end
  end
end
