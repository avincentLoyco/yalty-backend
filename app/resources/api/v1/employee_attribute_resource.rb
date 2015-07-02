module API
  module V1
    class EmployeeAttributeResource < JSONAPI::Resource
      attributes :name, :attribute_type, :data
    end
  end
end
