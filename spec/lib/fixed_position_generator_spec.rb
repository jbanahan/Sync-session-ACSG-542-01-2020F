require 'spec_helper'

describe OpenChain::FixedPositionGenerator do
  before :each do
    @f = described_class.new
  end
  describe :str do
    it "should right pad string" do
      expect(@f.str('x',3)).to eq 'x  '
    end
    it "should left pad string with flag set" do
      expect(@f.str('x',3,true)).to eq '  x'
    end
    it "should truncate string" do
      expect(@f.str('xyz',2)).to eq 'xy'
    end
    it "should raise exception on too long string with flag set" do
      expect{described_class.new(exception_on_truncate:true).str('xyz',2)}.
        to raise_error StandardError, "String 'xyz' is longer than 2 characters"
    end
    it "should handle nil as blank" do
      expect(@f.str(nil,2)).to eq '  '
    end
    it "should use pad_character" do
      expect(described_class.new(pad_char:'q').str('x',3)).to eq 'xqq'
    end
    it "should strip line breaks and repace with line_break_replace_char" do
      expect(described_class.new(line_break_replace_char:'r').str("x\r\ny\nz\r!",9)).to eq 'xryrzr!  '
    end
  end
  describe :num do
    it "should include implied decimals on fixnum" do
      expect(@f.num(5,6,2)).to eq '000500'
    end
    it "should include decimals on bigdecimal" do
      expect(@f.num(BigDecimal('523.23'),6,2)).to eq '052323'
    end
    it "should include right side decimals on bigdecimal" do
      expect(@f.num(BigDecimal('523.2'),6,2)).to eq '052320'
    end
    it "should truncate too many decimals" do
      expect(@f.num(BigDecimal('523.27'),5,1)).to eq '05233'
    end
    it "should round with round_mode" do
      expect(@f.num(BigDecimal('523.27'),5,1,round_mode:BigDecimal::ROUND_FLOOR)).to eq '05232'
    end
    it "should raise exception on truncate regardless of exception_on_truncate flag" do
      expect{@f.num(5000,3,2)}.to raise_error StandardError, "Number 500000 (2 implied decimals) doesn't fit in 3 character field"
    end
  end
  describe :date do
    it "should handle nil" do
      expect(@f.date(nil)).to eq ''.ljust(8)
    end
    it "should use default date format" do
      expect(@f.date(Date.new(2014,1,31))).to eq '20140131'
    end
    it "should use constructor date format" do
      expect(described_class.new(date_format:'%Y').date(Date.new(2014,1,31))).to eq '2014'
    end
    it "should use override date format" do
      expect(@f.date(Date.new(2014,1,31),'%Y')).to eq '2014'
    end
    it "converts datetimes to specified timezone" do
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      expect(@f.date(d, nil, ActiveSupport::TimeZone["Hawaii"])).to eq '20141231'
    end
    it "converts datetimes to default Time.zone if no parameter or class opt specified" do
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      Time.use_zone("Hawaii") do
        expect(@f.date(d)).to eq '20141231'
      end
    end
    it "converts datetimes to timezone specified in class opts" do
      f = described_class.new output_timezone: "Hawaii"
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      expect(f.date(d)).to eq '20141231'
    end
  end
end
