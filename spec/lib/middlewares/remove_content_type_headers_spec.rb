require 'rails_helper'

RSpec.describe RemoveContentTypeHeader do
  let(:app) { ->(env) { [response_status, env, ['test']] }}
  let(:middleware) { RemoveContentTypeHeader.new(app) }
  let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
    'Content-Type' => 'text/plain',
    'Content-Length' => 3
  })}

  before { RequestStore.clear! }

  context 'when response status is 205' do
    let(:response_status) { 205 }

    it { expect(middleware.call(env)[1]).to_not include('Content-Type') }
    it { expect(middleware.call(env)[1]).to_not include('Content-Length') }
    it { expect(middleware.call(env)[2]).to eq [] }
  end

  context 'when response status is different than 205' do
    let(:response_status) { 200 }

    it { expect(middleware.call(env)[1]).to include('Content-Type') }
    it { expect(middleware.call(env)[1]).to include('Content-Length') }
    it { expect(middleware.call(env)[2]).to include 'test' }
  end
end
