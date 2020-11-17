describe OpenChain::CustomHandler::PoloSapBomHandler do
  context 'security' do
    it "shoud allow user who can edit products" do
      u = User.new
      expect(u).to receive(:edit_products?).and_return(true)
      expect(described_class.new(nil).can_view?(u)).to be_truthy
    end
    it "should not allow user who can't edit products" do
      u = User.new
      expect(u).to receive(:edit_products?).and_return(false)
      expect(described_class.new(nil).can_view?(u)).to be_falsey
    end
  end

  context "xl_client processing" do
    before :each do
      @xlc = double("XL Client")
      @cf = double('custom_file')
      allow(@cf).to receive(:attached_file_name).and_return('t.xlsx')
      @att = double('attached')
      expect(@att).to receive(:path).and_return('/path/to')
      allow(@cf).to receive(:attached).and_return(@att)
      allow_any_instance_of(User).to receive(:edit_products?).and_return true
      expect(OpenChain::XLClient).to receive(:new).with('/path/to').and_return(@xlc)
    end
    it "should create new parent product and new existing children" do
      expect(@xlc).to receive(:last_row_number).and_return(2)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10004', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'2', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      p = Product.find_by unique_identifier: 'parentuid'
      expect(p.bill_of_materials_children.size).to eq(2)
      r = p.bill_of_materials_children.to_a
      expect(r.first.child_product.unique_identifier).to eq('10003')
      expect(r.first.quantity).to eq(1)
      expect(r.last.child_product.unique_identifier).to eq('10004')
      expect(r.last.quantity).to eq(2)
    end
    it "should process two parents with two children each" do
      expect(@xlc).to receive(:last_row_number).and_return(4)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10004', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'2', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 3).and_return(
        0=>{'value'=>'parentuid2', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10005', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 4).and_return(
        0=>{'value'=>'parentuid2', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10006', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'2', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      p2 = Product.find_by(unique_identifier: 'parentuid2')
      expect(p2.bill_of_materials_children.size).to eq(2)
      expect(p2.child_products.first.unique_identifier).to eq('10005')
      expect(p2.child_products.last.unique_identifier).to eq('10006')
      expect(Product.find_by(unique_identifier: 'parentuid').bill_of_materials_children.size).to eq(2)
    end
    it "should process duplicate parents with different plant codes and only take last values" do
      expect(@xlc).to receive(:last_row_number).and_return(4)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10004', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'2', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 3).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode2', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10005', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 4).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode2', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10006', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'2', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      p = Product.find_by_unique_identifier 'parentuid'
      expect(p.bill_of_materials_children.size).to eq(2)
      r = p.bill_of_materials_children.to_a
      expect(r.first.child_product.unique_identifier).to eq('10005')
      expect(r.first.quantity).to eq(1)
      expect(r.last.child_product.unique_identifier).to eq('10006')
      expect(r.last.quantity).to eq(2)
    end
    it "should associate existing parent / child" do
      p = Factory(:product, :unique_identifier=>'parentuid')
      c = Factory(:product, :unique_identifier=>'10003')
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      expect(Product.count).to eq(2)
      expect(p.child_products.to_a).to eq([c])
    end
    it "should associate new child with existing parent" do
      p = Factory(:product, :unique_identifier=>'parentuid')
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      expect(Product.count).to eq(2)
      c = Product.find_by_unique_identifier '10003'
      expect(c).not_to be_nil
      expect(p.child_products.to_a).to eq([c])
    end
    it "should maintain existing parent when new parent added for child" do
      old_parent = Factory(:product)
      c = Factory(:product, :unique_identifier=>'10003')
      c.bill_of_materials_parents.create!(:parent_product_id=>old_parent.id, :quantity=>1)
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      expect(Product.count).to eq(3)
      c.reload
      expect(c.bill_of_materials_parents.size).to eq(2)
    end
    it "should clear existing children (but shouldn't delete them) when parent is processed" do
      p = Factory(:product, :unique_identifier=>'parentuid')
      old_c = Factory(:product)
      p.bill_of_materials_children.create!(:child_product_id=>old_c.id, :quantity=>1)
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process Factory(:user)
      expect(Product.count).to eq(3)
      old_c.reload
      expect(old_c.parent_products).to be_empty
      p.reload
      expect(p.child_products.first.unique_identifier).to eq('10003')
    end
    it "should write message to user account" do
      u = Factory(:user)
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'parentuid', 'datatype'=>'string'}, # parent material number
        2=>{'value'=>'plantcode', 'datatype'=>'string'}, # plant code
        4=>{'value'=>'10003', 'datatype'=>'number'}, # child material number
        6=>{'value'=>'1', 'datatype'=>'number'} # quantity
      )
      described_class.new(@cf).process u
      expect(u.messages.size).to eq(1)
    end
  end
end
