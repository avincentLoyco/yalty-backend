RSpec.shared_examples "example_crud_resources" do |settings|
  include_context "shared_context_headers"
  actions = [:create, :update, :show, :index, :delete].map do |action|
    if settings[action] || settings[action].nil?
      action
    end
  end.compact
  let(:resource_name) { settings[:resource_name] }

  context "#example_crud_resources"do
    if actions.include?(:index)
      context "GET #index" do
        before(:each) do
          create_list(settings[:resource_name], 3, account: account)
        end

        it "should respond with success" do
          get :index

          expect(response).to have_http_status(:success)
        end

        it "should not be visible in context of other account" do
          user = create(:account_user)
          Account.current = user.account

          get :index

          expect(response).to have_http_status(:success)
          expect(response.body).to eq "[]"
        end
      end
      if actions.include?(:create)
        context "POST #create" do
          context "valid data and valid id" do
            let(:params) { resource_params.merge("type": settings[:resource_name].pluralize) }

            if settings[:resource_name].eql?("working_place")
              let(:resource_params) { attributes_for(settings[:resource_name], :with_address) }
            else
              let(:resource_params) { attributes_for(settings[:resource_name]) }
            end

            it "should create resource" do
              expect { post :create, params }.to change { resource_name.classify.
                                                          safe_constantize.count }.by(1)
            end

            it "should respond with success" do
              post :create, params

              expect(response).to have_http_status(:success)
            end

            it "should assign current account id as account id" do
              post :create, params

              data = JSON.parse response.body
              resource = resource_name.classify.safe_constantize.where(id: data["id"]).first
              expect(resource.try(:account_id)).to eq Account.current.id
            end
          end
        end
      end
      if actions.include?(:update)
        context "PUT #update" do
          context "valid data and valid id" do

            let(settings[:resource_name]) { create(settings[:resource_name], account: account)}
            let(:resource_param) { (attributes_for(settings[:resource_name])).keys.first }

            let(:params) do
              { resource_param => "test" }.tap do |param|
                param[:type] = settings[:resource_name].pluralize.gsub("_", "-")
                param[:id] = send(settings[:resource_name]).id
                param[:country_code] = "CH" if settings[:resource_name].eql?("working_place")
                param[:city] = "Zurich" if settings[:resource_name].eql?("working_place")
              end
            end

            it "should update resource attribute" do
              expect { put :update, params }.to change { send(settings[:resource_name])
                                                         .reload[resource_param] }.to("test")
            end

            it "should respond with success" do
              put :update, params
              expect(response).to have_http_status(204)
            end
          end
        end
      end
      if actions.include?(:show)
        context "GET #show" do
          let(settings[:resource_name]) { create(settings[:resource_name], account: account) }

          context "valid id" do
             it "should response with success" do
              get :show, { id: send(settings[:resource_name]).id }

              expect(response).to have_http_status(:success)
              data = JSON.parse(response.body)
              expect(data["id"]).to eq(send(settings[:resource_name]).id)
            end
          end

          context "invalid id" do
            subject { get :show, params }

            context "when wrong id in wrong format send" do
              let(:params) {{ id: "1" }}

              it "should respond with 404" do
                subject
                expect(response).to have_http_status(404)
                expect(response.body).to include "Record Not Found"
              end
            end

            context "when record does not exist" do
              let(:params) {{ id: "abcdefgh-1234-1234-1234-123456789012" }}

              it "should respond with 404" do
                subject
                expect(response).to have_http_status(404)
                expect(response.body).to include "Record Not Found"
              end
            end

            context "when record exist but belongs to other user" do
              let!(settings[:resource_name]) { create(settings[:resource_name]) }
              let(:params) {{ id: send(settings[:resource_name]).id }}

              it "should respond with 404" do
                subject
                expect(response).to have_http_status(404)
                expect(response.body).to include "Record Not Found"
              end
            end
          end
        end
      end
      if actions.include?(:delete)
        context "DELETE #destroy" do
          let!(settings[:resource_name]) { create(settings[:resource_name], account: account) }
          subject { delete :destroy, id: send(settings[:resource_name]).id }

          context "valid id" do
            it "should delete proper resources" do
              subject

              expect(response).to have_http_status(:success)
            end

            it "should change resource number" do
              expect { subject }.to change { settings[:resource_name]
                                              .classify.safe_constantize.count }.by(-1)
            end
          end

          context "invalid id" do
            subject { delete :destroy, params }

            context "when record does not exist" do
              let(:params) {{ id: "12345678-1234-1234-1234-123456789012" }}

              it "should respond with 404" do
                subject
                expect(response).to have_http_status(404)
                expect(response.body).to include "Record Not Found"
              end
            end

            context "when record exist but belongs to other user" do
              let!(settings[:resource_name]) { create(settings[:resource_name]) }
              let(:params) {{ id: send(settings[:resource_name]).id }}

              it "should respond with 404" do
                subject
                expect(response).to have_http_status(404)
                expect(response.body).to include "Record Not Found"
              end
            end
          end
        end
      end
    end
  end
end
