require_relative 'client/pay_by_phone'
require_relative 'logger/execution_logger.rb'

logger = ExecutionLogger.new

logger.info("New process")
client = PayByPhone.new(logger)

logger.info("Checking vehicule coverage")
coverage = client.vehicule_covered?

if coverage
    logger.info("Vehicule covered at this time. Task stopped.")
else
    logger.info("Vehicule not covered at this time. Renewing ticket for a new period.")
end