# frozen_string_literal: true

require 'sinatra'
require 'net/http'
require 'json'
require 'slim'
require 'yaml'
require 'mime/types'
require 'dotenv'
require "google/cloud/translate"

Dotenv.load

PEXELS_API_KEY = ENV.fetch('PEXELS_API_KEY')
COMMON_NOUNS = YAML.load_file('nouns.yml')

# Your Google Cloud Platform project ID
GOOGLE_PROJECT_ID = "learn-ig-228920"
GOOGLE_CREDENTIALS = [File.dirname(__FILE__), "learn-ig.json"].join('/')

BASE64_REGEXP = /\Adata:([-\w]+\/[-\w\+\.]+)?;base64,(.*)/m

def cache(key, &block)
  full_cache_key = [File.dirname(__FILE__), 'cache' , key].join('/')
  return File.read(full_cache_key) if File.exist?(full_cache_key)

  block.call.tap do |result|
    File.open(full_cache_key, 'w') do |file|
      file.write(result)
      file.close
    end
  end
end

# Search for stock images
def search_pexels(query)
  return nil unless query.length > 1

  normalized_query = query.gsub(' ', '+');
  cache_key = "pexels/#{normalized_query}.json"

  begin
    cache(cache_key) do
      uri = URI('https://api.pexels.com/v1/search')
      uri.query = ["query=#{normalized_query}", "per_page=30", "page=1"].compact.join('&')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      req = Net::HTTP::Get.new(uri.request_uri, { 'Content-Type' =>'application/json', 'Authorization' => PEXELS_API_KEY })
      res = http.request(req)

      JSON.parse(res.body)
    end
  rescue => e
    puts "Request failed #{e}"
    nil
  end
end

# Google translate text
def translate_text(text, target: 'el', from: 'en')
  cache_key = "translate/#{text.gsub(' ', '+')}+#{target}+#{from}.txt"
  translate_client = Google::Cloud::Translate.new project: GOOGLE_PROJECT_ID, credentials: GOOGLE_CREDENTIALS

  cache(cache_key) do
    translate_client.translate(text, to: target, from: from)
  end
end

def save_image(name, target, data)
  data_parts = data.match(BASE64_REGEXP) || []
  extension = MIME::Types[data_parts[1]].first.preferred_extension
  filename = "#{name}.#{extension}"

  File.open([File.dirname(__FILE__), 'images', target, filename].join('/'), 'wb') do |f|
    f.write(Base64.decode64(data_parts[2]))
  end
end

post '/:target/save_image' do
  @name = params[:ig_image_name]
  @data = params[:ig_image_data]
  @target = params[:target]

  save_image(@name, @target, @data)

  redirect "/#{@target}/generate/#{COMMON_NOUNS.sample}"
end

get '/:target/generate/:query' do
  @query = params.fetch(:query, '')
  @query = "the " + @query if params.fetch(:pronoun, 1).to_i == 1
  @target = params.fetch(:target)
  @translation = translate_text(@query, target: @target)

  result = search_pexels(@query.gsub('the ', ''))
  @photos = result['photos'].collect do |photo|
    OpenStruct.new(photo['src'].transform_keys { |k| k.to_sym })
  end

  slim :index
end
