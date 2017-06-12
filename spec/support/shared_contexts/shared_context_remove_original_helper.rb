RSpec.shared_context 'shared_context_remove_original_helper' do
  before { allow_any_instance_of(FindValueForAttribute).to receive(:remove_original) {} }
end
