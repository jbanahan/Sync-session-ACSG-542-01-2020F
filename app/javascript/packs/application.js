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

/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

import moment from 'moment';
window.moment = moment
//import 'moment';
//import moment from 'moment'
//import 'moment/min/locales'

import 'jquery';
import {} from 'jquery-ujs'
import 'angular-moment';
import 'angular';
import 'angucomplete-alt';
import 'angular-local-storage';
import 'angular-route';
import 'angular-sanitize';
import 'popper.js';
import 'bootstrap';

import './chain';
import './chain_bootstrap';
import './components';
import './every_page/chain_all_pages';
import './every_page/nav_panel';
import './every_page/notification_center';
import './setup_data/setup_data_svc';

import "../stylesheets/application";

const images = require.context('../images', true);
const imagePath = (name) => images(name, true);
