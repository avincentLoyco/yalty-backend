# frozen_string_literal: true

module TimeEntries
  class Create
    include AppDependencies[
      update_default_full_time: "use_cases.presence_policies.update_default_full_time",
      verify_employees_not_assigned: "use_cases.presence_policies.verify_employees_not_assigned",
    ]

    def call(params:, presence_day:)
      @presence_policy = presence_day.presence_policy
      verify_employees_not_assigned_to_presence_policy

      presence_day.time_entries.new(params).tap do |time_entry|
        ActiveRecord::Base.transaction do
          time_entry.save!
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
