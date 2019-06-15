// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//= require jquery
// Because all the stub'ed applications below require jquery_ujs (and the fact that it comes from a gem)
// we need to link it externally and then add it in as an asset to the header.
//= link jquery_ujs
//= require json3
//= require bootstrap.bundle
//= require jquery-ui
//= require angular
//= require_directory ./every_page
//= require_directory ./domainer
//= require_directory ./comment
//= require_directory ./product
//= require_directory ./shipment
//= require_directory .
// These directories are after "." because they require scripts loaded from root
//= require_directory ./setup_data
//= require_directory ./state_toggle_buttons
//= require_directory ./official_tariff
//= require_directory ./field_validator
//= require_directory ./folders
//= stub legacy
//= stub html5shim
//= stub vendor_portal
//= stub trade_lanes
//= stub chain_vendor_maint
//= stub chain_admin
//= stub login
