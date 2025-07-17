#groq apiを使用

require 'net/http'
require 'uri'
require 'json'
require 'net/http/post/multipart'

api_url = 'https://api.groq.com/openai/v1/audio/transcriptions'
api_key = ENV["GROQ_API_KEY"]

filename = ARGV[0]
file = File.open(filename, 'rb')

uri = URI.parse(api_url)

data = {
  'file' => UploadIO.new(file, 'audio/wav', filename),
  'model' => 'whisper-large-v3-turbo',
  'response_format' => 'json',
  'language' => 'ja'
}

request = Net::HTTP::Post::Multipart.new(uri.path, data)

request['Authorization'] = "Bearer #{api_key}"

response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
  http.request(request)
end

if response.is_a?(Net::HTTPSuccess)
  transcription = JSON.parse(response.body)
  puts transcription.to_json
else
  puts "Error: #{response.code} - #{response.body}"
end

file.close
