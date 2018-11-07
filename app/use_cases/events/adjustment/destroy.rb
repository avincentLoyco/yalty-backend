# TODO: refactor this class to use dependency injection

module Events
  module Adjustment
    class Destroy < Default::Destroy
      include Adjustment::Balances

      config_accessor :balance_destroyer do
        DestroyEmployeeBalance
      end

      def call
        ActiveRecord::Base.transaction do
          destroy_event.tap do
            balance_destroyer.call(adjustment_balance)
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
