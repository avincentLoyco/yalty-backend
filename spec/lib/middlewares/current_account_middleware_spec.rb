require "rails_helper"

RSpec.describe CurrentAccountMiddleware do
  let(:account_user) { create(:account_user) }
  let(:account_subdomain) { account_user.account.subdomain }
  let(:env) { Rack::MockRequest.env_for("https://api.yalty.io", {
    "HTTP_YALTY_ACCOUNT_SUBDOMAIN" => "#{account_subdomain}"
  })}
  let(:app) { ->(env) { [200, env, [""]] }}
  let(:middleware) { CurrentAccountMiddleware.new(app) }

  before do
    RequestStore.clear!
  end

  context "when Account::User set" do
    before { Account::User.current = account_user }
    before { middleware.call(env) }

    it { expect(Account.current).to eql(account_user.account) }
    it { expect(Account::User.current).to eql(account_user) }
  end

  context "when Account::User set with yalty user" do
    let(:account_user) { create(:account_user, :with_yalty_role) }

    before { Account::User.current = account_user }
    before { middleware.call(env) }

    it { expect(Account.current).to eql(account_user.account) }
    it { expect(Account::User.current).to eql(account_user) }
  end

  context "when Account::User not set" do
    context "when YALTY_ACCOUNT_SUBDOMAIN header send" do
      context "and subdomain valid" do
        before { middleware.call(env) }

        it { expect(Account.current).to eql(account_user.account) }
        it { expect(Account::User.current).to eql(nil) }
      end

      context "and subdomain invalid" do
        let(:account_subdomain) { "test" }

        before { middleware.call(env) }

        it { expect(Account.current).to eql(nil) }
        it { expect(Account::User.current).to eql(nil) }
      end

      context "and subdomain empty" do
        before { env["HTTP_YALTY_ACCOUNT_SUBDOMAIN"] = nil }
        before { middleware.call(env) }

        it { expect(Account.current).to eql(nil) }
        it { expect(Account::User.current).to eql(nil) }
      end
    end

    context "when YALTY_ACCOUNT_SUBDOMAIN header not send" do
      before { env.delete("HTTP_YALTY_ACCOUNT_SUBDOMAIN") }
      before { middleware.call(env) }

      it { expect(Account.current).to eql(nil) }
      it { expect(Account::User.current).to eql(nil) }
    end
  end
end

