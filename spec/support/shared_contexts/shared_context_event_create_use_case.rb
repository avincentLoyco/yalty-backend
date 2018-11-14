# TODO: remove this file after all use cases are refactored to use dependency injection

RSpec.shared_context "event create use case" do
  subject { use_case.call }

  let(:use_case) { described_class.new(params) }
  let(:event_creator) { class_double("CreateEvent") }
  let(:event_creator_instance) { instance_double("CreateEvent") }
  let(:params) do
    {
      employee_attributes: employee_attributes,
      data: :data,
    }
  end
  let(:employee_attributes) { nil }

  before do
    use_case.event_creator = event_creator
    allow(event_creator).to receive(:new).and_return(event_creator_instance)
    allow(event_creator_instance).to receive(:call)
  end
end
