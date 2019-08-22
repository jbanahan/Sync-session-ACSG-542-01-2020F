module OpenChain; class HealthCheckMiddleware

  def initialize(app)
    @app = app
  end

  def call(env)
    if env['PATH_INFO'] == '/health_check'
      begin
        # We going to consider connecting to the database part of the application being healthy,
        # not just the ability to receive HTTP requests
        uuid = MasterSetup.limit(1).pluck(:uuid).first
        return [200, {"Content-Type" => "text/plain; charset=utf-8"}, [uuid.to_s]]
      rescue Exception => e
        return [503, {"Content-Type" => "text/plain; charset=utf-8"}, [format_error(e)]]
      end
    else
      @app.call(env)
    end
  end

  def format_error error
    error_message = error.message.to_s
    Array.wrap(error.backtrace).each {|b| error_message << "\n        #{b.to_s}"}
    error_message
  end

end; end;