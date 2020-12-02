describe SearchCriterion do
  let(:product) { create(:product) }

  it 'knows what type of criterion it is' do
    sc = described_class.create(model_field_uid: 'ent_release_date', operator: 'nqf', value: 'ent_arrival_date')
    expect(sc.operator_label).to eql('Not Equal To (Field Including Time)')
  end

  describe "core_module" do
    it "returns core module based on module type" do
      expect(described_class.new(model_field_uid: 'ent_release_date').core_module.klass).to eq Entry
    end
  end

  describe "copy_attributes" do
    let(:criterion) do
      create(:search_criterion, search_setup: create(:search_setup), business_validation_template: create(:business_validation_template),
                                 one_time_alert: create(:one_time_alert), include_empty: true, model_field_uid: "ent_cust_num",
                                 operator: "eq", secondary_model_field_uid: "ent_brok_ref", value: "val")
    end

    it "hashifies attributes without foreign keys" do
      attributes = {"search_criterion" =>
                     {"include_empty" => true,
                      "model_field_uid" => "ent_cust_num",
                      "operator" => "eq",
                      "secondary_model_field_uid" => "ent_brok_ref",
                      "value" => "val"}}

      expect(criterion.copy_attributes).to eq attributes
    end
  end

  context "less than decimal" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'CommercialInvoiceLine', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'cil_value', operator: 'ltfdec', value: '50', secondary_model_field_uid: 'cil_contract_amount')
    end

    it "does not pass if field is greater than other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      search_criterion.update(value: '200')
      expect(search_criterion.test?(cil)).to be_falsey
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils).to be_empty
    end

    it "passes if field is less than other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_truthy
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils.first).to eq(cil)
    end
  end

  context "greater than decimal" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'CommercialInvoiceLine', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'cil_value', operator: 'gtfdec', value: '200', secondary_model_field_uid: 'cil_contract_amount')
    end

    it "does not pass if field is less than other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      search_criterion.update(value: '0.4')
      expect(search_criterion.test?(cil)).to be_falsey
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils).to be_empty
    end

    it "passes if field is greater than other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_truthy
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils.first).to eq(cil)
    end
  end

  context "equal decimal" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'CommercialInvoiceLine', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'cil_value', operator: 'eqfdec', value: '100', secondary_model_field_uid: 'cil_contract_amount')
    end

    it "passes if field is equal to other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_truthy
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils.first).to eq(cil)
    end

    it "does not pass if field is not equal to other field's value as decimal" do
      search_criterion.update(value: '50')
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_falsey
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils).to be_empty
    end
  end

  context "not equal decimal" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'CommercialInvoiceLine', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'cil_value', operator: 'nqfdec', value: '50', secondary_model_field_uid: 'cil_contract_amount')
    end

    it "passes if field is not equal to other field's value as decimal" do
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_truthy
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils.first).to eq(cil)
    end

    it "does not pass if field is equal to other field's value as decimal" do
      search_criterion.update(value: '100')
      cil = CommercialInvoiceLine.create!(line_number: 1, value: 10, contract_amount: 5)
      expect(search_criterion.test?(cil)).to be_falsey
      cils = search_criterion.apply(CommercialInvoiceLine.all).all
      expect(cils).to be_empty
    end
  end

  context "split field" do
    let(:ss) { SearchSetup.new(module_type: 'Entry') }

    context "non-relative fields" do
      let(:sc) { ss.search_criterions.new(model_field_uid: 'ent_customer_references', operator: 'regexp', value: 'X\d{3}Y') }

      it "passes if all field segments validate" do
        ent = create(:entry, customer_references: "X123Y\n X456Y")
        expect(sc.test?(ent, nil, {split_field: true})).to be_truthy
      end

      it "fails if any field segment fails to validate" do
        ent = create(:entry, customer_references: "X123Y\n 456Y")
        expect(sc.test?(ent, nil, {split_field: true})).to be_falsey
      end

      context "with pass_if_any option" do
        it "passes if at least one field segment validates" do
          ent = create(:entry, customer_references: "X123Y\n 456Y")
          expect(sc.test?(ent, nil, {split_field: true, pass_if_any: true})).to be_truthy
        end

        it "fails if all field segments fail to validate" do
          ent = create(:entry, customer_references: "123Y\n 456Y")
          expect(sc.test?(ent, nil, {split_field: true, pass_if_any: true})).to be_falsey
        end
      end
    end

    context "relative fields" do
      let(:sc) { ss.search_criterions.new(model_field_uid: 'ent_customer_references', operator: 'eqf', value: 'ent_cust_num') }

      it "passes if all field segments validate" do
        ent = create(:entry, customer_references: "FOO\n FOO", customer_number: "FOO")
        expect(sc.test?(ent, nil, {split_field: true})).to be_truthy
      end

      it "fails if any field segment fails to validate" do
        ent = create(:entry, customer_references: "FOO\n BAR", customer_number: "FOO")
        expect(sc.test?(ent, nil, {split_field: true})).to be_falsey
      end

      context "with pass_if_any option" do
        it "passes if at least one field segment validates" do
          ent = create(:entry, customer_references: "FOO\n BAR", customer_number: "FOO")
          expect(sc.test?(ent, nil, {split_field: true, pass_if_any: true})).to be_truthy
        end

        it "fails if all field segments fail to validate" do
          ent = create(:entry, customer_references: "BAR\n BAR", customer_number: "FOO")
          expect(sc.test?(ent, nil, {split_field: true, pass_if_any: true})).to be_falsey
        end
      end
    end
  end

  context "not equal to (field)" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'Entry', user: user) }
    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'ent_release_date', operator: 'nqfd', value: 'ent_arrival_date')
    end

    it "passes if field is not equal to other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "does not pass if field is equal other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is null" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "passes if other field is null" do
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end
  end

  context "not equal to (field including time)" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'Entry', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'ent_release_date', operator: 'nqf', value: 'ent_arrival_date')
    end

    it "cares about time" do
      time1 = Time.zone.local("2017", "01", "01", "12", "59")
      time2 = Time.zone.local("2017", "01", "01", "12", "58")
      ent = create(:entry, arrival_date: time1, release_date: time2)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "passes if field is not equal to other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "does not pass if field is equal other field's value" do
      time = Time.zone.local("2017", "01", "01", "12", "59")
      ent = create(:entry, arrival_date: time, release_date: time)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is null" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "passes if other field is null" do
      ent = create(:entry, arrival_date: nil, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end
  end

  context "equals (field including time)" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'Entry', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'ent_release_date', operator: 'eqf', value: 'ent_arrival_date')
    end

    it "cares about time" do
      time1 = Time.zone.local("2017", "01", "01", "12", "59")
      time2 = Time.zone.local("2017", "01", "01", "12", "58")
      ent = create(:entry, arrival_date: time1, release_date: time2)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is equal to other field's value" do
      time = Time.zone.local("2017", "01", "01", "12", "59")
      ent = create(:entry, arrival_date: time, release_date: time)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "does not pass if field does not equal other field's value" do
      time1 = Time.zone.local("2017", "01", "01", "12", "59")
      time2 = Time.zone.local("2017", "01", "01", "12", "58")
      ent = create(:entry, arrival_date: time1, release_date: time2)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "does not pass if field is null" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "does not pass if other field is null" do
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end
  end

  context "after (field)" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'Entry', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'ent_release_date', operator: 'afld', value: 'ent_arrival_date')
    end

    it "passes if field is after other field's value" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "fails if field is same as other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if field is before other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if field is null" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if other field is null" do
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is null and include empty is true" do
      search_criterion.include_empty = true
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is not null and other field is true and include empty is true" do
      search_criterion.include_empty = true
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes for custom date fields before another custom date field" do
      # There's no real logic differences in search criterion for handling custom fields
      # for the before fields, but there is some backend stuff behind it that I want to make sure
      # don't cause regressions if they're modified.
      def1 = create(:custom_definition, data_type: 'date', module_type: 'Entry')
      def2 = create(:custom_definition, data_type: 'date', module_type: 'Entry')
      search_criterion.model_field_uid = described_class.make_field_name def1
      search_criterion.value = described_class.make_field_name def2

      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      ent.update_custom_value! def1, 1.month.ago
      ent.update_custom_value! def2, 2.months.ago

      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "passes when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is after the invoice date
      inv = create(:commercial_invoice, invoice_date: 2.months.ago)
      ent = inv.entry
      ent.update release_date: 1.month.ago
      search_criterion.value = "ci_invoice_date"

      expect(search_criterion.test?([ent, inv])).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end
  end

  context "before (field)" do
    let(:user) { create(:master_user) }
    let(:search_setup) { SearchSetup.new(module_type: 'Entry', user: user) }

    let(:search_criterion) do
      search_setup.search_criterions.new(model_field_uid: 'ent_release_date', operator: 'bfld', value: 'ent_arrival_date')
    end

    it "passes if field is before other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end

    it "fails if field is same as other field's value" do
      ent = create(:entry, arrival_date: 1.day.ago, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if field is after other field's value" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: 1.day.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if field is null" do
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "fails if other field is null" do
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_falsey
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is null and include empty is true" do
      search_criterion.include_empty = true
      ent = create(:entry, arrival_date: 2.days.ago, release_date: nil)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes if field is not null and other field is true and include empty is true" do
      search_criterion.include_empty = true
      ent = create(:entry, arrival_date: nil, release_date: 2.days.ago)
      expect(search_criterion.test?(ent)).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents).to be_empty
    end

    it "passes for custom date fields before another custom date field" do
      # There's no real logic differences in search criterion for handling custom fields
      # for the before fields, but there is some backend stuff behind it that I want to make sure
      # don't cause regressions if they're modified.
      def1 = create(:custom_definition, data_type: 'date')
      def2 = create(:custom_definition, data_type: 'date')
      search_criterion.model_field_uid = described_class.make_field_name def1
      search_criterion.value = described_class.make_field_name def2

      product.update_custom_value! def1, 2.months.ago
      product.update_custom_value! def2, 1.month.ago

      expect(search_criterion.test?(product)).to be_truthy
      prods = search_criterion.apply(Product.all).all
      expect(prods.first).to eq(product)
    end

    it "passes when comparing fields across multiple module levels" do
      # This tests that we get the entry back if the release date is before the invoice date
      inv = create(:commercial_invoice, invoice_date: 1.month.ago)
      ent = inv.entry
      ent.update release_date: 2.months.ago
      search_criterion.value = "ci_invoice_date"

      expect(search_criterion.test?([ent, inv])).to be_truthy
      ents = search_criterion.apply(Entry.all).all
      expect(ents.first).to eq(ent)
    end
  end

  context "previous _ months" do
    describe "test?" do
      let(:search_criterion) do
        described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
      end

      it "finds something from the last month with val = 1" do
        product.created_at = 1.month.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not find something from this month" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "finds something from last month with val = 2" do
        product.created_at = 1.month.ago
        search_criterion.value = 2
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "finds something from 2 months ago with val = 2" do
        product.created_at = 2.months.ago
        search_criterion.value = 2
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not find something from 2 months ago with val = 1" do
        product.created_at = 2.months.ago
        search_criterion.value = 1
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not find a date in the future" do
        product.created_at = 1.month.from_now
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "is false for nil" do
        product.created_at = nil
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "is true for nil with include_empty for date fields" do
        product.created_at = nil
        crit = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
        crit.include_empty = true
        expect(crit.test?(product)).to be_truthy
      end

      it "is true for nil and blank values with include_empty for string fields" do
        product.name = nil
        crit = described_class.new(model_field_uid: :prod_name, operator: "eq", value: "1")
        crit.include_empty = true
        expect(crit.test?(product)).to be_truthy
        product.name = ""
        expect(crit.test?(product)).to be_truthy
        # Make sure we consider nothing but whitespace as empty
        product.name = "\n  \t  \r"
        expect(crit.test?(product)).to be_truthy
      end

      it "is true for nil and 0 with include_empty for numeric fields" do
        e = Entry.new
        crit = described_class.new(model_field_uid: :ent_total_fees, operator: "eq", value: "1")
        crit.include_empty = true
        expect(crit.test?(e)).to be_truthy
        e.total_fees = 0
        expect(crit.test?(e)).to be_truthy
        e.total_fees = 0.0
        expect(crit.test?(e)).to be_truthy
      end

      it "is true for nil and false with include_empty for boolean fields" do
        e = Entry.new
        crit = described_class.new(model_field_uid: :ent_paperless_release, operator: "notnull", value: nil)
        crit.include_empty = true
        expect(crit.test?(e)).to be_truthy
        e.paperless_release = true
        expect(crit.test?(e)).to be_truthy
        e.paperless_release = false
        expect(crit.test?(e)).to be_falsey
      end

      it "does not consider trailing whitespce for = operator" do
        product.name = "ABC   "
        crit = described_class.new(model_field_uid: :prod_name, operator: "eq", value: "ABC")
        expect(crit.test?(product)).to be_truthy
        crit.value = "ABC   "
        product.name = "ABC"
        expect(crit.test?(product)).to be_truthy

        # Make sure we are considering leading whitespace
        product.name = "   ABC"
        expect(crit.test?(product)).to be_falsey
        crit.value = "   ABC"
        product.name = "ABC"
        expect(crit.test?(product)).to be_falsey
      end

      it "does not consider trailing whitespce for != operator" do
        product.name = "ABC   "
        crit = described_class.new(model_field_uid: :prod_name, operator: "nq", value: "ABC")
        expect(crit.test?(product)).to be_falsey
        crit.value = "ABC   "
        product.name = "ABC"
        expect(crit.test?(product)).to be_falsey

        # Make sure we are considering leading whitespace
        product.name = "   ABC"
        expect(crit.test?(product)).to be_truthy
        crit.value = "   ABC"
        product.name = "ABC"
        expect(crit.test?(product)).to be_truthy
      end

      it "does not consider trailing whitespce for IN operator" do
        crit = described_class.new(model_field_uid: :prod_name, operator: "in", value: "ABC\nDEF")
        product.name = "ABC   "
        expect(crit.test?(product)).to be_truthy
        product.name = "DEF    "
        expect(crit.test?(product)).to be_truthy
        crit.value = "ABC   \nDEF   \n"
        expect(crit.test?(product)).to be_truthy

        # Make sure we are considering leading whitespace
        product.name = "   ABC"
        expect(crit.test?(product)).to be_falsey
        product.name = "   DEF"
        expect(crit.test?(product)).to be_falsey
      end

      it "finds something with a NOT IN operator" do
        crit = described_class.new(model_field_uid: :prod_name, operator: "notin", value: "ABC\nDEF")
        product.name = "A"
        expect(crit.test?(product)).to be_truthy
        product.name = "ABC"
        expect(crit.test?(product)).to be_falsey
        product.name = "ABC   "
        expect(crit.test?(product)).to be_falsey
        product.name = "DEF   "
        expect(crit.test?(product)).to be_falsey

        product.name = "  ABC"
        expect(crit.test?(product)).to be_truthy
        product.name = "  DEF"
        expect(crit.test?(product)).to be_truthy
      end
    end

    describe "apply" do
      context "custom_field" do
        it "finds something created last month with val = 1" do
          definition = create(:custom_definition, data_type: 'date')
          product.update_custom_value! definition, 1.month.ago
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "pm", value: 1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with nil date and include_empty" do
          definition = create(:custom_definition, data_type: 'date')
          product.update_custom_value! definition, nil
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "pm", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with nil string and include_empty" do
          definition = create(:custom_definition, data_type: 'string')
          product.update_custom_value! definition, nil
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with blank string and include_empty" do
          definition = create(:custom_definition, data_type: 'string')
          # MySQL only trims out spaces (not other whitespace), that's good enough for our use
          # as the actual vetting of the model fields will catch any additional whitespace and reject
          # the model
          product.update_custom_value! definition, "   "
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with nil text and include_empty" do
          definition = create(:custom_definition, data_type: 'text')
          product.update_custom_value! definition, nil
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with blank text and include_empty" do
          definition = create(:custom_definition, data_type: 'text')
          product.update_custom_value! definition, " "
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with 0 and include_empty" do
          definition = create(:custom_definition, data_type: 'integer')
          product.update_custom_value! definition, 0
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with include_empty that doesn't have a custom value record for custom field" do
          definition = create(:custom_definition, data_type: 'integer')
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "finds something with include_empty that doesn't have a custom value record for the child object's custom field" do
          definition = create(:custom_definition, data_type: 'integer', module_type: "Classification")
          sc = described_class.new(model_field_uid: "*cf_#{definition.id}", operator: "eq", value: 1)
          sc.include_empty = true
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "handles virtual custom fields" do
          # Virtual search queries work pretty much identical to standard fields, so we shouldn't need to bother checking all different data types, etc
          cdef = create(:custom_definition, data_type: 'datetime', virtual_search_query: "SELECT NOW()", virtual_value_query: "SELECT NOW()")

          sc = described_class.new(model_field_uid: "*cf_#{cdef.id}", operator: "gt", value: (Time.zone.now.to_date - 1.day).to_s)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
          expect(sc.test?(product)).to eq true
        end
      end

      context "normal_field" do
        it "processes value before search" do
          t = create(:tariff_record, hts_1: "9801001010")
          sc = described_class.new(model_field_uid: :hts_hts_1, operator: "eq", value: "9801.00.1010")
          v = sc.apply(TariffRecord.where("1=1"))
          expect(v.all).to include t
        end

        it "finds something created last month with val = 1" do
          product.update(created_at: 1.month.ago)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).to include product
        end

        it "does not find something created in the future" do
          product.update(created_at: 1.month.from_now)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
          v = sc.apply(Product.where("1=1"))
          expect(v.all).not_to include product
        end

        it "does not find something created this month with val = 1" do
          product.update(created_at: 0.seconds.ago)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
          expect(sc.apply(Product.where("1=1")).all).not_to include product
        end

        it "does not find something created two months ago with val = 1" do
          product.update(created_at: 2.months.ago)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 1)
          expect(sc.apply(Product.where("1=1")).all).not_to include product
        end

        it "finds something created last month with val = 2" do
          product.update(created_at: 1.month.ago)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 2)
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "finds something created two months ago with val 2" do
          product.update(created_at: 2.months.ago)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "pm", value: 2)
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "finds something with a nil date and include_empty" do
          # Need to use an order since there are no nullable datetime fields on a product
          order = create(:order)
          sc = described_class.new(model_field_uid: :ord_closed_at, operator: "pm", value: 2)
          sc.include_empty = true
          expect(sc.apply(Order.all)).to include order
        end

        it "finds a product when there is a regex match on the appropriate text field" do
          product.update(unique_identifier: "Blue jeans")
          sc = described_class.new(model_field_uid: :prod_uid, operator: "regexp", value: "jean")
          expect(sc.apply(Product.where("1=1")).all).to include product
          expect(sc.test?(product)).to be_truthy
        end

        it "does not find a product when there is not a regex match on the appropriate text field" do
          product.update(unique_identifier: "Blue jeans")
          sc = described_class.new(model_field_uid: :prod_uid, operator: "regexp", value: "khaki")
          expect(sc.apply(Product.where("1=1")).all).not_to include product
          expect(sc.test?(product)).to be_falsey
        end

        it "finds a product when there is a NOT regex match on the appropriate text field" do
          product.update(unique_identifier: "Blue jeans")
          sc = described_class.new(model_field_uid: :prod_uid, operator: "notregexp", value: "shirt")
          expect(sc.apply(Product.where("1=1")).all).to include product
          expect(sc.test?(product)).to be_truthy
        end

        it "does not find a product when there is a NOT regex match on the appropriate text field" do
          product.update(unique_identifier: "Blue shirt")
          sc = described_class.new(model_field_uid: :prod_uid, operator: "notregexp", value: "shirt")
          expect(sc.apply(Product.where("1=1")).all).not_to include product
          expect(sc.test?(product)).to be_falsey
        end

        it "finds an entry when there is a regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = create(:entry, eta_date: '2013-02-03')

          sc = described_class.new(model_field_uid: :ent_eta_date, operator: "dt_regexp", value: "-02-")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy

          sc = described_class.new(model_field_uid: :ent_eta_date, operator: "dt_regexp", value: "[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy
        end

        it "finds an entry when there is a not regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = create(:entry, eta_date: '2013-02-03')

          sc = described_class.new(model_field_uid: :ent_eta_date, operator: "dt_notregexp", value: "1999")
          expect(sc.apply(Entry.where("1=1")).all).to include e
          expect(sc.test?(e)).to be_truthy
        end

        it "does not find an entry when there is a not regex match on the appropriate date field" do
          # Using entry because it has an actual date field in it
          e = create(:entry, eta_date: '2013-02-03')

          sc = described_class.new(model_field_uid: :ent_eta_date, operator: "dt_notregexp", value: "2013")
          expect(sc.apply(Entry.where("1=1")).all).not_to include e
          expect(sc.test?(e)).to be_falsey
        end

        it "finds a product when regex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this.
          product.update(created_at: Time.zone.now)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_regexp", value: Time.zone.now.year.to_s)
          expect(sc.test?(product)).to be_truthy

          Time.use_zone("Eastern Time (US & Canada)") do
            product.update(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            # Note the day in the regex is the day before what we set in the created_at attribute
            sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_regexp", value: "02-02")
            expect(sc.test?(product)).to be_truthy
          end
        end

        it "finds a product when notregex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this
          product.update(created_at: Time.zone.now)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_notregexp", value: "1999")
          expect(sc.test?(product)).to be_truthy

          Time.use_zone("Eastern Time (US & Canada)") do
            product.update(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_notregexp", value: "02-03")
            expect(sc.test?(product)).to be_truthy
          end
        end

        it "does not find a product when notregex on datetime field" do
          # Because of the way we use the mysql function convert_tz (which only works in prod due to having to setup the full timezone support in the database)
          # we're only testing the test? method for this
          product.update(created_at: Time.zone.now)
          sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_notregexp", value: Time.zone.now.year.to_s)
          expect(sc.test?(product)).to be_falsey

          Time.use_zone("Eastern Time (US & Canada)") do
            product.update(created_at: ActiveSupport::TimeZone["UTC"].parse("2013-02-03 04:05"))
            sc = described_class.new(model_field_uid: :prod_created_at, operator: "dt_notregexp", value: "02-02")
            expect(sc.test?(product)).to be_falsey
          end
        end

        it "finds a product when there is a regex match on the appropriate integer field" do
          product.attachments << create(:attachment)
          sc = described_class.new(model_field_uid: :prod_attachment_count, operator: "regexp", value: "1")
          expect(sc.apply(Product.where("1=1")).all).to include product
          expect(sc.test?(product)).to be_truthy
        end

        it "finds a product when there is a regex match on the appropriate integer field" do
          product.attachments << create(:attachment)
          sc = described_class.new(model_field_uid: :prod_attachment_count, operator: "notregexp", value: "0")
          expect(sc.apply(Product.where("1=1")).all).to include product
          expect(sc.test?(product)).to be_truthy
        end

        it "finds something with a nil string and include_empty" do
          product.update(name: nil)
          sc = described_class.new(model_field_uid: :prod_name, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "finds something with a blank string and include_empty" do
          product.update(name: '   ')
          sc = described_class.new(model_field_uid: :prod_name, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "finds something with 0 integer value and include_empty" do
          entry = create(:entry)
          entry.update(total_packages: 0)
          sc = described_class.new(model_field_uid: :ent_total_packages, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "finds an entry with a decimal value and a regex match" do
          entry = create(:entry)
          entry.update(total_fees: 123.45)
          sc = described_class.new(model_field_uid: :ent_total_fees, operator: "regexp", value: "123")
          sc.apply(Entry.where("1=1")).to_sql
          expect(sc.apply(Entry.where("1=1")).all).to include entry
          expect(sc.test?(entry)).to be_truthy
        end

        it "finds something with 0 decimal value and include_empty" do
          entry = create(:entry)
          entry.update(total_fees: 0.0)
          sc = described_class.new(model_field_uid: :ent_total_fees, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "finds something with blank text value and include_empty" do
          entry = create(:entry)
          entry.update(sub_house_bills_of_lading: '   ')
          sc = described_class.new(model_field_uid: :ent_sbols, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "finds something with NOT IN operator" do
          sc = described_class.new(model_field_uid: :prod_uid, operator: "notin", value: "val\nval2")
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "does not find something with NOT IN operator" do
          # Leave some whitespace in so we know it's getting trimmed out
          sc = described_class.new(model_field_uid: :prod_uid, operator: "notin", value: "#{product.unique_identifier}   ")
          expect(sc.apply(Product.where("1=1")).all).not_to include product
        end

        it "finds something with an include empty search parameter on a child object, even if the child object doesn't exist" do
          entry = create(:entry)
          sc = described_class.new(model_field_uid: :ci_invoice_number, operator: "eq", value: "1")
          sc.include_empty = true
          expect(sc.apply(Entry.where("1=1")).all).to include entry
        end

        it "finds something with doesn't start with parameter" do
          sc = described_class.new(model_field_uid: :prod_uid, operator: "nsw", value: "ABC123")
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "doesn't find something with doesn't start with parameter" do
          sc = described_class.new(model_field_uid: :prod_uid, operator: "nsw", value: product.unique_identifier[0..2])
          expect(sc.apply(Product.where("1=1")).all).not_to include product
        end

        it "finds something with doesn't end with parameter" do
          sc = described_class.new(model_field_uid: :prod_uid, operator: "new", value: "ABC123")
          expect(sc.apply(Product.where("1=1")).all).to include product
        end

        it "doesn't find something with doesn't start with parameter" do
          sc = described_class.new(model_field_uid: :prod_uid, operator: "new", value: product.unique_identifier[-3..-1])
          expect(sc.apply(Product.where("1=1")).all).not_to include product
        end
      end
    end
  end

  context "Before _ Months Ago" do
    let(:search_criterion) do
      described_class.new(model_field_uid: :prod_created_at, operator: "bma", value: 1)
    end

    context "test?" do
      let(:search_criterion_2) { described_class.new(model_field_uid: :pro_start_date, operator: "bma", value: 1) }
      let(:rate_override) { create(:product_rate_override, product_id: product.id) }

      it "accepts product created prior to first of the previous month" do
        product.created_at = 2.months.ago.end_of_month
        expect(search_criterion.test?(product)).to be_truthy

        rate_override.start_date = 2.months.ago.end_of_month
        expect(search_criterion_2.test?(rate_override)).to be_truthy
      end

      it "does not accept product created on first of the previous month" do
        product.created_at = 1.month.ago.beginning_of_month.at_midnight
        expect(search_criterion.test?(product)).to be_falsey

        rate_override.start_date = 1.month.ago.beginning_of_month.at_midnight
        expect(search_criterion_2.test?(rate_override)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created prior to first of the previous month" do
        product.update created_at: 2.months.ago.end_of_month
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created on the first of the previous month" do
        product.update created_at: 1.month.ago.beginning_of_month.at_midnight
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "After _ Months Ago" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "ama", value: 1) }

    context "test?" do
      let(:search_criterion_2) { described_class.new(model_field_uid: :pro_start_date, operator: "ama", value: 1) }
      let(:rate_override) { create(:product_rate_override, product_id: product.id) }

      it "accepts product created after the first of the previous month" do
        product.created_at = Time.zone.now.beginning_of_month.at_midnight
        expect(search_criterion.test?(product)).to be_truthy

        rate_override.start_date = Time.zone.now.beginning_of_month.at_midnight
        expect(search_criterion_2.test?(rate_override)).to be_truthy
      end

      it "does not accept product created prior to the first of the previous month" do
        product.created_at = (Time.zone.now.beginning_of_month.at_midnight - 1.second)
        expect(search_criterion.test?(product)).to be_falsey

        rate_override.start_date = (Time.zone.now.beginning_of_month.at_midnight - 1.second)
        expect(search_criterion_2.test?(rate_override)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created prior to first of the previous month" do
        product.update created_at: Time.zone.now.beginning_of_month.at_midnight
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created prior to the first of the previous month" do
        product.update created_at: (Time.zone.now.beginning_of_month.at_midnight - 1.second)
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "After _ Months From Now" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "amf", value: 1) }

    context "test?" do
      let(:search_criterion_2) { described_class.new(model_field_uid: :pro_start_date, operator: "amf", value: 1) }
      let(:rate_override) { create(:product_rate_override, product_id: product.id) }

      it "accepts product created after 1 month from now" do
        product.created_at = (Time.zone.now.beginning_of_month + 2.months).at_midnight
        expect(search_criterion.test?(product)).to be_truthy

        rate_override.start_date = (Time.zone.now.beginning_of_month + 2.months).at_midnight
        expect(search_criterion_2.test?(rate_override)).to be_truthy
      end

      it "does not accept product created on last of the next month" do
        product.created_at = ((Time.zone.now.beginning_of_month + 2.months).at_midnight - 1.second)
        expect(search_criterion.test?(product)).to be_falsey

        rate_override.start_date = ((Time.zone.now.beginning_of_month + 2.months).at_midnight - 1.second)
        expect(search_criterion_2.test?(rate_override)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created after 1 month from now" do
        product.update created_at: (Time.zone.now.beginning_of_month + 2.months).at_midnight
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created on last of the next month" do
        product.update created_at: ((Time.zone.now.beginning_of_month + 2.months).at_midnight - 1.second)
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Before _ Months From Now" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "bmf", value: 1) }

    context "test?" do
      let(:search_criterion_2) { described_class.new(model_field_uid: :pro_start_date, operator: "bmf", value: 1) }
      let(:rate_override) { create(:product_rate_override, product_id: product.id) }

      it "accepts product created before 1 month from now" do
        product.created_at = ((Time.zone.now.beginning_of_month + 1.month).at_midnight - 1.second)
        expect(search_criterion.test?(product)).to be_truthy

        rate_override.start_date = ((Time.zone.now.beginning_of_month + 1.month).at_midnight - 1.second)
        expect(search_criterion_2.test?(rate_override)).to be_truthy
      end

      it "does not accept product created on first of the next month" do
        product.created_at = (Time.zone.now.beginning_of_month + 1.month).at_midnight
        expect(search_criterion.test?(product)).to be_falsey

        rate_override.start_date = (Time.zone.now.beginning_of_month + 1.month).at_midnight
        expect(search_criterion_2.test?(rate_override)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created before 1 month from now" do
        product.update created_at: ((Time.zone.now.beginning_of_month + 1.month).at_midnight - 1.second)
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created before 1 month from now" do
        product.update created_at: (Time.zone.now.beginning_of_month + 1.month).at_midnight
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Current Month" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "cmo") }

    context "test?" do
      it "accepts product created during this month" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not accept product created last month" do
        product.created_at = 1.month.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product that will be created next month" do
        product.created_at = 1.month.from_now
        expect(search_criterion.test?(product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created during this month" do
        product.update created_at: 1.second.ago
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created last month" do
        product.update created_at: 1.month.ago
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product that will be created next month" do
        product.update created_at: 1.month.from_now
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Previous _ Quarters" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "pqu", value: 2) }

    context "test?" do
      it "accepts product created during the previous quarter" do
        product.created_at = described_class.get_previous_quarter_start_date(Time.zone.now, 1)
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "accepts product created during the quarter preceding the previous quarter" do
        product.created_at = described_class.get_previous_quarter_start_date(Time.zone.now, 2)
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not accept product created during the current quarter" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product created during the quarter preceding the previous two quarters" do
        product.created_at = described_class.get_previous_quarter_start_date(Time.zone.now, 3)
        expect(search_criterion.test?(product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created during the previous quarter" do
        product.update created_at: described_class.get_previous_quarter_start_date(Time.zone.now, 1)
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "finds product created during the quarter preceding the previous quarter" do
        product.update created_at: described_class.get_previous_quarter_start_date(Time.zone.now, 2)
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created during the current quarter" do
        product.update created_at: 1.second.ago
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product created during the quarter preceding the previous two quarters" do
        product.update created_at: described_class.get_previous_quarter_start_date(Time.zone.now, 3)
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Current Quarter" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "cqu") }

    context "test?" do
      it "accepts product created during this quarter" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not accept product created last quarter" do
        product.created_at = (described_class.get_quarter_start_date(described_class.get_quarter_number(Time.zone.now), Time.zone.now.year).to_date - 1.day).to_date
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product that will be created during a future quarter" do
        product.created_at = described_class.get_next_quarter_start_date(Time.zone.now, 1)
        expect(search_criterion.test?(product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created during this quarter" do
        product.update created_at: 1.second.ago
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created last quarter" do
        product.update created_at: (described_class.get_quarter_start_date(described_class.get_quarter_number(Time.zone.now), Time.zone.now.year).to_date - 1.day).to_date
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product that will be created during a future quarter" do
        product.update created_at: described_class.get_next_quarter_start_date(Time.zone.now, 1)
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Previous _ Full Calendar Years" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "pfcy", value: 2) }

    context "test?" do
      it "accepts product created during the previous year" do
        product.created_at = 1.year.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "accepts product created two years ago" do
        product.created_at = 2.years.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "accepts product created two years ago where date occurs in an earlier month within that year than today" do
        Timecop.freeze(DateTime.new(2018, 4, 15)) do
          product.created_at = DateTime.new(2016, 3, 5)
          expect(search_criterion.test?(product)).to be_truthy
        end
      end

      it "does not accept product created during the current year" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product created three years ago" do
        product.created_at = 3.years.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product that will be created in the future" do
        product.created_at = 1.year.from_now
        expect(search_criterion.test?(product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created during the previous year" do
        product.update created_at: 1.year.ago
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "finds product created two years ago" do
        product.update created_at: 2.years.ago
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "finds product created two years ago where date occurs in an earlier month within that year than today" do
        Timecop.freeze(DateTime.new(2018, 4, 15)) do
          product.update created_at: DateTime.new(2016, 3, 5)
          expect(search_criterion.apply(Product.where("1=1")).all).to include product
        end
      end

      it "does not find product created during the current year" do
        product.update created_at: 1.second.ago
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product created three years ago" do
        product.update created_at: 3.years.ago
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product that will be created in the future" do
        product.update created_at: 1.year.from_now
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "Current Year To Date" do
    let(:search_criterion) { described_class.new(model_field_uid: :prod_created_at, operator: "cytd") }

    context "test?" do
      it "accepts product created during this year" do
        product.created_at = 1.second.ago
        expect(search_criterion.test?(product)).to be_truthy
      end

      it "does not accept product created last year" do
        product.created_at = 1.year.ago
        expect(search_criterion.test?(product)).to be_falsey
      end

      it "does not accept product that will be created at a later date this year" do
        product.created_at = 1.minute.from_now
        expect(search_criterion.test?(product)).to be_falsey
      end
    end

    context "apply" do
      it "finds product created during this year" do
        product.update created_at: 1.day.ago
        expect(search_criterion.apply(Product.where("1=1")).all).to include product
      end

      it "does not find product created last year" do
        product.update created_at: 1.year.ago
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end

      it "does not find product that will be created at a later date this year" do
        product.update created_at: 1.minute.from_now
        expect(search_criterion.apply(Product.where("1=1")).all).not_to include product
      end
    end
  end

  context "get_quarter_number" do
    it "determines the quarter for a date" do
      expect(described_class.get_quarter_number(Date.new(2015, 10, 1))).to eq(4)
      expect(described_class.get_quarter_number(Date.new(2017, 2, 5))).to eq(1)
      expect(described_class.get_quarter_number(Date.new(2016, 1, 15))).to eq(1)
      expect(described_class.get_quarter_number(Date.new(2017, 8, 4))).to eq(3)
      expect(described_class.get_quarter_number(Date.new(2017, 5, 13))).to eq(2)
    end
  end

  context "get_quarter_start_date" do
    it "determines the start date of a quarter" do
      expect(described_class.get_quarter_start_date(4, 2015)).to eq(Date.new(2015, 10, 1))
      expect(described_class.get_quarter_start_date(1, 2017)).to eq(Date.new(2017, 1, 1))
      expect(described_class.get_quarter_start_date(1, 2016)).to eq(Date.new(2016, 1, 1))
      expect(described_class.get_quarter_start_date(3, 2017)).to eq(Date.new(2017, 7, 1))
      expect(described_class.get_quarter_start_date(2, 2017)).to eq(Date.new(2017, 4, 1))
    end
  end

  context "get_previous_quarter_start_date" do
    it "determines the start of a previous quarter" do
      expect(described_class.get_previous_quarter_start_date(Date.new(2015, 10, 1), 1)).to eq(Date.new(2015, 7, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2017, 2, 5), 1)).to eq(Date.new(2016, 10, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2016, 1, 15), 3)).to eq(Date.new(2015, 4, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2017, 8, 4), 4)).to eq(Date.new(2016, 7, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2017, 8, 4), 8)).to eq(Date.new(2015, 7, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2017, 5, 13), 1)).to eq(Date.new(2017, 1, 1))
      expect(described_class.get_previous_quarter_start_date(Date.new(2018, 1, 2), 2)).to eq(Date.new(2017, 7, 1))
    end
  end

  context "get_next_quarter_start_date" do
    it "determines the start of a following quarter" do
      expect(described_class.get_next_quarter_start_date(Date.new(2015, 10, 1), 1)).to eq(Date.new(2016, 1, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2017, 2, 5), 1)).to eq(Date.new(2017, 4, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2016, 1, 15), 3)).to eq(Date.new(2016, 10, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2017, 8, 4), 4)).to eq(Date.new(2018, 7, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2017, 8, 4), 8)).to eq(Date.new(2019, 7, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2017, 5, 13), 1)).to eq(Date.new(2017, 7, 1))
      expect(described_class.get_next_quarter_start_date(Date.new(2017, 7, 2), 2)).to eq(Date.new(2018, 1, 1))
    end
  end

  context "string field IN list" do
    it "finds something using a string field from a list of values using unix newlines" do
      sc = described_class.new(model_field_uid: :prod_uid, operator: "in", value: "val\n#{product.unique_identifier}\nval2")
      expect(sc.apply(Product.where("1=1")).all).to include product
    end

    it "finds something using a string field from a list of values using windows newlines" do
      sc = described_class.new(model_field_uid: :prod_uid, operator: "in", value: "val\r\n#{product.unique_identifier}\r\nval2")
      expect(sc.apply(Product.where("1=1")).all).to include product
    end

    it "does not add blank strings in the IN list when using windows newlines" do
      sc = described_class.new(model_field_uid: :prod_uid, operator: "in", value: "val\r\n#{product.unique_identifier}\r\nval2")
      expect(sc.apply(Product.where("1=1")).to_sql).to match(/\('val',\s?'#{product.unique_identifier}',\s?'val2'\)/)
    end

    it "finds something using a numeric field from a list of values" do
      sc = described_class.new(model_field_uid: :prod_class_count, operator: "in", value: "1\n0\r\n3")
      expect(sc.apply(Product.where("1=1")).all).to include product
    end

    it "finds something with a blank value provided a blank IN list value" do
      # Without the added code backing what's in this test, the query produced for a blank IN list value would be IN (null),
      # but after the change it's IN (''), which is more in line with what the user is requesting if they left the value blank.
      product.update name: ""
      sc = described_class.new(model_field_uid: :prod_name, operator: "in", value: "")
      expect(sc.apply(Product.where("1=1")).all).to include product
    end
  end

  context 'date time field' do
    it "properlies handle not null" do
      u = create(:master_user)
      cd = create(:custom_definition, module_type: 'Product', data_type: 'date')
      product.update_custom_value! cd, Time.zone.now
      create(:product)
      p3 = create(:product)
      p3.custom_values.create!(custom_definition_id: cd.id)
      ss = SearchSetup.new(module_type: 'Product', user: u)
      ss.search_criterions.new(model_field_uid: "*cf_#{cd.id}", operator: 'notnull')
      sq = SearchQuery.new ss, u
      h = sq.execute
      expect(h.collect {|r| r[:row_key]}).to eq([product.id])
    end

    it "properlies handle null" do
      u = create(:master_user)
      cd = create(:custom_definition, module_type: 'Product', data_type: 'date')
      product.update_custom_value! cd, Time.zone.now
      p2 = create(:product)
      p3 = create(:product)
      p3.custom_values.create!(custom_definition_id: cd.id)
      ss = SearchSetup.new(module_type: 'Product', user: u)
      ss.search_criterions.new(model_field_uid: "*cf_#{cd.id}", operator: 'null')
      sq = SearchQuery.new ss, u
      h = sq.execute
      expect(h.collect {|r| r[:row_key]}.sort).to eq([p2.id, p3.id])
    end

    it "translates datetime values to UTC for lt operator" do
      # Run these as central timezone
      tz = "Hawaii"
      date = "2013-01-01"
      value = date + " " + tz
      expected_value = Time.use_zone(tz) do
        Time.zone.parse(date).utc.to_formatted_s(:db)
      end

      sc = described_class.new(model_field_uid: :prod_created_at, operator: "lt", value: value)
      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)
    end

    it "translates datetime values to UTC for gt, geteq operator" do
      ['gt', 'gteq'].each do |op|
        # Make sure we're also allowing actual time values as well
        tz = "Hawaii"
        date = "2012-01-01 07:08:09"
        value = date + " " + tz
        expected_value = Time.use_zone(tz) do
          Time.zone.parse(date).utc.to_formatted_s(:db)
        end
        sc = described_class.new(model_field_uid: :prod_created_at, operator: op, value: value)
        sql = sc.apply(Product.where("1=1")).to_sql
        expect(sql).to match(/#{expected_value}/)
      end
    end

    it "returns false for nil values for comparison operators" do
      ent = Entry.new
      ["co", "nc", "sw", "ew", "gt", "gteq", "lt", "bda", "ada", "adf", "bdf", "pm", "bma", "ama", "amf", "bmf", "cmo", "pqu", "cqu", "pfcy", "cytd"].each do |op|
        sc = described_class.new(model_field_uid: :ent_file_logged_date, value: '2016-01-01')
        sc.operator = op
        expect(sc.test?(ent)).to be_falsey
        sc.include_empty = true
        expect(sc.test?(ent)).to be_truthy
      end
    end

    it "translates datetime values to UTC for eq operator" do
      # Make sure that if the timezone is not in the value, that we add eastern timezone to it
      value = "2012-01-01"
      sc = described_class.new(model_field_uid: :prod_created_at, operator: "eq", value: value)
      expected_value = Time.use_zone("Eastern Time (US & Canada)") do
        Time.zone.parse(value + " 00:00:00").utc.to_formatted_s(:db)
      end

      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)

      # verify the nq operator is translated too
      sc.operator = "nq"
      expect(sc.apply(Product.where("1=1")).to_sql).to match(/#{expected_value}/)
    end

    it "does not translate date values to UTC for lt, gt, gteq, or eq operators" do
      value = "2012-01-01"
      # There's no actual date field in product, we'll use Entry.duty_due_date instead
      sc = described_class.new(model_field_uid: :ent_duty_due_date, operator: "eq", value: value)
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)

      sc.operator = "lt"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)

      sc.operator = "gteq"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)

      sc.operator = "gt"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/#{value}/)
    end

    it "does not translate datetime values to UTC for any operator other than lt, gt, eq, or nq" do
      sc = described_class.new(model_field_uid: :prod_created_at, operator: "bda", value: 10)
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "ada"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "bdf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "adf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "pm"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/10/)

      sc.operator = "null"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/NULL/)

      sc.operator = "notnull"
      expect(sc.apply(Entry.where("1=1")).to_sql).to match(/NOT NULL/)
    end

    it "uses current timezone to compare object field" do
      ['gt', 'gteq'].each do |op|
        tz = "Hawaii"
        date = "2013-01-01"
        value = date + " " + tz

        sc = described_class.new(model_field_uid: :prod_created_at, operator: op, value: value)
        p = Product.new
        # Hawaii is 10 hours behind UTC so adjust our created at to make sure
        # the offset is being calculated
        p.created_at = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 10:01"

        Time.use_zone(tz) do
          expect(sc.test?(p)).to be_truthy
          p.created_at = ActiveSupport::TimeZone["UTC"].parse "2013-01-01 09:59"
          expect(sc.test?(p)).to be_falsey
        end
      end
    end

    it "utilize's users current time in UTC when doing days/months comparison against date time fields" do
      sc = described_class.new(model_field_uid: :prod_created_at, operator: "bda", value: 1)
      now = Time.zone.now.in_time_zone 'Hawaii'
      allow(Time.zone).to receive(:now).and_return now

      current_time = "'#{now.at_midnight.in_time_zone("UTC").strftime("%Y-%m-%d %H:%M:%S")}'"

      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time

      sc.operator = "ada"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "adf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bdf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bma"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "ama"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "amf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "bmf"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
      sc.operator = "pm"
      expect(sc.apply(Product.where("1=1")).to_sql).to include current_time
    end

    it "utilize's users current date when doing days/months comparison against date fields" do
      sc = described_class.new(model_field_uid: :ent_export_date, operator: "bda", value: 1)
      now = Time.zone.now.in_time_zone 'Hawaii'
      allow(Time.zone).to receive(:now).and_return now

      current_date = "'#{now.at_midnight.strftime("%Y-%m-%d %H:%M:%S")}'"

      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date

      sc.operator = "ada"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "adf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bdf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bma"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "ama"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "amf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "bmf"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
      sc.operator = "pm"
      expect(sc.apply(Entry.where("1=1")).to_sql).to include current_date
    end
  end

  context 'boolean custom field' do
    let(:definition) { create(:custom_definition, data_type: 'boolean') }
    let(:custom_value) { product.get_custom_value definition }

    context 'Is Empty' do
      let(:search_criterion) do
        described_class.create!(model_field_uid: "*cf_#{definition.id}", operator: "null", value: '')
      end

      it 'returns for Is Empty and false' do
        custom_value.value = false
        custom_value.save!
        expect(search_criterion.apply(Product)).to include product
        expect(search_criterion.test?(product)).to eq(true)
      end

      it 'returns for Is Empty and nil' do
        custom_value.value = nil
        custom_value.save!
        expect(search_criterion.apply(Product)).to include product
        expect(search_criterion.test?(product)).to eq(true)
      end

      it 'does not return for Is Empty and true' do
        custom_value.value = true
        custom_value.save!
        expect(search_criterion.apply(Product)).not_to include product
        expect(search_criterion.test?(product)).to eq(false)
      end

      context "string_handling" do
        let!(:entry) { create(:entry, broker_reference: ' ') }
        let(:search_criterion) { described_class.new(model_field_uid: 'ent_brok_ref', operator: 'null') }

        it "returns on empty string" do
          expect(search_criterion.apply(Entry).to_a).to eq [entry]
          entry.update(broker_reference: 'x')
          expect(search_criterion.apply(Entry)).to be_empty
        end

        it "tests on empty string" do
          expect(search_criterion.test?(entry)).to be_truthy
          entry.update(broker_reference: 'x')
          expect(search_criterion.test?(entry)).to be_falsey
        end
      end
    end

    context 'Is Not Empty' do
      let(:search_criterion) do
        described_class.create!(model_field_uid: "*cf_#{definition.id}", operator: "notnull", value: '')
      end

      it 'returns for Is Not Empty and true' do
        custom_value.value = true
        custom_value.save!
        expect(search_criterion.apply(Product)).to include product
        expect(search_criterion.test?(product)).to eq(true)
      end

      it 'does not return for Is Not Empty and false' do
        custom_value.value = false
        custom_value.save!
        expect(search_criterion.apply(Product)).not_to include product
        expect(search_criterion.test?(product)).to eq(false)
      end

      it 'does not return for Is Not Empty and nil' do
        custom_value.value = nil
        custom_value.save!
        expect(search_criterion.apply(Product)).not_to include product
        expect(search_criterion.test?(product)).to eq(false)
      end

      it 'returns for Is Not Empty, include_empty and nil' do
        custom_value.value = nil
        custom_value.save!
        search_criterion.include_empty = true
        expect(search_criterion.apply(Product)).to include product
        expect(search_criterion.test?(product)).to eq(true)
      end

      context "string_handling" do
        let!(:entry) { create(:entry, broker_reference: 'x') }
        let(:search_criterion) { described_class.new(model_field_uid: 'ent_brok_ref', operator: 'notnull') }

        it "returns on empty string" do
          expect(search_criterion.apply(Entry).to_a).to eq [entry]
          entry.update(broker_reference: ' ')
          expect(search_criterion.apply(Entry)).to be_empty
        end

        it "tests on empty string" do
          expect(search_criterion.test?(entry)).to be_truthy
          entry.update(broker_reference: ' ')
          expect(search_criterion.test?(entry)).to be_falsey
        end
      end
    end
  end

  context "not starts with" do
    it "tests for strings not starting with" do
      sc = described_class.new(model_field_uid: 'prod_uid', operator: 'nsw', value: "ZZZZZZZZZ")
      expect(sc.test?(product)).to be_truthy
      expect(sc.apply(Product).all).to eq [product]

      sc.value = product.unique_identifier
      expect(sc.test?(product)).to be_falsey
      expect(sc.apply(Product).all).to eq []
    end

    it "tests for numbers not starting with" do
      ent = create(:entry, total_packages: 10)
      sc = described_class.new(model_field_uid: 'ent_total_packages', operator: 'nsw', value: "9")

      expect(sc.test?(ent)).to be_truthy
      expect(sc.apply(Entry).all).to eq [ent]

      sc.value = 1
      expect(sc.test?(ent)).to be_falsey
      expect(sc.apply(Entry).all).to eq []
    end
  end

  context "not ends with" do
    it "tests for strings not ending with" do
      sc = described_class.new(model_field_uid: 'prod_uid', operator: 'new', value: "ZZZZZZZZZ")
      expect(sc.test?(product)).to be_truthy
      expect(sc.apply(Product).all).to eq [product]

      sc.value = product.unique_identifier[-2..-1]
      expect(sc.test?(product)).to be_falsey
      expect(sc.apply(Product).all).to eq []
    end

    it "tests for numbers not ending with" do
      ent = create(:entry, total_packages: 10)
      sc = described_class.new(model_field_uid: 'ent_total_packages', operator: 'new', value: "9")

      expect(sc.test?(ent)).to be_truthy
      expect(sc.apply(Entry).all).to eq [ent]

      sc.value = 0
      expect(sc.test?(ent)).to be_falsey
      expect(sc.apply(Entry).all).to eq []
    end
  end

  context "hierarchical behavior of #test?" do
    let!(:entry) { create(:entry)}
    let!(:ci1) { create(:commercial_invoice, entry: entry) }
    let!(:cil1_1) { create(:commercial_invoice_line, commercial_invoice: ci1, cotton_fee: 100) }
    let(:cit1_1_1) { create(:commercial_invoice_tariff, commercial_invoice_line: cil1_1)}
    let(:cit1_1_2) { create(:commercial_invoice_tariff, commercial_invoice_line: cil1_1)}
    let!(:mf) { ModelField.by_uid :cil_cotton_fee }
    let!(:sc) { create(:search_criterion, model_field_uid: "cil_cotton_fee", operator: "eq", value: 100)}

    it "applies standard test to object's children" do
      expect(sc.test?(entry)).to eq true
    end

    it "applies decimal test to object's children" do
      cil = entry.commercial_invoice_lines.first
      cil.update! value: 10, contract_amount: 5
      sc.update! model_field_uid: "cil_value", operator: "eqfdec", value: 100, secondary_model_field_uid: "cil_contract_amount"
      entry.reload
      expect(sc.test?(entry)).to eq true
    end

    context "relative" do
      before do
        entry.update! other_fees: 100
        sc.update! operator: "eqf", model_field_uid: "ent_other_fees", value: "cil_cotton_fee"
      end

      it "compares fields within same hierarchy" do
        expect(sc.test?(entry)).to eq true
      end

      it "compares fields across hierarchies" do
        cil2 = create(:commercial_invoice_line, cotton_fee: 100)
        expect(sc.test?([entry, cil2.commercial_invoice.entry])).to eq true
      end
    end

    # It's difficult/impossible to check which records have been tested through the public interface.
    # Hence the specs here for two private methods.
    describe "compare_one_field" do
      it "stops yielding after last testable field has been reached" do
        tested = []
        block = proc { |obj_descendant| tested << obj_descendant; false }

        sc.send(:compare_one_field, mf, entry, &block)
        expect(tested).to eq [cil1_1]
      end
    end

    describe "compare_two_fields" do
      let!(:cil1_2) { create(:commercial_invoice_line, commercial_invoice: ci1) }
      let(:cit1_2_1) { create(:commercial_invoice_tariff, commercial_invoice_line: cil1_2) }
      let(:cit1_2_2) { create(:commercial_invoice_tariff, commercial_invoice_line: cil1_2) }

      let!(:ci2) { create(:commercial_invoice, entry: entry) }

      context "single hierarchy" do
        it "stops yielding after last field testable fields have been reached" do
          tested = []
          block = proc { |obj1_descendant, obj2_descendant| tested << {obj1: obj1_descendant, obj2: obj2_descendant}; false }
          mf_base = ModelField.by_uid :ci_invoice_value

          sc.send(:compare_two_fields, mf_base, entry, mf, entry, &block)
          expect(tested).to eq([{obj1: ci1, obj2: cil1_1}, {obj1: ci1, obj2: cil1_2}, {obj1: ci2, obj2: cil1_1}, {obj1: ci2, obj2: cil1_2}])
        end
      end

      context "two hierarchies" do
        let(:entry2) { create(:entry)}
        let(:ci_ent2) { create(:commercial_invoice, entry: entry2) }
        let!(:cil_ent2) { create(:commercial_invoice_line, commercial_invoice: ci_ent2) }
        let(:cit_ent2) { create(:commercial_invoice_tariff, commercial_invoice_line: cil_ent2)}

        it "stops yielding after last testable fields have been reached" do
          tested = []
          block = proc { |obj1_descendant, obj2_descendant| tested << {obj1: obj1_descendant, obj2: obj2_descendant}; false }
          mf_base = ModelField.by_uid :ci_invoice_value

          sc.send(:compare_two_fields, mf_base, entry, mf, entry2, &block)

          expect(tested).to eq([{obj1: ci1, obj2: cil_ent2}, {obj1: ci2, obj2: cil_ent2}])
        end
      end
    end
  end
end
