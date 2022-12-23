1. Set up your ENV variables : `PAYBYPHONE_USERNAME` `PAYBYPHONE_PASSWORD` `PAYBYPHONE_LICENSEPLATE`

2. Create a cron task taht run asoften that you want (i did every 5 minutes between 9am and 7pm) : 
    `*/5 09-19 * * * ruby path_to_the_directory/index.rb`

3. Your done, this will renew your parking ticket everytime it expire

4. Just ensure your credit card linked to the account is provisionned
