require "active_support/concern"

module StripeHelpers
  extend ActiveSupport::Concern

  def stripe_enabled?
    !Rails.env.test?
  end
end
