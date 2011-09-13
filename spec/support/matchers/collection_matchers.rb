#Make sure the give collection is sorted alphabetically by the given field
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

  failure_message_for_should do |c|
    "expected collection #{c.to_s} to be in alphabetical order by #{field}"
  end
  failure_message_for_should_not do |c|
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

  failure_message_for_should do |c|
    "expected collection #{c.to_s} to be in descending alphabetical order by #{field}"
  end
  failure_message_for_should_not do |c|
    "expected collection #{c.to_s} not to be in descending alphabetical order by #{field}"
  end
end
