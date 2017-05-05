module CustomTokenResponse
  def body
    super.merge(user: Api::V1::UserRepresenter.new(current_user).session)
  end

  private

  def current_user
    Account::User.find(token.resource_owner_id)
  end
end
