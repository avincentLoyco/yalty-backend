module API
  module V1
    class EmployeeAttributeResource < JSONAPI::Resource
      model_name 'Employee::Attribute'
      attributes :attribute_name, :attribute_type, :data, :effective_at
    end
  end
end
