RSpec.shared_context 'shared_context_headers', :a => :b do
  let(:user) { create(:account_user) }
  let(:account) { user.account }

  unless described_class == API::V1::EmployeeAttributeDefinitionsController
    before do
      allow_any_instance_of(Account).to receive(:update_default_attribute_definitions!) { true }
    end
  end

  before(:each) do
    Account::User.current = user
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/json',
      'ACCEPT' => 'application/json'
    )
  end
end
