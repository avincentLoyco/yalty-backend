# frozen_string_literal: true

module PresencePolicies
  class Archive
    include AppDependencies[
      verify_active_employees_not_assigned:
        "use_cases.presence_policies.verify_active_employees_not_assigned",
      verify_not_default_full_time:
        "use_cases.presence_policies.verify_not_default_full_time",
    ]

    def call(presence_policy:)
      verify_active_employees_not_assigned.call(presence_policy: presence_policy)
      verify_not_default_full_time.call(presence_policy: presence_policy)
      presence_policy.archived = true
      presence_policy.save!
    end
  end
end
