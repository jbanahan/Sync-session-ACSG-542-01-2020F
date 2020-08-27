RSpec::Matchers.define :be_same_second_as do |t|
  match do |time|
    if !time.nil? && !t.nil?
      time.to_i.eql?(t.to_i)
    else
      time.eql?(t)
    end
  end

  failure_message do |actual|
    "expected #{actual} to be the same second as #{t}"
  end
end