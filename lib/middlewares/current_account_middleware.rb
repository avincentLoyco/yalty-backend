class CurrentAccountMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    find_current_account

    @app.call(env)
  end

  private

  def find_current_account
    Account.current = Account::User.current ? account_from_user : account_from_subdomain
  end

  def account_from_user
    Account.joins(:users).where(account_users: { id: Account::User.current.id }).first
  end

  def account_from_subdomain
    Account.where(subdomain: account_subdomain).first
  end

  def account_subdomain
    @request.env['HTTP_YALTY_ACCOUNT_SUBDOMAIN']
  end
end
