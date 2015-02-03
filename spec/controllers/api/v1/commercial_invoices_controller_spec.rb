require 'spec_helper'

describe Api::V1::CommercialInvoicesController do
  before(:each) do
    MasterSetup.get.update_attributes(entry_enabled:true)
    @u = Factory(:user,commercial_invoice_edit:true,commercial_invoice_view:true)
    @u.company.update_attributes(importer:true,system_code:'SYS')
    allow_api_access @u
  end
  describe 'index' do
    before(:each) do
      2.times {|i| Factory(:commercial_invoice,invoice_number:"#{i}ci",importer:@u.company)}
    end
    it "should find invoices" do
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      res = j['results']
      expect(res.size).to eql 2
      expect(res[0]['ci_invoice_number']).to eql '0ci'
      expect(res[1]['ci_invoice_number']).to eql '1ci'
    end
    it "should default to page 1" do
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['page']).to eql 1
    end
    it "should default to 10 per page" do
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['per_page']).to eql 10
    end
    it "should limit to 50 per page when larger value passed" do
      get :index, {'per_page'=>'100'}
      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['per_page']).to eql 50
    end
    it "should apply pagination" do
      get :index, {'per_page'=>'1','page'=>'2'}
      expect(response).to be_success
      j = JSON.parse response.body
      res = j['results']
      expect(res.size).to eql 1
      expect(res[0]['ci_invoice_number']).to eql '1ci'
    end
    it "should apply search criterions" do
      Factory(:commercial_invoice,invoice_number:'1xz',importer:@u.company)
      get :index, {'sid1'=>'ci_invoice_number','sop1'=>'sw','sv1'=>'1',
        'sid2'=>'ci_invoice_number','sop2'=>'ew','sv2'=>'i'}
      expect(response).to be_success
      j = JSON.parse response.body
      res = j['results']
      expect(res.size).to eql 1
      expect(res[0]['ci_invoice_number']).to eql '1ci'
    end
    it "should throw error for search criterions that don't match core module" do
      get :index, {'sid1'=>'cil_part_number','sop1'=>'sw','sv1'=>'1'}
      expect(response.status).to eql 400
      expect(JSON.parse(response.body)['errors'].first).to eql "Search field cil_part_number is for incorrect module."
    end
    it "should apply sort criterions" do
      get :index, {'oid1'=>'ci_invoice_number','oo1'=>'D'}
      expect(response).to be_success
      j = JSON.parse response.body
      res = j['results']
      expect(res.size).to eql 2
      expect(res[0]['ci_invoice_number']).to eql '1ci'
    end

    it "should secure for visible commercial invoices" do
      c = Factory(:company,importer:true)
      CommercialInvoice.last.update_attributes(importer_id:c.id)
      get :index
      j = JSON.parse response.body
      res = j['results']
      expect(res.size).to eql 1
      expect(res[0]['ci_invoice_number']).to eql '0ci'
    end
    it "should confirm that user can view commercial invoices" do
      @u.update_attributes(commercial_invoice_view:false)
      get :index
      expect(response.status).to eql 401
      j = JSON.parse response.body
      expect(j['errors'].first).to eql "You do not have permission to view this module."
    end
  end
  describe 'create' do
    before(:each) do
      @base_hash = {'commercial_invoice'=>
        {'ci_imp_syscode'=>'SYS','ci_invoice_number'=>'INVNUM',
          'ci_invoice_date'=>'2014-04-21','ci_mfid'=>'12345ABCDEF',
          'ci_currency'=>'GBP','ci_invoice_value_foreign'=>'99',
          'ci_vendor_name'=>'MyVendor','ci_invoice_value'=>'100',
          'ci_gross_weight'=>'1001','ci_total_charges'=>'112',
          'ci_exchange_rate'=>'0.013','ci_total_quantity'=>'300',
          'ci_total_quantity_uom'=>'PCS',
          'ci_docs_received_date'=>'2014-04-18',
          'ci_docs_ok_date'=>'2014-05-01',
          'ci_issue_codes'=>'A',
          'ci_rater_comments'=>'COMM',
          'commercial_invoice_lines'=>[{'cil_po_number'=>'po','cil_part_number'=>'part','cil_units'=>10,'cil_value'=>100.2,ent_unit_price:10.02,'cil_line_number'=>1,'cil_uom'=>'EA','cil_country_origin_code'=>'DE','cil_country_export_code'=>'GB',
            'cil_currency'=>'GBP',
            'cil_value_foreign'=>'53',
            'commercial_invoice_tariffs'=>[{'cit_hts_code'=>'1234567890',
              'cit_entered_value'=>99.45,
              'cit_spi_primary'=>'A',
              'cit_spi_secondary'=>'B',
              'cit_classification_qty_1'=>100,
              'cit_classification_uom_1'=>'DOZ',
              'cit_classification_qty_2'=>101,
              'cit_classification_uom_2'=>'KGS',
              'cit_classification_qty_3'=>102,
              'cit_classification_uom_3'=>'OTR',
              'cit_gross_weight'=>'203',
              'cit_tariff_description'=>'My Desc'
              }]
            }
          ]
        }
      }
    end
    it "should create invoice" do
      expect {
        post :create, @base_hash
      }.to change(CommercialInvoice,:count).from(0).to(1)
      ci = CommercialInvoice.first
      expect(ci.invoice_number).to eq 'INVNUM'
      expect(ci.invoice_date).to eql Date.new(2014,4,21)
      expect(ci.mfid).to eql '12345ABCDEF'
      expect(ci.importer).to eql(@u.company)
      expect(ci.docs_received_date).to eql Date.new(2014,4,18)
      expect(ci.docs_ok_date).to eql Date.new(2014,5,1)
      expect(ci.issue_codes).to eql 'A'
      expect(ci.rater_comments).to eql 'COMM'
    end
    it "should return invoices" do
      expect {post :create, @base_hash}.to change(CommercialInvoice,:count).from(0).to(1)
      expect(response).to be_success
      j = JSON.parse(response.body)['commercial_invoice']
      expect(j['id']).to eq CommercialInvoice.first.id
      expect(j['ci_invoice_number']).to eq 'INVNUM'
      expect(j['ci_invoice_date']).to eq '2014-04-21'
      expect(j['ci_mfid']).to eq '12345ABCDEF'
      expect(j['ci_imp_syscode']).to eq 'SYS'
      expect(j['ci_currency']).to eq 'GBP'
      expect(j['ci_invoice_value_foreign']).to eq '99.0'
      expect(j['ci_vendor_name']).to eq 'MyVendor'
      expect(j['ci_invoice_value']).to eq '100.0'
      expect(j['ci_gross_weight']).to eq 1001
      expect(j['ci_total_charges']).to eq '112.0'
      expect(j['ci_exchange_rate']).to eq '0.013'
      expect(j['ci_total_quantity']).to eq '300.0'
      expect(j['ci_total_quantity_uom']).to eq 'PCS'
      expect(j['ci_docs_received_date']).to eq '2014-04-18'
      expect(j['ci_docs_ok_date']).to eq '2014-05-01'
      expect(j['ci_issue_codes']).to eq 'A'
      expect(j['ci_rater_comments']).to eq 'COMM'

    end

    context :lines do
      it "should save lines" do
        @base_hash['commercial_invoice']['commercial_invoice_lines'] << {
          'cil_po_number'=>'po2','cil_part_number'=>'p0','cil_units'=>11,'cil_line_number'=>'2'
        }
        expect {post :create, @base_hash}.to change(CommercialInvoiceLine,:count).from(0).to(2)
        ci = CommercialInvoice.first
        ln1 = ci.commercial_invoice_lines.where(line_number:1).first
        expect(ln1.po_number).to eql('po')
        expect(ln1.part_number).to eql('part')
        expect(ln1.quantity).to eql(10)
        expect(ln1.value).to eql(100.2)
        expect(ln1.unit_price).to eql(10.02)
        expect(ln1.unit_of_measure).to eql('EA')
        expect(ln1.country_origin_code).to eql('DE')
        expect(ln1.country_export_code).to eql('GB')
        expect(ln1.value_foreign).to eql(53)
        expect(ln1.currency).to eql('GBP')
        ln2 = ci.commercial_invoice_lines.where(line_number:2).first
        expect(ln2.po_number).to eql('po2')
        expect(ln2.part_number).to eql('p0')
      end
      it "should return invoice lines" do
        @base_hash['commercial_invoice']['commercial_invoice_lines'] << {
          'cil_po_number'=>'po2','cil_part_number'=>'p0','cil_units'=>11,'cil_line_number'=>'2'
        }
        post :create, @base_hash
        expect(response).to be_success
        j = JSON.parse(response.body)['commercial_invoice']['commercial_invoice_lines']
        expect(j.size).to eql 2
        j1 = j.first
        #'cil_po_number'=>'po','cil_part_number'=>'part','cil_units'=>10,'cil_value'=>100.2,ent_unit_price:10.02,'cil_line_number'=>1,'cil_uom'=>'EA','cil_country_origin_code'=>'DE','cil_country_export_code'=>'GB',
        expect(j1['id']).to eql CommercialInvoiceLine.first.id
        expect(j1['cil_line_number']).to eql 1
        expect(j1['cil_po_number']).to eql 'po'
        expect(j1['cil_part_number']).to eql 'part'
        expect(j1['cil_units']).to eql "10.0"
        expect(j1['cil_value']).to eql "100.2"
        expect(j1['ent_unit_price']).to eql "10.02"
        expect(j1['cil_uom']).to eql 'EA'
        expect(j1['cil_country_origin_code']).to eql 'DE'
        expect(j1['cil_country_export_code']).to eql 'GB'
        expect(j1['cil_value_foreign']).to eql '53.0'
        expect(j1['cil_currency']).to eql 'GBP'
        j2 = j.last
        expect(j2['id']).to eql CommercialInvoiceLine.last.id
        expect(j2['cil_line_number']).to eql 2
        expect(j2['cil_po_number']).to eql 'po2'

      end
      it "should require invoice line number" do
        @base_hash['commercial_invoice']['commercial_invoice_lines'].first.delete('cil_line_number')
        expect {post :create, @base_hash}.to_not change(CommercialInvoice,:count)
        expect(response.status).to eq 400
        j = JSON.parse(response.body)['errors'].first
        expect(j).to eql "Line 1 is missing Invoice Line - Line Number."
      end
      context :tariffs do
        it "should add tariff records" do
          expect {post :create, @base_hash}.to change(CommercialInvoiceTariff,:count).from(0).to(1)
          t = CommercialInvoiceTariff.first
          expect(t.hts_code).to eq '1234567890'
          expect(t.spi_primary).to eq 'A'
          expect(t.spi_secondary).to eq 'B'
          expect(t.classification_qty_1).to eq 100
          expect(t.classification_uom_1).to eq 'DOZ'
          expect(t.classification_qty_2).to eq 101
          expect(t.classification_uom_2).to eq 'KGS'
          expect(t.classification_qty_3).to eq 102
          expect(t.classification_uom_3).to eq 'OTR'
          expect(t.gross_weight).to eq 203
          expect(t.tariff_description).to eq 'My Desc'
          expect(t.entered_value).to eql(99.45)
        end
        it "should return tariff records" do
          expected = {'cit_hts_code'=>'1234.56.7890',
            'cit_entered_value'=>'99.45',
            'cit_spi_primary'=>'A',
            'cit_spi_secondary'=>'B',
            'cit_classification_qty_1'=>'100.0',
            'cit_classification_uom_1'=>'DOZ',
            'cit_classification_qty_2'=>'101.0',
            'cit_classification_uom_2'=>'KGS',
            'cit_classification_qty_3'=>'102.0',
            'cit_classification_uom_3'=>'OTR',
            'cit_gross_weight'=>203,
            'cit_tariff_description'=>'My Desc'}
          expect {post :create, @base_hash}.to change(CommercialInvoiceTariff,:count).from(0).to(1)
          expected['id'] = CommercialInvoiceTariff.first.id
          expect(JSON.parse(response.body)['commercial_invoice']['commercial_invoice_lines'][0]['commercial_invoice_tariffs'][0]).to eql expected
        end
      end
    end
    context :importer do
      it "should check if user can edit invoices for importer" do
        c = Factory(:company,system_code:'OTHR',importer:true) #non linked company, can't edit
        @base_hash['commercial_invoice']['ci_imp_syscode'] = 'OTHR'
        expect {post :create, @base_hash}.to_not change(CommercialInvoice,:count)
        expect(response.status).to eq 400
        j = JSON.parse(response.body)['errors'].first
        expect(j).to eql "Cannot save invoice for importer OTHR."
      end
      it "should default importer to current_user if importer_system_code.blank? and current_user is importer" do
        @base_hash['commercial_invoice'].delete 'ci_imp_syscode'
        expect {post :create, @base_hash}.to change(CommercialInvoice,:count).from(0).to(1)
        expect(CommercialInvoice.first.importer).to eql @u.company
      end
      it "should error if current_user not importer and no importer_system_code" do
        @u.company.update_attributes(importer:false)
        expect {post :create, @base_hash}.to_not change(CommercialInvoice,:count)
        expect(response.status).to eq 400
        j = JSON.parse(response.body)['errors'].first
        expect(j).to eql "Cannot save invoice without importer."
      end
    end
  end
  describe "update" do
    before :each do
      @ci = Factory(:commercial_invoice,importer:@u.company,invoice_number:'OLD',entry:nil)
      @cil = @ci.commercial_invoice_lines.create!(line_number:1,
        part_number:'ABC',quantity:40)
      @base_hash = {'id'=>@ci.id,
        'ci_imp_syscode'=>'SYS','ci_invoice_number'=>'INVNUM',
        'ci_invoice_date'=>'2014-04-21','ci_mfid'=>'12345ABCDEF',
        'ci_currency'=>'GBP','ci_invoice_value_foreign'=>'99',
        'ci_vendor_name'=>'MyVendor','ci_invoice_value'=>'100',
        'ci_gross_weight'=>'1001','ci_total_charges'=>'112',
        'ci_exchange_rate'=>'0.013','ci_total_quantity'=>'300',
        'ci_total_quantity_uom'=>'PCS',
        'ci_docs_received_date'=>'2014-04-18',
        'ci_docs_ok_date'=>'2014-05-01',
        'ci_issue_codes'=>'A',
        'ci_rater_comments'=>'COMM',
        'commercial_invoice_lines'=>[{'id'=>@cil.id,'cil_po_number'=>'po','cil_part_number'=>'part','cil_units'=>10,'cil_value'=>100.2,ent_unit_price:10.02,'cil_line_number'=>1,'cil_uom'=>'EA','cil_country_origin_code'=>'DE','cil_country_export_code'=>'GB',
          'cil_currency'=>'GBP',
          'cil_value_foreign'=>'53',
          'commercial_invoice_tariffs'=>[{'cit_hts_code'=>'1234567890',
            'cit_entered_value'=>99.45,
            'cit_spi_primary'=>'A',
            'cit_spi_secondary'=>'B',
            'cit_classification_qty_1'=>100,
            'cit_classification_uom_1'=>'DOZ',
            'cit_classification_qty_2'=>101,
            'cit_classification_uom_2'=>'KGS',
            'cit_classification_qty_3'=>102,
            'cit_classification_uom_3'=>'OTR',
            'cit_gross_weight'=>'203',
            'cit_tariff_description'=>'My Desc'
            }]
          }
        ]
        }
    end
    it "should save update" do
      put :update, id:@ci.id, commercial_invoice: @base_hash
      expect(response).to be_success
      @ci.reload
      expect(@ci.invoice_number).to eq 'INVNUM'
      @cil.reload
      expect(@cil.part_number).to eq 'part'
      j = JSON.parse(response.body)['commercial_invoice']
      expect(j['id']).to eq @ci.id
      expect(j['ci_invoice_number']).to eq 'INVNUM'
    end
    it "should fail if ID in hash doesn't match route" do
      @base_hash['id'] = @ci.id+1
      put :update, id:@ci.id, commercial_invoice: @base_hash
      expect(response.status).to eq 400
      @ci.reload
      expect(@ci.invoice_number).to eq 'OLD'
      expect(JSON.parse(response.body)['errors'].first).to eql "Path ID #{@ci.id} does not match JSON ID #{@ci.id+1}."
    end
    it 'should not update record attached to entry' do
      ent = Factory(:entry,importer:@ci.importer)
      @ci.entry = ent
      @ci.save!
      put :update, id:@ci.id, commercial_invoice: @base_hash
      expect(response.status).to eq 403
      expect(JSON.parse(response.body)['errors'].first).to eql "Cannot update commercial invoice attached to customs entry."
    end
  end
end