# frozen_string_literal: true

require "rails_helper"

RSpec.describe Employees::AssignEmployeeToAllTops do
  include ActiveSupport::Testing::TimeHelpers

  context "#call" do
    subject do
      described_class
      .new(
        etop_model: etop_model_mock,
        find_unassigned_tops_for_employee: find_unassigned_tops_for_employee_mock
      )
      .call(employee)
    end

    let(:employee) { build(:employee) }
    let(:etop_model_mock) { class_double(EmployeeTimeOffPolicy, create!: true) }
    let(:unassigned_tops_mock) { [build(:employee_time_off_policy)] }
    let(:find_unassigned_tops_for_employee_mock) do
      instance_double(Employees::AssignEmployeeToAllTops, call: unassigned_tops_mock)
    end
    let(:expected_etops_to_create) do
      [
        {
          employee_id: employee.id,
          time_off_policy_id: unassigned_tops_mock.first.id,
          time_off_category_id: unassigned_tops_mock.first.time_off_category_id,
          effective_at: Time.current,
        },
      ]
    end

    it "gets unassigned time off policies" do
      subject
      expect(find_unassigned_tops_for_employee_mock).to have_received(:call).with(employee)
    end

    it "assigns unassigned time off policies to employee" do
      travel_to Time.current do
        subject
        expect(etop_model_mock).to have_received(:create!).with(expected_etops_to_create)
      end
    end
  end
end
