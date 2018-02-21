class MaintenanceModeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if Redis.current && Redis.current.get("maintenance_mode") == "true"
      [503, { "Content-Type" => "application/json" }, ['{"error": "Maintenance mode"}']]
    else
      @app.call(env)
    end
  end
end
