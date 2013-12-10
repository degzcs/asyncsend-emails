class MandrillSystemOperationWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(system_operation_id)
    system_operation = MandrillSystemOperation.find(system_operation_id)
    params =  system_operation.params
    response = system_operation.mandrill_operation.service.constantize.__send__(system_operation.method_name, params)
    system_operation.update_attribute(:status, response.first['status'])
    system_operation.update_attribute(:mandrill_id, response.first['_id'])
  end

end