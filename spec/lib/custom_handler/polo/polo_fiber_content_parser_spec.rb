require 'spec_helper'

describe OpenChain::CustomHandler::Polo::PoloFiberContentParser do

  before :each do
    @p = described_class.new
  end

  describe "parse_fiber_content" do
    context "valid fibers" do
      before :each do
        # We're going to allow every fabric utilized in this context to be valid, this 
        # saves us having to create datacrossreference objects for every test
        @validated_fabrics = Set.new ['Cotton', 'Spandex']
        # Stub the include? method so that any value passed to it is considered valid
        allow(@validated_fabrics).to receive(:include?).and_return true
        allow(@p).to receive(:all_validated_fabrics).and_return @validated_fabrics
      end

      it "parses simple X% Fiber content" do
        expect(@p.parse_fiber_content "100% Cotton").to eq ({fiber_1: "Cotton", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple percentages (with decimals)" do
        expect(@p.parse_fiber_content "78.5% COTTON 17.5% NYLON 4% ELASTANE").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "78.5", fiber_2: "NYLON", type_2: "Outer", percent_2: "17.5", fiber_3: "ELASTANE", type_3: "Outer", percent_3: "4"})
      end

      it "parses multiple percentages with punctuation" do
        expect(@p.parse_fiber_content "78% COTTON / 18% NYLON/4% ELASTANE").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "78", fiber_2: "NYLON", type_2: "Outer", percent_2: "18", fiber_3: "ELASTANE", type_3: "Outer", percent_3: "4"})
      end

      it "parses multiple percentages without spacing" do
        expect(@p.parse_fiber_content "49%MOHAIR27%CASHMERE12%SILK12%WOOL").to eq ({fiber_1: "MOHAIR", type_1: "Outer", percent_1: "49", fiber_2: "CASHMERE", type_2: "Outer", percent_2: "27", fiber_3: "SILK", type_3: "Outer", percent_3: "12", fiber_4: "WOOL", type_4: "Outer", percent_4: "12"})
      end

      it "parses multiple percentages with hyphenation between" do
        expect(@p.parse_fiber_content "97%cotton-3%elastan").to eq ({fiber_1: "cotton", type_1: "Outer", percent_1: "97", fiber_2: "elastan", type_2: "Outer", percent_2: "3"})
      end

      it "parses multiple percentages with commas between" do
        expect(@p.parse_fiber_content "70% CASHMERE, 30% SILK").to eq ({fiber_1: "CASHMERE", type_1: "Outer", percent_1: "70", fiber_2: "SILK", type_2: "Outer", percent_2: "30"})
      end

      it "skips leading EST in fiber contents" do
        expect(@p.parse_fiber_content "EST. 74% COTTON 26% WOOL").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "74", fiber_2: "WOOL", type_2: "Outer", percent_2: "26"})
      end

      it "handles spacing between number and percent and stripping & in fabric contents" do
        expect(@p.parse_fiber_content "46% Acrylic / 24 % polyester / 17% wool / 8% silk & 5 % other.").to eq ({fiber_1: "Acrylic", type_1: "Outer", percent_1: "46", fiber_2: "polyester", type_2: "Outer", percent_2: "24", fiber_3: "wool", type_3: "Outer", percent_3: "17", fiber_4: "silk", type_4: "Outer", percent_4: "8", fiber_5: "other", type_5: "Outer", percent_5: "5"})
      end

      it "parses single word fiber content" do
        expect(@p.parse_fiber_content "Alligator").to eq ({fiber_1: "Alligator", type_1: "Outer", percent_1: "100"})
      end

      it "parses fiber content without percentages" do
        expect(@p.parse_fiber_content "90 COTTON 10 SPANDEX").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "90", fiber_2: "SPANDEX", type_2: "Outer", percent_2: "10"})
      end

      it "parses fiber content w/ x/y fiber1/fiber2 splits" do
        expect(@p.parse_fiber_content "90/10 COTTON/SPANDEX").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "90", fiber_2: "SPANDEX", type_2: "Outer", percent_2: "10"})
      end

      it "parses fiber content like x%/y% fiber1/fiber2" do
        expect(@p.parse_fiber_content "90% / 10 % COTTON / SPANDEX").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "90", fiber_2: "SPANDEX", type_2: "Outer", percent_2: "10"})
      end

      it "parses simple footwear fiber content" do
        expect(@p.parse_fiber_content "CANVAS UPPER / LEATHER OUTSOLE").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100", fiber_2: "LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses mispelled upper as uper" do
        expect(@p.parse_fiber_content "CANVAS UPER / LEATHER OUTSOLE").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100", fiber_2: "LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses leader upper as uper" do
        expect(@p.parse_fiber_content "UPER: CANVAS / OUTSOLE: LEATHER").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100", fiber_2: "LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses mispelled upper as upppper" do
        expect(@p.parse_fiber_content "CANVAS UPPPER / LEATHER OUTSOLE").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100", fiber_2: "LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses leader upper as uper" do
        expect(@p.parse_fiber_content "UPPPER: CANVAS / OUTSOLE: LEATHER").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100", fiber_2: "LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses multi-line leading upper footwear" do
        expect(@p.parse_fiber_content "UPPER - 100% COW LEATHER\nOUTSOLE - 100% COW LEATHER").to eq ({fiber_1: "COW LEATHER", type_1: "Outer", percent_1: "100", fiber_2: "COW LEATHER", type_2: "Sole", percent_2: "100"})
      end

      it "parses footwear fiber content with multiple components for each type" do
        expect(@p.parse_fiber_content "95% COTTON +5% LEATHER Upper / 45.8% RUBBER + 54.2% FABRIC Outsole").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "95", fiber_2: "LEATHER", type_2: "Outer", percent_2: "5", fiber_3: "RUBBER", type_3: "Sole", percent_3: "45.8", fiber_4: "FABRIC", type_4: "Sole", percent_4: "54.2"})
      end

      it "parses footwear with no space after uppers" do
        expect(@p.parse_fiber_content "100%synthetic  Uppers100% rubber  Outsoles").to eq ({fiber_1: "synthetic", type_1: "Outer", percent_1: "100", fiber_2: "rubber", type_2: "Sole", percent_2: "100"})
      end

      it "parses footwear fiber content with conjunctions in them" do
        expect(@p.parse_fiber_content "62% Cotton 38% PU Uppers and 100% Polyester Outsole").to eq ({fiber_1: "Cotton", type_1: "Outer", percent_1: "62", fiber_2: "PU", type_2: "Outer", percent_2: "38", fiber_3: "Polyester", type_3: "Sole", percent_3: "100"})
      end

      it "handles sole in place of outsole" do
        expect(@p.parse_fiber_content "NYLON UPPER / ESO SOLE").to eq ({fiber_1: "NYLON", type_1: "Outer", percent_1: "100", fiber_2: "ESO", type_2: "Sole", percent_2: "100"})
      end

      it "handles comments in footwear" do
        expect(@p.parse_fiber_content "NYLON UPPER / ESO SOLE\nHAS FOXING, SLIP-ON STYLE").to eq ({fiber_1: "NYLON", type_1: "Outer", percent_1: "100", fiber_2: "ESO", type_2: "Sole", percent_2: "100"})
      end

      it "handles footwear with leading component descriptors" do
        expect(@p.parse_fiber_content "Uppers:   55%polyester/45%PU   Outsoles: 100%polyester").to eq ({fiber_1: "polyester", type_1: "Outer", percent_1: "55", fiber_2: "PU", type_2: "Outer", percent_2: "45",  fiber_3: "polyester", type_3: "Sole", percent_3: "100"})
      end

      it "only uses first in series of fiber components" do
        expect(@p.parse_fiber_content "Teak wood, Saddle Leather (RL Standard), Natural Leather, Polished Nickel hardware, Saddle Poly Suede").to eq ({fiber_1: "Teak wood", type_1: "Outer", percent_1: "100"})
      end

      it "retrieves only the first 100% of a type (skipping leading comments)" do
        expect(@p.parse_fiber_content "WAXED TWILL - 100% cotton w/ 100% cowhide leather trim").to eq ({fiber_1: "cotton", type_1: "Outer", percent_1: "100"})
      end

      it "retrieves only the first 100% of a type (skipping trailing comments)" do
        expect(@p.parse_fiber_content "100% COTTON + 100% RAYON ( EST 56% COTTON 44% VISCOSE )").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "handles multi-line standard fiber layouts" do
        expect(@p.parse_fiber_content "78% COTTON\n18% NYLON\n4% ELASTANE").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "78", fiber_2: "NYLON", type_2: "Outer", percent_2: "18", fiber_3: "ELASTANE", type_3: "Outer", percent_3: "4"})
      end

      it "handles multi-line fiber layouts with multiple components" do
        expect(@p.parse_fiber_content "100% cotton webbing\n+100% Jute webbing\nwith genuine leather").to eq ({fiber_1: "cotton webbing", type_1: "Outer", percent_1: "100"})
      end

      it "handles multi-line fiber layoutes with multiple components having different percentages" do
        expect(@p.parse_fiber_content "100% cotton webbing\n+(60%cotton/40%elastic) elastic webbing").to eq ({fiber_1: "cotton webbing", type_1: "Outer", percent_1: "100"})
      end

      it "handles multiple components" do
        expect(@p.parse_fiber_content "Shell: 100% Goat Suede Lining: 100% Acetate").to eq ({fiber_1: "Goat Suede", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple lines with unlisted components (using first result)" do
        expect(@p.parse_fiber_content "MESH 100% COTTON\nINTERLOCK 100% COTTON\nJERSEY 100% COTTON\nRIB 100% COTTON").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple components with trailing punctuation" do
        expect(@p.parse_fiber_content "STRAP: 100% ALLIGATOR LEATHER; LINING: 100% COWHIDE LEATHER").to eq ({fiber_1: "ALLIGATOR LEATHER", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple componets with indicators across multiple lines" do
        expect(@p.parse_fiber_content "SHELL: 100% SILK\nLINING:\n100% POLYESTER").to eq ({fiber_1: "SILK", type_1: "Outer", percent_1: "100"})
      end

      it "handles multiple components lines with leading numeric comments" do
        expect(@p.parse_fiber_content "IC#521181\nShell: 100% Goat Suede\nLining: 100% Acetate").to eq ({fiber_1: "Goat Suede", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple components with multiple 100% fabrics per component" do
        expect(@p.parse_fiber_content "Shell: Face - 100% Cotton, Back - 100% Polyurethane lamination Sleeve lining: 100% Polyester").to eq ({fiber_1: "Cotton", type_1: "Outer", percent_1: "100"})
      end

      it "parses multiple components pulling first 100% of an item" do
        expect(@p.parse_fiber_content "Ticketing - 70% wool 30% cashmere - Insert 95% grey duck feather, 5% grey duck down").to eq ({fiber_1: "wool", type_1: "Outer", percent_1: "70", fiber_2: "cashmere", type_2: "Outer", percent_2: "30"})
      end

      it "strips leading EST.:" do
        expect(@p.parse_fiber_content "EST.: COTTON").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "strips 'exclusive of X'" do
        expect(@p.parse_fiber_content "100% COTTON'Exclusive Of Decoration'").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything include and after 'with'" do
        expect(@p.parse_fiber_content "100% CANVAS WITH COW LEATHER TRIM").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything include and after 'and'" do
        expect(@p.parse_fiber_content "100% CANVAS AND COW LEATHER TRIM").to eq ({fiber_1: "CANVAS", type_1: "Outer", percent_1: "100"})
      end

      it "ignores leading numbers if numbers elsewhere have percentage" do
        expect(@p.parse_fiber_content "40/2 100% COTTON YD").to eq ({fiber_1: "COTTON YD", type_1: "Outer", percent_1: "100"})
      end

      it "ignores leading IC# Comments" do
        expect(@p.parse_fiber_content "IC#521181 95%Cotton 5%Elastane").to eq ({fiber_1: "Cotton", type_1: "Outer", percent_1: "95", fiber_2: "Elastane", type_2: "Outer", percent_2: "5"})
      end

      it "ignores trailing dimensions" do
        expect(@p.parse_fiber_content "100% COTTON\n40x40, 110x70").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything after a /" do
        expect(@p.parse_fiber_content "100% mulberry silk / Woven Cami: 100% Silk").to eq ({fiber_1: "mulberry silk", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything after a (" do
        expect(@p.parse_fiber_content "100% WOOL (side knitted by 1END)").to eq ({fiber_1: "WOOL", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything after an &" do
        expect(@p.parse_fiber_content "100% MULBERRY SILK & SLIP 100% SILK").to eq ({fiber_1: "MULBERRY SILK", type_1: "Outer", percent_1: "100"})
      end

      it "strips anything after an ' - '" do
        expect(@p.parse_fiber_content "100% MULBERRY SILK - SLIP 100% SILK").to eq ({fiber_1: "MULBERRY SILK", type_1: "Outer", percent_1: "100"})
      end

      it "normalizes multiple consecutive whitespace characters into to a sinlge space" do
        expect(@p.parse_fiber_content "100% MULBERRY\t\t\tSILK   SLIP 100% SILK").to eq ({fiber_1: "MULBERRY SILK SLIP", type_1: "Outer", percent_1: "100"})
      end

      it "uses an xref on fiber content with initial description" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_FABRIC_XREF, key: "wool (w/ stuff)", value: "XREF"
        expect(@p.parse_fiber_content "100% WOOL (w/ stuff)").to eq ({fiber_1: "XREF", type_1: "Outer", percent_1: "100"})
      end
      
      it "uses an xref on fiber content with cleaned up description" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_FABRIC_XREF, key: "wool", value: "XREF"
        expect(@p.parse_fiber_content "100% WOOL").to eq ({fiber_1: "XREF", type_1: "Outer", percent_1: "100"})
      end

      it "handles commas in place of decimal points in content percentages" do
        expect(@p.parse_fiber_content "78,5% COTTON 21,5% NYLON").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "78.5", fiber_2: "NYLON", type_2: "Outer", percent_2: "21.5"})
      end

      it "handles descriptions without spaces" do
        expect(@p.parse_fiber_content "78.5%COTTON21.5%NYLON").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "78.5", fiber_2: "NYLON", type_2: "Outer", percent_2: "21.5"})
      end

      it "strips leading/trailing spaces from xref keys/values" do
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_FABRIC_XREF, key: "   wool   ", value: "   XREF   "
        expect(@p.parse_fiber_content "100% WOOL").to eq ({fiber_1: "XREF", type_1: "Outer", percent_1: "100"})
      end
    end

    context "uses cross reference validated fibric list" do
      it "strips leading/trailing spaces from valid fiber list keys" do
        DataCrossReference.create! key: "   Cotton    ", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
        expect(@p.parse_fiber_content "100% COTTON").to eq ({fiber_1: "COTTON", type_1: "Outer", percent_1: "100"})
      end

      it "handles mismatched spacing between xref and valid list" do
        DataCrossReference.create! key: "   Cotton    ", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
        DataCrossReference.create! cross_reference_type: DataCrossReference::RL_FABRIC_XREF, key: "   wool   ", value: " Cotton "
        expect(@p.parse_fiber_content "100% wool").to eq ({fiber_1: "Cotton", type_1: "Outer", percent_1: "100"})
      end
    end

    context "with invalid fiber descriptions" do
      before :each do
        DataCrossReference.create! key: "Cotton", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      end

      it "raises parse error when percentages trail the fiber" do
        begin 
          @p.parse_fiber_content "ZINC 60%,  STEEL 10%              Cotton 30%"
          fail("Should have raised error.")
        rescue OpenChain::CustomHandler::Polo::PoloFiberContentParser::FiberParseError => e
          expect(e.message).to eq "Failed: Invalid Fiber Content % format."
          expect(e.parse_results).to eq ({fiber_1: "", type_1: "Outer", percent_1: "60", percent_2: "10", fiber_2: "Cotton", type_2: "Outer"})
        end
      end

      it "raises parse error for unusable fiber description" do
        expect {@p.parse_fiber_content "30/1'S COTTON MINI PIQUE"}.to raise_error OpenChain::CustomHandler::Polo::PoloFiberContentParser::FiberParseError, "Failed: Invalid Fiber Content % format."
      end

      it "raises an error when more than 100% of a fiber content is found" do
        DataCrossReference.create! key: "Wool", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
        expect {@p.parse_fiber_content "100% Cotton / 50% Wool"}.to raise_error OpenChain::CustomHandler::Polo::PoloFiberContentParser::FiberParseError, "Failed: Fabric percentages for all components must add up to 100%.  Found 150.0%"
      end

      it "raises an error when single fiber is more than 100" do
        expect {@p.parse_fiber_content "101% Cotton"}.to raise_error OpenChain::CustomHandler::Polo::PoloFiberContentParser::FiberParseError, "Failed: Fabric percentages for all components must add up to 100%.  Found 101.0%"
      end

      it "raises an error when an invalid fabric type is used" do
        expect {@p.parse_fiber_content "100% Polyseter"}.to raise_error OpenChain::CustomHandler::Polo::PoloFiberContentParser::FiberParseError, "Failed: Invalid fabric 'Polyseter' found."
      end

      it "does not error if fabric type casing is different" do
        expect {@p.parse_fiber_content "100% COTTON"}.not_to raise_error
      end
    end
  end

  describe "parse_and_set_fiber_content" do

    before :all do
      @custom_defs = described_class.new.send(:init_custom_definitions)
    end
    after :all do
      CustomDefinition.scoped.destroy_all
      @custom_defs = nil
    end
    before :each do
      @prod = Factory(:product)
      @test_cds = described_class.prep_custom_definitions [:fiber_content, :fabric_type_1, :fabric_1, :fabric_percent_1, :fabric_type_2, :fabric_2, :fabric_percent_2, :msl_fiber_failure, :msl_fiber_status]
      
      @prod.update_custom_value! @test_cds[:fabric_type_1], "Type"
      @prod.update_custom_value! @test_cds[:fabric_type_2], "Type2"
      @prod.update_custom_value! @test_cds[:fabric_1], "Fabric"
      @prod.update_custom_value! @test_cds[:fabric_percent_1], "0"
      @prod.update_custom_value! @test_cds[:msl_fiber_failure], true
    end

    it "parses a fiber content field and sets the values into the given product" do
      DataCrossReference.create! key: "Canvas", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
      changed_at = 1.day.ago
      @prod.update_column :changed_at, changed_at
      @prod.update_column :updated_at, changed_at
      expect(described_class.parse_and_set_fiber_content @prod.id).to be_truthy

      @prod.reload
      expect(@prod.get_custom_value(@test_cds[:fabric_type_1]).value).to eq "Outer"
      expect(@prod.get_custom_value(@test_cds[:fabric_1]).value).to eq "Canvas"
      expect(@prod.get_custom_value(@test_cds[:fabric_percent_1]).value).to eq BigDecimal.new("100")
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_failure]).value).to be_falsey
      # Make sure unused fields are deleted
      expect(@prod.custom_values.find{|cv| cv.custom_definition_id == @test_cds[:fabric_type_2].id}).to be_nil
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_status]).value).to eq "Passed"
      # Make sure the product's changed at is set (which also updates the updated at, so that setting the fiber fields
      # will trigger a send to MSL+ - which is where this fiber data ultimately needs to end up)
      expect(@prod.changed_at.to_i).to be > changed_at.to_i
      expect(@prod.updated_at.to_i).to be > changed_at.to_i
    end

    it "detects an error and updates fields based on that" do
      @prod.update_custom_value! @test_cds[:fiber_content], "30/1'S COTTON MINI PIQUE"
      expect(described_class.parse_and_set_fiber_content @prod.id).to be_falsey

      @prod.reload
      # Make sure the portions that are partially understood are saved off
      expect(@prod.get_custom_value(@test_cds[:fabric_type_1]).value).to eq "Outer"
      expect(@prod.get_custom_value(@test_cds[:fabric_1]).value).to eq ""
      expect(@prod.get_custom_value(@test_cds[:fabric_percent_1]).value).to eq BigDecimal.new("30")
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_failure]).value).to be_truthy
      expect(@prod.get_custom_value(@test_cds[:fabric_type_2]).value).to eq "Outer"
      expect(@prod.get_custom_value(@test_cds[:fabric_percent_2]).value).to eq BigDecimal.new("1")
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_status]).value).to eq "Failed: Invalid Fiber Content % format."
    end

    it 'does not update custom values if fiber fingerprint is unchanged' do
      # It should not update the custom values, since the fingerprint will be unchanged.
      # Think of this as the scenario where the user modifies the MSL+ fabric fields directly and the product is modified having the fiber content
      # stay exactly the same.  We don't want to overwrite the user's modifications.
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Cotton"
      results = ['Outer', 'Cotton', '100']
      42.times {results << ''}
      results << "Failed: Invalid fabric 'Cotton' found."
      DataCrossReference.create_rl_fabric_fingerprint! @prod.unique_identifier, Digest::MD5.hexdigest(results.join("\n"))

      @prod.update_custom_value! @test_cds[:fabric_type_1], "Type"
      @prod.update_custom_value! @test_cds[:fabric_1], "Fabric"
      @prod.update_custom_value! @test_cds[:fabric_percent_1], "0"

      expect(described_class.parse_and_set_fiber_content @prod.id).to be_truthy

      @prod.reload
      expect(@prod.get_custom_value(@test_cds[:fabric_type_1]).value).to eq "Type"
      expect(@prod.get_custom_value(@test_cds[:fabric_1]).value).to eq "Fabric"
      expect(@prod.get_custom_value(@test_cds[:fabric_percent_1]).value).to eq BigDecimal.new("0")
    end

    it 'does update custom values if fiber fingerprint is changed' do
      DataCrossReference.create! key: "Cotton", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
      # It should update the custom values, since the fingerprint will be unchanged.
      # Think of this as the scenario where the user modifies the MSL+ fabric fields directly and the product is modified having the fiber content
      # stay exactly the same.  We don't want to overwrite the user's modifications.
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Cotton"
      DataCrossReference.create_rl_fabric_fingerprint! @prod.unique_identifier, "fingerprint"

      @prod.update_custom_value! @test_cds[:fabric_type_1], "Type"
      @prod.update_custom_value! @test_cds[:fabric_1], "Fabric"
      @prod.update_custom_value! @test_cds[:fabric_percent_1], "0"

      expect(described_class.parse_and_set_fiber_content @prod.id).to be_truthy

      @prod.reload
      expect(@prod.get_custom_value(@test_cds[:fabric_type_1]).value).to eq "Outer"
      expect(@prod.get_custom_value(@test_cds[:fabric_1]).value).to eq "Cotton"
      expect(@prod.get_custom_value(@test_cds[:fabric_percent_1]).value).to eq BigDecimal.new("100")

      expect(DataCrossReference.find_rl_fabric_fingerprint @prod.unique_identifier).not_to eq "fingerprint"
    end

    it 'includes the pass fail message in the fingerprint' do
      # This is a scenario we have to account for when the fiber field doesn't change at all but the user adds xrefs 
      # so that even though the fiber field didn't change, the output state of it does, so it should be fully updated.
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Blah"

      # This first pass generates the fingerprint..marking it as invalid
      expect(described_class.parse_and_set_fiber_content @prod.id).to be_falsey
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_failure]).value).to be_truthy

      # Add an xref so 'Blah' is now valid
      DataCrossReference.create! key: "Blah", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC
     
      expect(described_class.parse_and_set_fiber_content @prod.id).to be_truthy
      @prod.reload
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_failure]).value).to be_falsey
    end

    it "updates failure message if new failure type is encountered, but underlying data is unchanged" do
      # This is just a scenario where the original issue was that one fiber type was bad, and a cross reference
      # was added to fix that, but now another one is bad.  The old fingerprinting didn't take this into account
      # so the error message was telling the user the wrong thing was bad.
      @prod.update_custom_value! @test_cds[:fiber_content], "50% Cotton / 50% Wool"

      expect(described_class.parse_and_set_fiber_content @prod.id).to be_falsey
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_status]).value).to eq "Failed: Invalid fabric 'Cotton' found."

      DataCrossReference.create! key: "Cotton", cross_reference_type: DataCrossReference::RL_VALIDATED_FABRIC

      expect(described_class.parse_and_set_fiber_content @prod.id).to be_falsey
      expect(@prod.get_custom_value(@test_cds[:msl_fiber_status]).value).to eq "Failed: Invalid fabric 'Wool' found."
    end
  end

  describe "run_schedulable" do
    before :each do
      @prod = Factory(:product)
      @test_cds = described_class.prep_custom_definitions [:fiber_content, :fabric_1, :msl_fiber_failure]
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
    end

    it "finds products with updated fiber contents and calls parse on them" do
      # This should be skipped because its updated at is in the future 
      future_product = Factory(:product)
      future_product.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
      future_product.custom_values.first.update_column :updated_at, (Time.zone.now + 1.day)

      # This should be skipped because its updated at is prior to the previous run
      old_product  = Factory(:product)
      old_product.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
      old_product.custom_values.first.update_column :updated_at, (Time.zone.now - 1.day)

      # This should be picked up because it is currently in a failure state even though the fiber field has not been updated
      failed_product = Factory(:product)
      failed_product.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
      failed_product.custom_values.first.update_column :updated_at, (Time.zone.now - 1.day)
      failed_product.update_custom_value! @test_cds[:msl_fiber_failure], true

      expect(described_class).to receive(:parse_and_set_fiber_content).with @prod.id, instance_of(described_class)
      expect(described_class).to receive(:parse_and_set_fiber_content).with failed_product.id, instance_of(described_class)
      described_class.run_schedulable({'last_run_time' => 5.minutes.ago.to_s})

      # Make sure the json key is updated too (we're only storing down to the minute)
      key = KeyJsonItem.polo_fiber_report('fiber_analysis').first
      expect(Time.zone.parse key.data['last_run_time']).to be >= 1.minute.ago
    end

    it "uses previously set key json start date" do
      KeyJsonItem.polo_fiber_report('fiber_analysis').first_or_create! json_data: "{\"last_run_time\":\"#{5.minutes.ago.to_s}\"}"

      expect(described_class).to receive(:parse_and_set_fiber_content).with @prod.id, instance_of(described_class)
      described_class.run_schedulable

      # Make sure the json key is updated too (we're only storing down to the minute)
      key = KeyJsonItem.polo_fiber_report('fiber_analysis').first
      expect(Time.zone.parse key.data['last_run_time']).to be >= 1.minute.ago
    end

    it "errors if start time is not discoverable" do
      expect {described_class.run_schedulable}.to raise_error "Failed to determine the last start time for Fiber Analysis parsing run."
    end
  end

  describe "update_styles" do
    before :each do
      @prod = Factory(:product)
      @test_cds = described_class.prep_custom_definitions [:fiber_content, :fabric_1]
      @prod.update_custom_value! @test_cds[:fiber_content], "100% Canvas"
    end

    it "updates given styles" do
      expect(described_class).to receive(:parse_and_set_fiber_content).with @prod.id, instance_of(described_class)
      described_class.update_styles "A  \n   #{@prod.unique_identifier}    \n    B"
    end
  end

end