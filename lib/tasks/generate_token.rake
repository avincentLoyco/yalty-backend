namespace :generate do
  task registration_key_token: [:environment] do
    STDOUT.puts 'Number of registration keys for generation: (by default 10)'
    input = STDIN.gets.chomp
    input = 10 if input.blank?
    create_tokens(input.to_i)
  end

  def create_tokens(input)
    puts 'Yalty Registration Keys:'
    puts ''

    puts 'Invalid input' if input.zero?

    input.to_i.times do
      registration_key = Account::RegistrationKey.create

      puts registration_key.token
    end
  end
end
