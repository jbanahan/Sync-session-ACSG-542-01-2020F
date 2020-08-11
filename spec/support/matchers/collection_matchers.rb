# Make sure the give collection is sorted alphabetically by the given field
RSpec::Matchers.define :be_alphabetical_by do |field|
  match do |collection|
    ret = true
    last_val = nil
    collection.each do |c|
      v = c.send(field)
      ret = false if last_val && (last_val.upcase <=> v.upcase) > 0
      last_val = v
      break unless ret
    end
    ret
  end

  failure_message do |c|
    "expected collection #{c.to_s} to be in alphabetical order by #{field}"
  end
  failure_message_when_negated do |c|
    "expected collection #{c.to_s} not to be in alphabetical order by #{field}"
  end
end

RSpec::Matchers.define :be_alphabetical_descending_by do |field|
  match do |collection|
    ret = true
    last_val = nil
    collection.each do |c|
      v = c.send(field)
      ret = false if last_val && (last_val.upcase <=> v.upcase) < 0
      last_val = v
      break unless ret
    end
    ret
  end

  failure_message do |c|
    "expected collection #{c.to_s} to be in descending alphabetical order by #{field}"
  end
  failure_message_when_negated do |c|
    "expected collection #{c.to_s} not to be in descending alphabetical order by #{field}"
  end
end

RSpec::Matchers.define :be_length do |expected|
  match do |actual|
    actual.length == expected
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be length #{expected}, but was #{actual.length}"
  end
end

RSpec::Matchers.define :match_property do |expected, property|
  match do |actual|
    actual&.map(&property) == expected
  end

  failure_message do |actual|
    "expected #{actual.inspect} to contain #{expected} in #{property}"
  end
end