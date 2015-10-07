RSpec.shared_examples 'example_crud_resources' do |settings|
  include_context 'shared_context_headers'
  actions = [:create, :update, :show, :index, :delete].map do |action|
    if settings[action] || settings[action].nil?
      action
    end
  end.compact
  let(:resource_name) { settings[:resource_name] }

  context '#example_crud_resources'do
    if actions.include?(:index)
      context 'GET #index' do
        before(:each) do
          create_list(settings[:resource_name], 3, account: account)
        end

        it 'should respond with success' do
          get :index

          expect(response).to have_http_status(:success)
        end

        it 'should not be visible in context of other account' do
          user = create(:account_user)
          Account.current = user.account

          get :index

          expect(response).to have_http_status(:success)
          expect_json_sizes(settings[:resource_name].pluralize.to_sym => 0)
        end
      end

      if actions.include?(:create)
        context 'POST #create' do
          let(:resource_params) { attributes_for(settings[:resource_name]) }
          let(:params) { resource_params.merge("type": settings[:resource_name].pluralize) }

          it 'should create resource' do
            expect { post :create, params }.to change { resource_name.classify.
                                                        safe_constantize.count }.by(1)
          end

          it 'should respond with success' do
            post :create, params

            expect(response).to have_http_status(:success)
          end

          it 'should assign current account id as account id' do
            post :create, params

            data = JSON.parse response.body
            resource = resource_name.classify.safe_constantize.where(id: data['id']).first
            expect(resource.try(:account_id)).to eq Account.current.id
          end
        end
      end
      if actions.include?(:update)
        context 'PUT #update' do
          let(settings[:resource_name]) { create(settings[:resource_name], account: account)}
          let(:resource_param) { (attributes_for(settings[:resource_name])).keys.first }
          let(:params) do
            {
              resource_param => 'test',
              "type": settings[:resource_name].pluralize.gsub('_', '-'),
              "id": send(settings[:resource_name]).id
            }
          end

          it 'should update resource attribute' do
            expect { put :update, params }.to change { send(settings[:resource_name])
                                                       .reload[resource_param] }.to('test')
          end

          it 'should respond with success' do
            put :update, params
            expect(response).to have_http_status(:success)
          end
        end
      end
      if actions.include?(:show)
        context 'GET #show' do
          let(settings[:resource_name]) { create(settings[:resource_name], account: account)}

          it 'should response with success' do
            get :show, { id: send(settings[:resource_name]).id }

            expect(response).to have_http_status(:success)
            data = JSON.parse(response.body)
            expect(data['id']).to eq(send(settings[:resource_name]).id)
          end
        end
      end
      if actions.include?(:delete)
        context 'DELETE #destroy' do
          let(settings[:resource_name]) { create(settings[:resource_name], account: account)}
          subject { delete :destroy, id: send(settings[:resource_name]).id }

          it 'should delete proper resources' do
            subject

            expect(response).to have_http_status(:success)
          end

          it 'should change resource number' do
            expect { subject }.to change { settings[:resource_name]
                                            .classify.safe_constantize.count }.by(-1)
          end

          it 'should delete resource from db' do
            subject
            get :show, id: send(settings[:resource_name]).id
            expect(response).to have_http_status(404)
          end
        end
      end
    end
  end
end
