class IntercomService
  def client
    return unless enabled?
    return IntercomServiceMock.new if Rails.env.development?

    Intercom::Client.new(token: ENV["INTERCOM_ACCESS_TOKEN"])
  end

  private

  def enabled?
    !Rails.env.test? && ENV["INTERCOM_ACCESS_TOKEN"].present?
  end
end

class IntercomServiceMock
  def method_missing(_name, *_args)
    self
  end
end
