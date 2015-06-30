require 'rails_helper'

RSpec.describe CurrentAccountMiddleware do
  let(:account_user) { FactoryGirl.create(:account_user) }
  let(:token) { FactoryGirl.create(:account_user_token, resource_owner_id: account_user.id).token }
  let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
    'HTTP_AUTHORIZATION' => "Bearer #{token}"
  })}
  let(:app) { ->(env) { [200, env, ['']] }}
  let(:middleware) { CurrentAccountMiddleware.new(app) }

  it 'should call app when is called' do
    expect(app).to receive(:call).with(env).and_call_original

    middleware.call(env)
  end

  it 'should set current account according to subdomain' do
    middleware.call(env)

    expect(Account.current).to eql(account_user.account)
  end

  it 'should not set current account if authentication header is not present' do
    env.delete('HTTP_AUTHORIZATION')

    expect {
      middleware.call(env)
    }.to_not raise_error

    expect(Account.current).to be_nil
  end
end
