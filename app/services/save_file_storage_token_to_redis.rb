require 'mime/types'

class SaveFileStorageTokenToRedis
  InvalidToken = Class.new(StandardError)
  SHORTTERM_TOKEN = 30
  LONGTERM_TOKEN = 43_200

  def initialize(attributes, attribute_version)
    @redis = Redis.current
    @time_to_expire = attributes[:duration].eql?('longterm') ? LONGTERM_TOKEN : SHORTTERM_TOKEN
    @duration = attributes[:duration].eql?('shortterm') ? 'shortterm' : 'longterm'
    @version = attributes[:version].present? ? attributes[:version] : 'original'
    @file_sha = file_sha(attribute_version)
    @file_type = file_type(attribute_version)
    @file_name = file_name(attribute_version)
    created_at = Time.zone.now
    @token_params = {
      token: generate_token,
      file_id: attributes[:file_id] || GenericFile.create!.id,
      type: 'token',
      created_at: created_at.to_s,
      expires_at: (created_at + @time_to_expire.seconds).to_s,
      counter: 1,
      action_type: attributes[:file_id].present? ? 'download' : 'upload'
    }
  end

  def call
    save_token_to_redis!
    @token_params
  end

  private

  def save_token_to_redis!
    @redis.hmset(
      @token_params[:token],
      'file_id', @token_params[:file_id],
      'created_at', @token_params[:created_at],
      'expires_at', @token_params[:expires_at],
      'counter', @token_params[:counter],
      'action_type', @token_params[:action_type],
      'file_sha', @file_sha,
      'file_type', @file_type,
      'file_name', @file_name,
      'duration', @duration,
      'version', @version
    )
    @redis.expire(@token_params[:token], @time_to_expire)
  end

  def generate_token
    token = nil

    3.times do |iterator|
      raise InvalidToken, 'Reached maximum number of regenerations.' if iterator == 2
      token = 'generic_file_' + SecureRandom.hex(8)
      break unless @redis.exists(token)
    end

    token
  end

  def file_sha(attribute_version)
    return unless attribute_version.present?
    attribute_version.data.send("#{@version}_sha")
  end

  def file_type(attribute_version)
    return unless attribute_version.present?
    attribute_version.data.file_type
  end

  def file_name(attribute_version)
    return unless attribute_version.present?
    event_name = attribute_version.attribute_definition.name
    ext = MIME::Types[attribute_version.data.file_type].first.extensions.first
    "#{event_name}.#{ext}"
  end
end
