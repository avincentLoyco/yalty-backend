# frozen_string_literal: true

module Containers
  include API::V1::Exceptions

  Errors = Dry::Container::Namespace.new("errors") do
    register("custom_error") { CustomError }
    register("invalid_resources_error") { InvalidResourcesError }
  end
end
