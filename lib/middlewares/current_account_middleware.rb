class CurrentAccountMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @request = ActionDispatch::Request.new(env)

    set_current_account(env)

    @app.call(env)
  end

  private

  def set_current_account(env)
    Account.current = Account::User.current ? account_from_user : account_from_subdomain(env)
  end

  def account_from_user
    Account.joins(:users).where(account_users: { id: Account::User.current.id }).first
  end

  def account_from_subdomain(env)
    Account.where(subdomain: account_subdomain(env)).first
  end

  def account_subdomain(env)
    env['HTTP_YALTY_ACCOUNT_SUBDOMAIN']
  end
end
