module Policy
  module TimeOff
    class FindOrCreateByAmount
      LOCK_WAIT = 5

      pattr_initialize :time_off_policy_amount, :account_id

      def self.call(time_off_policy_amount, account_id)
        new(time_off_policy_amount, account_id).call
      end

      def call
        TimeOffPolicy.with_advisory_lock(lockname, timeout_seconds: LOCK_WAIT, transaction: true) do
          find_time_off_policy || create_time_off_policy
        end
      end

      private

      def find_time_off_policy
        Policy::TimeOff::FindByAmount.call(time_off_policy_amount, account_id)
      end

      def create_time_off_policy
        Policy::TimeOff::CreateByAmount.call(time_off_policy_amount, account_id)
      end

      def lockname
        ['time_off_policy', time_off_policy_amount].join
      end
    end
  end
end
