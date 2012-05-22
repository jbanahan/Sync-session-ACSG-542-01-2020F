require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    # Updates CSM number for existing styles based on spreadsheet sent from team in Italy
    class PoloCsmSyncHandler
      def initialize(custom_file)
        @custom_file = custom_file
        @csm_cd = CustomDefinition.find_or_create_by_label("CSM Number",:module_type=>'Product',:data_type=>'string')
      end

      def process user
        xlc = XLClient.new(@custom_file.attached.path)
        last_row = xlc.last_row_number(0)
        (1..last_row).each do |n|
          matched = 'not matched'
          style = xlc.get_cell(0, n, 9)['cell']['value']
          next if style.blank?
          style.strip!
          style = style[0,style.size-2] if style.end_with? '.0' #fix accidental numerics
          p = Product.find_by_unique_identifier style
          if !p.blank?
            raise "User does not have permission to edit product #{p.unique_identifier}" unless p.can_edit? user
            csm_number = xlc.get_cell(0, n, 5)['cell']['value']
            csm_number = csm_number[0,csm_number.size-2] if csm_number.end_with? '.0' #fix accidental numerics
            p.update_custom_value! @csm_cd, csm_number
            p.create_snapshot user
            matched = 'matched'
          end
          xlc.set_cell 0, n, 16, matched
        end
        xlc.save
        user.messages.create(:subject=>"CSM Sync Complete",:body=>"Your CSM Sync job has completed.  You can download the updated file <a href='/custom_features/csm_sync'>here</a>.")
      end
    end
  end
end
