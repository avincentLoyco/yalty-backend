module Policy
  module TimeOff
    class FindOrCreateByAmount
      attr_reader :time_off_policy_amount, :account_id

      def self.call(time_off_policy_amount, account_id)
        new(time_off_policy_amount, account_id).call
      end

      def initialize(time_off_policy_amount, account_id)
        @time_off_policy_amount = time_off_policy_amount
        @account_id             = account_id
      end

      def call
        time_off_policy = Policy::TimeOff::FindByAmount.call(time_off_policy_amount, account_id)

        return time_off_policy if time_off_policy.present?
        Policy::TimeOff::CreateByAmount.call(time_off_policy_amount, account_id)
      end
    end
  end
end
