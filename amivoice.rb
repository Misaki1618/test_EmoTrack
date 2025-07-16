#amivoice api（感情解析）
require 'net/http/post/multipart' 
require 'uri'
require 'json'
require 'logger'
require 'dotenv'


Dotenv.load

logger = Logger.new(nil)
logger.level = Logger::DEBUG

endpoint = 'https://acp-api-async.amivoice.com/v1/recognitions'
app_key = ENV['AMIVOICE_API_KEY']
filename = ARGV[0]

domain = {
  'grammarFileNames' => '-a-general',
  'loggingOptOut' => 'True',
  'contentId' => filename,
  'speakerDiarization' => 'True',
  'diarizationMinSpeaker' => '1',
  'diarizationMaxSpeaker' => '1',
  'sentimentAnalysis' => 'True'
}

domain_param = domain.map { |key, value| "#{key}=#{URI.encode_www_form_component(value)}" }.join(' ') + ' keepFillerToken=1'

params = {
  'd' => domain_param,
  'a' => UploadIO.new(File.open(filename), 'application/octet-stream', filename)
}


uri = URI.parse(endpoint)

logger.info(params)

request = Net::HTTP::Post::Multipart.new(uri.path, params)
request['Authorization'] = "Bearer #{app_key}"

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
  http.request(request)
end
logger.info("Response Body: #{response.body.strip}")
if response.code.to_i != 200
  logger.error("Failed to request - #{response.body.strip}")
  exit(1)
end

request_response = JSON.parse(response.body.strip)

unless request_response.key?('sessionid')
  logger.error("Failed to create job - #{request_response['message']} (#{request_response['code']})")
  exit(2)
end

logger.info(request_response)

loop do
  begin
    uri = URI.parse("#{endpoint}/#{request_response['sessionid']}")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{app_key}"

    result_response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
    
    logger.info("Result Body: #{result_response.body}")
    if result_response.code.to_i == 200
      result = JSON.parse(result_response.body)
      if result['status'] == 'completed' || result['status'] == 'error'
        logger.info("Results Body: #{result}")
        #logger = Logger.new(STDOUT)
        #logger.info(result)
        puts JSON.pretty_generate(result)
        logger.info("確認")
        exit(0)
      else
        logger.info(result)
        sleep 10
      end
    else
      logger.error("Failed. Response is #{result_response.body}")
      exit(3)
    end
  rescue => e
    logger.error("Exception occurred: #{e.message}")
    exit(3)
  end
end
