module API
  module V1
    class EmployeeEventResource < JSONAPI::Resource
      model_name 'Employee::Event'

      attributes :effective_at, :comment

      has_many :employee_attributes, relation_name: :employee_attribute_versions
    end
  end
end
