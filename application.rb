# frozen_string_literal: true

require 'sinatra'
require 'net/http'
require 'json'
require 'slim'
require 'yaml'

require 'dotenv'
Dotenv.load

PEXELS_API_KEY = ENV.fetch('PEXELS_API_KEY')
COMMON_NOUNS = YAML.load_file('nouns.yml')

def search_pexels(query)
  return nil unless query.length > 1

  normalized_query = query.gsub(' ', '+');
  cache_key = File.dirname(__FILE__) + "/cache/pexels/#{normalized_query}.json"
  result = File.read(cache_key) if File.exist?(cache_key)

  puts "Cache hit #{normalized_query}" if result
  puts "Cache miss #{normalized_query}" unless result

  result ||=
    begin
      uri = URI('https://api.pexels.com/v1/search')
      uri.query = ["query=#{normalized_query}", "per_page=30", "page=1"].compact.join('&')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Get.new(uri.request_uri, { 'Content-Type' =>'application/json', 'Authorization' => PEXELS_API_KEY })
      res = http.request(req)

      res.body.tap do |body|
        File.open(cache_key, 'w') do |file|
          file.write(body)
          file.close
        end
      end

    rescue => e
      puts "failed #{e}"
      nil
    end

  JSON.parse(result) if result
end

# Imports the Google Cloud client library
require "google/cloud/translate"

def translate_text(text, target: 'el', from: 'en')
  # Your Google Cloud Platform project ID
  project_id = "learn-ig-228920"
  credentials = "/home/evan/Workspace/learn.ig/learn-ig.json"

  # Instantiates a client
  translate_client = Google::Cloud::Translate.new project: project_id, credentials: credentials

  cache_key = File.dirname(__FILE__) + "/cache/translate/#{text.gsub(' ', '+')}+#{target}+#{from}.txt"
  result = File.read(cache_key) if File.exist?(cache_key)

  puts "Cache hit #{text}" if result
  puts "Cache miss #{text}" unless result

  translate_client.translate(text, to: target, from: from).tap do |result|
    File.open(cache_key, 'w') do |file|
      file.write(result)
      file.close
    end
  end
end

get '/translate/:query' do
  @query = params.fetch(:query, '')
  translate_text(@query).to_s
end

get '/:query' do
  @query = params.fetch(:query, '')
  @query = "the " + @query if params.fetch(:pronoun, 1).to_i == 1
  @target = params.fetch(:target, 'el')
  @result = search_pexels(@query.gsub('the ', ''))
  @translation = translate_text(@query, target: @target)

  @photos = @result['photos'].collect do |photo|
    OpenStruct.new(photo['src'].transform_keys { |k| k.to_sym })
  end

  slim :index
end
