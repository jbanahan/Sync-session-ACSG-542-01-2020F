require 'spec_helper'

describe Product do
  context "security" do
    before :each do
      @master_user = Factory(:master_user,:product_view=>true,:product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true)
      @importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true)
      @other_importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true)
      @linked_importer_user = Factory(:importer_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true)
      @importer_user.company.linked_companies << @linked_importer_user.company
      @unassociated_product = Factory(:product)
      @importer_product = Factory(:product,:importer=>@importer_user.company)
      @linked_product = Factory(:product,:importer=>@linked_importer_user.company)
    end
    describe "item permissions" do
      it "should allow master company to handle any product" do
        [@unassociated_product,@importer_product,@linked_product].each do |p|
          p.can_view?(@master_user).should be_true
          p.can_edit?(@master_user).should be_true
          p.can_classify?(@master_user).should be_true
          p.can_comment?(@master_user).should be_true
          p.can_attach?(@master_user).should be_true
        end
      end
      it "should allow importer to handle own products" do
        @importer_product.can_view?(@importer_user).should be_true
        @importer_product.can_edit?(@importer_user).should be_true
        @importer_product.can_classify?(@importer_user).should be_true
        @importer_product.can_comment?(@importer_user).should be_true
        @importer_product.can_attach?(@importer_user).should be_true
      end
      it "should allow importer to handle linked company products" do
        @linked_product.can_view?(@importer_user).should be_true
        @linked_product.can_edit?(@importer_user).should be_true
        @linked_product.can_classify?(@importer_user).should be_true
        @linked_product.can_comment?(@importer_user).should be_true
        @linked_product.can_attach?(@importer_user).should be_true
      end
      it "should not allow importer to handle unlinked company products" do
        @importer_product.can_view?(@other_importer_user).should be_false
        @importer_product.can_edit?(@other_importer_user).should be_false
        @importer_product.can_classify?(@other_importer_user).should be_false
        @importer_product.can_comment?(@other_importer_user).should be_false
        @importer_product.can_attach?(@other_importer_user).should be_false
      end
      it "should not allow importer to handle product with no importer" do
        @unassociated_product.can_view?(@importer_user).should be_false
        @unassociated_product.can_edit?(@importer_user).should be_false
        @unassociated_product.can_classify?(@importer_user).should be_false
        @unassociated_product.can_comment?(@importer_user).should be_false
        @unassociated_product.can_attach?(@importer_user).should be_false
      end
      context "vendor" do
        before :each do
          @vendor_user = Factory(:vendor_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true)
          @vendor_user.company.linked_companies << @linked_importer_user.company 
          @vendor_product = Factory(:product,:vendor=>@vendor_user.company) 
          @linked_vendor_user = Factory(:vendor_user,:product_view=>true, :product_edit=>true, :classification_edit=>true,:product_comment=>true,:product_attach=>true) 
          @linked_vendor_user.company.linked_companies << @vendor_user.company
        end

        it "should allow a vendor to handle own products" do
          @vendor_product.can_view?(@vendor_user).should be_true
          #Vendors can't edit products - only master and importer types
          @vendor_product.can_edit?(@vendor_user).should be_false
          @vendor_product.can_classify?(@vendor_user).should be_false
          @vendor_product.can_comment?(@vendor_user).should be_true
          @vendor_product.can_attach?(@vendor_user).should be_true
        end

        it "should allow vendor to handle linked importer company products" do
          @linked_product.can_view?(@vendor_user).should be_true
          @linked_product.can_edit?(@vendor_user).should be_false
          @linked_product.can_classify?(@vendor_user).should be_false
          @linked_product.can_comment?(@vendor_user).should be_true
          @linked_product.can_attach?(@vendor_user).should be_true
        end
        
        it "should allow vendor to handle linked vendor company products" do
          @vendor_product.can_view?(@linked_vendor_user).should be_true
          @vendor_product.can_edit?(@linked_vendor_user).should be_false
          @vendor_product.can_classify?(@linked_vendor_user).should be_false
          @vendor_product.can_comment?(@linked_vendor_user).should be_true
          @vendor_product.can_attach?(@linked_vendor_user).should be_true
        end

        it "should not allow vendor to handle unlinked company products" do
          @importer_product.can_view?(@vendor_user).should be_false
          @importer_product.can_edit?(@vendor_user).should be_false
          @importer_product.can_classify?(@vendor_user).should be_false
          @importer_product.can_comment?(@vendor_user).should be_false
          @importer_product.can_attach?(@other_importer_user).should be_false
        end

        it "should not allow vendor to handle product with no vendor" do
          @unassociated_product.can_view?(@vendor_user).should be_false
          @unassociated_product.can_edit?(@vendor_user).should be_false
          @unassociated_product.can_classify?(@vendor_user).should be_false
          @unassociated_product.can_comment?(@vendor_user).should be_false
          @unassociated_product.can_attach?(@vendor_user).should be_false
        end
      end
    end
    describe "search_secure" do
      it "should find all for master" do
        Product.search_secure(@master_user, Product.where("1=1")).sort {|a,b| a.id<=>b.id}.should == [@linked_product,@importer_product,@unassociated_product].sort {|a,b| a.id<=>b.id}
      end
      it "should find importer's products" do
        Product.search_secure(@importer_user, Product.where("1=1")).sort {|a,b| a.id<=>b.id}.should == [@linked_product,@importer_product].sort {|a,b| a.id<=>b.id}
      end
      it "should not find other importer's products" do
        Product.search_secure(@other_importer_user,Product.where("1=1")).should be_empty
      end
    end
  end
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      product = Factory(:product)
      linkable = Factory(:linkable_attachment,:model_field_uid=>'prod',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>product)
      product.reload
      product.linkable_attachments.first.should == linkable
    end
  end
end
