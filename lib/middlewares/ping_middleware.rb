class PingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"] == "/ping"
      [200, { "Content-Type" => "text/plain" }, ["PONG"]]
    else
      @app.call(env)
    end
  end
end
