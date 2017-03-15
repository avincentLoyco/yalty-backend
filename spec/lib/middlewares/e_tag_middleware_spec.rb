require 'rails_helper'

RSpec.describe ETagMiddleware do
  let(:account) { create(:account, id: 'c5cbba38-b738-44af-997a-5ab130d81726') }
  let(:account_subdomain) { account.subdomain }
  let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
    'HTTP_YALTY_ACCOUNT_SUBDOMAIN' => "#{account_subdomain}"
  })}
  let(:app) { ->(env) { [200, env, ['']] }}
  let(:middleware) { ETagMiddleware.new(app) }

  context 'when current account is set' do
    before { Account.current = account }

    context 'and etag header is already set' do
      before { env[Rack::ETag::ETAG_STRING] = 'W/"1234567890"' }

      it 'should update etag' do
        status, headers, body = middleware.call(env)

        expect(headers).to have_key(Rack::ETag::ETAG_STRING)
        expect(headers[Rack::ETag::ETAG_STRING]).to be_eql('W/"7dd6404fcaadfa6c248034efaca37c61"')
      end
    end

    context 'and etag header is empty' do
      before { env.delete(Rack::ETag::ETAG_STRING) }

      it 'should not set etag' do
        status, headers, body = middleware.call(env)

        expect(headers).to_not have_key( Rack::ETag::ETAG_STRING)
      end
    end
  end

  context 'when current account is empty' do
    before { Account.current = nil }

    context 'and etag header is already set' do
      before { env[Rack::ETag::ETAG_STRING] = 'W/"1234567890"' }

      it 'should not update etag' do
        status, headers, body = middleware.call(env)

        expect(headers).to have_key(Rack::ETag::ETAG_STRING)
        expect(headers[Rack::ETag::ETAG_STRING]).to be_eql('W/"1234567890"')
      end
    end

    context 'and etag header is empty' do
      before { env.delete(Rack::ETag::ETAG_STRING) }

      it 'should not set etag' do
        status, headers, body = middleware.call(env)

        expect(headers).to_not have_key( Rack::ETag::ETAG_STRING)
      end
    end
  end
end
