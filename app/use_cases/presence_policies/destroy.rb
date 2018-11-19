# frozen_string_literal: true

module PresencePolicies
  class Destroy
    include AppDependencies[
      verify_employees_not_assigned:
        "use_cases.presence_policies.verify_employees_not_assigned",
      verify_not_default_full_time:
        "use_cases.presence_policies.verify_not_default_full_time",
    ]

    def call(presence_policy:)
      verify_employees_not_assigned.call(resource: presence_policy)
      verify_not_default_full_time.call(presence_policy: presence_policy)
      presence_policy.destroy!
    end
  end
end
