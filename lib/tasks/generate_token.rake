task generate_token: [:environment] do
  puts 'Yalty Registration Keys:'
  puts ''

  10.times do
    registration_key = Account::RegistrationKey.create()

    puts registration_key.token
  end
end
