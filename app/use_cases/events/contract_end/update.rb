module Events
  module ContractEnd
    class Update < Default::Update

      config_accessor :contract_end_service do
        ::ContractEnds::Update
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
        update_event.tap do
          handle_contract_end
        end
      end

      private

      attr_reader :old_effective_at

      def handle_contract_end
        return unless old_effective_at != params[:effective_at]
        contract_end_service.call(
          employee: event.employee,
          new_contract_end_date: params[:effective_at],
          old_contract_end_date: old_effective_at
        )
      end

    end
  end
end
