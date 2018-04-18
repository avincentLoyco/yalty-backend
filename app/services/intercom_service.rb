class IntercomService
  def client
    return unless enabled?

    Intercom::Client.new(token: ENV["INTERCOM_ACCESS_TOKEN"])
  end

  private

  def enabled?
    !Rails.env.test? && ENV["INTERCOM_ACCESS_TOKEN"].present?
  end
end
