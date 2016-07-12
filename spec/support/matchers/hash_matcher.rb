require 'rspec/expectations'

RSpec::Matchers.define :match_hash do |expected|
  @errors = nil

  match do |actual|
    hash_or_array_of_hashes? && type_match? && length_match? && keys_and_values_match?
  end

  def keys_and_values_match?
    result = expected.is_a?(Hash) ? compare_expected_hash : check_for_array_of_hashes
    @errors = 'keys and values do not match' unless result.exclude?(false)
    result.exclude?(false)
  end

  def compare_expected_hash(target_hash = expected)
    target_hash.map do |key, value|
      if actual.is_a?(Hash)
        actual.has_key?(key) && actual[key] == value
      else
        related = actual.select { |act| act[key] == value }.first
        related.values.map(&:class) == target_hash.values.map(&:class) &&
          convert_to_array_of_strings(related) == convert_to_array_of_strings(target_hash)
      end
    end
  end

  def convert_to_array_of_strings(hash)
    hash.to_a.flatten.map do |value|
      value.is_a?(Hash) ? value.to_a : value
    end.flatten.map(&:to_s).sort
  end

  def check_for_array_of_hashes
    expected.map do |single_expected|
      compare_expected_hash(single_expected.to_h)
    end
  end

  def length_match?
    result = (actual.is_a?(Hash) && actual.size == expected.size) ||
      actual.map(&:keys).flatten.size == expected.map(&:keys).flatten.size
    @errors = 'length is not matching' unless result
    result
  end

  def type_match?
    @errors = 'type is not matching' if expected.class != actual.class
    expected.class == actual.class
  end

  def hash_or_array_of_hashes?
    result = expected.is_a?(Hash) ||
      (expected.is_a?(Array) && expected.map { |exp| exp.is_a?(Hash) }.uniq == [true])
    @errors = 'expected value must be a hash of array of hashes' unless result
    result
  end

  failure_message do |actual|
    "expected params to match json but #{@errors}"
  end

  failure_message_when_negated do |actual|
    "expected params to not match json"
  end
end
