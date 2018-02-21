namespace :intercom do
  desc "import users to intercom"
  task import: [:environment] do
    import_data
  end

  def import_data
    return puts "No intercom_client" unless intercom_client.present?

    puts "import accounts"
    Account.find_each { |account| intercom_client.companies.create(account.intercom_data) }
    puts "import users"
    Account::User.find_in_batches(batch_size: 100) do |users|
      intercom_client.users.submit_bulk_job(create_items: users.map(&:intercom_data))
    end
  end

  def intercom_client
    @intercom_service ||= IntercomService.new.client
  end
end
