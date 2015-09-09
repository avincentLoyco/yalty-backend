module API
  module V1
    module Employees
      class EventResource < JSONAPI::Resource
        model_name 'Employee::Event'
        attributes :effective_at, :comment
      end
    end
  end
end
