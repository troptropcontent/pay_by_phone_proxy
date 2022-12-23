require_relative 'client/pay_by_phone'

puts "New process"
client = PayByPhone.new

puts "Checking vehicule coverage"
coverage = client.vehicule_covered?

if coverage
    puts "Vehicule covered at this time. Task stopped."
else
    puts "Vehicule not covered at this time. Renewing ticket for a new period."
end