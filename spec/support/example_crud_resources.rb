RSpec.shared_examples 'example_crud_resources' do |settings|
  include_context 'shared_context_headers'
  actions = [:create, :update, :show, :index, :delete].map do |action|
    if settings[action] || settings[action].nil?
      action
    end
  end.compact

  context '#example_crud_resources'do
    if actions.include?(:index)
      context 'GET #index' do
        before(:each) do
          FactoryGirl.create_list(settings[:resource_name], 3, account: account)
        end

        it 'should respond with success' do
          get :index

          expect(response).to have_http_status(:success)
        end

        it 'should not be visible in context of other account' do
          user = FactoryGirl.create(:account_user)
          Account.current = user.account

          get :index

          expect(response).to have_http_status(:success)
          expect_json_sizes(data: 0)
        end
      end
      if actions.include?(:create)
        context 'POST #create' do

        end
      end
    end
  end
end
