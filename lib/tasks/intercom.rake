namespace :intercom do
  desc 'import users to intercom'
  task :import => [:environment] do
    Account.all.each do |account|
      puts "import  #{account.company_name}"
      account.create_or_update_on_intercom(true)

      account.users.each do |user|
        puts "import #{user.email}"
        user.create_or_update_on_intercom(true)
      end

      puts ''
    end
  end

  namespace :invite do
    desc 'Add registration key to a random list of lead'
    task :random => [:environment] do
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
    task :email => [:environment] do
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

    desc 'Convert leads invited to users'
    task :convert => [:environment] do
      beta_invitations.each do |beta_invitation|
        registration_key = Account::RegistrationKey
          .includes(account: [:users])
          .where(token: beta_invitation.custom_attributes['beta_invitation_key'])
          .first
        next unless registration_key.present? && registration_key.account.present?

        user = registration_key.account.users.where(email: beta_invitation.email).first
        next unless user.present?

        intercom_client.contacts.convert(beta_invitation, user.intercom_data)
      end
    end

    def intercom_client
      @intercom_client ||= Intercom::Client.new(
        app_id: ENV['INTERCOM_APP_ID'],
        api_key: ENV['INTERCOM_API_KEY']
      )
    end

    def beta_requests
      @beta_requests ||= begin
        intercom_client.contacts
          .all
          .select do |beta_request|
            !beta_request.custom_attributes['beta_invitation_key'].present? &&
              beta_request.tags.map(&:name).include?('beta request') &&
              !beta_request.tags.map(&:name).include?('beta excluded')
          end
      end
    end

    def beta_invitations
      @beta_requests ||= begin
        intercom_client.contacts
          .all
          .select do |beta_request|
            beta_request.custom_attributes['beta_invitation_key'].present? &&
              beta_request.tags.map(&:name).include?('beta invitation')
          end
      end
    end

    def add_registration_keys(leads)
      leads.each do |lead|
        registration_key = Account::RegistrationKey.create
        lead.custom_attributes['beta_invitation_key'] = registration_key.token
        intercom_client.contacts.save(lead)
        puts "Add regsitration key to '#{lead.email}'"
      end
    end
  end
end
