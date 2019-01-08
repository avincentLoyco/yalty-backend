module PresencePolicies
  class VerifyEmployeesNotAssigned
    include API::V1::Exceptions

    def call(resource:)
      @resource = resource
      return unless resource.respond_to?(:employees) && resource.employees.any?

      raise LockedError.new(
        type: resource_type,
        field: :employees,
        messages: [error_message],
        codes: [error_code],
      )
    end

    private

    attr_reader :resource

    def resource_type
      @resource_type ||= resource.class.name.underscore
    end

    # NOTE message and code was taken from ExceptionHandler class, where LockedError is also
    # generated - it should be refactored and generated in one place (TODO) but it's too much
    # for the scope of YA-2066, that's why this class is used only for presence_policy related
    # fragments of code.
    def error_message
      "Resource is locked because #{resource_type} has assigned employees to it"
    end

    def error_code
      "#{resource_type}_employees_present"
    end
  end
end
