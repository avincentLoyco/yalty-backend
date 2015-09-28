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
          # TODO
        end
      end
      if actions.include?(:update)
        context 'PUT #update' do
          # TODO
          # let(settings[:resource_name]) { FactoryGirl.create(settings[:resource_name], account: account)}
          #
          # it 'should response with success' do
          #   attributes = send(settings[:resource_name]).attributes
          #   attributes.delete('id')
          #   attributes.delete('created_at')
          #   attributes.delete('updated_at')
          #
          #   data = {
          #     "id": send(settings[:resource_name]).id,
          #     "data": {
          #       "id": send(settings[:resource_name]).id,
          #       "type": settings[:resource_name].pluralize.gsub('_', '-'),
          #       "attributes": attributes
          #     }
          #   }
          #   put :update, data
          #
          #   expect(response).to have_http_status(:success)
          # end
        end
      end
      if actions.include?(:show)
        context 'GET #show' do
          let(settings[:resource_name]) { FactoryGirl.create(settings[:resource_name], account: account)}

          it 'should response with success' do
            get :show, { id: send(settings[:resource_name]).id }

            expect(response).to have_http_status(:success)
            data = JSON.parse(response.body)
            expect(data['data']['id']).to eq(send(settings[:resource_name]).id)
          end
        end
      end
      if actions.include?(:delete)
        context 'DELETE #destroy' do
          let(settings[:resource_name]) { FactoryGirl.create(settings[:resource_name], account: account)}

          it 'should delete proper resources' do
            delete :destroy, { id: send(settings[:resource_name]).id }
            expect(response).to have_http_status(:success)
          end

          it 'should delete resource from db' do
            delete :destroy, { id: send(settings[:resource_name]).id }
            get :show, { id: send(settings[:resource_name]).id }

            expect(response).to have_http_status(404)
          end
        end
      end
    end
  end
end
