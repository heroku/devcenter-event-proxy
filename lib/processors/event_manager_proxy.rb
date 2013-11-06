require 'json'
require 'em-synchrony/em-http'

class EventManagerProxy

  class << self

    def process(value_hashes)
      multi = build_multirequest
      value_hashes.each do |value_hash|
        if(value_hash && value_hash.any?)
          body = JSON.dump(value_hash)
          multi.add SecureRandom.uuid, EM::HttpRequest.new(connection_url, connection_opts).post(
              body: body, head: connection_headers
          )
        end
      end if value_hashes
    end

    #--- Request handling

    def build_multirequest
      multirequest = EventMachine::MultiRequest.new
      multirequest.callback {
        multirequest.responses[:callback].each { |id, h| handle_response(h) }
        multirequest.responses[:errback].each { |id, h| handle_error(h) }
      }
      multirequest
    end

    def handle_response(http)
      component = JSON.parse(http.req.body)['component']
      if(http.response_header.status != 200)
        message = JSON.parse(http.response)['error_message']
        puts "source=#{component} count#devcenter-event-proxy.events.failed=1 status=#{http.response_header.status} error=\"#{message}\""
      else
        puts "source=#{component} count#devcenter-event-proxy.events.delivered=1 status=#{http.response_header.status}"
      end
    end

    def handle_error(http)
      component = JSON.parse(http.req.body)['component']
      puts "source=#{component} count#devcenter-event-proxy.events.failed=1 status=#{http.response_header.status} error=\"#{message}\""
    end

    #--- Connection info

    def connection_url
      ENV['EVENT_MANAGER_API_URL']
    end

    def connection_headers
      {
        'content-type' => 'application/json',
        'authorization' => ENV.values_at("EVENT_MANAGER_API_USER", "EVENT_MANAGER_API_PASSWORD")
      }
    end

    def connection_opts
      { 
        :connect_timeout => ENV['EVENT_MANAGER_API_CONNECT_TIMEOUT_SECS'] || 9,
        :inactivity_timeout => ENV['EVENT_MANAGER_API_INACTIVITY_TIMEOUT_SECS'] || 19
      }
    end
  end
end