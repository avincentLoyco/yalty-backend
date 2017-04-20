require 'rack'
require 'digest/md5'

class ETagMiddleware
  ETAG_REGEX = %r{W/"([^"]+)"}i

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    unless skip_etag_update?(headers)
      digest = updated_digest(headers)
      headers[Rack::ETag::ETAG_STRING] = %(W/"#{digest}") if digest
    end

    [status, headers, body]
  end

  private

  def skip_etag_update?(headers)
    !headers.key?(Rack::ETag::ETAG_STRING) || headers[Rack::ETag::ETAG_STRING] !~ ETAG_REGEX ||
      Account.current.nil?
  end

  def updated_digest(headers)
    digest = Digest::SHA256.new

    digest << headers[Rack::ETag::ETAG_STRING][ETAG_REGEX, 1]
    digest << Account.current.id
    digest << Account.current.subdomain

    digest.hexdigest.byteslice(0, 32)
  end
end
