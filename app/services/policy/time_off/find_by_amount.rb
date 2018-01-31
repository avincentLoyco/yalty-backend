module Policy
  module TimeOff
    class FindByAmount
      attr_reader :time_off_policy_amount, :account

      def self.call(time_off_policy_amount, account_id)
        new(time_off_policy_amount, account_id).call
      end

      def initialize(time_off_policy_amount, account_id)
        @time_off_policy_amount = time_off_policy_amount
        @account                = Account.find(account_id)
      end

      def call
        account
          .time_off_policies
          .vacations
          .find_by(active: true, amount: time_off_policy_amount, reset: false)
      end
    end
  end
end
