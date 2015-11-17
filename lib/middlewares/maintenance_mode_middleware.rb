class MaintenanceModeMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    if ENV['YALTY_MAINTENANCE_MODE'] == 'true'
      [503, { 'Content-Type' => 'application/json' }, ['{"error": "Maintenance mode"}']]
    else
      @app.call(env)
    end
  end
end
