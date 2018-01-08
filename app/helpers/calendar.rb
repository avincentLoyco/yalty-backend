module Calendar
  def self.days_in_a_year(date)
    Date.gregorian_leap?(date.year) ? 366 : 365
  end

  def self.number_of_days_until_end_of_year(date)
    (Date.new(date.year, 12, 31) - date + 1).to_i
  end
end
