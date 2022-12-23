
require "uri"
require "json"
require "net/http"
require "date"

class PayByPhone
    def initialize
        raise "ENV variables are not set" unless env_ready?
        @tokens = get_tokens    
    end

    def current_tickets
        @current_tickets ||= get_current_tickets
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
   
    private

    def env_ready?
        ENV["PAYBYPHONE_USERNAME"] && ENV["PAYBYPHONE_PASSWORD"] && ENV["PAYBYPHONE_LICENSEPLATE"]
    end

    def get_tokens
        puts "Retrieving Token"
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
        puts "Token retrieved : #{tokens['access_token']}"
        tokens
    end 

    def get_member_id
        url = URI("https://consumer.paybyphoneapis.com/identity/profileservice/v1/members")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Connection"] = "keep-alive"
        request["Content-Type"] = "application/json"

        response = https.request(request)
        JSON.parse(response.read_body)["memberId"]
    end

    def get_account_id
        url = URI("https://consumer.paybyphoneapis.com/parking/accounts")

        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token

        response = https.request(request)
        JSON.parse(response.read_body).dig(0,"id")
    end

    def get_current_tickets
        url = URI("https://consumer.paybyphoneapis.com/parking/accounts/#{account_id}/sessions?periodType=Current")
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true

        request = Net::HTTP::Get.new(url)
        request["Authorization"] = authorization_token
        request["Content-Type"] = "application/json"

        response = https.request(request)
        JSON.parse(response.read_body)
    end

    def authorization_token
        "Bearer #{@tokens['access_token']}"
    end
end

