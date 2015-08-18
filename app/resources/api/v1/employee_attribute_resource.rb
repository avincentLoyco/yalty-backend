module API
  module V1
    class EmployeeAttributeResource < JSONAPI::Resource
      model_name 'Employee::Attribute'
      attributes :name, :attribute_type, :data
    end
  end
end
