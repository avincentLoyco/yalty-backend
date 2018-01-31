module Policy
  module TimeOff
    class CreateByAmount
      attr_reader :time_off_policy_amount, :account

      def self.call(time_off_policy_amount, account_id)
        new(time_off_policy_amount, account_id).call
      end

      def initialize(time_off_policy_amount, account_id)
        @time_off_policy_amount = time_off_policy_amount
        @account                = Account.find(account_id)
      end

      def call
        standard_day_duration = account.presence_policies.full_time.standard_day_duration
        days_off = time_off_policy_amount / standard_day_duration

        TimeOffPolicy.create!(
          start_day: 1,
          start_month: 1,
          amount: time_off_policy_amount,
          policy_type: 'balancer',
          time_off_category_id: account.time_off_categories.vacation.first.id,
          name: "Time Off Policy #{days_off}",
          active: true
        )
      end
    end
  end
end
