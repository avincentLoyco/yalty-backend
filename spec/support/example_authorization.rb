RSpec.shared_examples 'example_authorization' do |settings|
  actions = [:create, :show, :index, :update, :delete].map do |action|
    if settings[action].nil?
      action
    end
  end.compact

  let(:resource) { settings[:resource_name] }

  shared_examples 'Invalid Authorization' do
    let(:env) { Rack::MockRequest.env_for('https://api.yalty.io', {
      'HTTP_AUTHORIZATION' => "Bearer #{token}"
    })}

    let(:app) { ->(env) { [200, env, ['']] }}
    let(:middleware) { CurrentAccountMiddleware.new(app) }

    after do
      RequestStore.clear!
    end

    context 'when valid access token send' do
      let(:account_user) { create(:account_user) }
      let(:token) { create(:account_user_token, resource_owner_id: account_user.id).token }

      before { middleware.call(env) }

      it { expect(Account::User.current).to eq(account_user) }
      it { expect(Account.current).to eq(account_user.account) }

      it { is_expected.to_not have_http_status(401) }
    end

    context 'when access token invalid' do
      let(:token) { '123' }

      before { middleware.call(env) }
      before { subject }

      it { expect(Account::User.current).to eq nil }
      it { expect(Account.current).to eq nil }

      it { is_expected.to have_http_status(401) }
      it { expect(response.body).to include 'User unauthorized' }
    end

    context 'when access token nil' do
      let(:token) { nil }

      before { middleware.call(env) }
      before { subject }

      it { expect(Account::User.current).to eq nil }
      it { expect(Account.current).to eq nil }

      it { is_expected.to have_http_status(401) }
      it { expect(response.body).to include 'User unauthorized' }
    end
  end

  if actions.include?(:show)
    let(:resource) { create(settings[:resource_name]) }
    subject { get :show, id: resource.id }

    it_behaves_like 'Invalid Authorization'
  end

  if actions.include?(:index)
    subject { get :index }

    it_behaves_like 'Invalid Authorization'
  end

  if actions.include?(:create)
    subject { post :create }

    it_behaves_like 'Invalid Authorization'
  end

  if actions.include?(:update)
    let(:resource) { create(settings[:resource_name]) }
    subject { put :update, id: resource.id }

    it_behaves_like 'Invalid Authorization'
  end

  if actions.include?(:delete)
    let(:resource) { create(settings[:resource_name]) }
    subject { put :update, id: resource.id }

    it_behaves_like 'Invalid Authorization'
  end
end
