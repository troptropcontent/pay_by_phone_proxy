
require "uri"
require "json"
require "net/http"
require "date"

class PayByPhone
    def initialize(logger)
        @logger = logger
        check_env
        @tokens = get_tokens  
    end

    def current_tickets
        @current_tickets ||= get_current_tickets
    end

    def vehicle_id
        @vehicle_id ||= find_vehicle["vehicleId"]
    end

    def member_id
        @member_id ||= get_member_id
    end

    def account_id
        @account_id ||= get_account_id
    end

    def vehicule_covered?
        !!current_tickets.filter{|parking| parking.dig('vehicle', 'licensePlate') == ENV["PAYBYPHONE_LICENSEPLATE"]}.sort_by{|parking| DateTime.parse(parking.dig("expireTime"))}.first 
    end

    def rate_option_id
        @rate_option_id ||= find_rate_option["rateOptionId"]
    end

    def quote
        @quote ||= get_quote
    end

    def payment_method_id
        @payment_method ||= find_payment_method["id"]
    end

    def new_session
        create_new_session
    end
   
    private

    def env_ready?
        ENV["PAYBYPHONE_USERNAME"] && ENV["PAYBYPHONE_PASSWORD"] && ENV["PAYBYPHONE_LICENSEPLATE"] && ENV["PAYBYPHONE_ZIPCODE"] && ENV["PAYBYPHONE_CARDNUMBER"]
    end

    def get_tokens
        @logger.info("Retrieving Token")
        url = URI("https://auth.paybyphoneapis.com/token")
        
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true
        
        request = Net::HTTP::Post.new(url)
        request["Accept"] = "application/json, text/plain, */*"
        request["Accept-Language"] = "fr-FR,fr;q=0.9"
        request["Connection"] = "keep-alive"
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request["Sec-Fetch-Dest"] = "empty"
        request["Sec-Fetch-Mode"] = "cors"
        request["Sec-Fetch-Site"] = "cross-site"
        request["X-Pbp-ClientType"] = "WebApp"
        request.body = URI.encode_www_form({
            grant_type: 'password',
            username: ENV["PAYBYPHONE_USERNAME"],
            password: ENV["PAYBYPHONE_PASSWORD"],
            client_id: 'paybyphone_web'
        })
        
        response = https.request(request)
        tokens = JSON.parse(response.read_body)
        @logger.info("Token retrieved")
        tokens
    end 

    def get_member_id
        @logger.info("Retrieving member_id")
        url = URI("https://consumer.paybyphoneapis.com/identity/profileservice/v1/members")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Connection"] = "keep-alive"
        request["Content-Type"] = "application/json"

        response = https.request(request)
        @logger.info("Member retrieved")
        JSON.parse(response.read_body)["memberId"]
    end

    def get_account_id
        @logger.info("Retrieving account_id")
        url = URI("https://consumer.paybyphoneapis.com/parking/accounts")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token

        response = https.request(request)
        @logger.info("Account_id retrieved")
        JSON.parse(response.read_body).dig(0,"id")
    end

    def get_current_tickets
        @logger.info("Retrieving current tickets")
        url = URI("https://consumer.paybyphoneapis.com/parking/accounts/#{account_id}/sessions?periodType=Current")
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"

        response = https.request(request)
        @logger.info("Current tickets retrieved")
        JSON.parse(response.read_body)
    end

    def get_vehicles
        @logger.info("Retrieving vehicles")
        url = URI("https://consumer.paybyphoneapis.com/identity/profileservice/v1/members/vehicles/paybyphone")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"

        response = https.request(request)
        @logger.info("Vehicle retrieved")
        JSON.parse(response.read_body)
    end

    def get_rate_options
        @logger.info("Retrieving rate_options")
        uri = URI.parse("https://consumer.paybyphoneapis.com/parking/locations/75018/rateOptions")
        uri.query = URI.encode_www_form({
            parkingAccountId: account_id,
            licensePlate: ENV["PAYBYPHONE_LICENSEPLATE"],
        })
        
        https = Net::HTTP.new(uri.host, uri.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"


        response = https.request(request)
        @logger.info("Rate_options retrieved")
        JSON.parse(response.read_body)
    end

    def find_rate_option
        get_rate_options.find{|rate_option| rate_option["name"] == "Résident"}
    end

    def find_vehicle
        get_vehicles.find{|vehicle| vehicle["licensePlate"] == ENV["PAYBYPHONE_LICENSEPLATE"]} 
    end

    def authorization_token
        "Bearer #{@tokens['access_token']}"
    end

    def get_quote
        @logger.info("Requesting a quote")
        url = URI.parse("https://consumer.paybyphoneapis.com/parking/accounts/#{account_id}/quote")
        url.query = URI.encode_www_form({
            locationId: ENV["PAYBYPHONE_ZIPCODE"],
            licensePlate: ENV["PAYBYPHONE_LICENSEPLATE"],
            stall: nil,
            rateOptionId: '75101',
            durationTimeUnit: 'Days',
            durationQuantity: 1,
            isParkUntil: false,
            expireTime: nil,
            parkingAccountId: account_id
        })
        
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"

        response = https.request(request)
        @logger.info("Quote obtained")
        JSON.parse(response.read_body)
    end

    def get_payment_methods
        @logger.info("Retrieving payment methods")
        url = URI("https://consumer.paybyphoneapis.com/payment/v3/accounts")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"

        response = https.request(request)
        @logger.info("Payment method retrieved")
        JSON.parse(response.read_body)
    end

    def find_payment_method
        get_payment_methods["items"].find{|payment_method| payment_method["maskedCardNumber"] == ENV["PAYBYPHONE_CARDNUMBER"]}
    end

    def create_new_session
        @logger.info("Requesting to start a new session")
        url = URI("https://consumer.paybyphoneapis.com/parking/accounts/#{account_id}/sessions/")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"
        request.body = JSON.dump({
        "expireTime": nil,
        "duration": {
            "quantity": "1",
            "timeUnit": "days"
        },
        "licensePlate": ENV["PAYBYPHONE_LICENSEPLATE"],
        "locationId": ENV["PAYBYPHONE_ZIPCODE"],
        "rateOptionId": "75101",
        "startTime": quote["parkingStartTime"],
        "quoteId": quote["quoteId"],
        "parkingAccountId": account_id,
        "paymentMethod": {
            "paymentMethodType": "PaymentAccount",
            "payload": {
            "paymentAccountId": payment_method_id,
            "clientBrowserDetails": {
                "browserAcceptHeader": "text/html",
                "browserColorDepth": "30",
                "browserJavaEnabled": "false",
                "browserLanguage": "fr-FR",
                "browserScreenHeight": "900",
                "browserScreenWidth": "1440",
                "browserTimeZone": "-60",
                "browserUserAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36"
            }
            }
        }
        })
        response = https.request(request)
        if response.code == 204
            @logger.info("New session started") 
        else
            @logger.info("An issue occured in the request of a new session")
        end
        JSON.parse(response.read_body)
    end

    def check_env
        unless env_ready?
            @logger.error("ENV variables are not set") 
            exit(false)
        end
    end
end
