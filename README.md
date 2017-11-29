# pimatic-sms

SMS Integration with [Pimatic](https://pimatic.org). Supports:
* [Twilio](https://www.twilio.com) 
* [ThreeHK](http://www.three.com.hk) 
* [ePochtaSMS](https://www.epochtasms.ru)
* [Mobilant](http://www.mobilant.be) 
* [MQTT-SIM900 SMS Bridge](https://github.com/ptvoinfo/sim-module) 
* new providers can be added (add your plugins to to the /providers/ folder)


## Plugin Configuration

You can load the backend by editing your `config.json` to include:

```json
{
   "plugin": "sms",
   "provider": "twilio",
   "fromNumber": "+112345689",
}
```

If you didn't want to specify the "to number" in every rule, you could set a global number in the config:

```json
{
  "toNumber": "+81239529"
}
```

_Note: Even when this is set, it can still be overridden for each rule if needed._

### Provider Configuration

Each provider requires different fields in the plugin config

__Twilio__

```json
{
  "twilioAccountSid": "YOUR_TWILLIO_ACCOUNT_SID",
  "twilioAuthToken": "YOUR_TWILLIO_AUTH_TOKEN"
}
```

__ThreeHK__

```json
{
  "threehkPassword": "YOUR_PASSWORD"
}
```

_Note: Uses the fromNumber as your login number so only password is required_

Depending on which provider you pick you will need to provide some additional properties as seen above with twilio*. You can see all available properties by looking at [sms-config-schema](sms-config-schema.coffee).

#### SMS Provider Pricing

Each provider has different pricing, it's up to you to handle this! Some providers might be free depending on the from/to number.

Check with each company for a detailed analysis of their pricing. Most are setup in a pre-pay type arrangement, so you can keep an eye on your budget.

## Example

It can be used like any normal Pimatic rule

- if it is 08:00 send sms message "Good morning!" to number "+1888123456"
- if X then send sms message "X Happened" to number "+1888123456"

If you want to add a button in the interface just to trigger an SMS, you could add it in the 'devices' section of `config.json` like so:

```json
{
  "id": "dummy-buttons",
  "name": "Dummy Buttons",
  "class": "ButtonsDevice",
  "buttons": [
    {
      "id": "button1",
      "text": "Send an SMS Message"
    }
  ]
}
```

Then you would add a rule
`when "button1" is pressed then send sms message "Good morning!" to number "+1888123456"`

## TODO

- Add [Plivo SMS Provider](https://www.plivo.com)
- Add [Sinch SMS Provider](https://www.sinch.com)
- Add [Nexmo SMS Provider](https://www.nexmo.com)

## Contributing

Feel free to submit any pull requests or add functionality, I'm usually pretty responsive.

If you like the module, please consider donating some bitcoin or litecoin.

**Bitcoin**

![LNzdZksXcCF6qXbuiQpHPQ7LUeHuWa8dDW](http://i.imgur.com/9rsCfv5.png?1)

**LiteCoin**

![LNzdZksXcCF6qXbuiQpHPQ7LUeHuWa8dDW](http://i.imgur.com/yF1RoHp.png?1)
