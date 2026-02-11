# frozen_string_literal: true

# Base strategy interface for transcription modes
class TranscriptionStrategy
  def initialize(client)
    @client = client
  end

  def transcribe(_file, _filename, translate: false, **_options)
    raise NotImplementedError, "#{self.class}#transcribe must be implemented"
  end
end
