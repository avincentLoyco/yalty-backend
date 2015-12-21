module Api::V1
  class EmployeeAttributeVersionRepresenter < BaseRepresenter
    def complete
      {
        attribute_name: resource.attribute_name,
        value: resource.data.value,
        order: resource.order
      }.merge(basic)
    end
  end
end
