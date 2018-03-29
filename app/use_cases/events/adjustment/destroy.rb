module Events
  module Adjustment
    class Destroy < Default::Destroy
      include Balances

      config_accessor :balance_destroyer do
        DestroyEmployeeBalance
      end

      def call
        ActiveRecord::Base.transaction do
          destroy_event.tap do
            balance_destroyer.new(adjustment_balance).call
          end
        end
      end

      private

      def old_effective_at
        event.effective_at
      end
    end
  end
end
