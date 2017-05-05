require 'rails_helper'

RSpec.describe CustomTokenResponse do
  subject { Doorkeeper::OAuth::TokenResponse.new(token).body }

  let(:token) { double(resource_owner_id: user.id).as_null_object }
  let(:uuid) { 'b10c846f-945e-4079-8c37-cbc91e377bdb' }
  let(:user) { create(:account_user, :with_employee, account: account, id: uuid, role: 'account_owner', locale: 'fr') }
  let(:account) { create(:account, default_locale: 'en') }

  before(:all) do
    if Doorkeeper::OAuth.const_defined?(:TokenResponse)
      Doorkeeper::OAuth.send(:remove_const, :TokenResponse)
      Object.send(:remove_const, :CustomTokenResponse)
      load 'doorkeeper/oauth/token_response.rb'
      load 'custom_token_response.rb'
      Doorkeeper::OAuth::TokenResponse.send :prepend, CustomTokenResponse
    end
  end

  it { expect(subject[:user][:id]).to eql(uuid) }
  it { expect(subject[:user][:intercom_hash]).to eql('7bfa694094c14c24e3e945269d4fe8fa7280c8496dd876ef455758880ad85dce') }
  it { expect(subject[:user][:role]).to eql('account_owner') }
  it { expect(subject[:user][:locale]).to eql('fr') }
  it { expect(subject[:user][:employee]).to include(id: user.employee.id) }
end
