class UserImportsController < AuthorizedController
  respond_to :html

  def new
    @user_import = SimpleCSV::UserImport.new
  end


  def create
    @user_import = SimpleCSV::UserImport.new(params[:simple_csv_user_import])

    @user_import.process!
    @rejected_user_data = @user_import.rejected_user_data
    render 'new'
  end
end