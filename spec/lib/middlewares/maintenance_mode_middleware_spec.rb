require 'rails_helper'

RSpec.describe MaintenanceModeMiddleware do
  let(:account_user) { create(:account_user) }
  let(:token) { create(:account_user_token, resource_owner_id: account_user.id).token }
  let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
    'HTTP_AUTHORIZATION' => "Bearer #{token}"
  })}
  let(:app) { ->(env) { [200, env, ['']] }}
  let(:middleware) { MaintenanceModeMiddleware.new(app) }

  before do
    RequestStore.clear!
  end

  context 'maintenance mode turn on' do
    before(:each) do
      ENV['YALTY_MAINTENANCE_MODE'] = 'true'
    end

    it 'should return 503 and maintenance mode' do
      expect(middleware.call(env)).to eq [
        503, { 'Content-Type' => 'application/json' }, ['{"error": "Maintenance mode"}']
      ]
    end
  end

  context 'maintenance mode turn off' do
    before(:each) do
      ENV['YALTY_MAINTENANCE_MODE'] = 'false'
    end

    it 'should return 200' do
      expect(middleware.call(env)[0]).to eq 200
    end
  end

end
