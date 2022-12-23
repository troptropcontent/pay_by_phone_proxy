require "logger"
class ExecutionLogger
    def initialize
       @logger = Logger.new('execution_logs.log') 
    end

    def info(message)
        @logger.info(message)
    end
    def error(message)
        @logger.error(message)
    end
end