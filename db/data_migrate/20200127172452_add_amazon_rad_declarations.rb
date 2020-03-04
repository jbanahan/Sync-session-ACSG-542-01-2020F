class AddAmazonRadDeclarations < ActiveRecord::Migration
  def up
    if MasterSetup.get.custom_feature?("WWW")
      statement_mapping.each_pair do |key, value|
        DataCrossReference.where(cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION, key: key[0..255]).first_or_create! value: value
      end
    end
  end

  def down
    if MasterSetup.get.custom_feature?("WWW")
      DataCrossReference.where(cross_reference_type: DataCrossReference::ACE_RADIATION_DECLARATION).destroy_all
    end
  end

  def statement_mapping
    {
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY WERE MANUFACTURED PRIOR TO THE EFFECTIVE DATE OF ANY APPLICABLE STANDARD.' => 'RA1',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE EXCLUDED BY THE APPLICABILITY CLAUSE OR DEFINITION IN THE STANDARD OR BY FDA WRITTEN GUIDANCE. SPECIFY REASON FOR EXCLUSION.' => 'RA2',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE PERSONAL HOUSEHOLD GOODS OF AN INDIVIDUAL ENTERING THE U.S. OR BEING RETURNED TO A U.S. RESIDENT. (LIMIT: 3 OF EACH PRODUCT TYPE).' => 'RA3',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE PROPERTY OF A PARTY RESIDING OUTSIDE THE U.S. AND WILL BE RETURNED TO THE OWNER AFTER REPAIR OR SERVICING.' => 'RA4',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE COMPONENTS OR SUBASSEMBLIES TO BE USED IN MANUFACTURING OR AS REPLACEMENT PARTS (NOT APPLICABLE TO DIAGNOSTIC X-RAY PARTS).' => 'RA5',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE PROTOTYPES INTENDED FOR ONGOING PRODUCT DEVELOPMENT BY THE IMPORTING FIRM, ARE LABELED "FOR TEST/EVALUATION ONLY," AND WILL BE EXPORTED, DESTROYED, OR HELD FOR FUTURE TESTING (I.E., NOT DISTRIBUTED). (QUANTITIES LIMITED - SEE REVERSE.).' => 'RA6',
      'I / WE DECLARE THAT THE PRODUCTS ARE NOT SUBJECT TO RADIATION PERFORMANCE STANDARDS BECAUSE THEY ARE BEING REPROCESSED IN ACCORDANCE WITH P.L. 104-134 OR OTHER FDA GUIDANCE, ARE LABELED "FOR EXPORT ONLY," AND WILL NOT BE SOLD, DISTRIBUTED, OR TRANSFERRED WITHOUT FDA APPROVAL.' => 'RA7',
      'I / WE DECLARE THAT THE PRODUCTS COMPLY WITH THE PERFORMANCE STANDARDS. LAST ANNUAL REPORT OR PRODUCT/INITIAL REPORT. NEED ACCESSION NUMBER OF REPORT AND NAME OF MANUFACTURER OF RECORD.' => 'RB1',
      'I / WE DECLARE THAT THE PRODUCTS COMPLY WITH THE PERFORMANCE STANDARDS. UNKNOWN MANUFACTURER OR REPORT NUMBER. REASON NEEDED.' => 'RB2',
      'I / WE DECLARE THAT THE PRODUCTS DO NOT COMPLY WITH PERFORMANCE STANDARDS(UNDER TEMPORARY IMPORT BOND). FOR RESEARCH, INVESTIGATIONS/STUDIES, OR TRAINING.' => 'RC1',
      'I / WE DECLARE THAT THE PRODUCTS DO NOT COMPLY WITH PERFORMANCE STANDARDS(UNDER TEMPORARY IMPORT BOND). FOR TRADE SHOW DEMINSTRATION.' => 'RC2',
      'I / WE DECLARE THAT THE PRODUCTS DO NOT COMPLY WITH PERFORMANCE STANDARDS. APPROVED PETITION IS ATTACHED.' => 'RD1',
      'I / WE DECLARE THAT THE PRODUCTS DO NOT COMPLY WITH PERFORMANCE STANDARDS. PETITION REQUEST IS ATTACHED.' => 'RD2',
      'I / WE DECLARE THAT THE PRODUCTS DO NOT COMPLY WITH PERFORMANCE STANDARDS. REQUEST WILL BE SUBMITTED WITHIN 60 DAYS.' => 'RD3'
    }
  end
end
