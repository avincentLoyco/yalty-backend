namespace :generate do
  task registration_key_token: [:environment] do
    STDOUT.puts "Number of registration keys for generation: (by default 10)"
    input = STDIN.gets.chomp

    if input == '' || integer?(input)
      create_tokens(input)
    else
      puts 'Invalid input'
    end
  end

  def create_tokens(input)
    puts 'Yalty Registration Keys:'
    puts ''

    input = 10 if input == ''

    input.to_i.times do
      registration_key = Account::RegistrationKey.create()

      puts registration_key.token
    end
  end

  def integer?(input)
    input.match(/^(\d)+$/)
  end
end
