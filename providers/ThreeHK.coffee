rp = require('request-promise')
_ = require('underscore')
urlencode = require('urlencode');
SMSProvider = require('./SMSProvider')

module.exports = (Promise, options, plugin) ->

  class ThreeHKSMSProvider extends SMSProvider
    constructor: (@options, @plugin) ->
        super()

        @checkOptions(options, {'password': '', 'fromNumber': 'mobileNumber'})

        phoneUtil = @plugin.phoneUtil
        @mobileLoginNumber = phoneUtil.format(phoneUtil.parse(@options.fromNumber,'HK'), @plugin.phone.PhoneNumberFormat.NATIONAL).replace(/ /,'').trim();
        @password = @options.password

        @options.headers = @options.headers || {}
        @options.requestOptions = @options.requestOptions || {}

        @cookieJar = rp.jar();

        @defaultHeaders = _.extendOwn({
            "Host": "www.three.com.hk"
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36"
            "Origin": "https://www.three.com.hk"
            "Upgrade-Insecure-Requests": "1"
            "DNT": "1"
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        }, @options.headers)

        # Set some Defaults
        @rp = rp.defaults(_.extendOwn({
                baseUrl: 'https://www.three.com.hk'
                method: 'POST'
                gzip: true
                jar: @cookieJar
            }, @options.requestOptions))

    _logout: () =>
        options = {
            method: "GET"
            uri: '/3Care/3CareBillAndUsage.do?lang=eng'
            headers: _.extendOwn(@defaultHeaders, {
                "Referer": "https://www.three.com.hk/appCS2/eng/processlogoutredir.jsp?URLTo=%2F3Care%2Feng%2Fhome.jsp%3Flang%3Deng"
            })
        }

        return @rp(options)
            .then( (response) =>
                @plugin.env.logger.debug('Successfully Logged Out')
            )

    _login: (mobileNumber, password) =>
        isCookiesValid = (j) ->
            try
                cookies = j.getCookies('https://www.three.com.hk/', {secure: false, expire: true, allPaths: false}, ( (err,cookies) ->
                    # Note this function actually does not work
                    ))
                cookies = j.getCookies('https://www.three.com.hk/', {secure: false, expire: true, allPaths: false}, ( (err,cookies) ->
                    # Note this function actually does not work
                    ))
                return cookies.length > 0
            catch error
                return false

        if (isCookiesValid(@cookieJar)) then return new Promise((resolve) -> resolve())

        options = {
            uri: '/3Care/verifyLogin.do?lang=eng&loginFrom=home'
            form: {
                "mobileno": mobileNumber
                "password": password
                "URLTo": ""
                "url_3g": ""
                "url_2g": ""
                "action": "login"
            }
            headers: _.extendOwn(@defaultHeaders, {
                "Referer": "https://www.google.com.hk/"
            })
        }

        return @rp(options)
            .then( () =>
                @plugin.env.logger.debug('Successfully Logged In')
            )

    _createSMS: (toNumber, message) =>
        msgLength = (160 - Buffer.from(message).length)
        toNumber = urlencode(toNumber)

        if msgLength < 0 then throw new Error "Message is over 160 characters!"

        # For some reason we need to fomrat this way
        message = urlencode(message).replace(/%20/g,'+')

        options = {
            uri: '/websms/eng/receive.jsp'
            form: "mobile_list=#{toNumber}&Message=#{message}&canmsg=--------+Select+predefined+message+--------&cansym=Expression&msgsize=#{msgLength}&sender="
            headers: _.extendOwn(@defaultHeaders, {
                "Referer": "https://www.three.com.hk/websms/eng/SenderEntry.jsp"
            })
        }

        return @rp(options)
            .then( () =>
                @plugin.env.logger.debug('Successfully Created SMS')
            )

    _sendSMS: () =>
        options = {
            uri: '/websms/eng/send.jsp'
            headers: _.extendOwn(@defaultHeaders, {
                "Referer": "https://www.three.com.hk/websms/eng/receive.jsp"
            })
        }

        return @rp(options).then( () =>
                @plugin.env.logger.debug('Successfully Sent SMS!')
            )

    _createAndSendSMS: (toNumber, message) =>
        return @_createSMS(toNumber, message)
            .then( () =>
                return @_sendSMS()
            )

    _extractCookieValues: (j) ->
        cookies = j.getCookies('https://www.three.com.hk/', {secure: false, expire: false, allPaths: false}, ( (err,cookies) ->
            # Note this function actually does not work
            ))

        userProfile = {
            customerName: []
            mobileNumber: ''
            customerClass: ''
            mobileActivationDate: ''
            contractExpiryDate: ''
            hasLTE: false,
            networkType: ''
            lastLogin: ''
        }

        for i of cookies
            cookie = cookies[i]
            #@plugin.env.logger.debug JSON.stringify(cookie,null,2)
            if (cookie.key is 'CustName') then userProfile.customerName = cookie.value.split('               ')
            else if (cookie.key is 'CustClass') then userProfile.customerClass = cookie.value
            else if (cookie.key is 'MobileActivationDate') then userProfile.mobileActivationDate = cookie.value
            else if (cookie.key is 'ContractExpiryDate') then userProfile.contractExpiryDate = cookie.value
            else if (cookie.key is 'NetType') then userProfile.networkType = cookie.value
            else if (cookie.key is 'LTE') then userProfile.hasLTE = cookie.value is 'Y' ? true : false
            else if (cookie.key is 'csLogin')
                csValues = cookie.value.split('|')
                userProfile.mobileNumber = csValues[1]
                userProfile.lastLogin = csValues[5]

        return userProfile

    sendSMSMessage: (toNumber, message) =>
      @plugin.env.logger.debug 'Attempting to Login to 3Care'
      return @_login(@mobileLoginNumber, @password)
          .then( () =>
            @plugin.env.logger.debug 'Successfully Logged into 3Care'
            return @_createAndSendSMS(toNumber,message)
          ).then( () =>
            return {
              to: toNumber
            }
          )

    destroy: () =>
      @_logout().then( () =>
          @cookieJar = null
          @rp = null
        )


  return new ThreeHKSMSProvider(options, plugin)
