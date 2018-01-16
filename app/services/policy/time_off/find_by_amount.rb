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
        vacation_tops = account.time_off_policies.all.select do |top|
          top.time_off_category.name == 'vacation' && top.active && !top.reset
        end
        vacation_tops.detect { |vacation_top| vacation_top.amount == time_off_policy_amount }
      end
    end
  end
end
