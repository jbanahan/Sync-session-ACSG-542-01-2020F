RSpec::Matchers.define :have_snapshot do |user, context|
  match do |obj|
    Array.wrap(obj.entity_snapshots).each do |s|
      return true if s.user == user && s.context == context
    end

    return false
  end

  failure_message do |actual|
    "expected that #{actual.inspect} would have a snapshot with the user '#{user.username}' and context '#{context}'"
  end

  failure_message_when_negated do |actual|
    "expected that #{actual.inspect} would not have a snapshot with the user '#{user.username}' and context '#{context}'"
  end
end

RSpec::Matchers.define :have_a_snapshot do
  match do |obj|
    return Array.wrap(obj.entity_snapshots).length > 0
  end

  description do
    "have a snapshot"
  end
end