# frozen_string_literal: true

# Validates uploaded audio files for format and size
class FileValidator
  ALLOWED_FORMATS = %w[mp3 mp4 wav webm flac ogg m4a mpeg mpga].freeze
  MAX_FILE_SIZE = 25 * 1024 * 1024 # 25MB

  def self.validate(file, filename)
    return { valid: false, error: 'No file provided' } if file.nil?

    extension = File.extname(filename).delete_prefix('.').downcase
    return { valid: false, error: "Unsupported file format: .#{extension}" } if extension.empty?
    return { valid: false, error: "Unsupported file format: .#{extension}" } unless ALLOWED_FORMATS.include?(extension)
    return { valid: false, error: "File size exceeds maximum of 25MB" } if file.size > MAX_FILE_SIZE

    { valid: true }
  end
end
