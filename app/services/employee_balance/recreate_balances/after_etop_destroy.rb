module RecreateBalances
  class AfterEtopDestroy
    attr_reader :params

    def initialize(destroyed_effective_at:, time_off_category_id:, employee_id:)
      @params = {
        destroyed_effective_at: destroyed_effective_at,
        time_off_category_id: time_off_category_id,
        employee_id: employee_id
      }
    end

    def call
      RecreateBalancesHelper.new(**params).after_etop_destroy
    end
  end
end
