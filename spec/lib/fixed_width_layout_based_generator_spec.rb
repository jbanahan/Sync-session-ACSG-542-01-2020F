describe OpenChain::FixedWidthLayoutBasedGenerator do

  class FakeFixedWidthLayoutBasedGenerator
    include OpenChain::FixedWidthLayoutBasedGenerator

    def initialize mappings
      @mappings = mappings
    end

    def output_mapping_for name
      @mappings[name]
    end

  end

  describe "write_line" do

    let (:output) {
      StringIO.new
    }

    let (:simple_object) {
      s = Struct.new(:string_field, :date_field, :datetime_field, :decimal_field, :integer_field)
      s.new "String", Date.new(2018, 9, 1), Time.zone.parse("2018-09-01 12:34:56"), BigDecimal("15.50"), 100
    }

    let (:simple_map) {
      {
        string_field: lambda {|o| o.string_field },
        date_field: lambda {|o| o.date_field },
        datetime_field: lambda {|o| o.datetime_field },
        decimal_field: lambda {|o| o.decimal_field },
        integer_field: lambda {|o| o.integer_field }, 
        object_field: lambda {|o| o }
      }
    }

    subject { FakeFixedWidthLayoutBasedGenerator.new({map_name: simple_map}) }

    def make_layout map_name, fields
      {
        map_name: map_name,
        fields: Array.wrap(fields)
      }
    end

    def single_layout field
      make_layout :map_name, field
    end

    def expect_output value
      output.rewind
      expect(output.read).to eq value
    end

    context "with string field" do

      it "outputs a simple string field" do
        subject.write_line output, single_layout({field: :string_field, length: 10, datatype: :string}), simple_object
        expect_output("String    ")
      end

      it "trims if string is too long" do
        subject.write_line output, single_layout({field: :string_field, length: 2, datatype: :string}), simple_object
        expect_output("St")
      end

      it "passes through format params to fixed position generator method" do
        # If the justification / pad char comes through then we can assume all format values are passed through
        subject.write_line output, single_layout({field: :string_field, length: 10, datatype: :string, format: {justification: :right, pad_char: "-"}}), simple_object
        expect_output("----String")
      end

      it "autodetects string datatype" do
        subject.write_line output, single_layout({field: :string_field, length: 10}), simple_object
        expect_output("String    ")
      end

      it "autodetects nil as String" do
        simple_object.string_field = nil
        subject.write_line output, single_layout({field: :string_field, length: 10}), simple_object
        expect_output("          ")
      end

      it "strips newlines" do
        simple_object.string_field = "test\r\ntest"
        subject.write_line output, single_layout({field: :string_field, length: 10, datatype: :string}), simple_object
        expect_output("test test ")
      end
    end

    context "with decimal_field" do
      it "outputs a simple decimal field" do
        subject.write_line output, single_layout({field: :decimal_field, length: 10, datatype: :decimal}), simple_object
        expect_output("     15.50")
      end

      it "rounds values have more than 2 decimal places by default" do
        simple_object.decimal_field = BigDecimal("1.235")
        subject.write_line output, single_layout({field: :decimal_field, length: 10, datatype: :decimal}), simple_object
        expect_output("      1.24")
      end

      it "errors on value truncation" do
        expect {subject.write_line output, single_layout({field: :decimal_field, length: 2, datatype: :decimal}), simple_object}.to raise_error OpenChain::FixedPositionGenerator::DataTruncationError
      end

      it "passes through format params to fixed position generator method" do
        # If the justification / pad char comes through then we can assume all format values are passed through
        subject.write_line output, single_layout({field: :decimal_field, length: 10, datatype: :decimal, format: {justification: :left, pad_char: "-"}}), simple_object
        expect_output("15.50-----")
      end

      it "autodetects decimal datatype with BigDecimal" do
        subject.write_line output, single_layout({field: :decimal_field, length: 10}), simple_object
        expect_output("     15.50")
      end

      it "autodetects decimal datatype with float" do
        simple_object.decimal_field = 15.5
        subject.write_line output, single_layout({field: :decimal_field, length: 10}), simple_object
        expect_output("     15.50")
      end
    end

    context "with integer field" do
      it "outputs a simple ingeger field" do
        subject.write_line output, single_layout({field: :integer_field, length: 10, datatype: :integer}), simple_object
        expect_output("       100")
      end

      it "rounds non-integer values" do
        subject.write_line output, single_layout({field: :decimal_field, length: 10, datatype: :integer}), simple_object
        expect_output("        16")
      end

      it "errors on value truncation" do
        expect {subject.write_line output, single_layout({field: :integer_field, length: 1, datatype: :integer}), simple_object}.to raise_error OpenChain::FixedPositionGenerator::DataTruncationError
      end

      it "passes through format params to fixed position generator method" do
        # If the justification / pad char comes through then we can assume all format values are passed through
        subject.write_line output, single_layout({field: :integer_field, length: 10, datatype: :integer, format: {justification: :left, pad_char: "-"}}), simple_object
        expect_output("100-------")
      end

      it "autodetects integer datatype" do
        subject.write_line output, single_layout({field: :integer_field, length: 10}), simple_object
        expect_output("       100")
      end
    end

    context "with date field" do
      it "outputs a simple date field" do
        subject.write_line output, single_layout({field: :date_field, length: 12, datatype: :date}), simple_object
        expect_output("    20180901")
      end

      it "passes through format params to fixed position generator method" do
        # If the justification / pad char comes through then we can assume all format values are passed through
        subject.write_line output, single_layout({field: :date_field, length: 12, datatype: :date, format: {justification: :left, pad_char: "-"}}), simple_object
        expect_output("20180901----")
      end

      it "autodetects date datatype" do
        subject.write_line output, single_layout({field: :date_field, length: 10}), simple_object
        expect_output("  20180901")
      end
    end

    context "with datetime field" do
      it "outputs a simple date field" do
        subject.write_line output, single_layout({field: :datetime_field, length: 15, datatype: :datetime}), simple_object
        expect_output(" 20180901123456")
      end

      it "passes through format params to fixed position generator method" do
        # If the justification / pad char comes through then we can assume all format values are passed through
        subject.write_line output, single_layout({field: :datetime_field, length: 15, datatype: :datetime, format: {justification: :left, pad_char: "-"}}), simple_object
        expect_output("20180901123456-")
      end

      it "autodetects datetime datatype with TimeWithZone objects" do
        subject.write_line output, single_layout({field: :datetime_field, length: 15}), simple_object
        expect_output(" 20180901123456")
      end

      it "autodetects datetime datatype with DateTime objects" do
        simple_object.datetime_field = DateTime.new(2018,9,1,12,34,56)
        subject.write_line output, single_layout({field: :datetime_field, length: 15}), simple_object
        expect_output(" 20180901123456")
      end
    end
    
    context "with multi-field line" do
      it "outputs multiple fields onto a single line" do
        layout = make_layout(:map_name, [
          {field: :string_field, length: 10},
          {field: :decimal_field, length: 10},
          {field: :integer_field, length: 10},
          {field: :date_field, length: 10},
          {field: :datetime_field, length: 15}
        ])

        subject.write_line output, layout, simple_object
        output.rewind
        o = output.read
        expect(o[0, 10]).to eq "String    "
        expect(o[10, 10]).to eq "     15.50"
        expect(o[20, 10]).to eq "       100"
        expect(o[30, 10]).to eq "  20180901"
        expect(o[40, 15]).to eq " 20180901123456"
      end
      
      it "handles sub-formats" do
        layout = make_layout(:map_name, [
          {field: :object_field, sub_layout: 
            make_layout(:sub_map, [
              {field: :string_field, length: 10}
            ])
          },
          {field: :integer_field, length: 5}
        ])

        g = FakeFixedWidthLayoutBasedGenerator.new({map_name: simple_map, sub_map: simple_map})

        g.write_line output, layout, simple_object
        output.rewind
        o = output.read
        expect(o[0, 10]).to eq "String    "
        expect(o[10, 15]).to eq "  100"
      end
    end
  end
end