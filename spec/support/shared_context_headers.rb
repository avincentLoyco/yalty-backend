RSpec.shared_context 'shared_context_headers', :a => :b do
  let(:user) { create(:account_user, account_manager: true) }
  let(:account) { user.account }

  unless described_class == API::V1::EmployeeAttributeDefinitionsController
    include_context 'shared_context_account_helper'
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
