RSpec.shared_context 'shared_context_account_helper' do
  before do
    allow_any_instance_of(Account).to receive(:update_default_attribute_definitions!) { true }
    allow_any_instance_of(Account).to receive(:update_default_time_off_categories!) { true }
  end
end
