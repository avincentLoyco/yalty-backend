class EmployeeFileTokens
  def initialize(attributes)
    @time_to_expire = attributes[:duration].eql?('longterm') ? 43200 : 30
    created_at = Time.zone.now
    @token_params = {
      token: SecureRandom.hex(8),
      file_id: attributes[:file_id] || EmployeeFile.create!.id,
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
    redis = Redis.new
    redis.hmset(
      @token_params[:token],
      'file_id', @token_params[:file_id],
      'created_at', @token_params[:created_at],
      'expires_at', @token_params[:expires_at],
      'counter', @token_params[:counter],
      'action_type', @token_params[:action_type]
    )
    redis.expire(@token_params[:token], @time_to_expire)
  end
end
