require "mime/types"

class SaveFileStorageTokenToRedis
  InvalidToken = Class.new(StandardError)
  SHORTTERM_TOKEN = 30
  LONGTERM_TOKEN = 43_200

  def initialize(attributes)
    @redis = Redis.current
    @time_to_expire = attributes[:duration].eql?("longterm") ? LONGTERM_TOKEN : SHORTTERM_TOKEN
    @duration = attributes[:duration].eql?("shortterm") ? "shortterm" : "longterm"
    @version = attributes[:version].present? ? attributes[:version] : "original"
    @file_data = build_file_data(attributes[:file_id])
    @token_params = build_token_params(attributes[:file_id])
  end

  def call
    save_token_to_redis!
    @token_params
  end

  private

  def save_token_to_redis!
    @redis.hmset(
      @token_params[:token],
      "file_id", @token_params[:file_id],
      "created_at", @token_params[:created_at],
      "expires_at", @token_params[:expires_at],
      "counter", @token_params[:counter],
      "action_type", @token_params[:action_type],
      "file_sha", @file_data[:sha],
      "file_type", @file_data[:type],
      "file_name", @file_data[:name],
      "duration", @duration,
      "version", @version
    )
    @redis.expire(@token_params[:token], @time_to_expire)
  end

  def build_token_params(file_id)
    created_at = Time.zone.now
    {
      token: generate_token,
      file_id: file_id || GenericFile.create!.id,
      type: "token",
      created_at: created_at.to_s,
      expires_at: (created_at + @time_to_expire.seconds).to_s,
      counter: 1,
      action_type: file_id.present? ? "download" : "upload"
    }
  end

  def generate_token
    token = nil

    3.times do |iterator|
      raise InvalidToken, "Reached maximum number of regenerations." if iterator == 2
      token = "generic_file_" + SecureRandom.hex(8)
      break unless @redis.exists(token)
    end

    token
  end

  def build_file_data(file_id)
    return {} unless file_id.present?
    file = GenericFile.find_by(id: file_id)
    {
      sha:  file.sha_sums[:"#{@version}_sha"],
      type: file.file_content_type,
      name: file.user_friendly_name
    }
  end
end
