RSpec::Matchers.define :have_system_identifier do |system, code|
  match do |company|
    !company.system_identifiers.find {|id| id.system == system && id.code == code }.nil?
  end

  failure_message do |actual|
    id = actual.system_identifiers.find {|i| i.system == system }
    if id.nil?
      "expected Company to have system identifier with system of #{system} and code of #{code}."
    else
      "expected Company to have system identifier with system of #{system} and code of #{code}, but identifier had a code of #{id.code}."
    end
    
  end

  failure_message_when_negated do |actual|

    "expected Company not to have system identifier with system of #{system} and code of #{code}."
  end
end