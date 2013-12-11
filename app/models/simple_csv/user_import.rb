module SimpleCSV
  class UserImport

    include ActiveAttr::Model

    # The actual file to be processed (imported)
    attribute :file
    attribute :data


    # limit: limits how many valid rows from the CSV file are processed (0 = all)
    attribute :limit, default: 0

    validates_presence_of :file
    validate :csv_file_format
    validate :csv_file_headers

    attr_accessor :rejected_user_data

    def setup_data
      @rejected_user_data = []
    end

    # Actually process this import and make it happen
    def process!
      if valid?
        # get the csv rows as an array of hashes
        setup_data
        raw_csv_data = compute_csv_data
        # remove duplicate rows in the csv file (by email or name)
        prefilterted_csv_data = prefilter_csv_data raw_csv_data
        # remove the rows that match emails in the database
        new_data = filter_data_through_db prefilterted_csv_data

        # crate a new users
        resolved_data = create_new_user_records new_data
      end
      @rejected_user_data
    end

    private

    # Create a new user instance from the whole data passed
    # @return [User] the new user instance
    def new_user_record_from(user_data)
      user = User.new(email: user_data[:email], name: user_data[:name], password: "temporal_password")
      user
    end

    # Creates new user records from the CSV data
    def create_new_user_records(new_data)
      new_users = []
      resolved_data = new_data
        resolved_data.each do |user_data|
          user = new_user_record_from user_data
          if user.save
            new_users << user
            user_data[:status] = :success
          else
            user_data[:unknown_errors] << user.errors.full_messages
          end
        end
      resolved_data
    end

    # @returns [Hash] processed csv data
    def filter_data_through_db(prefiltered_csv_data)

      email_filtered_data = prefiltered_csv_data.reject do |user_data|
        valid_data = complete_email_list.include? user_data[:email]
        if valid_data
          user_data[:errors] << "The Email already exists!"
          @rejected_user_data << user_data
        end
        valid_data
      end
    end

    # Returns a hash for the CSV data
    def csv_data
      @csv_data ||= compute_csv_data
    end

    # Pre-filters csv data to reject duplicate records in the csv itself
    # This is different than valid_row? because it uses the total data for computing additional filtering
    def prefilter_csv_data(raw_csv_data)
      # De-dup emails absolutely
      csv_data = raw_csv_data.uniq{|row| row[:email]}

      # Remove data with duplicate names scoped in company and address (parameterized)
      #csv_data.uniq{|row| "#{row[:first_name]} #{row[:last_name]} #{row[:company]} #{row[:address]}".try(:parameterize)}
    end

    # Creates and array of hashes for the csv file
    def compute_csv_data
      row_count = 0
      csv_row_number = 0
      csv_data = []
      CSV.foreach(self.file.path, headers: true) do |row|
        # Transform row to hash
        row = row.to_hash
        # Normalize it
        row = normalize_row(row)
        # Increment row number
        csv_row_number += 1

        # PRECOMPUTE
        row = precompute_row(row, csv_row_number) # row[:csv_row_number] = csv_row_number AND initialize errors and array fields as arrays

        # store the valid_row result
        valid_row = valid_row?(row)

        # tranform raw row hash into a intermediate (more concise) information OR put in rejected data
        if valid_row
          csv_data << compute_row(row)
        else
          @rejected_user_data << row
        end
        if !self.limit.zero? && valid_row
          row_count += 1
          if row_count >= self.limit
            break
          end
        end
      end
      # Save original CSV data for post-processing report
      @original_csv_data = csv_data
    end

    # Get complete email list from the DB
    def complete_email_list
      #Email.select(:email).map{|email_record| email_record.email}
      User.all.map(&:email)
    end

    # Get complete name list from the DB
    def complete_name_list
      #User.select(:name).map{|user_record| user_record.name}
    end

    # Give the row number to each row and initialize a errors fields
    def precompute_row(row, csv_row_number)
      row[:errors] = []
      row[:unknown_errors] = []
      row[:csv_row_number] = csv_row_number
      row
    end

    # Returns true if the given normalized row data is valid
    def valid_row?(row)
      required_csv_fields.all? do |required_field|
        valid_field = row[required_field].present?
        row[:errors] << "The field #{I18n.t(required_field).titleize} is required!" unless valid_field
        valid_field
      end
    end

    # Set here the required normalized CSV field names that need to be present for a row to be valid
    def required_csv_fields
      [:email, :name]
    end

    # Set here the required normalized CSV header names that need to be present for a CSV file to be valid
    def required_csv_headers
      [:email, :name]
    end

    # Returns true if the given normalized row headers are valid
    def valid_headers?(row)
      (required_csv_headers - row.keys).empty?
    end

    # Performs additional transformations on normalized row data
    def compute_row(row)
      row
    end

    # Transforms keys to symbol_underscore and all values to strings (normalize data)
    def normalize_row(row)
      Hash[row.map{|column_name, row_value| [column_name.parameterize.underscore.to_sym, row_value.to_s]}]
    end

    # Validation that CSV file name ends in .csv
    def csv_file_format
      if file.original_filename !~ /.*\.csv/
        errors.add :file, 'is not a .csv file'
      end
    end

    # Validates that file headers are ok with the first row
    def csv_file_headers
      # Open file
      CSV.foreach(self.file.path, headers: true) do |row|
        # Transform row to hash
        row = row.to_hash
        # Normalize it
        row = normalize_row(row)
        errors.add(:file, "Invalid CSV headers, please check if #{required_csv_headers.join(', ')} are present.") unless valid_headers?(row)
        break
      end
    end
  end
end
