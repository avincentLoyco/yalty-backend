module Api::V1
  class EmployeeEventTypeRepresenter
    attr_reader :type, :attributes

    def initialize(type, attributes)
      @type = type
      @attributes = attributes
    end

    def basic
      {
        event_type: type,
        attributes: attributes
      }
    end
  end
end
