module Events
  module ContractEnd
    class Create < Default::Create
      config_accessor :contract_end_service do
        ::ContractEnd::Create
      end

      def call
        event.tap do
          handle_contract_end
        end
      end

      private

      def handle_contract_end
        contract_end_service.call(employee: event.employee, contract_end_date: event.effective_at)
      end
    end
  end
end
