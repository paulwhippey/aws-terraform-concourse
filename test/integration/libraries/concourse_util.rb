require 'net/http'
require 'uri'

def wait(url, max=5)
  puts "connecting to #{url}"
  count = 0
  while count <= max
    begin
      response = get(url)
      raise "Bad response from Concourse UI: #{response.code}" if response.code.to_i != 200
      break
    rescue Exception => e
      count += 1
      if count == max
        raise 'There was an issue with contacting the Concourse UI, check if the Concourse Web service is running'
      end

      sleep 1
      next
    end
  end
  puts "success my friend!!!"
end

def post(url, data, token)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.ssl_version = 'TLSv1_2'
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(uri)
  request.set_form_data(data)
  request['Kong-Admin-Token'] = token
  response = http.request(request)
end

def get(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.ssl_version = 'TLSv1_2'
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new(uri)
  response = http.request(request)
  return response
end
