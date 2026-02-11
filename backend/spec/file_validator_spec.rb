# frozen_string_literal: true

require_relative '../lib/file_validator'

RSpec.describe FileValidator do
  let(:max_size) { 25 * 1024 * 1024 } # 25MB

  def make_file(size:)
    file = instance_double(StringIO)
    allow(file).to receive(:size).and_return(size)
    file
  end

  describe '.validate' do
    context 'when file is nil' do
      it 'returns invalid with an error message' do
        result = FileValidator.validate(nil, 'audio.mp3')
        expect(result[:valid]).to eq(false)
        expect(result[:error]).to be_a(String)
        expect(result[:error]).not_to be_empty
      end
    end

    context 'with allowed formats' do
      %w[mp3 mp4 wav webm flac ogg m4a mpeg mpga].each do |ext|
        it "accepts .#{ext} files" do
          file = make_file(size: 1024)
          result = FileValidator.validate(file, "audio.#{ext}")
          expect(result).to eq({ valid: true })
        end
      end
    end

    context 'with case-insensitive extension checking' do
      it 'accepts .MP3 (uppercase)' do
        file = make_file(size: 1024)
        result = FileValidator.validate(file, 'audio.MP3')
        expect(result).to eq({ valid: true })
      end

      it 'accepts .WaV (mixed case)' do
        file = make_file(size: 1024)
        result = FileValidator.validate(file, 'audio.WaV')
        expect(result).to eq({ valid: true })
      end

      it 'accepts .FLAC (uppercase)' do
        file = make_file(size: 1024)
        result = FileValidator.validate(file, 'recording.FLAC')
        expect(result).to eq({ valid: true })
      end
    end

    context 'with unsupported formats' do
      %w[txt pdf exe doc zip avi mov wmv aac].each do |ext|
        it "rejects .#{ext} files" do
          file = make_file(size: 1024)
          result = FileValidator.validate(file, "document.#{ext}")
          expect(result[:valid]).to eq(false)
          expect(result[:error]).to be_a(String)
          expect(result[:error]).not_to be_empty
        end
      end
    end

    context 'when filename has no extension' do
      it 'rejects the file' do
        file = make_file(size: 1024)
        result = FileValidator.validate(file, 'audiofile')
        expect(result[:valid]).to eq(false)
        expect(result[:error]).to be_a(String)
        expect(result[:error]).not_to be_empty
      end
    end

    context 'with file size limits' do
      it 'rejects files exceeding 25MB' do
        file = make_file(size: max_size + 1)
        result = FileValidator.validate(file, 'audio.mp3')
        expect(result[:valid]).to eq(false)
        expect(result[:error]).to be_a(String)
        expect(result[:error]).not_to be_empty
      end

      it 'accepts files exactly at 25MB' do
        file = make_file(size: max_size)
        result = FileValidator.validate(file, 'audio.mp3')
        expect(result).to eq({ valid: true })
      end

      it 'accepts files under 25MB' do
        file = make_file(size: max_size - 1)
        result = FileValidator.validate(file, 'audio.wav')
        expect(result).to eq({ valid: true })
      end
    end
  end
end
