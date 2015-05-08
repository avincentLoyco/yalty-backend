class AccountsController < ApplicationController

  def create
    ActiveRecord::Base.transaction do
      account = Account.create!(account_params)
      account.users.create!(user_params)
    end

    render nothing: true, status: 201
  end

  private

  def account_params
    params.require(:account).permit(:company_name)
  end

  def user_params
    params.require(:user).permit(:email, :password)
  end

end
