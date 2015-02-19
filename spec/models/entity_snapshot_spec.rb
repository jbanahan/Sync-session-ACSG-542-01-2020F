require 'spec_helper'

describe EntitySnapshot do
  describe :diff do
    before :each do
      @u = Factory(:user)
    end
    it "should return empty diff for identical snapshots" do
      ol = Factory(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      expect(diff.record_id).to eq o.id
      expect(diff.core_module).to eq 'Order'
      expect(diff.model_fields_changed).to be_empty
      expect(diff.children_added).to be_empty
      expect(diff.children_deleted).to be_empty

      cib = diff.children_in_both
      expect(cib.size).to eq 1
      expect(cib.first.record_id).to eq ol.id
      expect(cib.first.model_fields_changed).to be_empty
    end
    it "should reflect changed field" do
      o = Factory(:order)
      old_order_number = o.order_number
      new_order_number = "#{o.order_number}X"

      s = EntitySnapshot.create_from_entity o, @u
      o.update_attributes(order_number:new_order_number)
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.model_fields_changed['ord_ord_num']).to eq [old_order_number,new_order_number]
    end
    it "should reflect added child" do
      o = Factory(:order)
      s = EntitySnapshot.create_from_entity o, @u
      ol = Factory(:order_line,order:o)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_added.size).to eq 1
      ca = diff.children_added.first
      expect(ca.record_id).to eq ol.id
      expect(ca.model_fields_changed['ordln_line_number'][1]).to eq ol.line_number
    end
    it "should reflect deleted child" do
      ol = Factory(:order_line)
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.destroy
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s

      expect(diff.children_deleted.size).to eq 1
      cd = diff.children_deleted.first
      expect(cd.record_id).to eq ol.id
      expect(cd.model_fields_changed['ordln_line_number'][0]).to eq ol.line_number
    end
    it "should reflect field changed in child" do
      ol = Factory(:order_line)
      old_line_number = ol.line_number
      new_line_number = old_line_number + 1
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.update_attributes(line_number:new_line_number)
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_line_number']).to eq [old_line_number,new_line_number]
    end
    it "should reflect child with new id and same logical key as update not add/delete" do
      ol = Factory(:order_line,hts:'123456')
      line_number = ol.line_number
      o = ol.order
      s = EntitySnapshot.create_from_entity o, @u
      ol.destroy
      ol = Factory(:order_line,order:o,line_number:line_number,hts:'654321')
      o.reload
      s2 = EntitySnapshot.create_from_entity o, @u
      diff = s2.diff s
      
      expect(diff.children_in_both.size).to eq 1
      cib = diff.children_in_both.first
      expect(cib.model_fields_changed['ordln_hts']).to eq ['123456'.hts_format,'654321'.hts_format]
    end
  end
  describe :restore do
    before :each do 
      ModelField.reload
      #not worrying about permissions
      Product.any_instance.stub(:can_edit?).and_return(true)
      Classification.any_instance.stub(:can_edit?).and_return(true)
      TariffRecord.any_instance.stub(:can_edit?).and_return(true)

      @u = Factory(:user)
      @p = Factory(:product,:name=>'nm',:unique_identifier=>'uid')
      @tr = Factory(:tariff_record,:hts_1=>'1234567890',:classification=>Factory(:classification,:product=>@p))
      @first_snapshot = @p.create_snapshot @u
    end
    it "should replace base object properties" do
      @p.update_attributes(:name=>'n2')
      restored = @first_snapshot.restore(@u)
      restored.id.should == @p.id
      restored.name.should == 'nm'
    end
    it "should erase base object properties that have been added" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(@u)
      restored.id.should == @p.id
      restored.unit_of_measure.should be_blank
    end
    it "should insert base object properties that have been removed" do
      @p.update_attributes(:name=>nil)
      restored = @first_snapshot.restore(@u)
      restored.id.should == @p.id
      restored.name.should == 'nm'
    end
    it "should leave base object properties that haven't changed alone" do
      @p.update_attributes(:unit_of_measure=>'EA')
      restored = @first_snapshot.restore(@u)
      restored.id.should == @p.id
      restored.name.should == 'nm'
    end
    it "should update last_updated_by_id" do
      other_user = Factory(:user)
      restored = @first_snapshot.restore(other_user)
      restored.last_updated_by_id.should == other_user.id
    end
    it "should not restore if user does not have permission" do
      @p.update_attributes! last_updated_by: @u
      Product.any_instance.stub(:can_edit?).and_return(false)
      @p.update_attributes(:name=>'n2')
      other_user = Factory(:user)
      restored = @first_snapshot.restore(@u)
      restored.last_updated_by_id.should == @u.id
      restored.name.should == 'n2'
    end

    context :custom_values do
      before :each do 
        @cd = Factory(:custom_definition,:module_type=>'Product',:data_type=>'string')
        ModelField.reload
        @p.update_custom_value! @cd, 'x'
        @first_snapshot = @p.create_snapshot @u
      end
      it "should replace custom fields" do
        @p.update_custom_value! @cd, 'y'
        restored = @first_snapshot.restore(@u)
        restored.get_custom_value(@cd).value.should == 'x'
      end
      it "should erase custom fields that have been added" do
        cd2 = Factory(:custom_definition,:module_type=>'Product',:data_type=>'string')
        @p.update_custom_value! cd2, 'y'
        restored = @first_snapshot.restore(@u)
        restored.get_custom_value(cd2).value.should be_blank
      end
      it "should insert custom fields that have been removed" do
         @p.get_custom_value(@cd).destroy 
        restored = @first_snapshot.restore(@u)
        restored.get_custom_value(@cd).value.should == 'x'
      end
      it "should leave custom fields that haven't changed alone" do
        restored = @first_snapshot.restore(@u)
        restored.get_custom_value(@cd).value.should == 'x'
      end
    end

    context "children" do
      it "should add children that were removed" do
        @p.classifications.first.destroy
        restored = @first_snapshot.restore @u
        restored.classifications.first.tariff_records.first.hts_1.should == '1234567890'
      end
      it "should remove children that didn't exist" do
        p = Factory(:product)
        es = p.create_snapshot @u
        Factory(:tariff_record,:classification=>(Factory(:classification,:product=>p)))
        p.reload
        p.classifications.first.tariff_records.first.should_not be_nil
        es.restore @u
        p.reload
        p.classifications.first.should be_nil
      end
      it "should replace values in children that changed" do
        @tr.update_attributes(:hts_1=>'1234')
        @first_snapshot.restore @u
        TariffRecord.find(@tr.id).hts_1.should == '1234567890'
      end
      it "should replace custom values for children that changed" do
        cd = Factory(:custom_definition,:module_type=>"Classification",:data_type=>"string")
        @tr.classification.update_custom_value! cd, 'x'
        @first_snapshot = @p.create_snapshot @u
        @tr.classification.update_custom_value! cd, 'y'
        restored = @first_snapshot.restore @u
        restored.classifications.first.get_custom_value(cd).value.should == 'x'
      end

      it "should skip child records with blank record ids" do
        j = JSON.parse @first_snapshot.snapshot
        j['entity']['children'][0]['entity']['record_id'] = nil
        @first_snapshot.snapshot = j.to_json
        restored = @first_snapshot.restore @u
        expect(restored.classifications.size).to eq 0
      end
    end

  end

end
