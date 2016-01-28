module EmployeeBalanceRules
  include BaseRules

  def post_rules
    Gate.rules do
      required :amount, :Integer
      optional :effective_at
      required :employee, :Hash do
        required :id
      end
      required :time_off_category, :Hash do
        required :id
      end
    end
  end

  def put_rules
    Gate.rules do
      required :id
      optional :effective_at
      required :amount, :Integer
    end
  end
end
