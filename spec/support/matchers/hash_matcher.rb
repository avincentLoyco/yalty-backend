require 'rspec/expectations'

RSpec::Matchers.define :match_hash do |expected|
  @errors = nil

  match do |actual|
    @values_array = actual.is_a?(Array) ? actual.map { |a| a.values + a.keys }.flatten : nil
    hash_or_array_of_hashes? && type_match? && length_match? && keys_and_values_match?
  end

  def keys_and_values_match?
    result = expected.is_a?(Hash) ? compare_expected_hash : check_for_array_of_hashes
    @errors = 'keys and values do not match' unless result
    result
  end

  def compare_expected_hash(target_hash = expected)
    target_hash.map do |key, value|
      if actual.is_a?(Hash)
        actual.has_key?(key) && actual[key] == value
      else
        [value, key].flatten.map do |v|
          index = @values_array.find_index(v)
          return false unless index
          @values_array.delete_at(index)
          true
        end
      end
    end.flatten
  end

  def check_for_array_of_hashes
    expected.map do |single_expected|
      compare_expected_hash(single_expected.to_h)
    end.exclude?(false) && @values_array.blank?
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
    result = expected.is_a?(Hash) || is_array_of_hashes?
    @errors = 'expected value must be a hash of array of hashes' unless result
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
