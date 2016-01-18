module Api::V1
  class CategoryBalanceRepresenter
    attr_reader :employee, :category

    def initialize(employee, category)
      @employee = employee
      @category = category
    end

    def basic
      {
        category.name => employee.last_balance_in_category(category.id).try(:balance)
      }
    end
  end
end
