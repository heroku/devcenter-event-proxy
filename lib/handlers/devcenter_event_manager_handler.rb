require 'json'
require 'em-synchrony/em-http'
require './lib/parsers/devcenter_message_parser'

# Take log stream from Dev Center and send to Event Manager
class DevcenterEventManagerHandler

  EVENT_MANAGER_HEADERS = {
    'content-type' => 'application/json',
    'authorization' => ENV.values_at("EVENT_MANAGER_API_USER", "EVENT_MANAGER_API_PASSWORD")
  }

  class << self
    
    def logs_received(log_str)
      HerokuLogParser.parse(log_str).each do |event|
        sendable_values = DevcenterMessageParser.parse(event[:message])
        if(sendable_values && sendable_values.any?)
          body = JSON.dump(sendable_values)
          multi.add SecureRandom.uuid, EM::HttpRequest.new(ENV['EVENT_MANAGER_API_URL'], :connect_timeout => 3, :inactivity_timeout => 6).post(
            body: body, head: EVENT_MANAGER_HEADERS
          )
        end
      end
    end

    def multi
      if(!@multirequest)
        @multirequest = EventMachine::MultiRequest.new
        @multirequest.callback {
          @multirequest.responses[:callback].each { |id, h| handle_response(h) }
          @multirequest.responses[:errback].each { |id, h| handle_error(h) }
        }
      end
      @multirequest
    end

    def handle_response(http)
      if(http.response_header.status != 200)
        message = JSON.parse(http.response)['error_message']
        puts "at=error measure=event-drain.handler.send-log-error status=#{http.response_header.status} err=\"#{message}\""
      else
        puts "at=info measure=event-drain.handler.send-log"
      end
    end

    def handle_error(http)
      puts "at=error measure=event-drain.handler.send-log-errors status=#{http.response_header.status} err=\"#{http.error}\""
    end
  end
end