SMSProvider = require('./SMSProvider')

module.exports = (Promise, options, plugin) ->

  class TwilioSMSProvider extends SMSProvider
    constructor: (options, plugin) ->
      super()

      @checkOptions(options, {'login': '', 'password': '', 'fromNumber': 'from number'})
      # require the Twilio module and create a REST client
      @client = require("twilio")(options.login, options.password);
      @client.messages.create = Promise.promisify(@client.messages.create)

    sendSMSMessage: (toNumber, message) ->
      return @client.messages.create({
            to: toNumber,
            from: options.fromNumber,
            body: message})

  provider = new TwilioSMSProvider(options, plugin)

  # Pass back the message method
  return provider
