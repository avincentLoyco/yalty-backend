class RemoveContentTypeHeader
  def initialize(app)
    @app = app
  end

  def call(env)
    response = @app.call(env)
    status, headers, body = *response
    if status.eql?(205)
      ["Content-Type", "Content-Length"].each { |header| headers.delete(header) }
      body = []
    end
    [status, headers, body]
  end
end
