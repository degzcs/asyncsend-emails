class MandrillOperationWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(operation_id)
    operation_id = operation_id["$oid"]
    operation = MandrillOperation.find(operation_id)
    params =  operation.params.merge(operation_id: operation_id)
    operation.service.constantize.__send__(operation.method_name, params)
  end
end