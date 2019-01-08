module PresencePolicies
  class VerifyNotDefaultFullTime
    include API::V1::Exceptions

    def call(presence_policy:)
      @presence_policy = presence_policy
      return unless presence_policy.default_full_time?

      raise CustomError.new(
        type: "presence_policy",
        field: "default_full_time",
        messages: [error_message],
        codes: [error_code],
      )
    end

    private

    attr_reader :presence_policy

    def error_message
      "Cannot perform action because presence policy is marked as default full time"
    end

    def error_code
      "action_not_allowed_for_default_full_time_presence_policy"
    end
  end
end
