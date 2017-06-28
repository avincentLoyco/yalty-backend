RSpec.shared_examples 'example_authorization' do |settings|
  actions = [:create, :show, :index, :update, :delete].map do |action|
    if settings[action].nil?
      action
    end
  end.compact

  let(:resource) { settings[:resource_name] }

  shared_examples 'Invalid Authorization' do
    context 'when current account nil' do
      before { Account.current = nil }

      it { is_expected.to have_http_status(401) }

      context 'response body' do
        before { subject }

        it { expect_json(
          errors: [
            {
              field: 'error',
              messages: ['User unauthorized'],
              status: 'invalid',
              type: 'nil_class',
              codes: ['error_user_unauthorized']
            }
          ]
        )}
      end
    end

    context 'when current user nil' do
      before { Account::User.current = nil }

      it { is_expected.to have_http_status(401) }

      context 'response body' do
        before { subject }

        it { expect_json(
          errors: [
            {
              field: 'error',
              messages: ['User unauthorized'],
              status: 'invalid',
              type: 'nil_class',
              codes: ['error_user_unauthorized']
            }
          ]
        )}
      end
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
