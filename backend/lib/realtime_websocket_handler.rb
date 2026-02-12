# frozen_string_literal: true

require 'websocket/driver'
require 'json'
require 'logger'
require 'monitor'

# Rack middleware that intercepts WebSocket upgrade requests to
# /api/stream-transcribe and bridges them to OpenAI's Realtime API.
# Uses websocket-driver for protocol handling with Puma's rack.hijack.
class RealtimeWebSocketHandler
  def initialize(app)
    @app = app
    @logger = Logger.new($stdout, level: ENV.fetch('LOG_LEVEL', 'INFO').upcase)
  end

  def call(env)
    if WebSocket::Driver.websocket?(env) && env['PATH_INFO'] == '/api/stream-transcribe'
      handle_websocket(env)
    else
      @app.call(env)
    end
  end

  private

  def handle_websocket(env)
    io = env['rack.hijack'].call

    conn = WebSocketConnection.new(env, io, @logger)
    conn.start

    [101, {}, []]
  end
end

# Manages a single hijacked WebSocket connection from the browser.
# Handles reading/writing WebSocket frames via websocket-driver
# and delegates streaming logic to StreamingSession.
class WebSocketConnection
  attr_reader :env

  def initialize(env, io, logger)
    @env = env
    @io = io
    @logger = logger
    @driver = WebSocket::Driver.rack(self)
    @session = nil
    @monitor = Monitor.new

    setup_driver_events
  end

  def start
    @driver.start

    Thread.new do
      Thread.current.name = 'ws-read-loop'
      read_loop
    end
  end

  # Called by websocket-driver to write frames to the TCP socket
  def write(data)
    @io.write(data)
    @io.flush
  rescue IOError, Errno::EPIPE, Errno::ECONNRESET => e
    @logger.debug { "WebSocketConnection: write error: #{e.message}" }
  end

  def send_message(data)
    json = data.is_a?(String) ? data : JSON.generate(data)
    @monitor.synchronize { @driver.text(json) }
  end

  # Required by websocket-driver
  def url
    scheme = @env['rack.url_scheme'] == 'https' ? 'wss' : 'ws'
    host = @env['HTTP_HOST'] || "#{@env['SERVER_NAME']}:#{@env['SERVER_PORT']}"
    path = @env['REQUEST_URI'] || @env['PATH_INFO']
    "#{scheme}://#{host}#{path}"
  end

  private

  def setup_driver_events
    @driver.on(:open) do |_event|
      @logger.info { 'WebSocket: browser connected' }
    end

    @driver.on(:message) do |event|
      handle_message(event.data)
    end

    @driver.on(:close) do |event|
      @logger.info { "WebSocket: browser disconnected (code=#{event.code})" }
      @session&.cleanup
      @session = nil
      @io.close rescue nil
    end

    @driver.on(:error) do |event|
      @logger.error { "WebSocket: driver error: #{event.message}" }
    end
  end

  def handle_message(raw_data)
    data = JSON.parse(raw_data)

    case data['type']
    when 'start'
      @session = StreamingSession.new(browser_ws: self, logger: @logger)
      @session.start(
        language: data['language'],
        translate: data['translate'] == true
      )
    when 'audio'
      @session&.append_audio(data['data'])
    when 'stop'
      Thread.new do
        Thread.current.name = 'ws-post-process'
        @session&.stop
      end
    else
      @logger.warn { "WebSocket: unknown message type: #{data['type']}" }
    end
  rescue JSON::ParserError => e
    @logger.error { "WebSocket: JSON parse error: #{e.message}" }
    send_message(type: 'error', message: 'Invalid JSON')
  rescue StandardError => e
    @logger.error { "WebSocket: error handling message: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}" }
    send_message(type: 'error', message: e.message)
  end

  def read_loop
    while (data = @io.readpartial(4096))
      @monitor.synchronize { @driver.parse(data) }
    end
  rescue EOFError, IOError, Errno::ECONNRESET
    @monitor.synchronize { @driver.close rescue nil }
  rescue StandardError => e
    @logger.error { "WebSocket: read_loop error: #{e.class}: #{e.message}" }
    @monitor.synchronize { @driver.close rescue nil }
  end
end
