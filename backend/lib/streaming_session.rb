# frozen_string_literal: true

require 'base64'
require 'json'
require 'logger'
require 'tempfile'

# Manages the lifecycle of a single streaming transcription session.
# Bridges the browser WebSocket <-> OpenAI Realtime WebSocket,
# accumulates raw PCM16 audio for post-session batch diarization.
class StreamingSession
  def initialize(browser_ws:, logger: nil)
    @browser_ws = browser_ws
    @logger = logger || Logger.new($stdout)
    @openai_client = nil
    @audio_buffer = String.new(encoding: 'BINARY')
    @audio_mutex = Mutex.new
    @language = nil
    @translate = false
  end

  def start(language: nil, translate: false)
    @language = language
    @translate = translate
    @audio_mutex.synchronize { @audio_buffer.clear }

    @openai_client = OpenAIRealtimeClient.new(
      on_event: method(:handle_openai_event),
      language: language,
      logger: @logger
    )

    @openai_client.connect
  end

  def append_audio(base64_audio)
    raw_bytes = Base64.decode64(base64_audio)
    @audio_mutex.synchronize { @audio_buffer << raw_bytes }

    buf_size = @audio_buffer.bytesize
    @logger.info { "StreamingSession: append_audio chunk=#{raw_bytes.bytesize}B total=#{buf_size}B connected=#{@openai_client&.connected?}" } if buf_size <= 50_000 || buf_size % 100_000 < 5000

    @openai_client&.send_audio(base64_audio)
  end

  def stop
    @logger.info { "StreamingSession: stopping, buffer size: #{@audio_buffer.bytesize} bytes" }

    @openai_client&.commit_audio
    sleep(0.5)
    @openai_client&.close

    run_post_processing
  end

  def cleanup
    @openai_client&.close
  end

  private

  def handle_openai_event(event)
    case event['type']
    when 'connected'
      send_to_browser(type: 'session_started')
    when 'conversation.item.input_audio_transcription.delta'
      send_to_browser(
        type: 'transcript_delta',
        text: event['delta'],
        item_id: event['item_id']
      )
    when 'conversation.item.input_audio_transcription.completed'
      send_to_browser(
        type: 'transcript_complete',
        text: event['transcript'],
        item_id: event['item_id']
      )
    when 'error'
      error_msg = event.dig('error', 'message') || 'Unknown OpenAI error'
      @logger.error { "StreamingSession: OpenAI error: #{error_msg}" }
      send_to_browser(type: 'error', message: error_msg)
    when 'transcription_session.created', 'transcription_session.updated'
      @logger.info { "StreamingSession: #{event['type']}" }
    when 'input_audio_buffer.speech_started'
      @logger.debug { 'StreamingSession: speech started' }
    when 'input_audio_buffer.speech_stopped'
      @logger.debug { 'StreamingSession: speech stopped' }
    when 'input_audio_buffer.committed'
      @logger.debug { 'StreamingSession: buffer committed' }
    else
      @logger.info { "StreamingSession: unhandled event type: #{event['type']} keys=#{event.keys}" }
    end
  rescue StandardError => e
    @logger.error { "StreamingSession: error handling event: #{e.message}" }
  end

  def run_post_processing
    buffer_copy = @audio_mutex.synchronize { @audio_buffer.dup }

    if buffer_copy.empty?
      send_to_browser(type: 'session_stopped', diarized_result: nil, translation: nil)
      return
    end

    @logger.info { "StreamingSession: post-processing #{buffer_copy.bytesize} bytes of audio" }

    wav_data = WavEncoder.encode(buffer_copy)

    tempfile = Tempfile.new(['streaming_audio', '.wav'])
    tempfile.binmode
    tempfile.write(wav_data)
    tempfile.rewind

    begin
      client = OpenAIClient.new(logger: @logger)

      response = client.transcribe_diarized(tempfile)
      segments = parse_segments(response)
      speakers = segments.map { |s| s[:speaker] }.uniq

      diarized_result = {
        mode: 'merchant_buyer',
        full_text: response['text'],
        segments: segments,
        speakers: speakers,
        speaker_labels: speakers.each_with_object({}) { |s, h| h[s] = s },
        translation: nil
      }

      if @translate
        tempfile.rewind
        translation_response = client.translate_to_english(tempfile)
        diarized_result[:translation] = translation_response['text']
      end

      send_to_browser(type: 'session_stopped', diarized_result: diarized_result)
    rescue Faraday::ClientError => e
      body = e.response[:body] rescue 'unknown'
      @logger.error { "StreamingSession: post-processing API error (#{e.response[:status]}): #{body}" }
      send_to_browser(type: 'error', message: "Post-processing failed: #{e.message}")
      send_to_browser(type: 'session_stopped', diarized_result: nil)
    rescue StandardError => e
      @logger.error { "StreamingSession: post-processing error: #{e.class}: #{e.message}" }
      send_to_browser(type: 'error', message: "Post-processing failed: #{e.message}")
      send_to_browser(type: 'session_stopped', diarized_result: nil)
    ensure
      tempfile.close
      tempfile.unlink
    end
  end

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

  def send_to_browser(data)
    @browser_ws.send_message(data)
  rescue StandardError => e
    @logger.error { "StreamingSession: send_to_browser error: #{e.message}" }
  end
end
