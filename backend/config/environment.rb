# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)

require 'dotenv/load'
require 'json'
require 'sinatra/base'
require 'rack/cors'
require 'openai'

require_relative '../lib/file_validator'
require_relative '../lib/openai_client'
require_relative '../lib/disfluency_analysis'
require_relative '../lib/regex_disfluency_analyzer'
require_relative '../lib/llm_disfluency_analyzer'
require_relative '../lib/transcription_strategy'
require_relative '../lib/strategies/merchant_buyer_strategy'
require_relative '../lib/strategies/disfluency_strategy'
