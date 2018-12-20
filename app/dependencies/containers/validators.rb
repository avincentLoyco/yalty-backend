# frozen_string_literal: true

module Containers
  Validators = Dry::Container::Namespace.new("validators") do
    namespace "registered_working_times" do
      register("part_of_employment_period") do
        RegisteredWorkingTimes::PartOfEmploymentPeriodValidator.new
      end
    end
  end
end
