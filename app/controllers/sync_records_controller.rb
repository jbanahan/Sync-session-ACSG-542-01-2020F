class SyncRecordsController < ApplicationController

	def resend
		sync = SyncRecord.find params[:id]
			
		# Verify the user is allowed to access the syncable object associated with the record by means of calling can_view? or can_edit? on the object
		syncable = sync.syncable
		access = false
		if syncable.respond_to?(:can_view?) 
			access = syncable.can_view? current_user
		end

		if access
			sync.update_attributes(:sent_at => nil, :confirmed_at => nil, :confirmation_file_name => nil, :failure_message => nil)
			add_flash :notices, "This record will be resent the next time the sync program is executed for #{sync.trading_partner}."
		else
			add_flash :errors, "You do not have permission to resend this record."
		end

		respond_to do |format|
			format.html {
				# referrer should pretty much always be here...but handling it when it's not does allow an easy way to just type the address
				# into the location bar for "double secret" admin access useage
				unless request.referrer.blank?
					redirect_to request.referrer
				else
					redirect_by_core_module syncable
				end
			}
		end
	end
end