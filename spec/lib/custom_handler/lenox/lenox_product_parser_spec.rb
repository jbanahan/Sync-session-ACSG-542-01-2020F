require 'spec_helper'

describe OpenChain::CustomHandler::Lenox::LenoxProductParser do
  def expect_custom_value product, code, val
    expect(product.get_custom_value(@cdefs[code]).value).to eq val
  end
  before :each do
    @imp = Factory(:importer,system_code:'LENOX')
    @u = Factory(:master_user)
    @row = "    00200GB           ODIN 5 PC PLACE SET BOXED               A                         0003METALS         03STAINLESS           02DANSK               7                                    0010FINE STAINLESS FLATWARE       004METALS                        O002ODIN                          F0047FORMAL STAINLESS    61867            1387534          VN 55224                    1 FIRST     0004GLENN DESTEFANO               0004ANTHONY BADESSA               25 JOE GILSON               97 MADELINE LUMA                      MADELINE_LUMA@LENOX.COM       267-525-5153                  005"
  end
  context :hashing do
    it "should process line the first time" do
      expect {
        described_class.new.process @row, @u
      }.to change(Product,:count).by 1
    end
    it "should not process line the second time" do
      described_class.new.process @row, @u
      p = Product.first
      t = 1.year.ago
      p.update_attributes(updated_at:t)
      described_class.new.process @row, @u
      p.reload
      expect(p.updated_at.to_i).to eq t.to_i
    end
    it "should process a line with any change" do
      described_class.new.process @row, @u
      p = Product.first
      t = 1.year.ago
      p.update_attributes(updated_at:t)
      @row[0] = 'X'
      described_class.new.process @row, @u
      p.reload
      expect(p.updated_at.to_i).not_to eq t.to_i
    end
  end
  context :product do
    before :each do
      @cdefs = described_class.prep_custom_definitions described_class::CUSTOM_DEFINITION_INSTRUCTIONS.keys
    end
    it "should create product" do
      described_class.new.process @row, @u
      p = Product.first
      expect(p.unique_identifier).to eq 'LENOX-00200GB'
      expect(p.name).to eq 'ODIN 5 PC PLACE SET BOXED'
      expect_custom_value p, :part_number, '00200GB'
      expect_custom_value p, :product_group, 'METALS-STAINLESS'
      expect_custom_value p, :product_department, 'DANSK'
      expect_custom_value p, :product_pattern, 'ODIN'
      expect_custom_value p, :product_buyer_name, 'JOE GILSON'
      expect_custom_value p, :product_units_per_set, 5
      expect_custom_value p, :product_coo, 'VN'
    end
    it "should create history and last updated by" do
      described_class.new.process @row, @u
      p = Product.first
      expect(p.last_updated_by).to eq @u
      expect(p.entity_snapshots.count).to eq 1
    end

    describe "parse" do
      it "parses a product file" do
        @u.update_attributes! username: 'integration'

        # This is just an integration call through to the process method, just make sure it runs without error
        described_class.parse @row
        expect(Product.first.unique_identifier).to eq 'LENOX-00200GB'
      end
    end
  end

  describe "integration_folder" do
    it "uses an integration folder" do
      expect(described_class.integration_folder).to eq "/opt/wftpserver/ftproot/www-vfitrack-net/_lenox_product"
    end
  end
end
