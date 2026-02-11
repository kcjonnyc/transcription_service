# frozen_string_literal: true

class TranscriptionApp < Sinatra::Base
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: %i[get post options]
    end
  end

  STRATEGIES = {
    'merchant_buyer' => Strategies::MerchantBuyerStrategy,
    'disfluency' => Strategies::DisfluencyStrategy
  }.freeze

  before do
    content_type :json
  end

  get '/api/health' do
    { status: 'ok', timestamp: Time.now.iso8601 }.to_json
  end

  post '/api/transcribe' do
    unless params[:file] && params[:file][:tempfile]
      halt 400, { error: 'No audio file provided' }.to_json
    end

    mode = params[:mode]
    unless STRATEGIES.key?(mode)
      halt 400, { error: "Invalid mode: #{mode}. Must be 'merchant_buyer' or 'disfluency'" }.to_json
    end

    file = params[:file][:tempfile]
    filename = params[:file][:filename]
    translate = params[:translate] == 'true'

    validation = FileValidator.validate(file, filename)
    unless validation[:valid]
      halt 422, { error: validation[:error] }.to_json
    end

    client = OpenAIClient.new
    strategy = STRATEGIES[mode].new(client)

    begin
      result = strategy.transcribe(file, filename, translate: translate)
      result.to_json
    rescue OpenAIClient::ApiError => e
      halt 502, { error: "OpenAI API error: #{e.message}" }.to_json
    rescue StandardError => e
      halt 500, { error: "Transcription failed: #{e.message}" }.to_json
    end
  end

  error do
    { error: 'Internal server error' }.to_json
  end
end
