require 'spec_helper'

describe OpenChain::XmlBuilder do
  before :all do
    @builder = Class.new { extend OpenChain::XmlBuilder }
  end

  describe "build_xml_document" do
    it "builds a document with a root element" do
      doc, root = @builder.build_xml_document "root"
      expect(root.name).to eq "root"
      expect(doc).to be_a REXML::Document
      #Not entirely sure how to test if the xml version is there or not based on Document, printing works fine
      expect(doc.to_s).to eq "<?xml version='1.0' encoding='UTF-8'?><root/>"
    end

    it "suppresses xml declaration" do
      doc, root = @builder.build_xml_document "root", suppress_xml_declaration: true
      expect(doc.to_s).to eq "<root/>"
    end
  end

  describe "add_element" do

    before :each do
      *, @root = @builder.build_xml_document "root"
    end

    it "adds a child element to a parent" do
      el = @builder.add_element @root, "child", "content"
      expect(el.name).to eq "child"
      expect(el.text).to eq "content"
    end

    it "adds blank elements by default" do
      el = @builder.add_element @root, "child", ""
      expect(el.text).to eq ""
    end

    it "skips blank elements if instructed" do
      expect(@builder.add_element @root, "child", nil, allow_blank: false).to be_nil
    end

    it "wraps content in cdata if instructed" do
      el = @builder.add_element @root, "child", "cdata", cdate: true
      expect(el.children.first).to eq REXML::CData.new("cdata")
    end
  end

  describe "add_collection_element" do
    before :each do
      *, @root = @builder.build_xml_document "root"
    end

    it "splits values apart and adds children/grandchildren to a parent" do
      child = @builder.add_collection_element @root, "Children", "Child", "Thing 1\n Thing 2"
      expect(child.children.size).to eq 2
      expect(REXML::XPath.each(@root, "Children/Child").collect {|v| v.text}).to eq ["Thing 1", "Thing 2"]
    end

    it "uses custom split expression" do
      child = @builder.add_collection_element @root, "Children", "Child", "Thing 1~Thing 2", split_expression: "~"
      expect(child.children.size).to eq 2
      expect(REXML::XPath.each(@root, "Children/Child").collect {|v| v.text}).to eq ["Thing 1", "Thing 2"]
    end

    it "uses custom regex split expression" do
      child = @builder.add_collection_element @root, "Children", "Child", "Thing 1 ~ Thing 2", split_expression: /\s~\s/
      expect(child.children.size).to eq 2
      expect(REXML::XPath.each(@root, "Children/Child").collect {|v| v.text}).to eq ["Thing 1", "Thing 2"]
    end

    it "skips blank elements" do
      child = @builder.add_collection_element @root, "Children", "Child", "Thing 1\n Thing 2\n \n "
      expect(child.children.size).to eq 2
      expect(REXML::XPath.each(@root, "Children/Child").collect {|v| v.text}).to eq ["Thing 1", "Thing 2"]
    end
  end

  describe "add_date_elements" do
    before :each do
      *, @root = @builder.build_xml_document "root"
    end

    it "adds date and time elements to parent" do
      date_el = @builder.add_date_elements @root, Date.new(2015, 1, 1)
      expect(date_el.name).to eq @root.name
      expect(date_el.text "Date").to eq "20150101"
      expect(date_el.text "Time").to eq "0000"
    end

    it "adds datetime to parent" do
      date_el = @builder.add_date_elements @root, DateTime.new(2015, 1, 1, 12, 15)
      expect(date_el.text "Date").to eq "20150101"
      expect(date_el.text "Time").to eq "1215"
    end

    it "adds date and time elements to parent, prefixing children" do
      date_el = @builder.add_date_elements @root, Date.new(2015, 1, 1), element_prefix: "Some"
      expect(date_el.text "SomeDate").to eq "20150101"
      expect(date_el.text "SomeTime").to eq "0000"
    end

    it "accepts custom date/time formats" do
      date_el = @builder.add_date_elements @root, DateTime.new(2015, 1, 1, 12, 15), date_format: "%Y-%m-%d", time_format: "%H:%M"
      expect(date_el.text "Date").to eq "2015-01-01"
      expect(date_el.text "Time").to eq "12:15"
    end

    it "adds date and time elements to parent creating child element" do
      date_el = @builder.add_date_elements @root, Date.new(2015, 1, 1), child_element_name: "MyDate"
      expect(date_el.name).to eq "MyDate"
      expect(date_el.text "Date").to eq "20150101"
      expect(date_el.text "Time").to eq "0000"
    end

    it "reuses child element if it already exists" do
      child = @builder.add_element @root, "Child"

      date_el = @builder.add_date_elements @root, Date.new(2015, 1, 1), child_element_name: "Child"
      expect(date_el).to eq child
      expect(date_el.text "Date").to eq "20150101"
      expect(date_el.text "Time").to eq "0000"
    end
  end

  describe "add_entity_address_info" do
    before :each do
      *, @root = @builder.build_xml_document "root"
    end

    it "adds address info to parent" do
      add = @builder.add_entity_address_info @root, "Entity", name: "EntityName", id: "EntityId", address_1: "Add1", address_2: "Add2", city: "AI", state: "St", zip: "123", country: "US"
      expect(add.name).to eq "Entity"
      expect(add.text "Name").to eq "EntityName"
      expect(add.text "Id").to eq "EntityId"
      expect(add.text "Address1").to eq "Add1"
      expect(add.text "Address2").to eq "Add2"
      expect(add.text "City").to eq "AI"
      expect(add.text "State").to eq "St"
      expect(add.text "Zip").to eq "123"
      expect(add.text "Country").to eq "US"
    end
  end
end