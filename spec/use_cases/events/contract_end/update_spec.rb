require "rails_helper"

RSpec.describe Events::ContractEnd::Update do
  include_context "event update context"

  subject do
    described_class
      .new(
        assign_employee_top_to_event: assign_employee_top_to_event_mock,
        update_event_service: update_event_service_class_mock
      )
      .call(event, params)
  end

  let(:assign_employee_top_to_event_mock) do
    instance_double(Events::ContractEnd::AssignEmployeeTopToEvent, call: true)
  end

  it_behaves_like "event update example"

  it "assigns time off policy to the event" do
    subject
    expect(assign_employee_top_to_event_mock).to have_received(:call).with(event)
  end
end
