# #SMS Plugin
# This plugin sends SMS using various SMS providers

# ##The plugin code
module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  #util = env.require 'util'
  M = env.matcher 

  # Load our extra libraries
  phone = require('node-phonenumber')
  phoneUtil = phone.PhoneNumberUtil.getInstance()

  # SMS Plugin
  class SMSPlugin extends env.plugins.Plugin
    # ####init()
    init: (app, @framework, @config) =>
      @provider = null
      @env = env
      @phone = phone
      @phoneUtil = phoneUtil

      pluginPath = @framework.pluginManager.pathToPlugin("pimatic-"+@config.plugin)
      @currentSchemaRef = env.require pluginPath + '/sms-config-schema.coffee'
      getClassOf = Function.prototype.call.bind(Object.prototype.toString);

      providers = {}

      fs = require "fs"
      path = require "path"

      app.post('/pimatic-sms/provider', (req, res) =>
        newprovider = req.body.provider
        #console.log('Provider: ' + newprovider)
        if @currentSchemaRef.provideroptions? and (newprovider of @currentSchemaRef.provideroptions)
          @currentSchemaRef.required = @currentSchemaRef.provideroptions[newprovider].required
        res.sendStatus 200
      )

      @framework.on "after init", =>
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-sms/app/pimatic-sms-page.coffee"
        return

      # we can use only one provider at time therefore we load only the selected provider
      providersDir = '/providers/'
      providersPath = pluginPath + providersDir
      dirs = fs.readdirSync(providersPath)
      re = /\.coffee$/i
      for file in dirs
        if not file.match(re) then continue
        prov = file.replace(re, '').toLowerCase()
        if (prov isnt "index") and (prov isnt "smsprovider")
          file = '.' + providersDir + file
          providers[prov] = file

      if (providers.length is 0 or @config.provider.length is 0) then throw new Error("No Providers Available!")

      # ADD SMS PROVIDER CONFIG HERE
      if providers.hasOwnProperty @config.provider
        @provider = require(providers[@config.provider])(Promise, @config, @)
      else
        throw new Error("Invalid Provider '#{@config.provider}' Specified!")

      @framework.ruleManager.addActionProvider(new SMSActionProvider @framework, @)

    destroy: () =>
      if @provider? then @provider.destroy()
      super()
    prepareConfig: (config) =>
      try
        if config.twilioAccountSid?          
          config.login = config.twilioAccountSid unless config.login?
          delete config['twilioAccountSid'] 
        if config.twilioAuthToken?
          config.password = config.twilioAuthToken unless config.password?
          delete config['twilioAuthToken'] 
      catch error
        env.logger.error "Unable prepare config: " + error 

  # Create a instance of my plugin
  plugin = new SMSPlugin

  class SMSActionProvider extends env.actions.ActionProvider

    constructor: (@framework, @plugin) ->
      return

    parseAction: (input, context) =>
      # Helper to convert 'some text' to [ '"some text"' ]
      strToTokens = (str) => ["\"#{str}\""]

      textTokens = strToTokens ""
      toNumberTokens = strToTokens @plugin.config.toNumber || ""

      setText = (m, tokens) => textTokens = tokens
      setToNumber = (m, tokens) => toNumberTokens = tokens

      m = M(input, context)
        .match(['send ','write ','compose '], optional: yes)
        .match(['sms ','text '])
        .match(['message '], optional: yes)
        .matchStringWithVars(setText)

      if @plugin.config.toNumber?
        next = m.match([' to number ',' to phone ']).matchStringWithVars(setToNumber)
        if next.hadMatch() then m = next
      else
        m.match([' to number ',' to phone ']).matchStringWithVars(setToNumber)

      if m.hadMatch()
        match = m.getFullMatch()

        assert Array.isArray(textTokens)
        assert Array.isArray(toNumberTokens)

        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new SMSActionHandler(
            @framework, textTokens, toNumberTokens, @plugin.provider, @plugin.config.numberFormatCountry
          )
        }

  plugin.SMSActionProvider = SMSActionProvider

  class SMSActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @textTokens, @toNumberTokens, @provider, @numberFormatCountry) ->
      return

    executeAction: (simulate, context) ->
      Promise.all( [
        @framework.variableManager.evaluateStringExpression(@textTokens)
        @framework.variableManager.evaluateStringExpression(@toNumberTokens)
      ]).then( ([text, toNumber]) =>
        return new Promise((resolve, reject) =>

          if toNumber is ""
            return reject(__("No To Phone Number Specified"))
          # if toNumber is ""
          #   return reject(__("No Text Specified to post! Ignoring"))

          if @numberFormatCountry
            formattedToNumber = phoneUtil.format(phoneUtil.parse(toNumber,@numberFormatCountry), phone.PhoneNumberFormat.E164);
          else
            formattedToNumber = toNumber

          if simulate
            return resolve(__("Would send SMS #{message} to #{formattedToNumber}"))
          else
            return @provider.sendSMSMessage(formattedToNumber, text).then( (message) =>
                if (@provider.hasPriceInfo)
                    if (message.price is null)
                      env.logger.debug "SMS sent to #{formattedToNumber} for free!"
                      resolve __("SMS sent to #{formattedToNumber} for free!")
                    else
                      env.logger.debug "SMS sent to #{formattedToNumber} and cost #{message.price} #{message.price_unit}"
                      resolve __("SMS sent to #{formattedToNumber} and cost #{message.price} #{message.price_unit}")
                else
                    env.logger.debug "SMS sent to #{formattedToNumber}"
                    resolve __("SMS sent to #{formattedToNumber}")
            , (rejection) ->
              reject rejection.message
              )
        )
      )

  plugin.SMSActionHandler = SMSActionHandler

  # and return it to the framework.
  return plugin
