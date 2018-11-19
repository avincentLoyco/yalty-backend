# frozen_string_literal: true

module PresencePolicies
  class Update
    include AppDependencies[
      update_default_full_time: "use_cases.presence_policies.update_default_full_time",
    ]

    def call(presence_policy:, params:, default_full_time:)
      @presence_policy = presence_policy
      ActiveRecord::Base.transaction do
        presence_policy.update!(params)
        update_default_full_time_presence_policy if default_full_time
      end
      presence_policy.reload
    end

    private

    attr_reader :presence_policy

    def update_default_full_time_presence_policy
      update_default_full_time.call(
        presence_policy: presence_policy
      )
    end
  end
end
