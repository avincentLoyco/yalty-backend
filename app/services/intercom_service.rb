class IntercomService
  def client
    return unless enabled?

    Intercom::Client.new(
      app_id: ENV['INTERCOM_APP_ID'],
      api_key: ENV['INTERCOM_API_KEY']
    )
  end

  private

  def enabled?
    !Rails.env.test? && ENV['INTERCOM_APP_ID'].present? && ENV['INTERCOM_API_KEY'].present?
  end
end
