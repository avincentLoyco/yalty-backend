task setup: [:environment] do
  client_id           = ENV["YALTY_OAUTH_ID"]
  client_secret       = ENV["YALTY_OAUTH_SECRET"]
  client_redirect_uri = ENV["YALTY_OAUTH_REDIRECT_URI"]

  app = Doorkeeper::Application.by_uid(client_id)
  app = Doorkeeper::Application.new if app.nil?

  app.attributes = {
    name: "yalty.app",
    uid: client_id,
    secret: client_secret,
    redirect_uri: client_redirect_uri,
    scopes: "all_access",
  }

  app.save!

  puts "Yalty APP oauth information (name: #{app.name})"
  puts ""
  puts "YALTY_OAUTH_ID=#{app.uid}"
  puts "YALTY_OAUTH_SECRET=#{app.secret}"
  puts "YALTY_OAUTH_REDIRECT_URI=#{app.redirect_uri}"
  puts "YALTY_OAUTH_SCOPES=#{app.scopes}"
end
