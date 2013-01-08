require './config'
require 'goliath/rack/templates'
require 'em-synchrony/em-http'
require './lib/parsers/devcenter_message_parser'

class HerokuLogDrain < Goliath::API

  include Goliath::Rack::Templates

  EVENT_MANAGER_HEADERS = {
    'content-type' => 'application/json',
    'authorization' => ENV.values_at("EVENT_MANAGER_API_USER", "EVENT_MANAGER_API_PASSWORD")
  }

  # If we've explicitly set auth, check for it. Otherwise, buyer-beware!
  if(['HTTP_AUTH_USER', 'HTTP_AUTH_PASSWORD'].any? { |v| !ENV[v].nil? && ENV[v] != '' })
    use Rack::Auth::Basic, "Event Drain" do |username, password|
      authorized?(username, password)
    end
  end

  def response(env)
    case env['PATH_INFO']
    when '/drain' then
      proxy_log(env[Goliath::Request::RACK_INPUT].read) if(env[Goliath::Request::REQUEST_METHOD] == 'POST')
      [200, {}, "drained"]
    # when '/' then
    #   [200, {}, haml(:index, :locals => {
    #     :protected => self.class.protected?, :username => ENV['HTTP_AUTH_USER'], :password => ENV['HTTP_AUTH_PASSWORD'],
    #     :event_count => DB[:events].count, :env => env
    #   })]
    else
      raise Goliath::Validation::NotFoundError
    end    
  end

  private

  def proxy_log(log_str)
    HerokuLogParser.parse(log_str).each do |event|
      body = JSON.dump(DevcenterMessageParser.parse(event[:message]))
      multi.add SecureRandom.uuid, EM::HttpRequest.new(ENV['EVENT_MANAGER_API_URL'], :connect_timeout => 3, :inactivity_timeout => 5).post(body: body, head: EVENT_MANAGER_HEADERS)
    end
  end

  def handle_response(http)
    if(http.response_header.status != 200)
      message = JSON.parse(http.response)['error_message']
      puts "at=send-log status=error response=#{http.response_header.status} error=\"#{message}\" measure=true"
    end
  end

  def handle_error(http)
    puts "at=send-log status=error response=#{http.response_header.status} error=\"#{http.error}\" message=\"#{message}\" measure=true"
  end

  def multi
    if(!@multirequest)
      @multirequest = EventMachine::MultiRequest.new
      @multirequest.callback {
        @multirequest.responses[:callbacks].each { |http| handle_response(http) } if @multirequest.responses[:callbacks]
        @multirequest.responses[:errbacks].each { |http| handle_error(http) } if @multirequest.responses[:errbacks]
      }
    end
    @multirequest
  end

  def self.protected?
    ['HTTP_AUTH_USER', 'HTTP_AUTH_PASSWORD'].any? { |v| !ENV[v].nil? && ENV[v] != '' }
  end

  def self.authorized?(u, p)
    [u, p] == [ENV['HTTP_AUTH_USER'], ENV['HTTP_AUTH_PASSWORD']]
  end
end