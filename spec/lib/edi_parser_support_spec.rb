require 'spec_helper'

describe OpenChain::EdiParserSupport do
  subject {
    Class.new { include OpenChain::EdiParserSupport }.new
  }

  let (:segments) {
    REX12::Document.read 'spec/support/bin/ascena_apll_856.txt'
  }

  describe "with_qualified_segments" do
    it "finds segments with a given value in the qualified field" do
      segs = []
      subject.with_qualified_segments(segments, "ST", 1, "856") { |s| segs << s}
      expect(segs.length).to eq 9
    end

    it "yields nothing if no values are found" do 
      segs = []
      subject.with_qualified_segments(segments, "ST", 1, "850") { |s| segs << s}
      expect(segs.length).to eq 0
    end
  end

  describe "find_elements_by_qualifier" do
    it "finds all segment values that have the given qualifier value" do
      # We're just pulling back the ST counter, so the values should be 001....009
      expect(subject.find_elements_by_qualifier(segments, "ST", "856", 1, 2)).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "skips values if value position is not present" do
      expect(subject.find_elements_by_qualifier(segments, "ST", "856", 1, 5)).to eq []
    end

    it "returns blank values if segment value is blank" do
      expect(subject.find_elements_by_qualifier(segments, "HL", "1", 1, 2)).to eq ["", "", "", "", "", "", "", "", ""]
    end
  end

  describe "find_segments_by_qualifier" do
    it "finds all segments that have the given qualifier value" do
      segs = subject.find_segments_by_qualifier(segments, "ST01", "856")
      expect(segs.length).to eq 9
      # THis is mostly just to ensure that the return value we get is as expected
      expect(segs.map {|s| s.elements[1].value }.uniq).to eq ["856"]
    end

    it "doesn't fail if edi position doesn't exist" do
      expect(subject.find_segments_by_qualifier(segments, "ST010", "856")).to eq []
    end
  end

  describe "find_values_by_qualifier" do
    it "finds all value elements relative to a qualifier, using default value index position 1 greater than qualifier coordinate" do
      # We're just pulling back the ST counter, so the values should be 001....009
      expect(subject.find_values_by_qualifier(segments, "ST01", "856")).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "finds all value elements relative to a qualifier, using explicit value index" do
      expect(subject.find_values_by_qualifier(segments, "ST01", "856", value_index: 1)).to eq 9.times.map {|v| "856" }
    end

    it "returns nothing if value index is bad" do
      expect(subject.find_values_by_qualifier(segments, "ST01", "856", value_index: 10)).to eq []
    end
  end

  describe "find_value_by_qualifier" do
    it "returns the first segment value that matches" do
      expect(subject.find_value_by_qualifier(segments, "REF01", "CR")).to eq "HK956641"
    end

    it "returns nil if nothing found" do
      expect(subject.find_value_by_qualifier(segments, "REF01", "CRTVQ")).to be_nil
    end
  end

  describe "find_ref_values" do
    it "returns all ref values that match" do
      expect(subject.find_ref_values(segments, "BM")).to eq ["XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007980", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990", "XM1007990"]
    end

    it "returns blank list if nothing found" do
      expect(subject.find_ref_values(segments, "BMNN")).to eq []
    end
  end

  describe "find_ref_value" do
    it "returns first matching value" do
      expect(subject.find_ref_value(segments, "BM")).to eq "XM1007980"
    end

    it "returns nil if nothing found" do
      expect(subject.find_ref_value(segments, "BMNN")).to be_nil
    end
  end

  describe "find_element_values" do
    it "finds all values described by the given coordinate" do
      expect(subject.find_element_values(segments, "ST02")).to eq (1..9).map {|v| v.to_s.rjust(4, '0') }
    end

    it "retuns blank array if nothign found" do
      expect(subject.find_element_values(segments, "ST09")).to eq []
    end
  end

  describe "find_element_value" do
    it "finds first value described by the given coordinate" do
      expect(subject.find_element_value(segments, "ST02")).to eq "0001"
    end

    it "retuns blank array if nothign found" do
      expect(subject.find_element_value(segments, "ST09")).to be_nil
    end
  end

  describe "find_date_values" do
    it "finds and parses DTM segments using default values" do
      dates = subject.find_date_values(segments, "311")
      expect(dates.length).to eq 9
      expect(dates.first).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using time_zone as string" do
      dates = subject.find_date_values(segments, "311", time_zone: "America/New_York")
      expect(dates.first).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using given date_format" do
      dates = subject.find_date_values(segments, "311", date_format: "%Y%m%d")
      expect(dates.first).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segments using given date format and given timezone" do 
      dates = subject.find_date_values(segments, "311", date_format: "%Y%m%d", time_zone: "America/New_York")
      expect(dates.first).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end
  end

  describe "find_date_value" do
    it "finds and parses DTM segment using default values" do
      expect(subject.find_date_value(segments, "311")).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using time_zone as string" do
      expect(subject.find_date_value(segments, "311", time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using given date_format" do
      expect(subject.find_date_value(segments, "311", date_format: "%Y%m%d")).to eq ActiveSupport::TimeZone["UTC"].parse("2016-11-18")
    end

    it "finds and parses DTM segment using given date format and given timezone" do 
      expect(subject.find_date_value(segments, "311", date_format: "%Y%m%d", time_zone: "America/New_York")).to eq ActiveSupport::TimeZone["America/New_York"].parse("2016-11-18")
    end
  end

  describe "parse_dtm_date_value" do
    # This test mostly exists to test values we don't have in EDI files (mainly ones with times in the values)
    it "parses a DTM value with a time" do
      expect(subject.parse_dtm_date_value("201701011230")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 12:30")
    end

    it "parses a DTM value using a defined format" do
      expect(subject.parse_dtm_date_value("201701011230", date_format: "%Y%m%d%H%M")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 12:30")
    end

    it "parses a DTM value using a defined format containing the timezone in it" do
      expect(subject.parse_dtm_date_value("201701011230-0500", date_format: "%Y%m%d%H%M%z")).to eq ActiveSupport::TimeZone["UTC"].parse("2017-01-01 17:30")
    end
  end

  describe "find_segments" do
    it "finds all segments matching the given segment type" do
      segs = subject.find_segments segments, "GS"
      expect(segs.length).to eq 1
      expect(segs.first.elements[0].value).to eq "GS"
    end

    it "finds all segments matching the given segment types" do
      segs = subject.find_segments segments, "GS", "GE"
      expect(segs.length).to eq 2
      expect(segs.first.elements[0].value).to eq "GS"
      expect(segs.second.elements[0].value).to eq "GE"
    end

    it "yields matching segments" do
      vals = []
      expect(subject.find_segments(segments, "GS") {|s| vals << s} ).to be_nil
      expect(vals.length).to eq 1
      expect(vals.first.elements[0].value).to eq "GS"
    end
  end

  describe "parse_edi_coordinate" do
    it "parses standard edi element descriptor into segment / index pair" do
      expect(subject.parse_edi_coordinate("BEG10")).to eq ["BEG", 10]
    end

    it "raises an error if bad coordinates are given" do
      expect { subject.parse_edi_coordinate("ABC") }.to raise_error ArgumentError, "Invalid EDI coordinate value received: 'ABC'."
    end
  end
end