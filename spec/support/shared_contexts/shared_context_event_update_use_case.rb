RSpec.shared_context "event update context" do
  subject { use_case.call }

  let(:use_case) { described_class.new(event, params) }
  let(:event_updater) { class_double("UpdateEvent") }
  let(:event_updater_instance) { instance_double("UpdateEvent") }
  let(:params) do
    { employee_attributes: employee_attributes, effective_at: event_effective_at }
  end

  let(:event)               { double }
  let(:employee_attributes) { nil }
  let(:event_effective_at)  { nil }

  before do
    use_case.event_updater = event_updater
    allow(event_updater).to receive(:new).and_return(event_updater_instance)
    allow(event_updater_instance).to receive(:call)
  end
end
