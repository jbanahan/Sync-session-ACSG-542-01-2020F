RSpec::Matchers.define :be_same_second_as do |t|
  match do |time|
    if !time.nil? && !t.nil?
      time.to_i.eql?(t.to_i)
    else
      time.eql?(t)
    end
  end
end