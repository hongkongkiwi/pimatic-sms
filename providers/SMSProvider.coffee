class SMSProvider
     constructor: () ->
        @hasPriceInfo = false
        return
     destroy: () =>
        return
     sendSMSMessage: (toNumber, message) =>
        return      
     checkOptions: (options, params, fail = true) =>
        unless options?
          throw new Error 'Must pass options'
        for key of params
          if (not options.hasOwnProperty key) or (options[key] is '')
            if fail
              id = params[key] || key
              throw new Error "Must specify '#{id}' in options"
            else
              return key
        return ''

module.exports = SMSProvider
