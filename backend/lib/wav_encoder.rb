# frozen_string_literal: true

# Wraps raw PCM16 audio bytes in a WAV file header
class WavEncoder
  def self.encode(pcm16_bytes, sample_rate: 24_000, channels: 1, bits_per_sample: 16)
    data_size = pcm16_bytes.bytesize
    byte_rate = sample_rate * channels * bits_per_sample / 8
    block_align = channels * bits_per_sample / 8

    header = [
      'RIFF',
      data_size + 36,
      'WAVE',
      'fmt ',
      16,
      1,
      channels,
      sample_rate,
      byte_rate,
      block_align,
      bits_per_sample,
      'data',
      data_size
    ].pack('a4Va4a4VvvVVvva4V')

    header + pcm16_bytes
  end
end
