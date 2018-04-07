RSpec.shared_context "event destroy context" do
  subject { use_case.call }

  let(:use_case) { described_class.new(event) }

  let(:event_destroyer) { class_double("DestroyEvent") }
  let(:event_destroyer_instance) { instance_double("DestroyEvent") }

  let(:event) { double }

  before do
    use_case.event_destroyer = event_destroyer
    allow(event_destroyer).to receive(:new).and_return(event_destroyer_instance)
    allow(event_destroyer_instance).to receive(:call)
  end
end
