DBQueryMatchers.configure do |config|
  config.ignores = [/SHOW TABLES LIKE/]
  config.schemaless = true
end
