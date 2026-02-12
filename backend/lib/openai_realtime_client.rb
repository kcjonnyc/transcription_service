# frozen_string_literal: true

require 'websocket-client-simple'
require 'json'
require 'logger'

# WebSocket client for OpenAI's Realtime Transcription API.
# Connects to wss://api.openai.com/v1/realtime and forwards
# transcript events to a callback.
class OpenAIRealtimeClient
  def initialize(on_event:, language: nil, logger: nil)
    @on_event = on_event
    @language = language
    @logger = logger || Logger.new($stdout)
    @ws = nil
    @connected = false
    @mutex = Mutex.new
  end

  def connect
    api_key = ENV.fetch('OPENAI_API_KEY')
    base_url = ENV.fetch('OPENAI_BASE_URL', 'https://api.openai.com/v1/realtime') + '?intent=transcription'
    ws_url = ENV.fetch('OPENAI_REALTIME_URL') { build_ws_url(base_url) }
    ws_url = append_realtime_params(ws_url)

    @logger.info { "OpenAIRealtimeClient: connecting to #{ws_url}" }

    on_event = @on_event
    logger = @logger
    language = @language
    client = self

    ws = WebSocket::Client::Simple.connect(ws_url, headers: {
      'Authorization' => "Bearer #{api_key}",
      'OpenAI-Beta' => 'realtime=v1'
    })

    @ws = ws

    ws.on :open do
      logger.info { 'OpenAIRealtimeClient: connected, setting connected=true' }
      client.set_connected(true)
      logger.info { "OpenAIRealtimeClient: connected? = #{client.connected?}" }

      session_config = {
        type: 'transcription_session.update',
        session: {
          input_audio_format: 'pcm16',
          input_audio_transcription: {
            model: 'gpt-4o-transcribe'
          },
          turn_detection: {
            type: 'server_vad',
            threshold: 0.5,
            prefix_padding_ms: 300,
            silence_duration_ms: 500
          },
          input_audio_noise_reduction: {
            type: 'near_field'
          }
        }
      }

      if language && !language.empty?
        session_config[:session][:input_audio_transcription][:language] = language
      end

      config_json = JSON.generate(session_config)
      logger.info { "OpenAIRealtimeClient: sending session config: #{config_json}" }
      ws.send(config_json)
      on_event.call({ 'type' => 'connected' })
    end

    ws.on :message do |msg|
      logger.info { "OpenAIRealtimeClient: raw message received: type=#{msg.type.inspect} data_size=#{msg.data&.bytesize || 0} data_preview=#{msg.data&.slice(0, 300).inspect}" }

      if msg.type == :close
        logger.warn { 'OpenAIRealtimeClient: server sent close frame' }
        client.set_connected(false)
        on_event.call({ 'type' => 'error', 'error' => { 'message' => 'Realtime server closed the connection' } })
        next
      end

      next if msg.data.nil? || msg.data.empty? || msg.type == :binary

      begin
        data = JSON.parse(msg.data)
        logger.info { "OpenAIRealtimeClient: received event: #{data['type']}" }
        on_event.call(data)
      rescue JSON::ParserError => e
        logger.error { "OpenAIRealtimeClient: parse error: #{e.message} (data=#{msg.data[0..300].inspect})" }
      end
    end

    ws.on :error do |e|
      logger.error { "OpenAIRealtimeClient: error: #{e.inspect}" }
      on_event.call({ 'type' => 'error', 'error' => { 'message' => e.to_s } })
    end

    ws.on :close do |_e|
      logger.info { "OpenAIRealtimeClient: closed (was connected=#{client.connected?})" }
      client.set_connected(false)
    end
  end

  def send_audio(base64_audio)
    unless connected?
      @logger.warn { "OpenAIRealtimeClient: send_audio skipped, not connected" }
      return
    end

    @ws&.send(JSON.generate({
      type: 'input_audio_buffer.append',
      audio: base64_audio
    }))
  rescue StandardError => e
    @logger.error { "OpenAIRealtimeClient: send_audio error: #{e.message}" }
  end

  def commit_audio
    return unless connected?

    @ws&.send(JSON.generate({ type: 'input_audio_buffer.commit' }))
  rescue StandardError => e
    @logger.error { "OpenAIRealtimeClient: commit_audio error: #{e.message}" }
  end

  def connected?
    @mutex.synchronize { @connected }
  end

  def set_connected(value)
    @mutex.synchronize { @connected = value }
  end

  def close
    @ws&.close
  rescue StandardError => e
    @logger.error { "OpenAIRealtimeClient: close error: #{e.message}" }
  ensure
    @mutex.synchronize { @connected = false }
  end

  private

  def build_ws_url(base_url)
    uri = URI.parse(base_url)
    scheme = uri.scheme == 'https' ? 'wss' : 'ws'
    path = uri.path.sub(%r{/?\z}, '')
    "#{scheme}://#{uri.host}#{path}/realtime"
  end

  def append_realtime_params(url)
    uri = URI.parse(url)
    params = URI.decode_www_form(uri.query || '')
    params << ['intent', 'transcription'] unless params.any? { |k, _| k == 'intent' }
    params << ['model', 'gpt-4o-transcribe'] unless params.any? { |k, _| k == 'model' }
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
