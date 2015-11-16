angular.module('ChainComponents').directive 'tariffLink',['$compile','officialTariffSvc','chainDomainerSvc', ($compile,officialTariffSvc,chainDomainerSvc) ->
  {
    restrict: 'E'
    scope: {
      hts: '@'
      iso: '@'
    }
    templateUrl: '/partials/official_tariffs/tariff_link.html'
    link: (scope,el,attrs) ->
      scope.uid = new Date().getTime().toString() + scope.$id

      # set a unique id to find this once we move it out to the body to bust out of any surrounding modals
      mod = $(el).find('.modal')
      mod.attr('id',scope.uid)

      # bust out of any containers so the modal opens at the top of the stack when modals are nested
      mod.appendTo('body')

      # clean up detached modals
      el.on '$destroy', () ->
        $('#'+scope.uid).remove()

      scope.loadingFlag = () ->
        return '' if scope.dictionaryLoaded && scope.officialTariffLoaded
        return 'loading'

      scope.showDetail = () ->
        scope.modalActivated = true
        myModal = $('#'+scope.uid)
        myModal.modal('show')

        if !scope.dictionaryLoaded
          chainDomainerSvc.withDictionary().then (dict) ->
            scope.dictionaryLoaded = true
            scope.dictionary = dict
            fieldsToUse = [
              'ot_chapter'
              'ot_heading'
              'ot_sub_heading'
              'ot_remaining'
              'ot_common_rate'
              'ot_gen_rate'
              'ot_gpt'
              'ot_erga_omnes_rate'
              'ot_mfn'
              'ot_spec_rates'
              'ot_col_2'
              'ot_ad_v'
              'ot_per_u'
              'ot_calc_meth'
              'ot_uom'
              'ot_import_regs'
              'ot_export_regs'
            ]
            scope.fields = []
            $.each(fieldsToUse, (idx,fldUid) ->
              scope.fields.push(dict.field(fldUid))
            )

        # only load once since tariff is unlikely to change during
        # user session
        if !scope.officialTariffLoaded
          officialTariffSvc.getTariff(scope.iso,scope.hts).then (ot) ->
            scope.officialTariffLoaded = true
            scope.officialTariff = ot
            if ot==null
              scope.errorMessage = 'Tariff not found.'

  }
]