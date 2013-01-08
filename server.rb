require './config'
require './lib/handlers/devcenter_event_manager_handler'

class HerokuLogDrain < Goliath::API

  use Rack::Auth::Basic, "Event Drain" do |u, p|
    [u, p] == [ENV['HTTP_AUTH_USER'], ENV['HTTP_AUTH_PASSWORD']]
  end

  def response(env)
    case env['PATH_INFO']
    when '/drain' then
      if(env[Goliath::Request::REQUEST_METHOD] == 'POST')
        data = env[Goliath::Request::RACK_INPUT].read
        DevcenterEventManagerHandler.logs_received(data)    # Money shot
      end
      [200, {}, "drained"]
    else
      raise Goliath::Validation::NotFoundError
    end    
  end
end