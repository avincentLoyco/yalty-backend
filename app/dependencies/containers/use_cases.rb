# frozen_string_literal: true

module Containers
  UseCases = Dry::Container::Namespace.new("use_cases") do
    namespace "employees" do
      register("index") {  Employees::Index.new }
      register("show") {  Employees::Show.new }
      register("destroy") {  Employees::Destroy.new }
    end
  end
end
