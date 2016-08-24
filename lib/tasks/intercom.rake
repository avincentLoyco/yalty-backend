namespace :intercom do
  desc 'import users to intercom'
  task import: [:environment] do
    import_data
  end

  def import_data
    return puts 'No intercom_client' unless intercom_client.present?

    puts 'import accounts'
    intercom_client.companies.submit_bulk_job(create_items: Account.all.map(&:intercom_data))
    puts 'import users'
    intercom_client.users.submit_bulk_job(create_items: Account::User.all.map(&:intercom_data))
  end

  def intercom_client
    @intercom_service ||= IntercomService.new.client
  end

  namespace :invite do
    desc 'Add registration key to a random list of lead'
    task random: [:environment] do
      STDOUT.puts "Number of leads to invite: (default: 0, max: #{beta_requests.size})"
      invitation_count = STDIN.gets.chomp.to_i
      invitation_count = 0 if invitation_count < 0

      if beta_requests.size > invitation_count
        add_registration_keys(beta_requests.sample(invitation_count))
      else
        add_registration_keys(beta_requests)
      end
    end

    desc 'Add registration key to choosen leads'
    task email: [:environment] do
      return unless intercom_client.present?

      STDOUT.puts 'List of email to invite (coma separator):'
      emails = STDIN.gets.chomp.split(',').map(&:strip)

      beta_requests.delete_if { |lead| !emails.include?(lead.email) }

      (emails - beta_requests.map(&:email)).each do |email|
        lead   = intercom_client.contacts.find_all(email: email).first
        lead ||= intercom_client.contacts.create(email: email)

        next if lead.custom_attributes['beta_invitation_key'].present?
        next if lead.tags.map(&:name).include?('beta excluded')

        intercom_client.tags.tag(name: 'beta request', users: [{ id: lead.id }])

        puts "Create lead '#{lead.email}'"
        beta_requests << lead
      end

      add_registration_keys(beta_requests)
    end

    def beta_requests
      @beta_requests ||= begin
        intercom_client.contacts
                       .all
                       .select do |beta_request|
          tags = beta_request.tags.map(&:name)

          tags.include?('beta request') &&
            !beta_request.custom_attributes['beta_invitation_key'].present? &&
            !tags.include?('beta invitation') &&
            !tags.include?('beta excluded')
        end
      end
    end

    def add_registration_keys(leads)
      return unless intercom_client.present?

      leads.each do |lead|
        registration_key = Account::RegistrationKey.create
        lead.custom_attributes['beta_invitation_key'] = registration_key.token
        intercom_client.contacts.save(lead)
        puts "Add regsitration key '#{registration_key.token}' to '#{lead.email}'"
      end
    end
  end
end
