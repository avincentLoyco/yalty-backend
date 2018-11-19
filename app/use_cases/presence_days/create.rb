# frozen_string_literal: true

module PresenceDays
  class Create
    include AppDependencies[
      update_default_full_time: "use_cases.presence_policies.update_default_full_time",
      verify_employees_not_assigned: "use_cases.presence_policies.verify_employees_not_assigned",
    ]

    def call(params:, presence_policy:)
      @presence_policy = presence_policy
      verify_employees_not_assigned_to_presence_policy

      presence_policy.presence_days.new(params).tap do |presence_day|
        ActiveRecord::Base.transaction do
          presence_day.save!
          update_standard_day_duration_for_default_full_time
        end
      end
    end

    private

    attr_reader :presence_policy

    def verify_employees_not_assigned_to_presence_policy
      verify_employees_not_assigned.call(resource: presence_policy)
    end

    def update_standard_day_duration_for_default_full_time
      return unless presence_policy.default_full_time?
      update_default_full_time.call(presence_policy: presence_policy)
    end
  end
end
