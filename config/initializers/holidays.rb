countries = Dir.glob("lib/custom_holidays/*.yml")

countries.map! { |holiday| Rails.root.join(holiday).to_s }

Holidays.load_custom(countries)
