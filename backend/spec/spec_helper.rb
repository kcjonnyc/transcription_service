# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'
ENV['OPENAI_API_KEY'] ||= 'test-api-key'
ENV['LOG_LEVEL'] ||= 'FATAL'

require_relative '../config/environment'
require_relative '../app'
require 'rack/test'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
end
