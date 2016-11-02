module RecreateBalances
  class AfterEtopCreate
    attr_reader :params

    def initialize(new_effective_at:, time_off_category_id:, employee_id:, manual_amount: 0)
      @params = {
        new_effective_at: new_effective_at,
        time_off_category_id: time_off_category_id,
        employee_id: employee_id,
        manual_amount: manual_amount
      }
    end

    def call
      RecreateBalancesHelper.new(**params).after_etop_create
    end
  end
end
