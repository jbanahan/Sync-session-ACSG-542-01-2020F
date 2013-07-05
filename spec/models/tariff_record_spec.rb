require 'spec_helper'

describe TariffRecord do

  it "should not allow the same line number on multiple records for same classification" do
    tr = Factory(:tariff_record,:line_number=>1)
    new_rec = tr.classification.tariff_records.build(:line_number=>1)
    new_rec.save.should be_false
    new_rec.errors[:line_number].should have(1).message
  end

  it "should not allow same line number on multiple records for same classification using nested_attributes" do
    l = lambda do
      c = Factory(:country)
      h = {'unique_identifier'=>'truid',
        "classifications_attributes"=>{"0"=>{
          "country_id"=>c.id.to_s,
          'tariff_records_attributes'=>{
            '0'=>{
              'line_number'=>'1',
              'hts_1'=>'1234567890'
            },
            '1'=>{
              'line_number'=>'1',
              'hts_1'=>'7890123456'
            }
          }
        }}
      }
      p = Product.create!(h)
    end
    l.should raise_error ActiveRecord::RecordInvalid 
  end
  it "should allow auto-assigning of line numbers when using nested attributes" do
    c = Factory(:country)
    h = {'unique_identifier'=>'truid',
      "classifications_attributes"=>{"0"=>{
        "country_id"=>c.id.to_s,
        'tariff_records_attributes'=>{
          '0'=>{
            'hts_1'=>'1234567890'
          },
          '1'=>{
            'hts_1'=>'7890123456'
          }
        }
      }}
    }
    p = Product.create!(h)
    p.classifications.first.tariff_records.pluck(:line_number).should == [1,2]
  end

end
