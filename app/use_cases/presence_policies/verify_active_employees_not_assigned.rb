module PresencePolicies
  class VerifyActiveEmployeesNotAssigned
    include API::V1::Exceptions

    def call(presence_policy:)
      @presence_policy = presence_policy
      return unless presence_policy.employees.active_at_date.any?

      raise LockedError.new(
        type: "presence_policy",
        field: :employees,
        messages: [error_message],
        codes: [error_code],
      )
    end

    private

    attr_reader :presence_policy

    # NOTE message and code was taken from ExceptionHandler class, where LockedError is also
    # generated - it should be refactored and generated in one place (TODO) but it's too much
    # for the scope of YA-2066, that's why this class is used only for presence_policy related
    # fragments of code.
    def error_message
      "Resource is locked because presence_policy has assigned employees to it"
    end

    def error_code
      "presence_policy_employees_present"
    end
  end
end
