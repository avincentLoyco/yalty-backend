# frozen_string_literal: true

module PresencePolicies
  class Create
    include AppDependencies[
      create_presence_days: "use_cases.presence_policies.create_presence_days",
      update_default_full_time: "use_cases.presence_policies.update_default_full_time",
    ]

    def call(account:, params:, days_params:, default_full_time:)
      account.presence_policies.new(params).tap do |presence_policy|
        @presence_policy = presence_policy

        ActiveRecord::Base.transaction do
          presence_policy.save!
          create_presence_days_for_presence_policy(days_params)
          update_default_full_time_presence_policy(default_full_time)
        end
      end
    end

    private

    attr_reader :presence_policy

    def create_presence_days_for_presence_policy(days_params)
      create_presence_days.call(presence_policy: presence_policy, params: days_params)
    end

    def update_default_full_time_presence_policy(default_full_time)
      return unless default_full_time
      update_default_full_time.call(presence_policy: presence_policy)
    end
  end
end
