RSpec.shared_context 'shared_context_headers', :a => :b do
  let(:user) { create(:account_user) }
  let(:account) { user.account }

  before(:each) do
    Account::User.current = user
    Account.current = account
    @request.headers.merge!(
      'CONTENT-TYPE' => 'application/json',
      'ACCEPT' => 'application/json'
    )
  end
end
