require 'spec_helper'

describe PolymorphicFinders do
  subject { Class.new {include PolymorphicFinders}.new }

  describe "polymorphic_find" do
    it "executes a find on a given class and id value" do
      product = Factory(:product)

      expect(subject.polymorphic_find("Product", product.id)).to eq product
    end

    it "handles lowercase and underscorized version of classname" do
      broker_inv = Factory(:broker_invoice)
      expect(subject.polymorphic_find("broker_invoice", broker_inv.id)).to eq broker_inv
    end

    it "fails if class doesn't inherit from ActiveRecord::Base" do
      expect {expect(subject.polymorphic_find("String", 1))}.to raise_error "Invalid class name String"
    end
  end

  describe "polymorphic_scope" do
    it "returns an unscoped relation" do
      scope = subject.polymorphic_scope "entry"

      expect(scope).to be_a ActiveRecord::Relation
      # Not really sure how to determine if the relation returned is entriely unscoped...so just making sure
      # the sql doesn't have any where clauses or joins
      expect(scope.to_sql).not_to include "WHERE"
      expect(scope.to_sql).not_to include "JOIN"
    end

    it "handles lowercase and underscorized version of classname" do
      expect(subject.polymorphic_scope "broker_invoice").to eq BrokerInvoice.scoped
    end

    it "handles pluralized (rails route) form of classname" do
      expect(subject.polymorphic_scope "broker_invoices").to eq BrokerInvoice.scoped
    end

    it "fails if class doesn't inherit from ActiveRecord::Base" do
      expect {expect(subject.polymorphic_scope "String")}.to raise_error "Invalid class name String"
    end
  end

  describe "validate_polymorphic_class" do
    subject { 
      Class.new do 
        include PolymorphicFinders

        def validate_polymorphic_class model_class
          model_class == Entry
        end
      end.new 
    }

    it "allows overriding validate_polymorphic_class to change class usage limitation" do
      expect(subject.constantize("entry")).to eq Entry
      expect {subject.constantize("product")}.to raise_error "Invalid class name product"
    end
  end

  describe "polymorphic_where" do
    let! (:obj) { Factory(:entry) }

    it "returns a relation scoped to the given class and id value of the model" do
      expect(subject.polymorphic_where("entries", obj.id).first).to eq obj
    end
  end
end