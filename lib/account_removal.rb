# NOTE: the purpose of this rake task - clean up fake/tests accounts in
# production db.
class AccountRemoval
  def initialize(account_subdomain)
    @account = Account.find_by!(subdomain: account_subdomain)
  end

  def call
    # NOTE: we are able to delete only intercom users, because there is no
    # supported API endpoint for deleting intercom company,
    # at least for the date: 5.10.2018
    # Those companies should be removed by hand on Intercom Panel.
    delete_intercom_users
    delete_stripe_customer
    delete_account
  end

  private

  attr_reader :account

  def intercom_client
    @intercom_client ||= IntercomService.new.client
  end

  def delete_intercom_user(user_id)
    user = intercom_client.users.find(user_id: user_id)
    intercom_client.users.delete(user)
  rescue Intercom::ResourceNotFound => e
    Rails.logger.debug(e.message)
  end

  def delete_intercom_users
    account.user_ids.each do |user_id|
      delete_intercom_user(user_id)
    end
  end

  def delete_stripe_customer
    customer = Stripe::Customer.retrieve(account.customer_id)
    customer.delete
  rescue Stripe::InvalidRequestError => e
    Rails.logger.debug(e.message)
  end

  def delete_account
    account.destroy!
  end
end
