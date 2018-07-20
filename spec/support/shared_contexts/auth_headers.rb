RSpec.shared_context "auth_headers", :auth_user do
  let(:headers) do
    raise Yalty::WrongAuthUser, "set auth_user in the example/group" unless respond_to?(:auth_user)
    { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
  end

  let(:token) do
    create(:account_user_token, resource_owner_id: auth_user.id).token
  end
end
