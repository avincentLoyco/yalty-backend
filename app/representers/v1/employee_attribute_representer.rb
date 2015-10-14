module V1
  class EmployeeAttributeRepresenter < BaseRepresenter
    def complete
      {
        attribute_name: resource.attribute_name,
        value: resource.data.value
      }.merge(basic)
    end
  end
end
