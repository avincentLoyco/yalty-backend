require 'rails_helper'

RSpec.describe CurrentUserMiddleware do
  let(:account_user) { create(:account_user) }
  let(:token) { create(:account_user_token, resource_owner_id: account_user.id).token }
  let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
    'HTTP_AUTHORIZATION' => "Bearer #{token}"
  })}
  let(:app) { ->(env) { [200, env, ['']] }}
  let(:middleware) { CurrentUserMiddleware.new(app) }

  before do
    RequestStore.clear!
  end

  context 'when AUTHORIZATION header send' do
    context 'and token valid' do
      before { middleware.call(env) }

      it { expect(Account::User.current).to eql(account_user) }
    end

    context 'and token valid for a yalty user' do
      let(:account_user) { create(:account_user, :with_yalty_role) }

      before { middleware.call(env) }

      it { expect(Account::User.current).to eql(account_user) }
    end

    context 'and token invalid' do
      let(:token) { '123' }

      before { middleware.call(env) }

      it { expect(Account::User.current).to eql(nil) }
      it { expect(middleware.call(env)).to eq [
        401, {"Content-Type" => "application/json"}, ['{"error": "User not authorized"}']
      ]}
    end

    context 'and token empty' do
      before { env['HTTP_AUTHORIZATION'] = nil }
      before { middleware.call(env) }

      it { expect(Account::User.current).to eql(nil) }
      it { expect(middleware.call(env)).to_not eq [
        401, {"Content-Type" => "application/json"}, ['{"error": "User not authorized"}']
      ]}
    end
  end

  context 'when AUTHORIZATION header not send' do
    before { env.delete('HTTP_AUTHORIZATION') }
    before { middleware.call(env) }

    it { expect(Account::User.current).to eql(nil) }
    it { expect(middleware.call(env)).to_not eq [
      401, {"Content-Type" => "application/json"}, ['{"error": "User not authorized"}']
    ]}
  end
end
