require "rspec/expectations"

RSpec::Matchers.define :match_hash do |expected|
  @errors = nil

  match do |actual|
    @worked_actual = actual
    hash_or_array_of_hashes? && type_match? && length_match? && keys_and_values_match?
  end

  def keys_and_values_match?
    result = expected.is_a?(Hash) ? check_for_hash : check_for_array_of_hashes
    @errors = "keys and values do not match" unless result
    result
  end

  def compare_expected_hash(target_hash)
    results = find_target_keys(target_hash)
    return false unless results.uniq.size == 1 && results.uniq.first.size == target_hash.size
    @worked_actual = @worked_actual - results.uniq
    true
  end

  def find_target_keys(target_hash)
    target_hash.keys.map do |target_key|
      if target_hash[target_key].is_a?(Array)
        @worked_actual.find do |values|
          (values[:time_entries] & target_hash[:time_entries]).size ==
            target_hash[:time_entries].size
        end
      else
        @worked_actual.find { |values| values[target_key] == target_hash[target_key] }
      end
    end
  end

  def check_for_hash(expect = expected)
    expect.map do |key, value|
      actual.has_key?(key) && actual[key] == value ||
        (actual[key].is_a?(Array) && (actual[key] & value).size == value.size)
    end.exclude?(false)
  end

  def check_for_array_of_hashes
    expected.map do |single_expected|
      compare_expected_hash(single_expected.to_h)
    end.exclude?(false)
  end

  def length_match?
    result = (actual.is_a?(Hash) && actual.size == expected.size) ||
      actual.map(&:keys).flatten.size == expected.map(&:keys).flatten.size
    @errors = "length is not matching" unless result
    result
  end

  def type_match?
    @errors = "type is not matching" if expected.class != actual.class
    expected.class == actual.class
  end

  def hash_or_array_of_hashes?
    result = expected.is_a?(Hash) || is_array_of_hashes?
    @errors = "expected value must be a hash of array of hashes" unless result
    result
  end

  def is_array_of_hashes?(object = expected)
    object.is_a?(Array) && object.map { |exp| exp.is_a?(Hash) }.uniq == [true]
  end

  failure_message do |actual|
    "expected params to match json but #{@errors}
    expected #{expected}
    got #{actual}"
  end

  failure_message_when_negated do |actual|
    "expected params to not match json"
  end
end
