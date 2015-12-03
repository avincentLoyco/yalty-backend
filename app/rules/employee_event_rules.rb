module EmployeeEventRules
  include BaseRules

  def patch_rules
    Gate.rules do
      required :id
      optional :effective_at
      optional :event_type
      optional :comment
      optional :employee, :Hash do
        optional :id, :String
      end
      optional :employee_attributes, :Array
    end
  end

  def post_rules
    Gate.rules do
      required :effective_at
      required :event_type
      optional :comment
      required :employee, :Hash do
        optional :id, :String
      end
      optional :employee_attributes, :Array, allow_nil: true
    end
  end

  def put_rules
    Gate.rules do
      required :id
      required :effective_at
      required :event_type
      optional :comment
      required :employee, :Hash do
        required :id, :String
      end
      optional :employee_attributes, :Array, allow_nil: true
    end
  end
end
