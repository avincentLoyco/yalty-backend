# frozen_string_literal: true

module Containers
  Models = Dry::Container::Namespace.new("models") do
    register("account") { Account }
  end
end
