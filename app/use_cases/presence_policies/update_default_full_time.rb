# frozen_string_literal: true

module PresencePolicies
  class UpdateDefaultFullTime
    def call(presence_policy:)
      account = presence_policy.account
      account.default_full_time_presence_policy_id = presence_policy.id
      account.standard_day_duration = presence_policy.standard_day_duration
      account.save!
    end
  end
end
