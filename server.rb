require './config'

class HerokuLogDrain < Goliath::API

  Goliath::Request.log_block = proc do |env, response, elapsed_time|
    # Silence Goliath request logging - Heroku router gives us mostly the same thing
    # method = env[Goliath::Request::REQUEST_METHOD]
    # path = env[Goliath::Request::REQUEST_PATH]
    # env[Goliath::Request::RACK_LOGGER].info("at=info measure=server.requests method=#{method} path=#{path} val=#{'%.2f' % elapsed_time} units=ms")  
  end

  use Rack::Auth::Basic, "Event Drain" do |u, p|
    [u, p] == [ENV['HTTP_AUTH_USER'], ENV['HTTP_AUTH_PASSWORD']]
  end

  def response(env)
    case env['PATH_INFO']
    when '/drain' then
      if(ENV['DRAIN'].to_i > 0 && env[Goliath::Request::REQUEST_METHOD] == 'POST')
        LOG_MANAGER.logs_received(env[Goliath::Request::RACK_INPUT].read)
      end
      [200, {}, "drained"]
    else
      raise Goliath::Validation::NotFoundError
    end    
  end
end