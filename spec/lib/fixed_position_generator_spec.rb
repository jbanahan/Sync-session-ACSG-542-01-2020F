require 'spec_helper'

describe OpenChain::FixedPositionGenerator do
 
  describe "str" do
    it "should right pad string" do
      expect(subject.str('x',3)).to eq 'x  '
    end
    it "should left pad string with flag set" do
      expect(subject.str('x',3,true)).to eq '  x'
    end
    it "should truncate string" do
      expect(subject.str('xyz',2)).to eq 'xy'
    end
    it "should raise exception on too long string with flag set" do
      expect{described_class.new(exception_on_truncate:true).str('xyz',2)}.
        to raise_error StandardError, "String 'xyz' is longer than 2 characters"
    end
    it "should handle nil as blank" do
      expect(subject.str(nil,2)).to eq '  '
    end
    it "should use pad_character" do
      expect(described_class.new(pad_char:'q').str('x',3)).to eq 'xqq'
    end
    it "should strip line breaks and repace with line_break_replace_char" do
      expect(described_class.new(line_break_replace_char:'r').str("x\r\ny\nz\r!",9)).to eq 'xryrzr!  '
    end
    it "encodes string to a different encoding" do
      p = described_class.new(string_output_encoding: "ASCII")
      out = p.str("value", 10)
      expect(out.encoding.name).to eq "US-ASCII"
    end
    it "uses ? as default encoding replacement value" do
      p = described_class.new(string_output_encoding: "ASCII")
      expect(p.str("¶", 1)).to eq "?"
    end
    it "allows changing encoding replacement char" do
      p = described_class.new(string_output_encoding: "ASCII", string_output_encoding_replacement_char: "!")
      expect(p.str("¶", 1)).to eq "!"
    end
  end

  describe "string" do
    it "should right pad string" do
      expect(subject.string('x',3)).to eq 'x  '
    end
    it "should left pad string with flag set" do
      expect(subject.string('x',3, justification: :right)).to eq '  x'
    end
    it "should truncate string" do
      expect(subject.string('xyz',2)).to eq 'xy'
    end
    it "should raise exception on too long string with flag set" do
      expect{described_class.new(exception_on_truncate:true).string('xyz',2)}.
        to raise_error StandardError, "String 'xyz' is longer than 2 characters"
    end
    it "should handle nil as blank" do
      expect(subject.string(nil,2)).to eq '  '
    end
    it "should use pad_character" do
      expect(described_class.new(pad_char:'q').string('x',3)).to eq 'xqq'
    end
    it "should strip line breaks and repace with line_break_replace_char" do
      expect(described_class.new(line_break_replace_char:'r').string("x\r\ny\nz\r!",9)).to eq 'xryrzr!  '
    end
    it "encodes string to a different encoding at class level" do
      p = described_class.new(string_output_encoding: "ASCII")
      out = p.string("value", 10)
      expect(out.encoding.name).to eq "US-ASCII"
    end
    it "encodes string to a different encoding at method level" do
      out = subject.string("value", 10, encoding: "ASCII")
      expect(out.encoding.name).to eq "US-ASCII"
    end
    it "encodes string to a different encoding at method level using an Encoding instance" do
      out = subject.string("value", 10, encoding: Encoding.find("ASCII"))
      expect(out.encoding.name).to eq "US-ASCII"
    end
    it "uses ? as default encoding replacement value" do
      p = described_class.new(string_output_encoding: "ASCII")
      expect(p.string("¶", 1)).to eq "?"
    end
    it "allows changing encoding replacement char at class level" do
      p = described_class.new(string_output_encoding: "ASCII", string_output_encoding_replacement_char: "!")
      expect(p.string("¶", 1)).to eq "!"
    end
    it "allows changing encoding replacement char at method level" do
      p = described_class.new(string_output_encoding: "ASCII")
      expect(p.string("¶", 1, encoding_replacment_char: "!")).to eq "!"
    end
    it "allows disabling padding" do
      expect(subject.string("a", 5, pad_string: false)).to eq "a"
    end
  end

  describe "num" do
    it "should include implied decimals on fixnum" do
      expect(subject.num(5,6,2)).to eq '  5.00'
    end
    it "should include decimals on bigdecimal" do
      expect(subject.num(BigDecimal('523.23'),6,2)).to eq '523.23'
    end
    it "should include right side decimals on bigdecimal" do
      expect(subject.num(BigDecimal('523.2'),6,2)).to eq '523.20'
    end
    it "should truncate too many decimals" do
      expect(subject.num(BigDecimal('523.27'),5,1)).to eq '523.3'
    end
    it "should round with round_mode" do
      expect(subject.num(BigDecimal('523.27'),5,1,round_mode:BigDecimal::ROUND_FLOOR)).to eq '523.2'
    end
    it "should raise exception on truncate regardless of exception_on_truncate flag" do
      expect{subject.num(5000,3,2)}.to raise_error StandardError, "Number 5000.00 doesn't fit in 3 character field"
    end
    it "raises exception on truncate with implied decimal readout" do
      expect{subject.num(5000,3,2, numeric_strip_decimals: true)}.to raise_error StandardError, "Number 500000 (2 implied decimals) doesn't fit in 3 character field"
    end
    it "accepts a different pad char as an option" do
      expect(subject.num(1, 6, 2, numeric_pad_char: '*')).to eq '**1.00'
    end
    it "uses a default constructor supplied pad char" do
      c = described_class.new numeric_pad_char: '*'
      expect(c.num(1, 6, 2)).to eq '**1.00'
    end
    it "accepts instruction to left justify" do
      expect(subject.num(5,6,2, numeric_left_align: true)).to eq '5.00  '
    end
    it "strips decimals" do
      expect(subject.num(5.2, 3, 2, numeric_strip_decimals: true)).to eq "520"
    end
    it "strips decimals if given in constructor" do
      g = described_class.new numeric_strip_decimals: true
      expect(g.num(5.2, 3, 2)).to eq "520"
    end
  end

  describe "number" do
    it "should include implied decimals on fixnum" do
      expect(subject.number(5,6, decimal_places: 2)).to eq '  5.00'
    end
    it "should include decimals on bigdecimal" do
      expect(subject.number(BigDecimal('523.23'),6, decimal_places: 2)).to eq '523.23'
    end
    it "should include right side decimals on bigdecimal" do
      expect(subject.number(BigDecimal('523.2'),6, decimal_places: 2)).to eq '523.20'
    end
    it "should truncate too many decimals" do
      expect(subject.number(BigDecimal('523.27'),5, decimal_places: 1)).to eq '523.3'
    end
    it "should round with round_mode" do
      expect(subject.number(BigDecimal('523.27'),5, decimal_places: 1, round_mode:BigDecimal::ROUND_FLOOR)).to eq '523.2'
    end
    it "should raise exception on truncate regardless of exception_on_truncate flag" do
      expect{subject.number(5000,3, decimal_places: 2)}.to raise_error StandardError, "Number 5000.00 doesn't fit in 3 character field"
    end
    it "raises exception on truncate with implied decimal readout" do
      expect{subject.number(5000,3, decimal_places: 2, strip_decimals: true)}.to raise_error StandardError, "Number 500000 (2 implied decimals) doesn't fit in 3 character field"
    end
    it "accepts a different pad char as an option" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: '*')).to eq '**1.00'
    end
    it "uses a default constructor supplied pad char" do
      c = described_class.new numeric_pad_char: '*'
      expect(c.number(1, 6, decimal_places: 2)).to eq '**1.00'
    end
    it "uses supplied pad char at method level" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: "*")).to eq '**1.00'
    end
    it "accepts instruction to left justify" do
      expect(subject.number(5,6, decimal_places: 2, justification: :left)).to eq '5.00  '
    end
    it "does not pad if instructed not to" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: "*", pad_string: false)).to eq '1.00'
    end
    it "strips decimals" do
      expect(subject.number(5.2, 3, decimal_places: 2, strip_decimals: true)).to eq "520"
    end
    it "strips decimals if given in constructor" do
      g = described_class.new numeric_strip_decimals: true
      expect(g.number(5.2, 3, decimal_places: 2)).to eq "520"
    end
  end
  describe "number" do
    it "should include implied decimals on fixnum" do
      expect(subject.number(5,6, decimal_places: 2)).to eq '  5.00'
    end
    it "should include decimals on bigdecimal" do
      expect(subject.number(BigDecimal('523.23'),6, decimal_places: 2)).to eq '523.23'
    end
    it "should include right side decimals on bigdecimal" do
      expect(subject.number(BigDecimal('523.2'),6, decimal_places: 2)).to eq '523.20'
    end
    it "should truncate too many decimals" do
      expect(subject.number(BigDecimal('523.27'),5, decimal_places: 1)).to eq '523.3'
    end
    it "should round with round_mode" do
      expect(subject.number(BigDecimal('523.27'),5, decimal_places: 1, round_mode:BigDecimal::ROUND_FLOOR)).to eq '523.2'
    end
    it "should raise exception on truncate regardless of exception_on_truncate flag" do
      expect{subject.number(5000,3, decimal_places: 2)}.to raise_error StandardError, "Number 5000.00 doesn't fit in 3 character field"
    end
    it "raises exception on truncate with implied decimal readout" do
      expect{subject.number(5000,3, decimal_places: 2, strip_decimals: true)}.to raise_error StandardError, "Number 500000 (2 implied decimals) doesn't fit in 3 character field"
    end
    it "accepts a different pad char as an option" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: '*')).to eq '**1.00'
    end
    it "uses a default constructor supplied pad char" do
      c = described_class.new numeric_pad_char: '*'
      expect(c.number(1, 6, decimal_places: 2)).to eq '**1.00'
    end
    it "uses supplied pad char at method level" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: "*")).to eq '**1.00'
    end
    it "accepts instruction to left justify" do
      expect(subject.number(5,6, decimal_places: 2, justification: :left)).to eq '5.00  '
    end
    it "does not pad if instructed not to" do
      expect(subject.number(1, 6, decimal_places: 2, pad_char: "*", pad_string: false)).to eq '1.00'
    end
    it "strips decimals" do
      expect(subject.number(5.2, 3, decimal_places: 2, strip_decimals: true)).to eq "520"
    end
    it "strips decimals if given in constructor" do
      g = described_class.new numeric_strip_decimals: true
      expect(g.number(5.2, 3, decimal_places: 2)).to eq "520"
    end
  end
  describe "date" do
    it "should handle nil" do
      expect(subject.date(nil)).to eq ''.ljust(8)
    end
    it "should use default date format" do
      expect(subject.date(Date.new(2014,1,31))).to eq '20140131'
    end
    it "should use constructor date format" do
      expect(described_class.new(date_format:'%Y').date(Date.new(2014,1,31))).to eq '2014'
    end
    it "should use override date format" do
      expect(subject.date(Date.new(2014,1,31),'%Y')).to eq '2014'
    end
    it "converts datetimes to specified timezone" do
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      expect(subject.date(d, nil, ActiveSupport::TimeZone["Hawaii"])).to eq '20141231'
    end
    it "converts datetimes to default Time.zone if no parameter or class opt specified" do
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      Time.use_zone("Hawaii") do
        expect(subject.date(d)).to eq '20141231'
      end
    end
    it "converts datetimes to timezone specified in class opts" do
      f = described_class.new output_timezone: "Hawaii"
      d = ActiveSupport::TimeZone["UTC"].parse("2015-01-01")
      expect(f.date(d)).to eq '20141231'
    end
  end
end
