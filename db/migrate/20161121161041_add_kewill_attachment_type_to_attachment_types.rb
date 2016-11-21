class AddKewillAttachmentTypeToAttachmentTypes < ActiveRecord::Migration
  def change
    add_column :attachment_types, :kewill_attachment_type, :string
    add_column :attachment_types, :disable_multiple_kewill_docs, :boolean

    execute "UPDATE attachment_types SET kewill_attachment_type = name"

    # The following codes are special cases where they don't match our Attachment Type names
    # - primarily because the names need to be able to be Folder names and the chars in teh 
    # attachment name won't work as folder names on same/all OSes.
    [['38', '3461 ENTRY/IMMEDIATE DELIVERY'], ['27', 'ENTRY SUMMARY - F7501'], ['101', 'Fish & Wildlife Declaration'], 
      ['70028', 'PEA / Protest'], ['70046', 'CF4647 Notice to Mark and/or Re-Deliver'], ['70048', 'FDA RELEASE (AFTER EXAM/SAMPLING)'], 
      ['70064', "USDA Emergency Action Notification's"], ['70078', 'ADD/CVD Packet']].each do |v|
        execute "UPDATE attachment_types SET kewill_attachment_type = #{AttachmentType.sanitize(v[1])} WHERE kewill_document_code = '#{v[0]}'"
    end

  end
end
