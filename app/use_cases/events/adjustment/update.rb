# TODO: refactor this class to use dependency injection

module Events
  module Adjustment
    class Update < Default::Update
      include Adjustment::Balances

      config_accessor :next_balance_updater do
        UpdateNextEmployeeBalances
      end

      class << self
        def call(event, params)
          new(event, params).call
        end
      end

      pattr_initialize :event, :params do
        @old_effective_at = event.effective_at
      end

      def call
        ActiveRecord::Base.transaction do
          update_event.tap do |event|
            adjustment_balance.update!(
              resource_amount: event.attribute_value("adjustment"),
              effective_at: event.effective_at + Employee::Balance::MANUAL_ADJUSTMENT_OFFSET
            )
            next_balance_updater.new(adjustment_balance).call
          end
        end
      end

      private

      attr_reader :old_effective_at
    end
  end
end
