# frozen_string_literal: true

require 'sinatra'
require 'net/http'
require 'json'
require 'slim'

require 'dotenv'
Dotenv.load

PEXELS_API_KEY = ENV.fetch('PEXELS_API_KEY')

def search_pexels(query)
  return nil unless query.length > 1

  begin
    uri = URI('https://api.pexels.com/v1/search')
    uri.query = ["query=#{query.gsub(' ', '+')}", "per_page=15", "page=1"].compact.join('&')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Get.new(uri.request_uri, { 'Content-Type' =>'application/json', 'Authorization' => PEXELS_API_KEY })
    #req.body = {"pizza_type" => "Margherita", "pizza_no" => "2"}.to_json
    res = http.request(req)

    JSON.parse(res.body)
  rescue => e
    puts "failed #{e}"
    nil
  end
end

get '/:query' do
  @query = params.fetch(:query, '')
  @result = search_pexels(@query)
  @photos = @result['photos'].collect do |photo|
    photo['src']['small']
  end

  slim :index
end
