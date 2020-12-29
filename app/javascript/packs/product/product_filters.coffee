@pa = angular.module('ProductApp')
# filters an array of fields and only returns those that the users
# should get in an edit dialog
@pa.filter('productEditFields', ->
  (input) ->
    return input unless input && input.length > 0
    $.grep(input, (fld) ->
      return null if fld.uid.match(/^\*fhts/)
      return fld
    )
)

@pa.filter 'productComponentEditFields', ->
  (dictionary,country_iso) ->
    return [] unless dictionary
    fields = dictionary.fieldsByRecordType(dictionary.recordTypes.TariffRecord)
    return $.grep(fields, (fld) ->
      # don't show legacy hts 1, 2 & 3 fields (or schedule b  2-3 equivalents)
      #hts 1 is hard coded in the view so it can have proper autocomplete
      for regex in [/hts_[123]$/,/[23]_schedb$/,/^hts_hts_1$/,/hts_line_number/,/hts_view_sequence/]
        return null if fld.uid.match(regex)

      # only return schedule b for US
      return null if !country_iso || country_iso.toLowerCase()!='us' && fld.uid=='hts_hts_1_schedb'

      return fld
    )

@pa.filter 'productClassificationEditFields', ->
  (dictionary) ->
    return [] unless dictionary
    fields = dictionary.fieldsByRecordType(dictionary.recordTypes.Classification)
    return  $.grep(fields, (fld) ->
      return null if fld.uid.match(/^class_cntry_/)
      return fld
    )

@pa.filter 'productClassificationViewFields', ->
  (dictionary) ->
    return [] unless dictionary
    fields = dictionary.fieldsByRecordType(dictionary.recordTypes.Classification)
    return  $.grep(fields, (fld) ->
      for regex in [/^class_cntry_/,/^class_class_comp_cnt/]
        return null if fld.uid.match(regex)
      return fld
    )