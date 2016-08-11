//! moment.js
//! version : 2.13.0
//! authors : Tim Wood, Iskren Chernev, Moment.js contributors
//! license : MIT
//! momentjs.com
!function(a,b){"object"==typeof exports&&"undefined"!=typeof module?module.exports=b():"function"==typeof define&&define.amd?define(b):a.moment=b()}(this,function(){"use strict";function a(){return fd.apply(null,arguments)}function b(a){fd=a}function c(a){return a instanceof Array||"[object Array]"===Object.prototype.toString.call(a)}function d(a){return a instanceof Date||"[object Date]"===Object.prototype.toString.call(a)}function e(a,b){var c,d=[];for(c=0;c<a.length;++c)d.push(b(a[c],c));return d}function f(a,b){return Object.prototype.hasOwnProperty.call(a,b)}function g(a,b){for(var c in b)f(b,c)&&(a[c]=b[c]);return f(b,"toString")&&(a.toString=b.toString),f(b,"valueOf")&&(a.valueOf=b.valueOf),a}function h(a,b,c,d){return Ja(a,b,c,d,!0).utc()}function i(){return{empty:!1,unusedTokens:[],unusedInput:[],overflow:-2,charsLeftOver:0,nullInput:!1,invalidMonth:null,invalidFormat:!1,userInvalidated:!1,iso:!1,parsedDateParts:[],meridiem:null}}function j(a){return null==a._pf&&(a._pf=i()),a._pf}function k(a){if(null==a._isValid){var b=j(a),c=gd.call(b.parsedDateParts,function(a){return null!=a});a._isValid=!isNaN(a._d.getTime())&&b.overflow<0&&!b.empty&&!b.invalidMonth&&!b.invalidWeekday&&!b.nullInput&&!b.invalidFormat&&!b.userInvalidated&&(!b.meridiem||b.meridiem&&c),a._strict&&(a._isValid=a._isValid&&0===b.charsLeftOver&&0===b.unusedTokens.length&&void 0===b.bigHour)}return a._isValid}function l(a){var b=h(NaN);return null!=a?g(j(b),a):j(b).userInvalidated=!0,b}function m(a){return void 0===a}function n(a,b){var c,d,e;if(m(b._isAMomentObject)||(a._isAMomentObject=b._isAMomentObject),m(b._i)||(a._i=b._i),m(b._f)||(a._f=b._f),m(b._l)||(a._l=b._l),m(b._strict)||(a._strict=b._strict),m(b._tzm)||(a._tzm=b._tzm),m(b._isUTC)||(a._isUTC=b._isUTC),m(b._offset)||(a._offset=b._offset),m(b._pf)||(a._pf=j(b)),m(b._locale)||(a._locale=b._locale),hd.length>0)for(c in hd)d=hd[c],e=b[d],m(e)||(a[d]=e);return a}function o(b){n(this,b),this._d=new Date(null!=b._d?b._d.getTime():NaN),id===!1&&(id=!0,a.updateOffset(this),id=!1)}function p(a){return a instanceof o||null!=a&&null!=a._isAMomentObject}function q(a){return 0>a?Math.ceil(a):Math.floor(a)}function r(a){var b=+a,c=0;return 0!==b&&isFinite(b)&&(c=q(b)),c}function s(a,b,c){var d,e=Math.min(a.length,b.length),f=Math.abs(a.length-b.length),g=0;for(d=0;e>d;d++)(c&&a[d]!==b[d]||!c&&r(a[d])!==r(b[d]))&&g++;return g+f}function t(b){a.suppressDeprecationWarnings===!1&&"undefined"!=typeof console&&console.warn&&console.warn("Deprecation warning: "+b)}function u(b,c){var d=!0;return g(function(){return null!=a.deprecationHandler&&a.deprecationHandler(null,b),d&&(t(b+"\nArguments: "+Array.prototype.slice.call(arguments).join(", ")+"\n"+(new Error).stack),d=!1),c.apply(this,arguments)},c)}function v(b,c){null!=a.deprecationHandler&&a.deprecationHandler(b,c),jd[b]||(t(c),jd[b]=!0)}function w(a){return a instanceof Function||"[object Function]"===Object.prototype.toString.call(a)}function x(a){return"[object Object]"===Object.prototype.toString.call(a)}function y(a){var b,c;for(c in a)b=a[c],w(b)?this[c]=b:this["_"+c]=b;this._config=a,this._ordinalParseLenient=new RegExp(this._ordinalParse.source+"|"+/\d{1,2}/.source)}function z(a,b){var c,d=g({},a);for(c in b)f(b,c)&&(x(a[c])&&x(b[c])?(d[c]={},g(d[c],a[c]),g(d[c],b[c])):null!=b[c]?d[c]=b[c]:delete d[c]);return d}function A(a){null!=a&&this.set(a)}function B(a){return a?a.toLowerCase().replace("_","-"):a}function C(a){for(var b,c,d,e,f=0;f<a.length;){for(e=B(a[f]).split("-"),b=e.length,c=B(a[f+1]),c=c?c.split("-"):null;b>0;){if(d=D(e.slice(0,b).join("-")))return d;if(c&&c.length>=b&&s(e,c,!0)>=b-1)break;b--}f++}return null}function D(a){var b=null;if(!nd[a]&&"undefined"!=typeof module&&module&&module.exports)try{b=ld._abbr,require("./locale/"+a),E(b)}catch(c){}return nd[a]}function E(a,b){var c;return a&&(c=m(b)?H(a):F(a,b),c&&(ld=c)),ld._abbr}function F(a,b){return null!==b?(b.abbr=a,null!=nd[a]?(v("defineLocaleOverride","use moment.updateLocale(localeName, config) to change an existing locale. moment.defineLocale(localeName, config) should only be used for creating a new locale"),b=z(nd[a]._config,b)):null!=b.parentLocale&&(null!=nd[b.parentLocale]?b=z(nd[b.parentLocale]._config,b):v("parentLocaleUndefined","specified parentLocale is not defined yet")),nd[a]=new A(b),E(a),nd[a]):(delete nd[a],null)}function G(a,b){if(null!=b){var c;null!=nd[a]&&(b=z(nd[a]._config,b)),c=new A(b),c.parentLocale=nd[a],nd[a]=c,E(a)}else null!=nd[a]&&(null!=nd[a].parentLocale?nd[a]=nd[a].parentLocale:null!=nd[a]&&delete nd[a]);return nd[a]}function H(a){var b;if(a&&a._locale&&a._locale._abbr&&(a=a._locale._abbr),!a)return ld;if(!c(a)){if(b=D(a))return b;a=[a]}return C(a)}function I(){return kd(nd)}function J(a,b){var c=a.toLowerCase();od[c]=od[c+"s"]=od[b]=a}function K(a){return"string"==typeof a?od[a]||od[a.toLowerCase()]:void 0}function L(a){var b,c,d={};for(c in a)f(a,c)&&(b=K(c),b&&(d[b]=a[c]));return d}function M(b,c){return function(d){return null!=d?(O(this,b,d),a.updateOffset(this,c),this):N(this,b)}}function N(a,b){return a.isValid()?a._d["get"+(a._isUTC?"UTC":"")+b]():NaN}function O(a,b,c){a.isValid()&&a._d["set"+(a._isUTC?"UTC":"")+b](c)}function P(a,b){var c;if("object"==typeof a)for(c in a)this.set(c,a[c]);else if(a=K(a),w(this[a]))return this[a](b);return this}function Q(a,b,c){var d=""+Math.abs(a),e=b-d.length,f=a>=0;return(f?c?"+":"":"-")+Math.pow(10,Math.max(0,e)).toString().substr(1)+d}function R(a,b,c,d){var e=d;"string"==typeof d&&(e=function(){return this[d]()}),a&&(sd[a]=e),b&&(sd[b[0]]=function(){return Q(e.apply(this,arguments),b[1],b[2])}),c&&(sd[c]=function(){return this.localeData().ordinal(e.apply(this,arguments),a)})}function S(a){return a.match(/\[[\s\S]/)?a.replace(/^\[|\]$/g,""):a.replace(/\\/g,"")}function T(a){var b,c,d=a.match(pd);for(b=0,c=d.length;c>b;b++)sd[d[b]]?d[b]=sd[d[b]]:d[b]=S(d[b]);return function(b){var e,f="";for(e=0;c>e;e++)f+=d[e]instanceof Function?d[e].call(b,a):d[e];return f}}function U(a,b){return a.isValid()?(b=V(b,a.localeData()),rd[b]=rd[b]||T(b),rd[b](a)):a.localeData().invalidDate()}function V(a,b){function c(a){return b.longDateFormat(a)||a}var d=5;for(qd.lastIndex=0;d>=0&&qd.test(a);)a=a.replace(qd,c),qd.lastIndex=0,d-=1;return a}function W(a,b,c){Kd[a]=w(b)?b:function(a,d){return a&&c?c:b}}function X(a,b){return f(Kd,a)?Kd[a](b._strict,b._locale):new RegExp(Y(a))}function Y(a){return Z(a.replace("\\","").replace(/\\(\[)|\\(\])|\[([^\]\[]*)\]|\\(.)/g,function(a,b,c,d,e){return b||c||d||e}))}function Z(a){return a.replace(/[-\/\\^$*+?.()|[\]{}]/g,"\\$&")}function $(a,b){var c,d=b;for("string"==typeof a&&(a=[a]),"number"==typeof b&&(d=function(a,c){c[b]=r(a)}),c=0;c<a.length;c++)Ld[a[c]]=d}function _(a,b){$(a,function(a,c,d,e){d._w=d._w||{},b(a,d._w,d,e)})}function aa(a,b,c){null!=b&&f(Ld,a)&&Ld[a](b,c._a,c,a)}function ba(a,b){return new Date(Date.UTC(a,b+1,0)).getUTCDate()}function ca(a,b){return c(this._months)?this._months[a.month()]:this._months[Vd.test(b)?"format":"standalone"][a.month()]}function da(a,b){return c(this._monthsShort)?this._monthsShort[a.month()]:this._monthsShort[Vd.test(b)?"format":"standalone"][a.month()]}function ea(a,b,c){var d,e,f,g=a.toLocaleLowerCase();if(!this._monthsParse)for(this._monthsParse=[],this._longMonthsParse=[],this._shortMonthsParse=[],d=0;12>d;++d)f=h([2e3,d]),this._shortMonthsParse[d]=this.monthsShort(f,"").toLocaleLowerCase(),this._longMonthsParse[d]=this.months(f,"").toLocaleLowerCase();return c?"MMM"===b?(e=md.call(this._shortMonthsParse,g),-1!==e?e:null):(e=md.call(this._longMonthsParse,g),-1!==e?e:null):"MMM"===b?(e=md.call(this._shortMonthsParse,g),-1!==e?e:(e=md.call(this._longMonthsParse,g),-1!==e?e:null)):(e=md.call(this._longMonthsParse,g),-1!==e?e:(e=md.call(this._shortMonthsParse,g),-1!==e?e:null))}function fa(a,b,c){var d,e,f;if(this._monthsParseExact)return ea.call(this,a,b,c);for(this._monthsParse||(this._monthsParse=[],this._longMonthsParse=[],this._shortMonthsParse=[]),d=0;12>d;d++){if(e=h([2e3,d]),c&&!this._longMonthsParse[d]&&(this._longMonthsParse[d]=new RegExp("^"+this.months(e,"").replace(".","")+"$","i"),this._shortMonthsParse[d]=new RegExp("^"+this.monthsShort(e,"").replace(".","")+"$","i")),c||this._monthsParse[d]||(f="^"+this.months(e,"")+"|^"+this.monthsShort(e,""),this._monthsParse[d]=new RegExp(f.replace(".",""),"i")),c&&"MMMM"===b&&this._longMonthsParse[d].test(a))return d;if(c&&"MMM"===b&&this._shortMonthsParse[d].test(a))return d;if(!c&&this._monthsParse[d].test(a))return d}}function ga(a,b){var c;if(!a.isValid())return a;if("string"==typeof b)if(/^\d+$/.test(b))b=r(b);else if(b=a.localeData().monthsParse(b),"number"!=typeof b)return a;return c=Math.min(a.date(),ba(a.year(),b)),a._d["set"+(a._isUTC?"UTC":"")+"Month"](b,c),a}function ha(b){return null!=b?(ga(this,b),a.updateOffset(this,!0),this):N(this,"Month")}function ia(){return ba(this.year(),this.month())}function ja(a){return this._monthsParseExact?(f(this,"_monthsRegex")||la.call(this),a?this._monthsShortStrictRegex:this._monthsShortRegex):this._monthsShortStrictRegex&&a?this._monthsShortStrictRegex:this._monthsShortRegex}function ka(a){return this._monthsParseExact?(f(this,"_monthsRegex")||la.call(this),a?this._monthsStrictRegex:this._monthsRegex):this._monthsStrictRegex&&a?this._monthsStrictRegex:this._monthsRegex}function la(){function a(a,b){return b.length-a.length}var b,c,d=[],e=[],f=[];for(b=0;12>b;b++)c=h([2e3,b]),d.push(this.monthsShort(c,"")),e.push(this.months(c,"")),f.push(this.months(c,"")),f.push(this.monthsShort(c,""));for(d.sort(a),e.sort(a),f.sort(a),b=0;12>b;b++)d[b]=Z(d[b]),e[b]=Z(e[b]),f[b]=Z(f[b]);this._monthsRegex=new RegExp("^("+f.join("|")+")","i"),this._monthsShortRegex=this._monthsRegex,this._monthsStrictRegex=new RegExp("^("+e.join("|")+")","i"),this._monthsShortStrictRegex=new RegExp("^("+d.join("|")+")","i")}function ma(a){var b,c=a._a;return c&&-2===j(a).overflow&&(b=c[Nd]<0||c[Nd]>11?Nd:c[Od]<1||c[Od]>ba(c[Md],c[Nd])?Od:c[Pd]<0||c[Pd]>24||24===c[Pd]&&(0!==c[Qd]||0!==c[Rd]||0!==c[Sd])?Pd:c[Qd]<0||c[Qd]>59?Qd:c[Rd]<0||c[Rd]>59?Rd:c[Sd]<0||c[Sd]>999?Sd:-1,j(a)._overflowDayOfYear&&(Md>b||b>Od)&&(b=Od),j(a)._overflowWeeks&&-1===b&&(b=Td),j(a)._overflowWeekday&&-1===b&&(b=Ud),j(a).overflow=b),a}function na(a){var b,c,d,e,f,g,h=a._i,i=$d.exec(h)||_d.exec(h);if(i){for(j(a).iso=!0,b=0,c=be.length;c>b;b++)if(be[b][1].exec(i[1])){e=be[b][0],d=be[b][2]!==!1;break}if(null==e)return void(a._isValid=!1);if(i[3]){for(b=0,c=ce.length;c>b;b++)if(ce[b][1].exec(i[3])){f=(i[2]||" ")+ce[b][0];break}if(null==f)return void(a._isValid=!1)}if(!d&&null!=f)return void(a._isValid=!1);if(i[4]){if(!ae.exec(i[4]))return void(a._isValid=!1);g="Z"}a._f=e+(f||"")+(g||""),Ca(a)}else a._isValid=!1}function oa(b){var c=de.exec(b._i);return null!==c?void(b._d=new Date(+c[1])):(na(b),void(b._isValid===!1&&(delete b._isValid,a.createFromInputFallback(b))))}function pa(a,b,c,d,e,f,g){var h=new Date(a,b,c,d,e,f,g);return 100>a&&a>=0&&isFinite(h.getFullYear())&&h.setFullYear(a),h}function qa(a){var b=new Date(Date.UTC.apply(null,arguments));return 100>a&&a>=0&&isFinite(b.getUTCFullYear())&&b.setUTCFullYear(a),b}function ra(a){return sa(a)?366:365}function sa(a){return a%4===0&&a%100!==0||a%400===0}function ta(){return sa(this.year())}function ua(a,b,c){var d=7+b-c,e=(7+qa(a,0,d).getUTCDay()-b)%7;return-e+d-1}function va(a,b,c,d,e){var f,g,h=(7+c-d)%7,i=ua(a,d,e),j=1+7*(b-1)+h+i;return 0>=j?(f=a-1,g=ra(f)+j):j>ra(a)?(f=a+1,g=j-ra(a)):(f=a,g=j),{year:f,dayOfYear:g}}function wa(a,b,c){var d,e,f=ua(a.year(),b,c),g=Math.floor((a.dayOfYear()-f-1)/7)+1;return 1>g?(e=a.year()-1,d=g+xa(e,b,c)):g>xa(a.year(),b,c)?(d=g-xa(a.year(),b,c),e=a.year()+1):(e=a.year(),d=g),{week:d,year:e}}function xa(a,b,c){var d=ua(a,b,c),e=ua(a+1,b,c);return(ra(a)-d+e)/7}function ya(a,b,c){return null!=a?a:null!=b?b:c}function za(b){var c=new Date(a.now());return b._useUTC?[c.getUTCFullYear(),c.getUTCMonth(),c.getUTCDate()]:[c.getFullYear(),c.getMonth(),c.getDate()]}function Aa(a){var b,c,d,e,f=[];if(!a._d){for(d=za(a),a._w&&null==a._a[Od]&&null==a._a[Nd]&&Ba(a),a._dayOfYear&&(e=ya(a._a[Md],d[Md]),a._dayOfYear>ra(e)&&(j(a)._overflowDayOfYear=!0),c=qa(e,0,a._dayOfYear),a._a[Nd]=c.getUTCMonth(),a._a[Od]=c.getUTCDate()),b=0;3>b&&null==a._a[b];++b)a._a[b]=f[b]=d[b];for(;7>b;b++)a._a[b]=f[b]=null==a._a[b]?2===b?1:0:a._a[b];24===a._a[Pd]&&0===a._a[Qd]&&0===a._a[Rd]&&0===a._a[Sd]&&(a._nextDay=!0,a._a[Pd]=0),a._d=(a._useUTC?qa:pa).apply(null,f),null!=a._tzm&&a._d.setUTCMinutes(a._d.getUTCMinutes()-a._tzm),a._nextDay&&(a._a[Pd]=24)}}function Ba(a){var b,c,d,e,f,g,h,i;b=a._w,null!=b.GG||null!=b.W||null!=b.E?(f=1,g=4,c=ya(b.GG,a._a[Md],wa(Ka(),1,4).year),d=ya(b.W,1),e=ya(b.E,1),(1>e||e>7)&&(i=!0)):(f=a._locale._week.dow,g=a._locale._week.doy,c=ya(b.gg,a._a[Md],wa(Ka(),f,g).year),d=ya(b.w,1),null!=b.d?(e=b.d,(0>e||e>6)&&(i=!0)):null!=b.e?(e=b.e+f,(b.e<0||b.e>6)&&(i=!0)):e=f),1>d||d>xa(c,f,g)?j(a)._overflowWeeks=!0:null!=i?j(a)._overflowWeekday=!0:(h=va(c,d,e,f,g),a._a[Md]=h.year,a._dayOfYear=h.dayOfYear)}function Ca(b){if(b._f===a.ISO_8601)return void na(b);b._a=[],j(b).empty=!0;var c,d,e,f,g,h=""+b._i,i=h.length,k=0;for(e=V(b._f,b._locale).match(pd)||[],c=0;c<e.length;c++)f=e[c],d=(h.match(X(f,b))||[])[0],d&&(g=h.substr(0,h.indexOf(d)),g.length>0&&j(b).unusedInput.push(g),h=h.slice(h.indexOf(d)+d.length),k+=d.length),sd[f]?(d?j(b).empty=!1:j(b).unusedTokens.push(f),aa(f,d,b)):b._strict&&!d&&j(b).unusedTokens.push(f);j(b).charsLeftOver=i-k,h.length>0&&j(b).unusedInput.push(h),j(b).bigHour===!0&&b._a[Pd]<=12&&b._a[Pd]>0&&(j(b).bigHour=void 0),j(b).parsedDateParts=b._a.slice(0),j(b).meridiem=b._meridiem,b._a[Pd]=Da(b._locale,b._a[Pd],b._meridiem),Aa(b),ma(b)}function Da(a,b,c){var d;return null==c?b:null!=a.meridiemHour?a.meridiemHour(b,c):null!=a.isPM?(d=a.isPM(c),d&&12>b&&(b+=12),d||12!==b||(b=0),b):b}function Ea(a){var b,c,d,e,f;if(0===a._f.length)return j(a).invalidFormat=!0,void(a._d=new Date(NaN));for(e=0;e<a._f.length;e++)f=0,b=n({},a),null!=a._useUTC&&(b._useUTC=a._useUTC),b._f=a._f[e],Ca(b),k(b)&&(f+=j(b).charsLeftOver,f+=10*j(b).unusedTokens.length,j(b).score=f,(null==d||d>f)&&(d=f,c=b));g(a,c||b)}function Fa(a){if(!a._d){var b=L(a._i);a._a=e([b.year,b.month,b.day||b.date,b.hour,b.minute,b.second,b.millisecond],function(a){return a&&parseInt(a,10)}),Aa(a)}}function Ga(a){var b=new o(ma(Ha(a)));return b._nextDay&&(b.add(1,"d"),b._nextDay=void 0),b}function Ha(a){var b=a._i,e=a._f;return a._locale=a._locale||H(a._l),null===b||void 0===e&&""===b?l({nullInput:!0}):("string"==typeof b&&(a._i=b=a._locale.preparse(b)),p(b)?new o(ma(b)):(c(e)?Ea(a):e?Ca(a):d(b)?a._d=b:Ia(a),k(a)||(a._d=null),a))}function Ia(b){var f=b._i;void 0===f?b._d=new Date(a.now()):d(f)?b._d=new Date(f.valueOf()):"string"==typeof f?oa(b):c(f)?(b._a=e(f.slice(0),function(a){return parseInt(a,10)}),Aa(b)):"object"==typeof f?Fa(b):"number"==typeof f?b._d=new Date(f):a.createFromInputFallback(b)}function Ja(a,b,c,d,e){var f={};return"boolean"==typeof c&&(d=c,c=void 0),f._isAMomentObject=!0,f._useUTC=f._isUTC=e,f._l=c,f._i=a,f._f=b,f._strict=d,Ga(f)}function Ka(a,b,c,d){return Ja(a,b,c,d,!1)}function La(a,b){var d,e;if(1===b.length&&c(b[0])&&(b=b[0]),!b.length)return Ka();for(d=b[0],e=1;e<b.length;++e)(!b[e].isValid()||b[e][a](d))&&(d=b[e]);return d}function Ma(){var a=[].slice.call(arguments,0);return La("isBefore",a)}function Na(){var a=[].slice.call(arguments,0);return La("isAfter",a)}function Oa(a){var b=L(a),c=b.year||0,d=b.quarter||0,e=b.month||0,f=b.week||0,g=b.day||0,h=b.hour||0,i=b.minute||0,j=b.second||0,k=b.millisecond||0;this._milliseconds=+k+1e3*j+6e4*i+1e3*h*60*60,this._days=+g+7*f,this._months=+e+3*d+12*c,this._data={},this._locale=H(),this._bubble()}function Pa(a){return a instanceof Oa}function Qa(a,b){R(a,0,0,function(){var a=this.utcOffset(),c="+";return 0>a&&(a=-a,c="-"),c+Q(~~(a/60),2)+b+Q(~~a%60,2)})}function Ra(a,b){var c=(b||"").match(a)||[],d=c[c.length-1]||[],e=(d+"").match(ie)||["-",0,0],f=+(60*e[1])+r(e[2]);return"+"===e[0]?f:-f}function Sa(b,c){var e,f;return c._isUTC?(e=c.clone(),f=(p(b)||d(b)?b.valueOf():Ka(b).valueOf())-e.valueOf(),e._d.setTime(e._d.valueOf()+f),a.updateOffset(e,!1),e):Ka(b).local()}function Ta(a){return 15*-Math.round(a._d.getTimezoneOffset()/15)}function Ua(b,c){var d,e=this._offset||0;return this.isValid()?null!=b?("string"==typeof b?b=Ra(Hd,b):Math.abs(b)<16&&(b=60*b),!this._isUTC&&c&&(d=Ta(this)),this._offset=b,this._isUTC=!0,null!=d&&this.add(d,"m"),e!==b&&(!c||this._changeInProgress?jb(this,db(b-e,"m"),1,!1):this._changeInProgress||(this._changeInProgress=!0,a.updateOffset(this,!0),this._changeInProgress=null)),this):this._isUTC?e:Ta(this):null!=b?this:NaN}function Va(a,b){return null!=a?("string"!=typeof a&&(a=-a),this.utcOffset(a,b),this):-this.utcOffset()}function Wa(a){return this.utcOffset(0,a)}function Xa(a){return this._isUTC&&(this.utcOffset(0,a),this._isUTC=!1,a&&this.subtract(Ta(this),"m")),this}function Ya(){return this._tzm?this.utcOffset(this._tzm):"string"==typeof this._i&&this.utcOffset(Ra(Gd,this._i)),this}function Za(a){return this.isValid()?(a=a?Ka(a).utcOffset():0,(this.utcOffset()-a)%60===0):!1}function $a(){return this.utcOffset()>this.clone().month(0).utcOffset()||this.utcOffset()>this.clone().month(5).utcOffset()}function _a(){if(!m(this._isDSTShifted))return this._isDSTShifted;var a={};if(n(a,this),a=Ha(a),a._a){var b=a._isUTC?h(a._a):Ka(a._a);this._isDSTShifted=this.isValid()&&s(a._a,b.toArray())>0}else this._isDSTShifted=!1;return this._isDSTShifted}function ab(){return this.isValid()?!this._isUTC:!1}function bb(){return this.isValid()?this._isUTC:!1}function cb(){return this.isValid()?this._isUTC&&0===this._offset:!1}function db(a,b){var c,d,e,g=a,h=null;return Pa(a)?g={ms:a._milliseconds,d:a._days,M:a._months}:"number"==typeof a?(g={},b?g[b]=a:g.milliseconds=a):(h=je.exec(a))?(c="-"===h[1]?-1:1,g={y:0,d:r(h[Od])*c,h:r(h[Pd])*c,m:r(h[Qd])*c,s:r(h[Rd])*c,ms:r(h[Sd])*c}):(h=ke.exec(a))?(c="-"===h[1]?-1:1,g={y:eb(h[2],c),M:eb(h[3],c),w:eb(h[4],c),d:eb(h[5],c),h:eb(h[6],c),m:eb(h[7],c),s:eb(h[8],c)}):null==g?g={}:"object"==typeof g&&("from"in g||"to"in g)&&(e=gb(Ka(g.from),Ka(g.to)),g={},g.ms=e.milliseconds,g.M=e.months),d=new Oa(g),Pa(a)&&f(a,"_locale")&&(d._locale=a._locale),d}function eb(a,b){var c=a&&parseFloat(a.replace(",","."));return(isNaN(c)?0:c)*b}function fb(a,b){var c={milliseconds:0,months:0};return c.months=b.month()-a.month()+12*(b.year()-a.year()),a.clone().add(c.months,"M").isAfter(b)&&--c.months,c.milliseconds=+b-+a.clone().add(c.months,"M"),c}function gb(a,b){var c;return a.isValid()&&b.isValid()?(b=Sa(b,a),a.isBefore(b)?c=fb(a,b):(c=fb(b,a),c.milliseconds=-c.milliseconds,c.months=-c.months),c):{milliseconds:0,months:0}}function hb(a){return 0>a?-1*Math.round(-1*a):Math.round(a)}function ib(a,b){return function(c,d){var e,f;return null===d||isNaN(+d)||(v(b,"moment()."+b+"(period, number) is deprecated. Please use moment()."+b+"(number, period)."),f=c,c=d,d=f),c="string"==typeof c?+c:c,e=db(c,d),jb(this,e,a),this}}function jb(b,c,d,e){var f=c._milliseconds,g=hb(c._days),h=hb(c._months);b.isValid()&&(e=null==e?!0:e,f&&b._d.setTime(b._d.valueOf()+f*d),g&&O(b,"Date",N(b,"Date")+g*d),h&&ga(b,N(b,"Month")+h*d),e&&a.updateOffset(b,g||h))}function kb(a,b){var c=a||Ka(),d=Sa(c,this).startOf("day"),e=this.diff(d,"days",!0),f=-6>e?"sameElse":-1>e?"lastWeek":0>e?"lastDay":1>e?"sameDay":2>e?"nextDay":7>e?"nextWeek":"sameElse",g=b&&(w(b[f])?b[f]():b[f]);return this.format(g||this.localeData().calendar(f,this,Ka(c)))}function lb(){return new o(this)}function mb(a,b){var c=p(a)?a:Ka(a);return this.isValid()&&c.isValid()?(b=K(m(b)?"millisecond":b),"millisecond"===b?this.valueOf()>c.valueOf():c.valueOf()<this.clone().startOf(b).valueOf()):!1}function nb(a,b){var c=p(a)?a:Ka(a);return this.isValid()&&c.isValid()?(b=K(m(b)?"millisecond":b),"millisecond"===b?this.valueOf()<c.valueOf():this.clone().endOf(b).valueOf()<c.valueOf()):!1}function ob(a,b,c,d){return d=d||"()",("("===d[0]?this.isAfter(a,c):!this.isBefore(a,c))&&(")"===d[1]?this.isBefore(b,c):!this.isAfter(b,c))}function pb(a,b){var c,d=p(a)?a:Ka(a);return this.isValid()&&d.isValid()?(b=K(b||"millisecond"),"millisecond"===b?this.valueOf()===d.valueOf():(c=d.valueOf(),this.clone().startOf(b).valueOf()<=c&&c<=this.clone().endOf(b).valueOf())):!1}function qb(a,b){return this.isSame(a,b)||this.isAfter(a,b)}function rb(a,b){return this.isSame(a,b)||this.isBefore(a,b)}function sb(a,b,c){var d,e,f,g;return this.isValid()?(d=Sa(a,this),d.isValid()?(e=6e4*(d.utcOffset()-this.utcOffset()),b=K(b),"year"===b||"month"===b||"quarter"===b?(g=tb(this,d),"quarter"===b?g/=3:"year"===b&&(g/=12)):(f=this-d,g="second"===b?f/1e3:"minute"===b?f/6e4:"hour"===b?f/36e5:"day"===b?(f-e)/864e5:"week"===b?(f-e)/6048e5:f),c?g:q(g)):NaN):NaN}function tb(a,b){var c,d,e=12*(b.year()-a.year())+(b.month()-a.month()),f=a.clone().add(e,"months");return 0>b-f?(c=a.clone().add(e-1,"months"),d=(b-f)/(f-c)):(c=a.clone().add(e+1,"months"),d=(b-f)/(c-f)),-(e+d)||0}function ub(){return this.clone().locale("en").format("ddd MMM DD YYYY HH:mm:ss [GMT]ZZ")}function vb(){var a=this.clone().utc();return 0<a.year()&&a.year()<=9999?w(Date.prototype.toISOString)?this.toDate().toISOString():U(a,"YYYY-MM-DD[T]HH:mm:ss.SSS[Z]"):U(a,"YYYYYY-MM-DD[T]HH:mm:ss.SSS[Z]")}function wb(b){b||(b=this.isUtc()?a.defaultFormatUtc:a.defaultFormat);var c=U(this,b);return this.localeData().postformat(c)}function xb(a,b){return this.isValid()&&(p(a)&&a.isValid()||Ka(a).isValid())?db({to:this,from:a}).locale(this.locale()).humanize(!b):this.localeData().invalidDate()}function yb(a){return this.from(Ka(),a)}function zb(a,b){return this.isValid()&&(p(a)&&a.isValid()||Ka(a).isValid())?db({from:this,to:a}).locale(this.locale()).humanize(!b):this.localeData().invalidDate()}function Ab(a){return this.to(Ka(),a)}function Bb(a){var b;return void 0===a?this._locale._abbr:(b=H(a),null!=b&&(this._locale=b),this)}function Cb(){return this._locale}function Db(a){switch(a=K(a)){case"year":this.month(0);case"quarter":case"month":this.date(1);case"week":case"isoWeek":case"day":case"date":this.hours(0);case"hour":this.minutes(0);case"minute":this.seconds(0);case"second":this.milliseconds(0)}return"week"===a&&this.weekday(0),"isoWeek"===a&&this.isoWeekday(1),"quarter"===a&&this.month(3*Math.floor(this.month()/3)),this}function Eb(a){return a=K(a),void 0===a||"millisecond"===a?this:("date"===a&&(a="day"),this.startOf(a).add(1,"isoWeek"===a?"week":a).subtract(1,"ms"))}function Fb(){return this._d.valueOf()-6e4*(this._offset||0)}function Gb(){return Math.floor(this.valueOf()/1e3)}function Hb(){return this._offset?new Date(this.valueOf()):this._d}function Ib(){var a=this;return[a.year(),a.month(),a.date(),a.hour(),a.minute(),a.second(),a.millisecond()]}function Jb(){var a=this;return{years:a.year(),months:a.month(),date:a.date(),hours:a.hours(),minutes:a.minutes(),seconds:a.seconds(),milliseconds:a.milliseconds()}}function Kb(){return this.isValid()?this.toISOString():null}function Lb(){return k(this)}function Mb(){return g({},j(this))}function Nb(){return j(this).overflow}function Ob(){return{input:this._i,format:this._f,locale:this._locale,isUTC:this._isUTC,strict:this._strict}}function Pb(a,b){R(0,[a,a.length],0,b)}function Qb(a){return Ub.call(this,a,this.week(),this.weekday(),this.localeData()._week.dow,this.localeData()._week.doy)}function Rb(a){return Ub.call(this,a,this.isoWeek(),this.isoWeekday(),1,4)}function Sb(){return xa(this.year(),1,4)}function Tb(){var a=this.localeData()._week;return xa(this.year(),a.dow,a.doy)}function Ub(a,b,c,d,e){var f;return null==a?wa(this,d,e).year:(f=xa(a,d,e),b>f&&(b=f),Vb.call(this,a,b,c,d,e))}function Vb(a,b,c,d,e){var f=va(a,b,c,d,e),g=qa(f.year,0,f.dayOfYear);return this.year(g.getUTCFullYear()),this.month(g.getUTCMonth()),this.date(g.getUTCDate()),this}function Wb(a){return null==a?Math.ceil((this.month()+1)/3):this.month(3*(a-1)+this.month()%3)}function Xb(a){return wa(a,this._week.dow,this._week.doy).week}function Yb(){return this._week.dow}function Zb(){return this._week.doy}function $b(a){var b=this.localeData().week(this);return null==a?b:this.add(7*(a-b),"d")}function _b(a){var b=wa(this,1,4).week;return null==a?b:this.add(7*(a-b),"d")}function ac(a,b){return"string"!=typeof a?a:isNaN(a)?(a=b.weekdaysParse(a),"number"==typeof a?a:null):parseInt(a,10)}function bc(a,b){return c(this._weekdays)?this._weekdays[a.day()]:this._weekdays[this._weekdays.isFormat.test(b)?"format":"standalone"][a.day()]}function cc(a){return this._weekdaysShort[a.day()]}function dc(a){return this._weekdaysMin[a.day()]}function ec(a,b,c){var d,e,f,g=a.toLocaleLowerCase();if(!this._weekdaysParse)for(this._weekdaysParse=[],this._shortWeekdaysParse=[],this._minWeekdaysParse=[],d=0;7>d;++d)f=h([2e3,1]).day(d),this._minWeekdaysParse[d]=this.weekdaysMin(f,"").toLocaleLowerCase(),this._shortWeekdaysParse[d]=this.weekdaysShort(f,"").toLocaleLowerCase(),this._weekdaysParse[d]=this.weekdays(f,"").toLocaleLowerCase();return c?"dddd"===b?(e=md.call(this._weekdaysParse,g),-1!==e?e:null):"ddd"===b?(e=md.call(this._shortWeekdaysParse,g),-1!==e?e:null):(e=md.call(this._minWeekdaysParse,g),-1!==e?e:null):"dddd"===b?(e=md.call(this._weekdaysParse,g),-1!==e?e:(e=md.call(this._shortWeekdaysParse,g),-1!==e?e:(e=md.call(this._minWeekdaysParse,g),-1!==e?e:null))):"ddd"===b?(e=md.call(this._shortWeekdaysParse,g),-1!==e?e:(e=md.call(this._weekdaysParse,g),-1!==e?e:(e=md.call(this._minWeekdaysParse,g),-1!==e?e:null))):(e=md.call(this._minWeekdaysParse,g),-1!==e?e:(e=md.call(this._weekdaysParse,g),-1!==e?e:(e=md.call(this._shortWeekdaysParse,g),-1!==e?e:null)))}function fc(a,b,c){var d,e,f;if(this._weekdaysParseExact)return ec.call(this,a,b,c);for(this._weekdaysParse||(this._weekdaysParse=[],this._minWeekdaysParse=[],this._shortWeekdaysParse=[],this._fullWeekdaysParse=[]),d=0;7>d;d++){if(e=h([2e3,1]).day(d),c&&!this._fullWeekdaysParse[d]&&(this._fullWeekdaysParse[d]=new RegExp("^"+this.weekdays(e,"").replace(".",".?")+"$","i"),this._shortWeekdaysParse[d]=new RegExp("^"+this.weekdaysShort(e,"").replace(".",".?")+"$","i"),this._minWeekdaysParse[d]=new RegExp("^"+this.weekdaysMin(e,"").replace(".",".?")+"$","i")),this._weekdaysParse[d]||(f="^"+this.weekdays(e,"")+"|^"+this.weekdaysShort(e,"")+"|^"+this.weekdaysMin(e,""),this._weekdaysParse[d]=new RegExp(f.replace(".",""),"i")),c&&"dddd"===b&&this._fullWeekdaysParse[d].test(a))return d;if(c&&"ddd"===b&&this._shortWeekdaysParse[d].test(a))return d;if(c&&"dd"===b&&this._minWeekdaysParse[d].test(a))return d;if(!c&&this._weekdaysParse[d].test(a))return d}}function gc(a){if(!this.isValid())return null!=a?this:NaN;var b=this._isUTC?this._d.getUTCDay():this._d.getDay();return null!=a?(a=ac(a,this.localeData()),this.add(a-b,"d")):b}function hc(a){if(!this.isValid())return null!=a?this:NaN;var b=(this.day()+7-this.localeData()._week.dow)%7;return null==a?b:this.add(a-b,"d")}function ic(a){return this.isValid()?null==a?this.day()||7:this.day(this.day()%7?a:a-7):null!=a?this:NaN}function jc(a){return this._weekdaysParseExact?(f(this,"_weekdaysRegex")||mc.call(this),a?this._weekdaysStrictRegex:this._weekdaysRegex):this._weekdaysStrictRegex&&a?this._weekdaysStrictRegex:this._weekdaysRegex}function kc(a){return this._weekdaysParseExact?(f(this,"_weekdaysRegex")||mc.call(this),a?this._weekdaysShortStrictRegex:this._weekdaysShortRegex):this._weekdaysShortStrictRegex&&a?this._weekdaysShortStrictRegex:this._weekdaysShortRegex}function lc(a){return this._weekdaysParseExact?(f(this,"_weekdaysRegex")||mc.call(this),a?this._weekdaysMinStrictRegex:this._weekdaysMinRegex):this._weekdaysMinStrictRegex&&a?this._weekdaysMinStrictRegex:this._weekdaysMinRegex}function mc(){function a(a,b){return b.length-a.length}var b,c,d,e,f,g=[],i=[],j=[],k=[];for(b=0;7>b;b++)c=h([2e3,1]).day(b),d=this.weekdaysMin(c,""),e=this.weekdaysShort(c,""),f=this.weekdays(c,""),g.push(d),i.push(e),j.push(f),k.push(d),k.push(e),k.push(f);for(g.sort(a),i.sort(a),j.sort(a),k.sort(a),b=0;7>b;b++)i[b]=Z(i[b]),j[b]=Z(j[b]),k[b]=Z(k[b]);this._weekdaysRegex=new RegExp("^("+k.join("|")+")","i"),this._weekdaysShortRegex=this._weekdaysRegex,this._weekdaysMinRegex=this._weekdaysRegex,this._weekdaysStrictRegex=new RegExp("^("+j.join("|")+")","i"),this._weekdaysShortStrictRegex=new RegExp("^("+i.join("|")+")","i"),this._weekdaysMinStrictRegex=new RegExp("^("+g.join("|")+")","i")}function nc(a){var b=Math.round((this.clone().startOf("day")-this.clone().startOf("year"))/864e5)+1;return null==a?b:this.add(a-b,"d")}function oc(){return this.hours()%12||12}function pc(){return this.hours()||24}function qc(a,b){R(a,0,0,function(){return this.localeData().meridiem(this.hours(),this.minutes(),b)})}function rc(a,b){return b._meridiemParse}function sc(a){return"p"===(a+"").toLowerCase().charAt(0)}function tc(a,b,c){return a>11?c?"pm":"PM":c?"am":"AM"}function uc(a,b){b[Sd]=r(1e3*("0."+a))}function vc(){return this._isUTC?"UTC":""}function wc(){return this._isUTC?"Coordinated Universal Time":""}function xc(a){return Ka(1e3*a)}function yc(){return Ka.apply(null,arguments).parseZone()}function zc(a,b,c){var d=this._calendar[a];return w(d)?d.call(b,c):d}function Ac(a){var b=this._longDateFormat[a],c=this._longDateFormat[a.toUpperCase()];return b||!c?b:(this._longDateFormat[a]=c.replace(/MMMM|MM|DD|dddd/g,function(a){return a.slice(1)}),this._longDateFormat[a])}function Bc(){return this._invalidDate}function Cc(a){return this._ordinal.replace("%d",a)}function Dc(a){return a}function Ec(a,b,c,d){var e=this._relativeTime[c];return w(e)?e(a,b,c,d):e.replace(/%d/i,a)}function Fc(a,b){var c=this._relativeTime[a>0?"future":"past"];return w(c)?c(b):c.replace(/%s/i,b)}function Gc(a,b,c,d){var e=H(),f=h().set(d,b);return e[c](f,a)}function Hc(a,b,c){if("number"==typeof a&&(b=a,a=void 0),a=a||"",null!=b)return Gc(a,b,c,"month");var d,e=[];for(d=0;12>d;d++)e[d]=Gc(a,d,c,"month");return e}function Ic(a,b,c,d){"boolean"==typeof a?("number"==typeof b&&(c=b,b=void 0),b=b||""):(b=a,c=b,a=!1,"number"==typeof b&&(c=b,b=void 0),b=b||"");var e=H(),f=a?e._week.dow:0;if(null!=c)return Gc(b,(c+f)%7,d,"day");var g,h=[];for(g=0;7>g;g++)h[g]=Gc(b,(g+f)%7,d,"day");return h}function Jc(a,b){return Hc(a,b,"months")}function Kc(a,b){return Hc(a,b,"monthsShort")}function Lc(a,b,c){return Ic(a,b,c,"weekdays")}function Mc(a,b,c){return Ic(a,b,c,"weekdaysShort")}function Nc(a,b,c){return Ic(a,b,c,"weekdaysMin")}function Oc(){var a=this._data;return this._milliseconds=Le(this._milliseconds),this._days=Le(this._days),this._months=Le(this._months),a.milliseconds=Le(a.milliseconds),a.seconds=Le(a.seconds),a.minutes=Le(a.minutes),a.hours=Le(a.hours),a.months=Le(a.months),a.years=Le(a.years),this}function Pc(a,b,c,d){var e=db(b,c);return a._milliseconds+=d*e._milliseconds,a._days+=d*e._days,a._months+=d*e._months,a._bubble()}function Qc(a,b){return Pc(this,a,b,1)}function Rc(a,b){return Pc(this,a,b,-1)}function Sc(a){return 0>a?Math.floor(a):Math.ceil(a)}function Tc(){var a,b,c,d,e,f=this._milliseconds,g=this._days,h=this._months,i=this._data;return f>=0&&g>=0&&h>=0||0>=f&&0>=g&&0>=h||(f+=864e5*Sc(Vc(h)+g),g=0,h=0),i.milliseconds=f%1e3,a=q(f/1e3),i.seconds=a%60,b=q(a/60),i.minutes=b%60,c=q(b/60),i.hours=c%24,g+=q(c/24),e=q(Uc(g)),h+=e,g-=Sc(Vc(e)),d=q(h/12),h%=12,i.days=g,i.months=h,i.years=d,this}function Uc(a){return 4800*a/146097}function Vc(a){return 146097*a/4800}function Wc(a){var b,c,d=this._milliseconds;if(a=K(a),"month"===a||"year"===a)return b=this._days+d/864e5,c=this._months+Uc(b),"month"===a?c:c/12;switch(b=this._days+Math.round(Vc(this._months)),a){case"week":return b/7+d/6048e5;case"day":return b+d/864e5;case"hour":return 24*b+d/36e5;case"minute":return 1440*b+d/6e4;case"second":return 86400*b+d/1e3;case"millisecond":return Math.floor(864e5*b)+d;default:throw new Error("Unknown unit "+a)}}function Xc(){return this._milliseconds+864e5*this._days+this._months%12*2592e6+31536e6*r(this._months/12)}function Yc(a){return function(){return this.as(a)}}function Zc(a){
return a=K(a),this[a+"s"]()}function $c(a){return function(){return this._data[a]}}function _c(){return q(this.days()/7)}function ad(a,b,c,d,e){return e.relativeTime(b||1,!!c,a,d)}function bd(a,b,c){var d=db(a).abs(),e=_e(d.as("s")),f=_e(d.as("m")),g=_e(d.as("h")),h=_e(d.as("d")),i=_e(d.as("M")),j=_e(d.as("y")),k=e<af.s&&["s",e]||1>=f&&["m"]||f<af.m&&["mm",f]||1>=g&&["h"]||g<af.h&&["hh",g]||1>=h&&["d"]||h<af.d&&["dd",h]||1>=i&&["M"]||i<af.M&&["MM",i]||1>=j&&["y"]||["yy",j];return k[2]=b,k[3]=+a>0,k[4]=c,ad.apply(null,k)}function cd(a,b){return void 0===af[a]?!1:void 0===b?af[a]:(af[a]=b,!0)}function dd(a){var b=this.localeData(),c=bd(this,!a,b);return a&&(c=b.pastFuture(+this,c)),b.postformat(c)}function ed(){var a,b,c,d=bf(this._milliseconds)/1e3,e=bf(this._days),f=bf(this._months);a=q(d/60),b=q(a/60),d%=60,a%=60,c=q(f/12),f%=12;var g=c,h=f,i=e,j=b,k=a,l=d,m=this.asSeconds();return m?(0>m?"-":"")+"P"+(g?g+"Y":"")+(h?h+"M":"")+(i?i+"D":"")+(j||k||l?"T":"")+(j?j+"H":"")+(k?k+"M":"")+(l?l+"S":""):"P0D"}var fd,gd;gd=Array.prototype.some?Array.prototype.some:function(a){for(var b=Object(this),c=b.length>>>0,d=0;c>d;d++)if(d in b&&a.call(this,b[d],d,b))return!0;return!1};var hd=a.momentProperties=[],id=!1,jd={};a.suppressDeprecationWarnings=!1,a.deprecationHandler=null;var kd;kd=Object.keys?Object.keys:function(a){var b,c=[];for(b in a)f(a,b)&&c.push(b);return c};var ld,md,nd={},od={},pd=/(\[[^\[]*\])|(\\)?([Hh]mm(ss)?|Mo|MM?M?M?|Do|DDDo|DD?D?D?|ddd?d?|do?|w[o|w]?|W[o|W]?|Qo?|YYYYYY|YYYYY|YYYY|YY|gg(ggg?)?|GG(GGG?)?|e|E|a|A|hh?|HH?|kk?|mm?|ss?|S{1,9}|x|X|zz?|ZZ?|.)/g,qd=/(\[[^\[]*\])|(\\)?(LTS|LT|LL?L?L?|l{1,4})/g,rd={},sd={},td=/\d/,ud=/\d\d/,vd=/\d{3}/,wd=/\d{4}/,xd=/[+-]?\d{6}/,yd=/\d\d?/,zd=/\d\d\d\d?/,Ad=/\d\d\d\d\d\d?/,Bd=/\d{1,3}/,Cd=/\d{1,4}/,Dd=/[+-]?\d{1,6}/,Ed=/\d+/,Fd=/[+-]?\d+/,Gd=/Z|[+-]\d\d:?\d\d/gi,Hd=/Z|[+-]\d\d(?::?\d\d)?/gi,Id=/[+-]?\d+(\.\d{1,3})?/,Jd=/[0-9]*['a-z\u00A0-\u05FF\u0700-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]+|[\u0600-\u06FF\/]+(\s*?[\u0600-\u06FF]+){1,2}/i,Kd={},Ld={},Md=0,Nd=1,Od=2,Pd=3,Qd=4,Rd=5,Sd=6,Td=7,Ud=8;md=Array.prototype.indexOf?Array.prototype.indexOf:function(a){var b;for(b=0;b<this.length;++b)if(this[b]===a)return b;return-1},R("M",["MM",2],"Mo",function(){return this.month()+1}),R("MMM",0,0,function(a){return this.localeData().monthsShort(this,a)}),R("MMMM",0,0,function(a){return this.localeData().months(this,a)}),J("month","M"),W("M",yd),W("MM",yd,ud),W("MMM",function(a,b){return b.monthsShortRegex(a)}),W("MMMM",function(a,b){return b.monthsRegex(a)}),$(["M","MM"],function(a,b){b[Nd]=r(a)-1}),$(["MMM","MMMM"],function(a,b,c,d){var e=c._locale.monthsParse(a,d,c._strict);null!=e?b[Nd]=e:j(c).invalidMonth=a});var Vd=/D[oD]?(\[[^\[\]]*\]|\s+)+MMMM?/,Wd="January_February_March_April_May_June_July_August_September_October_November_December".split("_"),Xd="Jan_Feb_Mar_Apr_May_Jun_Jul_Aug_Sep_Oct_Nov_Dec".split("_"),Yd=Jd,Zd=Jd,$d=/^\s*((?:[+-]\d{6}|\d{4})-(?:\d\d-\d\d|W\d\d-\d|W\d\d|\d\d\d|\d\d))(?:(T| )(\d\d(?::\d\d(?::\d\d(?:[.,]\d+)?)?)?)([\+\-]\d\d(?::?\d\d)?|\s*Z)?)?/,_d=/^\s*((?:[+-]\d{6}|\d{4})(?:\d\d\d\d|W\d\d\d|W\d\d|\d\d\d|\d\d))(?:(T| )(\d\d(?:\d\d(?:\d\d(?:[.,]\d+)?)?)?)([\+\-]\d\d(?::?\d\d)?|\s*Z)?)?/,ae=/Z|[+-]\d\d(?::?\d\d)?/,be=[["YYYYYY-MM-DD",/[+-]\d{6}-\d\d-\d\d/],["YYYY-MM-DD",/\d{4}-\d\d-\d\d/],["GGGG-[W]WW-E",/\d{4}-W\d\d-\d/],["GGGG-[W]WW",/\d{4}-W\d\d/,!1],["YYYY-DDD",/\d{4}-\d{3}/],["YYYY-MM",/\d{4}-\d\d/,!1],["YYYYYYMMDD",/[+-]\d{10}/],["YYYYMMDD",/\d{8}/],["GGGG[W]WWE",/\d{4}W\d{3}/],["GGGG[W]WW",/\d{4}W\d{2}/,!1],["YYYYDDD",/\d{7}/]],ce=[["HH:mm:ss.SSSS",/\d\d:\d\d:\d\d\.\d+/],["HH:mm:ss,SSSS",/\d\d:\d\d:\d\d,\d+/],["HH:mm:ss",/\d\d:\d\d:\d\d/],["HH:mm",/\d\d:\d\d/],["HHmmss.SSSS",/\d\d\d\d\d\d\.\d+/],["HHmmss,SSSS",/\d\d\d\d\d\d,\d+/],["HHmmss",/\d\d\d\d\d\d/],["HHmm",/\d\d\d\d/],["HH",/\d\d/]],de=/^\/?Date\((\-?\d+)/i;a.createFromInputFallback=u("moment construction falls back to js Date. This is discouraged and will be removed in upcoming major release. Please refer to https://github.com/moment/moment/issues/1407 for more info.",function(a){a._d=new Date(a._i+(a._useUTC?" UTC":""))}),R("Y",0,0,function(){var a=this.year();return 9999>=a?""+a:"+"+a}),R(0,["YY",2],0,function(){return this.year()%100}),R(0,["YYYY",4],0,"year"),R(0,["YYYYY",5],0,"year"),R(0,["YYYYYY",6,!0],0,"year"),J("year","y"),W("Y",Fd),W("YY",yd,ud),W("YYYY",Cd,wd),W("YYYYY",Dd,xd),W("YYYYYY",Dd,xd),$(["YYYYY","YYYYYY"],Md),$("YYYY",function(b,c){c[Md]=2===b.length?a.parseTwoDigitYear(b):r(b)}),$("YY",function(b,c){c[Md]=a.parseTwoDigitYear(b)}),$("Y",function(a,b){b[Md]=parseInt(a,10)}),a.parseTwoDigitYear=function(a){return r(a)+(r(a)>68?1900:2e3)};var ee=M("FullYear",!0);a.ISO_8601=function(){};var fe=u("moment().min is deprecated, use moment.max instead. https://github.com/moment/moment/issues/1548",function(){var a=Ka.apply(null,arguments);return this.isValid()&&a.isValid()?this>a?this:a:l()}),ge=u("moment().max is deprecated, use moment.min instead. https://github.com/moment/moment/issues/1548",function(){var a=Ka.apply(null,arguments);return this.isValid()&&a.isValid()?a>this?this:a:l()}),he=function(){return Date.now?Date.now():+new Date};Qa("Z",":"),Qa("ZZ",""),W("Z",Hd),W("ZZ",Hd),$(["Z","ZZ"],function(a,b,c){c._useUTC=!0,c._tzm=Ra(Hd,a)});var ie=/([\+\-]|\d\d)/gi;a.updateOffset=function(){};var je=/^(\-)?(?:(\d*)[. ])?(\d+)\:(\d+)(?:\:(\d+)\.?(\d{3})?\d*)?$/,ke=/^(-)?P(?:(-?[0-9,.]*)Y)?(?:(-?[0-9,.]*)M)?(?:(-?[0-9,.]*)W)?(?:(-?[0-9,.]*)D)?(?:T(?:(-?[0-9,.]*)H)?(?:(-?[0-9,.]*)M)?(?:(-?[0-9,.]*)S)?)?$/;db.fn=Oa.prototype;var le=ib(1,"add"),me=ib(-1,"subtract");a.defaultFormat="YYYY-MM-DDTHH:mm:ssZ",a.defaultFormatUtc="YYYY-MM-DDTHH:mm:ss[Z]";var ne=u("moment().lang() is deprecated. Instead, use moment().localeData() to get the language configuration. Use moment().locale() to change languages.",function(a){return void 0===a?this.localeData():this.locale(a)});R(0,["gg",2],0,function(){return this.weekYear()%100}),R(0,["GG",2],0,function(){return this.isoWeekYear()%100}),Pb("gggg","weekYear"),Pb("ggggg","weekYear"),Pb("GGGG","isoWeekYear"),Pb("GGGGG","isoWeekYear"),J("weekYear","gg"),J("isoWeekYear","GG"),W("G",Fd),W("g",Fd),W("GG",yd,ud),W("gg",yd,ud),W("GGGG",Cd,wd),W("gggg",Cd,wd),W("GGGGG",Dd,xd),W("ggggg",Dd,xd),_(["gggg","ggggg","GGGG","GGGGG"],function(a,b,c,d){b[d.substr(0,2)]=r(a)}),_(["gg","GG"],function(b,c,d,e){c[e]=a.parseTwoDigitYear(b)}),R("Q",0,"Qo","quarter"),J("quarter","Q"),W("Q",td),$("Q",function(a,b){b[Nd]=3*(r(a)-1)}),R("w",["ww",2],"wo","week"),R("W",["WW",2],"Wo","isoWeek"),J("week","w"),J("isoWeek","W"),W("w",yd),W("ww",yd,ud),W("W",yd),W("WW",yd,ud),_(["w","ww","W","WW"],function(a,b,c,d){b[d.substr(0,1)]=r(a)});var oe={dow:0,doy:6};R("D",["DD",2],"Do","date"),J("date","D"),W("D",yd),W("DD",yd,ud),W("Do",function(a,b){return a?b._ordinalParse:b._ordinalParseLenient}),$(["D","DD"],Od),$("Do",function(a,b){b[Od]=r(a.match(yd)[0],10)});var pe=M("Date",!0);R("d",0,"do","day"),R("dd",0,0,function(a){return this.localeData().weekdaysMin(this,a)}),R("ddd",0,0,function(a){return this.localeData().weekdaysShort(this,a)}),R("dddd",0,0,function(a){return this.localeData().weekdays(this,a)}),R("e",0,0,"weekday"),R("E",0,0,"isoWeekday"),J("day","d"),J("weekday","e"),J("isoWeekday","E"),W("d",yd),W("e",yd),W("E",yd),W("dd",function(a,b){return b.weekdaysMinRegex(a)}),W("ddd",function(a,b){return b.weekdaysShortRegex(a)}),W("dddd",function(a,b){return b.weekdaysRegex(a)}),_(["dd","ddd","dddd"],function(a,b,c,d){var e=c._locale.weekdaysParse(a,d,c._strict);null!=e?b.d=e:j(c).invalidWeekday=a}),_(["d","e","E"],function(a,b,c,d){b[d]=r(a)});var qe="Sunday_Monday_Tuesday_Wednesday_Thursday_Friday_Saturday".split("_"),re="Sun_Mon_Tue_Wed_Thu_Fri_Sat".split("_"),se="Su_Mo_Tu_We_Th_Fr_Sa".split("_"),te=Jd,ue=Jd,ve=Jd;R("DDD",["DDDD",3],"DDDo","dayOfYear"),J("dayOfYear","DDD"),W("DDD",Bd),W("DDDD",vd),$(["DDD","DDDD"],function(a,b,c){c._dayOfYear=r(a)}),R("H",["HH",2],0,"hour"),R("h",["hh",2],0,oc),R("k",["kk",2],0,pc),R("hmm",0,0,function(){return""+oc.apply(this)+Q(this.minutes(),2)}),R("hmmss",0,0,function(){return""+oc.apply(this)+Q(this.minutes(),2)+Q(this.seconds(),2)}),R("Hmm",0,0,function(){return""+this.hours()+Q(this.minutes(),2)}),R("Hmmss",0,0,function(){return""+this.hours()+Q(this.minutes(),2)+Q(this.seconds(),2)}),qc("a",!0),qc("A",!1),J("hour","h"),W("a",rc),W("A",rc),W("H",yd),W("h",yd),W("HH",yd,ud),W("hh",yd,ud),W("hmm",zd),W("hmmss",Ad),W("Hmm",zd),W("Hmmss",Ad),$(["H","HH"],Pd),$(["a","A"],function(a,b,c){c._isPm=c._locale.isPM(a),c._meridiem=a}),$(["h","hh"],function(a,b,c){b[Pd]=r(a),j(c).bigHour=!0}),$("hmm",function(a,b,c){var d=a.length-2;b[Pd]=r(a.substr(0,d)),b[Qd]=r(a.substr(d)),j(c).bigHour=!0}),$("hmmss",function(a,b,c){var d=a.length-4,e=a.length-2;b[Pd]=r(a.substr(0,d)),b[Qd]=r(a.substr(d,2)),b[Rd]=r(a.substr(e)),j(c).bigHour=!0}),$("Hmm",function(a,b,c){var d=a.length-2;b[Pd]=r(a.substr(0,d)),b[Qd]=r(a.substr(d))}),$("Hmmss",function(a,b,c){var d=a.length-4,e=a.length-2;b[Pd]=r(a.substr(0,d)),b[Qd]=r(a.substr(d,2)),b[Rd]=r(a.substr(e))});var we=/[ap]\.?m?\.?/i,xe=M("Hours",!0);R("m",["mm",2],0,"minute"),J("minute","m"),W("m",yd),W("mm",yd,ud),$(["m","mm"],Qd);var ye=M("Minutes",!1);R("s",["ss",2],0,"second"),J("second","s"),W("s",yd),W("ss",yd,ud),$(["s","ss"],Rd);var ze=M("Seconds",!1);R("S",0,0,function(){return~~(this.millisecond()/100)}),R(0,["SS",2],0,function(){return~~(this.millisecond()/10)}),R(0,["SSS",3],0,"millisecond"),R(0,["SSSS",4],0,function(){return 10*this.millisecond()}),R(0,["SSSSS",5],0,function(){return 100*this.millisecond()}),R(0,["SSSSSS",6],0,function(){return 1e3*this.millisecond()}),R(0,["SSSSSSS",7],0,function(){return 1e4*this.millisecond()}),R(0,["SSSSSSSS",8],0,function(){return 1e5*this.millisecond()}),R(0,["SSSSSSSSS",9],0,function(){return 1e6*this.millisecond()}),J("millisecond","ms"),W("S",Bd,td),W("SS",Bd,ud),W("SSS",Bd,vd);var Ae;for(Ae="SSSS";Ae.length<=9;Ae+="S")W(Ae,Ed);for(Ae="S";Ae.length<=9;Ae+="S")$(Ae,uc);var Be=M("Milliseconds",!1);R("z",0,0,"zoneAbbr"),R("zz",0,0,"zoneName");var Ce=o.prototype;Ce.add=le,Ce.calendar=kb,Ce.clone=lb,Ce.diff=sb,Ce.endOf=Eb,Ce.format=wb,Ce.from=xb,Ce.fromNow=yb,Ce.to=zb,Ce.toNow=Ab,Ce.get=P,Ce.invalidAt=Nb,Ce.isAfter=mb,Ce.isBefore=nb,Ce.isBetween=ob,Ce.isSame=pb,Ce.isSameOrAfter=qb,Ce.isSameOrBefore=rb,Ce.isValid=Lb,Ce.lang=ne,Ce.locale=Bb,Ce.localeData=Cb,Ce.max=ge,Ce.min=fe,Ce.parsingFlags=Mb,Ce.set=P,Ce.startOf=Db,Ce.subtract=me,Ce.toArray=Ib,Ce.toObject=Jb,Ce.toDate=Hb,Ce.toISOString=vb,Ce.toJSON=Kb,Ce.toString=ub,Ce.unix=Gb,Ce.valueOf=Fb,Ce.creationData=Ob,Ce.year=ee,Ce.isLeapYear=ta,Ce.weekYear=Qb,Ce.isoWeekYear=Rb,Ce.quarter=Ce.quarters=Wb,Ce.month=ha,Ce.daysInMonth=ia,Ce.week=Ce.weeks=$b,Ce.isoWeek=Ce.isoWeeks=_b,Ce.weeksInYear=Tb,Ce.isoWeeksInYear=Sb,Ce.date=pe,Ce.day=Ce.days=gc,Ce.weekday=hc,Ce.isoWeekday=ic,Ce.dayOfYear=nc,Ce.hour=Ce.hours=xe,Ce.minute=Ce.minutes=ye,Ce.second=Ce.seconds=ze,Ce.millisecond=Ce.milliseconds=Be,Ce.utcOffset=Ua,Ce.utc=Wa,Ce.local=Xa,Ce.parseZone=Ya,Ce.hasAlignedHourOffset=Za,Ce.isDST=$a,Ce.isDSTShifted=_a,Ce.isLocal=ab,Ce.isUtcOffset=bb,Ce.isUtc=cb,Ce.isUTC=cb,Ce.zoneAbbr=vc,Ce.zoneName=wc,Ce.dates=u("dates accessor is deprecated. Use date instead.",pe),Ce.months=u("months accessor is deprecated. Use month instead",ha),Ce.years=u("years accessor is deprecated. Use year instead",ee),Ce.zone=u("moment().zone is deprecated, use moment().utcOffset instead. https://github.com/moment/moment/issues/1779",Va);var De=Ce,Ee={sameDay:"[Today at] LT",nextDay:"[Tomorrow at] LT",nextWeek:"dddd [at] LT",lastDay:"[Yesterday at] LT",lastWeek:"[Last] dddd [at] LT",sameElse:"L"},Fe={LTS:"h:mm:ss A",LT:"h:mm A",L:"MM/DD/YYYY",LL:"MMMM D, YYYY",LLL:"MMMM D, YYYY h:mm A",LLLL:"dddd, MMMM D, YYYY h:mm A"},Ge="Invalid date",He="%d",Ie=/\d{1,2}/,Je={future:"in %s",past:"%s ago",s:"a few seconds",m:"a minute",mm:"%d minutes",h:"an hour",hh:"%d hours",d:"a day",dd:"%d days",M:"a month",MM:"%d months",y:"a year",yy:"%d years"},Ke=A.prototype;Ke._calendar=Ee,Ke.calendar=zc,Ke._longDateFormat=Fe,Ke.longDateFormat=Ac,Ke._invalidDate=Ge,Ke.invalidDate=Bc,Ke._ordinal=He,Ke.ordinal=Cc,Ke._ordinalParse=Ie,Ke.preparse=Dc,Ke.postformat=Dc,Ke._relativeTime=Je,Ke.relativeTime=Ec,Ke.pastFuture=Fc,Ke.set=y,Ke.months=ca,Ke._months=Wd,Ke.monthsShort=da,Ke._monthsShort=Xd,Ke.monthsParse=fa,Ke._monthsRegex=Zd,Ke.monthsRegex=ka,Ke._monthsShortRegex=Yd,Ke.monthsShortRegex=ja,Ke.week=Xb,Ke._week=oe,Ke.firstDayOfYear=Zb,Ke.firstDayOfWeek=Yb,Ke.weekdays=bc,Ke._weekdays=qe,Ke.weekdaysMin=dc,Ke._weekdaysMin=se,Ke.weekdaysShort=cc,Ke._weekdaysShort=re,Ke.weekdaysParse=fc,Ke._weekdaysRegex=te,Ke.weekdaysRegex=jc,Ke._weekdaysShortRegex=ue,Ke.weekdaysShortRegex=kc,Ke._weekdaysMinRegex=ve,Ke.weekdaysMinRegex=lc,Ke.isPM=sc,Ke._meridiemParse=we,Ke.meridiem=tc,E("en",{ordinalParse:/\d{1,2}(th|st|nd|rd)/,ordinal:function(a){var b=a%10,c=1===r(a%100/10)?"th":1===b?"st":2===b?"nd":3===b?"rd":"th";return a+c}}),a.lang=u("moment.lang is deprecated. Use moment.locale instead.",E),a.langData=u("moment.langData is deprecated. Use moment.localeData instead.",H);var Le=Math.abs,Me=Yc("ms"),Ne=Yc("s"),Oe=Yc("m"),Pe=Yc("h"),Qe=Yc("d"),Re=Yc("w"),Se=Yc("M"),Te=Yc("y"),Ue=$c("milliseconds"),Ve=$c("seconds"),We=$c("minutes"),Xe=$c("hours"),Ye=$c("days"),Ze=$c("months"),$e=$c("years"),_e=Math.round,af={s:45,m:45,h:22,d:26,M:11},bf=Math.abs,cf=Oa.prototype;cf.abs=Oc,cf.add=Qc,cf.subtract=Rc,cf.as=Wc,cf.asMilliseconds=Me,cf.asSeconds=Ne,cf.asMinutes=Oe,cf.asHours=Pe,cf.asDays=Qe,cf.asWeeks=Re,cf.asMonths=Se,cf.asYears=Te,cf.valueOf=Xc,cf._bubble=Tc,cf.get=Zc,cf.milliseconds=Ue,cf.seconds=Ve,cf.minutes=We,cf.hours=Xe,cf.days=Ye,cf.weeks=_c,cf.months=Ze,cf.years=$e,cf.humanize=dd,cf.toISOString=ed,cf.toString=ed,cf.toJSON=ed,cf.locale=Bb,cf.localeData=Cb,cf.toIsoString=u("toIsoString() is deprecated. Please use toISOString() instead (notice the capitals)",ed),cf.lang=ne,R("X",0,0,"unix"),R("x",0,0,"valueOf"),W("x",Fd),W("X",Id),$("X",function(a,b,c){c._d=new Date(1e3*parseFloat(a,10))}),$("x",function(a,b,c){c._d=new Date(r(a))}),a.version="2.13.0",b(Ka),a.fn=De,a.min=Ma,a.max=Na,a.now=he,a.utc=h,a.unix=xc,a.months=Jc,a.isDate=d,a.locale=E,a.invalid=l,a.duration=db,a.isMoment=p,a.weekdays=Lc,a.parseZone=yc,a.localeData=H,a.isDuration=Pa,a.monthsShort=Kc,a.weekdaysMin=Nc,a.defineLocale=F,a.updateLocale=G,a.locales=I,a.weekdaysShort=Mc,a.normalizeUnits=K,a.relativeTimeThreshold=cd,a.prototype=De;var df=a;return df});

(function() {
  var app;

  app = angular.module('ChainCommon', ['ChainCommon-Templates', 'ChainDomainer']);

  app.config([
    '$httpProvider', function($httpProvider) {
      $httpProvider.defaults.headers.common['Accept'] = 'application/json';
      return $httpProvider.interceptors.push([
        '$q', 'chainErrorSvc', '$log', function($q, chainErrorSvc, $log) {
          return {
            responseError: function(rejection) {
              var data;
              $log.log(rejection);
              data = rejection.data;
              if (data && data.errors && data.errors.length > 0) {
                chainErrorSvc.addErrors(data.errors);
              } else if (rejection.statusText) {
                chainErrorSvc.addErrors(["Unexpected server error: " + rejection.statusText]);
              } else {
                chainErrorSvc.addErrors(["Unexpected server error: " + data]);
              }
              return $q.reject(rejection);
            }
          };
        }
      ]);
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').factory('bulkSelectionSvc', [
    function() {
      var cache, getInnerCache, publicMethods;
      cache = {};
      getInnerCache = function(uid) {
        var innerCache;
        innerCache = cache[uid];
        if (!innerCache) {
          innerCache = {};
          cache[uid] = innerCache;
        }
        return innerCache;
      };
      publicMethods = {
        toggle: function(uid, obj) {
          var innerCache;
          innerCache = getInnerCache(uid);
          if (innerCache[obj.id]) {
            delete innerCache[obj.id];
          } else {
            innerCache[obj.id] = obj;
          }
        },
        isSelected: function(uid, obj) {
          if (getInnerCache(uid)[obj.id]) {
            return true;
          } else {
            return false;
          }
        },
        selected: function(uid) {
          var id, innerCache, obj, r;
          r = [];
          innerCache = getInnerCache(uid);
          for (id in innerCache) {
            obj = innerCache[id];
            r.push(obj);
          }
          return r;
        },
        selectedCount: function(uid) {
          return Object.keys(getInnerCache(uid)).length;
        },
        selectAll: function(uid, objects) {
          var i, innerCache, len, obj;
          innerCache = getInnerCache(uid);
          for (i = 0, len = objects.length; i < len; i++) {
            obj = objects[i];
            innerCache[obj.id] = obj;
          }
        },
        selectNone: function(uid) {
          cache[uid] = {};
        }
      };
      return publicMethods;
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainAddress', [
    function() {
      return {
        restrict: 'E',
        scope: {
          address: '@'
        },
        template: "<address> <span ng-repeat='ln in lines' ng-class='{\"chain-address-name\":$first}'> {{ln}}<br ng-if='!$last'/> </span> </address>",
        link: function(scope, el, attrs) {
          return scope.lines = scope.address.split("\n");
        }
      };
    }
  ]);

}).call(this);

(function() {
  var app;

  app = angular.module('ChainCommon');

  app.factory('chainApiSvc', [
    '$http', '$q', '$sce', '$location', '$rootScope', function($http, $q, $sce, $location, $rootScope) {
      var newAttachmentClient, newBulkExecuteClient, newCommentClient, newCoreModuleClient, newCountryClient, newFieldValidatorClient, newMessageClient, newSearchTableConfigClient, newSupportClient, newUserClient, newUserManualClient, publicMethods;
      publicMethods = {};
      newBulkExecuteClient = function() {
        var runningBulkCount;
        runningBulkCount = 0;
        return {
          execute: function(func, paramsArray) {
            var errorList, j, jobId, len, outerDeferred, p, pA, params, promisesRemainingCount, successList;
            jobId = func.toString() + Date.now();
            promisesRemainingCount = paramsArray.length;
            successList = [];
            errorList = [];
            outerDeferred = $q.defer();
            runningBulkCount = runningBulkCount + 1;
            for (j = 0, len = paramsArray.length; j < len; j++) {
              params = paramsArray[j];
              pA = Array.isArray(params) ? params : [params];
              p = func.apply(null, pA);
              p.then(function(r) {
                return successList.push(r);
              })["catch"](function(r) {
                return errorList.push(r);
              })["finally"](function(r) {
                promisesRemainingCount = promisesRemainingCount - 1;
                outerDeferred.notify({
                  total: paramsArray.length,
                  remaining: promisesRemainingCount,
                  jobId: jobId
                });
                if (promisesRemainingCount === 0) {
                  outerDeferred.resolve({
                    success: successList,
                    errors: errorList,
                    jobId: jobId
                  });
                  $rootScope.$broadcast('chain-bulk-execute-end', p, jobId);
                  return runningBulkCount = runningBulkCount - 1;
                }
              });
            }
            outerDeferred.notify({
              total: paramsArray.length,
              remaining: promisesRemainingCount,
              jobId: jobId
            });
            p = outerDeferred.promise;
            $rootScope.$broadcast('chain-bulk-execute-start', p, jobId);
            return p;
          },
          queueDepth: function() {
            return runningBulkCount;
          }
        };
      };
      publicMethods.Bulk = newBulkExecuteClient();
      newCoreModuleClient = function(moduleType, objectProperty, loadSuccessHandler) {
        var cache, handleServerResponse, prepSearchOpts, sanitizeSearchCriteria, sanitizeSortOpts, setCache;
        cache = {};
        handleServerResponse = function(resp) {
          var data;
          data = resp.data[objectProperty];
          if (loadSuccessHandler) {
            return loadSuccessHandler(data);
          } else {
            return data;
          }
        };
        setCache = function(obj) {
          cache[obj.id] = obj;
          return obj;
        };
        sanitizeSortOpts = function(opts) {
          var i, j, len, ref, s;
          if (opts.sorts) {
            ref = opts.sorts;
            for (i = j = 0, len = ref.length; j < len; i = ++j) {
              s = ref[i];
              opts['oid' + i] = s.field;
              if (s.order) {
                opts['oo' + i] = s.order;
              }
            }
            return delete opts.sorts;
          }
        };
        sanitizeSearchCriteria = function(opts) {
          var c, i, j, len, ref;
          if (opts.criteria) {
            ref = opts.criteria;
            for (i = j = 0, len = ref.length; j < len; i = ++j) {
              c = ref[i];
              opts['sid' + i] = c.field;
              opts['sop' + i] = c.operator;
              opts['sv' + i] = c.val;
            }
            return delete opts.criteria;
          }
        };
        prepSearchOpts = function(searchOpts) {
          var sOpts;
          sOpts = $.extend({}, searchOpts);
          sanitizeSortOpts(sOpts);
          sanitizeSearchCriteria(sOpts);
          return sOpts;
        };
        return {
          get: function(id, queryOpts) {
            var deferred;
            if (cache[id]) {
              deferred = $q.defer();
              deferred.resolve(cache[id]);
              return deferred.promise;
            } else {
              return this.load(id, queryOpts);
            }
          },
          load: function(id, queryOpts) {
            var config;
            config = {};
            if (queryOpts) {
              config.params = queryOpts;
            }
            return $http.get('/api/v1/' + moduleType + '/' + id + '.json', config).then(handleServerResponse).then(setCache);
          },
          save: function(obj, extraOpts) {
            var data, method, url;
            data = $.extend({}, extraOpts);
            data[objectProperty] = obj;
            method = 'post';
            url = '/api/v1/' + moduleType;
            if (obj.id && obj.id > 0) {
              method = 'put';
              url = url + "/" + obj.id;
            }
            return $http[method](url + '.json', data).then(handleServerResponse).then(setCache);
          },
          search: function(searchOpts) {
            var sOpts;
            sOpts = prepSearchOpts(searchOpts);
            return $http.get('/api/v1/' + moduleType + '.json', {
              params: sOpts
            }).then(function(resp) {
              var j, len, r, ref, v;
              r = [];
              ref = resp.data.results;
              for (j = 0, len = ref.length; j < len; j++) {
                v = ref[j];
                if (loadSuccessHandler) {
                  r.push(loadSuccessHandler(v));
                } else {
                  r.push(v);
                }
              }
              return r;
            });
          },
          count: function(searchOpts) {
            var sOpts;
            sOpts = prepSearchOpts(searchOpts);
            sOpts.count_only = 'true';
            return $http.get('/api/v1/' + moduleType + '.json', {
              params: sOpts
            }).then(function(resp) {
              return resp.data.record_count;
            });
          },
          csvUrl: function(searchOpts) {
            var queryString, sOpts;
            sOpts = prepSearchOpts(searchOpts);
            queryString = $.param(sOpts);
            return '/api/v1/' + moduleType + '.csv?' + queryString;
          },
          stateToggleButtons: function(obj) {
            return $http.get('/api/v1/' + moduleType + '/' + obj.id + '/state_toggle_buttons.json').then(function(resp) {
              return resp.data.state_toggle_buttons;
            });
          },
          toggleStateButton: function(obj, button) {
            return $http.post('/api/v1/' + moduleType + '/' + obj.id + '/toggle_state_button.json', {
              button_id: button.id
            }).then(function(resp) {
              return true;
            });
          }
        };
      };
      publicMethods.Address = newCoreModuleClient('addresses', 'address', function(a) {
        if (a.map_url) {
          a.map_url = $sce.trustAsResourceUrl(a.map_url);
        }
        return a;
      });
      publicMethods.Address["delete"] = function(obj) {
        var d;
        if (obj.id) {
          return $http["delete"]('/api/v1/addresses/' + obj.id + '.json').then(function(resp) {
            return true;
          });
        } else {
          d = $q.defer();
          d.resolve(false);
          return d.promise;
        }
      };
      newCountryClient = function() {
        var cache;
        cache = null;
        return {
          list: function() {
            var d;
            d = $q.defer();
            if (cache) {
              d.resolve(cache.slice(0));
            } else {
              $http.get('/api/v1/countries').then(function(resp) {
                cache = resp.data;
                return d.resolve(cache.slice(0));
              });
            }
            return d.promise;
          }
        };
      };
      publicMethods.Country = newCountryClient();
      publicMethods.TradeLane = newCoreModuleClient('trade_lanes', 'trade_lane');
      publicMethods.TradePreferenceProgram = newCoreModuleClient('trade_preference_programs', 'trade_preference_program');
      publicMethods.TppHtsOverride = newCoreModuleClient('tpp_hts_overrides', 'tpp_hts_override');
      publicMethods.Vendor = newCoreModuleClient('vendors', 'company');
      publicMethods.Product = newCoreModuleClient('products', 'product', function(product) {
        delete product.prod_ent_type_id;
        return product;
      });
      publicMethods.ProductVendorAssignment = newCoreModuleClient('product_vendor_assignments', 'product_vendor_assignment');
      publicMethods.Order = newCoreModuleClient('orders', 'order');
      publicMethods.Order.accept = function(order) {
        return $http.post('/api/v1/orders/' + order.id + '/accept.json', {
          id: order.id
        }).then(function(resp) {
          return publicMethods.Order.load(order.id);
        });
      };
      publicMethods.Order.unaccept = function(order) {
        return $http.post('/api/v1/orders/' + order.id + '/unaccept.json', {
          id: order.id
        }).then(function(resp) {
          return publicMethods.Order.load(order.id);
        });
      };
      newMessageClient = function() {
        var processMessageResponse;
        processMessageResponse = function(m) {
          if (m.body) {
            m.htmlSafeBody = $sce.trustAsHtml(m.body);
          }
          return m;
        };
        return {
          list: function(pageNumber) {
            var pn;
            pn = pageNumber ? pageNumber : 1;
            return $http.get('/api/v1/messages.json?page=' + pn).then(function(resp) {
              var j, len, m, msgs;
              msgs = resp.data.messages;
              for (j = 0, len = msgs.length; j < len; j++) {
                m = msgs[j];
                processMessageResponse(m);
              }
              return msgs;
            });
          },
          count: function(user) {
            return $http.get('/api/v1/messages/count/' + user.id + '.json').then(function(resp) {
              return resp.data.message_count;
            });
          },
          markAsRead: function(message) {
            return $http.post('/api/v1/messages/' + message.id + '/mark_as_read.json', {
              message: message
            }).then(function(resp) {
              return processMessageResponse(resp.data.message);
            });
          }
        };
      };
      publicMethods.Message = newMessageClient();
      newUserClient = function() {
        var cachedMe;
        cachedMe = null;
        return {
          changePassword: function(password, confirmation) {
            var d;
            d = $q.defer();
            if (password !== confirmation) {
              d.reject({
                errors: ["Password confirmation does not match. Please try again."]
              });
            } else {
              $http.post('/api/v1/users/change_my_password.json', {
                password: password
              }).then((function(resp) {
                return d.resolve(resp.data);
              }), (function(errResp) {
                return d.reject(errResp.data);
              }));
            }
            return d.promise;
          },
          loadMe: function() {
            return $http.get('/api/v1/users/me.json').then(function(resp) {
              return resp.data.user;
            });
          },
          me: function() {
            var d;
            if (cachedMe) {
              d = $q.defer();
              d.resolve(cachedMe);
              return d.promise;
            } else {
              return this.loadMe().then(function(u) {
                cachedMe = u;
                return cachedMe;
              });
            }
          },
          toggleEmailNewMessages: function() {
            return $http.post('/api/v1/users/me/toggle_email_new_messages.json', {}).then(function(resp) {
              cachedMe = resp.data.user;
              return cachedMe;
            });
          }
        };
      };
      publicMethods.User = newUserClient();
      newCommentClient = function() {
        return {
          "delete": function(comment) {
            return $http["delete"]('/api/v1/comments/' + comment.id + '.json');
          },
          forModule: function(moduleType, objectId) {
            return $http.get('/api/v1/comments/for_module/' + moduleType + '/' + objectId + '.json').then(function(resp) {
              return resp.data.comments;
            });
          },
          post: function(comment) {
            return $http.post('/api/v1/comments.json', {
              comment: comment
            }).then(function(resp) {
              return resp.data.comment;
            });
          }
        };
      };
      publicMethods.Comment = newCommentClient();
      newAttachmentClient = function() {
        return {
          forModule: function(moduleType, objectId) {
            return $http.get('/api/v1/' + moduleType + '/' + objectId + '/attachments.json').then(function(resp) {
              return resp.data.attachments;
            });
          }
        };
      };
      publicMethods.Attachment = newAttachmentClient();
      newSupportClient = function() {
        return {
          sendRequest: function(supportRequest) {
            return $http.post('/api/v1/support_requests', {
              support_request: supportRequest
            }).then(function(resp) {
              return resp.data.support_request_response;
            });
          }
        };
      };
      publicMethods.Support = newSupportClient();
      newUserManualClient = function() {
        return {
          list: function() {
            var url;
            url = $location.absUrl();
            return $http.get('/api/v1/user_manuals', {
              params: {
                source_page: url
              }
            }).then(function(resp) {
              return resp.data.user_manuals;
            });
          }
        };
      };
      publicMethods.UserManual = newUserManualClient();
      newFieldValidatorClient = function() {
        return {
          validateModel: function(field, model) {
            return this.validateValue(field, model[field.uid]);
          },
          validateValue: function(field, value) {
            return $http.get('/field_validator_rules/validate', {
              params: {
                mf_id: field.uid,
                value: value
              }
            }).then(function(resp) {
              return {
                errors: resp.data
              };
            });
          }
        };
      };
      publicMethods.FieldValidator = newFieldValidatorClient();
      newSearchTableConfigClient = function() {
        var resultCache;
        resultCache = {};
        return {
          forPage: function(page) {
            var cachedResult, d;
            d = $q.defer();
            cachedResult = resultCache[page];
            if (cachedResult && cachedResult.length > 0) {
              d.resolve(cachedResult);
            } else {
              $http.get('/api/v1/search_table_configs/for_page/' + encodeURIComponent(page) + '.json').then(function(resp) {
                var configs;
                configs = resp.data.search_table_configs;
                resultCache[page] = configs;
                return d.resolve(configs);
              });
            }
            return d.promise;
          }
        };
      };
      publicMethods.SearchTableConfig = newSearchTableConfigClient();
      return publicMethods;
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainAttachmentsPanel', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          parent: '=',
          moduleType: '@'
        },
        templateUrl: 'chain-attachments-panel.html',
        link: function(scope, el, attrs) {
          var load;
          load = function() {
            return chainApiSvc.Attachment.forModule(scope.moduleType, scope.parent.id).then(function(atts) {
              return scope.attachments = atts;
            });
          };
          return load();
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainBulkEdit', [
    'chainApiSvc', 'bulkSelectionSvc', '$compile', '$timeout', function(chainApiSvc, bulkSelectionSvc, $compile, $timeout) {
      return {
        restrict: 'E',
        scope: {
          apiObjectName: '@',
          pageUid: '@',
          buttonClasses: '@'
        },
        replace: true,
        template: '<button class="btn {{buttonClasses}}" ng-disabled="isDisabled()" title="Bulk Edit" ng-click="activateEdit()"><i class="fa fa-pencil-square-o"></i></button>',
        link: function(scope, el, attrs) {
          var myModal;
          myModal = null;
          scope.isDisabled = function() {
            return bulkSelectionSvc.selectedCount(scope.pageUid) === 0;
          };
          return scope.activateEdit = function() {
            if (!myModal) {
              myModal = $compile('<chain-bulk-edit-modal api-object-name="' + scope.apiObjectName + '" page-uid="' + scope.pageUid + '"></chain-bulk-edit-modal>')(scope);
              $('body').append(myModal);
            }
            $timeout(function() {
              return myModal.find('.modal').modal('show');
            });
            return null;
          };
        }
      };
    }
  ]);

}).call(this);

(function() {
  var hasProp = {}.hasOwnProperty;

  angular.module('ChainCommon').directive('chainBulkEditModal', [
    'chainApiSvc', 'bulkSelectionSvc', 'chainDomainerSvc', '$compile', '$timeout', function(chainApiSvc, bulkSelectionSvc, chainDomainerSvc, $compile, $timeout) {
      return {
        restrict: 'E',
        scope: {
          apiObjectName: '@',
          pageUid: '@'
        },
        templateUrl: 'chain-bulk-edit-modal.html',
        link: function(scope, el, attrs) {
          var init;
          init = function() {
            scope.loading = 'loading';
            scope.bulkEditObj = {};
            return chainDomainerSvc.withDictionary().then(function(d) {
              scope.editFields = $.grep(d.fieldsByRecordType(d.recordTypes[scope.apiObjectName]), function(field) {
                return field.can_edit === true;
              }).sort(function(a, b) {
                if (a.label && b.label) {
                  return a.label.localeCompare(b.label);
                } else {
                  return a.uid.localeCompare(b.uid);
                }
              });
              return delete scope.loading;
            });
          };
          scope.save = function() {
            var cbe, doSave, i, len, needsTimeout, o, prop, ref, selected, updateOb, updateObjs, val;
            el.find('.modal').modal('hide');
            updateObjs = [];
            doSave = false;
            selected = bulkSelectionSvc.selected(scope.pageUid);
            for (i = 0, len = selected.length; i < len; i++) {
              o = selected[i];
              updateOb = {
                id: o.id
              };
              ref = scope.bulkEditObj;
              for (prop in ref) {
                if (!hasProp.call(ref, prop)) continue;
                val = ref[prop];
                if (val && val.length > 0) {
                  updateOb[prop] = val;
                  doSave = true;
                }
              }
              updateObjs.push(updateOb);
            }
            if (doSave) {
              needsTimeout = false;
              cbe = $('chain-bulk-execute');
              if (cbe.length === 0) {
                $('body').append($compile('<chain-bulk-execute></chain-bulk-execute>')(scope.$root));
                needsTimeout = true;
              }
              if (needsTimeout) {
                return $timeout(function() {
                  return chainApiSvc.Bulk.execute(chainApiSvc[scope.apiObjectName].save, updateObjs).then(function() {
                    return scope.bulkEditObj = {};
                  });
                });
              } else {
                return chainApiSvc.Bulk.execute(chainApiSvc[scope.apiObjectName].save, updateObjs).then(function() {
                  return scope.bulkEditObj = {};
                });
              }
            }
          };
          scope.cancel = function() {
            scope.bulkEditObj = {};
            el.find('.modal').modal('hide');
            return null;
          };
          if (!scope.$root.isTest) {
            return init();
          }
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainBulkExecute', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-bulk-execute-modal.html',
        link: function(scope, el, attrs) {
          var calcTaskList, hideModalIfNeeded, showModalIfNeeded;
          showModalIfNeeded = function() {
            if (scope.isVisible) {
              return;
            }
            el.find('.modal').modal('show');
            return scope.isVisible = true;
          };
          hideModalIfNeeded = function() {
            if (!scope.isVisible) {
              return;
            }
            el.find('.modal').modal('hide');
            return scope.isVisible = false;
          };
          calcTaskList = function() {
            var cnt, key, ref;
            scope.tasks = {
              total: 0,
              remaining: 0,
              complete: 0
            };
            ref = scope.bulkQ;
            for (key in ref) {
              cnt = ref[key];
              scope.tasks.total = scope.tasks.total + cnt.total;
              scope.tasks.remaining = scope.tasks.remaining + cnt.remaining;
              scope.tasks.complete = scope.tasks.complete + cnt.complete;
            }
            return scope.tasks.percentComplete = Math.round(scope.tasks.complete / scope.tasks.total * 100);
          };
          scope.bulkQ = {};
          scope.isVisible = false;
          scope.tasks = {
            total: 0,
            remaining: 0,
            complete: 0
          };
          scope.queueDepth = function() {
            return Object.keys(scope.bulkQ).length;
          };
          scope.addPromise = function(jobId, p) {
            scope.bulkQ[jobId] = {
              total: 0,
              remaining: 0,
              complete: 0
            };
            return p.then(null, null, function(msg) {
              var counts;
              counts = scope.bulkQ[msg.jobId];
              if (counts) {
                counts.total = msg.total;
                counts.remaining = msg.remaining;
                counts.complete = msg.total - msg.remaining;
              }
              return calcTaskList();
            });
          };
          scope.removePromise = function(jobId, p) {
            delete scope.bulkQ[jobId];
            return calcTaskList();
          };
          scope.$on('chain-bulk-execute-start', function(evt, p, jobId) {
            return scope.addPromise(jobId, p);
          });
          scope.$on('chain-bulk-execute-end', function(evt, p, jobId) {
            return scope.removePromise(jobId, p);
          });
          return scope.$watch('queueDepth()', function(nv, ov) {
            if (nv > 0) {
              showModalIfNeeded();
            }
            if (nv === 0) {
              return hideModalIfNeeded();
            }
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainChangePasswordModal', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-change-password-modal.html',
        link: function(scope, el, attrs) {
          scope.changePassword = function() {
            var conf, pwd;
            scope.loading = 'loading';
            scope.errors = [];
            delete scope.success;
            pwd = scope.password;
            conf = scope.confirmation;
            return chainApiSvc.User.changePassword(pwd, conf).then((function(resp) {
              delete scope.loading;
              return scope.success = "Password successfully changed.";
            }), (function(err) {
              var i, len, m, ref, results;
              delete scope.loading;
              ref = err.errors;
              results = [];
              for (i = 0, len = ref.length; i < len; i++) {
                m = ref[i];
                results.push(scope.errors.push(m));
              }
              return results;
            }));
          };
          $(el).on('show.bs.modal', function() {
            return scope.$apply(function() {
              delete scope.loading;
              scope.errors = [];
              scope.password = '';
              scope.confirmation = '';
              return delete scope.success;
            });
          });
          return $(el).on('shown.bs.modal', function() {
            return $(document).find('input[type="password"]:first').focus();
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainCommentsPanel', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          parent: '=',
          moduleType: '@'
        },
        templateUrl: 'chain-comments-panel.html',
        link: function(scope, el, attrs) {
          var loadComments, setCommentToAdd;
          loadComments = function() {
            return chainApiSvc.Comment.forModule(scope.moduleType, scope.parent.id).then(function(comments) {
              return scope.comments = comments;
            });
          };
          setCommentToAdd = function() {
            return scope.commentToAdd = {
              commentable_id: scope.parent.id,
              commentable_type: scope.moduleType
            };
          };
          scope["delete"] = function(comment) {
            return chainApiSvc.Comment["delete"](comment).then(function() {
              return loadComments();
            });
          };
          scope.add = function(comment) {
            return chainApiSvc.Comment.post(comment).then(function(c) {
              if (!scope.comments) {
                scope.comments = [];
              }
              scope.comments.push(c);
              return setCommentToAdd();
            });
          };
          loadComments();
          return setCommentToAdd();
        }
      };
    }
  ]);

}).call(this);

(function() {
  var cDom;

  cDom = angular.module('ChainDomainer', ['Domainer']);

  cDom.factory('chainDomainerSvc', [
    '$http', 'domainerSvc', function($http, domainerSvc) {
      var domainDAOChain, setupDone;
      domainDAOChain = {
        makeDictionary: function(worker) {
          return $http.get('/api/v1/model_fields').then(function(resp) {
            var data, dict, fld, i, j, len, len1, recordTypes, ref, ref1, rt;
            data = resp.data;
            dict = new DomainDictionary();
            recordTypes = {};
            ref = data.recordTypes;
            for (i = 0, len = ref.length; i < len; i++) {
              rt = ref[i];
              dict.registerRecordType(rt);
              recordTypes[rt.uid] = rt;
            }
            ref1 = data.fields;
            for (j = 0, len1 = ref1.length; j < len1; j++) {
              fld = ref1[j];
              fld.recordType = recordTypes[fld.record_type_uid];
              dict.registerField(fld);
            }
            return worker(dict);
          });
        }
      };
      setupDone = false;
      return {
        withDictionary: function() {
          if (!setupDone) {
            domainerSvc.setLocalDAO(domainDAOChain);
            domainerSvc.setRemoteDAO(domainDAOChain);
            domainerSvc.setExpirationChecker(new DomainExpirationCheckerLocal());
            setupDone = true;
          }
          return domainerSvc.withDictionary();
        }
      };
    }
  ]);

}).call(this);

(function() {
  var mod;

  mod = angular.module('ChainCommon');

  mod.factory('chainErrorSvc', [
    '$rootScope', function($rootScope) {
      var buildErrorCache, errorCache, errors;
      errors = {};
      errorCache = [];
      buildErrorCache = function() {
        var m, results;
        errorCache.length = 0;
        results = [];
        for (m in errors) {
          results.push(errorCache.push({
            message: m,
            count: errors[m]
          }));
        }
        return results;
      };
      return {
        addErrors: function(errorMessages) {
          var i, len, m;
          for (i = 0, len = errorMessages.length; i < len; i++) {
            m = errorMessages[i];
            if (errors[m]) {
              errors[m] = errors[m] + 1;
            } else {
              errors[m] = 1;
            }
          }
          buildErrorCache();
          return $rootScope.$broadcast('chain-errors-added');
        },
        clearErrors: function() {
          var m;
          for (m in errors) {
            delete errors[m];
          }
          buildErrorCache();
          return $rootScope.$broadcast('chain-errors-cleared');
        },
        errors: function() {
          return errorCache;
        },
        errorCount: function() {
          return errorCache.length;
        }
      };
    }
  ]);

  mod.directive('chainErrors', [
    'chainErrorSvc', '$http', function(chainErrorSvc, $http) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-errors.html',
        link: function(scope, el, attrs) {
          var httpWatchCheck, showErrors;
          scope.httpBackend = $http;
          showErrors = function() {
            if (chainErrorSvc.errorCount() === 0 || chainErrorSvc.silenceErrors || $http.pendingRequests.length > 0) {
              return;
            }
            scope.isVisible = true;
            return $('.chain-errors-modal:first').modal('show');
          };
          scope.errorSvc = chainErrorSvc;
          scope.silence = function() {
            return chainErrorSvc.silenceErrors = true;
          };
          scope.isVisible = false;
          scope.$root.$on('chain-errors-added', function() {
            return showErrors();
          });
          $(el).on('hide.bs.modal', function() {
            return scope.$apply(function() {
              scope.isVisible = false;
              return chainErrorSvc.clearErrors();
            });
          });
          httpWatchCheck = function() {
            return $http.pendingRequests.length;
          };
          scope.$watch(httpWatchCheck, function(nv) {
            if (nv === 0) {
              return showErrors();
            }
          });
          return null;
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainFieldInput', [
    '$compile', 'chainApiSvc', function($compile, chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          model: '=',
          field: '=',
          inputClass: '@'
        },
        template: "<input type='text' ng-model='model[field.uid]' class='{{inputClass}}' />",
        link: function(scope, el, attrs) {
          var i, inp, inputTypes, jqEl, len, opt, realInput, ref, sel, updatedInputType;
          jqEl = $(el);
          inp = jqEl.find('input');
          realInput = inp;
          if (scope.field.select_options) {
            inp.remove();
            sel = $compile(angular.element('<select ng-model="model[field.uid]" class="{{inputClass}}"></select>'))(scope);
            jqEl.append(sel);
            realInput = sel;
            sel.append("<option value=''></option>");
            ref = scope.field.select_options;
            for (i = 0, len = ref.length; i < len; i++) {
              opt = ref[i];
              sel.append("<option value='" + opt[0] + "'>" + opt[1] + "</option>");
            }
          } else if (scope.field.data_type === 'text') {
            inp.remove();
            realInput = $compile(angular.element('<textarea ng-model="model[field.uid]" class="{{inputClass}}"></textarea>'))(scope);
            jqEl.append(realInput);
          } else if (scope.field.data_type === 'boolean') {
            inp.remove();
            realInput = $compile(angular.element('<div><input type="checkbox" ng-model="model[field.uid]"></div>'))(scope);
            jqEl.append(realInput);
          } else {
            inputTypes = {
              number: 'number',
              integer: 'number',
              decimal: 'number',
              date: 'date',
              datetime: 'datetime-local'
            };
            updatedInputType = inputTypes[scope.field.data_type];
            if (updatedInputType) {
              inp.attr('type', updatedInputType);
            }
          }
          if (!scope.field.can_edit) {
            realInput.prop('disabled', 'disabled');
          }
          if (scope.field.remote_validate) {
            return realInput.on('blur', function() {
              return scope.$apply(function() {
                var errorBlock, parent;
                parent = realInput.parent();
                errorBlock = parent.find('.chain-field-input-errmsgs')[0];
                return chainApiSvc.FieldValidator.validateModel(scope.field, scope.model).then(function(resp) {
                  if (resp.errors.length > 0) {
                    parent.addClass('has-error');
                    if (!errorBlock) {
                      errorBlock = $compile(angular.element('<div class="text-danger text-right chain-field-input-errmsgs"></div>'))(scope);
                      realInput.after(errorBlock);
                    }
                    return $(errorBlock).html(resp.errors.join(' '));
                  } else {
                    parent.removeClass('has-error');
                    if (errorBlock) {
                      return $(errorBlock).html('');
                    }
                  }
                });
              });
            });
          }
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainFieldLabel', [
    function() {
      return {
        restrice: 'E',
        scope: {
          field: '='
        },
        replace: true,
        template: '<label class="control-label">{{field.label}}<i ng-if="field.required" class="fa fa-asterisk required-icon"></i></label>'
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainFieldValue', [
    '$compile', function($compile) {
      return {
        restrict: 'E',
        scope: {
          model: '=',
          field: '='
        },
        template: "",
        link: function(scope, el, attrs) {
          var getHtml, html;
          getHtml = function(scope) {
            var checkedClass, m, val, withMs;
            if (!scope.field || !scope.model) {
              return '';
            }
            val = scope.model[scope.field.uid];
            if ((typeof val !== 'boolean') && (!val || val.length === 0)) {
              return '';
            }
            if (scope.field.data_type === 'date') {
              m = null;
              if (val.length === 10) {
                m = moment(val, 'YYYY-MM-DD');
              } else if (val.length === 25) {
                withMs = (val.length === 25 ? val.slice(0, 19) + '.000' + val.slice(19) : val);
                m = moment(withMs);
              } else {
                m = moment(val);
              }
              return m.format('YYYY-MM-DD');
            }
            if (scope.field.data_type === 'datetime') {
              withMs = (val.length === 25 ? val.slice(0, 19) + '.000' + val.slice(19) : val);
              return moment(withMs).format('YYYY-MM-DD HH:mm ZZ');
            }
            if (scope.field.data_type === 'text') {
              return $compile(angular.element('<pre>' + val + '</pre>'))(scope);
            }
            if (scope.field.data_type === 'boolean') {
              checkedClass = val ? 'fa-check-square-o' : 'fa-times';
              return $compile(angular.element('<i class="fa ' + checkedClass + '" model-field-uid="' + scope.field.uid + '"></i>'))(scope);
            }
            return val;
          };
          html = getHtml(scope);
          return $(el).html(html);
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').filter('chainFieldsWithValues', function() {
    return function(fields, model) {
      if (!fields || fields.length === 0) {
        return [];
      }
      return $.grep(fields, function(fld) {
        var val;
        val = model[fld.uid];
        if (!val || val.trim().length === 0) {
          return null;
        }
        return fld;
      });
    };
  });

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainFlagIcon', [
    function() {
      return {
        restrict: 'E',
        scope: {
          isoCode: "@",
          imgClass: "@"
        },
        template: '<img ng-show="isoCode && isoCode.length == 2" class="{{imgClass}}" ng-src="{{srcPath}}" title="Flag of {{isoCode}}" />',
        link: function(scope, el, attrs) {
          return scope.$watch('isoCode', function(nv, ov) {
            if (nv && nv.length === 2) {
              return scope.srcPath = "/images/flags/" + nv.toLowerCase() + ".png";
            } else {
              return scope.srcPath = null;
            }
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainLoader', function() {
    return {
      restrict: 'E',
      replace: true,
      template: '<div class="chain-loader"></div>'
    };
  });

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainLoadingWrapper', function() {
    return {
      restrict: 'E',
      scope: {
        loadingFlag: '@'
      },
      transclude: true,
      template: "<div class='container-fluid' ng-if='isLoading()'> <div class='row'> <div class='col-md-12'> <chain-loader></chain-loader> </div> </div> </div> <div ng-transclude ng-if='!isLoading()'></div>",
      link: function(scope, el, attrs) {
        return scope.isLoading = function() {
          return scope.loadingFlag === 'loading';
        };
      }
    };
  });

}).call(this);

(function() {
  var app;

  app = angular.module('ChainCommon');

  app.directive('chainMessagesLink', [
    'chainApiSvc', '$interval', '$timeout', '$compile', function(chainApiSvc, $interval, $timeout, $compile) {
      return {
        restrict: 'E',
        scope: {},
        replace: true,
        template: "<a ng-click='showModal()'>Messages</a>",
        link: function(scope, el, attrs) {
          var actuallyShowModal, updateMessageCount;
          updateMessageCount = function() {
            return chainApiSvc.User.me().then(function(me) {
              return chainApiSvc.Message.count(me).then(function(c) {
                if (c > 0) {
                  return el.html('Messages (' + c + ')');
                } else {
                  return el.html('Messages');
                }
              });
            });
          };
          updateMessageCount();
          $interval(updateMessageCount, 30000);
          actuallyShowModal = function() {
            return $('#chain-messages-modal').modal('show');
          };
          return scope.showModal = function() {
            var compiledEl, mod;
            mod = $('#chain-messages-modal');
            if (mod.length === 0) {
              compiledEl = angular.element('<chain-messages-modal></chain-messages-modal>');
              $compile(compiledEl)(scope.$root.$new());
              $('body').append(compiledEl);
              $timeout(actuallyShowModal, 0);
            } else {
              actuallyShowModal();
            }
            return null;
          };
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainMessagesModal', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-messages-modal.html',
        link: function(scope, el, atrs) {
          scope.loadMessages = function(pageNum) {
            scope.nextPage = pageNum + 1;
            if (pageNum === 1) {
              delete scope.messages;
            }
            return chainApiSvc.Message.list(pageNum).then(function(msgs) {
              var i, len, m;
              if (!scope.messages) {
                scope.messages = [];
              }
              for (i = 0, len = msgs.length; i < len; i++) {
                m = msgs[i];
                scope.messages.push(m);
              }
              scope.hasMore = msgs.length === 10;
              return scope.messages;
            });
          };
          scope.loadUser = function() {
            delete scope.user;
            return chainApiSvc.User.me().then(function(u) {
              scope.user = u;
              return scope.user;
            });
          };
          scope.readMessage = function(message) {
            if (!message.viewed) {
              chainApiSvc.Message.markAsRead(message);
            }
            message.shown = true;
            return message.viewed = true;
          };
          scope.toggleEmailNewMessages = function() {
            scope.loading = 'loading';
            return chainApiSvc.User.toggleEmailNewMessages().then(function(u) {
              scope.user = u;
              return delete scope.loading;
            });
          };
          return $(el).on('show.bs.modal', function() {
            scope.loading = 'loading';
            return scope.loadUser().then(function() {
              return scope.loadMessages(1).then(function() {
                return delete scope.loading;
              });
            });
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainSearchPanel', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {
          name: '@',
          apiObjectName: '@',
          pageUid: '@',
          baseSearchSetupFunction: '=',
          bulkEdit: '='
        },
        templateUrl: 'chain-search-panel.html',
        link: function(scope, el, attrs) {
          scope.coreSearch = {};
          scope.activateSearch = function(stc) {
            var c, i, j, k, l, len, len1, len2, len3, len4, m, ref, ref1, ref2, ref3, ref4, search, ss;
            scope.searchTableConfig = stc;
            search = stc.config;
            if (!search) {
              search = {};
            }
            ss = {};
            if (scope.baseSearchSetupFunction) {
              ss = scope.baseSearchSetupFunction();
            }
            if (!ss.columns && search.columns) {
              ss.columns = [];
            }
            if (search.columns) {
              ref = search.columns;
              for (i = 0, len = ref.length; i < len; i++) {
                c = ref[i];
                ss.columns.push(c);
              }
            }
            if (!ss.sorts && search.sorts) {
              ss.sorts = [];
            }
            if (search.sorts) {
              ref1 = search.sorts;
              for (j = 0, len1 = ref1.length; j < len1; j++) {
                c = ref1[j];
                ss.sorts.push(c);
              }
            }
            if (!ss.criteria && search.criteria) {
              ss.criteria = [];
            }
            if (search.criteria) {
              ref2 = search.criteria;
              for (k = 0, len2 = ref2.length; k < len2; k++) {
                c = ref2[k];
                ss.criteria.push(c);
              }
            }
            if (!ss.hiddenCriteria && search.hiddenCriteria) {
              ss.hiddenCriteria = [];
            }
            if (search.hiddenCriteria) {
              ref3 = search.hiddenCriteria;
              for (l = 0, len3 = ref3.length; l < len3; l++) {
                c = ref3[l];
                ss.hiddenCriteria.push(c);
              }
            }
            if (!ss.buttons && search.buttons) {
              ss.buttons = [];
            }
            if (search.buttons) {
              ref4 = search.buttons;
              for (m = 0, len4 = ref4.length; m < len4; m++) {
                c = ref4[m];
                ss.buttons.push(c);
              }
            }
            ss.reload = new Date().getTime();
            return scope.coreSearch.searchSetup = ss;
          };
          scope.init = function() {
            return chainApiSvc.SearchTableConfig.forPage(scope.pageUid).then(function(stcs) {
              scope.searchTableConfigs = stcs;
              if (scope.searchTableConfigs.length > 0) {
                return scope.activateSearch(scope.searchTableConfigs[0]);
              }
            });
          };
          return scope.init();
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainSearchTable', [
    'chainApiSvc', 'chainDomainerSvc', 'bulkSelectionSvc', '$window', function(chainApiSvc, chainDomainerSvc, bulkSelectionSvc, $window) {
      return {
        restrict: 'E',
        scope: {
          apiObjectName: '@',
          loadTrigger: '=?',
          searchSetup: '=?',
          pageUid: '@'
        },
        templateUrl: 'chain-search-table.html',
        replace: true,
        link: function(scope, el, attrs) {
          var buildSearchParams, calcPages, doLoad, findCriterionByUid;
          scope.neverLoaded = true;
          scope.hasBeenLoaded = false;
          if (!scope.searchSetup) {
            scope.searchSetup = {};
          }
          if (!scope.searchSetup.columns) {
            scope.searchSetup.columns = ['id'];
          }
          scope.columnFields = {};
          calcPages = function(recordCount, perPage) {
            var i, num, pages, ref, results;
            if (recordCount === 0) {
              return [];
            }
            pages = Math.ceil(recordCount / perPage);
            scope.pages = [];
            results = [];
            for (num = i = 1, ref = pages; 1 <= ref ? i <= ref : i >= ref; num = 1 <= ref ? ++i : --i) {
              results.push(scope.pages.push(num.toString()));
            }
            return results;
          };
          doLoad = function(dict) {
            var apiObj, c, i, len, ref, searchParams, ss;
            if (!scope.searchSetup.page) {
              scope.searchSetup.page = '1';
              scope.pageVal = '1';
            }
            if (!scope.searchSetup.per_page) {
              scope.searchSetup.per_page = 50;
            }
            scope.neverLoaded = false;
            apiObj = chainApiSvc[scope.apiObjectName];
            delete scope.recordCount;
            ss = scope.searchSetup;
            ref = ss.columns;
            for (i = 0, len = ref.length; i < len; i++) {
              c = ref[i];
              scope.columnFields[c] = dict.field(c);
            }
            searchParams = buildSearchParams(ss);
            return apiObj.search(searchParams).then(function(resp) {
              scope.content = resp;
              scope.hasBeenLoaded = true;
              delete scope.loading;
              if (scope.content.length < ss.per_page) {
                scope.recordCount = ((ss.page - 1) * ss.per_page) + scope.content.length;
                return calcPages(scope.recordCount, ss.per_page);
              } else {
                return apiObj.count(searchParams).then(function(count) {
                  scope.recordCount = count;
                  return calcPages(scope.recordCount, scope.searchSetup.per_page);
                });
              }
            });
          };
          buildSearchParams = function(setup) {
            var r;
            r = {
              criteria: []
            };
            if (setup.hiddenCriteria) {
              r.criteria = r.criteria.concat(setup.hiddenCriteria);
            }
            if (setup.criteria) {
              r.criteria = r.criteria.concat(setup.criteria);
            }
            if (setup.columns && setup.columns.length > 0) {
              if (!(setup.columns.length === 1 && setup.columns[0] === 'id')) {
                r.fields = setup.columns.join(',');
              }
            }
            if (setup.sorts) {
              r.sorts = setup.sorts;
            }
            if (setup.per_page) {
              r.per_page = setup.per_page;
            }
            if (setup.page) {
              r.page = setup.page;
            }
            return r;
          };
          scope.toggleBulkSelect = function(obj) {
            return bulkSelectionSvc.toggle(scope.pageUid, obj);
          };
          scope.selectAll = function() {
            if (scope.content.length === bulkSelectionSvc.selectedCount(scope.pageUid)) {
              return bulkSelectionSvc.selectNone(scope.pageUid);
            } else {
              return bulkSelectionSvc.selectAll(scope.pageUid, scope.content);
            }
          };
          scope.isSelected = function(obj) {
            return bulkSelectionSvc.isSelected(scope.pageUid, obj);
          };
          findCriterionByUid = function(uid) {
            var allCriteria, c, i, len;
            allCriteria = scope.searchSetup.criteria;
            if (!allCriteria) {
              return false;
            }
            for (i = 0, len = allCriteria.length; i < len; i++) {
              c = allCriteria[i];
              if (c.field === uid) {
                return c;
              }
            }
            return false;
          };
          scope.isFilteredColumn = function(uid) {
            if (findCriterionByUid(uid)) {
              return true;
            }
            return false;
          };
          scope.filterColumn = function(uid) {
            var c;
            c = findCriterionByUid(uid);
            if (!c) {
              c = {
                field: uid,
                operator: 'co',
                val: ''
              };
            }
            scope.filterCriterion = c;
            el.find('.modal').modal('show').on('shown.bs.modal', function() {
              return el.find('.modal input:first').focus();
            });
            return null;
          };
          scope.addFilter = function(f) {
            var found;
            found = findCriterionByUid(f.field);
            if (found) {
              found.val = f.val;
              found.operator = 'co';
            } else {
              if (!scope.searchSetup.criteria) {
                scope.searchSetup.criteria = [];
              }
              scope.searchSetup.criteria.push(f);
            }
            scope.searchSetup.reload = new Date().getTime();
            el.find('.modal').modal('hide');
            return null;
          };
          scope.removeFilter = function(f) {
            var allCriteria, c, i, idx, len;
            allCriteria = scope.searchSetup.criteria;
            for (idx = i = 0, len = allCriteria.length; i < len; idx = ++i) {
              c = allCriteria[idx];
              if (c.field === f.field) {
                allCriteria.splice(idx, 1);
              }
            }
            scope.searchSetup.reload = new Date().getTime();
            el.find('.modal').modal('hide');
            return null;
          };
          scope.downloadCsv = function() {
            var apiObj, ss, url;
            ss = $.extend({}, scope.searchSetup);
            delete ss.page;
            delete ss.per_page;
            apiObj = chainApiSvc[scope.apiObjectName];
            url = apiObj.csvUrl(buildSearchParams(ss));
            return $window.location = url;
          };
          scope.load = function() {
            scope.loading = 'loading';
            scope.reloadVal = scope.searchSetup.reload;
            scope.pageVal = scope.searchSetup.page;
            if (scope.dict) {
              return doLoad(scope.dict);
            } else {
              return chainDomainerSvc.withDictionary().then(function(dict) {
                scope.dict = dict;
                return doLoad(scope.dict);
              });
            }
          };
          scope.columnCount = function() {
            return el.find('thead th').length;
          };
          scope.totalPages = function() {
            if (!scope.pages) {
              return 0;
            }
            return scope.pages.length;
          };
          scope.$watch('loadTrigger', function(nv, ov) {
            if (scope.neverLoaded && nv) {
              return scope.load();
            }
          });
          scope.$watch('searchSetup.page', function(nv, ov) {
            if (nv === scope.pageVal) {
              return;
            }
            if (!scope.neverLoaded) {
              return scope.load();
            }
          });
          scope.$watch('searchSetup.reload', function(nv, ov) {
            if (nv === scope.reloadVal) {
              return;
            }
            if (nv && nv !== ov) {
              return scope.load();
            }
          });
          scope.$on('chain-bulk-execute-end', function() {
            if (!scope.neverLoaded) {
              return scope.load();
            }
          });
          if (typeof scope.loadTrigger === 'undefined' && !scope.$root.isTest) {
            return scope.load();
          }
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').filter('chainSkipReadOnly', function() {
    return function(fields) {
      if (!(fields && fields.length > 0)) {
        return [];
      }
      return $.grep(fields, function(fld) {
        if (fld.read_only) {
          return null;
        } else {
          return fld;
        }
      });
    };
  });

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainStateToggleButtons', [
    'chainApiSvc', '$window', function(chainApiSvc, $window) {
      return {
        restrict: 'E',
        scope: {
          apiObjectName: '@',
          buttonClasses: '@',
          object: '=',
          toggleCallback: '='
        },
        replace: true,
        templateUrl: 'chain-state-toggle-buttons.html',
        link: function(scope, el, attrs) {
          var loadButtons;
          loadButtons = function(object) {
            delete scope.stButtons;
            return chainApiSvc[scope.apiObjectName].stateToggleButtons(object).then(function(buttons) {
              scope.stButtons = buttons;
              return object._chainStateToggleButtonLoaded = true;
            });
          };
          scope.toggle = function(button) {
            if (!button.button_confirmation || button.button_confirmation.length === 0 || $window.confirm(button.button_confirmation)) {
              return chainApiSvc[scope.apiObjectName].toggleStateButton(scope.object, button).then(function(resp) {
                if (scope.toggleCallback) {
                  return scope.toggleCallback();
                }
              });
            }
          };
          return scope.$watch('object._chainStateToggleButtonLoaded', function(nv, ov) {
            if (!nv) {
              return loadButtons(scope.object);
            }
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').directive('chainSupportModal', [
    'chainApiSvc', function(chainApiSvc) {
      return {
        restrict: 'E',
        scope: {},
        templateUrl: 'chain-support-modal.html',
        link: function(scope, el, attrs) {
          var clearMessageInfo, loadUserManuals;
          scope.submit = function() {
            scope.loading = 'loading';
            scope.errors = [];
            return chainApiSvc.Support.sendRequest({
              body: scope.messageBody
            }).then((function(r) {
              scope.messageBody = '';
              scope.ticketNumber = r.ticket_number;
              scope.moreHelpMessage = r.more_help_message;
              return delete scope.loading;
            }), (function(err) {
              var i, len, m, ref, results;
              delete scope.loading;
              ref = err.errors;
              results = [];
              for (i = 0, len = ref.length; i < len; i++) {
                m = ref[i];
                results.push(scope.errors.push(m));
              }
              return results;
            }));
          };
          clearMessageInfo = function() {
            delete scope.ticketNumber;
            return scope.messageBody = '';
          };
          loadUserManuals = function() {
            scope.umLoading = "loading";
            return chainApiSvc.UserManual.list().then(function(r) {
              scope.userManuals = r;
              return delete scope.umLoading;
            });
          };
          $(el).on('show.bs.modal', function() {
            return scope.$apply(function() {
              clearMessageInfo();
              if (!scope.userManuals) {
                return loadUserManuals();
              }
            });
          });
          return $(el).on('shown.bs.modal', function() {
            return $(el).find('textarea').focus();
          });
        }
      };
    }
  ]);

}).call(this);

(function() {
  angular.module('ChainCommon').filter('chainViewFields', function() {
    return function(fields, fieldList, isBlacklist) {
      var blacklist, whitelist;
      if (!(fields && fields.length > 0)) {
        return [];
      }
      whitelist = null;
      blacklist = null;
      if (isBlacklist) {
        blacklist = fieldList;
      } else {
        whitelist = fieldList;
      }
      return $.grep(fields, function(fld) {
        if (whitelist && whitelist.length > 0) {
          if (whitelist.indexOf(fld.uid) < 0) {
            return null;
          }
        }
        if (blacklist && blacklist.length > 0) {
          if (blacklist.indexOf(fld.uid) >= 0) {
            return null;
          }
        }
        if (fld.user_id_field) {
          return null;
        }
        if (fld.user_field && !fld.user_full_name_field) {
          return null;
        }
        return fld;
      });
    };
  });

}).call(this);

(function() {
  var dMod;

  dMod = angular.module('Domainer', []);

  dMod.factory('domainerSvc', [
    '$q', function($q) {
      var domainer, expChecker, localDAO, remoteDAO;
      localDAO = null;
      remoteDAO = null;
      expChecker = null;
      domainer = null;
      return {
        setLocalDAO: function(d) {
          localDAO = d;
          return domainer = null;
        },
        setRemoteDAO: function(d) {
          remoteDAO = d;
          return domainer = null;
        },
        setExpirationChecker: function(d) {
          expChecker = d;
          return domainer = null;
        },
        withDictionary: function() {
          var deferred;
          if (!domainer) {
            domainer = new Domainer(new DomainDataAccessSetup(localDAO, remoteDAO, expChecker));
          }
          deferred = $q.defer();
          domainer.withDictionary(function(dict) {
            return deferred.resolve(dict);
          });
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

angular.module('ChainCommon-Templates', ['chain-attachments-panel.html', 'chain-bulk-edit-modal.html', 'chain-bulk-execute-modal.html', 'chain-change-password-modal.html', 'chain-comments-panel.html', 'chain-errors.html', 'chain-messages-modal.html', 'chain-search-panel.html', 'chain-search-table.html', 'chain-state-toggle-buttons.html', 'chain-support-modal.html']);

angular.module("chain-attachments-panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-attachments-panel.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Attachments</h3></div><ul class=\"list-group\"><li ng-repeat=\"att in attachments track by att.id\" class=\"list-group-item\"><button class=\"btn btn-xs btn-danger pull-right\" ng-click=\"deleteAttachment(att.id)\" href=\"javascript:;\" ng-if=\"canAttach\"><i class=\"fa fa-trash\"></i></button> <a href=\"/attachments/{{att.id}}/download\" target=\"_blank\">{{att.att_file_name}} <span class=\"badge\">{{att.friendly_size}}</span></a></li></ul></div>");
}]);

angular.module("chain-bulk-edit-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-bulk-edit-modal.html",
    "<div class=\"modal fade\" data-keyboard=\"false\" data-backdrop=\"static\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Bulk Edit</h4></div><div class=\"modal-body\"><div ng-repeat=\"f in editFields track by f.uid\"><chain-field-label field=\"f\"></chain-field-label><chain-field-input model=\"bulkEditObj\" field=\"f\" input-class=\"form-control\"></chain-field-input></div></div><div class=\"modal-footer text-right\"><button ng-click=\"cancel()\" class=\"btn btn-default\">Cancel</button> <button ng-click=\"save()\" class=\"btn btn-success\" title=\"Save\"><i class=\"fa fa-save\"></i></button></div></div></div></div>");
}]);

angular.module("chain-bulk-execute-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-bulk-execute-modal.html",
    "<div class=\"modal fade\" data-keyboard=\"false\" data-backdrop=\"static\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Bulk Action Running</h4></div><div class=\"modal-body\" ng-if=\"isVisible\"><p><b>A bulk action is processing.</b></p><p class=\"text-danger\">Do not close this window until the process is complete.</p><div class=\"progress\"><div class=\"progress-bar progress-bar-striped active\" role=\"progressbar\" aria-valuenow=\"{{tasks.complete}}\" aria-valuemin=\"0\" aria-valuemax=\"{{tasks.total}}\" style=\"width: {{tasks.percentComplete}}%\"><span class=\"sr-only\">{{tasks.remaining}} tasks remaining</span></div></div></div></div></div></div>");
}]);

angular.module("chain-change-password-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-change-password-modal.html",
    "<div class=\"modal fade\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><h4 class=\"modal-title\">Change Password</h4></div><div class=\"modal-body\"><div id=\"chain-change-password-form\" ng-show=\"!loading && !success\"><div class=\"form-group\"><label for=\"np\">New Password</label><input type=\"password\" class=\"form-control\" ng-model=\"password\"></div><div class=\"form-group\"><label for=\"np\">Confirm New Password</label><input type=\"password\" class=\"form-control\" ng-model=\"confirmation\"></div></div><div id=\"chain-change-password-loading\" ng-show=\"loading==&quot;loading&quot;\"><chain-loader></chain-loader></div><div id=\"chain-change-password-confirm\" ng-show=\"success.length > 0\"><div class=\"alert alert-success\">Password changed successfully.</div></div><div id=\"chain-change-password-errors\" ng-show=\"errors.length > 0\"><div class=\"alert alert-danger\"><strong>Errors:</strong><ul><li ng-repeat=\"e in errors\">{{e}}</li></ul></div></div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button> <button id=\"chain-change-password-submit\" ng-click=\"changePassword()\" ng-show=\"!(success.length > 0)\" type=\"button\" class=\"btn btn-primary\">Save changes</button></div></div></div></div>");
}]);

angular.module("chain-comments-panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-comments-panel.html",
    "<div class=\"panel panel-primary chain-comments-panel\"><div class=\"panel-heading\"><h3 class=\"panel-title\">Comments</h3></div><div class=\"panel-body\"><div ng-repeat=\"c in comments track by c.id\"><div class=\"panel panel-info\"><div class=\"panel-heading\"><div><div class=\"pull-right\"><abbr am-time-ago=\"c.created_at\" title=\"{{c.created_at}}\"></abbr> {{c.user.full_name}}</div>{{c.subject}}&nbsp;</div></div><div class=\"panel-body comment-body\">{{c.body}}</div><div class=\"panel-footer text-right\" ng-if=\"c.permissions.can_delete\"><button class=\"btn btn-xs btn-danger chain-comment-delete\" ng-click=\"c.deleteCheck=true\" ng-hide=\"c.deleteCheck\" title=\"Delete\"><i class=\"fa fa-trash\"></i></button><div ng-show=\"c.deleteCheck && !c.deleting\">Are you sure you want to delete this? <button class=\"btn btn-sm btn-danger chain-comment-delete-confirm\" ng-click=\"delete(c)\">Yes</button> &nbsp; <button class=\"btn btn-sm btn-default\" ng-click=\"c.deleteCheck=false\">No</button></div><div ng-show=\"deleting\">Deleting...</div></div></div></div><div class=\"panel panel-default chain-add-comment-panel\" ng-if=\"parent.permissions.can_comment\"><div class=\"panel-heading\"><input class=\"form-control\" placeholder=\"Subject\" ng-model=\"commentToAdd.subject\"></div><div class=\"panel-body\"><textarea ng-model=\"commentToAdd.body\" class=\"form-control\"></textarea></div><div class=\"panel-footer text-right\"><button class=\"btn btn-xs btn-success chain-add-comment-button\" ng-click=\"add(commentToAdd)\" ng-disabled=\"!(commentToAdd.body.length > 0)\"><i class=\"fa fa-plus\"></i></button></div></div></div></div>");
}]);

angular.module("chain-errors.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-errors.html",
    "<div class=\"modal fade chain-errors-modal\" id=\"chain-errors-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Errors</h4></div><div class=\"modal-body\" ng-if=\"isVisible\"><p ng-repeat=\"e in errorSvc.errors()\">{{e.message}} <span ng-if=\"e.count>1\" class=\"badge\">{{e.count}}</span></p></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-link\" data-dismiss=\"modal\" ng-click=\"silence()\">Stop showing errors on this page</button> <button type=\"button\" class=\"btn btn-primary\" data-dismiss=\"modal\">Close</button></div></div></div></div>");
}]);

angular.module("chain-messages-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-messages-modal.html",
    "<div class=\"modal\" id=\"chain-messages-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Messages</h4></div><div class=\"modal-body\"><chain-loading-wrapper loading-flag=\"{{loading}}\"><div ng-if=\"messages && messages.length==0\" class=\"text-success text-center\">You don't have any messages.</div><div class=\"panel-group\"><div class=\"panel\" ng-repeat=\"m in messages track by m.id\"><div class=\"panel-heading\"><h3 class=\"panel-title subject\" ng-click=\"readMessage(m)\" ng-class=\"{'unread-subject':!m.viewed}\">{{m.subject}}</h3></div><div ng-show=\"m.shown\" class=\"panel-body\"><div ng-bind-html=\"m.htmlSafeBody\" class=\"message-body\"></div></div></div></div></chain-loading-wrapper></div><div class=\"modal-footer\"><button ng-if=\"hasMore\" ng-click=\"loadMessages(nextPage)\" type=\"button\" class=\"btn btn-default\" id=\"chain-messages-modal-load-more\">More Messages</button> <button type=\"button\" class=\"btn btn-default\" id=\"toggle-email-new-messages\" ng-click=\"toggleEmailNewMessages()\"><i class=\"fa\" ng-class=\"{'fa-square-o':!user.email_new_messages, 'fa-check-square-o':user.email_new_messages}\"></i> Email Messages</button> <button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button></div></div></div></div>");
}]);

angular.module("chain-search-panel.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-search-panel.html",
    "<div class=\"panel panel-primary\"><div class=\"panel-heading\"><h3 class=\"panel-title\">{{name}}</h3></div><div class=\"panel-body\"><select ng-model=\"searchTableConfig\" ng-change=\"activateSearch(searchTableConfig)\" class=\"form-control\" ng-options=\"c as c.name for c in searchTableConfigs track by c.id\"></select></div><div class=\"panel-body\" ng-show=\"searchTableConfigs && searchTableConfigs.length==0\"><div class=\"panel panel-danger\"><div class=\"panel-body\">There aren't any searches setup for this panel. For more help, please contact support.</div></div></div><div class=\"panel-body\"><chain-search-table api-object-name=\"{{apiObjectName}}\" search-setup=\"coreSearch.searchSetup\" load-trigger=\"false\" page-uid=\"{{pageUid}}\"></chain-search-table></div><div class=\"panel-footer text-right\" ng-if=\"bulkEdit && coreSearch.searchSetup.bulkSelections\"><chain-bulk-edit api-object-name=\"{{apiObjectName}}\" page-uid=\"{{pageUid}}\" button-classes=\"btn-default btn-sm\"></chain-bulk-edit></div></div>");
}]);

angular.module("chain-search-table.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-search-table.html",
    "<div class=\"chain-search-table container-fluid\"><chain-loading-wrapper loading-flag=\"{{loading}}\"></chain-loading-wrapper><div class=\"text-right\"><div class=\"btn-group\"><button ng-click=\"downloadCsv()\" ng-show=\"hasBeenLoaded\" class=\"btn btn-xs btn-default\" title=\"Download CSV\"><i class=\"fa fa-download\"></i></button> <button ng-click=\"load()\" ng-show=\"searchSetup.allowManualInit || hasBeenLoaded\" class=\"btn-xs btn btn-default\" title=\"Reload\"><i class=\"fa fa-refresh\"></i></button></div></div><table class=\"table\" ng-if=\"content && !loading\"><thead><tr><th ng-if=\"searchSetup.bulkSelections\"><button title=\"Select All\" class=\"btn btn-xs btn-link\" ng-click=\"selectAll()\"><i class=\"fa fa-square-o\"></i></button></th><th ng-if=\"searchSetup.buttons.length > 0\">&nbsp;</th><th ng-repeat=\"col in searchSetup.columns track by $index\"><button class=\"btn btn-xs {{isFilteredColumn(col) ? &quot;btn-primary&quot; : &quot;btn-default&quot;}}\" ng-click=\"filterColumn(col)\" title=\"Filter\" ng-if=\"columnFields[col].data_type==&quot;string&quot;\"><i class=\"fa fa-filter\"></i></button> {{columnFields[col].label}}</th></tr></thead><tbody><tr ng-repeat=\"obj in content track by obj.id\"><td ng-if=\"searchSetup.bulkSelections\"><button ng-click=\"toggleBulkSelect(obj)\" title=\"Select Row\" class=\"btn btn-link btn-xs\"><i class=\"fa\" ng-class=\"{&quot;fa-check-square-o&quot;:isSelected(obj), &quot;fa-square-o&quot;:!isSelected(obj)}\"></i></button></td><td ng-if=\"searchSetup.buttons.length > 0\"><button ng-repeat=\"b in searchSetup.buttons track by $index\" class=\"{{b.class}}\" ng-click=\"b.onClick(obj)\" title=\"{{b.label}}\"><span ng-if=\"!b.iconClass\">{{b.label}}</span> <i class=\"{{b.iconClass}}\" ng-if=\"b.iconClass\"></i></button></td><td ng-repeat=\"col in searchSetup.columns track by $index\"><chain-field-value model=\"obj\" field=\"columnFields[col]\"></chain-field-value></td></tr></tbody><tfoot ng-if=\"totalPages()>1\"><td colspan=\"{{columnCount()}}\" class=\"text-right\">Page&nbsp;<select ng-model=\"searchSetup.page\" ng-options=\"p as p for p in pages\" class=\"form-control page-selector\"></select>&nbsp;of&nbsp; <span class=\"total-pages\">{{totalPages()}}</span></td></tfoot></table><div class=\"modal fade\" tabindex=\"-1\" role=\"dialog\" aria-labelledby=\"\" aria-hidden=\"true\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Filter</h4></div><div class=\"modal-body\"><chain-field-label field=\"columnFields[filterCriterion.field]\"></chain-field-label><input ng-model=\"filterCriterion.val\" class=\"form-control\"></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button> <button type=\"button\" class=\"btn btn-default\" ng-click=\"removeFilter(filterCriterion)\" title=\"Clear Filter\"><i class=\"fa fa-trash\"></i></button> <button type=\"button\" class=\"btn btn-primary\" ng-click=\"addFilter(filterCriterion)\" title=\"Filter\"><i class=\"fa fa-filter\"></i></button></div></div></div></div></div>");
}]);

angular.module("chain-state-toggle-buttons.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-state-toggle-buttons.html",
    "<div class=\"btn-group\"><button ng-hide=\"stButtons && stButtons.length==0\" type=\"button\" class=\"btn btn-default dropdown-toggle {{buttonClasses}}\" data-toggle=\"dropdown\" aria-haspopup=\"true\" aria-expanded=\"false\">Actions <span class=\"caret\"></span></button><ul class=\"dropdown-menu\"><li ng-if=\"!stButtons\" title=\"loading buttons\"><i class=\"fa fa-circle-o-notch fa-spin\"></i> Loading</li><li ng-repeat-start=\"b in stButtons track by b.id\" ng-repeat-end=\"b\" ng-click=\"toggle(b)\"><a href=\"javascript:void(0)\">{{b.button_text}}</a></li></ul></div>");
}]);

angular.module("chain-support-modal.html", []).run(["$templateCache", function($templateCache) {
  $templateCache.put("chain-support-modal.html",
    "<div class=\"modal fade\" id=\"chain-support-modal\"><div class=\"modal-dialog\"><div class=\"modal-content\"><div class=\"modal-header\"><button type=\"button\" class=\"close\" data-dismiss=\"modal\" aria-hidden=\"true\">&times;</button><h4 class=\"modal-title\">Help</h4></div><div class=\"modal-body\"><div><h3>User Manuals:</h3><div id=\"userManualLoading\" ng-if=\"umLoading==&quot;loading&quot;\"><chain-loader></chain-loader></div><div ng-show=\"userManuals.length==0\">There aren't any user manuals for this page.</div><div ng-repeat=\"um in userManuals track by um.id\"><a href=\"/user_manuals/{{um.id}}/download\" target=\"_blank\">{{um.name}}</a></div><hr></div><div ng-hide=\"ticketNumber || loading\"><label>Send A Message:</label><textarea ng-model=\"messageBody\" class=\"form-control\"></textarea></div><div ng-show=\"ticketNumber\"><div class=\"alert alert-success\"><p>Your ticket number is <strong id=\"chain-support-ticket-no\">{{ticketNumber}}</strong>.</p><p ng-show=\"moreHelpMessage\">{{moreHelpMessage}}</p></div></div><div ng-show=\"errors.length > 0\"><div class=\"alert alert-danger\"><strong>There were errors submitting your support request. You may email <a href=\"mailto:support@vandegriftinc.com\">support@vandegriftinc.com</a> for more help:</strong><ul><li ng-repeat=\"e in errors\">{{e}}</li></ul></div></div><div ng-show=\"loading==&quot;loading&quot;\"><chain-loader></chain-loader></div></div><div class=\"modal-footer\"><button type=\"button\" class=\"btn btn-default\" data-dismiss=\"modal\">Close</button> <button id=\"chain-support-submit\" ng-show=\"!ticketNumber\" ng-disabled=\"!messageBody || messageBody.length == 0\" ng-click=\"submit()\" type=\"button\" class=\"btn btn-primary\">Send Message</button></div></div></div></div>");
}]);
