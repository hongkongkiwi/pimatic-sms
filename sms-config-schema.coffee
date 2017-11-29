module.exports = {
  title: "SMS Plugin Config Options"
  type: "object"
  required: ["provider","fromNumber"]
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    provider:
      description: "Which SMS Provider to use"
      type: "string"
      default: "twilio"
      enum: ["twilio"]
    login:
      description: "Login (authorization ID for your SMS provider)"
      type: "string"
      default: ""
    password:
      description: "Password or authorization token"
      type: "string"
      default: ""
    fromNumber:
      description: "Number to send SMS from"
      type: "string"
      default: ""
    toNumber:
      description: "Default number to send SMS messages to"
      type: "string"
      default: ""
    numberFormatCountry:
      description: "Country code to format numbers in. This helps us to format numbers correctly incase country code is not passed. You can still override it without a country code, but allows you to write numbers with a default country code for convenience."
      type: "string"
      default: ""
}

#util = require('util')
#console.log(util.inspect(env, { showHidden: true, depth: null }));

providers = []

fs = require "fs"
path = require "path"
dir = path.dirname(__dirname)
re = /pimatic\-sms[\\\/]*/i
dir = dir.replace(re, '')
dir += '/pimatic-sms/providers/'
files = fs.readdirSync(dir)
re = /\.coffee$/i
re2 = /\-schema\.*/i

schemas = []

for f in files
  if f.match(re2)
    schemas.push(f)
    continue
  else if not f.match(re) then continue
  f = f.replace(re, '').toLowerCase()
  if (f isnt "index") and (f isnt "smsprovider")
    providers.push(f)
providers = providers.sort()
module.exports.properties.provider.enum = providers

module.exports.defaultrequired = module.exports.required
module.exports.provideroptions = {}

for f in schemas
  custom_schema = require(dir + f)
  provider = f.replace(re, '').replace(re2, '').toLowerCase()

  module.exports.provideroptions[provider] = {}
  module.exports.provideroptions[provider].required = module.exports.required
  
  if custom_schema.required?
    module.exports.provideroptions[provider].required = custom_schema.required
  module.exports.provideroptions[provider].hide = [];
  if custom_schema.hide?
    module.exports.provideroptions[provider].hide = custom_schema.hide

  main_prop = module.exports.properties  
  if custom_schema.properties?
    for p of custom_schema.properties
      if main_prop.hasOwnProperty p
        unless main_prop.defaultdescription?
          main_prop[p].defaultdescription = main_prop[p].description
        if custom_schema.properties[p].description?
          main_prop[p]['descriptions'] ||= {}
          main_prop[p]['descriptions'][provider] = custom_schema.properties[p].description
      else
        main_prop[p] = custom_schema.properties[p]
        main_prop[p].provider = provider
